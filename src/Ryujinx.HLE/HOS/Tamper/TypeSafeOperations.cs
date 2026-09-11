using System;
using System.Runtime.CompilerServices;

namespace Ryujinx.HLE.HOS.Tamper
{
    /// <summary>
    /// Provides type-safe operations for unmanaged types without using dynamic casting.
    /// This enables AOT compilation compatibility.
    /// </summary>
    internal static class TypeSafeOperations
    {
        public static T Add<T>(T left, T right) where T : unmanaged
        {
            if (typeof(T) == typeof(byte))
            {
                return (T)(object)(byte)((byte)(object)left + (byte)(object)right);
            }
            else if (typeof(T) == typeof(ushort))
            {
                return (T)(object)(ushort)((ushort)(object)left + (ushort)(object)right);
            }
            else if (typeof(T) == typeof(uint))
            {
                return (T)(object)((uint)(object)left + (uint)(object)right);
            }
            else if (typeof(T) == typeof(ulong))
            {
                return (T)(object)((ulong)(object)left + (ulong)(object)right);
            }
            else if (typeof(T) == typeof(sbyte))
            {
                return (T)(object)(sbyte)((sbyte)(object)left + (sbyte)(object)right);
            }
            else if (typeof(T) == typeof(short))
            {
                return (T)(object)(short)((short)(object)left + (short)(object)right);
            }
            else if (typeof(T) == typeof(int))
            {
                return (T)(object)((int)(object)left + (int)(object)right);
            }
            else if (typeof(T) == typeof(long))
            {
                return (T)(object)((long)(object)left + (long)(object)right);
            }
            else
            {
                throw new NotSupportedException($"Add operation not supported for type {typeof(T)}");
            }
        }

        public static T Subtract<T>(T left, T right) where T : unmanaged
        {
            if (typeof(T) == typeof(byte))
            {
                return (T)(object)(byte)((byte)(object)left - (byte)(object)right);
            }
            else if (typeof(T) == typeof(ushort))
            {
                return (T)(object)(ushort)((ushort)(object)left - (ushort)(object)right);
            }
            else if (typeof(T) == typeof(uint))
            {
                return (T)(object)((uint)(object)left - (uint)(object)right);
            }
            else if (typeof(T) == typeof(ulong))
            {
                return (T)(object)((ulong)(object)left - (ulong)(object)right);
            }
            else if (typeof(T) == typeof(sbyte))
            {
                return (T)(object)(sbyte)((sbyte)(object)left - (sbyte)(object)right);
            }
            else if (typeof(T) == typeof(short))
            {
                return (T)(object)(short)((short)(object)left - (short)(object)right);
            }
            else if (typeof(T) == typeof(int))
            {
                return (T)(object)((int)(object)left - (int)(object)right);
            }
            else if (typeof(T) == typeof(long))
            {
                return (T)(object)((long)(object)left - (long)(object)right);
            }
            else
            {
                throw new NotSupportedException($"Subtract operation not supported for type {typeof(T)}");
            }
        }

        public static T Multiply<T>(T left, T right) where T : unmanaged
        {
            if (typeof(T) == typeof(byte))
            {
                return (T)(object)(byte)((byte)(object)left * (byte)(object)right);
            }
            else if (typeof(T) == typeof(ushort))
            {
                return (T)(object)(ushort)((ushort)(object)left * (ushort)(object)right);
            }
            else if (typeof(T) == typeof(uint))
            {
                return (T)(object)((uint)(object)left * (uint)(object)right);
            }
            else if (typeof(T) == typeof(ulong))
            {
                return (T)(object)((ulong)(object)left * (ulong)(object)right);
            }
            else if (typeof(T) == typeof(sbyte))
            {
                return (T)(object)(sbyte)((sbyte)(object)left * (sbyte)(object)right);
            }
            else if (typeof(T) == typeof(short))
            {
                return (T)(object)(short)((short)(object)left * (short)(object)right);
            }
            else if (typeof(T) == typeof(int))
            {
                return (T)(object)((int)(object)left * (int)(object)right);
            }
            else if (typeof(T) == typeof(long))
            {
                return (T)(object)((long)(object)left * (long)(object)right);
            }
            else
            {
                throw new NotSupportedException($"Multiply operation not supported for type {typeof(T)}");
            }
        }

