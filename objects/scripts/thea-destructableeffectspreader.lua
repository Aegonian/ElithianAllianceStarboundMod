require "/scripts/vec2.lua"

function init()  
  self.effectRadius = config.getParameter("effectRadius", 50)
  self.damageParticles = config.getParameter("damageParticles", false)
  self.destroyParticles = config.getParameter("destroyParticles", false)
  self.useFollowProjectile = config.getParameter("useFollowProjectile", false)
  self.followProjectileCooldown = config.getParameter("followProjectileCooldown", 0.5)
  self.followTargetOffset = config.getParameter("followTargetOffset", {0, 0})
  self.targetTypes = config.getParameter("targetTypes", {"creature"})
  
  if (config.getParameter("idleParticles", false)) then
	animator.setParticleEmitterActive("idleParticles", true)
  end
  
  self.cooldown = self.followProjectileCooldown
  
  storage.health = storage.health or object.health()
end

function update(dt)
  local targets = world.entityQuery(entity.position(), self.effectRadius, {
	withoutEntityId = entity.id(),
	includedTypes = self.targetTypes,
	order = "nearest"
  })
  
  self.cooldown = math.max(0, self.cooldown - dt)
  
  for _, target in ipairs(targets) do
	world.spawnProjectile(config.getParameter("effectProjectile"), world.entityPosition(target), entity.id(), {0,0})
	
	if self.useFollowProjectile and self.cooldown == 0 then
	  local projectileId = world.spawnProjectile(config.getParameter("followProjectile"), world.entityPosition(target), entity.id(), {0,0})
	  if projectileId then
		world.sendEntityMessage(projectileId, "setTargetEntity", entity.id(), self.followTargetOffset, target)
	  end
	  self.cooldown = self.followProjectileCooldown
	end
  end
  
  --If our current health is lower than stored health, we received damage and should burst the damage particle emitter
  if self.damageParticles and object.health() ~= storage.health then
	animator.burstParticleEmitter("damage")
	animator.playSound("damage")
  end
  
  storage.health = object.health()
  
  world.debugPoint(vec2.add(object.position(), config.getParameter("explosionOffset", {0,0})), "red")
end

function die()
  local projectileConfig = {
	damageTeam = { type = "indiscriminate" },
	power = config.getParameter("explosionDamage", 50),
	onlyHitTerrain = false,
	timeToLive = 0,
	damageRepeatGroup = config.getParameter("damageRepeatGroup", "environment"),
	actionOnReap = {
	  {
		action = "config",
		file =  config.getParameter("explosionConfig")
	  }
	}
  }
  world.spawnProjectile("invisibleprojectile", vec2.add(object.position(), config.getParameter("explosionOffset", {0,0})), entity.id(), {0,0}, false, projectileConfig)
  
  if self.destroyParticles then
	animator.burstParticleEmitter("destroy")
  end
end
