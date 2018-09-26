require "/scripts/vec2.lua"

function init()
  --self.targetSpeed = vec2.mag(mcontroller.velocity())
  self.targetSpeed = config.getParameter("speed")
  self.searchDistance = config.getParameter("searchRadius")
  self.controlForce = config.getParameter("baseHomingControlForce") * self.targetSpeed
end

function update()

  mcontroller.controlParameters({
       gravityMultiplier = -1
  })
  
  local targets = world.entityQuery(mcontroller.position(), self.searchDistance, {
      withoutEntityId = projectile.sourceEntity(),
      includedTypes = {"creature"},
      order = "nearest"
    })

  for _, target in ipairs(targets) do
    if entity.entityInSight(target) and world.entityCanDamage(projectile.sourceEntity(), target) and not (world.getProperty("entityinvisible" .. tostring(target)) and not config.getParameter("ignoreInvisibility", false)) then
      local targetPos = world.entityPosition(target)
      local myPos = mcontroller.position()
      local dist = world.distance(targetPos, myPos)

      mcontroller.approachVelocity(vec2.mul(vec2.norm(dist), self.targetSpeed), self.controlForce)
      return
    end
  end
end
