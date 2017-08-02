require "/items/active/weapons/weapon.lua"

LightningArc = WeaponAbility:new()

function LightningArc:init()
  self.cooldownTimer = self.cooldownTime
  self:reset()
end

function LightningArc:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility
	and self.fireMode == (self.activatingFireMode or self.abilitySlot)
	and self.cooldownTimer == 0
	and not status.resourceLocked("energy") then
	  
	self:setState(self.fire)
  end
end

function LightningArc:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()
	
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
	
  --Play custom arcing animation, and activate particles
  animator.setAnimationState("swoosh", "arcing")
  animator.setParticleEmitterActive("holdparticles", true)

  animator.playSound("fire")
	
  animator.playSound("holdLoop", -1)

  local params = copy(self.projectileParameters)
  params.power = self.baseDps * self.fireTime * config.getParameter("damageLevelMultiplier")
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  
  local fireTimer = 0.2
	
  --While holding the fire button and we have plenty of energy
  while self.fireMode == "alt" and status.overConsumeResource("energy", self.energyUsage * self.dt) do
	
	--Force the player to walk instead of run
	mcontroller.controlModifiers({runningSuppressed=true})
	  
	--Count down a fireTimer. When at zero, spawn the arc source projectile, then reset the timer
	fireTimer = math.max(0, fireTimer - self.dt)
	if fireTimer == 0 then
	  fireTimer = self.fireTime
	  local position = self:firePosition()
	  local aim = self.weapon.aimAngle
	  if not world.lineTileCollision(mcontroller.position(), position) then
		world.spawnProjectile(self.projectileType, position, activeItem.ownerEntityId(), {mcontroller.facingDirection() * math.cos(aim), math.sin(aim)}, true, params)
	  end
	end

	coroutine.yield()
  end
  self.cooldownTimer = self.cooldownTime
end

function LightningArc:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.projectileSpawnPosition))
end
  
function LightningArc:reset()
  animator.setAnimationState("swoosh", "idle")
  animator.setParticleEmitterActive("holdparticles", false)
  animator.stopAllSounds("holdLoop")
end

function LightningArc:uninit()
  self:reset()
end
