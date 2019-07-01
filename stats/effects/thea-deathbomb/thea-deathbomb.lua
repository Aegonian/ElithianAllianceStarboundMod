function init()
  if status.resourceMax("health") < config.getParameter("minMaxHealth", 0) then
    effect.expire()
  end
end

function update(dt)
  if not status.resourcePositive("health") and status.resourceMax("health") >= config.getParameter("minMaxHealth", 0) then
    explode()
  end
end

function uninit()
  
end

function explode()
  if not self.exploded then
    local sourceEntityId = effect.sourceEntity() or entity.id()
    local sourceDamageTeam = world.entityDamageTeam(sourceEntityId)
    local bombPower = status.resourceMax("health") * config.getParameter("healthDamageFactor", 1.0)
    local projectileConfig = {
      power = bombPower,
      damageTeam = sourceDamageTeam,
      onlyHitTerrain = false,
      timeToLive = 0,
	  statusEffects = config.getParameter("explosionStatusEffects") or nil,
      actionOnReap = {
        {
          action = "config",
          file = config.getParameter("bombConfig")
        }
      }
    }
    world.spawnProjectile("invisibleprojectile", mcontroller.position(), 0, {0, 0}, false, projectileConfig)
    self.exploded = true
  end
end