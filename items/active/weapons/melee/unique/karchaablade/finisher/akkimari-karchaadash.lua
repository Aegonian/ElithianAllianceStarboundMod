require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

KarchaaDash = WeaponAbility:new()

function KarchaaDash:init()
  self.freezeTimer = 0

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
	self.weapon:updateAim()
  end
  
  self.queryDamageSince = 0
end

-- Ticks on every update regardless if this is the active ability
function KarchaaDash:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.freezeTimer = math.max(0, self.freezeTimer - self.dt)
  if self.freezeTimer > 0 and not mcontroller.onGround() then
    mcontroller.controlApproachVelocity({0, 0}, 1000)
  end

  if self.damageListener then
    self.damageListener:update()
  end
  
  --Check for inflicted hits and give us a status effect on a kill
  local damageNotifications, nextStep = status.inflictedDamageSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  for _, notification in ipairs(damageNotifications) do
	if notification.targetEntityId then
	  if notification.hitType == "Kill" and notification.damageSourceKind == self.damageConfig.damageSourceKind and world.entityType(notification.targetEntityId) == ("monster" or "npc") then
		--sb.logInfo("Got a kill")
		status.addEphemeralEffect("karchaafrenzy")
	  end
	end
	--local entityInfo = sb.printJson(world.entityType(notification.targetEntityId), 1)
	--sb.logInfo(entityInfo)
	--local info = sb.printJson(notification, 1)
	--sb.logInfo(info)
  end
  
  --If we are enraged and in idle, set custom idle stance
  if not self.weapon.currentAbility then
	if status.statusProperty("karchaafrenzy", 0) == 1 then
	  activeItem.emote("annoyed")
	  self.weapon:setStance(self.stances.enragedIdle)
	  self.weapon:updateAim()
	else
	  self.weapon:setStance(self.stances.idle)
	  self.weapon:updateAim()
	end
  end
end

-- used by fist weapon combo system
function KarchaaDash:startAttack()
  self:setState(self.windup)
  self.weapon:updateAim()

  self.weapon.freezesLeft = 0
  self.freezeTimer = self.freezeTime or 0
end

-- State: windup
function KarchaaDash:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()

  util.wait(self.stances.windup.duration)

  self:setState(self.windup2)
end

-- State: windup2
function KarchaaDash:windup2()
  self.weapon:setStance(self.stances.windup2)
  self.weapon:updateAim()

  util.wait(self.stances.windup2.duration)

  self:setState(self.dash)
end

-- State: special
function KarchaaDash:dash()
  self.weapon:setStance(self.stances.dash)
  self.weapon:updateAim()

  animator.setAnimationState("attack", "special")
  animator.playSound("special")

  status.addEphemeralEffect("invulnerable", self.stances.dash.duration + 0.1)

  if self.burstParticlesOnHit then
    self.damageListener = damageListener("inflictedDamage", function(notifications)
      for _, notification in pairs(notifications) do
        if notification.healthLost > 0 and notification.damageSourceKind == self.damageConfig.damageSourceKind then
          animator.burstParticleEmitter(self.burstParticlesOnHit)
          return
        end
      end
    end)
  end

  util.wait(self.stances.dash.duration, function()
    mcontroller.controlMove(mcontroller.facingDirection())
	
	local aimDirection = {mcontroller.facingDirection() * math.cos(self.weapon.aimAngle), math.sin(self.weapon.aimAngle)}
	local dashVector = vec2.mul(vec2.norm(aimDirection), self.stances.dash.velocity)
    mcontroller.controlApproachVelocity(dashVector, 2000)
	
	--world.debugLine(mcontroller.position(), vec2.add(mcontroller.position(), dashVector), "blue")
	--world.debugLine(mcontroller.position(), vec2.add(mcontroller.position(), aimDirection), "red")

    local damageArea = partDamageArea("specialswoosh")
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
  end)

  self.damageListener = nil

  local stopVelocity = vec2.mul(mcontroller.velocity(), self.retainVelocityFactor)
  mcontroller.setVelocity(stopVelocity)

  finishFistCombo()
  activeItem.callOtherHandScript("finishFistCombo")
  
  self.weapon:setStance(self.stances.idle)
  self.weapon:updateAim()
end

function KarchaaDash:uninit(unloaded)
  self.weapon:setDamage()
  if unloaded then
	status.removeEphemeralEffect("karchaafrenzy")
  end
end
