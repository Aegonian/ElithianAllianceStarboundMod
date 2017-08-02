require "/scripts/util.lua"

function init()
  script.setUpdateDelta(25)
end

function update(dt)
  world.spawnProjectile("centensiangravityrepel", mcontroller.position(), 0, {0, 0}, false)
end


function uninit()
end
