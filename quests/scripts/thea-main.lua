--An expansion on the vanilla main quest script that overrides the buildConditions function, allowing for additional custom condition types to be configured

require "/quests/scripts/main.lua"
require('/quests/scripts/conditions/thea-monsterkills.lua')
require('/quests/scripts/conditions/thea-collections.lua')

function buildConditions()
  local conditions = {}
  local conditionConfig = config.getParameter("conditions", {})

  for _,config in pairs(conditionConfig) do
    local newCondition
    if config.type == "gatherItem" then
      newCondition = buildGatherItemCondition(config)
    elseif config.type == "gatherTag" then
      newCondition = buildGatherTagCondition(config)
    elseif config.type == "shipLevel" then
      newCondition = buildShipLevelCondition(config)
    elseif config.type == "scanObjects" then
      newCondition = buildScanObjectsCondition(config)
    elseif config.type == "killMonsters" then
      newCondition = buildMonsterKillCondition(config)
    elseif config.type == "completeCollection" then
      newCondition = buildCompleteCollectionCondition(config)
    end

    table.insert(conditions, newCondition)
  end

  return conditions
end