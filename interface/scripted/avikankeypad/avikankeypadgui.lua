require "/scripts/util.lua"

function init()
  self.slotOne = nil
  self.slotTwo = nil
  self.slotThree = nil
  self.slotFour = nil
  self.slotFive = nil
  self.totalNumbers = 0
  self.passcode = "-----"
  
  update()
end

function update(dt)
  --Code for enabling and disabling the confirm button
  if self.totalNumbers == 5 then
	widget.setButtonEnabled("btnConfirm", true)
  else
	widget.setButtonEnabled("btnConfirm", false)
  end
end

function updateSlots()
  --Slot One
  if self.slotOne == nil then
	widget.setImage("scrnSlot1", "/interface/scripted/avikankeypad/screen_empty.png")
  else
	widget.setImage("scrnSlot1", "/interface/scripted/avikankeypad/screen_"..self.slotOne..".png")
  end
  --Slot Two
  if self.slotTwo == nil then
	widget.setImage("scrnSlot2", "/interface/scripted/avikankeypad/screen_empty.png")
  else
	widget.setImage("scrnSlot2", "/interface/scripted/avikankeypad/screen_"..self.slotTwo..".png")
  end
  --Slot Three
  if self.slotThree == nil then
	widget.setImage("scrnSlot3", "/interface/scripted/avikankeypad/screen_empty.png")
  else
	widget.setImage("scrnSlot3", "/interface/scripted/avikankeypad/screen_"..self.slotThree..".png")
  end
  --Slot Four
  if self.slotFour == nil then
	widget.setImage("scrnSlot4", "/interface/scripted/avikankeypad/screen_empty.png")
  else
	widget.setImage("scrnSlot4", "/interface/scripted/avikankeypad/screen_"..self.slotFour..".png")
  end
  --Slot Five
  if self.slotFive == nil then
	widget.setImage("scrnSlot5", "/interface/scripted/avikankeypad/screen_empty.png")
  else
	widget.setImage("scrnSlot5", "/interface/scripted/avikankeypad/screen_"..self.slotFive..".png")
  end
  
  --Build the passcode string
  --If any of the number hasn't been entered yet, set the string to "-----"
  if not self.slotOne == nil and
	 not self.slotTwo == nil and
	 not self.slotThree == nil and
	 not self.slotFour == nil and
	 not self.slotFive == nil then
	
	self.passcode = self.slotOne..self.slotTwo..self.slotThree..self.slotFour..self.slotFive
  else
	self.passcode = "-----"
  end
end

--Send the assembled passcode to the keypad object for checking, then close the GUI
function buttonConfirm()
  --Build the passcode string
  --If any of the number hasn't been entered yet, set the string to "-----"
  if self.totalNumbers == 5 then
	self.passcode = self.slotOne..self.slotTwo..self.slotThree..self.slotFour..self.slotFive
  else
	self.passcode = "-----"
  end
  world.sendEntityMessage(pane.sourceEntity(), "checkPasscode", self.passcode)
  sb.logInfo("A player has entered a passcode "..self.passcode)
  pane.dismiss()
end

--Reset all slots, the assembled passcode and the number count
function buttonClear()
  self.slotOne = nil
  self.slotTwo = nil
  self.slotThree = nil
  self.slotFour = nil
  self.slotFive = nil
  self.totalNumbers = 0
  self.passcode = "-----"
  
  updateSlots()
end

function buttonNumber1()  
  if self.totalNumbers == 0 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotOne = 1
  elseif self.totalNumbers == 1 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotTwo = 1
  elseif self.totalNumbers == 2 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotThree = 1
  elseif self.totalNumbers == 3 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFour = 1
  elseif self.totalNumbers == 4 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFive = 1
  end  
  updateSlots()
end

function buttonNumber2()  
  if self.totalNumbers == 0 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotOne = 2
  elseif self.totalNumbers == 1 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotTwo = 2
  elseif self.totalNumbers == 2 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotThree = 2
  elseif self.totalNumbers == 3 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFour = 2
  elseif self.totalNumbers == 4 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFive = 2
  end  
  updateSlots()
end

function buttonNumber3()  
  if self.totalNumbers == 0 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotOne = 3
  elseif self.totalNumbers == 1 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotTwo = 3
  elseif self.totalNumbers == 2 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotThree = 3
  elseif self.totalNumbers == 3 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFour = 3
  elseif self.totalNumbers == 4 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFive = 3
  end  
  updateSlots()
end

function buttonNumber4()  
  if self.totalNumbers == 0 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotOne = 4
  elseif self.totalNumbers == 1 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotTwo = 4
  elseif self.totalNumbers == 2 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotThree = 4
  elseif self.totalNumbers == 3 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFour = 4
  elseif self.totalNumbers == 4 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFive = 4
  end  
  updateSlots()
end

function buttonNumber5()  
  if self.totalNumbers == 0 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotOne = 5
  elseif self.totalNumbers == 1 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotTwo = 5
  elseif self.totalNumbers == 2 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotThree = 5
  elseif self.totalNumbers == 3 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFour = 5
  elseif self.totalNumbers == 4 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFive = 5
  end  
  updateSlots()
end

function buttonNumber6()  
  if self.totalNumbers == 0 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotOne = 6
  elseif self.totalNumbers == 1 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotTwo = 6
  elseif self.totalNumbers == 2 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotThree = 6
  elseif self.totalNumbers == 3 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFour = 6
  elseif self.totalNumbers == 4 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFive = 6
  end  
  updateSlots()
end

function buttonNumber7()  
  if self.totalNumbers == 0 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotOne = 7
  elseif self.totalNumbers == 1 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotTwo = 7
  elseif self.totalNumbers == 2 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotThree = 7
  elseif self.totalNumbers == 3 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFour = 7
  elseif self.totalNumbers == 4 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFive = 7
  end  
  updateSlots()
end

function buttonNumber8()  
  if self.totalNumbers == 0 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotOne = 8
  elseif self.totalNumbers == 1 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotTwo = 8
  elseif self.totalNumbers == 2 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotThree = 8
  elseif self.totalNumbers == 3 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFour = 8
  elseif self.totalNumbers == 4 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFive = 8
  end  
  updateSlots()
end

function buttonNumber9()  
  if self.totalNumbers == 0 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotOne = 9
  elseif self.totalNumbers == 1 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotTwo = 9
  elseif self.totalNumbers == 2 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotThree = 9
  elseif self.totalNumbers == 3 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFour = 9
  elseif self.totalNumbers == 4 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFive = 9
  end  
  updateSlots()
end

function buttonNumber0()  
  if self.totalNumbers == 0 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotOne = 0
  elseif self.totalNumbers == 1 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotTwo = 0
  elseif self.totalNumbers == 2 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotThree = 0
  elseif self.totalNumbers == 3 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFour = 0
  elseif self.totalNumbers == 4 then
	self.totalNumbers = self.totalNumbers + 1
	self.slotFive = 0
  end  
  updateSlots()
end