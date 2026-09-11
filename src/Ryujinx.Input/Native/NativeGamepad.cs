using Ryujinx.Common.Configuration.Hid;
using Ryujinx.Common.Configuration.Hid.Controller;
using System.Collections.Generic;
using System;
using System.Numerics;
using System.Runtime.InteropServices;

namespace Ryujinx.Input.Native
{
    public class NativeGamepad : IGamepad
    {
        private readonly object _stateLock = new object();
        private readonly bool[] _buttonStates;
        private readonly float[] _stickStates; 
        private readonly Vector3[] _motionStates; 

        private static readonly GamepadButtonInputId[] ButtonMapping = new GamepadButtonInputId[17]
        {
            GamepadButtonInputId.A,             // 0
            GamepadButtonInputId.B,             // 1
            GamepadButtonInputId.X,             // 2
            GamepadButtonInputId.Y,             // 3
            GamepadButtonInputId.Back,          // 4
            GamepadButtonInputId.Guide,         // 5
            GamepadButtonInputId.Start,         // 6
            GamepadButtonInputId.LeftStick,     // 7
            GamepadButtonInputId.RightStick,    // 8
            GamepadButtonInputId.LeftShoulder,  // 9
            GamepadButtonInputId.RightShoulder, // 10
            GamepadButtonInputId.DpadUp,        // 11
            GamepadButtonInputId.DpadDown,      // 12
            GamepadButtonInputId.DpadLeft,      // 13
            GamepadButtonInputId.DpadRight,     // 14
            GamepadButtonInputId.LeftTrigger,   // 15
            GamepadButtonInputId.RightTrigger   // 16
        };

        private StandardControllerInputConfig _configuration;
        private float _triggerThreshold;

        public string Id { get; }
        public string Name { get; }
        public bool IsConnected { get; private set; }
        public GamepadFeaturesFlag Features { get; }

        public NativeGamepad(string name, string id)
        {
            Name = name;
            Id = id;
            IsConnected = true;
            Features = GamepadFeaturesFlag.Rumble | GamepadFeaturesFlag.Motion;

            _buttonStates = new bool[(int)GamepadButtonInputId.Count];
            _stickStates = new float[4];
            _motionStates = new Vector3[2];
            _triggerThreshold = 0.0f;
        }

        internal void SetButtonStateInternal(int buttonId2, bool pressed)
        {
            if (buttonId2 >= 0 && buttonId2 < ButtonMapping.Length)
            {
                int mappedId = (int)ButtonMapping[buttonId2];
                lock (_stateLock)
                {
                    _buttonStates[mappedId] = pressed;
                }
            }
        }

        internal void SetStickAxisInternal(int stickId, float x, float y)
        {
            lock (_stateLock)
            {
                if (stickId == 1) // Left Stick
                {
                    _stickStates[0] = Math.Clamp(x, -1.0f, 1.0f);
                    _stickStates[1] = Math.Clamp(y, -1.0f, 1.0f);
                }
                else if (stickId == 2) // Right Stick
                {
                    _stickStates[2] = Math.Clamp(x, -1.0f, 1.0f);
                    _stickStates[3] = Math.Clamp(y, -1.0f, 1.0f);
                }
            }
        }

        internal void SetMotionDataInternal(int motionType, float x, float y, float z)
        {
            lock (_stateLock)
            {
                if (motionType == (int)MotionInputId.Accelerometer)
                    _motionStates[0] = new Vector3(x, y, z);
                else if (motionType == (int)MotionInputId.Gyroscope)
                    _motionStates[1] = new Vector3(x, y, z);
            }
        }

        public GamepadStateSnapshot GetStateSnapshot()
        {
            return IGamepad.GetStateSnapshot(this);
        }
        
        public GamepadStateSnapshot GetMappedStateSnapshot() => GetStateSnapshot();

        public bool IsPressed(GamepadButtonInputId inputId)
        {
            lock (_stateLock)
            {
                return (int)inputId >= 0 && (int)inputId < _buttonStates.Length && _buttonStates[(int)inputId];
            }
        }

        public (float, float) GetStick(StickInputId inputId)
        {
            lock (_stateLock)
            {
                return inputId == StickInputId.Left ? (_stickStates[0], _stickStates[1]) : (_stickStates[2], _stickStates[3]);
            }
        }

        public Vector3 GetMotionData(MotionInputId inputId)
        {
            lock (_stateLock)
            {
                return inputId == MotionInputId.Accelerometer ? _motionStates[0] : _motionStates[1];
            }
        }

        public void SetConfiguration(InputConfig configuration)
        {
            _configuration = (StandardControllerInputConfig)configuration;
            _triggerThreshold = _configuration.TriggerThreshold;
        }

        public void SetTriggerThreshold(float triggerThreshold) => _triggerThreshold = triggerThreshold;

        public void ResetStateInternal()
        {
            lock (_stateLock)
            {
                Array.Clear(_buttonStates, 0, _buttonStates.Length);
                Array.Clear(_stickStates, 0, _stickStates.Length);
                Array.Clear(_motionStates, 0, _motionStates.Length);
            }
        }

        [DllImport("RyujinxHelper.framework/RyujinxHelper", CallingConvention = CallingConvention.Cdecl)]
        public static extern void TriggerCallbackWithData(string cIdentifier, IntPtr data, UIntPtr dataLength);

        public void Rumble(float lowFrequency, float highFrequency, uint durationMs)
        {
            var rumbleData = new RumbleData { LowFrequency = lowFrequency, HighFrequency = highFrequency, DurationMs = durationMs };
            int size = Marshal.SizeOf(typeof(RumbleData));
            IntPtr ptr = Marshal.AllocHGlobal(size);
            try {
                Marshal.StructureToPtr(rumbleData, ptr, false);
                TriggerCallbackWithData($"rumble-{Id}", ptr, (UIntPtr)size);
            } finally {
                Marshal.FreeHGlobal(ptr);
            }
        }

        public void Dispose() => IsConnected = false;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct RumbleData { public float LowFrequency; public float HighFrequency; public uint DurationMs; }
}