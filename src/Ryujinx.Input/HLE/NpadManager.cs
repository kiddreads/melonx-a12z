using Ryujinx.Common.Configuration.Hid;
using Ryujinx.Common.Configuration.Hid.Controller;
using Ryujinx.Common.Configuration.Hid.Keyboard;
using Ryujinx.HLE.HOS.Services.Hid;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Runtime.CompilerServices;
using CemuHookClient = Ryujinx.Input.Motion.CemuHook.Client;
using ControllerType = Ryujinx.Common.Configuration.Hid.ControllerType;
using PlayerIndex = Ryujinx.HLE.HOS.Services.Hid.PlayerIndex;
using Switch = Ryujinx.HLE.Switch;

namespace Ryujinx.Input.HLE
{
    public class NpadManager : IDisposable
    {
        private readonly CemuHookClient _cemuHookClient;

        private readonly object _lock = new();

        private bool _blockInputUpdates;

        private const int MaxControllers = 9;

        private readonly NpadController[] _controllers;
        
        private readonly List<GamepadInput> _hleInputStatesCache = new(MaxControllers);
        private readonly List<SixAxisInput> _hleMotionStatesCache = new(MaxControllers * 2);

        private readonly IGamepadDriver _keyboardDriver;
        private readonly IGamepadDriver _gamepadDriver;
        private readonly IGamepadDriver _mouseDriver;
        private bool _isDisposed;

        private List<InputConfig> _inputConfig;
        private bool _enableKeyboard;
        private bool _enableMouse;
        private Switch _device;

        public NpadManager(IGamepadDriver keyboardDriver, IGamepadDriver gamepadDriver, IGamepadDriver mouseDriver)
        {
            _controllers = new NpadController[MaxControllers];
            _cemuHookClient = new CemuHookClient(this);

            _keyboardDriver = keyboardDriver;
            _gamepadDriver = gamepadDriver;
            _mouseDriver = mouseDriver;
            _inputConfig = new List<InputConfig>();

            _gamepadDriver.OnGamepadConnected += HandleOnGamepadConnected;
            _gamepadDriver.OnGamepadDisconnected += HandleOnGamepadDisconnected;
        }

        private void RefreshInputConfigForHLE()
        {
            lock (_lock)
            {
                List<InputConfig> validInputs = new();
                foreach (var inputConfigEntry in _inputConfig)
                {
                    if (_controllers[(int)inputConfigEntry.PlayerIndex] != null)
                    {
                        validInputs.Add(inputConfigEntry);
                    }
                }

                _device.Hid.RefreshInputConfig(validInputs);
            }
        }

        private void HandleOnGamepadDisconnected(string obj)
        {
            // Force input reload
            lock (_lock)
            {
                // Forcibly disconnect any controllers with this ID.
                for (int i = 0; i < _controllers.Length; i++)
                {
                    if (_controllers[i]?.Id == obj)
                    {
                        _controllers[i]?.Dispose();
                        _controllers[i] = null;
                    }
                }

                ReloadConfiguration(_inputConfig, _enableKeyboard, _enableMouse);
            }
        }

        private void HandleOnGamepadConnected(string id)
        {
            // Force input reload
            ReloadConfiguration(_inputConfig, _enableKeyboard, _enableMouse);
        }
        
        public void ReloadConfiguration(List<InputConfig> inputConfig, bool enableKeyboard, bool enableMouse)
        {
            lock (_lock)
            {
                NpadController[] oldControllers = _controllers.ToArray();

                Console.WriteLine($"Reloading input configuration... {inputConfig} controllers");

                List<InputConfig> validInputs = new();

                foreach (InputConfig inputConfigEntry in inputConfig)
                {
                    NpadController controller;
                    int index = (int)inputConfigEntry.PlayerIndex;

                    if (oldControllers[index] != null)
                    {
                        // Try reuse the existing controller.
                        controller = oldControllers[index];
                        oldControllers[index] = null;
                    }
                    else
                    {
                        controller = new(_cemuHookClient);
                    }

                    bool isValid = DriverConfigurationUpdate(ref controller, inputConfigEntry);

                    Console.WriteLine(isValid
                        ? $" - Player {inputConfigEntry.PlayerIndex}: Connected '{controller.Id}' as {inputConfigEntry.ControllerType}"
                        : $" - Player {inputConfigEntry.PlayerIndex}: No valid controller found for configuration '{inputConfigEntry.Id}'");

                    if (!isValid)
                    {
                        _controllers[index] = null;
                        controller.Dispose();
                    }
                    else
                    {
                        _controllers[index] = controller;
                        validInputs.Add(inputConfigEntry);
                    }
                }

                for (int i = 0; i < oldControllers.Length; i++)
                {
                    // Disconnect any controllers that weren't reused by the new configuration.

                    oldControllers[i]?.Dispose();
                    oldControllers[i] = null;
                }

                _inputConfig = inputConfig;
                _enableKeyboard = enableKeyboard;
                _enableMouse = enableMouse;

                _device.Hid.RefreshInputConfig(validInputs);
            }
        }

