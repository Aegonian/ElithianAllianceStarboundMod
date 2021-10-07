require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/poly.lua"
require "/items/active/weapons/weapon.lua"

TheaParry = WeaponAbility:new()

function TheaParry:init()
  self.cooldownTimer = 0
end

function TheaParry:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)

  if self.weapon.currentAbility == nil
    and fireMode == "alt"
    and self.cooldownTimer == 0
    and status.overConsumeResource("energy", self.energyUsage) then

    self:setState(self.parry)
  end
end

function TheaParry:parry()
  self.weapon:setStance(self.stances.parry)
  self.weapon:updateAim()
  
  --Display the shield health bar
  status.setPersistentEffects("broadswordParry", {{stat = "shieldHealth", amount = 1000}})
  
  --Create a shield poly to block attacks
  local blockPoly = animator.partPoly("parryShield", "shieldPoly")
  activeItem.setItemShieldPolys({blockPoly})
  
  --Play the iniate guard stance sound
  animator.playSound("guard")
  
  --Set up a damagelistener for incoming blocked damage
  local damageListener = damageListener("damageTaken", function(notifications)
    for _,notification in pairs(notifications) do
      if notification.sourceEntityId ~= -65536 and notification.healthLost == 0 then
        animator.playSound("parry")
		world.spawnProjectile(self.deflectProjectileType, mcontroller.position(), activeItem.ownerEntityId(), {0, 0}, true)
		
		self:setState(self.preslash)
        return
      end
    end
  end)
  
  --Wait for incoming attacks
  util.wait(self.parryTime, function(dt)
    --Interrupt when running out of shield stamina
    if not status.resourcePositive("shieldStamina") then
	  return true
	end

    damageListener:update()
  end)
  
  --Reset the parry behaviour
  self.cooldownTimer = self.cooldownTime
  activeItem.setItemShieldPolys({})
end

--Brief frame before the parry attack
function TheaParry:preslash()
  self.weapon:setStance(self.stances.preslash)
  self.weapon:updateAim()

  util.wait(self.stances.preslash.duration)

  self:setState(self.fire)
end

--Parry attack
function TheaParry:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  animator.setAnimationState("altSwoosh", "fire")
  animator.playSound(self.fireSound or "riposte")

  util.wait(self.stances.fire.duration, function()
    local damageArea = partDamageArea("altSwoosh")
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
  end)

  self.cooldownTimer = self.successfulCooldownTime
end

function TheaParry:reset()
  status.clearPersistentEffects("broadswordParry")
  activeItem.setItemShieldPolys({})
end

function TheaParry:uninit()
  self:reset()
end
