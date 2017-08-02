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
	
	--Locate targets for shock arcing
	local targetIds = world.entityQuery(mcontroller.position(), config.getParameter("jumpDistance", 8), {
      withoutEntityId = entity.id(),
      includedTypes = {"creature"}
    })

    shuffle(targetIds)

    for i,id in ipairs(targetIds) do
      local sourceEntityId = effect.sourceEntity() or entity.id()
      if world.entityCanDamage(sourceEntityId, id) and not world.lineTileCollision(mcontroller.position(), world.entityPosition(id)) then
        local sourceDamageTeam = world.entityDamageTeam(sourceEntityId)
        local directionTo = world.distance(world.entityPosition(id), mcontroller.position())
        world.spawnProjectile(
          config.getParameter("projectileType"),
          mcontroller.position(),
          entity.id(),
          directionTo,
          false,
          {
            power = actualDamage,
            damageTeam = sourceDamageTeam
          }
        )
        return
      end
    end
  end
  
  if not status.resourcePositive("health") and status.resourceMax("health") >= config.getParameter("minMaxHealth", 0) then
    effect.setParentDirectives(config.getParameter("deathDirective"))
	explode()
  end
end

function explode()
  if not self.exploded then
    world.spawnProjectile(config.getParameter("deathProjectileType"), mcontroller.position(), 0, {0, 0}, false)
    self.exploded = true
  end
end

function uninit()
  
end
