require "/scripts/vec2.lua"
require "/scripts/util.lua"

--===================================================================================
-- LIGHTNING SCRIPT UTILS
--===================================================================================
function drawLightning(startLine, endLine, displacement, minDisplacement, forks, forkAngleRange, width, color)
  if displacement < minDisplacement then
    local position = startLine
    endLine = vec2.sub(endLine, startLine)
    startLine = {0,0}
    localAnimator.addDrawable({line = {startLine, endLine}, width = width, color = color, position = position, fullbright = true})
  else
    local mid = {(startLine[1] + endLine[1]) / 2, (startLine[2] + endLine[2]) / 2}
    mid = vec2.add(mid, randomOffset(displacement))
    drawLightning(startLine, mid, displacement / 2, minDisplacement, forks - 1, forkAngleRange, width, color)
    drawLightning(mid, endLine, displacement / 2, minDisplacement, forks - 1, forkAngleRange, width, color)

    if forks > 0 then
      local direction = vec2.sub(mid, startLine)
      local length = vec2.mag(direction) / 2
      local angle = math.atan(direction[2], direction[1]) + randomInRange(forkAngleRange)
      forkEnd = vec2.mul({math.cos(angle), math.sin(angle)}, length)
      drawLightning(mid, vec2.add(mid, forkEnd), displacement / 2, minDisplacement, forks - 1, forkAngleRange, width, color)
    end
  end
end

function randomInRange(range)
  return -range + math.random() * 2 * range
end

function randomOffset(range)
  return {randomInRange(range), randomInRange(range)}
end

