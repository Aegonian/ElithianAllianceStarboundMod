function init()
  animator.setParticleEmitterOffsetRegion("embers", mcontroller.boundBox())
  animator.setParticleEmitterActive("embers", true)
  
  self.powerModifier = config.getParameter("powerModifier", 1.5)
  effect.addStatModifierGroup({
	{stat = "powerMultiplier", effectiveMultiplier = self.powerModifier}
  })
end


function update(dt)
  if animator.hasSound("apply") and not self.applySoundPlayed then
	animator.playSound("apply")
	self.applySoundPlayed = true
  end
end

function uninit()

end
