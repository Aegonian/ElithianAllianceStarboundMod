function init()
end

function update(dt)
  if world.loungeableOccupied(entity.id()) then
	animator.setAnimationState("loungeState", "occupied")
  else
	animator.setAnimationState("loungeState", "empty")
  end
end
