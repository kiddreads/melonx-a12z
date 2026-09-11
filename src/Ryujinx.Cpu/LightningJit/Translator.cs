using ARMeilleure.Common;
using ARMeilleure.Memory;
using Ryujinx.Cpu.Jit;
using Ryujinx.Cpu.LightningJit.Cache;
using Ryujinx.Cpu.LightningJit.CodeGen.Arm64;
using Ryujinx.Cpu.LightningJit.State;
using Ryujinx.Cpu.Signal;
using Ryujinx.Memory;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;
using Ryujinx.Common.Logging;

namespace Ryujinx.Cpu.LightningJit
{
    public class DualMappedTranslator {
        public static bool InitializeDualMapped() {
            return Translator.InitializeDualMapped();
        }
    }

    class Translator : IDisposable
    {
        // Should be enabled on platforms that enforce W^X.
        private static bool IsNoWxPlatform => OperatingSystem.IsIOS();


        private static readonly AddressTable<ulong>.Level[] _levels64Bit =
            new AddressTable<ulong>.Level[]
            {
                new(31, 17),
                new(23,  8),
                new(15,  8),
                new( 7,  8),
                new( 2,  5),
            };

        private static readonly AddressTable<ulong>.Level[] _levels32Bit =
            new AddressTable<ulong>.Level[]
            {
                new(23, 9),
                new(15, 8),
                new( 7, 8),
                new( 1, 6),
            };

        private readonly ConcurrentQueue<KeyValuePair<ulong, TranslatedFunction>> _oldFuncs;
        private readonly NoWxCache _noWxCache;
        public DualMappedNoWxCache _dualMappedCache;
        private bool _disposed;

        private static DualMappedNoWxCache originalDualMappedCache;
        private static bool firstSet = false;

        static internal TranslatorCache<TranslatedFunction> Functions { get; set; }
        internal AddressTable<ulong> FunctionTable { get; }
        static internal TranslatorStubs Stubs { get; set; }
        internal IMemoryManager Memory { get; }

        public Translator(IMemoryManager memory, bool for64Bits)
        {
            Memory = memory;

            _oldFuncs = new ConcurrentQueue<KeyValuePair<ulong, TranslatedFunction>>();

            if (IsNoWxPlatform)
            {
                string dualMapped = Environment.GetEnvironmentVariable("DUAL_MAPPED_JIT");
                if (dualMapped == "1") //(OperatingSystem.IsIOSVersionAtLeast(19) || OperatingSystem.IsIOSVersionAtLeast(26))
                {
                    Console.WriteLine($"Dual Mapped JIT enabled.");
                    if (DualMappedJitAllocator.hasTXM)
                    {
                        if (originalDualMappedCache == null) {
                            originalDualMappedCache = new(new JitMemoryAllocator(), CreateStackWalker());
                            Functions = new TranslatorCache<TranslatedFunction>();
                        }
                        _dualMappedCache = originalDualMappedCache;
                        _dualMappedCache.SetTranslator(this);
                        FunctionTable = new AddressTable<ulong>(for64Bits ? _levels64Bit : _levels32Bit);
                        Stubs = new TranslatorStubs(FunctionTable, _dualMappedCache); 
                    } 
                    else
                    {
                        if (originalDualMappedCache != null && !firstSet)
                        {
                            _dualMappedCache = originalDualMappedCache;
                            firstSet = true;
                        } else
                        {
                            _dualMappedCache = new(new JitMemoryAllocator(), CreateStackWalker());
                        }
                        _dualMappedCache.SetTranslator(this);
                        Functions = new TranslatorCache<TranslatedFunction>();
                        FunctionTable = new AddressTable<ulong>(for64Bits ? _levels64Bit : _levels32Bit);
                        Stubs = new TranslatorStubs(FunctionTable, _dualMappedCache); 
                    }
                }
                else
                {
                    if (_dualMappedCache != null) {
                        _dualMappedCache = null;
                    }
                    _noWxCache = new(new JitMemoryAllocator(), CreateStackWalker(), this);
                    Functions = new TranslatorCache<TranslatedFunction>();
                    FunctionTable = new AddressTable<ulong>(for64Bits ? _levels64Bit : _levels32Bit);
                    Stubs = new TranslatorStubs(FunctionTable, _noWxCache);
                }
            }
            else
            {
                JitCache.Initialize(new JitMemoryAllocator(forJit: true));
                Functions = new TranslatorCache<TranslatedFunction>();
                FunctionTable = new AddressTable<ulong>(for64Bits ? _levels64Bit : _levels32Bit);
                Stubs = new TranslatorStubs(FunctionTable, (NoWxCache)null);
            }

            FunctionTable.Fill = (ulong)Stubs.SlowDispatchStub;

            if (memory.Type.IsHostMappedOrTracked())
            {
                NativeSignalHandler.InitializeSignalHandler();
            }

        }

