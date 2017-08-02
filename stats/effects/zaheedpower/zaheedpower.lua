function init()
  self.powerModifier = config.getParameter("powerModifier", 0)
  effect.addStatModifierGroup({{stat = "powerMultiplier", effectiveMultiplier = self.powerModifier}})

  local enableParticles = config.getParameter("particles", true)
  animator.setParticleEmitterOffsetRegion("embers", mcontroller.boundBox())
  animator.setParticleEmitterActive("embers", enableParticles)
  
  effect.setParentDirectives("border=2;FF930020;00000000")
end


function update(dt)
  
end

function uninit()

end
