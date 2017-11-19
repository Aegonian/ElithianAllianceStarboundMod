require "/scripts/vec2.lua"

function init()
  if status.resourceMax("health") < config.getParameter("minMaxHealth", 0) then
    effect.expire()
  end
  
  animator.setParticleEmitterOffsetRegion("flames", mcontroller.boundBox())
  animator.setParticleEmitterActive("flames", true)
  --effect.setParentDirectives("fade=60B8EA=0.25")
  effect.setParentDirectives("border=3;B2D6EA80;00000000")
  
  self.shadowHasSpawned = false
end

function update(dt)
  --Check if there are already Xanafian Shadows at our position. If so, prevent another one from spawning. (This it to prevent double spawns from the shadowmarked-healing effect)
  local monsters = world.monsterQuery(mcontroller.position(), 0.25)
  for _, monster in ipairs(monsters) do
	--sb.logInfo(world.entityTypeName(monster))
	if world.entityTypeName(monster) == "xanafianshadow-friendly" then
	  self.shadowHasSpawned = true
	end
  end
  
  if not status.resourcePositive("health") and status.resourceMax("health") >= config.getParameter("minMaxHealth", 0) then
    spawnShadow()
  end
end

function uninit()
  
end

function spawnShadow()
  if not self.shadowHasSpawned then
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