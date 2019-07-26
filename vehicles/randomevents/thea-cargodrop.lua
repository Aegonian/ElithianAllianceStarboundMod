require "/scripts/vec2.lua"

function init()
  --Settings from config file
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
  
  --Instanced variables
  self.lifeTimer = self.timeToLive
  self.spawning = (animator.animationState("body") == "spawn" or animator.animationState("body") == "despawn")
  self.wasColliding = false
  
  vehicle.setPersistent(false)
  vehicle.setInteractive(true)
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
  
  --If we have exceeded our life time, start despawn sequence
  if self.lifeTimer == 0 and animator.animationState("body") == "open" then
	animator.setAnimationState("body", "despawn")
	self.spawning = true
	if self.hasTopCollision then
	  vehicle.setMovingCollisionEnabled("top", false)
	end
  end
  
  --If animation state is set to invisible, destroy the vehicle
  if animator.animationState("body") == "invisible" then
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
  world.debugText(self.lifeTimer, vec2.add(mcontroller.position(), {0,0}), "yellow")
  world.debugText(sb.print(nearGround()), vec2.add(mcontroller.position(), {0,-1}), "yellow")
end

--On interaction, open the storage
function onInteraction(args)
  local interactingEntityId = args.sourceId
  
  if not storage.vehicleOpened then
	world.spawnTreasure(vec2.add(mcontroller.position(), self.treasureSpawnPosition), self.treasurePool, world.threatLevel())
	animator.setAnimationState("body", "opening")
	animator.playSound("open")
	vehicle.setInteractive(false)
	storage.vehicleOpened = true
  end
end

--Function to check if we are near the ground
function nearGround()
  if world.lineCollision(mcontroller.position(), vec2.add(mcontroller.position(), {0, -self.groundSearchDistance})) then
	return true
  else
	return false
  end
end
