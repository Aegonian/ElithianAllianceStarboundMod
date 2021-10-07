require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  animator.setParticleEmitterOffsetRegion("smoke", mcontroller.boundBox())
  animator.setParticleEmitterActive("smoke", true)
  animator.setParticleEmitterOffsetRegion("streaks", mcontroller.boundBox())
  animator.setParticleEmitterActive("streaks", true)
  effect.setParentDirectives(config.getParameter("directive"))
  
  --Check for damage taken in the init() step to ensure that damage taken before the status was applied isn't taken into account
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  self.canRecordDamage = false
  self.damageInterval = config.getParameter("damageInterval")
  self.damageTimer = self.damageInterval
  
  self.damageTaken = 0
  
  animator.playSound("loop", -1)
  
  message.setHandler("ancientcursekill", function(_, _, delay)
	effect.modifyDuration(-effect.duration() + delay)
  end)
  
  script.setUpdateDelta(5)
end

function update(dt)  
  --Listen for damage taken
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  self.damageTimer = math.max(0, self.damageTimer - dt)
  
  --Deal damage every second
  if self.damageTimer == 0 then
	status.applySelfDamageRequest({
	  damageType = "IgnoresDef",
	  damage = config.getParameter("damagePerTick"),
	  damageSourceKind = "ancientcurse",
	  sourceEntityId = entity.id()
	})
	self.damageTimer = self.damageInterval
  end
  
  --Record all damage taken and activate curse if exceeding threshold
  if self.canRecordDamage then
	for _, notification in ipairs(damageNotifications) do
	  if notification.damageSourceKind ~= "ancientcurseexplosion" then
		self.damageTaken = self.damageTaken + notification.damageDealt
	  end
	end
	
	--Activate effect when over the threshold, then reset damage taken
	if self.damageTaken > config.getParameter("activationDamageThreshold") then
	  activateCurse()
	  self.damageTaken = 0
	end
  end
  
  --Prevent the afflicted target from using damage absorption shields
  if status.isResource("damageAbsorption") then
	status.setResource("damageAbsorption", 0)
  end
  
  --If the afflicted target died while the effect is active, create the death projectiles
  if not status.resourcePositive("health") then
    effect.setParentDirectives(config.getParameter("deathDirective"))
	explode()
  end
  
  self.canRecordDamage = true
end

function activateCurse()
  status.addEphemeralEffect(config.getParameter("transitionEffect"), config.getParameter("transitionEffectDuration", 5), effect.sourceEntity())
end

function explode()
  if not self.exploded then
    world.spawnProjectile(config.getParameter("deathProjectileType"), mcontroller.position(), effect.sourceEntity() or entity.id(), {0, -1}, false)
    world.spawnProjectile(config.getParameter("deathProjectileType"), mcontroller.position(), effect.sourceEntity() or entity.id(), {1, 1}, false)
    world.spawnProjectile(config.getParameter("deathProjectileType"), mcontroller.position(), effect.sourceEntity() or entity.id(), {-1, 1}, false)
    self.exploded = true
  end
end
