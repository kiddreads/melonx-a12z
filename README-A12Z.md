# melonx-a12z

A clone of **MeloNX itself** — not a fork of a fork — carrying one investigation: **why does it
fail on the A12Z (2020 iPad Pro) and nowhere else?**

`upstream` is a snapshot of `git.ryujinx.app/MeloNX/MeloNX-Legacy` branch `XC-ios-ht`.
`main` is that plus the changes below.

## The symptom

On an A12Z the app launches, a game starts loading, and then:

- **black screen, loading forever** — it does not crash, it hangs
- the process sits at **60–70 MB of RAM**

Reported independently by more than one A12Z owner, with identical wording. Not a
one-off install problem.

That number is the whole clue. A Switch emulator that had started would be holding *gigabytes* —
guest RAM alone is over 3 GB. Sixty megabytes means **the emulator never allocated anything at
all**. It is not rendering wrong, or running slow. It never started.

That rules out a lot. In particular it rules out the first thing everyone suspects on a family-5
GPU — Metal argument buffer tiers — because those fail during *rendering*, long after allocation.

## What is actually different about the A12Z

`src/Ryujinx.Memory/DualMappedJitAllocator.cs`:

```csharp
static public bool hasTXM => Environment.GetEnvironmentVariable("HAS_TXM") == "1";
...
if (hasTXM) { _mmapPtr = BreakGetJITMapping((nuint)Size); }   // A13 and later
else        { _mmapPtr = mmap(..., PROT_READ | PROT_EXEC, ...); }   // A12Z
```

`HAS_TXM` is set by the Swift side from a chip check whose cutoff is literally *"A12 is the last
non-TXM chip"*. So:

- **A13 and every later device** → `HAS_TXM=1` → `BreakpointJIT.framework`
- **A12Z** → `HAS_TXM=0` → a plain `mmap` + `vm_remap` path

**The A12Z runs a JIT allocator that essentially no modern device exercises.** That alone makes it
the obvious place to look, and it is the only code in the tree that branches this way.

It also explains why the bug looks unique to one chip. A12 and A12X are `HAS_TXM=0` too — but they
have 4 GB of RAM, so nobody runs a Switch emulator on them. **The A12Z is the only non-TXM device
anyone actually tries.**

## The size, which is the likely cause

`src/Ryujinx.Cpu/LightningJit/Cache/DualMappedNoWxCache.cs`:

```csharp
private ulong SharedCacheSize = DualMappedJitAllocator.hasTXM ? 512 MB : 1024 MB;
private ulong LocalCacheSize  = 256 MB;
```

**The non-TXM device asks for twice what every TXM device asks for.** A12Z requests a
**1 GB single contiguous executable mapping**, dual-mapped — so 2 GB of address space —
plus another 512 MB for the local cache, before the guest's own 3+ GB. On a 6 GB iPad
without `extended-virtual-addressing`, that is exactly the allocation that fails.

And `SharedCacheSize` is a field initialiser, so a throw from `DualMappedJitAllocator`
surfaces as a `TypeInitializationException`. That kills the emulation thread without
taking the app down — which is why it **hangs on a black screen instead of crashing**,
and why the process never grows past its launch footprint.

Black screen, infinite load, and 60–70 MB are all the same event.

There is no reason the weaker device should ask for more than the stronger one.

## The second defect, in the same path

```csharp
mmap(..., PROT_READ | PROT_EXEC, ...)              // mapped WITHOUT write
vm_remap(...)                                       // alias the same pages
vm_protect(bufRW, VM_PROT_READ | VM_PROT_WRITE)     // now make the alias writable
```

`vm_remap` caps the new mapping's `max_protection` at the source's. The source was created with no
`PROT_WRITE`, so the alias may never be permitted to become writable, and the `vm_protect` is
refused.

And **every failure in that function threw immediately** — no fallback, no diagnostics beyond a
Mach error number. A throw there means no guest memory is ever allocated, which presents as an app
idling at 60–70 MB. The failure and the symptom match exactly.

## What this clone changes

`DualMappedNoWxCache.cs`:

1. **512 MB for everyone**, instead of 1 GB for the one device least able to provide it.
2. **Halve and retry** down to 64 MB rather than failing outright. A smaller JIT cache
   costs some recompilation; a failed one stops emulation completely, because there is no
   interpreter to fall back on.

`DualMappedJitAllocator.cs`:

3. **Map `PROT_READ | PROT_WRITE | PROT_EXEC` first**, so `max_protection` is permissive enough for
   the writable alias to exist. The RX view is protected back down afterwards, so W^X still holds.
4. **Fall back rather than throw** — RWX, then RX, then `BreakGetJITMapping` even without TXM.
   That last one probably will not work, but it costs nothing and if it *does* work it identifies
   the fix precisely.
5. **Say what happened.** Every attempt is recorded, `vm_remap`'s `cur`/`max` protections are
   logged, and if `max_protection` lacks `VM_PROT_WRITE` it says so in plain words instead of
   returning an opaque Mach number.
6. **Add `PROT_WRITE`**, which the file used but never defined.

Nothing about emulation, rendering, or input is touched.

## How to read the result

Run it on the A12Z and look at the log.

| What you see | What it means |
|---|---|
| `JIT dual mapping established: RX=... RW=...` then the emulator runs | Fixed. It was the missing `PROT_WRITE`. |
| `max_protection is 0x5, which does not include VM_PROT_WRITE` | Confirms the diagnosis; the kernel refuses a writable alias even from an RWX source. Needs a different dual-mapping strategy. |
| `No strategy produced a mapping` + the list of attempts | The process is not permitted executable memory at all. A JIT-enabler problem, not an allocator one. |
| `JIT cache reduced to N MB` then it runs | Confirms the size was the problem: 1 GB was unmappable, less is fine. |
| Still 60–70 MB with none of these lines | It dies *before* the allocator. Look earlier in startup. |

Any of those four is progress, because all four are more than "it doesn't work on A12Z".

## Status

**Nothing here has run on an A12Z.** The diagnosis is from reading the source against the reported
symptom. It is written down in this much detail so it can be *disproved quickly* — if the log says
something not in the table above, the reasoning was wrong and this file should say so.

## Licence

MeloNX is GPLv3; this clone inherits it. Upstream by Stossy11.
