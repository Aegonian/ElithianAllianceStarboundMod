require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/vec2.lua"

function init()
  animator.setParticleEmitterOffsetRegion("cloakedParticles", mcontroller.boundBox())
  animator.setParticleEmitterOffsetRegion("cloakedParticles2", mcontroller.boundBox())
  animator.setParticleEmitterOffsetRegion("activate", mcontroller.boundBox())
  animator.setParticleEmitterOffsetRegion("deactivate", mcontroller.boundBox())
  
  self.powerModifier = config.getParameter("cloakedPowerModifier", 0)
  
  self.activated = false
  self.deactivated = false
  --self.queryDamageSince = 0
  
  script.setUpdateDelta(1)
end

function update(dt)  
  --Listen for incoming and outgoing damage, and break the cloak if we give or receive damage
  local damageNotificationsIncoming, nextStep = status.damageTakenSince(self.queryDamageSince)
  local damageNotificationsOutgoing, nextStep = status.inflictedDamageSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  for _, notification in ipairs(damageNotificationsIncoming) do
	--if notification.healthLost > 1 and notification.sourceEntityId ~= notification.targetEntityId then
	if notification.healthLost > 1 then
	  if self.activated and not self.deactivated then
		deactivate()
	  end
	end
  end
  for _, notification in ipairs(damageNotificationsOutgoing) do
	if notification.targetEntityId then
	  if notification.sourceEntityId ~= notification.targetEntityId and self.activated and not self.deactivated then
		deactivate()
	  end
	end
  end
  
  --Activate the invisibility effect if we haven't activated yet
  if not self.activated then
	activate()
  end
  
  --Force the deactivation sequence to play before the effect expires
  if effect.duration() < 0.25 and not self.deactivated then
	deactivate()
  end
  
  --world.debugText("Invisible Status = " .. sb.printJson(world.getProperty("entityinvisible" .. tostring(entity.id())), 1), vec2.add(mcontroller.position(), {0,1}), "blue")
  --world.debugText(effect.duration(), vec2.add(mcontroller.position(), {0,1}), "blue")
end

function activate()
  animator.playSound("activate")
  animator.burstParticleEmitter("activate")
  
  animator.setParticleEmitterActive("cloakedParticles", true)
  animator.setParticleEmitterActive("cloakedParticles2", true)

  --local alpha = math.ceil(config.getParameter("alpha") * 255)
  --local multiplyDirective = string.format("?multiply=ffffff%02x", alpha)
  --local borderDirective = "?border=2;FFFFFF30;00000000"
  
  --local directive = multiplyDirective .. borderDirective
  local directive = config.getParameter("directive")
  effect.setParentDirectives(directive)
  
  world.setProperty("entityinvisible" .. tostring(entity.id()), true)
  self.activated = true
  
  effect.addStatModifierGroup({{stat = "powerMultiplier", effectiveMultiplier = self.powerModifier}})
end

function deactivate()
  animator.playSound("deactivate")
  animator.burstParticleEmitter("deactivate")
  
  animator.setParticleEmitterActive("cloakedParticles", false)
  animator.setParticleEmitterActive("cloakedParticles2", false)

  effect.setParentDirectives()
  
  world.setProperty("entityinvisible" .. tostring(entity.id()), nil)
  self.deactivated = true
  
  local durationreduction = effect.duration() - 0.25
  effect.modifyDuration(-durationreduction)
end

function uninit()
  effect.setParentDirectives()
  world.setProperty("entityinvisible" .. tostring(entity.id()), nil)
end