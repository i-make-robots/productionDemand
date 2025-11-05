data:extend({
  {
    type = "shortcut",
    name = "productionDemand-toggle",
    action = "lua",
    toggleable = true,
    icon = "__base__/graphics/icons/iron-gear-wheel.png",
    small_icon = "__base__/graphics/icons/iron-gear-wheel.png",
    associated_control_input = "productionDemand-toggle"
  },
  {
    type = "custom-input",
    name = "productionDemand-toggle",
    consuming = "none"
  }
})

-- ==============================================================
--  GUI Styles for productionDemand
-- ==============================================================

local styles = data.raw["gui-style"]["default"]

styles["productionDemand_table"] = {
  type = "table_style",
  -- parent = "table", -- safest base table style in 2.0
  horizontal_spacing = 8,
  vertical_spacing = 2,
  draw_horizontal_lines = true,
  draw_vertical_lines = false,
  column_alignments = {
    {column = 1, alignment = "center"},
    {column = 2, alignment = "right"},
    {column = 3, alignment = "right"},
    {column = 4, alignment = "right"},
  }
}
