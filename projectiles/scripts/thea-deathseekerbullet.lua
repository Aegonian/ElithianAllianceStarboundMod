require "/scripts/vec2.lua"

function init()
  self.targetSpeed = vec2.mag(mcontroller.velocity())
  self.searchDistance = config.getParameter("searchRadius")
  self.controlForce = config.getParameter("baseHomingControlForce") * self.targetSpeed
  
  if config.getParameter("randomTimeToLive") ~= nil then
	local minLifeTime = config.getParameter("minLifeTime")
	local maxLifeTime = config.getParameter("maxLifeTime")
	local lifeTime = math.random(minLifeTime, maxLifeTime)
	projectile.setTimeToLive(lifeTime/100)
  end
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
      return
    end
  end
  
  --Return to regular speed if we speed up too much
  if vec2.mag(mcontroller.velocity()) > self.targetSpeed then
	local currentVector = mcontroller.velocity()
	local targetVector = vec2.mul(vec2.norm(currentVector), self.targetSpeed)
	mcontroller.approachVelocity(targetVector, 20)
  end
end
