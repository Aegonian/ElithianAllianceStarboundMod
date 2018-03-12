function init()
   effect.addStatModifierGroup({
	{stat = "fireStatusImmunity", amount = 1},
	{stat = "iceStatusImmunity", amount = 1},
	{stat = "electricStatusImmunity", amount = 1},
	{stat = "poisonStatusImmunity", amount = 1},
	{stat = "linerifleStatusImmunity", amount = 1},
	{stat = "centensianenergyStatusImmunity", amount = 1},
	{stat = "xanafianStatusImmunity", amount = 1},
	{stat = "akkimariacidStatusImmunity", amount = 1},
	{stat = "bleedingImmunity", amount = 1}
  })

   script.setUpdateDelta(0)
end

function update(dt)

end

function uninit()

end
