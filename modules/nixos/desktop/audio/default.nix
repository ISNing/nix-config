{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfgSpeaker = config.hardware.audio.speaker-tuning;
  cfgMic = config.hardware.audio.noise-suppression;

  mkSpeakerPack =
    name: opts:
    pkgs.callPackage ./config-packages/speaker-tuning.nix {
      inherit name;
      inherit (opts)
        nodeTarget
        description
        baseOffset
        referenceLevel
        ;
    };

  mkMicPack =
    name: opts:
    pkgs.callPackage ./config-packages/noise-suppression.nix {
      inherit name;
      inherit (opts) nodeTarget description attenuationLimit;
    };

in
{
  options.hardware.audio = {
    speaker-tuning = {
      enable = mkEnableOption "hardware-specific speaker frequency compensation";
      instances = mkOption {
        type = types.attrsOf (
          types.submodule (
            { name, ... }:
            {
              options = {
                enable = mkEnableOption "this instance";
                nodeTarget = mkOption {
                  type = types.str;
                  description = "The physical ALSA sink node name (e.g., alsa_output.pci-0000_00_1f.3-platform-skl_had_dsp_generic.HiFi__Speaker__sink).";
                };
                description = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Display name in sound settings. If null, auto-generated from hardware name.";
                };
                baseOffset = mkOption {
                  type = types.float;
                  description = ''
                    The calibration offset in decibels (dB). 
                    This value aligns the digital volume scale with the physical Sound Pressure Level (SPL).
                    It represents the difference between your measured output (e.g., at -14 LUFS) and the 
                    target listening level. Higher values result in more perceived 'fullness' at lower volumes.
                  '';
                };
                referenceLevel = mkOption {
                  type = types.int;
                  default = 83;
                  description = ''
                    The target reference listening level in dB SPL, typically following ISO 226 standards.
                    Default is 83 dB. This is the 'pivot point' where the frequency response is 
                    considered flat. As you lower your system volume below this point, the plugin 
                    dynamically boosts bass and treble to maintain perceived tonal balance.
                  '';
                };
              };
            }
          )
        );
        default = { };
      };
    };

    noise-suppression = {
      enable = mkEnableOption "hardware-level microphone noise suppression";
      instances = mkOption {
        type = types.attrsOf (
          types.submodule (
            { name, ... }:
            {
              options = {
                enable = mkEnableOption "this instance";
                nodeTarget = mkOption {
                  type = types.str;
                  description = "The physical ALSA source node name (e.g., alsa_input.pci-0000_00_1f.3-platform-skl_had_dsp_generic.HiFi__Mic1__source).";
                };
                description = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Display name in settings. If null, auto-generated from hardware name.";
                };
                attenuationLimit = mkOption {
                  type = types.int;
                  default = 100;
                  description = "The maximum amount of noise attenuation in dB. 100 is the maximum suppression.";
                };
              };
            }
          )
        );
        default = { };
      };
    };
  };

  config = mkMerge [
    {
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
      };
      # rtkit is optional but recommended
      security.rtkit.enable = true;
      # Disable pulseaudio, it conflicts with pipewire too.
      services.pulseaudio.enable = false;
    }

    (mkIf cfgSpeaker.enable {
      services.pipewire.configPackages = mapAttrsToList mkSpeakerPack (
        filterAttrs (n: v: v.enable) cfgSpeaker.instances
      );
      services.pipewire.wireplumber.configPackages = mapAttrsToList mkSpeakerPack (
        filterAttrs (n: v: v.enable) cfgSpeaker.instances
      );
    })

    (mkIf cfgMic.enable {
      services.pipewire.configPackages = mapAttrsToList mkMicPack (
        filterAttrs (n: v: v.enable) cfgMic.instances
      );
      services.pipewire.wireplumber.configPackages = mapAttrsToList mkMicPack (
        filterAttrs (n: v: v.enable) cfgMic.instances
      );
    })
  ];
}
