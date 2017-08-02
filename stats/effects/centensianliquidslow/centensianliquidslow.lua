function init()
  animator.setParticleEmitterOffsetRegion("centensianliquiddrips", mcontroller.boundBox())
  animator.setParticleEmitterActive("centensianliquiddrips", true)
  effect.setParentDirectives("fade=A073FF=0.3")
  effect.addStatModifierGroup({
    {stat = "jumpModifier", amount = -0.20}
  })
  
  self.tickDamagePercentage = 0.075
  self.tickTime = 1.0
  self.tickTimer = self.tickTime
end

function update(dt)
  mcontroller.controlModifiers({
      groundMovementModifier = 0.5,
      speedModifier = 0.65,
      airJumpModifier = 0.80
    })
	
  self.tickTimer = self.tickTimer - dt
  if self.tickTimer <= 0 then
    self.tickTimer = self.tickTime
    status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = math.floor(status.resourceMax("health") * self.tickDamagePercentage) + 1,
        damageSourceKind = "centensianenergy",
        sourceEntityId = entity.id()
    })
  end
  
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
	  statusEffects = {"centensianliquidslow"},
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