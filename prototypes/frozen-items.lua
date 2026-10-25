-- Frozen variants of every perishable item: ten items sealed in one block of
-- ice that keeps `gcs-frozen-multiplier` times longer. Freshness carries over
-- through both recipes because ingredients pass their spoil percent on.

local I = GCS.path .. "/graphics/icons/"
local PER_BLOCK = 10
local multiplier = settings.startup["gcs-frozen-multiplier"].value
local preserve_science = settings.startup["gcs-preserve-science"].value
local MAX_SPOIL_TICKS = 4294967295

local ITEM_TYPES = { "item", "capsule", "tool", "ammo" }

--- Copy an item's icon layers, shrunk and shifted by `factor`.
local function shrunk_icons(item, factor)
  local layers = item.icons or { { icon = item.icon, icon_size = item.icon_size } }
  local result = {}
  for _, layer in pairs(layers) do
    local size = layer.icon_size or 64
    local copy = table.deepcopy(layer)
    copy.icon_size = size
    copy.scale = (layer.scale or (32 / size)) * factor
    if layer.shift then copy.shift = { layer.shift[1] * factor, layer.shift[2] * factor } end
    result[#result + 1] = copy
  end
  return result
end

local function frozen_icons(item)
  local icons = shrunk_icons(item, 0.8)
  icons[#icons + 1] = { icon = I .. "ice-overlay.png", icon_size = 64, scale = 0.5 }
  icons[#icons + 1] = { icon = I .. "snowflake.png", icon_size = 64, scale = 0.2, shift = { -10, -10 } }
  return icons
end

local function thaw_icons(item)
  local icons = shrunk_icons(item, 1)
  icons[#icons + 1] = { icon = I .. "thaw.png", icon_size = 64, scale = 0.2, shift = { 10, 10 } }
  return icons
end

local function item_name(item)
  return item.localised_name or { "item-name." .. item.name }
end

-- Anything a technology consumes counts as a science pack.
local science = {}
for _, technology in pairs(data.raw.technology) do
  for _, ingredient in pairs(technology.unit and technology.unit.ingredients or {}) do
    science[ingredient[1] or ingredient.name] = true
  end
end

local function eligible(item)
  if not item.spoil_ticks or item.spoil_ticks <= 0 then return false end
  if item.hidden or item.parameter then return false end
  if item.spoil_to_trigger_result then return false end -- eggs hatch; keep that danger
  if string.sub(item.name, 1, 4) == "gcs-" then return false end
  if science[item.name] and not preserve_science then return false end
  return true
end

local tech = data.raw.technology["gcs-cryo-encapsulation"]
local candidates = {}
for _, type_name in pairs(ITEM_TYPES) do
  for name, item in pairs(data.raw[type_name] or {}) do
    if eligible(item) then candidates[#candidates + 1] = { item = item } end
  end
end
table.sort(candidates, function(a, b) return a.item.name < b.item.name end)

for i, c in pairs(candidates) do
  local item = c.item
  local frozen = "gcs-frozen-" .. item.name
  local order = string.format("%03d", i)
  data:extend({
    {
      type = "item",
      name = frozen,
      localised_name = { "item-name.gcs-frozen", item_name(item) },
      localised_description = { "item-description.gcs-frozen", tostring(PER_BLOCK), item_name(item) },
      icons = frozen_icons(item),
      subgroup = "gcs-frozen",
      order = "b-" .. order,
      stack_size = math.max(1, math.floor((item.stack_size or 50) / PER_BLOCK)),
      weight = item.weight and item.weight * PER_BLOCK or nil,
      spoil_ticks = math.min(item.spoil_ticks * multiplier, MAX_SPOIL_TICKS),
      spoil_result = item.spoil_result,
      default_import_location = item.default_import_location,
    },
    {
      type = "recipe",
      name = "gcs-freeze-" .. item.name,
      localised_name = { "recipe-name.gcs-freeze", item_name(item) },
      categories = { "gcs-encapsulation" },
      enabled = false,
      energy_required = 2,
      ingredients = {
        { type = "item", name = item.name, amount = PER_BLOCK },
        { type = "item", name = "ice", amount = 1 },
      },
      results = { { type = "item", name = frozen, amount = 1 } },
      subgroup = "gcs-frozen",
      order = "b-" .. order,
      allow_productivity = false,
      auto_recycle = false,
      hide_from_player_crafting = true,
    },
    {
      type = "recipe",
      name = "gcs-thaw-" .. item.name,
      localised_name = { "recipe-name.gcs-thaw", item_name(item) },
      icons = thaw_icons(item),
      categories = { "gcs-encapsulation" },
      enabled = false,
      energy_required = 1,
      ingredients = { { type = "item", name = frozen, amount = 1 } },
      results = { { type = "item", name = item.name, amount = PER_BLOCK } },
      subgroup = "gcs-thawing",
      order = "b-" .. order,
      allow_productivity = false,
      auto_recycle = false,
      hide_from_player_crafting = true,
    },
  })
  table.insert(tech.effects, { type = "unlock-recipe", recipe = "gcs-freeze-" .. item.name })
  table.insert(tech.effects, { type = "unlock-recipe", recipe = "gcs-thaw-" .. item.name })
end
