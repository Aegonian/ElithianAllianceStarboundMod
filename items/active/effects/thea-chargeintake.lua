require "/scripts/vec2.lua"
require "/scripts/util.lua"

function update()
  localAnimator.clearDrawables()

  self.particleConfig = animationConfig.animationParameter("particleConfig")
  self.particles = animationConfig.animationParameter("particles") or {}
  
  for _, particle in pairs(self.particles) do	
	local alphaMultiplier = math.min(1, (1 - (particle.lifeTime / particle.maxLifeTime)) * 2)
	local alpha = math.ceil(254 * alphaMultiplier)
	
	--Optionally give the charge particle a randomly flipped rotation
	if self.particleConfig.rotationSpeed then
	  if self.particleConfig.randomRotationDirection then
		particle.vector = vec2.rotate(particle.vector, (particle.lifeTime / particle.maxLifeTime) * self.particleConfig.rotationSpeed * util.randomChoice({1, -1}))
	  else
		particle.vector = vec2.rotate(particle.vector, (particle.lifeTime / particle.maxLifeTime) * self.particleConfig.rotationSpeed)
	  end
	end
	
	local drawable = {
	  image = self.particleConfig.image,
	  centered = true,
	  mirrored = false,
	  color = {255, 255, 255, alpha},
	  rotation = vec2.angle(particle.vector),
	  scale = (particle.lifeTime / particle.maxLifeTime) * self.particleConfig.scale * (particle.scaleMultiplier or 1) + (particle.scaleAddition or 0),
	  position = vec2.add(particle.muzzlePosition, vec2.mul(particle.vector, (particle.lifeTime / particle.maxLifeTime))),
	  fullbright = self.particleConfig.fullbright
	}
	
	--Optionally give the charge particle a randomly flipped rotation
	if self.particleConfig.randomRotation then
	  drawable.rotation = util.randomChoice({vec2.angle(particle.vector), vec2.angle(vec2.rotate(particle.vector, math.pi))})
	end
	
	--Optionally inverse the direction of the particles
	if self.particleConfig.invertDirection then
	  drawable.position = vec2.add(particle.muzzlePosition, vec2.mul(particle.vector, 1 - (particle.lifeTime / particle.maxLifeTime)))
	end
	
	localAnimator.addDrawable(drawable)
  end
end
