function init()
  script.setUpdateDelta(3)
  
  self.lightPositionStanding = config.getParameter("lightPositionStanding")
  self.lightPositionCrouching = config.getParameter("lightPositionCrouching")
  
  --Set this to true so the game will correctly set the standing light position on init
  self.wasCrouching = true
end

function update(dt)
  animator.setFlipped(mcontroller.facingDirection() == -1)
  
  if mcontroller.crouching() then
	animator.setLightPosition("glow", self.lightPositionCrouching)
	animator.setLightPosition("beam", self.lightPositionCrouching)
	self.wasCrouching = true
  elseif not mcontroller.crouching() and self.wasCrouching == true then
	animator.setLightPosition("glow", self.lightPositionStanding)
	animator.setLightPosition("beam", self.lightPositionStanding)
	self.wasCrouching = false
  end
  
  sb.setLogMap("THEA - Active racial benefit", "EYELIGHTS")
end

function uninit()
  
end
