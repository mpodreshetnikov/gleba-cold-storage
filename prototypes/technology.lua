local T = GCS.path .. "/graphics/technology/"

local function packs(list)
  local result = {}
  for _, name in pairs(list) do result[#result + 1] = { name, 1 } end
  return result
end

local GLEBA = { "automation-science-pack", "logistic-science-pack", "chemical-science-pack",
                "space-science-pack", "agricultural-science-pack" }
local AQUILO = { "automation-science-pack", "logistic-science-pack", "chemical-science-pack",
                 "production-science-pack", "utility-science-pack", "space-science-pack",
                 "agricultural-science-pack", "cryogenic-science-pack" }

data:extend({
  {
    type = "technology",
    name = "gcs-cold-chamber",
    icon = T .. "cold-chamber.png",
    icon_size = 256,
    prerequisites = { "agricultural-science-pack" },
    effects = { { type = "unlock-recipe", recipe = "gcs-cold-chamber" } },
    unit = { count = 300, ingredients = packs(GLEBA), time = 30 },
  },
  {
    type = "technology",
    name = "gcs-cryo-vault",
    icon = T .. "cryo-vault.png",
    icon_size = 256,
    prerequisites = { "gcs-cold-chamber", "cryogenic-science-pack", "logistic-system" },
    effects = {
      { type = "unlock-recipe", recipe = "gcs-cryo-vault" },
      { type = "unlock-recipe", recipe = "gcs-cryo-vault-passive-provider" },
      { type = "unlock-recipe", recipe = "gcs-cryo-vault-requester" },
      { type = "unlock-recipe", recipe = "gcs-cryo-vault-buffer" },
      { type = "unlock-recipe", recipe = "gcs-refrigerated-wagon" },
      { type = "unlock-recipe", recipe = "gcs-empty-cryo-cell" },
      { type = "unlock-recipe", recipe = "gcs-cryo-cell" },
    },
    unit = { count = 1000, ingredients = packs(AQUILO), time = 60 },
  },
  {
    type = "technology",
    name = "gcs-cryo-encapsulation",
    icon = T .. "encapsulation.png",
    icon_size = 256,
    prerequisites = { "gcs-cryo-vault" },
    effects = {
      { type = "unlock-recipe", recipe = "gcs-cryo-encapsulator" },
      { type = "unlock-recipe", recipe = "gcs-freeze-water" },
    },
    unit = { count = 1500, ingredients = packs(AQUILO), time = 60 },
  },
})
