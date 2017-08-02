function init()
  animator.setParticleEmitterOffsetRegion("sparks", mcontroller.boundBox())
  animator.setParticleEmitterActive("sparks", true)
  effect.setParentDirectives("fade=7733AA=0.25")
  
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
  
  if not self.soundIsPlaying then
	animator.playSound("stunLoop", -1)
	self.soundIsPlaying = true
  end
  
  self.allowBreakTimer = math.max(0, self.allowBreakTimer - dt)
  
  --If we have lasted for at least the minimum duration, taking damage will end the stun effect
  if self.allowBreakTimer == 0 then
    local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
    self.queryDamageSince = nextStep
    for _, notification in ipairs(damageNotifications) do
      if notification.healthLost > self.minTriggerDamage and notification.sourceEntityId ~= notification.targetEntityId then
		effect.expire()
        break
      end
    end
  end
end

function onExpire()
  if status.isResource("stunned") then
	status.setResource("stunned", 0)
  end
end
