function init()
  self.crouchCorrected = false
  
  --Code for correcting animation offset for crouching
  --Perform this in init as well to correct the position immediately and prevent a stutter
  if mcontroller.crouching() and not self.crouchCorrected then
	animator.translateTransformationGroup("shield", {0, -1.0})
	self.crouchCorrected = true
  elseif not mcontroller.crouching() and self.crouchCorrected then
	animator.translateTransformationGroup("shield", {0, 1.0})
	self.crouchCorrected = false
  end
  
  self.startingColour = {72, 108, 128}
  self.fadeTime = 0.8
  animator.setLightColor("glow", self.startingColour)
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
  
  --Code for fading out the light
  local factor = effect.duration() / self.fadeTime
  local updatedColourR = self.startingColour[1] * factor
  local updatedColourG = self.startingColour[2] * factor
  local updatedColourB = self.startingColour[3] * factor
  local updatedColour = {updatedColourR, updatedColourG, updatedColourB}
  
  animator.setLightColor("glow", updatedColour)
end