require "/scripts/util.lua"
require "/scripts/status.lua"

-- Melee primary ability
TheaShieldBladeDefend = WeaponAbility:new()

function TheaShieldBladeDefend:init()
  self.cooldownTimer = 0
  
  self.shieldHealth = 1000
end

-- Ticks on every update regardless if this is the active ability
function TheaShieldBladeDefend:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  
  --Swap frames for when the weapon is in the front or back hand
  animator.setGlobalTag("hand", self.weapon:isFrontHand() and "front" or "back")

  if self.weapon.currentAbility == nil
    and fireMode == "alt"
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy") then

    self:setState(self.defend)
  end
end

function TheaShieldBladeDefend:defend()
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
		animator.playSound("shieldHit")
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
  
  while self.fireMode == "alt" and status.overConsumeResource("energy", self.energyUsage * self.dt) do
	self.weapon:updateAim()

	self.damageListener:update()
	
	coroutine.yield()
  end
end

function TheaShieldBladeDefend:reset()
  animator.setAnimationState("weapon", "idle")
  activeItem.setItemShieldPolys({})
  activeItem.setItemDamageSources({})
  status.clearPersistentEffects("broadswordParry")
end

function TheaShieldBladeDefend:uninit()
  self:reset()
end
