require "/scripts/vec2.lua"

function init()
  --Settings from config file
  self.maxHealth = config.getParameter("maxHealth")
  self.protection = config.getParameter("protection")
  self.materialKind = config.getParameter("materialKind")
  self.timeToLive = config.getParameter("timeToLive")
  self.descentSpeed = config.getParameter("descentSpeed")
  self.descentControl = config.getParameter("descentControl")
  self.groundSearchDistance = config.getParameter("groundSearchDistance")
  self.treasurePool = config.getParameter("treasurePool")
  self.treasureSpawnPosition = config.getParameter("treasureSpawnPosition")
  self.hasTopCollision = config.getParameter("hasTopCollision")
  self.movementSettings = config.getParameter("movementSettings")
  self.groundedMovementSettings = config.getParameter("groundedMovementSettings")
  
  --Stored variables
  if not storage.vehicleOpened then
	storage.vehicleOpened = false
	animator.setAnimationState("body", "spawn")
  end
  storage.health = storage.health or self.maxHealth
  
  --Instanced variables
  self.lifeTimer = self.timeToLive
  self.spawning = (animator.animationState("body") == "spawn" or animator.animationState("body") == "despawn")
  self.wasColliding = false
  
  --Functions setup
  self.selfDamageNotifications = {}
  
  vehicle.setDamageTeam({type = "passive"})
  vehicle.setPersistent(false)
  vehicle.setInteractive(false)
end

function update()
  --========================= General Behaviour =========================
  self.spawning = (animator.animationState("body") == "spawn" or animator.animationState("body") == "despawn" or animator.animationState("body") == "invisible")
  
  mcontroller.resetParameters(self.movementSettings)
  if nearGround() or storage.vehicleOpened then
    mcontroller.applyParameters(self.groundedMovementSettings)
  end
  
  --========================= Destruction Behaviour =========================
  --If the storage has been opened, count down the lifeTimer
  if storage.vehicleOpened then
	self.lifeTimer = math.max(0, self.lifeTimer - script.updateDt())
  end
  
  --If we have run out of health, spawn items and set the vehicle to destroy
  if storage.health <= 0 then
	if not storage.vehicleOpened then
	  world.spawnTreasure(vec2.add(mcontroller.position(), self.treasureSpawnPosition), self.treasurePool, world.threatLevel())
	  animator.burstParticleEmitter("break")
	  animator.playSound("break")
	  storage.vehicleOpened = true
	end
  end
  
  --If the vehicle has been opened, destroy the vehicle
  if storage.vehicleOpened then
	vehicle.destroy()
  end
  
  --========================= Animation and Sound Behaviour =========================  
  --If we are near the ground, cut thrusters
  if nearGround() and not storage.vehicleOpened and not self.spawning then
	animator.setAnimationState("body", "idle")
  end
  
  if mcontroller.isColliding() then
	if not self.wasColliding then
	  animator.playSound("collide")
	end
  end
  
  --========================= Movement Behaviour =========================
  --While in the hover animation, move down
  if animator.animationState("body") == "hovering" then
	mcontroller.approachYVelocity(-self.descentSpeed, self.descentControl)
  end
  
  self.wasColliding = mcontroller.isColliding()
  
  --Debug values
  world.debugText(storage.health, vec2.add(mcontroller.position(), {0,0}), "yellow")
  world.debugText(sb.print(nearGround()), vec2.add(mcontroller.position(), {0,-1}), "yellow")
end

--Function for applying damage to the vehicle
function applyDamage(damageRequest)
  local damage = 0
  if damageRequest.damageType == "Damage" then
    damage = damage + root.evalFunction2("protection", damageRequest.damage, self.protection)
  elseif damageRequest.damageType == "IgnoresDef" then
    damage = damage + damageRequest.damage
  else
    return {}
  end
  
  local healthLost = math.min(damage, storage.health)
  storage.health = storage.health - healthLost

  return {{
    sourceEntityId = damageRequest.sourceEntityId,
    targetEntityId = entity.id(),
    position = mcontroller.position(),
    damageDealt = damage,
    healthLost = healthLost,
    hitType = "Hit",
    damageSourceKind = damageRequest.damageSourceKind,
    targetMaterialKind = self.materialKind,
    killed = storage.health <= 0
  }}
end

--Damage notification setup
function selfDamageNotifications()
  local sdn = self.selfDamageNotifications
  self.selfDamageNotifications = {}
  return sdn
end

--Function to check if we are near the ground
function nearGround()
  if world.lineCollision(mcontroller.position(), vec2.add(mcontroller.position(), {0, -self.groundSearchDistance})) then
	return true
  else
	return false
  end
end
