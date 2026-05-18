{ pkgs, ... }:
{
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    pulseaudio # provides `pactl`, which is required by some apps(e.g. sonic-pi)
    libfido2 # for security keys like yubikey
    libwacom # for tablets
    overskride
  ];

  #============================= Bluetooth =============================

  # enable bluetooth & gui paring tools - blueman
  # or you can use cli:
  # $ bluetoothctl
  # [bluetooth] # power on
  # [bluetooth] # agent on
  # [bluetooth] # default-agent
  # [bluetooth] # scan on
  # ...put device in pairing mode and wait [hex-address] to appear here...
  # [bluetooth] # pair [hex-address]
  # [bluetooth] # connect [hex-address]
  # Bluetooth devices automatically connect with bluetoothctl as well:
  # [bluetooth] # trust [hex-address]
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Shows battery charge of connected devices on supported
        # Bluetooth adapters. Defaults to 'false'.
        Experimental = true;
        # When enabled other devices can connect faster to us, however
        # the tradeoff is increased power consumption. Defaults to
        # 'false'.
        FastConnectable = true;
      };
      Policy = {
        # Enable all controllers when they are found. This includes
        # adapters present on start as well as adapters that are plugged
        # in later on. Defaults to 'true'.
        AutoEnable = true;
      };
    };
  };

  #================================= Misc =================================
  hardware.i2c.enable = true; # for ddcutil etc.

  services = {
    printing.enable = true; # Enable CUPS to print documents.
    geoclue2.enable = true; # Enable geolocation services.

    udev.packages = with pkgs; [
      gnome-settings-daemon
      # platformio # udev rules for platformio
      # openocd # required by paltformio, see https://github.com/NixOS/nixpkgs/issues/224895
      # openfpgaloader
    ];

    # A key remapping daemon for linux.
    # https://github.com/rvaiya/keyd
    keyd = {
      enable = true;
      keyboards.default.settings = {
        main = {
          # overloads the capslock key to function as both escape (when tapped) and control (when held)
          capslock = "overload(control, esc)";
          esc = "capslock";
        };
      };
    };
  };
}