        public static bool InitializeDualMapped() {
            if (IsNoWxPlatform)
            {   
                string dualMapped = Environment.GetEnvironmentVariable("DUAL_MAPPED_JIT");
                if (dualMapped == "1") //(OperatingSystem.IsIOSVersionAtLeast(19) || OperatingSystem.IsIOSVersionAtLeast(26))
                {
                    Console.WriteLine($"Dual Mapped JIT enabled.");
                    try {
                        if (originalDualMappedCache == null) {
                            originalDualMappedCache = new(new JitMemoryAllocator(), CreateStackWalker());
                            Functions = new TranslatorCache<TranslatedFunction>();
                        }
                    } catch {
                        return false;
                    }

                    NativeSignalHandler.InitializeSignalHandler();

                }

            }

            return true;
        }

        private static IStackWalker CreateStackWalker()
        {
            if (RuntimeInformation.ProcessArchitecture == Architecture.Arm64)
            {
                return new StackWalker();
            }
            else
            {
                throw new PlatformNotSupportedException();
            }
        }

        public void Execute(State.ExecutionContext context, ulong address)
        {
            ObjectDisposedException.ThrowIf(_disposed, this);

            NativeInterface.RegisterThread(context, Memory, this);

            // NativeInterface.SetPageTablePointer();

            Stubs.DispatchLoop(context.NativeContextPtr, address);


            NativeInterface.UnregisterThread();
            _noWxCache?.ClearEntireThreadLocalCache();
            _dualMappedCache?.ClearEntireThreadLocalCache();
        }


        internal IntPtr GetOrTranslatePointer(IntPtr framePointer, ulong address, ExecutionMode mode)
        {
            int guestCodeLength = 0;
            try
            {
                if (_noWxCache != null)
                {
                    if (_noWxCache.TryGetThreadLocalFunction(address, out IntPtr funcPtr))
                    {
                        return funcPtr;
                    }

                    CompiledFunction func = Compile(address, mode);
                    guestCodeLength = func.Code.Length;
                    return _noWxCache.Map(framePointer, func.Code, address, (ulong)func.GuestCodeLength);
                }
                else if (_dualMappedCache != null)
                {
                    if (_dualMappedCache.TryGetThreadLocalFunction(address, out IntPtr funcPtr))
                    {
                        return funcPtr;
                    }

                    CompiledFunction func = Compile(address, mode);
                    guestCodeLength = func.Code.Length;
                    return _dualMappedCache.Map(framePointer, func.Code, address, (ulong)func.GuestCodeLength);
                }
            }
            catch (Exception ex)
            {
                // thank you @BXYMartin for helping with this diagnostic info.
                string dualMappedEnv = Environment.GetEnvironmentVariable("DUAL_MAPPED_JIT");
                string diagnosticInfo = $"GetOrTranslatePointer failed for address 0x{address:X16}:\n" +
                    $"  framePointer: 0x{framePointer:X}\n" +
                    $"  mode: {mode}\n" +
                    $"  IsNoWxPlatform: {IsNoWxPlatform}\n" +
                    $"  DUAL_MAPPED_JIT env: '{dualMappedEnv}'\n" +
                    $"  DualMappedJitAllocator.hasTXM: {DualMappedJitAllocator.hasTXM}\n" +
                    $"  _noWxCache: {(_noWxCache != null ? "NOT NULL" : "NULL")}\n" +
                    $"  _dualMappedCache: {(_dualMappedCache != null ? "NOT NULL" : "NULL")}\n" +
                    $"  originalDualMappedCache: {(originalDualMappedCache != null ? "NOT NULL" : "NULL")}\n" +
                    $"  firstSet: {firstSet}\n" +
                    $"  Exception: {ex.GetType().Name}: {ex.Message}\n" +
                    $"  Stack trace: {ex.StackTrace}";
                    
                
                Logger.Info?.Print(LogClass.Cpu, diagnosticInfo);
                int nopLength = guestCodeLength > 0 ? guestCodeLength : 4;
                return CreateNopFunction(framePointer, address, mode, nopLength);
            }

            return GetOrTranslate(address, mode).FuncPointer;
        }

