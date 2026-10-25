-- Frozen variants are generated last so items added by other mods are covered too.
require("prototypes.frozen-items")

-- The wagon grid only takes power: generators, solar panels and batteries.
for _, kind in pairs({ "battery-equipment", "generator-equipment", "solar-panel-equipment" }) do
  for _, equipment in pairs(data.raw[kind] or {}) do
    table.insert(equipment.categories, "gcs-wagon-power")
  end
end
