-- Native logic for Noise Cancellation.
-- Configuration is injected at top as local table `CFG`.

local LOG_PREFIX = CFG.log_prefix
Log.warning(LOG_PREFIX .. "initialized")

local runtime = {
  tuned_module = nil,
  loopback_module = nil,
  enforcing_physical_volume = false,
  target_om = nil,
}

local function parse_props_param(pod)
  local parsed = pod:parse()
  if type(parsed) ~= "table" then return nil end
  return parsed.properties
end

local function force_physical_source_volume(node)
  if runtime.enforcing_physical_volume then return end

  local need_update = true
  for p in node:iterate_params("Props") do
    local props = parse_props_param(p)
    if type(props) == "table" then
      local volume = props.volume
      local mute = props.mute
      if type(volume) == "number" and math.abs(volume - 1.0) < 0.0001 and mute == false then
        need_update = false
      end
    end
    break
  end

  if not need_update then return end

  runtime.enforcing_physical_volume = true
  local param = Pod.Object {
    "Spa:Pod:Object:Param:Props", "Props",
    volume = 1.0,
    mute = false,
  }
  node:set_param("Props", param)
  runtime.enforcing_physical_volume = false
end

local function unload_modules()
  if runtime.tuned_module then
    Log.warning(LOG_PREFIX .. "physical target removed; unloading tuned source")
    runtime.tuned_module = nil
  end
  if runtime.loopback_module then
    Log.warning(LOG_PREFIX .. "physical target removed; unloading loopback source")
    runtime.loopback_module = nil
  end
end

local function load_modules(node)
  if runtime.tuned_module and runtime.loopback_module then return end

  local raw_desc = node.properties["node.description"] or "Unknown Source"
  local tuned_desc = CFG.override_desc or (raw_desc .. " w/ Noise Suppression")
  local loopback_desc = raw_desc

  Log.warning(LOG_PREFIX .. "target detected; loading tuned source as: " .. tuned_desc)
  Log.warning(LOG_PREFIX .. "target detected; loading loopback source as: " .. loopback_desc)

  local tuned_args = [[
    {
      "node.description": "]] .. tuned_desc .. [[",
      "media.name": "]] .. tuned_desc .. [[",
      "audio.rate": 48000,
      "filter.graph": {
        "nodes": [
          {
            "type": "ladspa",
            "name": "DeepFilter Stereo",
            "plugin": "libdeep_filter_ladspa",
            "label": "deep_filter_stereo",
            "control": { "Attenuation Limit (dB)": ]] .. tostring(CFG.tuned_attenuation_limit) .. [[ }
          }
        ]
      },
      "audio.channels": 2,
      "audio.position": [ "FL", "FR" ],
      "capture.props": {
        "node.name": "]] .. CFG.tuned_source_name .. [[_input",
        "node.target": "]] .. CFG.node_target .. [[",
        "node.passive": true
      },
      "playback.props": {
        "node.name": "]] .. CFG.tuned_source_name .. [[",
        "media.class": "Audio/Source"
      ]] .. CFG.tuned_priority_field .. [[
      }
    }
  ]]

  runtime.tuned_module = LocalModule("libpipewire-module-filter-chain", tuned_args, {})

  local loopback_args = [[
    {
      "node.description": "]] .. loopback_desc .. [[",
      "media.name": "]] .. loopback_desc .. [[",
      "audio.channels": 2,
      "audio.position": [ "FL", "FR" ],
      "capture.props": {
        "node.name": "]] .. CFG.loopback_source_name .. [[_input",
        "node.target": "]] .. CFG.node_target .. [[",
        "node.passive": true
      },
      "playback.props": {
        "node.name": "]] .. CFG.loopback_source_name .. [[",
        "media.class": "Audio/Source"
      ]] .. CFG.loopback_priority_field .. [[
      }
    }
  ]]

  runtime.loopback_module = LocalModule("libpipewire-module-loopback", loopback_args, {})
end

runtime.target_om = ObjectManager {
  Interest {
    type = "node",
    Constraint { "node.name", "equals", CFG.node_target },
  }
}

runtime.target_om:connect("object-added", function(_, node)
  Log.warning(LOG_PREFIX .. "target_om object-added: " .. (node.properties["node.name"] or "<unknown>"))
  if CFG.enforce_physical_volume then
    force_physical_source_volume(node)
  end
  load_modules(node)

  if CFG.enforce_physical_volume then
    node:connect("params-changed", function(n, param_name)
      if param_name ~= "Props" then return end
      force_physical_source_volume(n)
    end)
  end
end)

runtime.target_om:connect("object-removed", function(_, _)
  unload_modules()
end)

runtime.target_om:activate()
