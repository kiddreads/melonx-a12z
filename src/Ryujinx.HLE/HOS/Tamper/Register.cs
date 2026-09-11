using Ryujinx.Common.Logging;
using Ryujinx.HLE.HOS.Tamper.Operations;
using System;
using System.Runtime.CompilerServices;

namespace Ryujinx.HLE.HOS.Tamper
{
    class Register : IOperand
    {
        private ulong _register = 0;
        private readonly string _alias;

        public Register(string alias)
        {
            _alias = alias;
        }

        public T Get<T>() where T : unmanaged
        {
            return ConvertFromUlong<T>(_register);
        }

        public void Set<T>(T value) where T : unmanaged
        {
            Logger.Debug?.Print(LogClass.TamperMachine, $"{_alias}: {value}");

            _register = ConvertToUlong(value);
        }

        private static T ConvertFromUlong<T>(ulong value) where T : unmanaged
        {
            if (typeof(T) == typeof(byte))
            {
                return (T)(object)(byte)value;
            }
            else if (typeof(T) == typeof(ushort))
            {
                return (T)(object)(ushort)value;
            }
            else if (typeof(T) == typeof(uint))
            {
                return (T)(object)(uint)value;
            }
            else if (typeof(T) == typeof(ulong))
            {
                return (T)(object)value;
            }
            else if (typeof(T) == typeof(sbyte))
            {
                return (T)(object)(sbyte)value;
            }
            else if (typeof(T) == typeof(short))
            {
                return (T)(object)(short)value;
            }
            else if (typeof(T) == typeof(int))
            {
                return (T)(object)(int)value;
            }
            else if (typeof(T) == typeof(long))
            {
                return (T)(object)(long)value;
            }
            else
            {
                // Fallback for any other unmanaged types
                return Unsafe.As<ulong, T>(ref Unsafe.AsRef(value));
            }
        }

        private static ulong ConvertToUlong<T>(T value) where T : unmanaged
        {
            if (typeof(T) == typeof(byte))
            {
                return (byte)(object)value;
            }
            else if (typeof(T) == typeof(ushort))
            {
                return (ushort)(object)value;
            }
            else if (typeof(T) == typeof(uint))
            {
                return (uint)(object)value;
            }
            else if (typeof(T) == typeof(ulong))
            {
                return (ulong)(object)value;
            }
            else if (typeof(T) == typeof(sbyte))
            {
                return (ulong)(sbyte)(object)value;
            }
            else if (typeof(T) == typeof(short))
            {
                return (ulong)(short)(object)value;
            }
            else if (typeof(T) == typeof(int))
            {
                return (ulong)(int)(object)value;
            }
            else if (typeof(T) == typeof(long))
            {
                return (ulong)(long)(object)value;
            }
            else
            {
                // Fallback for any other unmanaged types
                return Unsafe.As<T, ulong>(ref Unsafe.AsRef(value));
            }
        }
    }
}
