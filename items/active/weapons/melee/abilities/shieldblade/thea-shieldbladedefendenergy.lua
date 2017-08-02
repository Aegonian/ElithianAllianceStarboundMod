require "/scripts/util.lua"
require "/scripts/status.lua"

-- Melee primary ability
TheaShieldBladeDefendEnergy = WeaponAbility:new()

function TheaShieldBladeDefendEnergy:init()
  self.cooldownTimer = 0
  self.blastCooldownTimer = 0
  self.wasActive = false
  
  self.shieldHealth = 1000
end

-- Ticks on every update regardless if this is the active ability
function TheaShieldBladeDefendEnergy:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  self.blastCooldownTimer = math.max(0, self.blastCooldownTimer - dt)
  
  --Swap frames for when the weapon is in the front or back hand
  animator.setGlobalTag("hand", self.weapon:isFrontHand() and "front" or "back")

  if self.weapon.currentAbility == nil
    and fireMode == "alt"
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy") then

    self:setState(self.defend)
  end
end

function TheaShieldBladeDefendEnergy:defend()
  self.weapon:setStance(self.stances.defendwindup)
  self.weapon:updateAim()
  
  --Shield animations
  animator.setAnimationState("weapon", "defend")
  animator.playSound("raiseShield")
  
  --Shield windup animation
  util.wait(self.stances.defendwindup.duration)
  self.weapon:setStance(self.stances.defend)
  
  self.weapon:updateAim()
  
  --Create the shielding poly
  local shieldPoly = animator.partPoly("blade", "shieldPoly")
  activeItem.setItemShieldPolys({shieldPoly})
  
  --Seting up the damage listener for actions on shield hit
  self.damageListener = damageListener("damageTaken", function(notifications)
	for _,notification in pairs(notifications) do
	  if notification.hitType == "ShieldHit" then		  
		--Fire a projectile when the shield is hit
		if self.blastCooldownTimer == 0 then
		  --Projectile parameters
		  local params = copy(self.projectileParameters)
		  params.power = self.baseDamage * config.getParameter("damageLevelMultiplier")
		  params.powerMultiplier = activeItem.ownerPowerMultiplier()
			
		  --Projectile spawn code
		  local position = vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("blade", "blastPoint")))
		  local aim = self.weapon.aimAngle
		  if not world.lineTileCollision(mcontroller.position(), position) then
			world.spawnProjectile(self.projectileType, position, activeItem.ownerEntityId(), {mcontroller.facingDirection() * math.cos(aim), math.sin(aim)}, false, params)
			animator.playSound("shieldBurst")
			animator.burstParticleEmitter("burst")
			self.blastCooldownTimer = self.blastCooldownTime
		  else
			animator.playSound("shieldHit")
		  end
		else
		  animator.playSound("shieldHit")
		end
		return
	  end
	end
  end)
  
  --Sets up the knockback for enemies running into the shield
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

  --Rendering the shield health bar
  status.setPersistentEffects("broadswordParry", {{stat = "shieldHealth", amount = self.shieldHealth}})
  
  self.wasActive = true
  
  while self.fireMode == "alt" and status.overConsumeResource("energy", self.energyUsage * self.dt) do
	self.weapon:updateAim()
	
	self.damageListener:update()
	
	coroutine.yield()
  end
end

function TheaShieldBladeDefendEnergy:reset()
  if self.wasActive == true then
	animator.setAnimationState("weapon", "activate")
  else
	animator.setAnimationState("weapon", "idle")
  end
  self.wasActive = false
  activeItem.setItemShieldPolys({})
  activeItem.setItemDamageSources({})
  status.clearPersistentEffects("broadswordParry")
end

function TheaShieldBladeDefendEnergy:uninit()
  self:reset()
end
