require "/scripts/vec2.lua"

function init()
  self.searchDistance = config.getParameter("searchRadius")
  self.searchDelayAfterSticky = config.getParameter("searchDelayAfterSticky") or false
  
  if config.getParameter("searchStartDelay") ~= nil then
	self.searchEnabled = false
	self.countdownTimer = config.getParameter("searchStartDelay")
  else
	self.searchEnabled = true
  end
  
  if not config.getParameter("waitUntilSticky") then
	self.proximityEnabled = true
  else
	self.proximityEnabled = false
  end
end

function update(dt)
  if not self.collided then
	if projectile.collision() or mcontroller.isCollisionStuck() or mcontroller.isColliding() then
	  self.proximityEnabled = true
	  self.collided = true
	end
  end
  
  if self.searchEnabled == true then
	if self.proximityEnabled == true then
	  local targets = world.entityQuery(mcontroller.position(), self.searchDistance, {
		withoutEntityId = projectile.sourceEntity(),
		includedTypes = {"creature"},
		order = "nearest"
	  })

	  for _, target in ipairs(targets) do
		if entity.entityInSight(target) and world.entityCanDamage(projectile.sourceEntity(), target) then
		  projectile.die()
		  return
		end
	  end
	end
  else
	if self.searchDelayAfterSticky and self.collided then
	  self.countdownTimer = math.max(0, self.countdownTimer - dt)
	  if self.countdownTimer == 0 then
		self.searchEnabled = true
	  end
	elseif not self.searchDelayAfterSticky then
	  self.countdownTimer = math.max(0, self.countdownTimer - dt)
	  if self.countdownTimer == 0 then
		self.searchEnabled = true
	  end
	end
  end
  
  if config.getParameter("killOnParentDeath") and self.searchEnabled then
	if not world.entityExists(projectile.sourceEntity()) then
	  projectile.die()
	end
  end
end
