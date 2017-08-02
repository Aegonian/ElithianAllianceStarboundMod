require "/scripts/util.lua"

function init()
  self.tickTime = config.getParameter("tickTime")
  self.tickTimer = self.tickTime
end

function update(dt)  
  self.tickTimer = self.tickTimer - dt
  if self.tickTimer <= 0 then
    self.tickTimer = self.tickTime
    
	local sourceEntityId = projectile.sourceEntity() or entity.id()
	
	world.spawnProjectile(
	  "sandmodspawner",
	  mcontroller.position(),
	  sourceEntityId,
	  {0,0},
	  false,
	  {
		--damage dealt by the bolt is base damage (boltPower) multiplied by the player's power modifier
		power = 1,
		damageTeam = sourceDamageTeam
	  }
	)
  end
end