function init()
  effect.setParentDirectives("fade=E0318B=0.1?border=2;E0318B60;00000000")
  effect.addStatModifierGroup({{stat = "fallDamageMultiplier", effectiveMultiplier = 0}})
end

function update(dt)
  mcontroller.controlParameters({
      bounceFactor = 0.95
    })
end

function uninit()

end
