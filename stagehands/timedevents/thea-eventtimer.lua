require "/scripts/rect.lua"
require "/scripts/util.lua"

function init()
  storage.spawnedNPC = storage.spawnedNPC or false
  self.npcSpecies = config.getParameter("npcSpecies")
  self.npcType = config.getParameter("npcType")
  self.npcLevel = config.getParameter("npcLevel") or world.threatLevel()
  
  self.eventStartDay = config.getParameter("eventStartDay")
  self.eventEndDay = config.getParameter("eventEndDay")
  self.eventActiveMonth = config.getParameter("eventActiveMonth")
  self.eventActive = false
  
  self.dieAfterSpawning = config.getParameter("stagehandDieAfterSpawning", true)
end

function update(dt)
  --If region is active, run time calculation functions
  if world.regionActive(regionCheckArea()) then
	--Calculate current year by checking difference between timeStamps between now and the start of 2000
	--Must use this method as start time of os.time() is unknown and likely variable, and os.date() is unavailable in Starbound's version of LUA
	local yearsSince2000 = (os.time() - os.time{year=2000, month=1, day=1, hour=0, sec=0}) / 31557600
	local yearsSinceYearStart = yearsSince2000 - math.floor(yearsSince2000)
	
	--Figure out if this year is a leap year
	local daysThisYear = 365
	local currentYear = math.floor(yearsSince2000 + 2000)
	world.debugText("Leap Year: " .. sb.print(checkLeapYear(currentYear)), vec2.add(entity.position(), {0,4}), "yellow")
	world.debugText("Year: " .. sb.print(currentYear), vec2.add(entity.position(), {0,3}), "yellow")
	if checkLeapYear(currentYear) then
	  daysThisYear = 366
	end
	
	--Calculate current month and day of the year
	local currentMonth = math.ceil(yearsSinceYearStart * 12)
	local currentDay = math.ceil(yearsSinceYearStart * daysThisYear)
	world.debugText("Month: " .. sb.print(currentMonth), vec2.add(entity.position(), {0,2}), "yellow")
	world.debugText("Day: " .. sb.print(currentDay), vec2.add(entity.position(), {0,1}), "yellow")
	
	--Check if the current date matches the event dates
	if self.eventStartDay and self.eventEndDay then
	  --If this is a leap year, and the start or end day is day 60 or later (February 29), increase start and/or end days by 1 to account for this leap day
	  local finalStartDay = self.eventStartDay
	  if finalStartDay >= 60 and checkLeapYear(currentYear) then
		finalStartDay = self.eventStartDay + 1
	  end
	  local finalEndDay = self.eventEndDay
	  if finalEndDay >= 60 and checkLeapYear(currentYear) then
		finalEndDay = self.eventEndDay + 1
	  end
	  
	  --If the current day is in between start and end days, activate the event
	  if currentDay >= finalStartDay and currentDay < finalEndDay then
		self.eventActive = true
	  end
	elseif self.eventActiveMonth then
	  --If the current month is the event month, activate the event
	  --Note that this function divides the year into 12 equally long months, and so actual start and end dates may not fully align with the intended month
	  if currentMonth == self.eventActiveMonth then
		self.eventActive = true
	  end
	end
  end
  
  --If the event is active and the NPC has not yet been spawned, do so now
  if self.eventActive and not storage.spawnedNPC then
	local species = util.randomChoice(self.npcSpecies)
	world.spawnNpc(entity.position(), species, self.npcType, self.npcLevel)
	storage.spawnedNPC = true
  end
  
  --If configured to die after spawning an NPC, do so here
  if storage.spawnedNPC and self.dieAfterSpawning then
	stagehand.die()
  end
  
  world.debugText("Event active: " .. sb.print(self.eventActive), entity.position(), "yellow")
end

--This function is used to calculate whether the current year is a leap year or not
function checkLeapYear(year)
  local isLeapYear = false
  
  --To check for leap years, see if the current year is evenly divisible by 4, then 100, then 400
  if (year % 4) == 0 then
	if (year % 100) == 0 then
	  if (year % 400) == 0 then
		isLeapYear = true
	  else
		isLeapYear = false
	  end
	else
	  isLeapYear = true
	end
  else
	isLeapYear = false
  end
  
  return isLeapYear
end

--This function is used to calculate a region around the stagehand position
--If this region is active/loaded, the rest of the stagehand behaviour can run
function regionCheckArea()
  local area = {-1, -1, 1, 1}
  local pos = entity.position()
  return {
	area[1] + pos[1],
	area[2] + pos[2],
	area[3] + pos[1],
	area[4] + pos[2]
  }
end
