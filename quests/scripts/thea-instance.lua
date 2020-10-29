require "/scripts/util.lua"
require "/quests/scripts/questutil.lua"
require "/quests/scripts/portraits.lua"

function init()
  self.descriptions = config.getParameter("descriptions")

  self.warpEntity = config.getParameter("warpEntityUid")
  self.warpAction = config.getParameter("warpAction")
  self.warpDialog = config.getParameter("warpDialog")

  self.goalTrigger = config.getParameter("goalTrigger", "proximity")

  self.goalEntity = config.getParameter("goalEntityUid")
  self.trackGoalEntity = config.getParameter("trackGoalEntity", false)
  self.indicateGoal = config.getParameter("indicateGoal", false)

  self.turnInEntity = config.getParameter("turnInEntityUid")
  
  self.radioMessage = config.getParameter("radioMessageOnFinish")

  if self.goalTrigger == "proximity" then
    self.proximityRange = config.getParameter("proximityRange", 20)
  elseif self.goalTrigger == "interact" then
    self.interactEntity = config.getParameter("interactEntityUid")

    self.goalInteract = function(entityId)
      if world.entityUniqueId(entityId) == self.interactEntity then
        storage.stage = 3
      end
    end
  elseif self.goalTrigger == "message" then
    self.triggerMessage = config.getParameter("triggerMessage")

    message.setHandler(self.triggerMessage, function()
      storage.stage = 3
    end)
  elseif self.goalTrigger == "collect" then
    self.collectTargetItem = config.getParameter("collectTargetItem")
    self.collectTargetItemCount = config.getParameter("collectTargetItemCount")
  end

  setPortraits()

  self.stages = {
    enterInstance,
    findGoal,
    turnIn
  }

  storage.stage = storage.stage or 1
  storage.radioMessagePlayed = storage.radioMessagePlayed or false
  self.state = FSM:new()
  self.state:set(self.stages[storage.stage])
end

function questStart()
  local associatedMission = config.getParameter("associatedMission")
  if associatedMission then
    player.enableMission(associatedMission)
  end

  local acceptItems = config.getParameter("acceptItems", {})
  for _,item in ipairs(acceptItems) do
    player.giveItem(item)
  end
end

function update(dt)
  self.state:update()
end

function questInteract(entityId)
  if self.onInteract then
    return self.onInteract(entityId)
  end
end

function questComplete()
  setPortraits()

  questutil.questCompleteActions()
end

function enterInstance(dt)
  quest.setCompassDirection(nil)
  quest.setObjectiveList({
    {self.descriptions.enterInstance, false}
  })
  quest.setParameter("warpentity", {type = "entity", uniqueId = self.warpEntity})
  quest.setIndicators({"warpentity"})

  self.onInteract = function(entityId)
    if world.entityUniqueId(entityId) == self.warpEntity then
      if not self.warpConfirmation then
        local dialogConfig = root.assetJson(self.warpDialog)
        dialogConfig.sourceEntityId = entityId
        self.warpConfirmation = player.confirm(dialogConfig)
      end
      return true
    end
  end

  local findWarpEntity = util.uniqueEntityTracker(self.warpEntity, 0.5)
  local findGoalEntity = util.uniqueEntityTracker(self.goalEntity, 1.0)
  while storage.stage == 1 do
    questutil.pointCompassAt(findWarpEntity())

    if findGoalEntity() then
      storage.stage = 2
    end

    if self.warpConfirmation and self.warpConfirmation:finished() then
      if self.warpConfirmation:result() then
        if type(self.warpAction) == "string" then
          player.warp(self.warpAction, "beam")
        elseif type(self.warpAction) == "table" then
          player.warp(self.warpAction[1], self.warpAction[2], self.warpAction[3])
        end
      end
      self.warpConfirmation = nil
    end

    coroutine.yield()
  end

  self.state:set(self.stages[storage.stage])
end

function findGoal(dt)
  quest.setCompassDirection(nil)
  quest.setObjectiveList({
    {self.descriptions.findGoal, false}
  })
  quest.setIndicators({})
  self.onInteract = nil

  if self.indicateGoal then
    quest.setParameter("goalentity", {type = "entity", uniqueId = self.goalEntity})
    quest.setIndicators({"goalentity"})
  end

  if self.goalTrigger == "interact" then
    self.onInteract = self.goalInteract
  end

  local findGoalEntity = util.uniqueEntityTracker(self.goalEntity, 0.5)
  while storage.stage == 2 do
    local goalPosition = findGoalEntity()
    if self.trackGoalEntity then
      questutil.pointCompassAt(goalPosition)
    end

    if self.goalTrigger == "proximity" and goalPosition then
      if world.magnitude(mcontroller.position(), goalPosition) < self.proximityRange then
        storage.stage = 3
      end
    end

    if self.goalTrigger == "collect" and goalPosition then
      if player.hasItem({ name = self.collectTargetItem, count = self.collectTargetItemCount }) then
        storage.stage = 3
      end
    end

    if goalPosition == nil then
      storage.stage = 1
    end

    coroutine.yield()
  end

  self.state:set(self.stages[storage.stage])
end

function turnIn()
  if self.radioMessage and not storage.radioMessagePlayed then
	world.sendEntityMessage(player.id(), "queueRadioMessage", self.radioMessage)
	storage.radioMessagePlayed = true
  end
  
  quest.setCompassDirection(nil)
  quest.setObjectiveList({
    {self.descriptions.turnIn, false}
  })
  quest.setIndicators({})
  self.onInteract = nil

  if self.turnInEntity then
    quest.setCanTurnIn(true)

    local findTurnInEntity = util.uniqueEntityTracker(self.turnInEntity, 0.5)
    while true do
      questutil.pointCompassAt(findTurnInEntity())
      coroutine.yield()
    end
  else
    quest.complete()
  end
end
