using ARMeilleure.Memory;
using Ryujinx.Common;
using Ryujinx.Memory;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;

namespace Ryujinx.Cpu.LightningJit.Cache
{
    class DualMappedNoWxCache : IDisposable
    {
        private const int CodeAlignment = 4; // Bytes.
        private ulong SharedCacheSize = DualMappedJitAllocator.hasTXM ? (ulong)512 * 1024 * 1024 : 1024 * 1024 * 1024;
        private ulong LocalCacheSize = 256 * 1024 * 1024;

        // How many calls to the same function we allow until we pad the shared cache to force the function to become available there
        // and allow the guest to take the fast path.
        private const int MinCallsForPad = 8;

        private class MemoryCache : IDisposable
        {
            private readonly DualMappedJitAllocator _allocator;
            private readonly CacheMemoryAllocator _cacheAllocator;
            public DualMappedJitAllocator Allocator => _allocator;
            public IntPtr RwPointer => _allocator.RwPtr;
            public IntPtr RxPointer => _allocator.RxPtr;

            public CacheMemoryAllocator CacheAllocator => _cacheAllocator;
            public IntPtr Pointer => _allocator.RwPtr; 

            public MemoryCache(ulong size)
            {
                _allocator = new DualMappedJitAllocator(size);
                _cacheAllocator = new((int)size);
            }

            public int Allocate(int codeSize)
            {
                codeSize = AlignCodeSize(codeSize);

                int allocOffset = _cacheAllocator.Allocate(codeSize);

                if (allocOffset < 0)
                {
                    throw new OutOfMemoryException("JIT Cache exhausted.");
                }

                return allocOffset;
            }

            public void Free(int offset, int size)
            {
                _cacheAllocator.Free(offset, size);
            }

            public void SysIcacheInvalidate(int offset, int size)
            {
                if (OperatingSystem.IsMacOS() || OperatingSystem.IsIOS())
                {
                    JitSupportDarwin.SysIcacheInvalidate(_allocator.RxPtr + offset, size);
                }
                else
                {
                    throw new PlatformNotSupportedException();
                }
            }

            private static int AlignCodeSize(int codeSize)
            {
                return checked(codeSize + (CodeAlignment - 1)) & ~(CodeAlignment - 1);
            }

            protected virtual void Dispose(bool disposing)
            {
                if (disposing)
                {
                    _allocator.Dispose();
                    _cacheAllocator.Clear();
                }
            }

            public void Dispose()
            {
                Dispose(disposing: true);
                GC.SuppressFinalize(this);
            }
        }

        // With iDevices that have TXM, we need to evict old functions because the JIT cache regions are limited due to the debugger needing to map the memory.
        // The Debugger detaches after we map the initial memory JIT cache regions so we cannot map any new executable memory.
        // (Also, mapping memory with the debugger takes quite a lot of time, so JIT cache regions need to be smaller.)
        // Therefore we need to evict old functions to make space for new ones when the cache is close to full.
        private const float EvictionThreshold = 0.85f;
        public bool EnableMemoryEviction => DualMappedJitAllocator.hasTXM;

        private readonly IStackWalker _stackWalker;
        private Translator _translator;
        private readonly MemoryCache _sharedCache;
        private readonly MemoryCache _localCache;
        private readonly PageAlignedRangeList _pendingMap;
        private readonly object _lock;
        private readonly Dictionary<ulong, FunctionMetadata> _functionMetadata;
        

        class FunctionMetadata
        {
            public ulong GuestAddress;
            public int Offset;
            public int Size;
            public DateTime LastAccessTime;
            public int AccessCount;

            public FunctionMetadata(ulong guestAddress, int offset, int size)
            {
                GuestAddress = guestAddress;
                Offset = offset;
                Size = size;
                LastAccessTime = DateTime.UtcNow;
                AccessCount = 1;
            }

            public void RecordAccess()
            {
                LastAccessTime = DateTime.UtcNow;
                AccessCount++;
            }

            public double GetEvictionScore()
            {
                double recencyScore = (DateTime.UtcNow - LastAccessTime).TotalSeconds;
                double frequencyScore = 1.0 / (AccessCount + 1);
                return frequencyScore * 0.3 + recencyScore * 0.7;
            }
        }

