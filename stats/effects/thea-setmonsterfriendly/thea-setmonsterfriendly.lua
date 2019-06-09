require "/scripts/vec2.lua"

function init()  
  --Check our entityType
  self.entityType = entity.entityType()
  
  --If we are a monster, enable animation effects. Otherwise, expire the effect
  if self.entityType == "monster" and (not config.getParameter("monsterType") or world.entityTypeName(entity.id()) == config.getParameter("monsterType")) then
	animator.setParticleEmitterOffsetRegion("embers", mcontroller.boundBox())
	animator.setParticleEmitterActive("embers", true)
  
	effect.setParentDirectives(config.getParameter("directive"))
  else
	effect.expire()
  end
  
  --Store initial parameters
  self.initialAggression = world.entityAggressive(entity.id())
  self.initialDamageTeam = world.entityDamageTeam(entity.id())
end


function update(dt)
  --If we are a monster and we have a sourceEntity, inherit that entity's damageTeam and set ourselves to "aggressive"
  if self.entityType == "monster" and (not config.getParameter("monsterType") or world.entityTypeName(entity.id()) == config.getParameter("monsterType")) then
	if effect.sourceEntity() and world.entityExists(effect.sourceEntity()) then
	  world.callScriptedEntity(entity.id(), "monster.setAggressive", true)
	  world.callScriptedEntity(entity.id(), "monster.setDamageTeam", world.entityDamageTeam(effect.sourceEntity()))
	  
	  --world.debugText("Source Entity", world.entityPosition(effect.sourceEntity()), "yellow")
	else
	  effect.expire()
	end
  end
  
  --Debug functionality
  --world.debugText("Entity Type: " .. sb.print(self.entityType), vec2.add(mcontroller.position(), {0,1}), "yellow")
  --world.debugText("Damage Team: " .. sb.print(world.entityDamageTeam(entity.id())), vec2.add(mcontroller.position(), {0,2}), "yellow")
  --world.debugText("Aggressive: " .. sb.print(world.entityAggressive(entity.id())), vec2.add(mcontroller.position(), {0,3}), "yellow")
  --world.debugText("Monster Type: " .. sb.print(world.entityTypeName(entity.id())), vec2.add(mcontroller.position(), {0,4}), "yellow")
end

function uninit()
  --If we are a monster and the effect expires, reset our damage team and aggression parameters
  if self.entityType == "monster" then
	world.callScriptedEntity(entity.id(), "monster.setAggressive", self.initialAggression)
	world.callScriptedEntity(entity.id(), "monster.setDamageTeam", self.initialDamageTeam)
  end
end
