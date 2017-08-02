
function init()
  message.setHandler("triggerSale", finishSale)
  object.setInteractive(true)
end

function update(dt)
  
end

function finishSale()
  world.containerTakeAll(entity.id())
end
