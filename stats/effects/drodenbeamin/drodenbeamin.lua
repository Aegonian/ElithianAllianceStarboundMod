function init()
  animator.setAnimationState("teleport", "beamIn")
  effect.setParentDirectives("?multiply=ffffff00")
  animator.setGlobalTag("effectDirectives", status.statusProperty("effectDirectives", ""))

  local speciesTags = config.getParameter("speciesTags")
  if status.statusProperty("species") then
    animator.setGlobalTag("species", speciesTags[status.statusProperty("species")] or "")
  end
end

function update(dt)
  effect.setParentDirectives(string.format("?multiply=%s", animator.animationStateProperty("teleport", "multiply")))
end