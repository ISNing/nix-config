{
  pkgs,
  name,
  nodeTarget,
  description,
  baseOffset,
  referenceLevel,
}:

let
  eqNodeName = "${name}_loudness_eq";
  captureNodeName = "${name}_input";
  luaScriptName = "${name}-logic.lua";
  componentName = "custom.${name}-logic";
  # Convert Nix null to Lua nil for the script logic
  descriptionVal = if description == null then "nil" else ''"${description}"'';
in
pkgs.symlinkJoin {
  name = "speaker-processing-pack-${name}";
  paths = [
    # WirePlumber component registration
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/10-${name}-registration.conf" ''
      wireplumber.components = [
        {
          name = ${luaScriptName}
          type = script/lua
          provides = ${componentName}
        }
      ]
      wireplumber.profiles.main = {
        "${componentName}" = required
      }
    '')

    # Dynamic Lua Logic with Original Technical Comments
    (pkgs.writeTextDir "share/wireplumber/scripts/${luaScriptName}" ''
      -- Native logic for Sink [${name}]
      -- Handles dynamic rate negotiation and hardware hot-plugging
      log.info("Sink post-processing logic for [${name}] initialized")

      local BASE_OFFSET = ${toString baseOffset}
      local OVERRIDE_DESC = ${descriptionVal}
      local target_metadata = nil
      local filter_module = nil

      -- ObjectManager to monitor the target (nodeTarget)
      local target_om = ObjectManager {
        Interest {
          type = "node",
          Constraint { "node.name", "=", "${nodeTarget}" }
        }
      }

      -- ObjectManager to find the global 'settings' metadata table
      local metadata_om = ObjectManager {
        Interest {
          type = "metadata",
          Constraint { "metadata.name", "=", "settings" }
        }
      }

      metadata_om:connect("object-added", function(om, metadata)
        target_metadata = metadata
      end)

      -- Load Filter Chain when target is detected
      target_om:connect("object-added", function(om, node)
        -- Determine display name: Use override or fetch from physical node properties
        local raw_desc = node.properties["node.description"] or "Unknown Speaker"
        local final_desc = OVERRIDE_DESC or (raw_desc .. " w/ Tuning")

        log.info("Target detected: " .. raw_desc .. ". Loading adaptive-rate filter: " .. final_desc)
        
        -- audio.rate is omitted to allow PipeWire to negotiate rates automatically (Rate Following)
        local args = [[
          {
            "node.description": "]] .. final_desc .. [[",
            "media.name": "]] .. final_desc .. [[",
            "filter.graph": {
              "nodes": [
                {
                  "type": "lv2",
                  "name": "${eqNodeName}",
                  "plugin": "http://lsp-plug.in/plugins/lv2/loud_comp_stereo",
                  "label": "loud_comp_stereo",
                  "control": {
                    "Volume": ]] .. tostring(BASE_OFFSET) .. [[,
                    "Contour": 1,
                    "Reference Level": ${toString referenceLevel}
                  }
                }
              ]
            },
            "capture.props": {
              "node.name": "${captureNodeName}",
              "media.class": "Audio/Sink",
              "audio.channels": 2,
              "audio.position": [ "FL", "FR" ]
            },
            "playback.props": {
              "node.target": "${nodeTarget}",
              "node.passive": true,
              "audio.channels": 2,
              "audio.position": [ "FL", "FR" ],
              "priority.session": 3000
            }
          }
        ]]
        filter_module = LocalModule("libpipewire-module-filter-chain", args, {})
      end)

      -- Unload Filter Chain when hardware is removed
      target_om:connect("object-removed", function(om, node)
        if filter_module then
          log.info("Physical target [${nodeTarget}] removed. Unloading filter-chain...")
          filter_module:destroy()
          filter_module = nil
        end
      end)

      -- Monitor virtual sink for volume updates to sync with metadata
      local virtual_om = ObjectManager {
        Interest {
          type = "node",
          Constraint { "node.name", "=", "${captureNodeName}" }
        }
      }

      function onNodeParamsChanged(node, param_name)
        if param_name ~= "Props" or target_metadata == nil then return end
        local props = node:get_param("Props")
        if not props or not props.channelVolumes then return end

        local vol_linear = props.channelVolumes[1]
        local target_val = "-60.0"

        if vol_linear > 0.001 then
          local vol_db = 20 * math.log10(vol_linear)
          target_val = string.format("%.2f", vol_db + BASE_OFFSET)
        end

        target_metadata:set_value(0, "${eqNodeName}:Volume", target_val)
      end

      virtual_om:connect("object-params-changed", function(om, node, param_name)
        onNodeParamsChanged(node, param_name)
      end)

      target_om:activate()
      metadata_om:activate()
      virtual_om:activate()
    '')
  ];
  passthru.requiredLv2Packages = [ pkgs.lsp-plugins ];
}
