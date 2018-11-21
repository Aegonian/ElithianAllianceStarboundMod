-- Melee primary ability
AkkimariChainSawNPC = WeaponAbility:new()

function AkkimariChainSawNPC:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime

  self.energyUsage = self.energyUsage or 0
  self.idleLoopPlaying = false
  self.holdLoopPlaying = false
  self.damageLoopPlaying = false
  self.active = false
  self.damagingTiles = false
  self.cooldownTimer = self.cooldownTime
  self.minimumActiveTimer = 0

  --NPC Behaviour Set-Up
  self.targetDetectionTime = 0
  self.miningCooldownTimer = 0
  
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
function AkkimariChainSawNPC:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  self.minimumActiveTimer = math.max(0, self.minimumActiveTimer - self.dt)
  
  animator.setParticleEmitterActive("miningSparks", self.damagingTiles)
  
  --============================== NPC BEHAVIOUR START ==============================
  --Check for our target material
  local materialPosition = vec2.add(mcontroller.position(), {self.materialCheckPosition[1] * mcontroller.facingDirection(), self.materialCheckPosition[2]})
  local material = world.material(materialPosition, "foreground")
  --world.debugText(sb.printJson(material), mcontroller.position(), "red")
  --world.debugPoint(materialPosition, "red")
  
  --Look for creatures within our detect distance
  local targets = world.entityQuery(mcontroller.position(), self.enemyDetectionRange, {
	withoutEntityId = activeItem.ownerEntityId(),
	includedTypes = {"creature"}
  })
  
  --For every entity found, check if we can damage it and have line of sight with it
  --Ignore targets if they are invisible
  for i,target in ipairs(targets) do
	if world.entityCanDamage(activeItem.ownerEntityId(), target) and not world.lineTileCollision(mcontroller.position(), world.entityPosition(target)) and not world.getProperty("entityinvisible" .. tostring(target)) then
	  self.targetDetectionTime = self.enemyDetectionTime
	end
  end
  
  --Count down the detection timer
  self.targetDetectionTime = math.max(0, self.targetDetectionTime - dt)
  self.miningCooldownTimer = math.max(0, self.miningCooldownTimer - dt)
  --world.debugText(self.targetDetectionTime, vec2.add(mcontroller.position(), {0,1}), "red")
  --world.debugText(self.miningCooldownTimer, vec2.add(mcontroller.position(), {0,2}), "red")
  --=============================== NPC BEHAVIOUR END ===============================

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
  
  --Regular attack behaviour
  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    self:setState(self.hold, false)
  
  --If no enemies are in range and target material was found, force the user to start mining
  elseif not self.weapon.currentAbility and self.miningCooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) and material == self.forceMiningMaterial and self.targetDetectionTime == 0 then
    self:setState(self.hold, true)
  end
end

function AkkimariChainSawNPC:hold(miningBehaviour)
  self.weapon:setStance(self.stances.hold)
  self.weapon:updateAim()
  
  if self.forceMiningTime and miningBehaviour then
	self.minimumActiveTimer = self.forceMiningTime
  elseif self.stances.hold.duration then
	self.minimumActiveTimer = self.stances.hold.duration
  end
  
  self.tileDamageTimer = 0
  
  while self.fireMode == "primary" or self.minimumActiveTimer > 0 and not (self.targetDetectionTime > 0 and miningBehaviour) do
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
	
	--Stop the user from moving if they are being forced to mine
	if miningBehaviour then
	  mcontroller.controlModifiers({ movementSuppressed = true })
	  world.debugText("I'm being forced into labour!", mcontroller.position(), "red")
	end
    coroutine.yield()
  end
  
  self.cooldownTimer = self.cooldownTime
  if miningBehaviour then
	self.miningCooldownTimer = self.forceMiningCooldownTime
  end
  self.active = false
end

function AkkimariChainSawNPC:damageTiles()
  local pos = mcontroller.position()
  local tipPosition = vec2.add(pos, activeItem.handPosition(animator.partPoint("blade", "tipPosition")))
  local sourcePosition = vec2.add(pos, activeItem.handPosition(animator.partPoint("blade", "sourcePosition")))
  
  world.debugLine(sourcePosition, tipPosition, "yellow")
  self.damagingTiles = false
  
  for i = 1, 3 do
    local overlappingTiles = world.collisionBlocksAlongLine(sourcePosition, tipPosition, nil, self.damageTileDepth)
	local tileDamage = root.evalFunction("thea-chainsawMiningStrengthTimeMultiplier", config.getParameter("level", 1))
    if #overlappingTiles > 0 then
	  self.damagingTiles = true
    else
	  self.damagingTiles = false
	end
  end
end

function AkkimariChainSawNPC:uninit()
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
