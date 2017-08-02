function init()
  --Loading the config values
  self.maxFrame = config.getParameter("animationFrames")
  self.animationTime = config.getParameter("animationTime")
  self.glitchMinTime = config.getParameter("glitchMinTime")
  self.glitchMaxTime = config.getParameter("glitchMaxTime")
  
  --Setting initial values
  self.spriteIndex = 1
  self.animationTimer = self.animationTime
  if self.glitchMinTime > 0 then
	self.glitchTimer = math.random(self.glitchMinTime * 100, self.glitchMaxTime * 100) / 100
	self.allowGlitches = true
  else
	self.glitchTimer = 0
	self.allowGlitches = false
  end
  
  --Starting directives
  effect.setParentDirectives("addmask=/stats/effects/thea-hologram/thea-hologramoverlay" .. self.spriteIndex .. ".png")
end

function update(dt)
  self.animationTimer = math.max(0, self.animationTimer - dt)
  self.glitchTimer = math.max(0, self.glitchTimer - dt)
  
  if self.allowGlitches and self.glitchTimer == 0 then
	effect.setParentDirectives("addmask=/stats/effects/thea-hologram/thea-hologramglitch.png")
	self.glitchTimer = math.random(self.glitchMinTime * 100, self.glitchMaxTime * 100) / 100
	self.animationTimer = self.animationTime
  end
  
  if self.animationTimer == 0 then
	self.spriteIndex = self.spriteIndex + 1
	if self.spriteIndex > self.maxFrame then
	  self.spriteIndex = 1
	end
	effect.setParentDirectives("addmask=/stats/effects/thea-hologram/thea-hologramoverlay" .. self.spriteIndex .. ".png")
	--effect.setParentDirectives("addmask=/stats/effects/thea-hologram/thea-hologramoverlay" .. self.spriteIndex .. ".png?fade=FF9D0D=0.5")
	self.animationTimer = self.animationTime
  end
end

function uninit()
  
end