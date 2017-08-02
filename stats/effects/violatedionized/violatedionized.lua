function init()
  animator.setParticleEmitterOffsetRegion("flames", mcontroller.boundBox())
  animator.setParticleEmitterActive("flames", true)

  self.damageProjectileType = config.getParameter("damageProjectileType") or "armorthornburst"
  self.damageMultiplier = config.getParameter("damageMultiplier") or 0.01
  self.minDamage = config.getParameter("minDamage") or 1
  self.maxDamage = config.getParameter("maxDamage") or 10

  self.cooldown = config.getParameter("cooldown") or 5
  self.removeInWater = config.getParameter("removeInWater")
  self.minTriggerDamage = config.getParameter("minTriggerDamage") or 0
  self.expireAfterHits = config.getParameter("expireAfterHits") or 5
  
  self.hitsLeft = self.expireAfterHits

  self.cooldownTimer = self.cooldown

  if self.border then
    effect.setParentDirectives("border="..self.border)
  end

  self.queryDamageSince = 0
end

function update(dt)
  if self.cooldownTimer <= 0 then
    local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
    self.queryDamageSince = nextStep
    for _, notification in ipairs(damageNotifications) do
      if notification.healthLost > self.minTriggerDamage and notification.sourceEntityId ~= notification.targetEntityId then
        triggerExplosion(notification.healthLost * self.damageMultiplier)
        self.cooldownTimer = self.cooldown
        break
      end
    end
  end

  if self.removeInWater then
    if effect.duration() and world.liquidAt({mcontroller.xPosition(), mcontroller.yPosition() - 1}) then
      effect.expire()
    end
  end
  
  if self.hitsLeft <= 0 then
	effect.expire()
  end

  if self.cooldownTimer > 0 then
    self.cooldownTimer = self.cooldownTimer - dt
  end
end

function triggerExplosion(damage)
  local damageConfig = {
    power = math.max(self.minDamage, math.min(damage, self.maxDamage)),
    speed = 0,
    physics = "default"
  }
  world.spawnProjectile(self.damageProjectileType, mcontroller.position(), effect.sourceEntity() or nil, {0, 0}, true, damageConfig)
  animator.playSound("burst")
  
  self.hitsLeft = self.hitsLeft -1
end
