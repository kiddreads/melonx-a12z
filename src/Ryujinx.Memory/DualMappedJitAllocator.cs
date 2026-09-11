using System;
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

        private void AllocateDualMapping()
        {
            IntPtr _mmapPtr;

            if (hasTXM)
            {
                _mmapPtr = BreakGetJITMapping((nuint)Size);
            }
            else
            {
                _mmapPtr = mmap(IntPtr.Zero, (UIntPtr)Size, PROT_READ | PROT_EXEC, MAP_ANON | MAP_PRIVATE, -1, 0);

                if (_mmapPtr == MAP_FAILED)
                    throw new Exception("Failed to mmap memory");
            }

            var bufRX = (ulong)_mmapPtr;
            ulong bufRW = 0;
            uint curProt = 0, maxProt = 0;

            int remapResult = vm_remap(mach_task_self(), ref bufRW, Size, 0, VM_FLAGS_ANYWHERE,
                                      mach_task_self(), bufRX, 0, ref curProt, ref maxProt, VM_INHERIT_NONE);
            if (remapResult != KERN_SUCCESS)
                throw new Exception($"Failed to remap RX region: {remapResult}");

            int protectRWResult = vm_protect(mach_task_self(), bufRW, Size, 0, VM_PROT_READ | VM_PROT_WRITE);
            if (protectRWResult != KERN_SUCCESS)
                throw new Exception($"Failed to set RW protection: {protectRWResult}");

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
        private const int PROT_EXEC = 4;
        private const int MAP_ANON = 0x1000;
        private const int MAP_PRIVATE = 0x2;
        private static readonly IntPtr MAP_FAILED = new IntPtr(-1);

        private const int VM_FLAGS_ANYWHERE = 1 << 0;
        private const int VM_INHERIT_NONE = 2;
        private const int KERN_SUCCESS = 0;
        private const int VM_PROT_READ = 1;
        private const int VM_PROT_WRITE = 2;

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
