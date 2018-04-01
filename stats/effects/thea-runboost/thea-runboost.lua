function init()
  animator.setParticleEmitterOffsetRegion("embers", mcontroller.boundBox())
  animator.setParticleEmitterActive("embers", true)
end

function update(dt)
  if animator.hasSound("apply") and not self.applySoundPlayed then
	animator.playSound("apply")
	self.applySoundPlayed = true
  end
  
  mcontroller.controlModifiers({
	speedModifier = config.getParameter("healAmount", 1.5)
  })
end

function uninit()
  
end
