require "/scripts/vec2.lua"

function init()
  self.wallPenetrations = config.getParameter("wallPenetrations", 1)
  self.maxPenetrationDistance = config.getParameter("maxPenetrationDistance", 1)
  self.damageTiles = config.getParameter("damageTiles", false)
  self.damageTileRadius = config.getParameter("damageTileRadius", 1)
  self.tileDamage = config.getParameter("tileDamage", 1000)
  self.harvestLevel = config.getParameter("harvestLevel", 0)
  self.penetrationActions = config.getParameter("penetrationActions", nil)
  
  self.penetrationDistance = 0
  self.penetrationsLeft = self.wallPenetrations
  self.isPenetrating = false
  self.tileDamageApplied = {} --This is a list so we can keep track of damage applied for every penetration
  
  self.startPosition = mcontroller.position()
  
  --Project the first entry position as soon as the projectile is created
  self.projectedEntryPosition = world.lineCollision(mcontroller.position(), vec2.add(mcontroller.position(), vec2.mul(vec2.norm(mcontroller.velocity()), 50)))
  
  script.setUpdateDelta(1) --Ensure the best possible update rate
end

function update(dt)
  --Near collision checks to see if we are inside a collision
  self.nearCollision = world.lineCollision(mcontroller.position(), vec2.add(mcontroller.position(), vec2.mul(vec2.norm(mcontroller.velocity()), 1)))
  self.nearCollisionBack = world.lineCollision(mcontroller.position(), vec2.add(mcontroller.position(), vec2.mul(vec2.norm(mcontroller.velocity()), -1)))
  
  if self.entryPosition and not self.exitPosition then
	self.projectedExitPosition = world.lineCollision(mcontroller.position(), vec2.add(mcontroller.position(), vec2.mul(vec2.norm(mcontroller.velocity()), -50)))
  end
  --============================== ENTRY/EXIT FUNCTIONS ==============================
  if self.projectedEntryPosition then
	--If we are past our projected entry point, the projected entry point is solidified as the actual entry point and we start penetrating
	if pastProjectedPoint(self.projectedEntryPosition) then
	  self.entryPosition = self.projectedEntryPosition
	  self.projectedEntryPosition = nil
	  self.exitPosition = nil
	  self.isPenetrating = true
	  self.penetrationsLeft = self.penetrationsLeft - 1
	  
	  --Optionally perform projectile actions on penetration
	  if self.penetrationActions then
		for _, action in pairs(self.penetrationActions) do
		  projectile.processAction(action)
		end
	  end
	  
	  --If the entry position is tile protected, prevent the projectile from penetrating
	  if world.isTileProtected(self.entryPosition) then
		self.penetrationsLeft = -1
		projectile.setPower(0)
	  end
	end
  end
  if self.projectedExitPosition then
	--If we are past our projected entry point, the projected entry point is solidified as the actual entry point and we start penetrating
	self.projectedEntryPosition = nil
	
	if pastProjectedPoint(self.projectedExitPosition) and not self.nearCollision then
	  self.exitPosition = self.projectedExitPosition
	  self.projectedExitPosition = nil
	  self.isPenetrating = false
	end
  end
  
  --============================== PROJECTION FUNCTIONS ==============================
  --Calculate projected entry and exit positions
  if not self.isPenetrating and not self.nearCollision then
	self.projectedEntryPosition = world.lineCollision(mcontroller.position(), vec2.add(mcontroller.position(), vec2.mul(vec2.norm(mcontroller.velocity()), 50)))
  end
  
  --============================== TILE DAMAGE FUNCTIONS ==============================  
  --Optionally destroy tiles
  if self.damageTiles and self.entryPosition and self.isPenetrating then
	local tilesAlongLine = world.collisionBlocksAlongLine(self.entryPosition, mcontroller.position()) or {}
	for _, tilePosition in ipairs(tilesAlongLine) do
	  world.damageTileArea(tilePosition, self.damageTileRadius, "foreground", self.entryPosition, "blockish", self.tileDamage, self.harvestLevel)
	  world.damageTileArea(tilePosition, self.damageTileRadius, "foreground", self.entryPosition, "blockish", self.tileDamage, self.harvestLevel)
	  self.tileDamageApplied[self.penetrationsLeft] = true
	end
  --If we have an entry and exit position but haven't damaged tiles yet (likely due to high velocity) perform the tile damage afterwards
  elseif self.damageTiles and self.entryPosition and self.exitPosition and not self.tileDamageApplied[self.penetrationsLeft] then
	local tilesAlongLine = world.collisionBlocksAlongLine(self.entryPosition, self.exitPosition) or {}
	for _, tilePosition in ipairs(tilesAlongLine) do
	  world.damageTileArea(tilePosition, self.damageTileRadius, "foreground", self.entryPosition, "blockish", self.tileDamage, self.harvestLevel)
	  world.damageTileArea(tilePosition, self.damageTileRadius, "foreground", self.entryPosition, "blockish", self.tileDamage, self.harvestLevel)
	  self.tileDamageApplied[self.penetrationsLeft] = true
	end
  end
  
  --============================== PROJECTILE DESTRUCTION FUNCTIONS ==============================
  if self.entryPosition then
	self.penetrationDistance = world.magnitude(self.entryPosition, self.exitPosition or mcontroller.position())
  end
  
  if self.penetrationDistance > self.maxPenetrationDistance or self.penetrationsLeft < 0 then
	projectile.die()
  end
  
  --============================== DEBUG FUNCTIONS ==============================
  --Debug projected positions
  if self.projectedEntryPosition then
	world.debugPoint(self.projectedEntryPosition, "cyan")
	world.debugText("PROJECTED ENTRY", self.projectedEntryPosition, "cyan")
	world.debugLine(mcontroller.position(), self.projectedEntryPosition, "cyan")
  end
  if self.projectedExitPosition then
	world.debugPoint(self.projectedExitPosition, "red")
	world.debugText("PROJECTED EXIT", self.projectedExitPosition, "red")
  end
  if self.entryPosition and self.projectedExitPosition then
	world.debugLine(self.entryPosition, self.projectedExitPosition, "red")
  end
  
  --Debug actual positions
  if self.entryPosition then
	world.debugPoint(self.entryPosition, "green")
	world.debugText("ENTRY", self.entryPosition, "green")
  end
  if self.exitPosition then
	world.debugPoint(self.exitPosition, "green")
	world.debugText("EXIT", self.exitPosition, "green")
  end
  if self.entryPosition and self.exitPosition then
	world.debugLine(self.entryPosition, self.exitPosition, "green")
  end
  
  --Debug distance
  world.debugText(self.penetrationDistance, mcontroller.position(), "yellow")
  
  world.debugPoint(self.startPosition, "pink")
  world.debugText("START", self.startPosition, "pink")
