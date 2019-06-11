require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/vec2.lua"

function init()
  animator.setParticleEmitterOffsetRegion("cloakedParticles", mcontroller.boundBox())
  animator.setParticleEmitterOffsetRegion("cloakedParticles2", mcontroller.boundBox())
  animator.setParticleEmitterOffsetRegion("cooldownParticles", mcontroller.boundBox())
  animator.setParticleEmitterOffsetRegion("activate", mcontroller.boundBox())
  animator.setParticleEmitterOffsetRegion("deactivate", mcontroller.boundBox())
  
  self.maximumDoubleTapTime = config.getParameter("maximumDoubleTapTime")
  self.directive = config.getParameter("directive")
  self.blinkDirective = config.getParameter("blinkDirective")
  self.maxDuration = config.getParameter("maxDuration")
  self.blinkDuration = config.getParameter("blinkDuration")
  self.cooldownTime = config.getParameter("cooldownTime")
  
  self.active = false
  self.recharged = true
  self.cooldownTimer = 0
  self.durationLeft = self.maxDuration
  self.doubleTapTimer = 0
  self.blinkTimer = 0
  
  tech.setParentDirectives()
end

function uninit()
  self.active = false
  tech.setParentDirectives()
end

function update(args)
  --Double tap behaviour
  if self.doubleTapTimer > 0 then
	self.doubleTapTimer = math.max(0, self.doubleTapTimer - args.dt)
  end
  
  if args.moves["up"] and self.cooldownTimer == 0 and not status.statPositive("activeMovementAbilities") then
	if not self.lastMoves["up"] then
	  if self.doubleTapTimer == 0 then
		self.doubleTapTimer = self.maximumDoubleTapTime
	  else
		if self.active then
		  deactivateStealth()
		elseif not world.getProperty("entityinvisible" .. tostring(entity.id())) then
		  activateStealth()
		end
		self.doubleTapTimer = 0
	  end
	end
  end
  
  --Deactivate stealth if any of the following buttons are pressed: primaryFire, altFire, special1
  if (args.moves["primaryFire"] or args.moves["altFire"] or args.moves["special1"]) and self.active then
	deactivateStealth()
  end
  
  --Count down the cooldown timer
  self.cooldownTimer = math.max(0, self.cooldownTimer - args.dt)
  if self.cooldownTimer == 0 and not self.recharged then
	animator.playSound("recharge")
	animator.setParticleEmitterActive("cooldownParticles", false)
	self.recharged = true
  elseif self.cooldownTimer > 0 then
	animator.setParticleEmitterActive("cooldownParticles", true)
  end
  
  --Listen for incoming damage and deactivate stealth if we take damage
  local damageNotificationsIncoming, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  for _, notification in ipairs(damageNotificationsIncoming) do
	if notification.healthLost > 1 then
	  if self.active then
		deactivateStealth()
	  end
	end
  end
  
  --While we are active, count down the duration and deactivate if we run our of time
  if self.active then
	self.durationLeft = math.max(0, self.durationLeft - args.dt)
	
	--If we are almost out of time, start blinking
	if self.durationLeft < self.blinkDuration then
	  self.blinkTimer = math.max(0, self.blinkTimer - args.dt)
	  
	  if self.blinkTimer == 0 then
	    tech.setParentDirectives(self.blinkDirective)
		self.blinkTimer = 0.2
	  else
		tech.setParentDirectives(self.directive)
	  end
	end
	
	--If we are out of time, deactivate stealth
	if self.durationLeft == 0 then
	  deactivateStealth()
	end
  end
  
  --Debug functionality
  --world.debugText(sb.print(args.moves), mcontroller.position(), "yellow")
  
  self.lastMoves = args.moves
end

function activateStealth()
  animator.playSound("activate")
  animator.burstParticleEmitter("activate")
  
  animator.setParticleEmitterActive("cloakedParticles", true)
  animator.setParticleEmitterActive("cloakedParticles2", true)
  
  tech.setParentDirectives(self.directive)
  
  world.setProperty("entityinvisible" .. tostring(entity.id()), true)
  self.active = true
  
  self.durationLeft = self.maxDuration
end

function deactivateStealth()
  animator.playSound("deactivate")
  animator.burstParticleEmitter("deactivate")
  
  animator.setParticleEmitterActive("cloakedParticles", false)
  animator.setParticleEmitterActive("cloakedParticles2", false)

  tech.setParentDirectives()
  
  world.setProperty("entityinvisible" .. tostring(entity.id()), nil)
  self.active = false
  
  self.cooldownTimer = self.cooldownTime
  self.recharged = false
end
