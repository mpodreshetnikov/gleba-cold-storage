-- Tier 3: the cryo-encapsulator. Freezes water into ice and seals perishables
-- in ice blocks that keep for much longer, so they survive rocket trips.
-- No modules and no beacons: the freeze/thaw loop must not create quality or
-- productivity out of thin air.

local item_sounds = require("__base__.prototypes.item_sounds")
local hit_effects = require("__base__.prototypes.entity.hit-effects")
local sounds = require("__base__.prototypes.entity.sounds")
local CMA = require("prototypes.cma.graphics")
local assembler_pictures = require("__base__.prototypes.entity.assembler-pictures")

local ICON = GCS.path .. "/graphics/icons/encapsulator.png"
local ICE = { 0.6, 0.85, 1 }

-- CMA Graphics' Mk2 industrial press, pressing ice-blue blocks. Built on the
-- assembling machine 2 footprint, so its pipes are the vanilla assembler's.
local G = {}
for _, d in pairs({ "north", "east", "south", "west" }) do
  G[d] = CMA("industrial-press", "mk2-" .. d)
  G[d].tint.tint = ICE
  G[d].emission.tint = ICE
end

--- Hoarfrost creeping over the press while it works, frame by frame.
local function frost(g, d)
  local m = g.base
  return {
    filename = GCS.path .. "/graphics/entity/encapsulator/frost-" .. d .. ".png",
    width = m.width, height = m.height, frame_count = m.frame_count, line_length = m.line_length,
    animation_speed = m.animation_speed, scale = 0.5, shift = m.shift,
  }
end

local function four(f)
  return { north = f(G.north), east = f(G.east), south = f(G.south), west = f(G.west) }
end

data:extend({
  {
    type = "assembling-machine",
    name = "gcs-cryo-encapsulator",
    icon = ICON,
    flags = { "placeable-neutral", "placeable-player", "player-creation" },
    minable = { mining_time = 0.5, result = "gcs-cryo-encapsulator" },
    max_health = 400,
    corpse = "medium-remnants",
    dying_explosion = "medium-explosion",
    damaged_trigger_effect = hit_effects.entity(),
    resistances = { { type = "fire", percent = 70 } },
    collision_box = { { -1.2, -1.2 }, { 1.2, 1.2 } },
    selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } },
    crafting_categories = { "gcs-encapsulation" },
    crafting_speed = 1,
    module_slots = 0,
    allowed_effects = { "consumption", "speed", "pollution" },
    effect_receiver = { uses_module_effects = false, uses_beacon_effects = false, uses_surface_effects = false },
    energy_usage = "1MW",
    energy_source = { type = "electric", usage_priority = "secondary-input", drain = "30kW", emissions_per_minute = { pollution = 1 } },
    heating_energy = "100kW", -- freezes on Aquilo like the machines it is built from
    fluid_boxes = {
      {
        production_type = "input",
        volume = 200,
        pipe_picture = assembler_pictures.assembler2pipepictures,
        pipe_covers = pipecoverspictures(),
        pipe_connections = {
          { flow_direction = "input-output", direction = defines.direction.north, position = { 0, -1 } },
          { flow_direction = "input-output", direction = defines.direction.south, position = { 0, 1 } },
        },
        secondary_draw_orders = { north = -1 },
      },
    },
    fluid_boxes_off_when_no_fluid_recipe = true,
    graphics_set = {
      animation = four(function(g) return { layers = { g.base, g.tint, g.shadow } } end),
      working_visualisations = {
        {
          fadeout = true,
          north_animation = frost(G.north, "north"), east_animation = frost(G.east, "east"),
          south_animation = frost(G.south, "south"), west_animation = frost(G.west, "west"),
        },
        {
          fadeout = true,
          north_animation = G.north.emission, east_animation = G.east.emission,
          south_animation = G.south.emission, west_animation = G.west.emission,
        },
        GCS.mist(0.65, util.by_pixel(0, -10), 0.6), -- the same cold mist as the cryo vault
        GCS.glow(8, 0.5),
      },
      frozen_patch = four(function(g) return g.frozen end),
      reset_animation_when_frozen = true,
    },
    drawing_box_vertical_extension = 1,
    open_sound = sounds.machine_open,
    close_sound = sounds.machine_close,
    impact_category = "metal",
    working_sound = {
      sound = { filename = "__base__/sound/electric-furnace.ogg", volume = 0.35 },
      idle_sound = { filename = "__base__/sound/idle1.ogg", volume = 0.5 },
      fade_in_ticks = 4,
      fade_out_ticks = 20,
    },
    circuit_connector = circuit_connector_definitions["assembling-machine"],
    circuit_wire_max_distance = default_circuit_wire_max_distance,
  },
  {
    type = "item",
    name = "gcs-cryo-encapsulator",
    icon = ICON,
    subgroup = "gcs-cold-storage",
    order = "d[cryo-encapsulator]",
    inventory_move_sound = item_sounds.mechanical_inventory_move,
    pick_sound = item_sounds.mechanical_inventory_pickup,
    drop_sound = item_sounds.mechanical_inventory_move,
    place_result = "gcs-cryo-encapsulator",
    stack_size = 10,
    weight = 100 * kg,
    default_import_location = "aquilo",
  },
  {
    type = "recipe",
    name = "gcs-cryo-encapsulator",
    categories = { "cryogenics" },
    enabled = false,
    energy_required = 15,
    ingredients = {
      { type = "item", name = "gcs-cold-chamber", amount = 1 },
      { type = "item", name = "lithium-plate", amount = 20 },
      { type = "item", name = "processing-unit", amount = 10 },
      { type = "item", name = "pump", amount = 2 },
      { type = "fluid", name = "fluoroketone-cold", amount = 100 },
    },
    results = { { type = "item", name = "gcs-cryo-encapsulator", amount = 1 } },
    allow_productivity = false,
  },
  {
    type = "recipe",
    name = "gcs-freeze-water",
    categories = { "gcs-encapsulation" },
    enabled = false,
    energy_required = 2,
    ingredients = { { type = "fluid", name = "water", amount = 20 } },
    results = { { type = "item", name = "ice", amount = 1 } },
    subgroup = "gcs-frozen",
    order = "a",
    allow_productivity = false,
    auto_recycle = false,
  },
})
