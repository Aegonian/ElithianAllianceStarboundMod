-- Melee primary ability
TheaChainSaw = WeaponAbility:new()

function TheaChainSaw:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime

  self.energyUsage = self.energyUsage or 0
  self.idleLoopPlaying = false
  self.holdLoopPlaying = false
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
  
  --world.debugText("Chainsaw Active? " .. sb.printJson(self.active), vec2.add(mcontroller.position(), {0,1}), "yellow")
  --world.debugText("Idle Loop Playing? " .. sb.printJson(self.idleLoopPlaying), vec2.add(mcontroller.position(), {0,2}), "yellow")
  --world.debugText("Hold Loop Playing? " .. sb.printJson(self.holdLoopPlaying), vec2.add(mcontroller.position(), {0,3}), "yellow")
  --world.debugText("Animation State : " .. sb.printJson(animator.animationState("blade")), vec2.add(mcontroller.position(), {0,4}), "yellow")

  --Play active and inactive looping sounds
  if animator.animationState("blade") == "active" then
	--If the weapon is active, play damage and hold sounds
	if self.active then
	  --If no hold loop sound is playing, activate them now
	  if not self.holdLoopPlaying then
		--If we have a holdLoop sound configured
		if animator.hasSound("holdLoop") then
		  animator.playSound("holdLoop", -1)
		  self.holdLoopPlaying = true
		end
		--If we have a damageLoop sound configured
		if animator.hasSound("damageLoop") then
		  animator.playSound("damageLoop", -1)
		  self.holdLoopPlaying = true
		end
	  --If a hold loop sound is already playing, adjust volumes based on whether or not we are damaging tiles
	  else
		if animator.hasSound("holdLoop") then
		  --If we are damaging tiles and have a damage loop sound configured
		  if self.damagingTiles and animator.hasSound("damageLoop") then
			animator.setSoundVolume("holdLoop", 0, 0)
			animator.setSoundVolume("damageLoop", 1, 0)
		  --If we aren't damaging any tiles or have no damage loop sound configured
		  else
			animator.setSoundVolume("holdLoop", 1, 0)
			if animator.hasSound("damageLoop") then
			  animator.setSoundVolume("damageLoop", 0, 0)
			end
		  end
		end
	  end
	  --If we are active and have and idleLoop sound, stop playing it
	  if animator.hasSound("idleLoop") then
		animator.stopAllSounds("idleLoop")
		self.idleLoopPlaying = false
	  end
	  
	--If the weapon is spinning but not active (no primaryFire), play idle loop sound and stop active sounds
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
  
  --If the weapon is not active, stop all sounds
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
	  self.holdLoopPlaying = false
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
  
  --self.tileDamageTimer = 0
  
  while self.fireMode == "primary" or self.minimumActiveTimer > 0 do
    self.active = true
	
	local damageArea = partDamageArea("blade")
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
	
	--self.tileDamageTimer = math.max(0, self.tileDamageTimer - self.dt)
    --if self.tileDamageTimer == 0 then
      --self.tileDamageTimer = self.fireTime
      self:damageTiles()
    --end
	
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
  --Create a list of positions to apply tile damage to. Include sourcePosition immediately as this position is static and not dynamically added
  local miningPositions = {sourcePosition}
  --Calculate tile damage per frame
  local tileDamage = root.evalFunction("thea-chainsawMiningStrengthTimeMultiplier", config.getParameter("level", 1)) * self.tileDamagePerSecond * self.dt
  
  --Reset damageTiles at the start of every frame
  self.damagingTiles = false
  
  --Calculate mining positions based on distance between configured tip and source positions
  for i = 1, world.magnitude(tipPosition, sourcePosition) do
	local distanceFactor = 1 / world.magnitude(tipPosition, sourcePosition)
	local position = vec2.add(vec2.mul(world.distance(tipPosition, sourcePosition), (distanceFactor * i)), sourcePosition)
	table.insert(miningPositions, position)
  end
  
  --For every calculated mining position, debug the vec2F position and the converted vec2I position. Also debug a line between sourcePosition and tipPosition
  world.debugLine(sourcePosition, tipPosition, "yellow")
  for _, pos in ipairs(miningPositions) do
	world.debugPoint(pos, "yellow")
	world.debugPoint({math.floor(pos[1]) + 0.5, math.floor(pos[2]) + 0.5}, "red")
  end
  
  --Optionally damage foreground tiles
  if self.damageForeground and tileDamage > 0 and self.tileDamagePerSecond > 0 then
	if world.damageTiles(miningPositions, "foreground", sourcePosition, "blockish", tileDamage, 99) then
	  self.damagingTiles = true
	end
  end
  
  --Optionally damage background tiles
  if self.damageBackground and tileDamage > 0 and self.tileDamagePerSecond > 0 then
	if world.damageTiles(miningPositions, "background", sourcePosition, "blockish", tileDamage, 99) then
	  self.damagingTiles = true
	end
  end
  
  --world.debugText("Tile damage this tick: " .. sb.printJson(tileDamage), vec2.add(mcontroller.position(), {0,5}), "yellow")
  --world.debugText("Tile damage per second: " .. sb.printJson(root.evalFunction("thea-chainsawMiningStrengthTimeMultiplier", config.getParameter("level", 1)) * self.tileDamagePerSecond), vec2.add(mcontroller.position(), {0,6}), "yellow")
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
