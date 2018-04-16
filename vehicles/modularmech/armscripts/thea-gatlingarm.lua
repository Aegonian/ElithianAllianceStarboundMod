--require "/vehicles/modularmech/armscripts/base.lua"
require "/vehicles/modularmech/armscripts/gatlingarm.lua"

--GatlingArm = MechArm:extend()

function GatlingArm:fire()
  local projectileIds = {}

  if self.aimAngle and self.aimVector and self.firePosition and self:rayCheck(self.firePosition) then
    local pParams = copy(self.projectileParameters)
    if not self.projectileTrackSource and self.projectileInheritVelocity and mcontroller.zeroG() then
      pParams.referenceVelocity = mcontroller.velocity()
    else
      pParams.referenceVelocity = nil
    end
    pParams.processing = self.directives

    local pCount = self.projectileCount or 1
    local pSpread = self.projectileSpread or 0
    local inacc = self.projectileInaccuracy or 0
    local aimVec = vec2.rotate(self.aimVector, -0.5 * (pCount - 1) * pSpread)

    local firePos = self.firePosition
    local pSpacing
    if self.projectileSpacing and pCount > 1 then
      pSpacing = vec2.mul(vec2.rotate(self.projectileSpacing, self.aimAngle), {self.facingDirection, 1})
      firePos = vec2.add(firePos, vec2.mul(pSpacing, (pCount - 1) * -0.5))
    end

    for i = 1, pCount do
      local thisFirePos = firePos
      if self.projectileRandomOffset then
        thisFirePos = vec2.add(thisFirePos, {(math.random() - 0.5) * self.projectileRandomOffset[1], (math.random() - 0.5) * self.projectileRandomOffset[2]})
      end
	  
      local thisAimVec = aimVec
      if self.projectileInaccuracy then
        thisAimVec = vec2.rotate(thisAimVec, sb.nrand(self.projectileInaccuracy, 0))
      end

      if self.projectileRandomSpeed then
        pParams.speed = util.randomInRange(self.projectileRandomSpeed)
      end

      local projectileId = world.spawnProjectile(
          self.projectileType,
          thisFirePos,
          self.driverId,
          thisAimVec,
          self.projectileTrackSource,
          pParams)

      if projectileId then
        table.insert(projectileIds, projectileId)
      end

      aimVec = vec2.rotate(aimVec, pSpread)
      if pSpacing then
        firePos = vec2.add(firePos, pSpacing)
      end
    end
  end

  return projectileIds
end
