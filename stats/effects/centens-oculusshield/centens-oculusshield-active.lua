function init()
  self.crouchCorrected = false
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
end

function onExpire()
  status.addEphemeralEffect("centens-oculusshield-break")
end