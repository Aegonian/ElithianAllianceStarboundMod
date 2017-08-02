require "/scripts/vec2.lua"
require "/scripts/util.lua"

function update()
  self.laserColour = animationConfig.animationParameter("laserColour") or {0,0,0,0}
  
  localAnimator.clearDrawables()
  local beams = animationConfig.animationParameter("beams") or {}
  
  for _,beam in pairs(beams) do
    local offset = beam.offset or {0,0}
    local maxLength = beam.length or 30
    local segmentCount = beam.segments or 1
    local angle = beam.angle or 0

    local beamPosition = vec2.add(activeItemAnimation.ownerPosition(), activeItemAnimation.handPosition(offset))
    local aimAngle = activeItemAnimation.ownerArmAngle() + angle
    local aimVector = {activeItemAnimation.ownerFacingDirection() * math.cos(aimAngle), math.sin(aimAngle)}

    local lineEnd = vec2.mul(aimVector, maxLength)

    local blocks = world.collisionBlocksAlongLine(beamPosition, vec2.add(beamPosition, lineEnd))
    if #blocks > 0 then
      blockPosition = blocks[1]
      --When approaching the block from the right or top, the intersecting edges will be the right or top ones
      if aimVector[1] < 0 then blockPosition[1] = blockPosition[1] + 1 end
      if aimVector[2] < 0 then blockPosition[2] = blockPosition[2] + 1 end

      local blockDistance = world.distance(blockPosition, beamPosition)

      -- If the block's edge is in a different direction than the aim direction
      -- it is impossible to have hit that edge, make sure we draw the beam to the other edge
      if aimVector[1] * (blockPosition[1] - beamPosition[1]) < 0 then blockDistance[1] = 0 end
      if aimVector[2] * (blockPosition[2] - beamPosition[2]) < 0 then blockDistance[2] = 0 end

      -- How long does the beam need to be to move 1 block in each axis
      local deltaDistX = 1 / math.abs(aimVector[1])
      local deltaDistY = 1 / math.abs(aimVector[2])

      -- How long does the beam need to be to reach the collided block on each axis
      local distX = math.abs(blockDistance[1]) * deltaDistX
      local distY = math.abs(blockDistance[2]) * deltaDistY

      -- The largest of the distances is the length of the beam when colliding with the block
      lineEnd = vec2.mul(aimVector, math.max(distX, distY))
    end


    local unit = vec2.norm(lineEnd)
    for i = 0, segmentCount-1 do
      if i * maxLength / segmentCount >= vec2.mag(lineEnd) then
        break
      end
      local startPosition = vec2.mul(unit, maxLength * i / segmentCount)
      local endPosition = vec2.mul(unit, math.min(vec2.mag(lineEnd), maxLength * (i+1) / segmentCount))
	  
	  local segmentColor = copy(self.laserColour)
      segmentColor[4] = segmentColor[4] * (1 - i/segmentCount)

	  if beam.renderLayer then
		localAnimator.addDrawable({line = {startPosition, endPosition}, width = beam.width or 1, color = segmentColor, position = beamPosition, fullbright = true}, beam.renderLayer)
	 else
	   localAnimator.addDrawable({line = {startPosition, endPosition}, width = beam.width or 1, color = segmentColor, position = beamPosition, fullbright = true})
	 end
    end
  end
end
