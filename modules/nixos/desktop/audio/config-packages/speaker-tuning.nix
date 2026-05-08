{
  pkgs,
  name,
  nodeTarget,
  description,

  splAtZeroDbVolume,
  standard ? "ISO226-2023",
  mode ? "FFT",
  fftSize ? 4096,
  iirQuality ? "Normal",
  hardClip ? false,
  hardClipRange ? 6.0,
  loopbackNodeName ? null,
  tunedNodeName ? null,
  loopbackPriority ? null,
  tunedPriority ? null,
  hidePhysicalNode ? true,
  enforcePhysicalVolume ? true,
}:

let
  mkPackage = import ./template.nix;
  common = import ./common.nix;
  stdMap = {
    "Flat" = 0;
    "ISO226-2003" = 1;
    "Fletcher-Munson" = 2;
    "Robinson-Dadson" = 3;
    "ISO226-2023" = 4;
  };
  modeMap = {
    "FFT" = 0;
    "IIR" = 1;
  };
  fftMap = {
    "256" = 0;
    "512" = 1;
    "1024" = 2;
    "2048" = 3;
    "4096" = 4;
    "8192" = 5;
    "16384" = 6;
  };
  approxMap = {
    "Fastest" = 0;
    "Low" = 1;
    "Normal" = 2;
    "High" = 3;
    "Best" = 4;
  };

  eqNodeName = "${name}_loudness_eq";
  # Precomputed linear gain values for integer dB offsets to avoid runtime math pitfalls.
  outputGainLinearTable = {
    "-12" = 0.2511886432;
    "-11" = 0.2818382931;
    "-10" = 0.3162277660;
    "-9" = 0.3548133892;
    "-8" = 0.3981071706;
    "-7" = 0.4466835922;
    "-6" = 0.5011872336;
    "-5" = 0.5623413252;
    "-4" = 0.6309573445;
    "-3" = 0.7079457844;
    "-2" = 0.7943282347;
    "-1" = 0.8912509381;
    "0" = 1.0;
    "1" = 1.1220184543;
    "2" = 1.2589254118;
    "3" = 1.4125375446;
    "4" = 1.5848931925;
    "5" = 1.7782794100;
    "6" = 1.9952623150;
    "7" = 2.2387211386;
    "8" = 2.5118864315;
    "9" = 2.8183829313;
    "10" = 3.1622776602;
    "11" = 3.5481338923;
    "12" = 3.9810717055;
  };
  outputGainDb = 83 - splAtZeroDbVolume;
  outputGainDbInt = builtins.toString (builtins.floor (outputGainDb + 0.5));
  outputGainLinear = outputGainLinearTable.${outputGainDbInt} or 1.0;
  eqCaptureNodeName = common.mkVirtualNodeName nodeTarget "tuned" tunedNodeName;
  directCaptureNodeName = common.mkVirtualNodeName nodeTarget "loopback" loopbackNodeName;
  tunedPriorityFieldLua =
    if tunedPriority == null then "" else '',"priority.session": ${toString tunedPriority}'';
  loopbackPriorityFieldLua =
    if loopbackPriority == null then "" else '',"priority.session": ${toString loopbackPriority}'';
  hidePhysicalNodeField = common.mkHidePhysicalNodeField "Audio/Sink/Internal" hidePhysicalNode;
  enforcePhysicalVolumeField = common.mkEnforcePhysicalVolumeField "sink" enforcePhysicalVolume;
  luaScriptName = "${name}-logic.lua";
  componentName = "custom.${name}-logic";
  # Convert Nix null to Lua nil for the script logic
  descriptionVal = if description == null then "nil" else ''"${description}"'';
in
mkPackage {
  inherit pkgs luaScriptName;
  packageName = "sink-processing-pack-${name}";
  registrationFileName = "10-${name}-registration.conf";
  registrationText = common.mkRegistrationText {
    inherit luaScriptName componentName;
    extraConfig = ''

            monitor.alsa.rules = [
              {
                matches = [
                  {
                    node.name = "${nodeTarget}"
                  }
                ]
                actions = {
                  update-props = {
      ${hidePhysicalNodeField}
                    priority.session = 1
      ${enforcePhysicalVolumeField}
                  }
                }
              }
            ]
    '';
  };
  scriptBody = ''
    local CFG = {
      name = ${builtins.toJSON name},
      log_prefix = ${builtins.toJSON "[audio:${name}:speaker] "},
      override_desc = ${descriptionVal},
      output_gain_db = ${toString outputGainDb},
      output_gain_linear = ${toString outputGainLinear},
      eq_node_name = ${builtins.toJSON eqNodeName},
      eq_capture_node_name = ${builtins.toJSON eqCaptureNodeName},
      direct_capture_node_name = ${builtins.toJSON directCaptureNodeName},
      node_target = ${builtins.toJSON nodeTarget},
      std = ${toString stdMap.${standard}},
      mode = ${toString modeMap.${mode}},
      fft = ${toString fftMap.${toString fftSize}},
      approx = ${toString approxMap.${iirQuality}},
      hclip = ${if hardClip then "1" else "0"},
      hcrange = ${toString hardClipRange},
      tuned_priority_field = [=[${tunedPriorityFieldLua}]=],
      loopback_priority_field = [=[${loopbackPriorityFieldLua}]=],
      enforce_physical_volume = ${if enforcePhysicalVolume then "true" else "false"},
    }

  ''
  + builtins.readFile ./speaker-tuning.lua;
  passthru.requiredLv2Packages = [ pkgs.lsp-plugins ];
}
