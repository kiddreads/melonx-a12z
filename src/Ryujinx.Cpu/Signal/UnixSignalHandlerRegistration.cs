using System;
using System.Runtime.InteropServices;

namespace Ryujinx.Cpu.Signal
{
    static partial class UnixSignalHandlerRegistration
    {
        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        public unsafe struct SigSet
        {
            fixed long sa_mask[16];
        }

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        public struct SigAction
        {
            public IntPtr sa_handler;
            public SigSet sa_mask;
            public int sa_flags;
            public IntPtr sa_restorer;
        }

        private const int SIGSEGV = 11;
        private const int SIGBUS = 10;
        private const int SA_SIGINFO = 0x00000004;

        [LibraryImport("libc", SetLastError = true)]
        private static partial int sigaction(int signum, ref SigAction sigAction, out SigAction oldAction);

        [LibraryImport("libc", SetLastError = true)]
        private static partial int sigaction(int signum, IntPtr sigAction, out SigAction oldAction);

        [LibraryImport("libc", SetLastError = true)]
        private static partial int sigemptyset(ref SigSet set);

        public static SigAction GetSegfaultExceptionHandler()
        {
            int result = sigaction(SIGSEGV, IntPtr.Zero, out SigAction old);

            if (result != 0)
            {
                throw new InvalidOperationException($"Could not get SIGSEGV sigaction. Error: {result}");
            }

            return old;
        }

        public static SigAction RegisterExceptionHandler(IntPtr action)
        {
            SigAction sig = new()
            {
                sa_handler = action,
                sa_flags = SA_SIGINFO,
            };

            sigemptyset(ref sig.sa_mask);

            int result = sigaction(SIGSEGV, ref sig, out SigAction old);

            if (result != 0)
            {
                throw new InvalidOperationException($"Could not register SIGSEGV sigaction. Error: {result}");
            }

            if (OperatingSystem.IsMacOS() || OperatingSystem.IsIOS())
            {
                result = sigaction(SIGBUS, ref sig, out _);

                if (result != 0)
                {
                    throw new InvalidOperationException($"Could not register SIGBUS sigaction. Error: {result}");
                }
            }

            return old;
        }

        /// <summary>
        /// Registers a signal handler for the specified signal number.
        /// </summary>
        /// <param name="signal">The signal number to register the handler for</param>
        /// <param name="action">Pointer to the signal handler function</param>
        /// <returns>The previous SigAction for the specified signal</returns>
        public static SigAction RegisterSignalHandler(int signal, IntPtr action)
        {
            SigAction sig = new()
            {
                sa_handler = action,
                sa_flags = SA_SIGINFO,
            };

            sigemptyset(ref sig.sa_mask);

            int result = sigaction(signal, ref sig, out SigAction old);

            if (result != 0)
            {
                throw new InvalidOperationException($"Could not register signal handler for signal {signal}. Error: {result}");
            }

            return old;
        }

        /// <summary>
        /// Gets the current signal handler for the specified signal number.
        /// </summary>
        /// <param name="signal">The signal number to query</param>
        /// <returns>The current SigAction for the specified signal</returns>
        public static SigAction GetSignalHandler(int signal)
        {
            int result = sigaction(signal, IntPtr.Zero, out SigAction old);

            if (result != 0)
            {
                throw new InvalidOperationException($"Could not get signal handler for signal {signal}. Error: {result}");
            }

            return old;
        }

        /// <summary>
        /// Restores a previously saved signal handler for the specified signal.
        /// </summary>
        /// <param name="signal">The signal number to restore the handler for</param>
        /// <param name="oldAction">The SigAction to restore</param>
        /// <returns>True if successful, false otherwise</returns>
        public static bool RestoreSignalHandler(int signal, SigAction oldAction)
        {
            return sigaction(signal, ref oldAction, out SigAction _) == 0;
        }

        public static bool RestoreExceptionHandler(SigAction oldAction)
        {
            return sigaction(SIGSEGV, ref oldAction, out SigAction _) == 0 && 
                   (!OperatingSystem.IsMacOS() || OperatingSystem.IsIOS() || sigaction(SIGBUS, ref oldAction, out SigAction _) == 0);
        }
    }
}