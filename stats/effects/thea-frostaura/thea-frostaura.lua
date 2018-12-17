require "/scripts/vec2.lua"
require "/scripts/rect.lua"

function init()
  animator.setParticleEmitterOffsetRegion("frostparticles", rect.scale(mcontroller.boundBox(), {1, 0.35}))
  animator.setParticleEmitterActive("frostparticles", true)
  animator.setParticleEmitterOffsetRegion("fogparticles", mcontroller.boundBox())
  animator.setParticleEmitterActive("fogparticles", true)
  effect.setParentDirectives("fade=00BBFF=0.1")

  self.materialModProjectile = config.getParameter("materialModProjectile")
  self.projectileSpawnWidth = config.getParameter("projectileSpawnWidth")
  self.projectileCooldownTime = config.getParameter("projectileCooldownTime")
  self.projectileTimer = 0
  
  self.statusProjectile = config.getParameter("statusProjectile")
  
  self.liquidConversions = config.getParameter("liquidConversions")
  self.liquidConvertPositions = config.getParameter("liquidConvertPositions")
  self.minimumLiquidLevel = config.getParameter("minimumLiquidLevel")
  self.allowOverlap = config.getParameter("allowOverlap")
  
  script.setUpdateDelta(1)
end

function update(dt)
  mcontroller.controlModifiers({
	speedModifier = 0.75
  })
  
  --Material mod projectiles
  self.projectileTimer = math.max(0, self.projectileTimer - dt)
  if self.projectileTimer == 0 then
	world.spawnProjectile(self.materialModProjectile, vec2.add(entity.position(), {math.random(-self.projectileSpawnWidth, self.projectileSpawnWidth), math.random(-2, -1)}), entity.id(), {0,0}, false, nil)
	world.spawnProjectile(self.statusProjectile, entity.position(), entity.id(), {0,0}, false, nil)
	self.projectileTimer = config.getParameter("projectileCooldownTime")
  end
  
  if not status.statPositive("activeMovementAbilities") then
	for _, position in ipairs(self.liquidConvertPositions) do
	  convertLiquid(vec2.add(entity.position(), position))
	end
  end
end

function convertLiquid(position)
  world.debugPoint(position, "green")
  
  if self.liquidConversions then
	local liquid = world.liquidAt(position)
	local liquidAbove = world.liquidAt(vec2.add(position, {0,1}))
	local liquidBelow = world.liquidAt(vec2.add(position, {0,-1}))
	local materialAbove = world.material(vec2.add(position, {0,1}), "foreground")
	
	--Check if the liquid at the projectile's position is the surface of the liquid
	local isLiquidSurface = false
	if liquid and not materialAbove then
	  --If there is no liquid above and liquid is over minimum liquid level
	  if liquid[2] > self.minimumLiquidLevel and not liquidAbove then
		isLiquidSurface = true
	  --If the same liquid is also below and the liquid above is not full
	  elseif liquidBelow and liquidBelow[1] == liquid[1] and not liquidAbove then
		isLiquidSurface = true
	  end
	end
	
	if isLiquidSurface then
	  --For every configured conversion, check if the current liquid matches anything in our conversion lists
	  for _, conversion in pairs(self.liquidConversions) do
		if liquid[1] == conversion[1] then
		  --If placement of material succeeded, kill the projectile
		  if world.placeMaterial(position, "foreground", conversion[2], nil, config.getParameter("allowOverlap", false)) then
			return true
		  end
		end
	  end
	end
  end
  
  return false
end

function uninit()

end
