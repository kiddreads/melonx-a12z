using ARMeilleure.Memory;
using Ryujinx.Common;
using Ryujinx.Memory;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;

namespace Ryujinx.Cpu.LightningJit.Cache
{
    class NoWxCache : IDisposable
    {
        private const int CodeAlignment = 4; // Bytes.
        private const int SharedCacheSize = 2047 * 1024 * 1024;
        private const int LocalCacheSize = 256 * 1024 * 1024;
        private const int CacheExpansionSize = 512 * 1024 * 1024; // Size to expand by

        // How many calls to the same function we allow until we pad the shared cache to force the function to become available there
        // and allow the guest to take the fast path.
        private const int MinCallsForPad = 8;

        private class MemoryCache : IDisposable
        {
            private readonly List<ReservedRegion> _regions = new();
            private readonly List<CacheMemoryAllocator> _allocators = new();
            private readonly IJitMemoryAllocator _jitAllocator;
            private readonly ulong _initialSize;
            private readonly ulong _expansionSize;

            public nint Pointer => _regions[0].Block.Pointer;

            public MemoryCache(IJitMemoryAllocator allocator, ulong size, ulong expansionSize)
            {
                _jitAllocator = allocator;
                _initialSize = size;
                _expansionSize = expansionSize;
                
                AddCacheSegment(size);
            }

            private void AddCacheSegment(ulong size)
            {
                var region = new ReservedRegion(_jitAllocator, size);
                var cacheAllocator = new CacheMemoryAllocator((int)size);
                
                _regions.Add(region);
                _allocators.Add(cacheAllocator);
            }

            public int Allocate(int codeSize)
            {
                codeSize = AlignCodeSize(codeSize);

                if (_allocators.Count > 0)
                {
                    int baseOffset = 0;
                    for (int i = 0; i < _allocators.Count - 1; i++)
                    {
                        baseOffset += _allocators[i].Capacity;
                    }
                    
                    int allocOffset = _allocators[^1].Allocate(codeSize);
                    
                    if (allocOffset >= 0)
                    {
                        int absoluteOffset = baseOffset + allocOffset;
                        _regions[^1].ExpandIfNeeded((ulong)allocOffset + (ulong)codeSize);
                        return absoluteOffset;
                    }
                }

                int searchBaseOffset = 0;
                for (int i = 0; i < _allocators.Count; i++)
                {
                    int allocOffset = _allocators[i].Allocate(codeSize);
                    
                    if (allocOffset >= 0)
                    {
                        int absoluteOffset = searchBaseOffset + allocOffset;
                        _regions[i].ExpandIfNeeded((ulong)allocOffset + (ulong)codeSize);
                        return absoluteOffset;
                    }
                    
                    searchBaseOffset += _allocators[i].Capacity;
                }

                int newBaseOffset = searchBaseOffset;
                
                ulong newSize = Math.Max(_expansionSize, (ulong)codeSize);
                AddCacheSegment(newSize);
                
                int newAllocOffset = _allocators[^1].Allocate(codeSize);
                if (newAllocOffset < 0)
                {
                    throw new OutOfMemoryException("JIT Cache exhausted even after expansion.");
                }
                
                int finalOffset = newBaseOffset + newAllocOffset;
                _regions[^1].ExpandIfNeeded((ulong)newAllocOffset + (ulong)codeSize);
                
                return finalOffset;
            }

            public void Free(int offset, int size)
            {
                var (allocatorIndex, localOffset) = GetAllocatorForOffset(offset);
                _allocators[allocatorIndex].Free(localOffset, size);
            }

            public void ReprotectAsRw(int offset, int size)
            {
                Debug.Assert(offset >= 0 && (offset & (int)(MemoryBlock.GetPageSize() - 1)) == 0);
                Debug.Assert(size > 0 && (size & (int)(MemoryBlock.GetPageSize() - 1)) == 0);

                var (allocatorIndex, localOffset) = GetAllocatorForOffset(offset);
                _regions[allocatorIndex].Block.MapAsRw((ulong)localOffset, (ulong)size);
            }

