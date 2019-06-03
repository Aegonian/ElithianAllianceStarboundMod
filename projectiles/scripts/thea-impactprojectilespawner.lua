require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.projectileType = config.getParameter("projectileType")
  self.projectilePowerInheritFactor = config.getParameter("projectilePowerInheritFactor")
  self.cooldownTime = config.getParameter("cooldownTime")
  
  self.cooldownTimer = self.cooldownTime
end

function update(dt)
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  
  if (projectile.collision() or mcontroller.isCollisionStuck() or mcontroller.isColliding() or mcontroller.onGround()) then
	if self.cooldownTimer == 0 then
	  local sourceEntityId = projectile.sourceEntity() or entity.id()
	  local sourceDamageTeam = world.entityDamageTeam(sourceEntityId)
	  world.spawnProjectile(
          self.projectileType,
          mcontroller.position(),
          sourceEntityId,
          mcontroller.velocity(),
          false,
          {
            power = projectile.power() * self.projectilePowerInheritFactor,
			powerMultiplier = projectile.powerMultiplier(),
            damageTeam = sourceDamageTeam
          }
        )
	end
  end
end
