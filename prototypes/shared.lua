-- Pieces shared by every tier: recipe categories, subgroups and the hidden
-- "cooler" machine that sits under each chamber or vault. Containers cannot
-- draw power or take fluids, so the cooler does that for them: while its
-- fixed cooling recipe runs, control.lua treats the container as cold.

local assembler_pictures = require("__base__.prototypes.entity.assembler-pictures")

GCS = GCS or {}
GCS.path = "__gleba-cold-storage__"

data:extend({
  { type = "recipe-category", name = "gcs-cooling" },
  { type = "recipe-category", name = "gcs-encapsulation" },
  { type = "item-subgroup", name = "gcs-cold-storage", group = "logistics", order = "b-a" },
  { type = "item-subgroup", name = "gcs-frozen", group = "intermediate-products", order = "z-gcs" },
  { type = "item-subgroup", name = "gcs-thawing", group = "intermediate-products", order = "z-gcs-b" },
})

--- Additive cold-mist loop drawn above a cooler while it works.
-- `strength` (0..1, default 1) dims it for machines whose art should show through.
function GCS.mist(scale, shift, strength)
  local k = strength or 1
  return {
    fadeout = true,
    -- The cooler sits exactly under its container; draw above the container.
    render_layer = "higher-object-under",
    animation = {
      filename = GCS.path .. "/graphics/entity/cold-chamber/cold-mist.png",
      priority = "extra-high",
      width = 256,
      height = 256,
      frame_count = 60,
      line_length = 8,
      animation_speed = 0.15,
      blend_mode = "additive",
      shift = shift or util.by_pixel(0, -6),
      scale = scale,
      tint = { k, k, k, k },
    },
  }
end

--- Soft blue glow under a working cooler.
function GCS.glow(size, intensity)
  return {
    fadeout = true,
    light = { intensity = intensity, size = size, color = { 0.45, 0.75, 1 }, shift = { 0, 0 } },
  }
end

GCS.hum_sound = {
  sound = { filename = GCS.path .. "/sound/fridge-hum.ogg", volume = 0.45, audible_distance_modifier = 0.6 },
  max_sounds_per_prototype = 3,
  fade_in_ticks = 10,
  fade_out_ticks = 30,
}

--- A fluid box for a cooler: `connections` is a list of {position, direction}.
function GCS.fluid_box(production_type, filter, connections)
  local pipe_connections = {}
  for _, c in pairs(connections) do
    pipe_connections[#pipe_connections + 1] = { flow_direction = production_type, position = c[1], direction = c[2] }
  end
  return {
    production_type = production_type,
    filter = filter,
    volume = 200,
    pipe_picture = assembler_pictures.assembler2pipepictures,
    pipe_covers = pipecoverspictures(),
    pipe_connections = pipe_connections,
    secondary_draw_orders = { north = -1 },
  }
end

--- The hidden cooler for a container of the given footprint.
-- @param spec {name, size, icon, recipe, energy_usage, fluid_boxes, mist_scale, mist_shift, glow_size, glow_layer}
-- glow_layer is an extra Animation drawn above the container while it cools.
function GCS.make_cooler(spec)
  local half = spec.size / 2
  local visualisations = {}
  if spec.glow_layer then
    visualisations[#visualisations + 1] = { fadeout = true, render_layer = "higher-object-under", animation = spec.glow_layer }
  end
  visualisations[#visualisations + 1] = GCS.mist(spec.mist_scale, spec.mist_shift, spec.mist_strength)
  visualisations[#visualisations + 1] = GCS.glow(spec.glow_size, 0.55)
  return {
    type = "assembling-machine",
    name = spec.name,
    localised_name = spec.localised_name or { "entity-name." .. spec.name },
    icon = spec.icon,
    hidden = true,
    hidden_in_factoriopedia = true,
    flags = {
      "not-on-map", "not-blueprintable", "not-deconstructable", "not-upgradable",
      "not-flammable", "not-repairable", "not-in-kill-statistics",
      "no-automated-item-insertion", "no-automated-item-removal", "hide-alt-info", "placeable-off-grid",
    },
    selectable_in_game = false,
    max_health = 1000,
    collision_box = { { -half + 0.15, -half + 0.15 }, { half - 0.15, half - 0.15 } },
    collision_mask = { layers = {} },
    selection_box = { { -half, -half }, { half, half } },
    crafting_categories = { "gcs-cooling" },
    fixed_recipe = spec.recipe,
    crafting_speed = 1,
    show_recipe_icon = false,
    show_recipe_icon_on_map = false,
    module_slots = 0,
    allowed_effects = {},
    effect_receiver = { uses_module_effects = false, uses_beacon_effects = false, uses_surface_effects = false },
    energy_usage = spec.energy_usage,
    energy_source = { type = "electric", usage_priority = "secondary-input", drain = "0W" },
    fluid_boxes = spec.fluid_boxes,
    graphics_set = {
      working_visualisations = visualisations,
    },
    working_sound = GCS.hum_sound,
  }
end

--- The fixed recipe a cooler runs. A chamber turns water into low-pressure
--- steam (it is a heat pump: the heat has to go somewhere); a vault only
--- needs power.
function GCS.make_cooling_recipe(name, water_per_second, steam_temperature)
  return {
    type = "recipe",
    name = name,
    icon = GCS.path .. "/graphics/icons/snowflake.png",
    categories = { "gcs-cooling" },
    hidden = true,
    hidden_in_factoriopedia = true,
    enabled = true,
    energy_required = 1,
    ingredients = water_per_second and { { type = "fluid", name = "water", amount = water_per_second } } or {},
    results = water_per_second and {
      { type = "fluid", name = "steam", amount = water_per_second, temperature = steam_temperature },
    } or {},
    allow_productivity = false,
    allow_quality = false,
    auto_recycle = false,
  }
end
