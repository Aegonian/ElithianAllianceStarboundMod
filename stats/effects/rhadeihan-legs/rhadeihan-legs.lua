require("/scripts/vec2.lua")

function init()  
  --Load in config values
  self.maxFallSpeed = config.getParameter("maxFallSpeed", -14)
  self.minFallTime = config.getParameter("minFallTime", 0.5)
  self.cooldownTimer = self.minFallTime
  
  --Disabling fall damage
  effect.addStatModifierGroup({
	{stat = "fallDamageMultiplier", effectiveMultiplier = 0}}
  )
end

function update(dt)
  animator.setFlipped(mcontroller.facingDirection() == -1)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  
  if mcontroller.falling() and not status.statPositive("activeMovementAbilities") then
	if self.cooldownTimer == 0 then
	  mcontroller.setYVelocity(math.max(mcontroller.yVelocity(), self.maxFallSpeed))
	  animator.setAnimationState("jets", "active")
	  animator.setLightActive("boosterGlow", true)
	else
	  animator.setAnimationState("jets", "off")
	  animator.setLightActive("boosterGlow", false)
	end
  else
	animator.setAnimationState("jets", "off")
	animator.setLightActive("boosterGlow", false)
	self.cooldownTimer = self.minFallTime
  end
end

function uninit()
end