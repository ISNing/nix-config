{
  pkgs,
  name,
  nodeTarget,
  description,
  attenuationLimit,
}:

let
  luaScriptName = "df-${name}-logic.lua";
  componentName = "custom.df-${name}-logic";
  sourceName = "deepfilter_${name}";
  descriptionVal = if description == null then "nil" else ''"${description}"'';
in
pkgs.symlinkJoin {
  name = "deepfilter-pack-${name}";
  paths = [
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/10-df-${name}.conf" ''
      wireplumber.components = [
        {
          name = ${luaScriptName}
          type = script/lua
          provides = ${componentName}
        }
      ]
      wireplumber.profiles.main = { "${componentName}" = required }
    '')

    (pkgs.writeTextDir "share/wireplumber/scripts/${luaScriptName}" ''
      -- Native logic for DeepFilter Noise Cancellation
      -- Dynamically attaches to [${nodeTarget}] when connected
      local OVERRIDE_DESC = ${descriptionVal}
      local filter_module = nil

      local target_om = ObjectManager {
        Interest {
          type = "node",
          Constraint { "node.name", "=", "${nodeTarget}" }
        }
      }

      target_om:connect("object-added", function(om, node)
        local raw_desc = node.properties["node.description"] or "Unknown Microphone"
        local final_desc = OVERRIDE_DESC or (raw_desc .. " (Cleaned)")

        log.info("Mic target [${nodeTarget}] detected. Loading DeepFilter as: " .. final_desc)
        
        -- audio.rate is fixed at 48000Hz as required by the DeepFilterNet model
        local args = [[
          {
            "node.description": "]] .. final_desc .. [[",
            "media.name": "]] .. final_desc .. [[",
            "audio.rate": 48000,
            "filter.graph": {
              "nodes": [
                {
                  "type": "ladspa",
                  "name": "DeepFilter Stereo",
                  "plugin": "libdeep_filter_ladspa",
                  "label": "deep_filter_stereo",
                  "control": { "Attenuation Limit (dB)": ${toString attenuationLimit} }
                }
              ]
            },
            "audio.channels": 2,
            "audio.position": [ "FL", "FR" ],
            "capture.props": {
              "node.name": "${sourceName}_input",
              "node.target": "${nodeTarget}",
              "node.passive": true
            },
            "playback.props": {
              "node.name": "${sourceName}",
              "media.class": "Audio/Source",
              "priority.session": 3000
            }
          }
        ]]
        filter_module = LocalModule("libpipewire-module-filter-chain", args, {})
      end)

      target_om:connect("object-removed", function(om, node)
        if filter_module then
          log.info("Mic [${nodeTarget}] disconnected. Unloading DeepFilter...")
          filter_module:destroy()
          filter_module = nil
        end
      end)

      target_om:activate()
    '')
  ];
  passthru.requiredLadspaPackages = [ pkgs.deepfilternet ];
}
