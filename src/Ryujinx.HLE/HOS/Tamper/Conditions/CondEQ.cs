using Ryujinx.HLE.HOS.Tamper.Operations;

namespace Ryujinx.HLE.HOS.Tamper.Conditions
{
    class CondEQ<T> : ICondition where T : unmanaged
    {
        private readonly IOperand _lhs;
        private readonly IOperand _rhs;

        public CondEQ(IOperand lhs, IOperand rhs)
        {
            _lhs = lhs;
            _rhs = rhs;
        }

        public bool Evaluate()
        {
            return TypeSafeOperations.Equal(_lhs.Get<T>(), _rhs.Get<T>());
        }
    }
}