        class ThreadLocalCacheEntry
        {
            public readonly int Offset;
            public readonly int Size;
            public readonly IntPtr FuncPtr;
            private int _useCount;

            public ThreadLocalCacheEntry(int offset, int size, IntPtr funcPtr)
            {
                Offset = offset;
                Size = size;
                FuncPtr = funcPtr;
                _useCount = 0;
            }

            public int IncrementUseCount()
            {
                return ++_useCount;
            }
        }

        [ThreadStatic]
        private static Dictionary<ulong, ThreadLocalCacheEntry> _threadLocalCache;

        public DualMappedNoWxCache(IJitMemoryAllocator allocator, IStackWalker stackWalker)
        {
            _stackWalker = stackWalker;
            _sharedCache = new MemoryCache(SharedCacheSize);
            _localCache = new MemoryCache(LocalCacheSize);
            _pendingMap = new PageAlignedRangeList(
                (offset, size) => _sharedCache.SysIcacheInvalidate(offset, size),
                (address, func) => RegisterFunction(address, func));
            _lock = new();
            _functionMetadata = new Dictionary<ulong, FunctionMetadata>();
        }

        public void SetTranslator(Translator translator)
        {
            _translator = translator;
        }

        private bool TryEvictOldFunctions(int requiredSize)
        {
            if (!EnableMemoryEviction)
            {
                return false;
            }

            int usedMemory = _sharedCache.CacheAllocator.UsedSize;
            int totalMemory = (int)SharedCacheSize;
            float utilization = (float)usedMemory / totalMemory;

            if (utilization < EvictionThreshold)
            {
                return false; 
            }

            var candidatesForEviction = _functionMetadata.Values
                .Where(m => !_pendingMap.Has(m.GuestAddress))
                .OrderByDescending(m => m.GetEvictionScore())
                .ToList();

            int freedSpace = 0;
            int targetSpace = requiredSize * 2; 

            foreach (var meta in candidatesForEviction)
            {
                if (freedSpace >= targetSpace)
                {
                    break;
                }

                if (Translator.Functions.Remove(meta.GuestAddress))
                {
                    _sharedCache.Free(meta.Offset, meta.Size);
                    _functionMetadata.Remove(meta.GuestAddress);
                    freedSpace += meta.Size;
                }
            }

            return freedSpace >= requiredSize;
        }

        public unsafe IntPtr Map(IntPtr framePointer, ReadOnlySpan<byte> code, ulong guestAddress, ulong guestSize)
        {
            try
            {
                if (TryGetThreadLocalFunction(guestAddress, out IntPtr funcPtr))
                {
                    lock (_lock)
                    {
                        if (_functionMetadata.TryGetValue(guestAddress, out var meta))
                        {
                            meta.RecordAccess();
                        }
                    }
                    return funcPtr;
                }

                lock (_lock)
                {
                    if (!_pendingMap.Has(guestAddress) && !Translator.Functions.ContainsKey(guestAddress))
                    {
                        int funcOffset;
                        
                        try
                        {
                            funcOffset = _sharedCache.Allocate(code.Length);
                        }
                        catch (OutOfMemoryException)
                        {
                            if (TryEvictOldFunctions(code.Length))
                            {
                                funcOffset = _sharedCache.Allocate(code.Length);
                            }
                            else
                            {
                                throw; 
                            }
                        }

                        funcPtr = _sharedCache.Pointer + funcOffset;
                        code.CopyTo(new Span<byte>((void*)funcPtr, code.Length));
                        funcPtr = _sharedCache.RxPointer + funcOffset;

                        TranslatedFunction function = new(funcPtr, guestSize);

                        _pendingMap.Add(funcOffset, code.Length, guestAddress, function);
                        _functionMetadata[guestAddress] = new FunctionMetadata(guestAddress, funcOffset, code.Length);
                    }

                    ClearThreadLocalCache(framePointer);

                    return AddThreadLocalFunction(code, guestAddress);
                }
            }
            catch
            {
                lock (_lock)
                {
                    var funcPtr = IntPtr.Zero;
                    int funcOffset;
                    
                    try
                    {
                        funcOffset = _sharedCache.Allocate(code.Length);
                    }
                    catch (OutOfMemoryException)
                    {
                        if (TryEvictOldFunctions(code.Length))
                        {
                            funcOffset = _sharedCache.Allocate(code.Length);
                        }
                        else
                        {
                            throw;
                        }
                    }

                    funcPtr = _sharedCache.Pointer + funcOffset;
                    code.CopyTo(new Span<byte>((void*)funcPtr, code.Length));
                    funcPtr = _sharedCache.RxPointer + funcOffset;

                    TranslatedFunction function = new(funcPtr, guestSize);

                    _pendingMap.Add(funcOffset, code.Length, guestAddress, function);
                    _functionMetadata[guestAddress] = new FunctionMetadata(guestAddress, funcOffset, code.Length);

                    ClearThreadLocalCache(framePointer);

                    return AddThreadLocalFunction(code, guestAddress);
                }
            }
        }

