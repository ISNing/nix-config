-- Native logic for sink processing.
-- Configuration is injected at top as local table `CFG`.

local LOG_PREFIX = CFG.log_prefix
Log.warning(LOG_PREFIX .. "initialized")
Log.warning(LOG_PREFIX .. string.format("output gain configured: %.2f dB (linear=%.6f)", CFG.output_gain_db, CFG.output_gain_linear))

local runtime = {
  target_metadata = nil,
  eq_module = nil,
  direct_module = nil,
  enforcing_physical_volume = false,
  syncing_eq_volume = false,
  eq_capture_node = nil,
  metadata_om = nil,
  target_om = nil,
  eq_capture_om = nil,
  last_linear = nil,
  last_target_db = nil,
  last_should_mute = nil,
}

local EQ_DB_FLOOR = -83.0
local EPS = 0.000001
local function read_linear_from_props(props)
  if type(props) ~= "table" then return nil end

  local channel_volumes = props.channelVolumes
  if type(channel_volumes) == "table" and #channel_volumes > 0 then
    local sum = 0.0
    local count = 0
    for _, v in ipairs(channel_volumes) do
      if type(v) == "number" then
        sum = sum + v
        count = count + 1
      elseif type(v) == "table" and type(v[1]) == "number" then
        sum = sum + v[1]
        count = count + 1
      elseif type(v) == "table" and type(v.value) == "number" then
        sum = sum + v.value
        count = count + 1
      end
    end
    if count > 0 then
      return sum / count
    end
  end

  if type(props.volume) == "number" then
    return props.volume
  end

  return nil
end

