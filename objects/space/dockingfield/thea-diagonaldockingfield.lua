require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.detectEntityTypes = config.getParameter("detectEntityTypes")
  self.detectDamageTeam = config.getParameter("detectDamageTeam")

  object.setInteractive(config.getParameter("interactive", true))
  object.setAllOutputNodes(false)
  animator.setAnimationState("switchState", "off")
  self.triggerTimer = 0

  local enableCollision = config.getParameter("enableCollision")
  if enableCollision then
    physics.setCollisionEnabled(enableCollision, true)
  end
end

function trigger()
  object.setAllOutputNodes(true)
  animator.setAnimationState("switchState", "on")
  object.setSoundEffectEnabled(true)
  self.triggerTimer = config.getParameter("detectDuration")
end

function onInteraction(args)
  trigger()
end

function update(dt)
  if self.triggerTimer > 0 then
    self.triggerTimer = self.triggerTimer - dt
  elseif self.triggerTimer <= 0 then
	local lineStart = vec2.add(entity.position(), config.getParameter("entityCheckLineStart"))
	local lineEnd = vec2.add(entity.position(), config.getParameter("entityCheckLineEnd"))
	world.debugLine(lineStart, lineEnd, "blue")
    local entityIds = world.entityLineQuery(lineStart, lineEnd, {
        withoutEntityId = entity.id(),
        includedTypes = self.detectEntityTypes
      })

    if self.detectDamageTeam then
      entityIds = util.filter(entityIds, function (entityId)
          local entityDamageTeam = world.entityDamageTeam(entityId)
          if self.detectDamageTeam.type and self.detectDamageTeam.type ~= entityDamageTeam.type then
            return false
          end
          if self.detectDamageTeam.team and self.detectDamageTeam.team ~= entityDamageTeam.team then
            return false
          end
          return true
        end)
    end

    if #entityIds > 0 then
      trigger()
    else
      object.setAllOutputNodes(false)
      object.setSoundEffectEnabled(false)
      animator.setAnimationState("switchState", "off")
    end
  end
end
