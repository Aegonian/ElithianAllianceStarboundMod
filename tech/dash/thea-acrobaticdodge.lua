require "/tech/doubletap.lua"

function init()
  self.airDashing = false
  self.dashDirection = 0
  self.dashTimer = 0
  self.dashCooldownTimer = 0
  self.rechargeEffectTimer = 0
  self.wasOnGround = false
  self.facingDirection = 1

  self.dashVelocity = config.getParameter("dashVelocity")
  self.dashDuration = config.getParameter("dashDuration")
  self.dashCooldown = config.getParameter("dashCooldown")
  self.groundOnly = config.getParameter("groundOnly")
  self.cooldownOnGroundOnly = config.getParameter("cooldownOnGroundOnly")
  self.stopAfterDash = config.getParameter("stopAfterDash")
  self.slowAfterDash = config.getParameter("slowAfterDash")
  self.slowDownFactor = config.getParameter("slowDownFactor")
  self.rechargeDirectives = config.getParameter("rechargeDirectives", "?fade=CCCCFFFF=0.25")
  self.rechargeEffectTime = config.getParameter("rechargeEffectTime", 0.1)

  self.doubleTap = DoubleTap:new({"left", "right"}, config.getParameter("maximumDoubleTapTime"), function(dashKey)
      if self.dashTimer == 0
          and self.dashCooldownTimer == 0
          and groundValid()
          and not mcontroller.crouching()
          and not status.statPositive("activeMovementAbilities") then

        startDash(dashKey == "left" and -1 or 1)
      end
    end)

  animator.setAnimationState("dashing", "off")
end

function uninit()
  status.clearPersistentEffects("movementAbility")
  status.removeEphemeralEffect("invulnerable")
  mcontroller.setRotation(0)
  tech.setParentState()
  tech.setParentDirectives()
end

function update(args)
  if mcontroller.onGround() or mcontroller.liquidMovement() or mcontroller.zeroG() then
	self.wasOnGround = true
  end  
  
  if self.dashCooldownTimer > 0 and not (self.cooldownOnGroundOnly and not self.wasOnGround) then
    self.dashCooldownTimer = math.max(0, self.dashCooldownTimer - args.dt)
    if self.dashCooldownTimer == 0 then
      self.rechargeEffectTimer = self.rechargeEffectTime
      tech.setParentDirectives(self.rechargeDirectives)
      animator.playSound("recharge")
    end
  end

  if self.rechargeEffectTimer > 0 then
    self.rechargeEffectTimer = math.max(0, self.rechargeEffectTimer - args.dt)
    if self.rechargeEffectTimer == 0 then
      tech.setParentDirectives()
    end
  end

  self.doubleTap:update(args.dt, args.moves)

  if self.dashTimer > 0 then
    --mcontroller.controlApproachVelocity({self.dashSpeed * self.dashDirection, 0}, self.dashControlForce)
    mcontroller.controlMove(self.dashDirection, true)
    mcontroller.controlModifiers({jumpingSuppressed = true})
	mcontroller.setRotation(-math.pi * 2 * self.dashDirection * (-self.dashTimer / self.dashDuration * 0.75))
	mcontroller.controlFace(self.facingDirection)
	
    animator.setFlipped(mcontroller.facingDirection() == -1)

    self.dashTimer = math.max(0, self.dashTimer - args.dt)
    if self.dashTimer == 0 then
      endDash()
    end
  end
end

function groundValid()
  return mcontroller.groundMovement() or not self.groundOnly
end

function startDash(direction)
  self.dashDirection = direction
  self.dashTimer = self.dashDuration
  self.facingDirection = mcontroller.facingDirection()
  self.airDashing = not mcontroller.groundMovement()
  status.setPersistentEffects("movementAbility", {{stat = "activeMovementAbilities", amount = 1}})
  animator.playSound("startDash")
  animator.setAnimationState("dashing", "on")
  --Activate particles based on facing direction and dash direction
  if self.dashDirection == 1 and self.facingDirection == 1 then
	animator.setParticleEmitterActive("dashParticlesLeft", true)
  elseif self.dashDirection == 1 and self.facingDirection == -1 then
	animator.setParticleEmitterActive("dashParticlesRight", true)
  elseif self.dashDirection == -1 and self.facingDirection == 1 then
	animator.setParticleEmitterActive("dashParticlesRight", true)
  elseif self.dashDirection == -1 and self.facingDirection == -1 then
	animator.setParticleEmitterActive("dashParticlesLeft", true)
  end
  
  tech.setParentState("Fall")
  tech.setToolUsageSuppressed(true)
  status.addEphemeralEffect("invulnerable")
  
  local dodgeVelocity = {self.dashVelocity[1] * self.dashDirection, self.dashVelocity[2]}
  mcontroller.setVelocity(dodgeVelocity)
end

function endDash()
  status.clearPersistentEffects("movementAbility")

  if self.stopAfterDash then
    local movementParams = mcontroller.baseParameters()
    local currentVelocity = mcontroller.velocity()
    if math.abs(currentVelocity[1]) > movementParams.runSpeed then
      mcontroller.setVelocity({movementParams.runSpeed * self.dashDirection, 0})
    end
    mcontroller.controlApproachXVelocity(self.dashDirection * movementParams.runSpeed, self.dashControlForce)
  elseif self.slowAfterDash then
	mcontroller.setXVelocity(self.dashVelocity[1] * self.slowDownFactor * self.dashDirection)
  end

  self.dashCooldownTimer = self.dashCooldown
  
  mcontroller.setRotation(0)

  animator.setAnimationState("dashing", "off")
  animator.setParticleEmitterActive("dashParticlesRight", false)
  animator.setParticleEmitterActive("dashParticlesLeft", false)
  
  self.wasOnGround = false
  
  tech.setParentState()
  tech.setToolUsageSuppressed(false)
  status.removeEphemeralEffect("invulnerable")
end
