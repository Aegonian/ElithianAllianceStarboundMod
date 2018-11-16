function init()
  self.multiJumpCount = config.getParameter("multiJumpCount")
  self.multiJumpModifier = config.getParameter("multiJumpModifier")
  self.hoverTime = config.getParameter("hoverTime")
  self.hoverActivations = config.getParameter("hoverActivations")
  
  self.hoverTimer = self.hoverTime
  self.hoverActivationsLeft = self.hoverActivations
  self.wasHovering = false

  refreshJumps()
end

function update(args)
  local jumpActivated = args.moves["jump"] and not self.lastJump
  self.lastJump = args.moves["jump"]

  updateJumpModifier()

  --world.debugText("Hover activations left: " .. self.hoverActivationsLeft .. " --- Hover time left: " .. self.hoverTimer, mcontroller.position(), "red")
  
  if jumpActivated and canMultiJump() then
    doMultiJump()
  else
    --If we have run out of multijumps and are falling, enable the hover ability
	if self.lastJump
	  and self.multiJumps == 0
	  and mcontroller.yVelocity() <= 0
	  and not (mcontroller.groundMovement() or mcontroller.liquidMovement())
	  and self.hoverTimer > 0
	  and self.hoverActivationsLeft > -1 then
	  
		if not self.wasHovering then
		  self.wasHovering = true
		  self.hoverActivationsLeft = self.hoverActivationsLeft - 1
		  animator.playSound("hoverSound", -1)
		  animator.burstParticleEmitter("hoverBurst")
		elseif self.hoverActivationsLeft > -1 then
		  mcontroller.setYVelocity(0)
		  self.hoverTimer = math.max(self.hoverTimer - args.dt)
		  animator.setParticleEmitterActive("hoverLoop", true)
		end
		
	elseif mcontroller.groundMovement() or mcontroller.liquidMovement() then
      refreshJumps()
	  animator.setParticleEmitterActive("hoverLoop", false)
	  animator.stopAllSounds("hoverSound")
	else
	  self.wasHovering = false
	  animator.setParticleEmitterActive("hoverLoop", false)
	  animator.stopAllSounds("hoverSound")
	end
  end
end

-- after the original ground jump has finished, start applying the new jump modifier
function updateJumpModifier()
  if self.multiJumpModifier then
    if not self.applyJumpModifier
        and not mcontroller.jumping()
        and not mcontroller.groundMovement() then

      self.applyJumpModifier = true
    end

    if self.applyJumpModifier then mcontroller.controlModifiers({airJumpModifier = self.multiJumpModifier}) end
  end
end

function canMultiJump()
  return self.multiJumps > 0
      and not mcontroller.jumping()
      and not mcontroller.canJump()
      and not mcontroller.liquidMovement()
      and not status.statPositive("activeMovementAbilities")
      and math.abs(world.gravity(mcontroller.position())) > 0
end

function doMultiJump()
  mcontroller.controlJump(true)
  mcontroller.setYVelocity(math.max(0, mcontroller.yVelocity()))
  self.multiJumps = self.multiJumps - 1
  animator.burstParticleEmitter("multiJumpParticles")
  animator.playSound("multiJumpSound")
end

function refreshJumps()
  self.multiJumps = self.multiJumpCount
  self.applyJumpModifier = false
  
  --Reset the hover ability
  self.wasHovering = false
  self.hoverTimer = self.hoverTime
  self.hoverActivationsLeft = self.hoverActivations
end
