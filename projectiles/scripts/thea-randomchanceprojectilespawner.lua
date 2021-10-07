require "/scripts/vec2.lua"

function init()
  message.setHandler("kill", function()
	projectile.die()
  end)
  
  self.projectileType = config.getParameter("projectileType")
  self.spawnChance = config.getParameter("spawnChance")
  
  self.startPosition = mcontroller.position()
  self.projectileSpawned = false
end

function update(dt)
  mcontroller.setPosition(self.startPosition)
  
  if not self.randomNumber then
	self.randomNumber = math.random(1, 100) / 100
	if self.randomNumber <= self.spawnChance and not self.projectileSpawned then
	  world.spawnProjectile(
		self.projectileType,
		mcontroller.position(),
		projectile.sourceEntity() or entity.id(),
		{0,0},
		false
	  )
	end
  end
end
