function init()
  self.currency = config.getParameter("currency", "money")
  self.regularPrice = config.getParameter("regularPrice", 1000)
  self.augmentPrice = config.getParameter("augmentPrice", 1000)
  self.randomWeaponPrice = config.getParameter("randomWeaponPrice", 1000)

  object.setInteractive(true)
end

function onInteraction(args)
  local interactData = config.getParameter("interactData")

  --Create an empty list of recipes
  interactData.recipes = {}
  --Build the function used to populate the list
  local addRecipes = function(items, category, price)
    for i, item in ipairs(items) do
      interactData.recipes[#interactData.recipes + 1] = generateRecipe(item, category, price)
    end
  end

  --Load in our statis stock
  local storeInventory = config.getParameter("storeInventory")
  addRecipes(storeInventory.guaranteed, "guaranteed", self.regularPrice)
  addRecipes(storeInventory.augments, "augments", self.augmentPrice)

  --Shuffle random stock items every day
  local stockCycle = math.floor(os.time() / (config.getParameter("rotationTime") * #storeInventory.randomWeapon))
  math.randomseed(stockCycle)
  shuffle(storeInventory.randomWeapon)
  math.randomseed(os.time())
  local currentSelection = math.floor(os.time() / config.getParameter("rotationTime")) % #storeInventory.randomWeapon + 1
  addRecipes(storeInventory.randomWeapon[currentSelection], "randomWeapon", self.randomWeaponPrice)

  return { "OpenCraftingInterface", interactData }
end

function generateRecipe(itemName, category, price)
  return {
	input = { {self.currency, price} },
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
