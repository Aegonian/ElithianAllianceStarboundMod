require "/scripts/vec2.lua"

function init()
  self.requiredItem = config.getParameter("requiredItem", nil)
  self.requiredItemCount = config.getParameter("requiredItemCount", 1)
  self.missingItemsMessage = config.getParameter("missingItemsMessage", nil)
  self.missingItemsRadioMessage = config.getParameter("missingItemsRadioMessage", nil)
  self.destroyParticles = config.getParameter("destroyParticles", false)
  self.explosionConfig = config.getParameter("explosionConfig", false)
  
  object.setInteractive(true)
end

function onInteraction(args)
  if self.requiredItem ~= nil and world.entityHasCountOfItem(args.sourceId, self.requiredItem) >= self.requiredItemCount then
	object.smash()
	
  elseif self.requiredItem ~= nil and world.entityHasCountOfItem(args.sourceId, self.requiredItem) < self.requiredItemCount then
	if self.missingItemsMessage ~= nil then
	  object.say(self.missingItemsMessage)
	end
	if self.missingItemsRadioMessage ~= nil then
	  world.sendEntityMessage(args.sourceId, "queueRadioMessage", self.missingItemsRadioMessage)
	end
	
  elseif self.requiredItem == nil then
	object.smash()
  end
end

function die()
  if self.explosionConfig ~= false then
	local projectileConfig = {
	  damageTeam = { type = "indiscriminate" },
	  power = config.getParameter("explosionDamage", 50),
	  onlyHitTerrain = false,
	  timeToLive = 0,
	  damageRepeatGroup = config.getParameter("damageRepeatGroup", "environment"),
	  actionOnReap = {
		{
		  action = "config",
		  file =  self.explosionConfig
		}
	  }
	}
	world.spawnProjectile("invisibleprojectile", vec2.add(object.position(), config.getParameter("explosionOffset", {0,0})), entity.id(), {0,0}, false, projectileConfig)
  end
  
  if animator.hasSound("destroy") then
	animator.playSound("destroy")
  end
  
  if self.destroyParticles then
	animator.burstParticleEmitter("destroy")
  end
end
