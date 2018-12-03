require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/scripts/poly.lua"
require "/items/active/weapons/weapon.lua"
require "/scripts/rails.lua"

TheaRailHook = WeaponAbility:new()

function TheaRailHook:init()
  self.cooldownTimer = self.cooldownTime
  self.hookCooldownTimer = self.hookCooldownTime or 1.0
  
  --Rail hook init
  self.railRider = Rails.createRider(self.railConfig)
  self.railRider:init()

  self.onRail = false
  self.volumeAdjustTimer = 0.0
  self.volumeAdjustTime = 0.1

  self.effectGroupName = "railhook" .. activeItem.hand()
  
  self:reset()
end

function TheaRailHook:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.hookCooldownTimer = math.max(0, self.hookCooldownTimer - self.dt)
  
  --If in the air, attempt to latch onto rails
  if self.weapon.currentAbility == nil and self.fireMode == "alt" and not mcontroller.onGround() and self.hookCooldownTimer == 0 then
	self:setState(self.railHook)
  end
end

function TheaRailHook:railHook()
  self.weapon:setStance(self.stances.railHook)
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  if not self.railRider:onRail() then
	self:engageHook()
  end
  
  while self.fireMode == "alt" and not mcontroller.isColliding() do
	self.railRider:updateConnectionOffset(self.connectionOffset)
	self.railRider:update(self.dt)
	
	world.debugPoint(vec2.add(mcontroller.position(), self.connectionOffset), "yellow")
	
	if self.railRider:onRail() then
	  --world.debugText("On Rail", vec2.add(mcontroller.position(), {0,-1}), "green")
	  mcontroller.controlModifiers(
		{jumpingSuppressed = true, movementSuppressed = true}
	  )
	  mcontroller.controlParameters(
		{airForce = 0}
	  )	  
	  status.setPersistentEffects(self.effectGroupName, {{stat = "activeMovementAbilities", amount = 1}})
	else
	  --world.debugText("Off Rail", vec2.add(mcontroller.position(), {0,-1}), "red")
	  status.clearPersistentEffects(self.effectGroupName)
	end
	
	--Overwrite the friction amount of the rail type we are currently attached to
	if self.railRider.onRailType then
	  self.railRider.railTypes[self.railRider.onRailType].friction = self.railFriction
	  --world.debugText(sb.printJson(self.railRider.onRailType), mcontroller.position(), "red")
	  --world.debugText(sb.printJson(self.railRider.railTypes[self.railRider.onRailType].friction), vec2.add(mcontroller.position(), {0,-1}), "red")
	end
	
	--Animation and sounds for the rail hook
	local onRail = self.railRider:onRail() and self.railRider.moving and self.railRider.speed > 0.01
	if onRail then
	  animator.setParticleEmitterActive("sparks", true)
	  animator.setParticleEmitterEmissionRate("sparks", math.floor(self.railRider.speed) * 2)

	  local volumeAdjustment = math.max(0.5, math.min(1.0, self.railRider.speed / 20))

	  if not self.onRail then
		self.onRail = true
		animator.playSound("grind", -1)
		animator.setSoundVolume("grind", volumeAdjustment, 0)
	  end

	  self.volumeAdjustTimer = math.max(0, self.volumeAdjustTimer - self.dt)
	  if self.volumeAdjustTimer == 0 then
		animator.setSoundVolume("grind", volumeAdjustment, self.volumeAdjustTime)
		self.volumeAdjustTimer = self.volumeAdjustTime
	  end
	else
	  animator.setParticleEmitterActive("sparks", false)

	  self.onRail = false
	  self.volumeAdjustTimer = self.volumeAdjustTime
	  animator.stopAllSounds("grind")
	end
	
	coroutine.yield()
  end
  
  self:disengageHook()
end

function TheaRailHook:engageHook()
  self.railRider:reset()
  self.railRider.connectionOffset = self.connectionOffset
end

function TheaRailHook:disengageHook()
  self.onRail = false
  self.hookCooldownTimer = self.hookCooldownTime or 1.0
  animator.setParticleEmitterActive("sparks", false)
  animator.stopAllSounds("grind")
  self.railRider:reset()
end

--Reset and uninit functions
function TheaRailHook:reset()
  animator.stopAllSounds("grind")
  animator.setParticleEmitterActive("sparks", false)
end

function TheaRailHook:uninit()
  self:reset()
  status.clearPersistentEffects(self.effectGroupName)
end
