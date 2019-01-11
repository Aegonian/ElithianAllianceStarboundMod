function init()
  if not storage.itemHasSpawned then
    object.setInteractive(true)
    animator.setAnimationState("objectState", "filled")
	storage.itemHasSpawned = false
  else
    animator.setAnimationState("objectState", "empty")
	object.setInteractive(false)
  end
  
  self.spawnableItem = config.getParameter("spawnableItem")
  self.useFloatingObject = config.getParameter("useFloatingObject", false)
  self.floatingObjectCycle = config.getParameter("floatingObjectCycle", 1.0) / (2 * math.pi)
  self.floatingObjectMaxTransform = config.getParameter("floatingObjectMaxTransform", 1.0)
  self.timer = 0
  
  --Optionally reset the floating object transformation group
  if self.useFloatingObject then
	animator.resetTransformationGroup("floatingObject")
  end
end

function update(dt)
  --Optionally make the artefact float up and down
  if self.useFloatingObject then
	self.timer = self.timer + dt
	local offset = math.sin(self.timer / self.floatingObjectCycle) * self.floatingObjectMaxTransform
	
	animator.resetTransformationGroup("floatingObject")
	animator.translateTransformationGroup("floatingObject", {0, offset})
  end
end

function open()
  animator.setAnimationState("objectState", "empty")
  world.spawnItem(self.spawnableItem, entity.position(), 1)
  storage.itemHasSpawned = true
  object.setInteractive(false)
  
  --Make sure that, if the object is broken after having been collected, nothing drops
  object.setConfigParameter("breakDropPool", "empty")
end

function onInteraction(args)
  if storage.itemHasSpawned == false then
    open()
  end
end
