function init()
  animator.setParticleEmitterOffsetRegion("icetrail", mcontroller.boundBox())
  animator.setParticleEmitterActive("icetrail", true)
  effect.setParentDirectives("fade=00BBFF=0.85?border=2;00BBFF80;00000000")
  
  --Check for damage taken in the init() step to ensure that damage taken before the status was applied won't get calculated for the damage increase
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  self.totalDamageTaken = 0

  script.setUpdateDelta(1)
  
  if status.isResource("stunned") then
    status.setResource("stunned", math.max(status.resource("stunned"), effect.duration()))
  end
  animator.playSound("freezeSound")
  
  --Freeze the target's animation
  animator.setAnimationRate(0)
  
  self.canMultiplyDamage = false --Disable damage amplification on the first frame to prevent damage amplification for damage received before the effect was active
end

function update(dt)	
  --Listen for damage taken
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  --Prevent the freezing status effect from applying while this effect is active
  status.removeEphemeralEffect("frostlaserfreezing")
  status.removeEphemeralEffect("frostlaserfreezingslow")
  
  --Prevent the target from moving
  mcontroller.controlModifiers({
	facingSuppressed = true,
	movementSuppressed = true
  })
  
  if self.canMultiplyDamage then
	for _, notification in ipairs(damageNotifications) do
	  if notification.healthLost > 1 and config.getParameter("damageAdditionPercentage", 0) > 0 then
		--sb.logInfo(sb.printJson(notification, 1))
	  
		local damageRequest = {}
		damageRequest.damageType = "IgnoresDef"
		damageRequest.damage = notification.damageDealt * config.getParameter("damageAdditionPercentage", 0)
		damageRequest.damageSourceKind = notification.damageSourceKind
		damageRequest.sourceEntityId = notification.sourceEntityId
		status.applySelfDamageRequest(damageRequest)
		
		self.totalDamageTaken = self.totalDamageTaken + notification.healthLost
	  end
	end
  end
  
  self.canMultiplyDamage = true
  world.debugText(self.totalDamageTaken, mcontroller.position(), "red")
  
  --Play the break animation and sound just before we break (won't work if called during onExpire...)
  if effect.duration() <= 0.25 and not self.hasBrokenFree then
	animator.burstParticleEmitter("break")
	animator.playSound("breakSound")
	self.hasBrokenFree = true
 end
  
  --If total damage taken exceeds max damage, then break
  if self.totalDamageTaken > config.getParameter("damageBeforeBreaking", 100) and not self.hasBrokenFree then
	animator.burstParticleEmitter("break")
	animator.playSound("breakSound")
	self.hasBrokenFree = true
	
	local durationreduction = effect.duration() - 0.25
	effect.modifyDuration(-durationreduction)
  end
  
  if not status.resourcePositive("health") then
	local durationreduction = effect.duration() - 0.25
	effect.modifyDuration(-durationreduction)
  end
end

function onExpire()
  animator.setAnimationRate(1)
end
