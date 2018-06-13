require "/scripts/util.lua"
require "/scripts/companions/recruitspawner.lua"

function init()
  widget.setItemSlotItem("itmTradeItem", "alliancecrewcontract")
  self.tradeCount = 1
  
  update()
end

function update(dt)
  --Check if player has sufficient Tokens of Merit to complete the recruitment
  local playerItemCount = player.hasCountOfItem("alliancecrewcontract")
  local canRecruit = playerItemCount >= self.tradeCount
  local directive = canRecruit and "^green;"or"^red;"
  if playerItemCount > 99 then
    playerItemCount = "99+"
  end
  widget.setText("lblTradeItemQuantity", string.format("%s%s/%s", directive, playerItemCount, self.tradeCount))
  
  --Enable or disable the recruitment buttons, depending on the results of our previous checks
  widget.setButtonEnabled("btnRecruitCombat", canRecruit)
  widget.setButtonEnabled("btnRecruitMedic", canRecruit)
  widget.setButtonEnabled("btnRecruitEngineer", canRecruit)
  widget.setButtonEnabled("btnRecruitMechanic", canRecruit)
  widget.setButtonEnabled("btnRecruitJanitor", canRecruit)
  widget.setButtonEnabled("btnRecruitTailor", canRecruit)
end

function recruitCrewmemberCombat()
  if player.consumeItem({"alliancecrewcontract", self.tradeCount}) then
	world.sendEntityMessage(pane.sourceEntity(), "spawnCompanion", "combat")
  end
  pane.dismiss()
end

function recruitCrewmemberMedic()
  if player.consumeItem({"alliancecrewcontract", self.tradeCount}) then
	world.sendEntityMessage(pane.sourceEntity(), "spawnCompanion", "medic")
  end
  pane.dismiss()
end

function recruitCrewmemberEngineer()
  if player.consumeItem({"alliancecrewcontract", self.tradeCount}) then
	world.sendEntityMessage(pane.sourceEntity(), "spawnCompanion", "engineer")
  end
  pane.dismiss()
end

function recruitCrewmemberMechanic()
  if player.consumeItem({"alliancecrewcontract", self.tradeCount}) then
	world.sendEntityMessage(pane.sourceEntity(), "spawnCompanion", "mechanic")
  end
  pane.dismiss()
end

function recruitCrewmemberJanitor()
  if player.consumeItem({"alliancecrewcontract", self.tradeCount}) then
	world.sendEntityMessage(pane.sourceEntity(), "spawnCompanion", "janitor")
  end
  pane.dismiss()
end

function recruitCrewmemberTailor()
  if player.consumeItem({"alliancecrewcontract", self.tradeCount}) then
	world.sendEntityMessage(pane.sourceEntity(), "spawnCompanion", "tailor")
  end
  pane.dismiss()
end
