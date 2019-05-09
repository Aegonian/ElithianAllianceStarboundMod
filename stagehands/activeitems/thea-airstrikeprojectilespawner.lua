require "/scripts/rect.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.projectileList = config.getParameter("projectileList")
  if not self.projectileList then
	--sb.logInfo("INVALID CONFIG")
	stagehand.die()
  else
	--sb.logInfo("RECEIVED PROJECTILE LIST FROM AIRSTRIKE WEAPON")
	--sb.logInfo(sb.printJson(self.projectileList, 1))
  end
  
  --Calculate the projectile with the greatest delay, then use that as the stagehand's lifetime
  local maximumDelay = 0
  for i = 1, #self.projectileList do
	local projectileConfig = self.projectileList[i]
	if projectileConfig.delay > maximumDelay then
	  maximumDelay = projectileConfig.delay
	end
  end
  self.timer = math.min(config.getParameter("maximumLifeTime"), maximumDelay)
end

function update(dt)
  self.timer = math.max(0, self.timer - dt)
  
  for i = 1, #self.projectileList do
	local projectileConfig = self.projectileList[i]
	if not projectileConfig.hasSpawned then
	  world.debugPoint(projectileConfig.position, "green")
	  world.debugText(projectileConfig.delay, projectileConfig.position, "green")
	  world.debugLine(projectileConfig.position, vec2.add(projectileConfig.position, projectileConfig.direction), "green")
	else
	  world.debugPoint(projectileConfig.position, "red")
	end
	
	projectileConfig.delay = math.max(0, projectileConfig.delay - dt)
	
	if projectileConfig.delay == 0 and not projectileConfig.hasSpawned then
	  if not world.pointTileCollision(projectileConfig.position) then
		world.spawnProjectile(
		  projectileConfig.projectileType,
		  projectileConfig.position,
		  projectileConfig.ownerEntityId,
		  projectileConfig.direction,
		  false,
		  projectileConfig.params
		)
	  end
	  projectileConfig.hasSpawned = true
	end
  end
  
  world.debugText(self.timer, entity.position(), "yellow")
  if self.timer == 0 then
	stagehand.die()
  end
end
