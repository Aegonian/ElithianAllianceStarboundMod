function init()
  object.setInteractive(true)
  
  self.nextChatLine = 1
end

function onInteraction(args)
  local chatLines = config.getParameter("chatLines", {})
  
  --Say the next line on our list
  object.say(chatLines[self.nextChatLine])
  --Set the line to be said on the following interaction
  self.nextChatLine = self.nextChatLine + 1
  
  --If we reach the end of our list, return to the first line
  if self.nextChatLine > #chatLines then
	self.nextChatLine = 1
  end
end
