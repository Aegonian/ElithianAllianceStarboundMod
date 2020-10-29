require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.messageRadius = config.getParameter("messageRadius")
  self.entityTypes = config.getParameter("entityTypes")
  self.ignoreSourceEntity = config.getParameter("ignoreSourceEntity", false)
  self.message = config.getParameter("message")
  
  self.delayMessagesByIndex = config.getParameter("delayMessagesByIndex", false)
  self.delayMessageByRange = config.getParameter("delayMessageByRange", false)
  self.delayTime = config.getParameter("delayTime")
end

function update(dt)
  local targets = {}
  
  if self.ignoreSourceEntity then
	targets = world.entityQuery(mcontroller.position(), self.messageRadius, {
	  includedTypes = self.entityTypes,
	  order = "nearest"
	})
  else
	targets = world.entityQuery(mcontroller.position(), self.messageRadius, {
	  withoutEntityId = projectile.sourceEntity(),
	  includedTypes = self.entityTypes,
	  order = "nearest"
	})
  end
  
  -- If we want to delay messages by index, increment a delay value for each target and send it as an argument
  if self.delayMessagesByIndex then
	local delay = 0
	for _, target in ipairs(targets) do
	  world.sendEntityMessage(target, self.message, delay, projectile.sourceEntity())
	  delay = delay + self.delayTime
	end
	
  -- If we want to delay messages by distance, calculate distance and send it as an argument
  elseif self.delayMessageByRange then
	for _, target in ipairs(targets) do
	  local delay = world.magnitude(world.entityPosition(projectile.sourceEntity()), world.entityPosition(target)) * self.delayTime
	  world.sendEntityMessage(target, self.message, delay, projectile.sourceEntity())
	end
	
  -- Otherwise, just send the message without any arguments
  else
	for _, target in ipairs(targets) do
	  world.sendEntityMessage(target, self.message, 0, projectile.sourceEntity())
	end
  end
  
  projectile.die()
end
