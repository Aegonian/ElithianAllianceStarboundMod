function checkEventActive(event)
  local eventActive = false
  
  --Calculate current year by checking difference between timeStamps between now and the start of 2000
  --Must use this method as start time of os.time() is unknown and possibly variable, and os.date() is unavailable in Starbound's version of LUA
  local yearsSince2000 = (os.time() - os.time{year=2000, month=1, day=1, hour=0, sec=0}) / 31557600
  local yearsSinceYearStart = yearsSince2000 - math.floor(yearsSince2000)
  
  --Figure out if this year is a leap year
  local daysThisYear = 365
  local currentYear = math.floor(yearsSince2000 + 2000)
  local leapYear = checkLeapYear(currentYear)
  if leapYear then
	daysThisYear = 366
  end
  
  --Calculate current month and day of the year
  local currentMonth = math.ceil(yearsSinceYearStart * 12)
  local currentDay = math.ceil(yearsSinceYearStart * daysThisYear)
  
  --Read the event schedule config file to see when the specified event should be active
  local eventConfig = root.assetJson("/thea-eventschedules.config:" .. event)
  local eventStartDay = eventConfig.eventStartDay
  local eventEndDay = eventConfig.eventEndDay
  local eventActiveMonth = eventConfig.eventActiveMonth
  
  --Check if the current date matches the event dates
  if eventStartDay and eventEndDay then
	--If this is a leap year, and the start or end day is day 60 or later (February 29), increase start and/or end days by 1 to account for this leap day
	local finalStartDay = eventStartDay
	if finalStartDay >= 60 and checkLeapYear(currentYear) then
	  finalStartDay = eventStartDay + 1
	end
	local finalEndDay = eventEndDay
	if finalEndDay >= 60 and checkLeapYear(currentYear) then
	  finalEndDay = eventEndDay + 1
	end
	  
	--If the current day is in between start and end days, activate the event
	if currentDay >= finalStartDay and currentDay <= finalEndDay then
	  eventActive = true
	end
	
  --If no event days were passed on but an event month was, check if the current month matches the event month
  --Note that this function divides the year into 12 equally long months, and so actual start and end dates may not fully align with the intended month
  elseif eventActiveMonth then
	if currentMonth == eventActiveMonth then
	  eventActive = true
	end
  end
  
  --Return the results
  return eventActive, currentMonth, currentDay, leapYear
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
