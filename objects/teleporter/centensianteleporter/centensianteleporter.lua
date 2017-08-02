require "/scripts/util.lua"

function init()
  self.detectArea = config.getParameter("detectArea")
  self.detectArea[1] = object.toAbsolutePosition(self.detectArea[1])
  self.detectArea[2] = object.toAbsolutePosition(self.detectArea[2])
end

function update(dt)
  local players = world.entityQuery(self.detectArea[1], self.detectArea[2], {
	includedTypes = {"player"},
	boundMode = "CollisionArea"
  })

  if #players > 0 and animator.animationState("portal") == "closed" then
	animator.setAnimationState("portal", "open")
  elseif #players == 0 and animator.animationState("portal") == "openloop" then
	animator.setAnimationState("portal", "close")
  end
end
