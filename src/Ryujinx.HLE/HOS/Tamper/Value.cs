using Ryujinx.HLE.HOS.Tamper.Operations;
using System;
using System.Runtime.CompilerServices;

namespace Ryujinx.HLE.HOS.Tamper
{
    class Value<TP> : IOperand where TP : unmanaged
    {
        private TP _value;

        public Value(TP value)
        {
            _value = value;
        }

        public T Get<T>() where T : unmanaged
        {
            return ConvertTo<T>(_value);
        }

        public void Set<T>(T value) where T : unmanaged
        {
            _value = ConvertTo<TP>(value);
        }

        private static TTo ConvertTo<TTo>(object value) where TTo : unmanaged
        {
            if (typeof(TTo) == typeof(byte))
            {
                return (TTo)(object)Convert.ToByte(value);
            }
            else if (typeof(TTo) == typeof(ushort))
            {
                return (TTo)(object)Convert.ToUInt16(value);
            }
            else if (typeof(TTo) == typeof(uint))
            {
                return (TTo)(object)Convert.ToUInt32(value);
            }
            else if (typeof(TTo) == typeof(ulong))
            {
                return (TTo)(object)Convert.ToUInt64(value);
            }
            else if (typeof(TTo) == typeof(sbyte))
            {
                return (TTo)(object)Convert.ToSByte(value);
            }
            else if (typeof(TTo) == typeof(short))
            {
                return (TTo)(object)Convert.ToInt16(value);
            }
            else if (typeof(TTo) == typeof(int))
            {
                return (TTo)(object)Convert.ToInt32(value);
            }
            else if (typeof(TTo) == typeof(long))
            {
                return (TTo)(object)Convert.ToInt64(value);
            }
            else
            {
                // Fallback for any other unmanaged types using unsafe conversion
                return Unsafe.As<object, TTo>(ref value);
            }
        }
    }
}
