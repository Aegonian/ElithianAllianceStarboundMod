function init()
  animator.setParticleEmitterOffsetRegion("embers", mcontroller.boundBox())
  animator.setParticleEmitterActive("embers", true)
  effect.setParentDirectives(config.getParameter("directive"))
  
  --Check for damage taken in the init() step to ensure that damage taken before the status was applied won't get calculated for the damage increase
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep

  script.setUpdateDelta(1)
  
  self.canMultiplyDamage = false --Disable damage amplification on the first frame to prevent damage amplification for damage received before the effect was active
end

function update(dt)	
  --Listen for damage taken
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  --Multiply damage if damage multiplication is enabled
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
	  end
	end
  end
  
  self.canMultiplyDamage = true
end
