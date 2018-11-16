require "/scripts/util.lua"

function init()
  self.powerModifier = config.getParameter("powerModifier")
end

function update(dt)
  --While at full health, increase all damage output
  if status.resourcePercentage("health") == 1.0 then
	if not self.damageBoostApplied then
	  self.statModifier = effect.addStatModifierGroup({{stat = "powerMultiplier", effectiveMultiplier = self.powerModifier}})
	  self.damageBoostApplied = true
	end
  --If not at full health but the damage boost has already been applied, remove the damage boost
  elseif self.damageBoostApplied then
	effect.removeStatModifierGroup(self.statModifier)
	self.damageBoostApplied = false
  end
  
  --world.debugText(status.resourcePercentage("health"), mcontroller.position(), "red")
end

function uninit()
end