            public void ReprotectAsRx(int offset, int size)
            {
                Debug.Assert(offset >= 0 && (offset & (int)(MemoryBlock.GetPageSize() - 1)) == 0);
                Debug.Assert(size > 0 && (size & (int)(MemoryBlock.GetPageSize() - 1)) == 0);

                var (allocatorIndex, localOffset) = GetAllocatorForOffset(offset);
                _regions[allocatorIndex].Block.MapAsRx((ulong)localOffset, (ulong)size);

                if (OperatingSystem.IsMacOS() || OperatingSystem.IsIOS())
                {
                    JitSupportDarwin.SysIcacheInvalidate(_regions[allocatorIndex].Block.Pointer + localOffset, size);
                }
                else
                {
                    throw new PlatformNotSupportedException();
                }
            }

            public nint GetPointerForOffset(int offset)
            {
                var (allocatorIndex, localOffset) = GetAllocatorForOffset(offset);
                return _regions[allocatorIndex].Block.Pointer + localOffset;
            }

            private (int allocatorIndex, int localOffset) GetAllocatorForOffset(int offset)
            {
                int baseOffset = 0;
                for (int i = 0; i < _allocators.Count; i++)
                {
                    int capacity = _allocators[i].Capacity;
                    if (offset < baseOffset + capacity)
                    {
                        return (i, offset - baseOffset);
                    }
                    baseOffset += capacity;
                }
                
                throw new ArgumentOutOfRangeException(nameof(offset), "Offset is outside allocated cache regions.");
            }

            public CacheMemoryAllocator GetCurrentAllocator()
            {
                return _allocators[^1];
            }

            private static int AlignCodeSize(int codeSize)
            {
                return checked(codeSize + (CodeAlignment - 1)) & ~(CodeAlignment - 1);
            }

            protected virtual void Dispose(bool disposing)
            {
                if (disposing)
                {
                    foreach (var region in _regions)
                    {
                        region.Dispose();
                    }
                    foreach (var allocator in _allocators)
                    {
                        allocator.Clear();
                    }
                    _regions.Clear();
                    _allocators.Clear();
                }
            }

            public void Dispose()
            {
                Dispose(disposing: true);
                GC.SuppressFinalize(this);
            }
        }

        private readonly IStackWalker _stackWalker;
        private readonly Translator _translator;
        private readonly MemoryCache _sharedCache;
        private readonly MemoryCache _localCache;
        private readonly PageAlignedRangeList _pendingMap;
        private readonly object _lock = new();

        class ThreadLocalCacheEntry
        {
            public readonly int Offset;
            public readonly int Size;
            public readonly nint FuncPtr;
            private int _useCount;

            public ThreadLocalCacheEntry(int offset, int size, nint funcPtr)
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

        public NoWxCache(IJitMemoryAllocator allocator, IStackWalker stackWalker, Translator translator)
        {
            _stackWalker = stackWalker;
            _translator = translator;
            _sharedCache = new(allocator, SharedCacheSize, CacheExpansionSize);
            _localCache = new(allocator, LocalCacheSize, CacheExpansionSize);
            _pendingMap = new(_sharedCache.ReprotectAsRx, RegisterFunction);
        }

        public unsafe nint Map(nint framePointer, ReadOnlySpan<byte> code, ulong guestAddress, ulong guestSize)
        {
            if (TryGetThreadLocalFunction(guestAddress, out nint funcPtr))
            {
                return funcPtr;
            }

            lock (_lock)
            {
                if (!_pendingMap.Has(guestAddress) && !Translator.Functions.ContainsKey(guestAddress))
                {
                    int funcOffset = _sharedCache.Allocate(code.Length);

                    funcPtr = _sharedCache.GetPointerForOffset(funcOffset);
                    code.CopyTo(new Span<byte>((void*)funcPtr, code.Length));

                    TranslatedFunction function = new(funcPtr, guestSize);

                    _pendingMap.Add(funcOffset, code.Length, guestAddress, function);
                }

                ClearThreadLocalCache(framePointer);

                return AddThreadLocalFunction(code, guestAddress);
            }
        }

