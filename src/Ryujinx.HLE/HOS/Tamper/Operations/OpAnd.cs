namespace Ryujinx.HLE.HOS.Tamper.Operations
{
    class OpAnd<T> : IOperation where T : unmanaged
    {
        readonly IOperand _destination;
        readonly IOperand _lhs;
        readonly IOperand _rhs;

        public OpAnd(IOperand destination, IOperand lhs, IOperand rhs)
        {
            _destination = destination;
            _lhs = lhs;
            _rhs = rhs;
        }

        public void Execute()
        {
            T result = TypeSafeOperations.BitwiseAnd(_lhs.Get<T>(), _rhs.Get<T>());
            _destination.Set(result);
        }
    }
}
