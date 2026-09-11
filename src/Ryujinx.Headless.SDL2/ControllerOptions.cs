using CommandLine;
using Ryujinx.Common.Configuration.Hid;

namespace Ryujinx.Headless.SDL2
{
    public class ControllerOptions
    {
        [Option("controller-type-1", Required = false, HelpText = "Set the controller type in use for Player 1.")]
        public ControllerType controllerType1 { get; set; }

        [Option("controller-type-2", Required = false, HelpText = "Set the controller type in use for Player 2.")]
        public ControllerType controllerType2 { get; set; }

        [Option("controller-type-3", Required = false, HelpText = "Set the controller type in use for Player 3.")]
        public ControllerType controllerType3 { get; set; }

        [Option("controller-type-4", Required = false, HelpText = "Set the controller type in use for Player 4.")]
        public ControllerType controllerType4 { get; set; }

        [Option("controller-type-5", Required = false, HelpText = "Set the controller type in use for Player 5.")]
        public ControllerType controllerType5 { get; set; }

        [Option("controller-type-6", Required = false, HelpText = "Set the controller type in use for Player 6.")]
        public ControllerType controllerType6 { get; set; }

        [Option("controller-type-7", Required = false, HelpText = "Set the controller type in use for Player 7.")]
        public ControllerType controllerType7 { get; set; }

        [Option("controller-type-8", Required = false, HelpText = "Set the controller type in use for Player 8.")]
        public ControllerType controllerType8 { get; set; }

        // ControllerType

        [Option("input-id-1", Required = false, HelpText = "Set the input id in use for Player 1.")]
        public string InputId1 { get; set; }

        [Option("input-id-2", Required = false, HelpText = "Set the input id in use for Player 2.")]
        public string InputId2 { get; set; }

        [Option("input-id-3", Required = false, HelpText = "Set the input id in use for Player 3.")]
        public string InputId3 { get; set; }

        [Option("input-id-4", Required = false, HelpText = "Set the input id in use for Player 4.")]
        public string InputId4 { get; set; }

        [Option("input-id-5", Required = false, HelpText = "Set the input id in use for Player 5.")]
        public string InputId5 { get; set; }

        [Option("input-id-6", Required = false, HelpText = "Set the input id in use for Player 6.")]
        public string InputId6 { get; set; }

        [Option("input-id-7", Required = false, HelpText = "Set the input id in use for Player 7.")]
        public string InputId7 { get; set; }

        [Option("input-id-8", Required = false, HelpText = "Set the input id in use for Player 8.")]
        public string InputId8 { get; set; }

        [Option("input-id-handheld", Required = false, HelpText = "Set the input id in use for the Handheld Player.")]
        public string InputIdHandheld { get; set; }
    }
}