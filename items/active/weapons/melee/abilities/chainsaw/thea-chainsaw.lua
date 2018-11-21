-- Melee primary ability
TheaChainSaw = WeaponAbility:new()

function TheaChainSaw:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime

  self.energyUsage = self.energyUsage or 0
  self.idleLoopPlaying = false
  self.holdLoopPlaying = false
  self.damageLoopPlaying = false
  self.active = false
  self.damagingTiles = false
  self.cooldownTimer = self.cooldownTime
  self.minimumActiveTimer = 0

  self.weapon:setStance(self.stances.idle)

  if animator.hasSound("idleLoop") then
	animator.stopAllSounds("idleLoop")
  end
  if animator.hasSound("holdLoop") then
	animator.stopAllSounds("holdLoop")
  end

  self.weapon.onLeaveAbility = function()
	self.weapon:setStance(self.stances.idle)
	self.damagingTiles = false
  end
end

-- Ticks on every update regardless if this is the active ability
function TheaChainSaw:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  self.minimumActiveTimer = math.max(0, self.minimumActiveTimer - self.dt)
  
  animator.setParticleEmitterActive("miningSparks", self.damagingTiles)
  
  --world.debugText("Chainsaw Active? " .. sb.printJson(self.active), vec2.add(mcontroller.position(), {0,1}), "red")
  --world.debugText("Idle Loop Playing? " .. sb.printJson(self.idleLoopPlaying), vec2.add(mcontroller.position(), {0,2}), "red")
  --world.debugText("Hold Loop Playing? " .. sb.printJson(self.holdLoopPlaying), vec2.add(mcontroller.position(), {0,3}), "red")
  --world.debugText("Animation State : " .. sb.printJson(animator.animationState("blade")), vec2.add(mcontroller.position(), {0,4}), "red")

  --Play active and inactive looping sounds
  if animator.animationState("blade") == "active" then
	--Optionally play idle sound
	if self.active then
	  if self.damagingTiles and animator.hasSound("damageLoop") then
		if not self.damageLoopPlaying then
		  animator.playSound("damageLoop", -1)
		  self.damageLoopPlaying = true
		  if animator.hasSound("holdLoop") then
			animator.stopAllSounds("holdLoop")
			self.holdLoopPlaying = false
		  end
		end
	  else
		if animator.hasSound("holdLoop") and not self.holdLoopPlaying then
		  animator.playSound("holdLoop", -1)
		  self.holdLoopPlaying = true
		  if animator.hasSound("idleLoop") then
			animator.stopAllSounds("idleLoop")
			self.idleLoopPlaying = false
		  end
		  if animator.hasSound("damageLoop") then
			animator.stopAllSounds("damageLoop")
			self.damageLoopPlaying = false
		  end
		end
	  end
	else
	  if animator.hasSound("idleLoop") and not self.idleLoopPlaying then
		animator.playSound("idleLoop", -1)
		self.idleLoopPlaying = true
		if animator.hasSound("holdLoop") then
		  animator.stopAllSounds("holdLoop")
		  self.holdLoopPlaying = false
		end
	  end
	end
  else
	if animator.hasSound("idleLoop") then
	  animator.stopAllSounds("idleLoop")
	  self.idleLoopPlaying = false
	end
	if animator.hasSound("holdLoop") then
	  animator.stopAllSounds("holdLoop")
	  self.holdLoopPlaying = false
	end
	if animator.hasSound("damageLoop") then
	  animator.stopAllSounds("damageLoop")
	  self.damageLoopPlaying = false
	end
  end
  
  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    self:setState(self.hold)
  end
end

function TheaChainSaw:hold()
  self.weapon:setStance(self.stances.hold)
  self.weapon:updateAim()
  
  if self.stances.hold.duration then
	self.minimumActiveTimer = self.stances.hold.duration
  end
  
  self.tileDamageTimer = 0
  
  while self.fireMode == "primary" or self.minimumActiveTimer > 0 do
    self.active = true
	
	local damageArea = partDamageArea("blade")
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
	
	self.tileDamageTimer = math.max(0, self.tileDamageTimer - self.dt)
    if self.tileDamageTimer == 0 then
      self.tileDamageTimer = self.fireTime
      self:damageTiles()
    end
	
	if self.energyUsage then
	  status.overConsumeResource("energy", self.energyUsage * self.dt)
	end
    coroutine.yield()
  end
  
  self.cooldownTimer = self.cooldownTime
  self.active = false
end

function TheaChainSaw:damageTiles()
  local pos = mcontroller.position()
  local tipPosition = vec2.add(pos, activeItem.handPosition(animator.partPoint("blade", "tipPosition")))
  local sourcePosition = vec2.add(pos, activeItem.handPosition(animator.partPoint("blade", "sourcePosition")))
  
  world.debugLine(sourcePosition, tipPosition, "yellow")
  self.damagingTiles = false
  
  for i = 1, 3 do
    local overlappingTiles = world.collisionBlocksAlongLine(sourcePosition, tipPosition, nil, self.damageTileDepth)
	local tileDamage = root.evalFunction("thea-chainsawMiningStrengthTimeMultiplier", config.getParameter("level", 1))
    if #overlappingTiles > 0 and tileDamage > 0 and self.tileDamage > 0 then
	  self.damagingTiles = true
      if self.damageForeground then
		world.damageTiles(overlappingTiles, "foreground", sourcePosition, "blockish", tileDamage, 99)
	  end
	  if self.damageBackground then
		world.damageTiles(overlappingTiles, "background", sourcePosition, "blockish", tileDamage, 99)
	  end
    else
	  self.damagingTiles = false
	end
  end
end

function TheaChainSaw:uninit()
  self.weapon:setDamage()
  
  if animator.hasSound("idleLoop") and self.active then
	animator.stopAllSounds("idleLoop")
  end
  if animator.hasSound("holdLoop") then
	animator.stopAllSounds("holdLoop")
  end
  if animator.hasSound("damageLoop") then
	animator.stopAllSounds("damageLoop")
  end
  
  animator.setParticleEmitterActive("miningSparks", false)
end