        public static T BitwiseAnd<T>(T left, T right) where T : unmanaged
        {
            if (typeof(T) == typeof(byte))
            {
                return (T)(object)(byte)((byte)(object)left & (byte)(object)right);
            }
            else if (typeof(T) == typeof(ushort))
            {
                return (T)(object)(ushort)((ushort)(object)left & (ushort)(object)right);
            }
            else if (typeof(T) == typeof(uint))
            {
                return (T)(object)((uint)(object)left & (uint)(object)right);
            }
            else if (typeof(T) == typeof(ulong))
            {
                return (T)(object)((ulong)(object)left & (ulong)(object)right);
            }
            else if (typeof(T) == typeof(sbyte))
            {
                return (T)(object)(sbyte)((sbyte)(object)left & (sbyte)(object)right);
            }
            else if (typeof(T) == typeof(short))
            {
                return (T)(object)(short)((short)(object)left & (short)(object)right);
            }
            else if (typeof(T) == typeof(int))
            {
                return (T)(object)((int)(object)left & (int)(object)right);
            }
            else if (typeof(T) == typeof(long))
            {
                return (T)(object)((long)(object)left & (long)(object)right);
            }
            else
            {
                throw new NotSupportedException($"BitwiseAnd operation not supported for type {typeof(T)}");
            }
        }

        public static T BitwiseOr<T>(T left, T right) where T : unmanaged
        {
            if (typeof(T) == typeof(byte))
            {
                return (T)(object)(byte)((byte)(object)left | (byte)(object)right);
            }
            else if (typeof(T) == typeof(ushort))
            {
                return (T)(object)(ushort)((ushort)(object)left | (ushort)(object)right);
            }
            else if (typeof(T) == typeof(uint))
            {
                return (T)(object)((uint)(object)left | (uint)(object)right);
            }
            else if (typeof(T) == typeof(ulong))
            {
                return (T)(object)((ulong)(object)left | (ulong)(object)right);
            }
            else if (typeof(T) == typeof(sbyte))
            {
                return (T)(object)(sbyte)((sbyte)(object)left | (sbyte)(object)right);
            }
            else if (typeof(T) == typeof(short))
            {
                return (T)(object)(short)((short)(object)left | (short)(object)right);
            }
            else if (typeof(T) == typeof(int))
            {
                return (T)(object)((int)(object)left | (int)(object)right);
            }
            else if (typeof(T) == typeof(long))
            {
                return (T)(object)((long)(object)left | (long)(object)right);
            }
            else
            {
                throw new NotSupportedException($"BitwiseOr operation not supported for type {typeof(T)}");
            }
        }

        public static T BitwiseXor<T>(T left, T right) where T : unmanaged
        {
            if (typeof(T) == typeof(byte))
            {
                return (T)(object)(byte)((byte)(object)left ^ (byte)(object)right);
            }
            else if (typeof(T) == typeof(ushort))
            {
                return (T)(object)(ushort)((ushort)(object)left ^ (ushort)(object)right);
            }
            else if (typeof(T) == typeof(uint))
            {
                return (T)(object)((uint)(object)left ^ (uint)(object)right);
            }
            else if (typeof(T) == typeof(ulong))
            {
                return (T)(object)((ulong)(object)left ^ (ulong)(object)right);
            }
            else if (typeof(T) == typeof(sbyte))
            {
                return (T)(object)(sbyte)((sbyte)(object)left ^ (sbyte)(object)right);
            }
            else if (typeof(T) == typeof(short))
            {
                return (T)(object)(short)((short)(object)left ^ (short)(object)right);
            }
            else if (typeof(T) == typeof(int))
            {
                return (T)(object)((int)(object)left ^ (int)(object)right);
            }
            else if (typeof(T) == typeof(long))
            {
                return (T)(object)((long)(object)left ^ (long)(object)right);
            }
            else
            {
                throw new NotSupportedException($"BitwiseXor operation not supported for type {typeof(T)}");
            }
        }

