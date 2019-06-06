require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.minDistanceToGround = config.getParameter("minDistanceToGround")
  self.maxDistanceToCeiling = config.getParameter("maxDistanceToCeiling")
  self.hoverCorrectionSpeed = config.getParameter("hoverCorrectionSpeed")
  self.hoverCycleLength = config.getParameter("hoverCycleLength")
  self.hoverCycleDuration = config.getParameter("hoverCycleDuration")
  
  self.searchDistance = config.getParameter("searchDistance")
  self.projectileType = config.getParameter("projectileType")
  self.cooldownTime = config.getParameter("cooldownTime")
  
  self.cooldownTimer = self.cooldownTime
  self.timer = 0
  
  self.stablePositionFound = false
  
  mcontroller.setVelocity({0,0})
end

function update(dt)  
  mcontroller.setRotation(0)
  
  --TIMER FUNCTIONS
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  self.timer = self.timer + dt
  
  --HOVER CALCULATIONS
  local hoverCycleProgress = math.sin(self.timer / self.hoverCycleDuration)
  local closeToGround = world.lineCollision(mcontroller.position(), vec2.add(mcontroller.position(), {0, -self.minDistanceToGround}))
  local closeToCeiling = world.lineCollision(mcontroller.position(), vec2.add(mcontroller.position(), {0, self.maxDistanceToCeiling}))
  
  --HOVER FUNCTIONS
  --If we are close to the ceiling, fly down
  if closeToCeiling and not self.stablePositionFound then
	world.debugText("CEILING NEAR", vec2.add(mcontroller.position(), {0,0}), "yellow")
	mcontroller.setYVelocity(-self.hoverCorrectionSpeed)
	--If we are close to the ceiling and the ground both, there is no suitable position. Force us to hover up and down anyways
	if closeToGround then
	  self.stablePositionFound = true
	end
  --If we are close to the ground, fly up
  elseif closeToGround and not self.stablePositionFound then
	world.debugText("GROUND NEAR", vec2.add(mcontroller.position(), {0,0}), "yellow")
	mcontroller.setYVelocity(self.hoverCorrectionSpeed)
  --If we have a stable position, or no suitable position could be found, hover up and down
  else
	mcontroller.setYVelocity(hoverCycleProgress * self.hoverCycleLength)
	self.stablePositionFound = true
  end
  
  --FIRING FUNCTIONS
  --Firing is only available once we are in a stable hover position
  if self.cooldownTimer <= 0 and self.stablePositionFound then
    local targetIds = world.entityQuery(mcontroller.position(), self.searchDistance, {
      withoutEntityId = entity.id(),
      includedTypes = {"creature"}
    })
    shuffle(targetIds)

	--Filter through all found targets
    for i,id in ipairs(targetIds) do
      local sourceEntityId = projectile.sourceEntity() or entity.id()
      if world.entityCanDamage(sourceEntityId, id) and not world.lineTileCollision(mcontroller.position(), world.entityPosition(id)) then
        --Fire a projectile
		local sourceDamageTeam = world.entityDamageTeam(sourceEntityId)
        local directionTo = world.distance(world.entityPosition(id), mcontroller.position())
        world.spawnProjectile(
          self.projectileType,
          mcontroller.position(),
          sourceEntityId,
          directionTo,
          false,
          {
            power = projectile.power() * self.cooldownTime,
			powerMultiplier = projectile.powerMultiplier(),
            damageTeam = sourceDamageTeam
          }
        )
		self.cooldownTimer = self.cooldownTime
        return
      end
    end
  end
end