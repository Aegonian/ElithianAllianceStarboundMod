require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.gearSetType = config.getParameter("gearSetType")
  self.gearPiecesNeeded = config.getParameter("gearPiecesNeeded")
  
  script.setUpdateDelta(1)
end

function update(dt)
  --Perform this action once during update() to prevent abusing the /reload command to erroneously inflate the number of gear pieces equipped
  --If performed from init(), the stat gets increased with every reload, allowing a single gear piece to activate the set bonus
  if not self.setPieceRegistered then
	--Increases the configured playerStat by 1. Count this stat to find out how many gear pieces have been equipped
	self.statModifierGroup = effect.addStatModifierGroup({
	  {stat = self.gearSetType, amount = 1}
	})
	self.setPieceRegistered = true
  end
  
  --world.debugText("Gear Set '" .. self.gearSetType .. "' pieces equipped: " .. status.stat(self.gearSetType) .. " / " .. self.gearPiecesNeeded, vec2.add(mcontroller.position(), {-8,4}), "orange")
  
  if status.stat(self.gearSetType) >= self.gearPiecesNeeded then
	status.addEphemeralEffect(config.getParameter("setBonusEffect"), 0.1)
  end
end

function uninit()
  effect.removeStatModifierGroup(self.statModifierGroup)
  self.setPieceRegistered = false
end