local function format_channel_volumes(props)
  if type(props) ~= "table" then return "<no-props>" end
  local channel_volumes = props.channelVolumes
  if type(channel_volumes) ~= "table" then return "<no-channelVolumes>" end

  local out = {}
  for _, v in ipairs(channel_volumes) do
    if type(v) == "number" then
      out[#out + 1] = string.format("%.6f", v)
    elseif type(v) == "table" and type(v[1]) == "number" then
      out[#out + 1] = string.format("%.6f", v[1])
    elseif type(v) == "table" and type(v.value) == "number" then
      out[#out + 1] = string.format("%.6f", v.value)
    else
      out[#out + 1] = tostring(v)
    end
  end
  return "[" .. table.concat(out, ",") .. "]"
end

local function read_node_volume_from_props(props)
  if type(props) ~= "table" then return nil end
  if type(props.volume) == "number" then return props.volume end
  return nil
end

local function clamp_linear(x)
  if type(x) ~= "number" then return 0.0 end
  if x < 0.0 then return 0.0 end
  if x > 1.0 then return 1.0 end
  return x
end

local function apply_eq_volume_from_linear(linear)
  if not runtime.eq_capture_node then return end
  if runtime.syncing_eq_volume then return end

  local clamped = clamp_linear(linear)
  local db = EQ_DB_FLOOR
  if clamped > 0.0 then
    db = 20.0 * math.log(clamped, 10)
  end

  local should_mute = db <= EQ_DB_FLOOR
  local target_db = should_mute and EQ_DB_FLOOR or db

  if runtime.last_linear ~= nil and math.abs(clamped - runtime.last_linear) < EPS then
    if runtime.last_target_db ~= nil and math.abs(target_db - runtime.last_target_db) < EPS and runtime.last_should_mute == should_mute then
      return
    end
  end

  runtime.syncing_eq_volume = true
  local param = Pod.Object {
    "Spa:Pod:Object:Param:Props", "Props",
    mute = should_mute,
    params = Pod.Struct {
      CFG.eq_node_name .. ":volume", Pod.Float(target_db),
    },
  }
  runtime.eq_capture_node:set_param("Props", param)
  runtime.syncing_eq_volume = false

  runtime.last_linear = clamped
  runtime.last_target_db = target_db
  runtime.last_should_mute = should_mute

  Log.warning(LOG_PREFIX .. string.format("volume map linear=%.6f db=%.3f mute=%s", clamped, target_db, tostring(should_mute)))
end

local function parse_props_param(pod)
  local parsed = pod:parse()
  if type(parsed) ~= "table" then return nil end
  return parsed.properties
end

local function force_physical_sink_volume(node)
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
  if runtime.eq_module then
    Log.info(LOG_PREFIX .. "physical target removed; unloading EQ filter-chain")
    runtime.eq_module = nil
  end
  if runtime.direct_module then
    Log.info(LOG_PREFIX .. "physical target removed; unloading direct loopback")
    runtime.direct_module = nil
  end
  runtime.eq_capture_node = nil
  runtime.last_linear = nil
  runtime.last_target_db = nil
  runtime.last_should_mute = nil
end

local function load_modules(node)
  if runtime.eq_module and runtime.direct_module then return end

  local raw_desc = node.properties["node.description"] or "Unknown Sink"
  local eq_desc = CFG.override_desc or (raw_desc .. " w/ Tuning")
  local direct_desc = raw_desc

  Log.warning(LOG_PREFIX .. "target detected; loading EQ sink as: " .. eq_desc)
  Log.warning(LOG_PREFIX .. "target detected; loading loopback sink as: " .. direct_desc)

  local args = [[
    {
      "node.description": "]] .. eq_desc .. [[",
      "media.name": "]] .. eq_desc .. [[",
      "filter.graph": {
        "nodes": [
          {
            "type": "lv2",
            "name": "]] .. CFG.eq_node_name .. [[",
            "plugin": "http://lsp-plug.in/plugins/lv2/loud_comp_stereo",
            "label": "loud_comp_stereo",
            "control": {
              "volume": 0.0,
              "std": ]] .. CFG.std .. [[,
              "mode": ]] .. CFG.mode .. [[,
              "fft": ]] .. CFG.fft .. [[,
              "approx": ]] .. CFG.approx .. [[,
              "hclip": ]] .. CFG.hclip .. [[,
              "hcrange": ]] .. CFG.hcrange .. [[
            }
          },
          {
            "type": "builtin",
            "name": "output_gain_l",
            "label": "linear",
            "control": {
              "Mult": ]] .. tostring(CFG.output_gain_linear) .. [[,
              "Add": 0.0
            }
          },
          {
            "type": "builtin",
            "name": "output_gain_r",
            "label": "linear",
            "control": {
              "Mult": ]] .. tostring(CFG.output_gain_linear) .. [[,
              "Add": 0.0
            }
          },
          {
            "type": "builtin",
            "name": "vol_map",
            "label": "linear",
            "control": {
              "Mult": 1.0,
              "Add": 0.0
            }
          }
        ],
        "links": [
          { "output": "]] .. CFG.eq_node_name .. [[:out_l", "input": "output_gain_l:In" },
          { "output": "]] .. CFG.eq_node_name .. [[:out_r", "input": "output_gain_r:In" }
        ],
        "inputs": [ "]] .. CFG.eq_node_name .. [[:in_l", "]] .. CFG.eq_node_name .. [[:in_r" ],
        "outputs": [ "output_gain_l:Out", "output_gain_r:Out" ],
        "capture.volumes": [
          {
            "control": "vol_map:Mult",
            "min": 0.0,
            "max": 1.0,
            "scale": "linear"
          }
        ]
      },
      "capture.props": {
        "node.name": "]] .. CFG.eq_capture_node_name .. [[",
        "media.class": "Audio/Sink",
        "audio.channels": 2,
        "audio.position": [ "FL", "FR" ]
      },
      "playback.props": {
        "node.target": "]] .. CFG.node_target .. [[",
        "node.passive": true,
        "audio.channels": 2,
        "audio.position": [ "FL", "FR" ]
      ]] .. CFG.tuned_priority_field .. [[
      }
    }
  ]]

  runtime.eq_module = LocalModule("libpipewire-module-filter-chain", args, {})

  local direct_args = [[
    {
      "node.description": "]] .. direct_desc .. [[",
      "media.name": "]] .. direct_desc .. [[",
      "audio.channels": 2,
      "audio.position": [ "FL", "FR" ],
      "capture.props": {
        "node.name": "]] .. CFG.direct_capture_node_name .. [[",
        "media.class": "Audio/Sink",
        "audio.channels": 2,
        "audio.position": [ "FL", "FR" ]
      },
      "playback.props": {
        "node.target": "]] .. CFG.node_target .. [[",
        "node.passive": true,
        "audio.channels": 2,
        "audio.position": [ "FL", "FR" ]
      ]] .. CFG.loopback_priority_field .. [[
      }
    }
  ]]

  runtime.direct_module = LocalModule("libpipewire-module-loopback", direct_args, {})
end

local function set_default_sink()
  if runtime.target_metadata then
    runtime.target_metadata:set(0, "default.audio.sink", "Spa:String:JSON", "{\"name\":\"" .. CFG.direct_capture_node_name .. "\"}")
  end
end

runtime.metadata_om = ObjectManager {
  Interest {
    type = "metadata",
    Constraint { "metadata.name", "equals", "settings" }
  }
}

runtime.target_om = ObjectManager {
  Interest {
    type = "node",
    Constraint { "node.name", "equals", CFG.node_target },
  }
}

runtime.metadata_om:connect("object-added", function(_, metadata)
  runtime.target_metadata = metadata
  set_default_sink()
end)

runtime.metadata_om:connect("object-removed", function(_, metadata)
  if runtime.target_metadata == metadata then
    runtime.target_metadata = nil
  end
end)

runtime.target_om:connect("object-added", function(_, node)
  Log.warning(LOG_PREFIX .. "target_om object-added: " .. (node.properties["node.name"] or "<unknown>"))
  set_default_sink()
  if CFG.enforce_physical_volume then
    force_physical_sink_volume(node)
  end
  load_modules(node)

  if CFG.enforce_physical_volume then
    node:connect("params-changed", function(n, param_name)
      if param_name ~= "Props" then return end
      force_physical_sink_volume(n)
    end)
  end
end)

runtime.target_om:connect("object-removed", function(_, _)
  unload_modules()
end)

runtime.target_om:activate()
runtime.metadata_om:activate()

runtime.eq_capture_om = ObjectManager {
  Interest {
    type = "node",
    Constraint { "node.name", "equals", CFG.eq_capture_node_name },
  }
}

runtime.eq_capture_om:connect("object-added", function(_, node)
  runtime.eq_capture_node = node
  Log.warning(LOG_PREFIX .. "eq capture node detected: " .. (node.properties["node.name"] or "<unknown>"))

  local initial_linear = 1.0
  for p in node:iterate_params("Props") do
    local props = parse_props_param(p)
    local mapped = read_linear_from_props(props)
    if type(mapped) == "number" then
      initial_linear = mapped
    end
    break
  end
  apply_eq_volume_from_linear(initial_linear)

  node:connect("params-changed", function(n, param_name)
    if param_name ~= "Props" then return end
    if runtime.syncing_eq_volume then return end

    local linear = nil
    local node_volume = nil
    for p in n:iterate_params("Props") do
      local props = parse_props_param(p)
      local mapped = read_linear_from_props(props)
      if type(mapped) == "number" then
        linear = mapped
      end
      local vol = read_node_volume_from_props(props)
      if type(vol) == "number" then
        node_volume = vol
      end
      Log.warning(LOG_PREFIX .. "eq capture raw channelVolumes=" .. format_channel_volumes(props))
      break
    end

    if linear ~= nil then
      apply_eq_volume_from_linear(linear)
    else
      if node_volume ~= nil then
        Log.warning(LOG_PREFIX .. string.format("channelVolumes read failed; node.volume=%.6f", node_volume))
      else
        Log.warning(LOG_PREFIX .. "channelVolumes read failed; node.volume=<nil>")
      end
    end
  end)
end)

runtime.eq_capture_om:connect("object-removed", function(_, node)
  if runtime.eq_capture_node == node then
    runtime.eq_capture_node = nil
  end
end)

runtime.eq_capture_om:activate()
