function init()
  self.buyFactor = config.getParameter("buyFactor", root.assetJson("/merchant.config").defaultBuyFactor)
  self.currency = config.getParameter("currency", "money")

  object.setInteractive(true)
end

function onInteraction(args)
  local interactData = config.getParameter("interactData")

  interactData.recipes = {}
  local addRecipes = function(items, category)
    for i, item in ipairs(items) do
      interactData.recipes[#interactData.recipes + 1] = generateRecipe(item, category)
    end
  end

  local storeInventory = config.getParameter("storeInventory")
  addRecipes(storeInventory.guaranteed, "guaranteed")

  --Shuffle random stock items every day
  local stockCycle = math.floor(os.time() / (config.getParameter("rotationTime") * #storeInventory.random))
  math.randomseed(stockCycle)
  shuffle(storeInventory.random)
  math.randomseed(os.time())
  local currentSelection = math.floor(os.time() / config.getParameter("rotationTime")) % #storeInventory.random + 1
  addRecipes(storeInventory.random[currentSelection], "random")

  return { "OpenCraftingInterface", interactData }
end

function generateRecipe(itemName, category)
  return {
	input = { {self.currency, math.floor(self.buyFactor * (root.itemConfig(itemName).config.price or 1000))} },
    output = itemName,
    groups = { category }
  }
end

function shuffle(list)
  for i=1,#list do
    local swapIndex = math.random(1,#list)
    list[i], list[swapIndex] = list[swapIndex], list[i]
  end
end
