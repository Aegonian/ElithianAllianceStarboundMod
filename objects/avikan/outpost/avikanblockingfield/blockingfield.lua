function init()
  local enableCollision = config.getParameter("enableCollision")
  if enableCollision then
    physics.setCollisionEnabled(enableCollision, true)
  end
end
