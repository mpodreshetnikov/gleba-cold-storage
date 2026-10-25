-- Cryo cells: the coolant a cryo vault burns. They can only be charged on
-- Aquilo (fluoroketone + ice, low pressure) and they thaw back into empty
-- cells within an hour, so every vault off Aquilo hangs on a steady
-- interplanetary supply, mirroring Gleba's own race against spoilage.

local I = GCS.path .. "/graphics/icons/"
local item_sounds = require("__base__.prototypes.item_sounds")

data:extend({
  {
    type = "item",
    name = "gcs-cryo-cell",
    icon = I .. "cryo-cell.png",
    subgroup = "gcs-cold-storage",
    order = "e[cryo-cell]-a",
    inventory_move_sound = item_sounds.metal_small_inventory_move,
    pick_sound = item_sounds.metal_small_inventory_pickup,
    drop_sound = item_sounds.metal_small_inventory_move,
    stack_size = 20,
    weight = 10 * kg,
    spoil_ticks = 60 * minute,
    spoil_result = "gcs-empty-cryo-cell",
    default_import_location = "aquilo",
  },
  {
    type = "item",
    name = "gcs-empty-cryo-cell",
    icon = I .. "empty-cryo-cell.png",
    subgroup = "gcs-cold-storage",
    order = "e[cryo-cell]-b",
    inventory_move_sound = item_sounds.metal_small_inventory_move,
    pick_sound = item_sounds.metal_small_inventory_pickup,
    drop_sound = item_sounds.metal_small_inventory_move,
    stack_size = 50,
    weight = 5 * kg,
    default_import_location = "aquilo",
  },
  {
    type = "recipe",
    name = "gcs-empty-cryo-cell",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "item", name = "steel-plate", amount = 2 },
      { type = "item", name = "lithium-plate", amount = 1 },
    },
    results = { { type = "item", name = "gcs-empty-cryo-cell", amount = 1 } },
  },
  {
    type = "recipe",
    name = "gcs-cryo-cell",
    categories = { "cryogenics" },
    enabled = false,
    energy_required = 5,
    ingredients = {
      { type = "item", name = "gcs-empty-cryo-cell", amount = 1 },
      { type = "item", name = "ice", amount = 2 },
      { type = "fluid", name = "fluoroketone-cold", amount = 10 },
    },
    results = {
      { type = "item", name = "gcs-cryo-cell", amount = 1, always_fresh = true },
      { type = "fluid", name = "fluoroketone-hot", amount = 10 },
    },
    main_product = "gcs-cryo-cell",
    allow_productivity = false,
    surface_conditions = { { property = "pressure", min = 100, max = 600 } }, -- Aquilo
  },
})
