function init()
  effect.addStatModifierGroup({
	{stat = "energyRegenPercentageRate", amount = config.getParameter("regenBonusAmount", 1.25)},
	{stat = "energyRegenBlockTime", effectiveMultiplier = config.getParameter("regenBlockTime", 0.35)}
  })
  
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
end
function uninit()
end