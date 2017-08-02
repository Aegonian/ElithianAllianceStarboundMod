function init()
  animator.setParticleEmitterOffsetRegion("drips", mcontroller.boundBox())
  animator.setParticleEmitterActive("drips", true)
  effect.setParentDirectives("fade=960000=0.25")
  effect.addStatModifierGroup({
    {stat = "jumpModifier", amount = -0.10}
  })
  
  self.tickDamagePercentage = 0.02
  self.tickTime = 1.0
  self.tickTimer = self.tickTime

end

function update(dt)
  mcontroller.controlModifiers({
	groundMovementModifier = 0.75,
	speedModifier = 0.75,
	airJumpModifier = 0.90
  })
  
  self.tickTimer = self.tickTimer - dt
  
  --Calculate tick damage
  local tickDamage = math.min(math.floor(status.resourceMax("health") * self.tickDamagePercentage) + 1, 20)
  
  if self.tickTimer <= 0 then
    self.tickTimer = self.tickTime
	status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = tickDamage,
        damageSourceKind = "default",
        sourceEntityId = entity.id()
    })
  end
end

function uninit()

end