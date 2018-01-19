function init()
  animator.setParticleEmitterOffsetRegion("flames", mcontroller.boundBox())
  animator.setParticleEmitterActive("flames", true)
  --effect.setParentDirectives("fade=BF3300=0.25")
  animator.playSound("burn", -1)
  
  script.setUpdateDelta(5)

  self.tickDamagePercentage = 0.025
  self.tickTime = 1.0
  self.tickTimer = self.tickTime
  
  self.activeTimer = 0
end

function update(dt)
  --Remove other burning effect to prevent double damage
  status.removeEphemeralEffect("burning")
  status.removeEphemeralEffect("thea-burning")
  
  --Burning code
  if effect.duration() and world.liquidAt({mcontroller.xPosition(), mcontroller.yPosition() - 1}) then
    effect.expire()
  end

  local targetDamage = math.floor(status.resourceMax("health") * self.tickDamagePercentage) + 1
  local actualDamage = math.min(targetDamage, 10)
  
  self.tickTimer = self.tickTimer - dt
  if self.tickTimer <= 0 then
    self.tickTimer = self.tickTime
    status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = actualDamage,
        damageSourceKind = "fire",
        sourceEntityId = entity.id()
      })
  end
  
  --Meltdown explosion code
  self.activeTimer = self.activeTimer + dt
  
  --Dynamic overlay and border effect
  local factor = (self.activeTimer / config.getParameter("timeToExplode", 5)) * 0.5
  local borderWidth = math.ceil(self.activeTimer / config.getParameter("timeToExplode", 5) * 10)
  local borderIntensity = math.ceil(self.activeTimer / config.getParameter("timeToExplode", 5) * 80) + 10
  local directive = "fade=BF3300=" .. factor .. "?border=" .. borderWidth .. ";BF3300" .. borderIntensity .. ";00000000"
  effect.setParentDirectives(directive)
  
  local R = math.ceil(self.activeTimer / config.getParameter("timeToExplode", 5) * 127) + 127
  local G = math.ceil(self.activeTimer / config.getParameter("timeToExplode", 5) * 63) + 63
  local B = math.ceil(self.activeTimer / config.getParameter("timeToExplode", 5) * 5) + 5
  local lightColour = {R, G, B}
  
  animator.setLightColor("glow", lightColour)
  
  --world.debugText(borderIntensity, mcontroller.position(), "blue")
  --world.debugText(sb.printJson(lightColour), mcontroller.position(), "blue")
  
  if self.activeTimer >= config.getParameter("timeToExplode", 5) then
	explode()
  end
end

function explode()
  if not self.exploded then
    local sourceEntityId = effect.sourceEntity() or entity.id()
    local sourceDamageTeam = world.entityDamageTeam(sourceEntityId)
    local bombPower = config.getParameter("explosionDamage", 50.0)
    local projectileConfig = {
      power = bombPower,
      damageTeam = sourceDamageTeam,
      onlyHitTerrain = false,
      timeToLive = 0,
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
  effect.expire()
end

function onExpire()
  status.addEphemeralEffect("thea-burning", config.getParameter("burnDuration", 5), effect.sourceEntity())
end

function uninit()

end
