
function init()
  message.setHandler("checkPasscode", checkPasscode)
  self.interval = config.getParameter("interval")
  self.timer = 0
  object.setAllOutputNodes(false)
  
  --Sets an optional preset passcode, for use in generated dungeons
  self.defaultCode = config.getParameter("defaultCode")
  if self.defaultCode then
	storage.passcode = self.defaultCode
  end
  
  --If a passcode has been set, make this visible
  if storage.passcode then
	animator.setAnimationState("lockState", "locked")
  end
  
  object.setInteractive(true)
end

function update(dt)
  if self.timer > 0 then
    self.timer = math.max(0, self.timer - dt)

    if self.timer == 0 then
      object.setAllOutputNodes(false)
    end
  end
end

function checkPasscode(_, _, passcode)
  --If this is the first code we receive, save the code into the object's memory
  if not storage.passcode then
	storage.passcode = passcode
	animator.setAnimationState("lockState", "locked")
	animator.playSound("confirm")
	object.setAllOutputNodes(true)
	self.timer = self.interval
  --If the incoming code is the same as the code we have saved
  elseif storage.passcode == passcode then
	animator.playSound("confirm")
	object.setAllOutputNodes(true)
	self.timer = self.interval
  else
	animator.playSound("error")
	object.setAllOutputNodes(false)
  end
end