        public void UnblockInputUpdates()
        {
            lock (_lock)
            {
                foreach (InputConfig inputConfig in _inputConfig)
                {
                    _controllers[(int)inputConfig.PlayerIndex]?.GamepadDriver?.Clear();
                }

                _blockInputUpdates = false;
            }
        }

        public void BlockInputUpdates()
        {
            lock (_lock)
            {
                _blockInputUpdates = true;
            }
        }

        public void Initialize(Switch device, List<InputConfig> inputConfig, bool enableKeyboard, bool enableMouse)
        {
            _device = device;
            _device.Configuration.RefreshInputConfig = RefreshInputConfigForHLE;

            ReloadConfiguration(inputConfig, enableKeyboard, enableMouse);
        }

        public void Update(float aspectRatio = 1)
        {
            lock (_lock)
            {
                if (_blockInputUpdates) return;

                _hleInputStatesCache.Clear();
                _hleMotionStatesCache.Clear();

                foreach (InputConfig inputConfig in _inputConfig)
                {
                    NpadController controller = _controllers[(int)inputConfig.PlayerIndex];
                    if (controller == null) continue;

                    PlayerIndex playerIndex = (PlayerIndex)inputConfig.PlayerIndex;

                    DriverConfigurationUpdate(ref controller, inputConfig);

                    controller.UpdateUserConfiguration(inputConfig);
                    controller.Update();
                    
                    var rumbleQueue = _device.Hid.Npads.GetRumbleQueue(playerIndex);
                    if (rumbleQueue.Count > 0)
                    {
                        controller.UpdateRumble(rumbleQueue);
                    }

                    GamepadInput inputState = controller.GetHLEInputState();
                    inputState.Buttons |= _device.Hid.UpdateStickButtons(inputState.LStick, inputState.RStick);
                    inputState.PlayerId = playerIndex;
                    _hleInputStatesCache.Add(inputState);

                    SixAxisInput motionMain = controller.GetHLEMotionState();
                    motionMain.PlayerId = playerIndex;
                    _hleMotionStatesCache.Add(motionMain);

                    if (inputConfig.ControllerType == ControllerType.JoyconPair)
                    {
                        SixAxisInput motionAlt = controller.GetHLEMotionState(true);
                        if (!motionAlt.Equals(default))
                        {
                            motionAlt.PlayerId = playerIndex;
                            _hleMotionStatesCache.Add(motionAlt);
                        }
                    }
                }

                _device.Hid.Npads.Update(_hleInputStatesCache);
                _device.Hid.Npads.UpdateSixAxis(_hleMotionStatesCache);

                if (_enableKeyboard)
                {
                    var hleKeyboard = NpadController.GetHLEKeyboardInput(_keyboardDriver);
                    if (hleKeyboard.Keys.Length != 0) _device.Hid.Keyboard.Update(hleKeyboard);
                }

                if (_enableMouse) UpdateMouse(aspectRatio);

                _device.TamperMachine.UpdateInput(_hleInputStatesCache);
            }
        }

        private void UpdateMouse(float aspectRatio)
        {
            var mouse = _mouseDriver.GetGamepad("0") as IMouse;
            if (mouse == null) return;

            var mouseInput = IMouse.GetMouseStateSnapshot(mouse);
            uint buttons = 0;
            if (mouseInput.IsPressed(MouseButton.Button1)) buttons |= 1 << 0;
            if (mouseInput.IsPressed(MouseButton.Button2)) buttons |= 1 << 1;
            if (mouseInput.IsPressed(MouseButton.Button3)) buttons |= 1 << 2;
            if (mouseInput.IsPressed(MouseButton.Button4)) buttons |= 1 << 3;
            if (mouseInput.IsPressed(MouseButton.Button5)) buttons |= 1 << 4;

            var position = IMouse.GetScreenPosition(mouseInput.Position, mouse.ClientSize, aspectRatio);
            _device.Hid.Mouse.Update((int)position.X, (int)position.Y, buttons, (int)mouseInput.Scroll.X, (int)mouseInput.Scroll.Y, true);
        }

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        private bool DriverConfigurationUpdate(ref NpadController controller, InputConfig config)
        {
            IGamepadDriver targetDriver = config is StandardKeyboardInputConfig ? _keyboardDriver : _gamepadDriver;

            if (controller.GamepadDriver != targetDriver || controller.Id != config.Id)
            {
                return controller.UpdateDriverConfiguration(targetDriver, config);
            }

            return true;
        }


        internal InputConfig GetPlayerInputConfigByIndex(int index)
        {
            lock (_lock)
            {
                return _inputConfig.Find(x => x.PlayerIndex == (Common.Configuration.Hid.PlayerIndex)index);
            }
        }

        protected virtual void Dispose(bool disposing)
        {
            if (disposing)
            {
                lock (_lock)
                {
                    if (!_isDisposed)
                    {
                        _cemuHookClient.Dispose();

                        _gamepadDriver.OnGamepadConnected -= HandleOnGamepadConnected;
                        _gamepadDriver.OnGamepadDisconnected -= HandleOnGamepadDisconnected;

                        for (int i = 0; i < _controllers.Length; i++)
                        {
                            _controllers[i]?.Dispose();
                        }

                        _isDisposed = true;
                    }
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
