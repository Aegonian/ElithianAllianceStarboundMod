function init()
  animator.setParticleEmitterOffsetRegion("icetrail", mcontroller.boundBox())
  animator.setParticleEmitterActive("icetrail", true)
  effect.setParentDirectives("fade=00BBFF=0.85?border=2;00BBFF80;00000000")

  script.setUpdateDelta(5)
  
  if status.isResource("stunned") then
    status.setResource("stunned", math.max(status.resource("stunned"), effect.duration()))
  end
  animator.playSound("freezeSound")
  
  --Freeze the target's animation
  animator.setAnimationRate(0)
end

function update(dt)	
  --Prevent the freezing status effect from applying while this effect is active
  status.removeEphemeralEffect("frostlaserfreezing")
  
  --Prevent the target from moving
  mcontroller.controlModifiers({
	facingSuppressed = true,
	movementSuppressed = true
  })
  
  if effect.duration() <= 0.25 and not self.hasBrokenFree then
	animator.burstParticleEmitter("break")
	animator.playSound("breakSound")
	self.hasBrokenFree = true
 end
end

function onExpire()
  animator.setAnimationRate(1)
end
