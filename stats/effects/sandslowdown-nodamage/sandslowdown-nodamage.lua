function init()
  animator.setParticleEmitterOffsetRegion("sanddrips", mcontroller.boundBox())
  animator.setParticleEmitterActive("sanddrips", true)
  effect.setParentDirectives("fade=BDAE65=0.1")
  effect.addStatModifierGroup({
    {stat = "jumpModifier", amount = -0.20}
  })
end

function update(dt)
  mcontroller.controlModifiers({
      groundMovementModifier = 0.5,
      speedModifier = 0.65,
      airJumpModifier = 0.80
    })		
end

function uninit()

end