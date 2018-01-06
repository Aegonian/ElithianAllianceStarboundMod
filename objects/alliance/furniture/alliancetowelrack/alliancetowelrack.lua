require "/scripts/vec2.lua"

function init()
  object.setInteractive(true)
end

function onInteraction(args)
  animator.playSound("dry")
  world.spawnProjectile("thea-dryaura", vec2.add(entity.position(), {1,1}))
end

function update(dt) 
  
end
