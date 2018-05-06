require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/vec2.lua"
require "/scripts/poly.lua"

function init()
  self.debug = true

  self.aimAngle = 0
  self.aimDirection = 1

  self.active = false
  self.cooldownTimer = config.getParameter("cooldownTime")
  self.hitCooldownTimer = config.getParameter("hitCooldown")
  self.activeTimer = 0

  --Loading in config values
  self.knockback = config.getParameter("knockback", 0)
  self.energyUsagePerSecond = config.getParameter("energyUsagePerSecond", 0)
  self.energyUsagePerHit = config.getParameter("energyUsagePerHit", 0)
  self.minActiveTime = config.getParameter("minActiveTime", 0)
  self.cooldownTime = config.getParameter("cooldownTime")
  self.hitCooldownTime = config.getParameter("hitCooldown")
  self.forceWalk = config.getParameter("forceWalk", false)

  animator.setGlobalTag("directives", "")
  animator.setAnimationState("shield", "idle")
  activeItem.setOutsideOfHand(true)

  self.stances = config.getParameter("stances")
  setStance(self.stances.idle)

  updateAim()
end

function update(dt, fireMode, shiftHeld)
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  self.hitCooldownTimer = math.max(0, self.hitCooldownTimer - dt)

  --world.debugText("Shield is active? " .. sb.printJson(self.active), vec2.add(mcontroller.position(), {0,3}), "red")
  
  if not self.active
    and fireMode == "primary"
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy") then

    raiseShield()
  end

  if self.active then
    self.activeTimer = self.activeTimer + dt

	--Add the shield status effect. The forcefield must be rendered through a status effect to ensure that it is always rendered in front of the player, regardless of which hand the shield is held in
	status.addEphemeralEffect("centens-oculusshield-active")
	
	--Update our damage listener function
    self.damageListener:update()

	
	--Force the player to walk if so configured
    if self.forceWalk then
      mcontroller.controlModifiers({runningSuppressed = true})
    end

	--Consume energy every second
	status.overConsumeResource("energy", self.energyUsagePerSecond * dt)
	
	--If the shield runs out of energy, break it
	if not status.resourcePositive("energy") then
	  animator.playSound("break")
	  animator.burstParticleEmitter("break")
	  world.spawnProjectile("forceshieldexplosion-invisible", mcontroller.position(), activeItem.ownerEntityId(), {0, 0}, true)
	end
	
	--Lower the shield is we run out of energy or let go of the button
    if (fireMode ~= "primary" and self.activeTimer >= self.minActiveTime) or not status.resourcePositive("energy") then
      lowerShield()
    end
  else
	if status.resourceLocked("energy") or self.cooldownTimer > 0 then
	  animator.setAnimationState("shield", "cooldown")
	else
	  animator.setAnimationState("shield", "idle")
	end
  end
  
  updateAim()
end

function uninit()
  status.clearPersistentEffects(activeItem.hand().."Shield")
  activeItem.setItemShieldPolys({})
  activeItem.setItemDamageSources({})
end

function updateAim()
  local aimAngle, aimDirection = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())
  
  if self.stance.allowRotate then
    self.aimAngle = aimAngle
  end
  activeItem.setArmAngle(self.aimAngle + self.relativeArmRotation)

  if self.stance.allowFlip then
    self.aimDirection = aimDirection
  end
  activeItem.setFacingDirection(self.aimDirection)

  animator.setGlobalTag("hand", isNearHand() and "near" or "far")
  activeItem.setOutsideOfHand(not self.active or isNearHand())
  
  if isNearHand() then
	activeItem.setFrontArmFrame("swim.2")
  else
	activeItem.setBackArmFrame("swim.2")
  end
end

function isNearHand()
  return (activeItem.hand() == "primary") == (self.aimDirection < 0)
end

function setStance(stance)
  self.stance = stance
  self.relativeShieldRotation = util.toRadians(stance.shieldRotation) or 0
  self.relativeArmRotation = util.toRadians(stance.armRotation) or 0
end

function raiseShield()
  setStance(self.stances.raised)
  animator.setAnimationState("shield", "raised")
  animator.playSound("raiseShield")
  self.active = true
  self.activeTimer = 0
  
  --Rendering the shield health bar
  status.setPersistentEffects(activeItem.hand().."Shield", {{stat = "shieldHealth", amount = 1000}})
  
  local shieldPoly = config.getParameter("shieldPoly")
  shieldPoly = poly.translate(shieldPoly, config.getParameter("shieldPolyOffset"))
  activeItem.setItemShieldPolys({shieldPoly})

  if self.knockback > 0 then
    local knockbackDamageSource = {
      poly = shieldPoly,
      damage = 0,
      damageType = "Knockback",
      sourceEntity = activeItem.ownerEntityId(),
      team = activeItem.ownerTeam(),
      knockback = self.knockback,
      rayCheck = true,
      damageRepeatTimeout = 0.25
    }
    activeItem.setItemDamageSources({ knockbackDamageSource })
  end

  --Setting up the damage listener function. This functions gets updated while the shield is raised, and can play actions when the shield is hit
  self.damageListener = damageListener("damageTaken", function(notifications)
    for _,notification in pairs(notifications) do
      --If the shield was hit, play these actions
	  if notification.hitType == "ShieldHit" then
		--Consume some energy if the shield was hit
		if self.hitCooldownTimer == 0 then
		  status.overConsumeResource("energy", self.energyUsagePerHit)
		  self.hitCooldownTimer = self.hitCooldownTime
		end
		
		--sb.logInfo(sb.printJson(notification, 1))
		
		--Play a block of break sound depending on how much energy is left
		animator.playSound("block")
		
		--Set the shield into its block animation state
        animator.setAnimationState("shield", "block")
        return
      end
    end
  end)
end

function lowerShield()
  setStance(self.stances.idle)
  animator.setGlobalTag("directives", "")
  animator.setAnimationState("shield", "idle")
  animator.playSound("lowerShield")
  status.removeEphemeralEffect("centens-oculusshield-active")
  self.active = false
  self.activeTimer = 0
  status.clearPersistentEffects(activeItem.hand().."Shield")
  activeItem.setItemShieldPolys({})
  activeItem.setItemDamageSources({})
  self.cooldownTimer = self.cooldownTime
end
