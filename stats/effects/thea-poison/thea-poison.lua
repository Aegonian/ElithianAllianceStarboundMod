function init()
  animator.setParticleEmitterOffsetRegion("drips", mcontroller.boundBox())
  animator.setParticleEmitterActive("drips", true)
  
  --Check for damage taken in the init() step to ensure that damage taken before the status was applied won't get calculated for the damage increase
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep

  script.setUpdateDelta(1)

  self.tickDamagePercentage = config.getParameter("tickDamagePercentage", 0.025)
  self.tickTime = 1.0
  self.tickTimer = self.tickTime
end

function update(dt)
  --Listen for damage taken
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  world.debugText(self.queryDamageSince, mcontroller.position(), "red")
  
  --Optionally multiply any non-poison damage taken by the target
  if config.getParameter("damageAdditionPercentage", 0) > 0 then
	for _, notification in ipairs(damageNotifications) do
	  if notification.healthLost > 1 then
		--sb.logInfo(sb.printJson(notification, 1))
		if notification.damageSourceKind ~= "poison" then
		  local damageRequest = {}
		  damageRequest.damageType = "IgnoresDef"
		  damageRequest.damage = notification.damageDealt * config.getParameter("damageAdditionPercentage", 0)
		  damageRequest.damageSourceKind = notification.damageSourceKind
		  damageRequest.sourceEntityId = notification.sourceEntityId
		  status.applySelfDamageRequest(damageRequest)
		end
	  end
	end
  end
  
  local targetDamage = math.floor(status.resourceMax("health") * self.tickDamagePercentage) + 1
  local actualDamage = math.min(targetDamage, config.getParameter("maxTickDamage", 10))
  
  self.tickTimer = self.tickTimer - dt
  if self.tickTimer <= 0 then
    self.tickTimer = self.tickTime
    status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = actualDamage,
        damageSourceKind = "poison",
        sourceEntityId = entity.id()
      })
  end

  effect.setParentDirectives(string.format("fade=00AA00=%.1f", self.tickTimer * 0.4))
end

function uninit()

end
