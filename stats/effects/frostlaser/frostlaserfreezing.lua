function init()
  animator.setParticleEmitterOffsetRegion("icetrail", mcontroller.boundBox())
  animator.setParticleEmitterActive("icetrail", true)
  effect.setParentDirectives("fade=00BBFF=0.15")

  script.setUpdateDelta(5)
  effect.addStatModifierGroup({
    {stat = "jumpModifier", amount = -0.15}
  })
  
  self.activeTimer = 0
end

function update(dt)
  self.activeTimer = self.activeTimer + dt
  
  mcontroller.controlModifiers({
	groundMovementModifier = 0.3,
	speedModifier = 0.75,
	airJumpModifier = 0.85
  })
  
  if self.activeTimer >= config.getParameter("timeToFreeze", 5) then
	status.addEphemeralEffect("frostlaserfrozen", config.getParameter("freezeDuration", 5), effect.sourceEntity())
	effect.expire()
  end
end

function onExpire()
  status.addEphemeralEffect("frostslow", config.getParameter("freezeDuration", 5), effect.sourceEntity())
end

function uninit()

end
