function init()
  self.floatingObjectCycle = config.getParameter("floatingObjectCycle", 1.0) / (2 * math.pi)
  self.floatingObjectMaxTransform = config.getParameter("floatingObjectMaxTransform", 1.0)
  self.timer = 0
  
  animator.resetTransformationGroup("floatingObject")
end

function update(dt)
  self.timer = self.timer + dt
  local offset = math.sin(self.timer / self.floatingObjectCycle) * self.floatingObjectMaxTransform
	
  animator.resetTransformationGroup("floatingObject")
  animator.translateTransformationGroup("floatingObject", {0, offset})
end
