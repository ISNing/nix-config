{ pkgs, ... }:
{
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    pulseaudio # provides `pactl`, which is required by some apps(e.g. sonic-pi)
    overskride
  ];

  #============================= Audio(PipeWire) =======================

  # PipeWire is a new low-level multimedia framework.
  # It aims to offer capture and playback for both audio and video with minimal latency.
  # It support for PulseAudio-, JACK-, ALSA- and GStreamer-based applications.
  # PipeWire has a great bluetooth support, it can be a good alternative to PulseAudio.
  #     https://nixos.wiki/wiki/PipeWire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    jack.enable = true;
    wireplumber.enable = true;

    configPackages = [
      (
        (pkgs.writeTextDir "share/pipewire/pipewire.conf.d/99-deepfilter-stereo.conf" ''
          context.modules = [
            {
              name = libpipewire-module-filter-chain
              args = {
                node.description = "DeepFilter Noise Canceling Source (Stereo)"
                media.name = "DeepFilter Noise Canceling Source (Stereo)"
                filter.graph = {
                  nodes = [
                    {
                      type = ladspa
                      name = "DeepFilter Stereo"
                      plugin = libdeep_filter_ladspa
                      label = deep_filter_stereo
                      control = {
                        "Attenuation Limit (dB)" = 100
                      }
                    }
                  ]
                }
                audio.rate = 48000
                audio.channels = 2
                audio.position = [ FL FR ]
                capture.props = {
                  node.passive = true
                }
                playback.props = {
                  media.class = "Audio/Source"
                  priority.session = 3000
                  priority.driver = 3000
                }
              }
            }
          ]
        '')
        // {
          passthru.requiredLadspaPackages = [ pkgs.deepfilternet ];
        }
      )
    ];
  };
  # rtkit is optional but recommended
  security.rtkit.enable = true;
  # Disable pulseaudio, it conflicts with pipewire too.
  services.pulseaudio.enable = false;

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
