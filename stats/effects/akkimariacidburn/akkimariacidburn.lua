require "/scripts/util.lua"

function init()
  if status.resourceMax("health") < config.getParameter("minMaxHealth", 0) then
    effect.expire()
  end
  
  animator.setParticleEmitterOffsetRegion("flames", mcontroller.boundBox())
  animator.setParticleEmitterActive("flames", true)
  effect.setParentDirectives(config.getParameter("directive"))
  
  script.setUpdateDelta(5)

  self.tickDamagePercentage = 0.025
  self.tickTime = 0.75
  self.tickTimer = self.tickTime
end

function update(dt)
  self.tickTimer = self.tickTimer - dt
  
  --Actions to be performed on every tick
  if self.tickTimer <= 0 then
    self.tickTimer = self.tickTime
	
	--Play the damage sound
	animator.playSound("shock")
	
	local targetDamage = math.floor(status.resourceMax("health") * self.tickDamagePercentage) + 1
	local actualDamage = math.min(targetDamage, 25)
	
	--Apply damage to self
    status.applySelfDamageRequest({
	  damageType = "IgnoresDef",
	  damage = actualDamage,
	  damageSourceKind = config.getParameter("damageKind"),
	  sourceEntityId = entity.id()
	})
  end
  
  if not status.resourcePositive("health") and status.resourceMax("health") >= config.getParameter("minMaxHealth", 0) then
    effect.setParentDirectives(config.getParameter("deathDirective"))
	explode()
  end
end

function explode()
  if not self.exploded then
    world.spawnProjectile(config.getParameter("deathProjectileType"), mcontroller.position(), effect.sourceEntity() or entity.id(), {0, 0}, false)
    self.exploded = true
  end
end

function uninit()
  
end
