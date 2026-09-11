using Ryujinx.HLE.HOS.Tamper.Operations;

namespace Ryujinx.HLE.HOS.Tamper.Conditions
{
    class CondGE<T> : ICondition where T : unmanaged
    {
        private readonly IOperand _lhs;
        private readonly IOperand _rhs;

        public CondGE(IOperand lhs, IOperand rhs)
        {
            _lhs = lhs;
            _rhs = rhs;
        }

        public bool Evaluate()
        {
            return TypeSafeOperations.GreaterThanOrEqual(_lhs.Get<T>(), _rhs.Get<T>());
        }
    }
}
