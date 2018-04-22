require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  message.setHandler("spawnCompanion", spawnCompanion)
  object.setInteractive(true)
end

function update(dt)
  
end

function spawnCompanion(_, _, crewmemberType)
  local uniqueId = sb.makeUuid()
  local parameters = {
	  scriptConfig = {
	  uniqueId = uniqueId
	  }
	}
  local entityType = "crewmemberalliance"
  if crewmemberType == "combat" then
	entityType = "crewmemberalliancecombat"
  elseif crewmemberType == "medic" then
	entityType = "crewmemberalliancemedic"
  elseif crewmemberType == "engineer" then
	entityType = "crewmemberallianceengineer"
  elseif crewmemberType == "mechanic" then
	entityType = "crewmemberalliancemechanic"
  elseif crewmemberType == "janitor" then
	entityType = "crewmemberalliancejanitor"
  elseif crewmemberType == "tailor" then
	entityType = "crewmemberalliancetailor"
  end
  local entitySpecies = util.randomFromList(config.getParameter("crewmemberSpecies", {"aegi"}))
  local entityId = world.spawnNpc(vec2.add(entity.position(), config.getParameter("spawnOffset", {0,0})), entitySpecies, entityType, world.threatLevel(), nil, parameters)
  world.callScriptedEntity(entityId, "status.addEphemeralEffect", "beamin")
end