        public unsafe IntPtr MapPageAligned(ReadOnlySpan<byte> code)
        {
            lock (_lock)
            {
                int sizeAligned = BitUtils.AlignUp(code.Length, (int)MemoryBlock.GetPageSize());
                
                _pendingMap.Pad(_sharedCache.CacheAllocator);

                int funcOffset;
                
                try
                {
                    funcOffset = _sharedCache.Allocate(sizeAligned);
                }
                catch (OutOfMemoryException)
                {
                    if (TryEvictOldFunctions(sizeAligned))
                    {
                        funcOffset = _sharedCache.Allocate(sizeAligned);
                    }
                    else
                    {
                        throw; 
                    }
                }
                
                Debug.Assert((funcOffset & ((int)MemoryBlock.GetPageSize() - 1)) == 0);

                IntPtr funcPtr = _sharedCache.Pointer + funcOffset;
                code.CopyTo(new Span<byte>((void*)funcPtr, code.Length));
                funcPtr = _sharedCache.RxPointer + funcOffset;

                _sharedCache.SysIcacheInvalidate(funcOffset, sizeAligned);

                return funcPtr;
            }
        }

        public bool TryGetThreadLocalFunction(ulong guestAddress, out IntPtr funcPtr)
        {       
            if ((_threadLocalCache ??= new()).TryGetValue(guestAddress, out var entry))
            {
                if (entry.IncrementUseCount() >= MinCallsForPad)
                {
                    // Function is being called often, let's make it available in the shared cache so that the guest code
                    // can take the fast path and stop calling the emulator to get the function from the thread local cache.
                    // To do that we pad all "pending" function until they complete a page of memory, allowing us to reprotect them as RX.

                    lock (_lock)
                    {
                        _pendingMap.Pad(_sharedCache.CacheAllocator);
                    }
                }

                funcPtr = entry.FuncPtr;

                return true;
            }

            funcPtr = IntPtr.Zero;

            return false;
        }

        private void ClearThreadLocalCache(IntPtr framePointer)
        {
            // Try to delete functions that are already on the shared cache
            // and no longer being executed.

            if (_threadLocalCache == null)
            {
                return;
            }

            IEnumerable<ulong> callStack = _stackWalker.GetCallStack(
                framePointer,
                _localCache.RxPointer,
                (int)LocalCacheSize,
                _sharedCache.RxPointer,
                (int)SharedCacheSize
            );

            HashSet<ulong> callStackAddresses = new HashSet<ulong>(callStack);

            List<(ulong, ThreadLocalCacheEntry)> toDelete = new();

            foreach ((ulong address, ThreadLocalCacheEntry entry) in _threadLocalCache)
            {
                // We only want to delete if the function is already on the shared cache,
                // otherwise we will keep translating the same function over and over again.
                bool canDelete = !_pendingMap.Has(address);
                if (!canDelete)
                {
                    continue;
                }

                // We can only delete if the function is not part of the current thread call stack,
                // otherwise we will crash the program when the thread returns to it.
                foreach (ulong funcAddress in callStackAddresses)
                {
                    if (funcAddress >= (ulong)entry.FuncPtr && funcAddress < (ulong)entry.FuncPtr + (ulong)entry.Size)
                    {
                        canDelete = false;
                        break;
                    }
                }

                if (canDelete)
                {
                    toDelete.Add((address, entry));
                }
            }

            int pageSize = (int)MemoryBlock.GetPageSize();

            foreach ((ulong address, ThreadLocalCacheEntry entry) in toDelete)
            {
                _threadLocalCache.Remove(address);

                int sizeAligned = BitUtils.AlignUp(entry.Size, pageSize);
                _localCache.Free(entry.Offset, sizeAligned);
            }
        }

