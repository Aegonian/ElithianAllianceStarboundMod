
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
  local entityType = "crewmemberdroden"
  if crewmemberType == "combat" then
	entityType = "crewmemberdrodenlegion"
  elseif crewmemberType == "medic" then
	entityType = "crewmemberdrodenmedic"
  elseif crewmemberType == "engineer" then
	entityType = "crewmemberdrodenengineer"
  elseif crewmemberType == "mechanic" then
	entityType = "crewmemberdrodenmechanic"
  end
  local entityId = world.spawnNpc(entity.position(), "droden", entityType, world.threatLevel(), nil, parameters)
  world.callScriptedEntity(entityId, "status.addEphemeralEffect", "beamin")
end
