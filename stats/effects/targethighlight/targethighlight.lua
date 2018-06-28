function init()
  effect.setParentDirectives("fade=FF0000=0.15")
  self.queryDamageSince = 0
  
  script.setUpdateDelta(1)
  
  self.canMultiplyDamage = false --Disable damage amplification on the first frame to prevent damage amplification for damage received before the effect was active
end

function update(dt)
  --Listen for damage taken
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  world.debugText(nextStep, mcontroller.position(), "red")
  
  if self.canMultiplyDamage then
	for _, notification in ipairs(damageNotifications) do
	  if notification.healthLost > 1 and config.getParameter("damageAdditionPercentage", 0) > 0 then
		--sb.logInfo(sb.printJson(notification, 1))
	  
		local damageRequest = {}
		damageRequest.damageType = "IgnoresDef"
		damageRequest.damage = notification.damageDealt * 0.1
		damageRequest.damageSourceKind = notification.damageSourceKind
		damageRequest.sourceEntityId = notification.sourceEntityId
		status.applySelfDamageRequest(damageRequest)
	  end
	end
  end
  
  self.canMultiplyDamage = true
end

function uninit()
  
end
