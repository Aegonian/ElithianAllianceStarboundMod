function init()
  animator.setParticleEmitterOffsetRegion("sanddrips", mcontroller.boundBox())
  animator.setParticleEmitterActive("sanddrips", true)
  effect.setParentDirectives("fade=BDAE65=0.1")
  effect.addStatModifierGroup({
    {stat = "jumpModifier", amount = -0.60}
  })
  
  self.tickDamagePercentage = 0.075
  self.tickTime = 1.0
  self.tickTimer = self.tickTime
end

function update(dt)
  mcontroller.controlModifiers({
      groundMovementModifier = 0.1,
      speedModifier = 0.2,
      airJumpModifier = 0.4
    })
  mcontroller.controlParameters({
       gravityMultiplier = 0.1,
	   liquidFriction = 75.0
    })
	
  self.tickTimer = self.tickTimer - dt
  
  local waterFactor = mcontroller.liquidPercentage();
  
  if (waterFactor>0.8) and self.tickTimer <= 0 then
    self.tickTimer = self.tickTime
	status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = math.floor(status.resourceMax("health") * self.tickDamagePercentage) + 1,
        damageSourceKind = "default",
        sourceEntityId = entity.id()
    })
  end
		
end

function uninit()

end