function init()
  animator.setParticleEmitterOffsetRegion("cloakedParticles", mcontroller.boundBox())
  animator.setParticleEmitterOffsetRegion("cloakedParticles2", mcontroller.boundBox())
  animator.setParticleEmitterActive("cloakedParticles", true)
  animator.setParticleEmitterActive("cloakedParticles2", true)

  local alpha = math.floor(config.getParameter("alpha") * 255)
  effect.setParentDirectives(string.format("?multiply=ffffff%02x", alpha))
  script.setUpdateDelta(0)
end
