-- Tier 2: refrigerated cargo wagon. Smaller than a cargo wagon and only cold
-- while its equipment grid can pay for cooling (control.lua drains the batteries).

local P = GCS.path .. "/graphics/entity/wagon/"
local ICON = GCS.path .. "/graphics/icons/refrigerated-wagon.png"

local wagon = table.deepcopy(data.raw["cargo-wagon"]["cargo-wagon"])
wagon.name = "gcs-refrigerated-wagon"
wagon.icon = ICON
wagon.icon_size = 64
wagon.icons = nil
wagon.minable.result = "gcs-refrigerated-wagon"
wagon.inventory_size = 30
wagon.weight = wagon.weight * 1.25
wagon.color = { r = 0.55, g = 0.8, b = 0.95, a = 1 }
wagon.equipment_grid = "gcs-wagon-grid"
wagon.factoriopedia_simulation = nil

local body_tint = { r = 0.72, g = 0.88, b = 1 }
for _, layer in pairs(wagon.pictures.rotated.layers) do
  if not layer.draw_as_shadow and not (layer.flags and layer.flags[1] == "mask") then
    layer.tint = body_tint
  end
end
if wagon.pictures.sloped then
  for _, layer in pairs(wagon.pictures.sloped.layers) do
    if not layer.draw_as_shadow and not (layer.flags and layer.flags[1] == "mask") then
      layer.tint = body_tint
    end
  end
end

local function door(layer, file, width, height)
  layer.filename = P .. file
  layer.filenames = nil
  layer.width = width
  layer.height = height
  layer.size = nil
  layer.line_length = nil
  layer.lines_per_file = nil
  layer.scale = 0.5
  layer.frame_count = 8
end
door(wagon.vertical_doors.layers[1], "cargo-wagon-door-vertical.png", 118, 402)
door(wagon.vertical_doors.layers[2], "cargo-wagon-door-vertical-mask.png", 110, 332)
door(wagon.horizontal_doors.layers[1], "cargo-wagon-door-horizontal.png", 438, 84)
door(wagon.horizontal_doors.layers[2], "cargo-wagon-door-horizontal-mask.png", 368, 80)
wagon.horizontal_doors.layers[1].line_length = 1
wagon.horizontal_doors.layers[2].line_length = 1

wagon.minimap_representation.filename = P .. "minimap.png"

data:extend({
  wagon,
  { type = "equipment-category", name = "gcs-wagon-power" },
  {
    type = "equipment-grid",
    name = "gcs-wagon-grid",
    width = 6,
    height = 4,
    equipment_categories = { "gcs-wagon-power" },
  },
  {
    type = "item-with-entity-data",
    name = "gcs-refrigerated-wagon",
    icon = ICON,
    subgroup = "gcs-cold-storage",
    order = "c[refrigerated-wagon]",
    inventory_move_sound = data.raw["item-with-entity-data"]["cargo-wagon"].inventory_move_sound,
    pick_sound = data.raw["item-with-entity-data"]["cargo-wagon"].pick_sound,
    drop_sound = data.raw["item-with-entity-data"]["cargo-wagon"].drop_sound,
    place_result = "gcs-refrigerated-wagon",
    stack_size = 5,
    weight = 250 * kg,
    default_import_location = "aquilo",
  },
  {
    type = "recipe",
    name = "gcs-refrigerated-wagon",
    enabled = false,
    energy_required = 10,
    ingredients = {
      { type = "item", name = "cargo-wagon", amount = 1 },
      { type = "item", name = "gcs-cold-chamber", amount = 2 },
      { type = "item", name = "lithium-plate", amount = 10 },
      { type = "item", name = "processing-unit", amount = 5 },
    },
    results = { { type = "item", name = "gcs-refrigerated-wagon", amount = 1 } },
  },
})
