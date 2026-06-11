{
  myvars,
  lib,
  pkgs,
  ...
}:
#############################################################
#
#  Saika
#
#############################################################
let
  hostName = "saika"; # Define your hostname.
in
{
  imports = [
    ./netdev-mount.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./graphics.nix
    ./saika

    ./preservation.nix
    ./secureboot.nix
    ./boot.nix
    ./bitlk-decrypt.nix
    ./power.nix
  ];

  services.sunshine.enable = lib.mkForce true;

  networking = {
    inherit hostName;

    wireless.iwd.enable = true;

    networkmanager.enable = true;
    networkmanager.wifi.backend = "iwd";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplipWithPlugin ];

  # HibernateMode=shutdown ensures the system powers off after hibernation
  # instead of relying on S4 sleep state, which can be unreliable on some firmware.
  systemd.sleep.settings.Sleep.HibernateMode = "shutdown";

  systemd.oomd = {
    enableSystemSlice = true;
    enableUserSlices = true;
  };

  hardware.audio = {
    # now working well
    # speaker-tuning = {
    #   enable = true;
    #   instances."internal-spk" = {
    #     enable = true;
    #     nodeTarget = "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink";
    #     splAtZeroDbVolume = 74.0;
    #     # standard = "ISO226-2023";
    #     standard = "Flat";

    #     hardClip = false;
    #     # hardClipRange = 3.5;
    #     # description = "Integrated Speaker w/ Tuning";
    #   };
    # };

    noise-suppression = {
      enable = true;
      instances."internal-dmic" = {
        enable = true;
        nodeTarget = "alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source";
        # description = "DeepFilter Noise Canceling Source (Stereo)";
      };
    };
  };

  boot.extraModprobeConfig = ''
    options snd_sof ipc_type=1
  '';

  boot.memfd-ashmem-shim.enable = true;

  # Zram consumes physical memory for compression, which can cause a deadlock and system hang if the model size approaches the physical memory limit.
  zramSwap.enable = lib.mkForce false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
