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
      inherit (opts) splAtZeroDbVolume;
      inherit (opts)
        nodeTarget
        description
        standard
        mode
        fftSize
        iirQuality
        hardClip
        hardClipRange
        tunedPriority
        loopbackPriority
        hidePhysicalNode
        enforcePhysicalVolume
        ;
    };

  mkMicPack =
    name: opts:
    pkgs.callPackage ./config-packages/noise-suppression.nix {
      inherit name;
      inherit (opts)
        nodeTarget
        description
        attenuationLimit
        tunedPriority
        loopbackPriority
        hidePhysicalNode
        enforcePhysicalVolume
        ;
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
                splAtZeroDbVolume = mkOption {
                  type = types.float;
                  description = "Measured dB SPL at listening position when playing -14 LUFS pink noise with plugin volume at 0.0 dB; used to compute post-EQ output gain (83 - splAtZeroDbVolume).";
                };
                standard = mkOption {
                  type = types.enum [
                    "Flat"
                    "ISO226-2003"
                    "Fletcher-Munson"
                    "Robinson-Dadson"
                    "ISO226-2023"
                  ];
                  default = "ISO226-2023";
                };
                mode = mkOption {
                  type = types.enum [
                    "FFT"
                    "IIR"
                  ];
                  default = "FFT";
                };
                fftSize = mkOption {
                  type = types.enum [
                    256
                    512
                    1024
                    2048
                    4096
                    8192
                    16384
                  ];
                  default = 4096;
                };
                iirQuality = mkOption {
                  type = types.enum [
                    "Fastest"
                    "Low"
                    "Normal"
                    "High"
                    "Best"
                  ];
                  default = "Normal";
                };
                hardClip = mkOption {
                  type = types.bool;
                  default = false;
                };
                hardClipRange = mkOption {
                  type = types.float;
                  default = 6.0;
                  description = "Hard-clipping range in dB (0.0 to 24.0). Higher means softer clipping knee.";
                };
                tunedPriority = mkOption {
                  type = types.nullOr types.int;
                  default = null;
                  description = "Optional priority.session for tuned virtual sink. null uses PipeWire/WirePlumber default.";
                };
                loopbackPriority = mkOption {
                  type = types.nullOr types.int;
                  default = null;
                  description = "Optional priority.session for loopback virtual sink. null uses PipeWire/WirePlumber default.";
                };
                hidePhysicalNode = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Hide physical sink node by setting node.hidden and internal media.class.";
                };
                enforcePhysicalVolume = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Force physical sink volume to 100% and keep it there.";
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
                tunedPriority = mkOption {
                  type = types.nullOr types.int;
                  default = null;
                  description = "Optional priority.session for tuned virtual source. null uses PipeWire/WirePlumber default.";
                };
                loopbackPriority = mkOption {
                  type = types.nullOr types.int;
                  default = null;
                  description = "Optional priority.session for loopback virtual source. null uses PipeWire/WirePlumber default.";
                };
                hidePhysicalNode = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Hide physical source node by setting node.hidden and internal media.class.";
                };
                enforcePhysicalVolume = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Force physical source volume to 100% and keep it there.";
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

      # systemd default LimitMEMLOCK=8M / LimitRTPRIO=0 causes
      # sched_setscheduler() failure in libpipewire-module-rt
      systemd.user.services.pipewire.serviceConfig = {
        LimitMEMLOCK = "infinity";
        LimitRTPRIO = "99";
        LimitNICE = "-20";
      };
      systemd.user.services.pipewire-pulse.serviceConfig = {
        LimitMEMLOCK = "infinity";
        LimitRTPRIO = "99";
        LimitNICE = "-20";
      };
      systemd.user.services.wireplumber.serviceConfig = {
        LimitMEMLOCK = "infinity";
        LimitRTPRIO = "99";
        LimitNICE = "-20";
      };
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
