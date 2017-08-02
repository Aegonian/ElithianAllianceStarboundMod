require "/scripts/vec2.lua"

function init()
  self.fireOffset = config.getParameter("fireOffset")
  self.openingSoundIsPlaying = false
  self.openSoundHasPlayed = false
  
  animator.setAnimationState("treasurebox", "closed")
  
  --Code for setting the treasure's intended level, only runs the first time the object is generated
  if not config.getParameter("treasureLevel") then
	local targetLevel = 1
	if config.getParameter("useWorldLevel", false) then
	  targetLevel = world.threatLevel()
	else
	  targetLevel = config.getParameter("level", 1)
	end
	targetLevel = math.min(6, targetLevel) --Make sure the treasure level is never higher than 6
	activeItem.setInstanceValue("treasureLevel", targetLevel)
  end
  
  updateAim()
end

function update(dt, fireMode, shiftHeld)
  updateAim()
  
  local treasureLevel = config.getParameter("treasureLevel", 1)
  world.debugText(treasureLevel, mcontroller.position(), "red")

  --If pressing mouse button, activate opening animation and play sound
  if fireMode == "primary" and animator.animationState("treasurebox")~="open" and animator.animationState("treasurebox")~="opentransition" then
	if self.openingSoundIsPlaying == false then
	  animator.playSound("openLoop", -1)
	  self.openingSoundIsPlaying = true
	end
	animator.setAnimationState("treasurebox", "opening")
  --If the container is open, consume the item and give the player an item from the treasurepool
  elseif animator.animationState("treasurebox")=="open" then
	item.consume(1)
    if player then
	  local pool = config.getParameter("treasure.pool")
	  local level = treasureLevel
      local seed = config.getParameter("treasure.seed")
      local treasure = root.createTreasure(pool, level, seed)
      for _,item in pairs(treasure) do
		player.giveItem(item)
      end
	end
    return
  --If the mouse button isn't held, and the container isn't open, reset the animation and stop all sounds
  elseif animator.animationState("treasurebox")=="opentransition" then
    --Wait for animation to finish, play open sound and burst particles
	self.openingSoundIsPlaying = false
	if self.openSoundHasPlayed == false then
	  animator.stopAllSounds("openLoop")
	  animator.playSound("open")
	  animator.burstParticleEmitter("openPoof")
	  self.openSoundHasPlayed = true
	end
  else
    animator.setAnimationState("treasurebox", "closed")
	self.openingSoundIsPlaying = false
	animator.stopAllSounds("openLoop")
  end
end

function updateAim()
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(self.fireOffset[2], activeItem.ownerAimPosition())
  activeItem.setArmAngle(self.aimAngle)
  activeItem.setFacingDirection(self.aimDirection)
end

function firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end

function aimVector()
  local aimVector = vec2.rotate({1, 0}, self.aimAngle + sb.nrand(config.getParameter("inaccuracy", 0), 0))
  aimVector[1] = aimVector[1] * self.aimDirection
  return aimVector
end

function holdingItem()
  return true
end

function recoil()
  return false
end

function outsideOfHand()
  return false
end
