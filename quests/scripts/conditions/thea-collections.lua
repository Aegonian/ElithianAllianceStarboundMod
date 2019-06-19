function buildCompleteCollectionCondition(config)
  --Set up the monster kill condition
  local completeCollectionCondition = {
    description = config.description or root.assetJson("/quests/quests.config:objectiveDescriptions.theaCompleteCollection"),
    collectionDisplayName = config.collectionDisplayName,
    collectionGroup = config.collectionGroup,
    collectionItem = config.collectionItem
  }
  
  --Set up the function for checking if the conditions were met
  function completeCollectionCondition:conditionMet()
    local collection = player.collectables(self.collectionGroup)
	local collectionCompleted = false
	
	--For every item in the player's collection, check if it matches the required collection
	for i, item in pairs(collection) do
	  if item == self.collectionItem then
		collectionCompleted = true
	  end
	end
	
	return collectionCompleted
  end

  --Set up the function for performing actions upon quest start
  function completeCollectionCondition:onQuestStart()
    --Nothing here!
  end

  --Set up the function for performing actions upon quest complete
  --These get called in addition to the default quest complete actions, and so should only contain actions relative to the objective
  function completeCollectionCondition:onQuestComplete()
    --Nothing here!
  end

  --Set up the function for constructing the objective text
  function completeCollectionCondition:objectiveText()
    local objective = self.description
    objective = objective:gsub("<collectionName>", self.collectionDisplayName)
    return objective
  end
  
  return completeCollectionCondition
end
