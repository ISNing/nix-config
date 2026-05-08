{
  mkRegistrationText =
    {
      luaScriptName,
      componentName,
      extraConfig ? "",
    }:
    ''
            wireplumber.components = [
              {
                name = "${luaScriptName}"
                type = "script/lua"
                provides = "${componentName}"
              }
            ]

            wireplumber.profiles = {
              main = {
                ${componentName} = "required"
              }
            }
      ${extraConfig}
    '';

  mkLuaForcePhysicalVolumeFunction =
    {
      functionName,
      runtimeVar ? "runtime",
    }:
    ''
      local function parse_props_param(pod)
        local parsed = pod:parse()
        if type(parsed) ~= "table" then return nil end
        return parsed.properties
      end

      local function ${functionName}(node)
        if ${runtimeVar}.enforcing_physical_volume then return end

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

        ${runtimeVar}.enforcing_physical_volume = true
        local param = Pod.Object {
          "Spa:Pod:Object:Param:Props", "Props",
          volume = 1.0,
          mute = false,
        }
        node:set_param("Props", param)
        ${runtimeVar}.enforcing_physical_volume = false
      end
    '';

  mkVirtualNodeName =
    nodeTarget: suffix: overrideName:
    if overrideName == null then "${nodeTarget}.${suffix}" else overrideName;

  mkPriorityField =
    priority:
    if priority == null then "" else ''\n              "priority.session": ${toString priority},'';

  mkHidePhysicalNodeField =
    mediaClass: hidePhysicalNode:
    if hidePhysicalNode then
      ''
        node.hidden = true
        media.class = "${mediaClass}"
      ''
    else
      "";

  mkEnforcePhysicalVolumeField =
    direction: enforcePhysicalVolume:
    if !enforcePhysicalVolume then
      ""
    else if direction == "sink" then
      ''
        device.routes.default-sink-volume = 1.0
      ''
    else
      ''
        device.routes.default-source-volume = 1.0
      '';
}
