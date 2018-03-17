function broadcastTheft(playerId, licenseItem, broadcastRange)
  local allowTheft = world.entityHasCountOfItem(playerId, licenseItem) > 0 or licenseItem == nil
  
  if not allowTheft then
	local notification = {
      type = "objectBroken",
      sourceId = entity.id(),
      targetPosition = entity.position(),
      targetId = playerId
    }
	local range = broadcastRange or 25
    local npcs = world.entityQuery(entity.position(), range, { includedTypes = {"npc"} })
    for _,npcId in pairs(npcs) do
      if world.entityDamageTeam(npcId).team == 1 then
        world.sendEntityMessage(npcId, "notify", notification)
      end
    end
  end
end
