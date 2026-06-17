{ config, lib, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.udev.extraRules = ''
    KERNEL=="card*", KERNELS=="0000:00:02.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/card-intel"
    KERNEL=="card*", KERNELS=="0000:01:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/card-nvidia"
  '';

  services.xserver.videoDrivers = [
    "intel"
    "nvidia"
    "modesetting"
  ];

  # ===============================================================================================
  # for Intel GPU
  # https://wiki.nixos.org/wiki/Intel_Graphics
  # https://wiki.archlinux.org/title/Intel_graphics
  # https://github.com/NixOS/nixos-hardware/tree/master/common/gpu/intel
  # ===============================================================================================

  boot.kernelParams = [
    # "i915.force_probe=!a78b"
    # "xe.force_probe=a78b"
  ];
  # Video acceleration has already been configured by nixos-hardware module

  hardware.intelgpu = {
    driver = "i915"; # or "xe"
    enableHybridCodec = true;
  };

  # ===============================================================================================
  # for Nvidia GPU
  # https://wiki.nixos.org/wiki/NVIDIA
  # https://wiki.hyprland.org/Nvidia/
  # https://github.com/NixOS/nixos-hardware/tree/master/common/gpu/nvidia
  # ===============================================================================================

  hardware.nvidia.primeBatterySaverSpecialisation = true;

  # Video acceleration has already been configured by nixos-hardware module

  hardware.nvidia = {
    # Open-source kernel modules are preferred over and planned to steadily replace proprietary modules
    open = true;
    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/os-specific/linux/nvidia-x11/default.nix
    package = config.boot.kernelPackages.nvidiaPackages.latest;

    nvidiaSettings = true;

    # required by most wayland compositors!
    modesetting.enable = true;

    powerManagement = {
      enable = true;
      finegrained = true;
    };
    dynamicBoost.enable = true;

    # Already configured and enabled by nixos-hardware module
    prime = {
    };
  };

  nixpkgs.overlays = [
    (_: super: {
      # ffmpeg-full = super.ffmpeg-full.override {
      #   withNvcodec = true;
      # };
    })
  ];

  services.sunshine.settings = {
    max_bitrate = 20000; # in Kbps
    # NVIDIA NVENC Encoder
    nvenc_preset = 3; # 1(fastest + worst quality) - 7(slowest + best quality)
    nvenc_twopass = "full_res"; # quarter_res / full_res.
  };
}
