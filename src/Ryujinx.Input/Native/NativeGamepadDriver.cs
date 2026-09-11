using Ryujinx.Common.Configuration.Hid;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;

namespace Ryujinx.Input.Native
{
    public class NativeGamepadDriver : IGamepadDriver
    {
        private static NativeGamepadDriver _instance;
        
        private readonly ConcurrentDictionary<IntPtr, NativeGamepad> _gamepads;
        
        private readonly List<string> _gamepadIds;
        private static readonly object _idLock = new object();

        public ReadOnlySpan<string> GamepadsIds
        {
            get
            {
                lock (_idLock)
                {
                    return _gamepadIds.ToArray();
                }
            }
        }

        public string DriverName => "Native";

        public event Action<string> OnGamepadConnected;
        public event Action<string> OnGamepadDisconnected;

        public NativeGamepadDriver()
        {
            _gamepads = new ConcurrentDictionary<IntPtr, NativeGamepad>();
            _gamepadIds = new List<string>();
            _instance = this;
        }

        public static IntPtr AttachGamepad(string name, IntPtr idPtr)
        {
            try
            {
                if (_instance != null && !string.IsNullOrEmpty(name) && idPtr != IntPtr.Zero)
                {
                    // Convert to hex string once during connection only
                    string idString = idPtr.ToInt64().ToString("X");

                    NativeGamepad gamepad = new NativeGamepad(name, idString);
                    
                    if (_instance._gamepads.TryAdd(idPtr, gamepad))
                    {
                        lock (_idLock)
                        {
                            _instance._gamepadIds.Add(idString);
                        }
                        _instance.OnGamepadConnected?.Invoke(idString);
                    }
                }

                return idPtr;
            }
            catch
            {
                return IntPtr.Zero;
            }
        }
        
        public static void DetachGamepad(IntPtr idPtr)
        {
            try
            {
                if (_instance != null && idPtr != IntPtr.Zero)
                {
                    if (_instance._gamepads.TryRemove(idPtr, out NativeGamepad gamepad))
                    {
                        string idString = gamepad.Id;
                        lock (_idLock)
                        {
                            _instance._gamepadIds.Remove(idString);
                        }
                        gamepad.Dispose();
                        _instance.OnGamepadDisconnected?.Invoke(idString);
                    }
                }
            }
            catch { }
        }

        public static void SetButtonState(IntPtr idPtr, int buttonId, byte pressed)
        {
            if (_instance != null && _instance._gamepads.TryGetValue(idPtr, out var gamepad))
            {
                gamepad.SetButtonStateInternal(buttonId, pressed != 0);
            }
        }

        public static void SetStickAxis(IntPtr idPtr, int stickId, float x, float y)
        {
            if (_instance != null && _instance._gamepads.TryGetValue(idPtr, out var gamepad))
            {
                gamepad.SetStickAxisInternal(stickId, x, y);
            }
        }

        public static void SetMotionData(IntPtr idPtr, int motionType, float x, float y, float z)
        {
            if (_instance != null && _instance._gamepads.TryGetValue(idPtr, out var gamepad))
            {
                gamepad.SetMotionDataInternal(motionType, x, y, z);
            }
        }

        public static void ResetState(IntPtr idPtr)
        {
            if (_instance != null && _instance._gamepads.TryGetValue(idPtr, out var gamepad))
            {
                gamepad.ResetStateInternal();
            }
        }

        public IGamepad GetGamepad(string id)
        {
            if (string.IsNullOrEmpty(id)) return null;

            try 
            {
                IntPtr idPtr = (IntPtr)Convert.ToInt64(id, 16);
                if (_gamepads.TryGetValue(idPtr, out var gamepad))
                {
                    return gamepad;
                }
            }
            catch 
            {
                return _gamepads.Values.FirstOrDefault(g => g.Id == id);
            }
            
            return null;
        }

        protected virtual void Dispose(bool disposing)
        {
            if (disposing)
            {
                foreach (var gamepad in _gamepads.Values)
                {
                    gamepad.Dispose();
                }

                lock (_idLock)
                {
                    foreach (string id in _gamepadIds)
                    {
                        OnGamepadDisconnected?.Invoke(id);
                    }
                    _gamepadIds.Clear();
                }

                _gamepads.Clear();

                if (_instance == this)
                {
                    _instance = null;
                }
            }
        }

        public void Dispose()
        {
            GC.SuppressFinalize(this);
            Dispose(true);
        }
    }
}