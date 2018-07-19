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
  local entitySpecies = util.randomFromList(config.getParameter("crewmemberSpecies", {"aegi"}))
  local entityType = "crewmemberalliance"
  if crewmemberType == "combat" then
	entityType = "crewmemberalliancecombat"
	if entitySpecies == "aegi" then
	  entityType = "crewmemberalliancecombat-aegi"
	end
  elseif crewmemberType == "medic" then
	entityType = "crewmemberalliancemedic"
	if entitySpecies == "aegi" then
	  entityType = "crewmemberalliancemedic-aegi"
	end
  elseif crewmemberType == "engineer" then
	entityType = "crewmemberallianceengineer"
	if entitySpecies == "aegi" then
	  entityType = "crewmemberallianceengineer-aegi"
	end
  elseif crewmemberType == "mechanic" then
	entityType = "crewmemberalliancemechanic"
	if entitySpecies == "aegi" then
	  entityType = "crewmemberalliancemechanic-aegi"
	end
  elseif crewmemberType == "janitor" then
	entityType = "crewmemberalliancejanitor"
	if entitySpecies == "aegi" then
	  entityType = "crewmemberalliancejanitor-aegi"
	end
  elseif crewmemberType == "tailor" then
	entityType = "crewmemberalliancetailor"
	if entitySpecies == "aegi" then
	  entityType = "crewmemberalliancetailor-aegi"
	end
  end
  local entityId = world.spawnNpc(vec2.add(entity.position(), config.getParameter("spawnOffset", {0,0})), entitySpecies, entityType, world.threatLevel(), nil, parameters)
  world.callScriptedEntity(entityId, "status.addEphemeralEffect", "beamin")
end
