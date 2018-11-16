function init()
  effect.setParentDirectives(config.getParameter("directive", "fade=FF0000=0.15"))
  
  self.stealthMaxDuration = config.getParameter("stealthMaxDuration", 1.25)
  
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
  
  --world.debugText(nextStep, mcontroller.position(), "red")
  --world.debugText(effect.duration(), mcontroller.position(), "red")
  
  if world.getProperty("entityinvisible" .. tostring(entity.id())) and effect.duration() > self.stealthMaxDuration then
	local timeReduction = effect.duration() - self.stealthMaxDuration
	effect.modifyDuration(-timeReduction)
  end
  
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
  
  if effect.duration() < 0.3 and animator.animationState("target") == "idle" then
	animator.setAnimationState("target", "end")
  elseif animator.animationState("target") == "invisible" then
	animator.setAnimationState("target", "start")
  end
  
  self.canMultiplyDamage = true
end

function uninit()
  
end
