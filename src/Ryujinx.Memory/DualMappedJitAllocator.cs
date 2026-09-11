using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Diagnostics;
using Ryujinx.Common.Logging;

namespace Ryujinx.Memory
{
    /// <summary>
    /// Class for JIT memory allocation on iOS.
    /// Intended to allocate memory with both r/x and r/w permissions,
    /// as a workaround for stricter W^X (Write XOR Execute) enforcement introduced in iOS 26.
    /// 
    /// Specifically targets iOS 26, where the traditional method of reprotecting
    /// memory from writable to executable (RX) no longer works for JIT code.
    /// </summary>
    public class DualMappedJitAllocator : IDisposable
    {

        public IntPtr RwPtr { get; private set; }
        public IntPtr RxPtr { get; private set; }
        public ulong Size { get; private set; }

        [DllImport("BreakpointJIT.framework/BreakpointJIT", EntryPoint = "BreakGetJITMapping")]
        public static extern unsafe byte* BreakGetJITMappingPub(byte* addr, nuint bytes);

        [DllImport("BreakpointJIT.framework/BreakpointJIT", EntryPoint = "BreakMarkJITMapping")]
        public static extern unsafe byte* BreakMarkJITMapping(nuint bytes);

        [DllImport("BreakpointJIT.framework/BreakpointJIT", EntryPoint = "BreakJITDetach")]
        public static extern unsafe void BreakJITDetach();

        static public bool hasTXM => Environment.GetEnvironmentVariable("HAS_TXM") == "1"; 


        private IntPtr _mmapPtr;

        public DualMappedJitAllocator(ulong size)
        {
            var stackTrace = new StackTrace(1, false); // Skip *this* frame
            var callingMethod = stackTrace.GetFrame(0)?.GetMethod();

            Logger.Info?.Print(LogClass.Cpu,
                $"Allocating dual-mapped JIT memory of size {size} bytes, called by {callingMethod?.DeclaringType?.FullName}.{callingMethod?.Name}");
            Size = size;
            AllocateDualMapping();
        }

        IntPtr BreakGetJITMapping(nuint bytes)
        {
            unsafe
            {
                byte* ptr = BreakMarkJITMapping(bytes);
                Logger.Info?.Print(LogClass.Cpu, $"testing for BreakGetJITMapping, got {(ulong)ptr}");
                if (ptr == null || ptr == (byte*)0 || ptr == (byte*)-1 || ptr == (byte*)14757395257293275360 || ptr == (byte*)1761607904)
                {
                    ptr = BreakGetJITMappingPub(null, bytes);
                    Logger.Info?.Print(LogClass.Cpu, $"testing for BreakGetJITMapping Again, got {(ulong)ptr}");
                    if (ptr == null || ptr == (byte*)0 || ptr == (byte*)-1)
                    {
                        Logger.Info?.Print(LogClass.Cpu, "Failed to get JIT mapping from BreakGetJITMapping.");
                        throw new Exception("Failed to get JIT, Are you using StikDebug and Picture in Picture is enabled?");
                    }
                }

                return (IntPtr)ptr;
            }
        }

