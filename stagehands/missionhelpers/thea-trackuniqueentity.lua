require "/scripts/stagehandutil.lua"

function init()
  self.isTrackingEntity = false
  
  --sb.logInfo("THEA MISSIONS HELPER - Initializing unique entity tracker...")
end

function update(dt)
  if self.trackedEntity and world.entityExists(self.trackedEntity) and not self.isTrackingEntity then
	--sb.logInfo("THEA MISSIONS HELPER - Tracking entity with ID " .. tostring(self.trackedEntity))
	self.isTrackingEntity = true
  else
	self.trackedEntity = world.loadUniqueEntity(config.getParameter("uniqueEntityUid"))
  end
  
  if self.isTrackingEntity then
	if not world.entityExists(self.trackedEntity) then
	  local playerIds = world.players()
	  for _, playerId in pairs(playerIds) do
        world.sendEntityMessage(playerId, config.getParameter("entityMessageOnKill"))
		--sb.logInfo("THEA MISSIONS HELPER - Sent the following message to player ID " .. tostring(playerId) .. " : " .. config.getParameter("entityMessageOnKill"))
      end
	  
	  self.isTrackingEntity = false
	end
  end
end
