require "/scripts/vec2.lua"

function init()
  self.timeToLive = config.getParameter("timeToLive")
  self.lifeTimer = 0
  self.loopSoundPlaying = false
  
  vehicle.setInteractive(false)
end

function update()
  self.lifeTimer = math.min(self.timeToLive, self.lifeTimer + script.updateDt())
  
  --Set collision based on animation state
  if animator.animationState("body") == "idle" then
	vehicle.setMovingCollisionEnabled("block", true)
  else
	vehicle.setMovingCollisionEnabled("block", false)
  end
  
  --Sound effects
  if not self.loopSoundPlaying then
	animator.playSound("idleLoop", -1)
	self.loopSoundPlaying = true
  end
  
  --If we have exceeded our life time, start despawn sequence
  if self.lifeTimer >= self.timeToLive and animator.animationState("body") == "idle" then
	animator.setAnimationState("body", "despawn")
	animator.playSound("despawn")
	animator.stopAllSounds("idleLoop")
  end
  
  --If animation state is set to invisible, destroy the vehicle
  if animator.animationState("body") == "invisible" then
	vehicle.destroy()
  end
  
  --Debug values
  world.debugText(self.lifeTimer, mcontroller.position(), "yellow")
end
