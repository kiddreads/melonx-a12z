namespace Ryujinx.Audio.Renderer.Dsp.Command
{
    public enum CommandType : byte
    {
        Invalid,
        PcmInt16DataSourceVersion1,
        PcmInt16DataSourceVersion2,
        PcmFloatDataSourceVersion1,
        PcmFloatDataSourceVersion2,
        AdpcmDataSourceVersion1,
        AdpcmDataSourceVersion2,
        Volume,
        VolumeRamp,
        BiquadFilter,
        BiquadFilterFloatCoeff, // 20.0.0+
        Mix,
        MixRamp,
        MixRampGrouped,
        DepopPrepare,
        DepopForMixBuffers,
        Delay,
        Upsample,
        DownMixSurroundToStereo,
        AuxiliaryBuffer,
        DeviceSink,
        CircularBufferSink,
        Reverb,
        Reverb3d,
        Performance,
        ClearMixBuffer,
        CopyMixBuffer,
        LimiterVersion1,
        LimiterVersion2,
        MultiTapBiquadFilter,
        MultiTapBiquadFilterFloatCoeff, // 20.0.0+
        CaptureBuffer,
        Compressor,
        BiquadFilterAndMix,
        BiquadFilterAndMixFloatCoeff, // 20.0.0+
        MultiTapBiquadFilterAndMix,
        MultiTapBiquadFilterAndMixFloatCoef, // 20.0.0+
        AuxiliaryBufferGrouped, // 20.0.0+
        FillMixBuffer, // 20.0.0+
        BiquadFilterCrossFade, // 20.0.0+
        MultiTapBiquadFilterCrossFade, // 20.0.0+
        FillBuffer, // 20.0.0+
    }
}
