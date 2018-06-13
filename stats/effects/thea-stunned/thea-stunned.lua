function init()
  animator.setParticleEmitterOffsetRegion("stars", mcontroller.boundBox())
  animator.setParticleEmitterActive("stars", true)
  
  self.allowBreakTimer = config.getParameter("minimumDuration") or 1
  self.minTriggerDamage = config.getParameter("minTriggerDamage") or 1
  self.soundIsPlaying = false

  script.setUpdateDelta(5)
  
  if status.isResource("stunned") then
    status.setResource("stunned", math.max(status.resource("stunned"), effect.duration()))
  end
end

function update(dt)
  --Prevent the target from moving
  mcontroller.controlModifiers({
	facingSuppressed = true,
	movementSuppressed = true
  })
  
  self.allowBreakTimer = math.max(0, self.allowBreakTimer - dt)
  
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  --If we have lasted for at least the minimum duration, taking damage will end the stun effect
  if self.allowBreakTimer == 0 then
    for _, notification in ipairs(damageNotifications) do
      if notification.healthLost > self.minTriggerDamage and notification.sourceEntityId ~= notification.targetEntityId then
		effect.expire()
        break
      end
    end
  end
  
  if not status.resourcePositive("health") then
	effect.expire()
  end
end

function onExpire()
  if status.isResource("stunned") then
	status.setResource("stunned", 0)
  end
end
