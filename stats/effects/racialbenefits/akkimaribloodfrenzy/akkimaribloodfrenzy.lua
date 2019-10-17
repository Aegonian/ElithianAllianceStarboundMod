require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/vec2.lua"

function init()
  --Loading config values
  self.maxPowerModifier = config.getParameter("maxPowerModifier", 1.5)
  self.maxSpeedModifier = config.getParameter("maxSpeedModifier", 1.5)
  self.maxAirJumpModifier = config.getParameter("maxAirJumpModifier", 1.5)
  self.maxParticleEmissionRate = config.getParameter("maxParticleEmissionRate", 10)
  self.killsForMaxEffect = config.getParameter("killsForMaxEffect", 1)
  self.frenzyDuration = config.getParameter("frenzyDuration", 1)
  
  --Setting modifiers
  self.statModifierGroup = effect.addStatModifierGroup({
	{stat = "powerMultiplier", effectiveMultiplier = 1.0}
  })
  
  --Animation effects
  animator.setParticleEmitterOffsetRegion("embers", mcontroller.boundBox())
  animator.setParticleEmitterOffsetRegion("initialBurst", mcontroller.boundBox())
  
  --General values
  self.durationLeft = 0
  self.killCount = 0
end


function update(dt)
  if entity.entityType() == "player" then
	local damageNotifications, nextStep = status.inflictedDamageSince(self.queryDamageSince)
	self.queryDamageSince = nextStep
  
	for _, notification in ipairs(damageNotifications) do
	  if notification.targetEntityId then
		if notification.hitType == "Kill" and world.entityType(notification.targetEntityId) == ("monster" or "npc") then
		  animator.burstParticleEmitter("initialBurst")
		  self.durationLeft = self.frenzyDuration
		  self.killCount = math.min(self.killsForMaxEffect, self.killCount + 1)
		end
	  end
	end
	
	if not self.playerCompanionsPromise then
	  self.playerCompanionsPromise = world.sendEntityMessage(entity.id(), "theaRequestCompanions")
	  if self.playerCompanionsPromise then
		if self.playerCompanionsPromise:finished() then
		  local messageResult = self.playerCompanionsPromise:result()
		  if messageResult then
			sb.logInfo(sb.printJson(messageResult, 1))
			
			for _, playerCompanion in ipairs(messageResult) do
			  sb.logInfo(playerCompanion.config.species)
			end
		  else
			self.playerCompanionsPromise = nil
		  end
		end
	  end
	end
	
	self.durationLeft = math.max(0, self.durationLeft - dt)
	if self.durationLeft > 0 and self.killCount > 0 then
	  --Calculate modifiers and animation parameters
	  local killCountFactor = self.killCount / self.killsForMaxEffect
	  local currentPowerModifier = ((self.maxPowerModifier - 1) * killCountFactor) + 1
	  local currentSpeedModifier = ((self.maxSpeedModifier - 1) * killCountFactor) + 1
	  local currentAirJumpModifier = ((self.maxAirJumpModifier - 1) * killCountFactor) + 1
	  local currentParticleEmissionRate = self.maxParticleEmissionRate * killCountFactor
	  
	  --world.debugText("Power Modifier: " .. currentPowerModifier, vec2.add(mcontroller.position(), {0,3}), "yellow")
	  --world.debugText("Speed Modifier: " .. currentSpeedModifier, vec2.add(mcontroller.position(), {0,4}), "yellow")
	  --world.debugText("Emission Rate: " .. currentParticleEmissionRate, vec2.add(mcontroller.position(), {0,5}), "yellow")
	
	  --Modify player parameters
	  effect.setStatModifierGroup(self.statModifierGroup, {
		{stat = "powerMultiplier", effectiveMultiplier  = currentPowerModifier}
	  })
	  mcontroller.controlModifiers({
		speedModifier = currentSpeedModifier,
		airJumpModifier = currentAirJumpModifier
	  })
	
	  --Modify animation and directives
	  animator.setParticleEmitterEmissionRate("embers", currentParticleEmissionRate)
	  animator.setParticleEmitterActive("embers", true)
	else
	  self.killCount = 0
	  animator.setParticleEmitterActive("embers", false)
	
	  effect.setStatModifierGroup(self.statModifierGroup, {
		{stat = "powerMultiplier", effectiveMultiplier  = 1.0}
	  })
	end
  end
  
  --world.debugText("Duration: " .. self.durationLeft, vec2.add(mcontroller.position(), {0,1}), "yellow")
  --world.debugText("Kills: " .. self.killCount, vec2.add(mcontroller.position(), {0,2}), "yellow")
  
  sb.setLogMap("THEA - Active racial benefit", "BLOOD FRENZY")
end

function uninit()
  effect.removeStatModifierGroup(self.statModifierGroup)
end
