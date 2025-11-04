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
    key_sequence = "CONTROL + F",
    consuming = "none"
  }
})