end

--Function to check if we are past the specified point
function pastProjectedPoint(point)
  local pastEntryPosX = false
  local pastEntryPosY = false
  
  if mcontroller.xVelocity() < 0 then
	if mcontroller.position()[1] < point[1] then
	  pastEntryPosX =  true
	end
  else
	if mcontroller.position()[1] > point[1] then
	  pastEntryPosX =  true
	end
  end
  
  if mcontroller.yVelocity() < 0 then
	if mcontroller.position()[2] < point[2] then
	  pastEntryPosY =  true
	end
  else
	if mcontroller.position()[2] > point[2] then
	  pastEntryPosY =  true
	end
  end
  
  --sb.logInfo("====================================")
  --sb.logInfo("MCPOS = {" .. mcontroller.position()[1] .. ", " .. mcontroller.position()[2] .. "}")
  --sb.logInfo("POINT = {" .. point[1] .. ", " .. point[2] .. "}")
  --sb.logInfo("Past Pos X = " .. sb.print(pastEntryPosX))
  --sb.logInfo("Past Pos Y = " .. sb.print(pastEntryPosY))
  --sb.logInfo("====================================")
  
  if pastEntryPosX and pastEntryPosY then
	return true
  else
	return false
  end
end

--Function that gets called on the projectile's death
function destroy()
  
end