        public static T BitwiseNot<T>(T value) where T : unmanaged
        {
            if (typeof(T) == typeof(byte))
            {
                return (T)(object)(byte)(~(byte)(object)value);
            }
            else if (typeof(T) == typeof(ushort))
            {
                return (T)(object)(ushort)(~(ushort)(object)value);
            }
            else if (typeof(T) == typeof(uint))
            {
                return (T)(object)(~(uint)(object)value);
            }
            else if (typeof(T) == typeof(ulong))
            {
                return (T)(object)(~(ulong)(object)value);
            }
            else if (typeof(T) == typeof(sbyte))
            {
                return (T)(object)(sbyte)(~(sbyte)(object)value);
            }
            else if (typeof(T) == typeof(short))
            {
                return (T)(object)(short)(~(short)(object)value);
            }
            else if (typeof(T) == typeof(int))
            {
                return (T)(object)(~(int)(object)value);
            }
            else if (typeof(T) == typeof(long))
            {
                return (T)(object)(~(long)(object)value);
            }
            else
            {
                throw new NotSupportedException($"BitwiseNot operation not supported for type {typeof(T)}");
            }
        }

        public static T LeftShift<T>(T value, T shiftAmount) where T : unmanaged
        {
            if (typeof(T) == typeof(byte))
            {
                return (T)(object)(byte)((byte)(object)value << (int)(byte)(object)shiftAmount);
            }
            else if (typeof(T) == typeof(ushort))
            {
                return (T)(object)(ushort)((ushort)(object)value << (int)(ushort)(object)shiftAmount);
            }
            else if (typeof(T) == typeof(uint))
            {
                return (T)(object)((uint)(object)value << (int)(uint)(object)shiftAmount);
            }
            else if (typeof(T) == typeof(ulong))
            {
                return (T)(object)((ulong)(object)value << (int)(ulong)(object)shiftAmount);
            }
            else if (typeof(T) == typeof(sbyte))
            {
                return (T)(object)(sbyte)((sbyte)(object)value << (int)(sbyte)(object)shiftAmount);
            }
            else if (typeof(T) == typeof(short))
            {
                return (T)(object)(short)((short)(object)value << (int)(short)(object)shiftAmount);
            }
            else if (typeof(T) == typeof(int))
            {
                return (T)(object)((int)(object)value << (int)(object)shiftAmount);
            }
            else if (typeof(T) == typeof(long))
            {
                return (T)(object)((long)(object)value << (int)(long)(object)shiftAmount);
            }
            else
            {
                throw new NotSupportedException($"LeftShift operation not supported for type {typeof(T)}");
            }
        }

        public static T RightShift<T>(T value, T shiftAmount) where T : unmanaged
        {
            if (typeof(T) == typeof(byte))
            {
                return (T)(object)(byte)((byte)(object)value >> (int)(byte)(object)shiftAmount);
            }
            else if (typeof(T) == typeof(ushort))
            {
                return (T)(object)(ushort)((ushort)(object)value >> (int)(ushort)(object)shiftAmount);
            }
            else if (typeof(T) == typeof(uint))
            {
                return (T)(object)((uint)(object)value >> (int)(uint)(object)shiftAmount);
            }
            else if (typeof(T) == typeof(ulong))
            {
                return (T)(object)((ulong)(object)value >> (int)(ulong)(object)shiftAmount);
            }
            else if (typeof(T) == typeof(sbyte))
            {
                return (T)(object)(sbyte)((sbyte)(object)value >> (int)(sbyte)(object)shiftAmount);
            }
            else if (typeof(T) == typeof(short))
            {
                return (T)(object)(short)((short)(object)value >> (int)(short)(object)shiftAmount);
            }
            else if (typeof(T) == typeof(int))
            {
                return (T)(object)((int)(object)value >> (int)(object)shiftAmount);
            }
            else if (typeof(T) == typeof(long))
            {
                return (T)(object)((long)(object)value >> (int)(long)(object)shiftAmount);
            }
            else
            {
                throw new NotSupportedException($"RightShift operation not supported for type {typeof(T)}");
            }
        }

