require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.worldProperty = config.getParameter("worldProperty")
  self.spawnItem = config.getParameter("spawnItem")
  self.spawnPosition = config.getParameter("spawnPosition")
  self.failTextProjectile = config.getParameter("failTextProjectile")
  self.failTextPosition = config.getParameter("failTextPosition")
  
  object.setInteractive(true)
end

function update(dt)
  world.debugPoint(vec2.add(entity.position(), self.spawnPosition), "yellow")
  world.debugPoint(vec2.add(entity.position(), self.failTextPosition), "white")
end

function onInteraction(args)
  local interactEntity = args.sourceId
  local entityReceivedItemToday = world.getProperty(self.worldProperty .. tostring(interactEntity))
  
  --If the player hasn't yet received our item today (checked using worldProperties), spawn the item now
  if not entityReceivedItemToday then
	world.spawnItem(self.spawnItem, vec2.add(entity.position(), self.spawnPosition))
	world.setProperty(self.worldProperty .. tostring(interactEntity), true)
  --If the player has already received our item, spawn a projectile that creates a text particle
  else
	world.spawnProjectile(self.failTextProjectile, vec2.add(entity.position(), self.failTextPosition))
  end
end
