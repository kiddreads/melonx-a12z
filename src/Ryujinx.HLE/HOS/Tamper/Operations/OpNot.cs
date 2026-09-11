namespace Ryujinx.HLE.HOS.Tamper.Operations
{
    class OpNot<T> : IOperation where T : unmanaged
    {
        readonly IOperand _destination;
        readonly IOperand _source;

        public OpNot(IOperand destination, IOperand source)
        {
            _destination = destination;
            _source = source;
        }

        public void Execute()
        {
            T result = TypeSafeOperations.BitwiseNot(_source.Get<T>());
            _destination.Set(result);
        }
    }
}
