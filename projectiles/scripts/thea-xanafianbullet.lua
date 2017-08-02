require "/scripts/vec2.lua"

function init()
  --self.targetSpeed = vec2.mag(mcontroller.velocity())
  self.targetSpeed = config.getParameter("speed")
  self.searchDistance = config.getParameter("searchRadius")
  self.controlForce = config.getParameter("baseHomingControlForce") * self.targetSpeed
  
  self.startingPosition = mcontroller.position()
  self.foundTarget = false
end

function update()
  local targets = world.entityQuery(mcontroller.position(), self.searchDistance, {
      withoutEntityId = projectile.sourceEntity(),
      includedTypes = {"creature"},
      order = "nearest"
    })

  for _, target in ipairs(targets) do
	if entity.entityInSight(target) and world.entityCanDamage(projectile.sourceEntity(), target) then
	  local targetPos = world.entityPosition(target)
	  local myPos = mcontroller.position()
	  local dist = world.distance(targetPos, myPos)

	  mcontroller.approachVelocity(vec2.mul(vec2.norm(dist), self.targetSpeed), self.controlForce)
	  self.foundTarget = true
	  return
    end
  end
  
  if self.foundTarget == false then
	local sourceEntityId = projectile.sourceEntity() or entity.id()
	local targetPos = world.entityPosition(sourceEntityId)
	local myPos = mcontroller.position()
	local dist = world.distance(targetPos, myPos)
	
	mcontroller.approachVelocity(vec2.mul(vec2.norm(dist), self.targetSpeed), self.controlForce)
  end
end