-- Tier 1: the cold chamber. A small 2x2 chest for Gleba that needs power and
-- water to keep its contents cold and has to get rid of the steam it makes.

local item_sounds = require("__base__.prototypes.item_sounds")
local hit_effects = require("__base__.prototypes.entity.hit-effects")
local sounds = require("__base__.prototypes.entity.sounds")

local P = GCS.path .. "/graphics/entity/cold-chamber/"
local ICON = GCS.path .. "/graphics/icons/cold-chamber.png"

local function chamber_picture()
  return {
    layers = {
      { filename = P .. "cold-chamber.png", priority = "extra-high", width = 256, height = 256, scale = 0.5 },
      {
        filename = P .. "cold-chamber-door.png", priority = "extra-high",
        width = 66, height = 30, x = 0, y = 0, shift = util.by_pixel(0, -10), scale = 0.5,
      },
      {
        filename = P .. "cold-chamber-shadow.png", priority = "extra-high",
        width = 256, height = 256, scale = 0.5, draw_as_shadow = true,
      },
    },
  }
end

data:extend({
  {
    type = "container",
    name = "gcs-cold-chamber",
    icon = ICON,
    flags = { "placeable-neutral", "placeable-player", "player-creation" },
    minable = { mining_time = 0.3, result = "gcs-cold-chamber" },
    max_health = 350,
    corpse = "medium-small-remnants",
    dying_explosion = "buffer-chest-explosion",
    damaged_trigger_effect = hit_effects.entity(),
    resistances = { { type = "fire", percent = 50 }, { type = "impact", percent = 50 } },
    collision_box = { { -0.85, -0.85 }, { 0.85, 0.85 } },
    selection_box = { { -1, -1 }, { 1, 1 } },
    inventory_size = 12,
    inventory_type = "with_filters_and_bar",
    icon_draw_specification = { scale = 0.7 },
    picture = chamber_picture(),
    open_sound = sounds.metallic_chest_open,
    close_sound = sounds.metallic_chest_close,
    impact_category = "metal",
    circuit_connector = circuit_connector_definitions.create_vector(universal_connector_template,
      { { variation = 26, main_offset = util.by_pixel(20, 18), shadow_offset = util.by_pixel(24, 21), show_shadow = true } }),
    circuit_wire_max_distance = default_circuit_wire_max_distance,
    fast_replaceable_group = "gcs-cold-storage",
    -- The water inlets belong to the hidden cooler, so the game cannot show
    -- them while placing; this overlay marks the water inlets (blue, pointing
    -- in) and steam outlets (orange, pointing out).
    radius_visualisation_specification = {
      sprite = { filename = P .. "pipe-hint.png", width = 256, height = 256 },
      distance = 2,
      draw_in_cursor = true,
      draw_on_selection = true,
    },
  },
  GCS.make_cooler({
    name = "gcs-cold-chamber-cooler",
    size = 2,
    icon = ICON,
    recipe = "gcs-chamber-cooling",
    energy_usage = "250kW",
    -- Water in on the north and west, steam out on the south and east.
    fluid_boxes = {
      GCS.fluid_box("input", "water", {
        { { -0.5, -0.5 }, defines.direction.north },
        { { -0.5, 0.5 }, defines.direction.west },
      }),
      GCS.fluid_box("output", "steam", {
        { { 0.5, 0.5 }, defines.direction.south },
        { { 0.5, -0.5 }, defines.direction.east },
      }),
    },
    mist_scale = 0.5,
    glow_size = 6,
  }),
  GCS.make_cooling_recipe("gcs-chamber-cooling", 6, 100),
  {
    type = "item",
    name = "gcs-cold-chamber",
    icon = ICON,
    subgroup = "gcs-cold-storage",
    order = "a[cold-chamber]",
    inventory_move_sound = item_sounds.metal_chest_inventory_move,
    pick_sound = item_sounds.metal_chest_inventory_pickup,
    drop_sound = item_sounds.metal_chest_inventory_move,
    place_result = "gcs-cold-chamber",
    stack_size = 20,
    weight = 40 * kg,
    default_import_location = "gleba",
  },
  {
    type = "recipe",
    name = "gcs-cold-chamber",
    enabled = false,
    energy_required = 5,
    ingredients = {
      { type = "item", name = "steel-plate", amount = 5 },
      { type = "item", name = "copper-plate", amount = 20 },
      { type = "item", name = "plastic-bar", amount = 10 },
      { type = "item", name = "electronic-circuit", amount = 5 },
    },
    results = { { type = "item", name = "gcs-cold-chamber", amount = 1 } },
  },
})
