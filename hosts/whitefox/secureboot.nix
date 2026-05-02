{
  pkgs,
  lib,
  lanzaboote,
  ...
}:
{
  # How to enter setup mode - msi motherboard
  ## 1. enter BIOS via [Del] Key
  ## 2. <Advance mode> => <Settings> => <Security> => <Secure Boot>
  ## 3. enable <Secure Boot>
  ## 4. set <Secure Boot Mode> to <Custom>
  ## 5. enter <Key Management>
  ## 6. select <Delete All Secure Boot Variables>, and then select <No> for <Reboot Without Saving>
  ## 7. Press F10 to saving and reboot.
  imports = [
    lanzaboote.nixosModules.lanzaboote
  ];

  environment.systemPackages = [
    # For debugging and troubleshooting Secure Boot.
    pkgs.sbctl
  ];

  # Lanzaboote currently replaces the systemd-boot module.
  # This setting is usually set to true in configuration.nix
  # generated at installation time. So we force it to false
  # for now.
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";

    # If Measured Boot is enabled, you cannot store more than 8 generations on the ESP.
    # This is a strict limit required and enforced by systemd-pcrlock.
    configurationLimit = 8;

    measuredBoot = {
      enable = true;
      pcrs = [
        0
        4
        7
      ];
    };
  };
}
