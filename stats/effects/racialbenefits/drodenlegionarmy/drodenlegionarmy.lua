require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/vec2.lua"

function init()
  --Loading config values
  self.powerModifierPerCrewmember = config.getParameter("powerModifierPerCrewmember", 1.0)
  self.timeBetweenRequests = config.getParameter("timeBetweenRequests", 1.0)
  
  --Setting modifiers
  self.statModifierGroup = effect.addStatModifierGroup({
	{stat = "powerMultiplier", effectiveMultiplier = 1.0}
  })
  
  --General values
  self.cooldownTimer = 0
  self.drodenCrewmemberCount = 0
  self.promiseCompleted = true
end


function update(dt)
  if entity.entityType() == "player" then
	--Request a list of companion followers the player has
	if not self.playerCompanionsPromise and self.cooldownTimer == 0 then
	  self.promiseCompleted = false
	  self.playerCompanionsPromise = world.sendEntityMessage(entity.id(), "theaRequestCompanions")
	  if self.playerCompanionsPromise then
		--If the request has finished
		if self.playerCompanionsPromise:finished() then
		  local messageResult = self.playerCompanionsPromise:result()
		  if messageResult then			
			--sb.logInfo(sb.printJson(messageResult, 1))
			--For every item in the message result (i.e. every companion the player has) check the species. If Droden, count up our counter
			self.drodenCrewmemberCount = 0
			for _, playerCompanion in ipairs(messageResult) do
			  local species = playerCompanion.config.species
			  if species and species == "droden" then
				self.drodenCrewmemberCount = math.min(2, self.drodenCrewmemberCount + 1)
			  end
			end
			self.cooldownTimer = self.timeBetweenRequests
		  end
		end
	  end
	end
	
	--Count down a timer to reset the request (prevents straining the CPU with frequent requests)
	self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
	if self.cooldownTimer == 0 then
	  self.playerCompanionsPromise = nil
	end
	
	--If we have any Droden followers, increase our damage output. Otherwise, reset it
	if self.drodenCrewmemberCount > 0 then
	  effect.setStatModifierGroup(self.statModifierGroup, {
		{stat = "powerMultiplier", effectiveMultiplier  = 1 + (self.powerModifierPerCrewmember * self.drodenCrewmemberCount)}
	  })
	else
	  effect.setStatModifierGroup(self.statModifierGroup, {
		{stat = "powerMultiplier", effectiveMultiplier  = 1.0}
	  })
	end
  end
  
  --world.debugText("Droden Crewmembers: " .. self.drodenCrewmemberCount, vec2.add(mcontroller.position(), {0,1}), "yellow")
  --world.debugText("Cooldown: " .. self.cooldownTimer, vec2.add(mcontroller.position(), {0,2}), "yellow")
end

function uninit()
  effect.removeStatModifierGroup(self.statModifierGroup)
end