        public static bool Equal<T>(T left, T right) where T : unmanaged
        {
            if (typeof(T) == typeof(byte))
            {
                return (byte)(object)left == (byte)(object)right;
            }
            else if (typeof(T) == typeof(ushort))
            {
                return (ushort)(object)left == (ushort)(object)right;
            }
            else if (typeof(T) == typeof(uint))
            {
                return (uint)(object)left == (uint)(object)right;
            }
            else if (typeof(T) == typeof(ulong))
            {
                return (ulong)(object)left == (ulong)(object)right;
            }
            else if (typeof(T) == typeof(sbyte))
            {
                return (sbyte)(object)left == (sbyte)(object)right;
            }
            else if (typeof(T) == typeof(short))
            {
                return (short)(object)left == (short)(object)right;
            }
            else if (typeof(T) == typeof(int))
            {
                return (int)(object)left == (int)(object)right;
            }
            else if (typeof(T) == typeof(long))
            {
                return (long)(object)left == (long)(object)right;
            }
            else
            {
                throw new NotSupportedException($"Equal comparison not supported for type {typeof(T)}");
            }
        }

        public static bool NotEqual<T>(T left, T right) where T : unmanaged
        {
            return !Equal(left, right);
        }

        public static bool LessThan<T>(T left, T right) where T : unmanaged
        {
            if (typeof(T) == typeof(byte))
            {
                return (byte)(object)left < (byte)(object)right;
            }
            else if (typeof(T) == typeof(ushort))
            {
                return (ushort)(object)left < (ushort)(object)right;
            }
            else if (typeof(T) == typeof(uint))
            {
                return (uint)(object)left < (uint)(object)right;
            }
            else if (typeof(T) == typeof(ulong))
            {
                return (ulong)(object)left < (ulong)(object)right;
            }
            else if (typeof(T) == typeof(sbyte))
            {
                return (sbyte)(object)left < (sbyte)(object)right;
            }
            else if (typeof(T) == typeof(short))
            {
                return (short)(object)left < (short)(object)right;
            }
            else if (typeof(T) == typeof(int))
            {
                return (int)(object)left < (int)(object)right;
            }
            else if (typeof(T) == typeof(long))
            {
                return (long)(object)left < (long)(object)right;
            }
            else
            {
                throw new NotSupportedException($"LessThan comparison not supported for type {typeof(T)}");
            }
        }

        public static bool LessThanOrEqual<T>(T left, T right) where T : unmanaged
        {
            return LessThan(left, right) || Equal(left, right);
        }

        public static bool GreaterThan<T>(T left, T right) where T : unmanaged
        {
            return !LessThanOrEqual(left, right);
        }

        public static bool GreaterThanOrEqual<T>(T left, T right) where T : unmanaged
        {
            return !LessThan(left, right);
        }

        public static string FormatHex<T>(T value) where T : unmanaged
        {
            if (typeof(T) == typeof(byte))
            {
                return $"{(byte)(object)value:X}";
            }
            else if (typeof(T) == typeof(ushort))
            {
                return $"{(ushort)(object)value:X}";
            }
            else if (typeof(T) == typeof(uint))
            {
                return $"{(uint)(object)value:X}";
            }
            else if (typeof(T) == typeof(ulong))
            {
                return $"{(ulong)(object)value:X}";
            }
            else if (typeof(T) == typeof(sbyte))
            {
                return $"{(sbyte)(object)value:X}";
            }
            else if (typeof(T) == typeof(short))
            {
                return $"{(short)(object)value:X}";
            }
            else if (typeof(T) == typeof(int))
            {
                return $"{(int)(object)value:X}";
            }
            else if (typeof(T) == typeof(long))
            {
                return $"{(long)(object)value:X}";
            }
            else
            {
                return value.ToString();
            }
        }
    }
}