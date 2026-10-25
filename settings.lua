data:extend({
  -- startup
  {
    type = "bool-setting", name = "gcs-preserve-science", setting_type = "startup",
    default_value = false, order = "a",
  },
  {
    type = "int-setting", name = "gcs-frozen-multiplier", setting_type = "startup",
    default_value = 10, minimum_value = 2, maximum_value = 100, order = "b",
  },
  -- runtime
  {
    type = "double-setting", name = "gcs-chamber-slowdown", setting_type = "runtime-global",
    default_value = 3, minimum_value = 1, maximum_value = 100, order = "a",
  },
  {
    type = "double-setting", name = "gcs-vault-slowdown", setting_type = "runtime-global",
    default_value = 20, minimum_value = 1, maximum_value = 1000, order = "b",
  },
  {
    type = "double-setting", name = "gcs-wagon-slowdown", setting_type = "runtime-global",
    default_value = 5, minimum_value = 1, maximum_value = 100, order = "c",
  },
  {
    type = "double-setting", name = "gcs-cell-minutes", setting_type = "runtime-global",
    default_value = 3, minimum_value = 0.5, maximum_value = 60, order = "d",
  },
  {
    type = "int-setting", name = "gcs-update-period", setting_type = "runtime-global",
    default_value = 60, minimum_value = 10, maximum_value = 600, order = "e",
  },
})
