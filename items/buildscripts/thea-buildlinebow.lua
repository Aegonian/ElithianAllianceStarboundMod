require "/scripts/util.lua"
require "/scripts/versioningutils.lua"
require "/items/buildscripts/abilities.lua"

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

  -- select, load and merge abilities
  setupAbility(config, parameters, "alt")
  setupAbility(config, parameters, "primary")

  -- elemental type
  local elementalType = parameters.elementalType or config.elementalType or "physical"
  replacePatternInData(config, nil, "<elementalType>", elementalType)
  if config.altAbility and config.altAbility.elementalConfig then
    util.mergeTable(config.altAbility, config.altAbility.elementalConfig[elementalType])
  end

  -- calculate damage level multiplier
  config.damageLevelMultiplier = root.evalFunction("weaponDamageLevelMultiplier", configParameter("level", 1))

  -- populate tooltip fields
  if config.tooltipKind ~= "base" then
	config.tooltipFields = {}
    config.tooltipFields.levelLabel = util.round(configParameter("level", 1), 1)
	config.tooltipFields.subtitle = parameters.category
	config.tooltipFields.drawTimeLabel = config.primaryAbility.drawTime or 0
	config.tooltipFields.energyPerShotLabel = config.primaryAbility.energyPerShot or 0
	config.tooltipFields.energyPerSecondLabel = config.primaryAbility.holdEnergyUsage or 0
	config.tooltipFields.maxDamageLabel = config.primaryAbility.baseDamage * config.damageLevelMultiplier
	if elementalType ~= "physical" then
	  config.tooltipFields.damageKindImage = "/interface/elements/"..elementalType..".png"
	end
    if config.primaryAbility then
      config.tooltipFields.primaryAbilityTitleLabel = "Primary:"
      config.tooltipFields.primaryAbilityLabel = config.primaryAbility.name or "unknown"
    end
    if config.altAbility then
      config.tooltipFields.altAbilityTitleLabel = "Special:"
      config.tooltipFields.altAbilityLabel = config.altAbility.name or "unknown"
    end
	--Custom manufacturer label
	config.tooltipFields.manufacturerLabel = configParameter("manufacturer") or "unknown"
  end

  -- set price
  config.price = (config.price or 0) * root.evalFunction("itemLevelPriceMultiplier", configParameter("level", 1))

  return config, parameters
end
