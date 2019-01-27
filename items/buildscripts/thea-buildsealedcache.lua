require "/scripts/util.lua"
require "/scripts/versioningutils.lua"

function build(directory, config, parameters, level, seed)
  local configParameter = function(keyName, defaultValue)
    if parameters[keyName] ~= nil then
      return parameters[keyName]
    elseif config[keyName] ~= nil then
      return config[keyName]
    else
      return defaultValue
    end
  end

  if level and not configParameter("fixedLevel", true) then
    parameters.level = level
  end
  
  config.tooltipFields = config.tooltipFields or {}
  config.tooltipFields.levelLabel = util.round(configParameter("level", 1), 1)
  
  return config, parameters
end
