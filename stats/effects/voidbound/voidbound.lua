require "/scripts/util.lua"

function init()
  --Config parameters
  self.groundMovementModifier = config.getParameter("groundMovementModifier")
  self.speedModifier = config.getParameter("speedModifier")
  self.airJumpModifier = config.getParameter("airJumpModifier")
  self.jumpModifier = config.getParameter("jumpModifier")
  self.gravityModifier = config.getParameter("gravityModifier")
  self.movementParams = mcontroller.baseParameters()
  
  --Effects
  animator.setParticleEmitterOffsetRegion("largeParticles", mcontroller.boundBox())
  animator.setParticleEmitterOffsetRegion("smallParticles", mcontroller.boundBox())
  animator.setParticleEmitterActive("largeParticles", true)
  animator.setParticleEmitterActive("smallParticles", true)
  effect.setParentDirectives(config.getParameter("directive"))
  
  --Stat modifiers
  effect.addStatModifierGroup({
    {stat = "jumpModifier", amount = self.jumpModifier}
  })
  
  --Set-up gravity functions
  setGravityMultiplier()
end

function setGravityMultiplier()
  local oldGravityMultiplier = self.movementParams.gravityMultiplier or 1

  self.newGravityMultiplier = self.gravityModifier * oldGravityMultiplier
end

function update(dt)
  --Movement modifiers
  mcontroller.controlModifiers({
	groundMovementModifier = self.groundMovementModifier,
	speedModifier = self.speedModifier,
	airJumpModifier = self.airJumpModifier
  })
  
  --Gravity modifiers
  mcontroller.controlParameters({
     gravityMultiplier = self.newGravityMultiplier
  })
  
  --Create an explosion if the target dies, but only if it exceeds the configured max health threshold
  if not status.resourcePositive("health") and status.resourceMax("health") >= config.getParameter("minMaxHealth", 0) then
    effect.setParentDirectives(config.getParameter("deathDirective"))
	explode()
  end
end

function explode()
  if not self.exploded then
    world.spawnProjectile(config.getParameter("deathProjectileType"), mcontroller.position(), 0, {0, 0}, false)
    self.exploded = true
  end
end

function uninit()
end
