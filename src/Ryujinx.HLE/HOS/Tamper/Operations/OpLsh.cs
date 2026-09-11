namespace Ryujinx.HLE.HOS.Tamper.Operations
{
    class OpLsh<T> : IOperation where T : unmanaged
    {
        readonly IOperand _destination;
        readonly IOperand _lhs;
        readonly IOperand _rhs;

        public OpLsh(IOperand destination, IOperand lhs, IOperand rhs)
        {
            _destination = destination;
            _lhs = lhs;
            _rhs = rhs;
        }

        public void Execute()
        {
            T result = TypeSafeOperations.LeftShift(_lhs.Get<T>(), _rhs.Get<T>());
            _destination.Set(result);
        }
    }
}
