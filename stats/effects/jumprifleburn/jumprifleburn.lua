function init()
  animator.setParticleEmitterOffsetRegion("flames", mcontroller.boundBox())
  animator.setParticleEmitterActive("flames", true)
  effect.setParentDirectives("fade=BF4C00=0.25")
  animator.playSound("burn", -1)
  
  script.setUpdateDelta(5)
  
  self.damageMultiplier = 0.015
  self.minDamage = 1
  self.maxDamage = 50
  self.tickTime = 1.0
  self.tickTimer = self.tickTime
end

function update(dt)
  if effect.duration() and world.liquidAt({mcontroller.xPosition(), mcontroller.yPosition() - 1}) then
    effect.expire()
  end

  self.tickTimer = self.tickTimer - dt
  if self.tickTimer <= 0 then
    self.tickTimer = self.tickTime
	local damage = math.floor(status.resourceMax("health") * self.damageMultiplier)
	local damageConfig = {
	  power = math.max(self.minDamage, math.min(damage, self.maxDamage)),
	  speed = 0,
	  physics = "default"
	}
	world.spawnProjectile("jumprifleburnburstspawner", mcontroller.position(), effect.sourceEntity() or nil, {0, 0}, true, damageConfig)
	animator.playSound("burst")
  end
end

function uninit()
  
end
