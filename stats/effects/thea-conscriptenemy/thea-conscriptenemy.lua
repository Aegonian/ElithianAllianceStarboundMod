require "/scripts/vec2.lua"

function init()
  --Settings from config file
  self.monsterType = config.getParameter("monsterType")
  self.conscriptMonsters = config.getParameter("conscriptMonsters")
  self.conscriptNPCs = config.getParameter("conscriptNPCs")
  self.npcEmote = config.getParameter("npcEmote")
  self.npcEmoteSingle = config.getParameter("npcEmoteSingle")
  self.npcDance = config.getParameter("npcDance")
  self.npcDanceSingle = config.getParameter("npcDanceSingle")
  self.directive = config.getParameter("directive")
  self.aggressive = config.getParameter("aggressive", true)
  self.damageTeam = config.getParameter("damageTeam", world.entityDamageTeam(effect.sourceEntity()))
  
  --Check our entityType
  self.entityType = entity.entityType()
  
  --If we are a monster, enable animation effects. Otherwise, check if we are an NPC
  if self.entityType == "monster" and (not self.monsterType or world.entityTypeName(entity.id()) == self.monsterType) and self.conscriptMonsters then
	animator.setParticleEmitterOffsetRegion("embers", mcontroller.boundBox())
	animator.setParticleEmitterActive("embers", true)
  
	effect.setParentDirectives(self.directive)
  
  --If we are an NPC, enable animation effects. Otherwise, expire the effect
  elseif self.entityType == "npc" and self.conscriptNPCs then
	animator.setParticleEmitterOffsetRegion("embers", mcontroller.boundBox())
	animator.setParticleEmitterActive("embers", true)
  
	effect.setParentDirectives(self.directive)
  else
	effect.expire()
  end
  
  --Store initial parameters
  self.initialAggression = world.entityAggressive(entity.id())
  self.initialDamageTeam = world.entityDamageTeam(entity.id())
  
  self.conscriptDialogPlayed = false
end


function update(dt)
  --If we are a monster and we have a sourceEntity, inherit that entity's damageTeam and set ourselves to "aggressive"
  if self.entityType == "monster" and (not self.monsterType or world.entityTypeName(entity.id()) == self.monsterType) and self.conscriptMonsters then
	if effect.sourceEntity() and world.entityExists(effect.sourceEntity()) then
	  world.callScriptedEntity(entity.id(), "monster.setAggressive", self.aggressive)
	  world.callScriptedEntity(entity.id(), "monster.setDamageTeam", self.damageTeam)
	  
	  --world.debugText("Source Entity", world.entityPosition(effect.sourceEntity()), "yellow")
	else
	  effect.expire()
	end
  
  --If we are an NPC and we have a sourceEntity, inherit that entity's damageTeam and set ourselves to "aggressive"
  elseif self.entityType == "npc" and self.conscriptNPCs then
	if effect.sourceEntity() and world.entityExists(effect.sourceEntity()) then
	  world.callScriptedEntity(entity.id(), "npc.setAggressive", self.aggressive)
	  world.callScriptedEntity(entity.id(), "npc.setDamageTeam", self.damageTeam)
	  
	  --Optionally play an emote or dance for as long as the NPC remains conscripted
	  if self.npcEmote then
		world.callScriptedEntity(entity.id(), "npc.emote", self.npcEmote)
	  end
	  if self.npcDance then
		world.callScriptedEntity(entity.id(), "npc.dance", self.npcDance)
	  end
	  
	  --Play a dialog line when the NPC gets conscripted
	  if not self.conscriptDialogPlayed then
		--Get the species of our NPC
		local npcSpecies = world.entitySpecies(entity.id())
		
		--Make the NPC say the appropriate dialog line
		if config.getParameter(npcSpecies .. "ConscriptDialog") then
		  world.callScriptedEntity(entity.id(), "npc.say", config.getParameter(npcSpecies .. "ConscriptDialog"))
		  --sb.logInfo(config.getParameter(npcSpecies .. "ConscriptDialog"))
		else
		  world.callScriptedEntity(entity.id(), "npc.say", config.getParameter("defaultConscriptDialog"))
		  --sb.logInfo(config.getParameter("defaultConscriptDialog"))
		end
	  
		--Optionally play an emote or dance when the NPC gets conscripted
		if self.npcEmoteSingle then
		  world.callScriptedEntity(entity.id(), "npc.emote", self.npcEmoteSingle)
		end
		if self.npcDanceSingle then
		  world.callScriptedEntity(entity.id(), "npc.dance", self.npcDanceSingle)
		end
		
		self.conscriptDialogPlayed = true
	  end
	  
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
  if self.entityType == "monster" and world.entityExists(entity.id()) then
	world.callScriptedEntity(entity.id(), "monster.setAggressive", self.initialAggression)
	world.callScriptedEntity(entity.id(), "monster.setDamageTeam", self.initialDamageTeam)
  end
  
  --If we are an NPC and the effect expires, reset our damage team and aggression parameters
  if self.entityType == "npc" and world.entityExists(entity.id()) then
	world.callScriptedEntity(entity.id(), "npc.setAggressive", self.initialAggression)
	world.callScriptedEntity(entity.id(), "npc.setDamageTeam", self.initialDamageTeam)
  end
end