        public void ClearEntireThreadLocalCache()
        {
            // Thread is exiting, delete everything.

            if (_threadLocalCache == null)
            {
                return;
            }

            int pageSize = (int)MemoryBlock.GetPageSize();

            foreach ((_, ThreadLocalCacheEntry entry) in _threadLocalCache)
            {
                int sizeAligned = BitUtils.AlignUp(entry.Size, pageSize);
                _localCache.Free(entry.Offset, sizeAligned);
            }

            _threadLocalCache.Clear();
            _threadLocalCache = null;
        }

        private unsafe IntPtr AddThreadLocalFunction(ReadOnlySpan<byte> code, ulong guestAddress)
        {
            int alignedSize = BitUtils.AlignUp(code.Length, (int)MemoryBlock.GetPageSize());
            int funcOffset = _localCache.Allocate(alignedSize);

            Debug.Assert((funcOffset & (int)(MemoryBlock.GetPageSize() - 1)) == 0);

            IntPtr funcPtr = _localCache.Pointer + funcOffset;
            code.CopyTo(new Span<byte>((void*)funcPtr, code.Length));
            funcPtr = _localCache.RxPointer + funcOffset;

            (_threadLocalCache ??= new()).Add(guestAddress, new(funcOffset, code.Length, funcPtr));

            _localCache.SysIcacheInvalidate(funcOffset, alignedSize);

            return funcPtr;
        }

        private void RegisterFunction(ulong address, TranslatedFunction func)
        {
            TranslatedFunction oldFunc = Translator.Functions.GetOrAdd(address, func.GuestSize, func);

            Debug.Assert(oldFunc == func);

            _translator.RegisterFunction(address, func);
        }

        public void InvalidateRegion(ulong guestAddress, ulong size)
        {
            lock (_lock)
            {
                _pendingMap.RemoveOverlaps(guestAddress, size);
                
                List<ulong> metadataToRemove = new();
                
                foreach (var kvp in _functionMetadata)
                {
                    ulong addr = kvp.Key;
                    
                    if (addr >= guestAddress && addr < guestAddress + size)
                    {
                        metadataToRemove.Add(addr);
                    }
                }
                
                foreach (ulong addr in metadataToRemove)
                {
                    if (_functionMetadata.TryGetValue(addr, out var meta))
                    {
                        _sharedCache.Free(meta.Offset, meta.Size);
                        _functionMetadata.Remove(addr);
                    }
                }
            }
            
            if (_threadLocalCache != null)
            {
                List<ulong> toRemove = new();
                
                foreach (var kvp in _threadLocalCache)
                {
                    ulong addr = kvp.Key;
                    
                    if (addr >= guestAddress && addr < guestAddress + size)
                    {
                        toRemove.Add(addr);
                    }
                }
                
                int pageSize = (int)MemoryBlock.GetPageSize();
                
                foreach (ulong addr in toRemove)
                {
                    if (_threadLocalCache.TryGetValue(addr, out var entry))
                    {
                        _threadLocalCache.Remove(addr);
                        
                        int sizeAligned = BitUtils.AlignUp(entry.Size, pageSize);
                        _localCache.Free(entry.Offset, sizeAligned);
                    }
                }
            }
        }

        protected virtual void Dispose(bool disposing)
        {
            if (disposing)
            {
                _localCache?.Dispose();
                _sharedCache?.Dispose();
            }
        }

        public void Dispose()
        {
            Dispose(disposing: true);
            GC.SuppressFinalize(this);
        }
    }
}