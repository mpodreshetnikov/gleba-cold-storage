-- Tier 2: the cryo vault. A 3x3 deep-cold store that nearly stops spoilage,
-- plus requester, passive provider and buffer variants for logistic networks.

local item_sounds = require("__base__.prototypes.item_sounds")
local hit_effects = require("__base__.prototypes.entity.hit-effects")
local sounds = require("__base__.prototypes.entity.sounds")

local I = GCS.path .. "/graphics/icons/"
local CMA = require("prototypes.cma.graphics")

-- The vault is CMA Graphics' Mk3 pressure tank. Its glow rings belong to
-- the hidden cooler, so they only light up while the vault is cooling, in
-- the colour of the vault's logistic mode.
local function vault_graphics(suffix)
  return CMA("pressure-tank", "mk3-north", { emission = suffix })
end

local VARIANTS = {
  { suffix = "", order = "b[cryo-vault]-a" },
  { suffix = "-passive-provider", mode = "passive-provider", order = "b[cryo-vault]-b" },
  { suffix = "-requester", mode = "requester", order = "b[cryo-vault]-c", trash = 10 },
  { suffix = "-buffer", mode = "buffer", order = "b[cryo-vault]-d", trash = 10 },
}

for _, v in pairs(VARIANTS) do
  local name = "gcs-cryo-vault" .. v.suffix
  local icon = I .. "cryo-vault" .. v.suffix .. ".png"
  local entity = {
    type = v.mode and "logistic-container" or "container",
    name = name,
    icon = icon,
    flags = { "placeable-neutral", "placeable-player", "player-creation" },
    minable = { mining_time = 0.6, result = name },
    max_health = 800,
    corpse = "medium-remnants",
    dying_explosion = "medium-explosion",
    damaged_trigger_effect = hit_effects.entity(),
    resistances = { { type = "fire", percent = 70 }, { type = "impact", percent = 60 } },
    collision_box = { { -1.35, -1.35 }, { 1.35, 1.35 } },
    selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } },
    inventory_size = 48,
    inventory_type = "with_filters_and_bar",
    icon_draw_specification = { scale = 1 },
    picture = { layers = { vault_graphics(v.suffix).idle, vault_graphics(v.suffix).shadow } },
    open_sound = sounds.metallic_chest_open,
    close_sound = sounds.metallic_chest_close,
    impact_category = "metal",
    circuit_connector = circuit_connector_definitions.create_vector(universal_connector_template,
      { { variation = 26, main_offset = util.by_pixel(36, 34), shadow_offset = util.by_pixel(40, 37), show_shadow = true } }),
    circuit_wire_max_distance = default_circuit_wire_max_distance,
    fast_replaceable_group = "gcs-cryo-vault",
  }
  if v.mode then
    entity.logistic_mode = v.mode
    entity.trash_inventory_size = v.trash
  end

  local ingredients = { { type = "item", name = "gcs-cryo-vault", amount = 1 } }
  if v.mode then
    ingredients[2] = { type = "item", name = v.mode .. "-chest", amount = 1 }
  end

  data:extend({
    entity,
    {
      type = "item",
      name = name,
      icon = icon,
      subgroup = "gcs-cold-storage",
      order = v.order,
      inventory_move_sound = item_sounds.metal_chest_inventory_move,
      pick_sound = item_sounds.metal_chest_inventory_pickup,
      drop_sound = item_sounds.metal_chest_inventory_move,
      place_result = name,
      stack_size = 10,
      weight = 100 * kg,
      default_import_location = "aquilo",
    },
  })

  data:extend({
    GCS.make_cooler({
      name = name .. "-cooler",
      localised_name = { "entity-name.gcs-cryo-vault-cooler" },
      size = 3,
      icon = icon,
      recipe = "gcs-vault-cooling",
      energy_usage = "300kW",
      mist_scale = 0.65,
      mist_shift = util.by_pixel(0, -10),
      mist_strength = 0.6,
      glow_size = 9,
      glow_layer = vault_graphics(v.suffix).emission,
    }),
  })

  if v.mode then
    data:extend({
      {
        type = "recipe",
        name = name,
        enabled = false,
        energy_required = 5,
        ingredients = ingredients,
        results = { { type = "item", name = name, amount = 1 } },
      },
    })
  end
end

data:extend({
  {
    type = "recipe",
    name = "gcs-cryo-vault",
    categories = { "cryogenics" },
    enabled = false,
    energy_required = 20,
    ingredients = {
      { type = "item", name = "gcs-cold-chamber", amount = 2 },
      { type = "item", name = "lithium-plate", amount = 10 },
      { type = "item", name = "steel-plate", amount = 20 },
      { type = "item", name = "processing-unit", amount = 5 },
      { type = "fluid", name = "fluoroketone-cold", amount = 50 },
    },
    results = { { type = "item", name = "gcs-cryo-vault", amount = 1 } },
    allow_productivity = false,
  },
  GCS.make_cooling_recipe("gcs-vault-cooling", nil),
})
