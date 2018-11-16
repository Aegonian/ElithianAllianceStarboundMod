require "/scripts/util.lua"

function init()  
  self.activateThreshold = config.getParameter("activateThreshold", 0.25)
  self.resetThreshold = config.getParameter("activateThreshold", 0.35)
  
  self.cloakReady = true
  
  script.setUpdateDelta(1)
end

function update(dt)
  self.healthPercentage = status.resourcePercentage("health")
  
  --If the cloak is ready and health becomes critical, activate stealth and make the user briefly invulnerable
  if self.cloakReady and self.healthPercentage < self.activateThreshold then
	status.addEphemeralEffect("thea-cloaking", config.getParameter("cloakingDuration", 5.0))
	status.addEphemeralEffect("invulnerable", config.getParameter("invulnerabilityDuration", 5.0))
	self.cloakReady = false
  end
  
  --If the cloak has been activated previously and we heal past the reset threshold, make the cloak available again
  if not self.cloakReady and self.healthPercentage > self.resetThreshold then
	self.cloakReady = true
  end
end

function uninit()
end
