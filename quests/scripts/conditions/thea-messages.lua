function buildMonsterKillCondition(config)
  --Set up the monster kill condition
  local monsterKillCondition = {
    description = config.description or root.assetJson("/quests/quests.config:objectiveDescriptions.theaMonsterKill"),
    monsterName = config.displayMonsterName,
    targetMessage = config.targetMessage,
    count = config.count or 1
  }

  --Set up the function that will get called when we receive our target message
  function monsterKillCondition:onMessageReceived(message, isLocal, objectName)
    storage.theaMonsterKillMessageCount = storage.theaMonsterKillMessageCount + 1
  end
  
  --Set up the function for checking if the conditions were met
  function monsterKillCondition:conditionMet()
    return storage.theaMonsterKillMessageCount >= self.count
  end

  --Set up the function for performing actions upon quest complete
  --These get called in addition to the default quest complete actions, and so should only contain actions relative to the objective
  function monsterKillCondition:onQuestComplete()
    --Nothing here!
  end

  --Set up the function for constructing the objective text
  function monsterKillCondition:objectiveText()
    local objective = self.description
    objective = objective:gsub("<monsterName>", self.monsterName)
    objective = objective:gsub("<required>", self.count)
    objective = objective:gsub("<current>", storage.theaMonsterKillMessageCount or 0)
    return objective
  end

  --Remember how many messages we have already received
  storage.theaMonsterKillMessageCount = storage.theaMonsterKillMessageCount or 0
  
  --sb.logInfo("======================== TEST ========================")
  --sb.logInfo("SELF =")
  --sb.logInfo(sb.printJson(self, 1))
  --sb.logInfo("STORAGE =")
  --sb.logInfo(sb.printJson(storage, 1))
  --sb.logInfo("CONFIG =")
  --sb.logInfo(sb.printJson(config, 1))
  --sb.logInfo("TEST STUFF =")
  --sb.logInfo(sb.printJson(self.test, 1))
  --sb.logInfo(sb.printJson(testlist, 1))
  --sb.logInfo("======================== TEST ========================")
  
  --Set up a listener function that listens for the specified target message
  message.setHandler(config.targetMessage, function(...) monsterKillCondition:onMessageReceived(...) end)
  
  return monsterKillCondition
end
