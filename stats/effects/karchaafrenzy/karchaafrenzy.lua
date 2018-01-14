function init()
  --Loading config values
  self.powerModifier = config.getParameter("powerModifier", 1.5)
  self.speedModifier = config.getParameter("speedModifier", 1.5)
  self.jumpModifier = config.getParameter("jumpModifier", 0.5)
  self.airJumpModifier = config.getParameter("airJumpModifier", 1.5)
  
  --Setting modifiers
  effect.addStatModifierGroup({
	{stat = "powerMultiplier", effectiveMultiplier = self.powerModifier}
  })
  effect.addStatModifierGroup({
    {stat = "jumpModifier", amount = self.jumpModifier}
  })
  
  --Animation effects
  animator.setParticleEmitterOffsetRegion("embers", mcontroller.boundBox())
  animator.setParticleEmitterOffsetRegion("initialBurst", mcontroller.boundBox())
  animator.setParticleEmitterActive("embers", true)
  animator.burstParticleEmitter("initialBurst")
  
  effect.setParentDirectives(config.getParameter("directive"))
  
  status.setStatusProperty("karchaafrenzy", 1)
end


function update(dt)
  mcontroller.controlModifiers({
	speedModifier = self.speedModifier,
	airJumpModifier = self.airJumpModifier
  })
end

function uninit()
  status.setStatusProperty("karchaafrenzy", 0)
end
