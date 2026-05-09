{
  pkgs,
  name,
  nodeTarget,
  description,
  attenuationLimit,
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
  luaScriptName = "noise_suppression-${name}-logic.lua";
  componentName = "custom.noise_suppression-${name}-logic";
  tunedSourceName = common.mkVirtualNodeName nodeTarget "tuned" tunedNodeName;
  loopbackSourceName = common.mkVirtualNodeName nodeTarget "loopback" loopbackNodeName;
  tunedPriorityFieldLua =
    if tunedPriority == null then "" else '',"priority.session": ${toString tunedPriority}'';
  loopbackPriorityFieldLua =
    if loopbackPriority == null then "" else '',"priority.session": ${toString loopbackPriority}'';
  hidePhysicalNodeField = common.mkHidePhysicalNodeField "Audio/Source/Internal" hidePhysicalNode;
  enforcePhysicalVolumeField = common.mkEnforcePhysicalVolumeField "source" enforcePhysicalVolume;
  tunedAttenuationLimit = toString attenuationLimit;
  descriptionVal = if description == null then "nil" else ''"${description}"'';
in
mkPackage {
  inherit pkgs luaScriptName;
  packageName = "noise-suppression-pack-${name}";
  registrationFileName = "10-noise-suppression-${name}.conf";
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
      log_prefix = ${builtins.toJSON "[audio:${name}:noise] "},
      override_desc = ${descriptionVal},
      node_target = ${builtins.toJSON nodeTarget},
      tuned_source_name = ${builtins.toJSON tunedSourceName},
      loopback_source_name = ${builtins.toJSON loopbackSourceName},
      tuned_attenuation_limit = ${tunedAttenuationLimit},
      tuned_priority_field = [=[${tunedPriorityFieldLua}]=],
      loopback_priority_field = [=[${loopbackPriorityFieldLua}]=],
      enforce_physical_volume = ${if enforcePhysicalVolume then "true" else "false"},
    }

  ''
  + builtins.readFile ./noise-suppression.lua;
  passthru.requiredLadspaPackages = [ pkgs.deepfilternet ];
}