        public unsafe nint MapPageAligned(ReadOnlySpan<byte> code)
        {
            lock (_lock)
            {
                // Ensure we will get an aligned offset from the allocator.
                _pendingMap.Pad(_sharedCache.GetCurrentAllocator());

                int sizeAligned = BitUtils.AlignUp(code.Length, (int)MemoryBlock.GetPageSize());
                int funcOffset = _sharedCache.Allocate(sizeAligned);

                Debug.Assert((funcOffset & ((int)MemoryBlock.GetPageSize() - 1)) == 0);

                nint funcPtr = _sharedCache.GetPointerForOffset(funcOffset);
                code.CopyTo(new Span<byte>((void*)funcPtr, code.Length));

                _sharedCache.ReprotectAsRx(funcOffset, sizeAligned);

                return funcPtr;
            }
        }

        public bool TryGetThreadLocalFunction(ulong guestAddress, out nint funcPtr)
        {
            if ((_threadLocalCache ??= new()).TryGetValue(guestAddress, out ThreadLocalCacheEntry entry))
            {
                if (entry.IncrementUseCount() >= MinCallsForPad)
                {
                    lock (_lock)
                    {
                        _pendingMap.Pad(_sharedCache.GetCurrentAllocator());
                    }
                }

                funcPtr = entry.FuncPtr;

                return true;
            }

            funcPtr = nint.Zero;

            return false;
        }

        private void ClearThreadLocalCache(nint framePointer)
        {
            // Try to delete functions that are already on the shared cache
            // and no longer being executed.

            if (_threadLocalCache == null)
            {
                return;
            }

            IEnumerable<ulong> callStack = _stackWalker.GetCallStack(
                framePointer,
                _localCache.Pointer,
                LocalCacheSize,
                _sharedCache.Pointer,
                SharedCacheSize);

            List<(ulong, ThreadLocalCacheEntry)> toDelete = [];

            foreach ((ulong address, ThreadLocalCacheEntry entry) in _threadLocalCache)
            {
                bool canDelete = !_pendingMap.Has(address);
                if (!canDelete)
                {
                    continue;
                }

                foreach (ulong funcAddress in callStack)
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
                _localCache.ReprotectAsRw(entry.Offset, sizeAligned);
            }
        }

        public void ClearEntireThreadLocalCache()
        {
            if (_threadLocalCache == null)
            {
                return;
            }

            int pageSize = (int)MemoryBlock.GetPageSize();

            foreach ((_, ThreadLocalCacheEntry entry) in _threadLocalCache)
            {
                int sizeAligned = BitUtils.AlignUp(entry.Size, pageSize);

                _localCache.Free(entry.Offset, sizeAligned);
                _localCache.ReprotectAsRw(entry.Offset, sizeAligned);
            }

            _threadLocalCache.Clear();
            _threadLocalCache = null;
        }

        private unsafe IntPtr AddThreadLocalFunction(ReadOnlySpan<byte> code, ulong guestAddress)
        {
            int alignedSize = BitUtils.AlignUp(code.Length, (int)MemoryBlock.GetPageSize());
            int funcOffset = _localCache.Allocate(alignedSize);

            Debug.Assert((funcOffset & (int)(MemoryBlock.GetPageSize() - 1)) == 0);

            nint funcPtr = _localCache.GetPointerForOffset(funcOffset);
            code.CopyTo(new Span<byte>((void*)funcPtr, code.Length));

            (_threadLocalCache ??= new()).Add(guestAddress, new(funcOffset, code.Length, funcPtr));

            _localCache.ReprotectAsRx(funcOffset, alignedSize);

            return funcPtr;
        }

        private void RegisterFunction(ulong address, TranslatedFunction func)
        {
            TranslatedFunction oldFunc = Translator.Functions.GetOrAdd(address, func.GuestSize, func);

            Debug.Assert(oldFunc == func);

            _translator.RegisterFunction(address, func);
        }

        protected virtual void Dispose(bool disposing)
        {
            if (disposing)
            {
                _localCache.Dispose();
                _sharedCache.Dispose();
            }
        }

        public void Dispose()
        {
            Dispose(disposing: true);
            GC.SuppressFinalize(this);
        }
    }
}