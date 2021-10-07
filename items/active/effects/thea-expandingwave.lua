require "/scripts/vec2.lua"
require "/scripts/util.lua"

function update()
  localAnimator.clearDrawables()

  self.waveConfig = animationConfig.animationParameter("waveConfig")
  self.waves = animationConfig.animationParameter("waves") or {}
  
  for _, wave in pairs(self.waves) do	
	local alphaMultiplier = math.min(0, 1 - (wave.lifeTime / wave.maxLifeTime))
	local alpha = math.ceil(255 * alphaMultiplier)
	
	local drawable = {
	  image = self.waveConfig.image,
	  centered = true,
	  mirrored = false,
	  color = {255, 255, 255, 255},
	  scale =  (1 - (wave.lifeTime / wave.maxLifeTime)) * self.waveConfig.maxScale,
	  position = wave.muzzlePosition,
	  fullbright = self.waveConfig.fullbright
	}
	
	localAnimator.addDrawable(drawable)
  end
end