        // A12Z NOTE. This method is where the A12Z very likely dies.
        //
        // hasTXM comes from the HAS_TXM environment variable, which the Swift side sets
        // from a chip check whose cutoff is literally "A12 is the last non-TXM chip". So
        // every A13 and later device takes the BreakGetJITMapping path, and the A12Z takes
        // the mmap path below - a path essentially no modern device exercises.
        //
        // Two things were wrong with it:
        //
        // 1. The RX region was mapped PROT_READ|PROT_EXEC, with no PROT_WRITE. vm_remap
        //    gives the new mapping a max_protection bounded by the source's, so the
        //    vm_protect(READ|WRITE) that follows can be refused outright. Mapping
        //    READ|WRITE|EXEC up front leaves max_protection permissive enough for the
        //    writable alias to exist; the RX view is then protected back down.
        //
        // 2. Every failure threw immediately, with no fallback and no diagnostics beyond a
        //    Mach error number. Since a throw here means the emulator allocates no guest
        //    memory at all, the visible symptom is an app sitting at 60-70 MB doing
        //    nothing - which is exactly what A12Z users report, and which says nothing
        //    about the cause.
        //
        // Now every strategy is tried in order, each logs what it got, and the exception
        // raised at the end carries the whole trail.
        private void AllocateDualMapping()
        {
            IntPtr _mmapPtr = MAP_FAILED;
            var attempts = new List<string>();

            if (hasTXM)
            {
                _mmapPtr = BreakGetJITMapping((nuint)Size);
                attempts.Add($"BreakGetJITMapping -> 0x{(ulong)_mmapPtr:X}");
            }
            else
            {
                // RWX first: this is what makes the writable alias possible at all.
                _mmapPtr = mmap(IntPtr.Zero, (UIntPtr)Size,
                                PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANON | MAP_PRIVATE, -1, 0);
                attempts.Add($"mmap(RWX) -> 0x{(ulong)_mmapPtr:X}");

                if (_mmapPtr == MAP_FAILED)
                {
                    // Some configurations refuse PROT_EXEC at map time. RX still allows
                    // the remap to be attempted, and if max_protection turns out to be
                    // permissive it will work.
                    _mmapPtr = mmap(IntPtr.Zero, (UIntPtr)Size,
                                    PROT_READ | PROT_EXEC, MAP_ANON | MAP_PRIVATE, -1, 0);
                    attempts.Add($"mmap(RX) -> 0x{(ulong)_mmapPtr:X}");
                }

                if (_mmapPtr == MAP_FAILED)
                {
                    // Last resort: the path every A13+ device uses. It may well not work
                    // without TXM, but failing here is free and succeeding would identify
                    // the fix precisely.
                    try
                    {
                        _mmapPtr = BreakGetJITMapping((nuint)Size);
                        attempts.Add($"BreakGetJITMapping (non-TXM fallback) -> 0x{(ulong)_mmapPtr:X}");
                    }
                    catch (Exception e)
                    {
                        attempts.Add($"BreakGetJITMapping (non-TXM fallback) threw: {e.Message}");
                    }
                }
            }

            if (_mmapPtr == MAP_FAILED || _mmapPtr == IntPtr.Zero)
            {
                throw new Exception(
                    "Failed to allocate JIT memory. No strategy produced a mapping.\n" +
                    $"  size:    {Size} bytes\n" +
                    $"  HAS_TXM: {hasTXM}\n" +
                    $"  tried:   {string.Join("; ", attempts)}\n" +
                    "Without executable memory there is no JIT, and Ryujinx has no " +
                    "interpreter - so emulation cannot start at all.");
            }

            var bufRX = (ulong)_mmapPtr;
            ulong bufRW = 0;
            uint curProt = 0, maxProt = 0;

            int remapResult = vm_remap(mach_task_self(), ref bufRW, Size, 0, VM_FLAGS_ANYWHERE,
                                      mach_task_self(), bufRX, 0, ref curProt, ref maxProt, VM_INHERIT_NONE);
            Logger.Info?.Print(LogClass.Cpu,
                $"vm_remap -> {remapResult}, cur=0x{curProt:X} max=0x{maxProt:X}, tried: {string.Join("; ", attempts)}");
            if (remapResult != KERN_SUCCESS)
                throw new Exception(
                    $"Failed to remap RX region: {remapResult} (cur=0x{curProt:X} max=0x{maxProt:X}). " +
                    $"HAS_TXM={hasTXM}; tried: {string.Join("; ", attempts)}");

            // max_protection is the ceiling on what the alias can ever become. If WRITE is
            // not in it, the vm_protect below cannot succeed no matter what - say so
            // rather than reporting an opaque Mach error.
            if ((maxProt & VM_PROT_WRITE) == 0)
            {
                throw new Exception(
                    $"The remapped region cannot be made writable: max_protection is 0x{maxProt:X}, " +
                    $"which does not include VM_PROT_WRITE (0x{VM_PROT_WRITE:X}). The source mapping " +
                    "was created without PROT_WRITE, and vm_remap caps the alias at the source's " +
                    $"maximum. HAS_TXM={hasTXM}; tried: {string.Join("; ", attempts)}");
            }

            int protectRWResult = vm_protect(mach_task_self(), bufRW, Size, 0, VM_PROT_READ | VM_PROT_WRITE);
            if (protectRWResult != KERN_SUCCESS)
                throw new Exception(
                    $"Failed to set RW protection: {protectRWResult} (max=0x{maxProt:X}). " +
                    $"HAS_TXM={hasTXM}; tried: {string.Join("; ", attempts)}");

            // The RX view must not stay writable, or W^X is defeated and the kernel may
            // refuse execution from it later.
            int protectRXResult = vm_protect(mach_task_self(), bufRX, Size, 0, VM_PROT_READ | VM_PROT_EXECUTE);
            if (protectRXResult != KERN_SUCCESS)
                Logger.Warning?.Print(LogClass.Cpu,
                    $"Could not re-protect the RX view down to R+X: {protectRXResult}");

            Logger.Info?.Print(LogClass.Cpu,
                $"JIT dual mapping established: RX=0x{bufRX:X} RW=0x{bufRW:X} size={Size}");

            RwPtr = (IntPtr)bufRW;
            RxPtr = (IntPtr)bufRX;
        }

        public void Dispose()
        {
            if (_mmapPtr != IntPtr.Zero)
            {
                munmap(_mmapPtr, (UIntPtr)Size);
                _mmapPtr = IntPtr.Zero;

                munmap(RwPtr, (UIntPtr)Size);
                RwPtr = IntPtr.Zero;
            }
        }

        private const int PROT_READ = 1;
        private const int PROT_WRITE = 2;
        private const int PROT_EXEC = 4;
        private const int MAP_ANON = 0x1000;
        private const int MAP_PRIVATE = 0x2;
        private static readonly IntPtr MAP_FAILED = new IntPtr(-1);

        private const int VM_FLAGS_ANYWHERE = 1 << 0;
        private const int VM_INHERIT_NONE = 2;
        private const int KERN_SUCCESS = 0;
        private const int VM_PROT_READ = 1;
        private const int VM_PROT_WRITE = 2;
        private const int VM_PROT_EXECUTE = 4;

        [DllImport("libc", SetLastError = true)]
        private static extern IntPtr mmap(IntPtr addr, UIntPtr len, int prot, int flags, int fd, long offset);

        [DllImport("libc", SetLastError = true)]
        private static extern int munmap(IntPtr addr, UIntPtr len);

        [DllImport("libc")]
        private static extern ulong mach_task_self();

        [DllImport("libc")]
        private static extern int vm_remap(
            ulong target_task,
            ref ulong target_address,
            ulong size,
            ulong mask,
            int anywhere,
            ulong src_task,
            ulong src_address,
            int copy,
            ref uint cur_protection,
            ref uint max_protection,
            int inheritance
        );

        [DllImport("libc")]
        private static extern int vm_protect(
            ulong task,
            ulong address,
            ulong size,
            int set_maximum,
            int new_protection
        );
    }
}
