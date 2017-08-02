require "/scripts/util.lua"

function init()
  animator.setParticleEmitterOffsetRegion("particles", mcontroller.boundBox())
  animator.setParticleEmitterActive("particles", true)
  effect.setParentDirectives("fade=000000=0.95?border=2;4800FF90;00000000")
  
  script.setUpdateDelta(25)
end

function update(dt)
  world.spawnProjectile(config.getParameter("gravitySourceProjectile", "centensiangravitysource"), mcontroller.position(), 0, {0, 0}, false)
end


function uninit()
end
