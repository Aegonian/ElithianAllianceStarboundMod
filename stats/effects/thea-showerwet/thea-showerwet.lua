function init()
  
end

function update(dt)
  status.removeEphemeralEffect("wet")
  status.removeEphemeralEffect("burning")
end

function onExpire()
  status.addEphemeralEffect("wet", 5)
end
