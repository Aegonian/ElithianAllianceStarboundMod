require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  animator.setParticleEmitterOffsetRegion("smoke", mcontroller.boundBox())
  animator.setParticleEmitterActive("smoke", true)
  effect.setParentDirectives(config.getParameter("directive"))
  
  --Check for damage taken in the init() step to ensure that damage taken before the status was applied won't get calculated for the damage increase
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  --Determine the size of the afflicted target to calculate how many blobs should spawn
  self.entitySize = 1
  local boundBox = mcontroller.boundBox()
  for i,coord in ipairs(boundBox) do
	if coord > self.entitySize then
	  self.entitySize = coord
	end
  end
  
  self.canRecordDamage = false
  self.totalDamage = 1
  self.spawnTimer = config.getParameter("timeBetweenBlobs")
  self.damageTimer = 1.0
  self.blobs = {}
  
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
  
  self.spawnTimer = math.max(0, self.spawnTimer - dt)
  self.damageTimer = math.max(0, self.damageTimer - dt)
  self.blobs = util.filter(self.blobs, world.entityExists)
  
  --If we haven't reached max blobs yet, create foreground and background blobs depending on the entityType (for correct renderLayers)
  if self.spawnTimer == 0 and #self.blobs < math.ceil(self.entitySize) then
	if entity.entityType() == "player" then
	  createBlob("ancientcurseblob-player")
	  createBlob("ancientcurseblob2-player")
	elseif entity.entityType() == "npc" then
	  createBlob("ancientcurseblob-npc")
	  createBlob("ancientcurseblob2-npc")
	else
	  createBlob("ancientcurseblob")
	  createBlob("ancientcurseblob2")
	end
	self.spawnTimer = config.getParameter("timeBetweenBlobs")
  end
  
  --Record all damage taken and update the blobs to match damage
  if self.canRecordDamage then
	for _, notification in ipairs(damageNotifications) do
	  if notification.damageSourceKind ~= "ancientcurseexplosion" then
		self.totalDamage = math.min(config.getParameter("maxExplosionDamage"), self.totalDamage + (notification.damageDealt * config.getParameter("damageInheritFactor")))
	  end
	end
  end
  for i,blob in ipairs(self.blobs) do
	world.callScriptedEntity(blob, "setDamage", self.totalDamage)
  end
  
  --If the afflicted target is submerged in the remnant liquid, deal damage every second
  if self.damageTimer == 0 and mcontroller.liquidId() == 131 and mcontroller.liquidPercentage() > 0.2 then
	status.applySelfDamageRequest({
	  damageType = "IgnoresDef",
	  damage = config.getParameter("liquidDamage"),
	  damageSourceKind = "ancientcurse",
	  sourceEntityId = entity.id()
	})
	self.damageTimer = 1.0
  end
  
  --If the afflicted target died while the effect is active, create the death projectiles
  if not status.resourcePositive("health") then
    effect.setParentDirectives(config.getParameter("deathDirective"))
	explode()
  end
  
  self.canRecordDamage = true
  world.debugText(sb.print(entity.entityType()), vec2.add(mcontroller.position(), {0,0}), "yellow")
  world.debugText(sb.print("Damage: " .. self.totalDamage), vec2.add(mcontroller.position(), {0,-1}), "yellow")
  world.debugText(sb.print("Size: " .. self.entitySize), vec2.add(mcontroller.position(), {0,-2}), "yellow")
end

function explode()
  if not self.exploded then
    world.spawnProjectile(config.getParameter("deathProjectileType"), mcontroller.position(), effect.sourceEntity() or entity.id(), {0, -1}, false)
    world.spawnProjectile(config.getParameter("deathProjectileType"), mcontroller.position(), effect.sourceEntity() or entity.id(), {1, 1}, false)
    world.spawnProjectile(config.getParameter("deathProjectileType"), mcontroller.position(), effect.sourceEntity() or entity.id(), {-1, 1}, false)
    self.exploded = true
  end
end

function createBlob(blobType)
  local boundBox = mcontroller.boundBox()
  local sector = math.random(1, 4)
  
  local projectileId = nil
  
  --Choose a random quadrant of the boundbox to spawn the blob in
  if sector == 1 then
	projectileId = world.spawnProjectile(blobType, vec2.add(mcontroller.position(), {math.random() * boundBox[1], math.random() * boundBox[2]}), entity.id(), {0,0}, true)
  elseif sector == 2 then
	projectileId = world.spawnProjectile(blobType, vec2.add(mcontroller.position(), {math.random() * boundBox[3], math.random() * boundBox[4]}), entity.id(), {0,0}, true)
  elseif sector == 3 then
	projectileId = world.spawnProjectile(blobType, vec2.add(mcontroller.position(), {math.random() * boundBox[1], math.random() * boundBox[4]}), entity.id(), {0,0}, true)
  elseif sector == 4 then
	projectileId = world.spawnProjectile(blobType, vec2.add(mcontroller.position(), {math.random() * boundBox[3], math.random() * boundBox[2]}), entity.id(), {0,0}, true)
  end
  world.callScriptedEntity(projectileId, "setParentEntity", entity.id()) --Set the projectile's parent entity so it will correctly destroy itself if the target dies
  
  table.insert(self.blobs, projectileId)
end

function uninit()
  for i,blob in ipairs(self.blobs) do
	world.callScriptedEntity(blob, "kill")
  end
end
