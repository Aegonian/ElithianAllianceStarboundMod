function init()
   effect.addStatModifierGroup({{stat = "avikanQuiver", amount = config.getParameter("damageBonus")}})

   script.setUpdateDelta(0)
end

function update(dt)

end

function uninit()
  
end