        private IntPtr CreateNopFunction(IntPtr framePointer, ulong address, ExecutionMode mode, int guestCodeLength)
        {
            byte[] nopInstruction;
            byte[] retInstruction;
            int instructionSize;
            
            if (mode == ExecutionMode.Aarch64)
            {
                nopInstruction = new byte[] { 0x1F, 0x20, 0x03, 0xD5 };
                retInstruction = new byte[] { 0xC0, 0x03, 0x5F, 0xD6 };
                instructionSize = 4;
            }
            else
            {
                nopInstruction = new byte[] { 0x90 };
                retInstruction = new byte[] { 0xC3 };
                instructionSize = 1;
            }
            
            int totalSize = Math.Max(guestCodeLength, instructionSize);
            byte[] nopCode = new byte[totalSize];
            
            for (int i = 0; i < totalSize - instructionSize; i++)
            {
                nopCode[i] = nopInstruction[i % instructionSize];
            }
            
            for (int i = 0; i < instructionSize; i++)
            {
                nopCode[totalSize - instructionSize + i] = retInstruction[i];
            }
            
            try
            {
                if (_noWxCache != null)
                {
                    return _noWxCache.Map(framePointer, nopCode, address, (ulong)totalSize); 
                }
                else if (_dualMappedCache != null)
                {
                    return _dualMappedCache.Map(framePointer, nopCode, address, (ulong)totalSize);
                }
            }
            catch (Exception nopEx)
            {
                Logger.Warning?.Print(LogClass.Cpu, $"Failed to create NOP function for 0x{address:X16}: {nopEx.Message}");
            }
            return IntPtr.Zero;
        }

        private TranslatedFunction GetOrTranslate(ulong address, ExecutionMode mode)
        {
            if (!Functions.TryGetValue(address, out TranslatedFunction func))
            {
                func = Translate(address, mode);

                TranslatedFunction oldFunc = Functions.GetOrAdd(address, func.GuestSize, func);

                if (oldFunc != func)
                {
                    JitCache.Unmap(func.FuncPointer);
                    func = oldFunc;
                }

                RegisterFunction(address, func);
            }

            return func;
        }

        internal void RegisterFunction(ulong guestAddress, TranslatedFunction func)
        {
            if (FunctionTable.IsValid(guestAddress))
            {
                Volatile.Write(ref FunctionTable.GetValue(guestAddress), (ulong)func.FuncPointer);
            }
        }

        private TranslatedFunction Translate(ulong address, ExecutionMode mode)
        {
            CompiledFunction func = Compile(address, mode);
            IntPtr funcPointer = JitCache.Map(func.Code);

            return new TranslatedFunction(funcPointer, (ulong)func.GuestCodeLength);
        }

        public CompiledFunction Compile(ulong address, ExecutionMode mode)
        {
            return AarchCompiler.Compile(CpuPresets.CortexA57, Memory, address, FunctionTable, Stubs.DispatchStub, mode, RuntimeInformation.ProcessArchitecture);
        }

        public void InvalidateJitCacheRegion(ulong address, ulong size)
        {
            ulong[] overlapAddresses = Array.Empty<ulong>();

            int overlapsCount = Functions.GetOverlaps(address, size, ref overlapAddresses);

            for (int index = 0; index < overlapsCount; index++)
            {
                ulong overlapAddress = overlapAddresses[index];

                if (Functions.TryGetValue(overlapAddress, out TranslatedFunction overlap))
                {
                    Functions.Remove(overlapAddress);
                    Volatile.Write(ref FunctionTable.GetValue(overlapAddress), FunctionTable.Fill);
                    EnqueueForDeletion(overlapAddress, overlap);
                }
            }

            // TODO: Remove overlapping functions from the JitCache aswell.
            // This should be done safely, with a mechanism to ensure the function is not being executed.
        }

        private void EnqueueForDeletion(ulong guestAddress, TranslatedFunction func)
        {
            _oldFuncs.Enqueue(new(guestAddress, func));
        }

        private void ClearJitCache()
        {
            List<TranslatedFunction> functions = Functions.AsList();

            foreach (var func in functions)
            {
                JitCache.Unmap(func.FuncPointer);
            }

            Functions.Clear();

            while (_oldFuncs.TryDequeue(out var kv))
            {
                JitCache.Unmap(kv.Value.FuncPointer);
            }
        }

        protected virtual void Dispose(bool disposing)
        {
            if (!_disposed)
            {
                if (disposing)
                {
                    if (_noWxCache != null)
                    {
                        _noWxCache.Dispose();
                    }
                    else if (_dualMappedCache != null)
                    {
                        _dualMappedCache.Dispose();
                    }
                    else
                    {
                        ClearJitCache();
                    }

                    Stubs.Dispose();
                    FunctionTable.Dispose();
                }

                _disposed = true;
            }
        }

        public void Dispose()
        {
            Dispose(disposing: true);
            GC.SuppressFinalize(this);
        }
    }
}
