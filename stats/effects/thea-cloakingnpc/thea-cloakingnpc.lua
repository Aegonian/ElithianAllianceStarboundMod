require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/vec2.lua"

function init()
  animator.setParticleEmitterOffsetRegion("cloakedParticles", mcontroller.boundBox())
  animator.setParticleEmitterOffsetRegion("cloakedParticles2", mcontroller.boundBox())
  animator.setParticleEmitterOffsetRegion("cloakedParticles3", mcontroller.boundBox())
  animator.setParticleEmitterOffsetRegion("activate", mcontroller.boundBox())
  animator.setParticleEmitterOffsetRegion("deactivate", mcontroller.boundBox())
  
  self.targetDetected = false
  self.active = false
  self.cooldownTimer = config.getParameter("initialCooldownTime", 1)
  self.queryDamageSince = 0
  
  script.setUpdateDelta(1)
end

function update(dt)
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)

  --Listen for damage taken
  local damageNotificationsIncoming, nextStep = status.damageTakenSince(self.queryDamageSince)
  local damageNotificationsOutgoing, nextStep = status.inflictedDamageSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  for _, notification in ipairs(damageNotificationsIncoming) do
	if notification.healthLost > 1 and notification.sourceEntityId ~= notification.targetEntityId then
	  if self.active then
		deactivate(true)
	  elseif self.cooldownTimer < 0.25 then --Should keep the cloak from reactivating if we are taking continuous damage
		self.cooldownTimer = 0.25 
	  end
	end
  end
  
  for _, notification in ipairs(damageNotificationsOutgoing) do
	if notification.targetEntityId then
	  if notification.sourceEntityId ~= notification.targetEntityId and self.active then
		deactivate(false)
	  end
	end
  end
  
  --Look for creatures within our detect distance
  local targetIds = world.entityQuery(mcontroller.position(), config.getParameter("detectDistance", 10), {
	withoutEntityId = entity.id(),
	includedTypes = {"creature"}
  })
  
  --For every entity found, check if we can damage it and have line of sight with it
  --Ignore targets if they are invisible themselves
  for i,id in ipairs(targetIds) do
	if world.entityCanDamage(entity.id(), id) and not world.lineTileCollision(mcontroller.position(), world.entityPosition(id)) and not world.getProperty("entityinvisible" .. tostring(id)) then
	  self.targetDetected = true
	end
  end
  
  if self.targetDetected and not self.active and self.cooldownTimer == 0 then
	activate()
  end
  
  --world.debugText("Active = " .. sb.printJson(self.active, 1), vec2.add(mcontroller.position(), {0,1}), "yellow")
  --world.debugText("Target Detected = " .. sb.printJson(self.targetDetected, 1), vec2.add(mcontroller.position(), {0,2}), "yellow")
  --world.debugText("Cooldown Time = " .. sb.printJson(self.cooldownTimer, 1), vec2.add(mcontroller.position(), {0,3}), "yellow")
  world.debugText("Invisible Status = " .. sb.printJson(world.getProperty("entityinvisible" .. tostring(entity.id())), 1), vec2.add(mcontroller.position(), {0,1}), "blue")
end

function activate()
  animator.playSound("activate")
  animator.burstParticleEmitter("activate")
  
  animator.setParticleEmitterActive("cloakedParticles", true)
  animator.setParticleEmitterActive("cloakedParticles2", true)
  animator.setParticleEmitterActive("cloakedParticles3", true)

  local alpha = math.ceil(config.getParameter("alpha") * 255)
  local multiplyDirective = string.format("?multiply=ffffff%02x", alpha)
  local borderDirective = "?border=2;FFFFFF30;00000000"
  
  --local directive = multiplyDirective .. borderDirective
  local directive = multiplyDirective
  effect.setParentDirectives(directive)
  
  self.active = true
  world.setProperty("entityinvisible" .. tostring(entity.id()), true)
end

function deactivate(cloakBroken)
  animator.playSound("deactivate")
  animator.burstParticleEmitter("deactivate")
  
  animator.setParticleEmitterActive("cloakedParticles", false)
  animator.setParticleEmitterActive("cloakedParticles2", false)
  animator.setParticleEmitterActive("cloakedParticles3", false)

  effect.setParentDirectives()
  
  self.active = false
  world.setProperty("entityinvisible" .. tostring(entity.id()), nil)
  if cloakBroken then
	self.cooldownTimer = config.getParameter("cooldownTime", 5)
  else
	self.cooldownTimer = config.getParameter("reactivateTime", 5)
  end
end

function uninit()
  world.setProperty("entityinvisible" .. tostring(entity.id()), nil)
  effect.setParentDirectives()
end