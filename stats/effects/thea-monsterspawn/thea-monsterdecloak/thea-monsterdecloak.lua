function init()  
  self.hasSpawned = false
end

function update(dt)
  if not self.hasSpawned then
	animator.burstParticleEmitter("decloak")
	animator.playSound("decloak")
	self.hasSpawned = true
  end
end
