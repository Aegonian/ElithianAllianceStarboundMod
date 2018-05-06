require "/scripts/util.lua"

function init()
  self.crouchCorrected = false
  
  animator.setParticleEmitterOffsetRegion("particles", mcontroller.boundBox())
  animator.setParticleEmitterActive("particles", true)
  --effect.setParentDirectives("fade=000000=0.95?border=2;4800FF90;00000000")
  
  self.timer = config.getParameter("frequency")
end

function update(dt)
  --Code for correcting animation offset for crouching
  if mcontroller.crouching() and not self.crouchCorrected then
	animator.translateTransformationGroup("shield", {0, -1.0})
	self.crouchCorrected = true
  elseif not mcontroller.crouching() and self.crouchCorrected then
	animator.translateTransformationGroup("shield", {0, 1.0})
	self.crouchCorrected = false
  end
  
  self.timer = math.max(0, self.timer - dt)
  
  if self.timer == 0 then
	world.spawnProjectile("centensiangravityrepel", mcontroller.position(), 0, {0, 0}, false)
	self.timer = config.getParameter("frequency")
  end
end


function uninit()
end
