function init()
  self.teleported = false
end

function update(dt)
  --If we have a configured sourceEntity, and haven't teleported yet, do so now
  if effect.sourceEntity() and world.entityExists(effect.sourceEntity()) and not self.teleported then
	local targetPosition = world.entityMouthPosition(effect.sourceEntity())
	
	world.sendEntityMessage(effect.sourceEntity(), "openDoor")
	mcontroller.setPosition(targetPosition)
	self.teleported = true
  end
  
  --If we have already been teleported, expire the effect
  if self.teleported then
	effect.expire()
  end
end

function uninit()
end