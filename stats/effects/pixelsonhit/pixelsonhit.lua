
function init()
  self.pixelsHaveSpawned = false
end

function update(dt)
  if self.pixelsHaveSpawned == false then
	world.spawnProjectile("thea-moneyspawner", entity.position(), entity.id(), {0,0}, true, nil)
	self.pixelsHaveSpawned = true
  end
  
  if self.pixelsHaveSpawned == true then
	effect.expire()
  end
end

function uninit()
  
end