function update()
  localAnimator.clearDrawables()

  --===================================================================================
  -- LIGHTNING SCRIPT
  --===================================================================================
  local tickRate = animationConfig.animationParameter("lightningTickRate") or 25

  local lightningSeed = animationConfig.animationParameter("lightningSeed")
  if not lightningSeed then
    local millis = math.floor((os.time() + (os.clock() % 1)) * 1000)
    lightningSeed = math.floor(millis / tickRate)
  end
  math.randomseed(lightningSeed)

  local getLinePosition = function(bolt, positionType)
    return bolt["world"..positionType.."Position"]
      or (bolt["item"..positionType.."Position"] and vec2.add(activeItemAnimation.ownerPosition(), activeItemAnimation.handPosition(bolt["item"..positionType.."Position"])))
      or (bolt["part"..positionType.."Position"] and vec2.add(activeItemAnimation.ownerPosition(),
        activeItemAnimation.handPosition(animationConfig.partPoint(bolt["part"..positionType.."Position"][1], bolt["part"..positionType.."Position"][2]))))
  end

  local lightningBolts = animationConfig.animationParameter("lightning")
  if lightningBolts then
    for _, bolt in pairs(lightningBolts) do
      local startPosition = getLinePosition(bolt, "Start")
      local endPosition = getLinePosition(bolt, "End")
      endPosition = vec2.add(startPosition, world.distance(endPosition, startPosition))
      if bolt.endPointDisplacement then
        endPosition = vec2.add(endPosition, randomOffset(bolt.endPointDisplacement))
      end
      drawLightning(startPosition, endPosition, bolt.displacement, bolt.minDisplacement, bolt.forks, bolt.forkAngleRange, bolt.width, bolt.color)
    end
  end


  --===================================================================================
  -- CHAIN SCRIPT
  --===================================================================================
  self.chains = animationConfig.animationParameter("chains") or {}
  
  for _, chain in pairs(self.chains) do
    local continue = false
    if chain.targetEntityId then
      if world.entityExists(chain.targetEntityId) then
        chain.endPosition = world.entityPosition(chain.targetEntityId)
      end
    end
    if chain.sourcePart then
      local beamSource = animationConfig.partPoint(chain.sourcePart, "beamSource")
      if beamSource then
        chain.startPosition = vec2.add(entity.position(), beamSource)
      else
        continue = true
      end
    end
    if chain.endPart then
      local beamEnd = animationConfig.partPoint(chain.endPart, "beamEnd")
      if beamEnd then
        chain.endPosition = vec2.add(entity.position(), beamEnd)
      else
        continue = true
      end
    end

    if not continue and (not chain.targetEntityId or world.entityExists(chain.targetEntityId)) then
      -- sb.logInfo("Building drawables for chain %s", chain)
      local startPosition = chain.startPosition or vec2.add(activeItemAnimation.ownerPosition(), activeItemAnimation.handPosition(chain.startOffset))
      local endPosition = chain.endPosition or vec2.add(activeItemAnimation.ownerPosition(), activeItemAnimation.handPosition(chain.endOffset))

      if chain.maxLength then
        endPosition = vec2.add(startPosition, vec2.mul(vec2.norm(world.distance(endPosition, startPosition)), chain.maxLength))
      end

      if chain.testCollision then
        local angle = vec2.angle(world.distance(endPosition, startPosition))
         -- lines starting on tile boundaries will collide with the tile
         -- work around this by starting the collision check a small distance along the line from the actual start position
        local collisionStart = vec2.add(startPosition, vec2.withAngle(angle, 0.01))
        local collision = world.lineTileCollisionPoint(startPosition, endPosition)
        if collision then
          local collidePosition, normal = collision[1], collision[2]
          if chain.bounces and chain.bounces > 0 then
            local length = world.magnitude(endPosition, startPosition) - world.magnitude(collidePosition, startPosition)
            local newChain = copy(chain)
            newChain.sourcePart, newChain.endPart, newChain.targetEntityId = nil, nil, nil
            newChain.startPosition = collidePosition
            newChain.endPosition = vec2.add(collidePosition, vec2.mul(vec2.withAngle(angle, length), normal[1] == 0 and {1, -1} or {-1, 1}))
            newChain.bounces = chain.bounces - 1
            table.insert(self.chains, newChain)
          end

          endPosition = collidePosition
        end
      end

      local chainVec = world.distance(endPosition, startPosition)
      local chainDirection = chainVec[1] < 0 and -1 or 1
      local chainLength = vec2.mag(chainVec)

      local arcAngle = 0
      if chain.arcRadius then
        arcAngle = chainDirection * 2 * math.asin(chainLength / (2 * chain.arcRadius))
        chainLength = chainDirection * arcAngle * chain.arcRadius
      end

      local segmentCount = math.floor(((chainLength + (chain.overdrawLength or 0)) / chain.segmentSize) + 0.5)
      if segmentCount > 0 then
        local chainStartAngle = vec2.angle(chainVec) - arcAngle / 2
        if chainVec[1] < 0 then chainStartAngle = math.pi - chainStartAngle end

        local segmentOffset = vec2.mul(vec2.norm(chainVec), chain.segmentSize)
        segmentOffset = vec2.rotate(segmentOffset, -arcAngle / 2)
        local currentBaseOffset = vec2.add(startPosition, vec2.mul(segmentOffset, 0.5))
        local lastDrawnSegment = chain.drawPercentage and math.ceil(segmentCount * chain.drawPercentage) or segmentCount
        for i = 1, lastDrawnSegment do
          local image = chain.segmentImage
          if i == 1 and chain.startSegmentImage then
            image = chain.startSegmentImage
          elseif i == lastDrawnSegment and chain.endSegmentImage then
            image = chain.endSegmentImage
          end

          -- taper applies evenly from full size at the start to (1.0 - chain.taper) size at the end
          if chain.taper then
            local taperFactor = 1 - ((i - 1) / lastDrawnSegment) * chain.taper
            image = image .. "?scale=1.0=" .. util.round(taperFactor, 1)
          end

          -- per-segment offsets (jitter, waveform, etc)
          local thisOffset = {0, 0}
          if chain.jitter then
            thisOffset = vec2.add(thisOffset, {0, (math.random() - 0.5) * chain.jitter})
          end
          if chain.waveform then
            local angle = ((i * chain.segmentSize) - (os.clock() * (chain.waveform.movement or 0))) / (chain.waveform.frequency / math.pi)
            local sineVal = math.sin(angle) * chain.waveform.amplitude * 0.5
            thisOffset = vec2.add(thisOffset, {0, sineVal})
          end

          local segmentAngle = chainStartAngle + (i - 1) * chainDirection * (arcAngle / segmentCount)

          thisOffset = vec2.rotate(thisOffset, chainVec[1] >= 0 and segmentAngle or -segmentAngle)

          local drawable = {
            image = image,
            centered = true,
            mirrored = chainVec[1] < 0,
            rotation = segmentAngle,
            position = vec2.add(currentBaseOffset, thisOffset),
            fullbright = chain.fullbright or false
          }

          localAnimator.addDrawable(drawable, chain.renderLayer)

          segmentOffset = vec2.rotate(segmentOffset, arcAngle / segmentCount)
          currentBaseOffset = vec2.add(currentBaseOffset, segmentOffset)
        end
      end
    end
  end
end
