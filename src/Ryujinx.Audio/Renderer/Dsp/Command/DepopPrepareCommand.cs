using Ryujinx.Audio.Renderer.Common;
using System;

namespace Ryujinx.Audio.Renderer.Dsp.Command
{
    public class DepopPrepareCommand : ICommand
    {
        public bool Enabled { get; set; }

        public int NodeId { get; private set; }

        public CommandType CommandType => CommandType.DepopPrepare;

        public uint EstimatedProcessingTime { get; set; }

        public uint MixBufferCount { get; private set; }

        public ushort[] OutputBufferIndices { get; }

        public Memory<VoiceState> State { get; private set; }
        public Memory<float> DepopBuffer { get; private set; }

        public DepopPrepareCommand()
        {
            OutputBufferIndices = new ushort[Constants.MixBufferCountMax];
        }

        public DepopPrepareCommand Initialize(Memory<VoiceState> state, Memory<float> depopBuffer, uint mixBufferCount, uint bufferOffset, int nodeId, bool enabled)
        {
            Enabled = enabled;
            NodeId = nodeId;
            MixBufferCount = mixBufferCount;

            for (int i = 0; i < Constants.MixBufferCountMax; i++)
            {
                OutputBufferIndices[i] = (ushort)(bufferOffset + i);
            }

            State = state;
            DepopBuffer = depopBuffer;

            return this;
        }

        public void Process(CommandList context)
        {
            ref VoiceState state = ref State.Span[0];

            Span<float> depopBuffer = DepopBuffer.Span;

            for (int i = 0; i < MixBufferCount; i++)
            {
                if (state.LastSamples[i] != 0)
                {
                    depopBuffer[OutputBufferIndices[i]] += state.LastSamples[i];

                    state.LastSamples[i] = 0;
                }
            }
        }
    }
}
