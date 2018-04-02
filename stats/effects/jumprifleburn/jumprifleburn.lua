require("/scripts/vec2.lua")

function init()
  animator.setParticleEmitterOffsetRegion("flames", mcontroller.boundBox())
  animator.setParticleEmitterActive("flames", true)
  effect.setParentDirectives("fade=BF4C00=0.25")
  animator.playSound("burn", -1)
  
  script.setUpdateDelta(5)
  
  self.tickDamagePercentage = 0.035
  self.tickTime = 1.0
  self.tickTimer = self.tickTime
  self.projectileTime = 0.25
  self.projectileTimer = self.projectileTime
  
  self.lastPosition = nil
end

function update(dt)
  if effect.duration() and world.liquidAt({mcontroller.xPosition(), mcontroller.yPosition() - 1}) then
    effect.expire()
  end

  --Overwrite other burning effects
  status.removeEphemeralEffect("thea-burning")
  status.removeEphemeralEffect("burning")
  
  --Dealing damage to self
  local targetDamage = math.floor(status.resourceMax("health") * self.tickDamagePercentage) + 1
  local actualDamage = math.min(targetDamage, 25)
  
  self.tickTimer = math.max(0, self.tickTimer - dt)
  if self.tickTimer == 0 then
    self.tickTimer = self.tickTime
	
    status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = actualDamage,
        damageSourceKind = "fire",
        sourceEntityId = entity.id()
      })
	animator.playSound("burst")
  end
  
  --Spawning fire trail
  self.projectileTimer = math.max(0, self.projectileTimer - dt)
  local distanceMoved = {0,0}
  if self.lastPosition then
	distanceMoved  = world.distance(mcontroller.position(), self.lastPosition)
  end
  if self.projectileTimer == 0 and (not self.lastPosition or vec2.mag(distanceMoved) > 2) and mcontroller.onGround() then
    self.projectileTimer = self.projectileTime
	
	local projectileConfig = {
	  power = 2
	}
	world.spawnProjectile("jumprifleflame-noeffect", mcontroller.position(), effect.sourceEntity() or nil, {0, 0}, false, projectileConfig)
	self.lastPosition = mcontroller.position()
  end
end

function uninit()
  
end
