require "/scripts/vec2.lua"

function init()
  if status.resourceMax("health") < config.getParameter("minMaxHealth", 0) then
    effect.expire()
  end
  
  animator.setParticleEmitterOffsetRegion("flames", mcontroller.boundBox())
  animator.setParticleEmitterActive("flames", true)
  --effect.setParentDirectives("fade=60B8EA=0.25")
  effect.setParentDirectives("border=3;B2D6EA80;00000000")
  
  self.projectileSpawned = false
  self.shadowHasSpawned = false
  self.isExpiring = false
end

function update(dt)
  --Check if there are already Xanafian Shadows at our position. If so, prevent another one from spawning. (This it to prevent double spawns from the shadowmarked-healing effect)
  local monsters = world.monsterQuery(mcontroller.position(), 0.5)
  for _, monster in ipairs(monsters) do
	--sb.logInfo(world.entityTypeName(monster))
	if world.entityTypeName(monster) == "xanafianshadow-friendly" then
	  self.shadowHasSpawned = true
	end
  end
  
  if not status.resourcePositive("health") and status.resourceMax("health") >= config.getParameter("minMaxHealth", 0) and not self.isExpiring then
    spawnShadow()
  end
  
  status.removeEphemeralEffect("shadowmarked")
  
  --If true, spawn a projectile which will seek out the status effect inflicter and heal them
  if not self.projectileSpawned then
	local sourceEntity = effect.sourceEntity()
	if world.entityExists(sourceEntity) then
	  --world.debugPoint(world.entityPosition(sourceEntity), "green")
	  local projectileNumber = 0
	  for i = 1, config.getParameter("projectileCount") do
		projectileNumber = projectileNumber + 1
		
		local direction = {0, 1}
		direction = vec2.rotate(direction, (360 / (config.getParameter("projectileCount") + 1) * projectileNumber))
		
		if config.getParameter("projectileCount") == 1 then
		  direction = {0, 0}
		end
		
		local projectileId = world.spawnProjectile(config.getParameter("projectileType"), mcontroller.position(), nil, direction, false)
		if projectileId then
		  world.sendEntityMessage(projectileId, "setTargetEntity", sourceEntity)
		  self.projectileSpawned = true
		end
	  end
	end
  end
end

function uninit()
  
end

function spawnShadow()
  if not self.shadowHasSpawned and not self.isExpiring then
	--Determine target level for spawned monster
	local spawnLevel = math.min(world.threatLevel(), 4)
	--Spawn the monster
    local spawnedShadowId = world.spawnMonster("xanafianshadow-friendly", mcontroller.position(), {
        level = spawnLevel,
        aggressive = true
      })
	world.callScriptedEntity(spawnedShadowId, "status.addEphemeralEffect", "automaticdespawn")
	world.spawnProjectile("xanafianshadowspawn", mcontroller.position(), 0, {0, 0}, false, nil)
    self.shadowHasSpawned = true
  end
end

function onExpire()
  self.isExpiring = true
  if not self.shadowHasSpawned then
	status.addEphemeralEffect("shadowmarked", config.getParameter(5), effect.sourceEntity())
  end
end