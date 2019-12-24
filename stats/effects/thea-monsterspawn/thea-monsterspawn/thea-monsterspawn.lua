function init()
  animator.setAnimationState("teleport", "beamIn")
  effect.setParentDirectives("?multiply=ffffff00")

  if status.isResource("stunned") then
    status.setResource("stunned", math.max(status.resource("stunned"), effect.duration()))
  end
end

function update(dt)
  effect.setParentDirectives(string.format("?multiply=%s", animator.animationStateProperty("teleport", "multiply")))
end
