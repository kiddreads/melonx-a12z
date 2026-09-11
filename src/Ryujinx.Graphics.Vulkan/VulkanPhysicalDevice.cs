using Ryujinx.Common.Utilities;
using Ryujinx.Graphics.GAL;
using Silk.NET.Vulkan;
using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;
using System.Runtime.InteropServices;

namespace Ryujinx.Graphics.Vulkan
{
    readonly struct VulkanPhysicalDevice
    {
        public static uint MaxPerStageDescriptorSamplers = 33;
        public readonly PhysicalDevice PhysicalDevice;
        public readonly PhysicalDeviceFeatures PhysicalDeviceFeatures;
        public readonly PhysicalDeviceProperties PhysicalDeviceProperties;
        public readonly PhysicalDeviceMemoryProperties PhysicalDeviceMemoryProperties;
        public readonly QueueFamilyProperties[] QueueFamilyProperties;
        public readonly string DeviceName;
        public readonly IReadOnlySet<string> DeviceExtensions;

        public VulkanPhysicalDevice(Vk api, PhysicalDevice physicalDevice)
        {
            PhysicalDevice = physicalDevice;
            PhysicalDeviceFeatures = api.GetPhysicalDeviceFeature(PhysicalDevice);

            api.GetPhysicalDeviceProperties(PhysicalDevice, out var physicalDeviceProperties);
            PhysicalDeviceProperties = physicalDeviceProperties;

            api.GetPhysicalDeviceMemoryProperties(PhysicalDevice, out PhysicalDeviceMemoryProperties);

            unsafe
            {
                DeviceName = Marshal.PtrToStringAnsi((IntPtr)physicalDeviceProperties.DeviceName);
            }

            Console.WriteLine($"Device: {DeviceName}");
            Console.WriteLine($"Max per-stage descriptor samplers: {physicalDeviceProperties.Limits.MaxPerStageDescriptorSamplers}");
            Console.WriteLine($"Max descriptor set samplers: {physicalDeviceProperties.Limits.MaxDescriptorSetSamplers}");
            Console.WriteLine($"Max per-stage resources: {physicalDeviceProperties.Limits.MaxPerStageResources}");
            VulkanPhysicalDevice.MaxPerStageDescriptorSamplers = physicalDeviceProperties.Limits.MaxPerStageDescriptorSamplers;
            uint propertiesCount = 0;

            api.GetPhysicalDeviceQueueFamilyProperties(physicalDevice, SpanHelpers.AsSpan(ref propertiesCount), Span<QueueFamilyProperties>.Empty);

            QueueFamilyProperties = new QueueFamilyProperties[propertiesCount];

            api.GetPhysicalDeviceQueueFamilyProperties(physicalDevice, SpanHelpers.AsSpan(ref propertiesCount), QueueFamilyProperties);

            api.EnumerateDeviceExtensionProperties(PhysicalDevice, Span<byte>.Empty, SpanHelpers.AsSpan(ref propertiesCount), Span<ExtensionProperties>.Empty).ThrowOnError();

            ExtensionProperties[] extensionProperties = new ExtensionProperties[propertiesCount];

            api.EnumerateDeviceExtensionProperties(PhysicalDevice, Span<byte>.Empty, SpanHelpers.AsSpan(ref propertiesCount), extensionProperties).ThrowOnError();

            unsafe
            {
                DeviceExtensions = extensionProperties.Select(x => Marshal.PtrToStringAnsi((IntPtr)x.ExtensionName)).ToImmutableHashSet();
            }
        }

        public string Id => $"0x{PhysicalDeviceProperties.VendorID:X}_0x{PhysicalDeviceProperties.DeviceID:X}";

        public bool IsDeviceExtensionPresent(string extension) => DeviceExtensions.Contains(extension);

        public unsafe bool TryGetPhysicalDeviceDriverPropertiesKHR(Vk api, out PhysicalDeviceDriverPropertiesKHR res)
        {
            if (!IsDeviceExtensionPresent("VK_KHR_driver_properties"))
            {
                res = default;

                return false;
            }

            PhysicalDeviceDriverPropertiesKHR physicalDeviceDriverProperties = new()
            {
                SType = StructureType.PhysicalDeviceDriverPropertiesKhr
            };

            PhysicalDeviceProperties2 physicalDeviceProperties2 = new()
            {
                SType = StructureType.PhysicalDeviceProperties2,
                PNext = &physicalDeviceDriverProperties
            };

            api.GetPhysicalDeviceProperties2(PhysicalDevice, &physicalDeviceProperties2);

            res = physicalDeviceDriverProperties;

            return true;
        }

        public DeviceInfo ToDeviceInfo()
        {
            return new DeviceInfo(
                Id,
                VendorUtils.GetNameFromId(PhysicalDeviceProperties.VendorID),
                DeviceName,
                PhysicalDeviceProperties.DeviceType == PhysicalDeviceType.DiscreteGpu);
        }
    }
}
