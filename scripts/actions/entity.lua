-- Helpers
function entityTable()
  if entity.entityType() == "npc" then
    return npc
  elseif entity.entityType() == "monster" then
    return monster
  elseif entity.entityType() == "object" then
    return object
  end
end

-- Actions
function setInteractive(args, board)
  entityTable().setInteractive(args.interactive)
  return true
end

function wasInteracted(args, board)
  return self.interacted == true
end

function wasDamaged(args, board)
  return self.damaged == true
end

function wasStunned(args, board)
  return self.stunned == true
end

-- param aggressive
function setAggressive(args, board)
  if args.aggressive == nil then return false end

  entityTable().setAggressive(args.aggressive)
  return true
end

function controlAggressive(args, board)
  self.controlAggressive = true
  return true
end

-- param damageTeam
function setDamageTeam(args, board)
  if args.damageTeam == nil then return false end

  entityTable().setDamageTeam(args.damageTeam)
  return true
end

-- param type
-- param team
function isDamageTeam(args, board)
  local damageTeam = entity.damageTeam()
  if args.team ~= nil and damageTeam.team ~= args.team then
    return false
  end
  if args.type ~= nil and damageTeam.type ~= args.type then
    return false
  end

  return true
end

-- param entity
function isValidTarget(args, board)
  if args.entity == nil then return false end

  return entity.isValidTarget(args.entity)
end

-- param touchDamage
function setDamageOnTouch(args, board)
  self.touchDamageEnabled = args.touchDamage
  return true
end

function setDying(args, board)
  self.shouldDie = args.shouldDie
  return true
end

-- param entity
function entityInSight(args, board)
  if args.entity == nil or not world.entityExists(args.entity) then return false end

  local inSight = entity.entityInSight(args.entity)
  if not inSight then
    return false
  end

  if not config.getParameter("seeThroughLiquid", true) then
    local liquid = world.liquidAlongLine(entity.position(), world.entityPosition(args.entity))
    if #liquid > 0 then
      return false
    end
  end
  
  --Custom code for performing an invisibility check. Invisibility status is saved in a worldProperty, since this is the only type of property that can be read and written from anywhere
  if world.getProperty("entityinvisible" .. tostring(args.entity)) and not status.statPositive("ignoreInvisibilityEffects") then
	return false
  end

  return true
end
