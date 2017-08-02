require "/scripts/vec2.lua"

function die()
  world.spawnProjectile(config.getParameter("explosionProjectile", "explosivebarrel"), vec2.add(object.position(), config.getParameter("explosionOffset", {0,0})), entity.id(), {0,0})
end
