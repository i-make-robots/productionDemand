-- ==============================================================
--  productionDemand  --  Factorio 2.0 clean numeric dashboard
-- ==============================================================

local crafting_entity_types
local current_sort = {column = "difference", descending = true}

-----------------------------------------------------------------
--  Cache craftable entity types
-----------------------------------------------------------------
local function get_crafting_entity_types()
  if crafting_entity_types then return crafting_entity_types end
  crafting_entity_types = {}
  for _, proto in pairs(prototypes.entity) do
    if proto.crafting_categories then
      crafting_entity_types[proto.type] = true
    end
  end
  return crafting_entity_types
end

-----------------------------------------------------------------
--  Demand calculation (items/sec)
-----------------------------------------------------------------
local function calculate_demand(force)
  local demand = {}
  local craft_types = get_crafting_entity_types()

  for _, surface in pairs(game.surfaces) do
    for _, e in pairs(surface.find_entities_filtered{force = force}) do
      if e.valid and craft_types[e.type] then
        local recipe = e.get_recipe()
        if recipe then
          local speed = e.crafting_speed or e.prototype.crafting_speed or 1
          local crafts_per_second = speed / (recipe.energy or 1)
          for _, ing in pairs(recipe.ingredients) do
            demand[ing.name] = (demand[ing.name] or 0) + ing.amount * crafts_per_second
          end
        end
      end
    end
  end
  return demand
end

-----------------------------------------------------------------
--  Helpers
-----------------------------------------------------------------
local function get_sprite_for(name)
  if prototypes.item[name] then
    return "item/" .. name
  elseif prototypes.fluid[name] then
    return "fluid/" .. name
  else
    return "utility/questionmark"
  end
end


-----------------------------------------------------------------
--  Gather combined production/demand data (items + fluids)
-----------------------------------------------------------------
local function collect_data(force, surface)
  local demand = calculate_demand(force)

  local item_stats  = force.get_item_production_statistics(surface)
  local fluid_stats = force.get_fluid_production_statistics(surface)
  local window = defines.flow_precision_index.one_minute

  local production = {}

  -- Items
  for name, _ in pairs(item_stats.input_counts) do
    local rate = item_stats.get_flow_count{
      name = name,
      precision_index = window,
      category = "input"
    }
    if rate and rate > 0 then
      production[name] = rate
    end
  end

  -- Fluids
  for name, _ in pairs(fluid_stats.input_counts) do
    local rate = fluid_stats.get_flow_count{
      name = name,
      precision_index = window,
      category = "input"
    }
    if rate and rate > 0 then
      production[name] = rate
    end
  end

  -----------------------------------------------------------------
  -- Combine production and demand
  -----------------------------------------------------------------
  local combined, seen = {}, {}
  for name, d in pairs(demand) do
    combined[name] = {name = name, demand = d, production = production[name] or 0}
    seen[name] = true
  end
  for name, p in pairs(production) do
    if not seen[name] then
      combined[name] = {name = name, demand = 0, production = p}
    end
  end

  local result = {}
  for name, v in pairs(combined) do
    v.difference = v.production - v.demand
    table.insert(result, v)
  end
  return result
end


-----------------------------------------------------------------
--  Sorting
-----------------------------------------------------------------
local function sort_data(data)
  local col, desc = current_sort.column, current_sort.descending
  table.sort(data, function(a, b)
    local va = tonumber(a[col]) or 0
    local vb = tonumber(b[col]) or 0
    if desc then
      return va > vb
    else
      return va < vb
    end
  end)
end

-----------------------------------------------------------------
--  GUI pieces
-----------------------------------------------------------------
local function build_header(parent)
  local header = parent.add{type="flow", direction="horizontal"}
  header.style.horizontal_spacing = 8
  header.style.vertical_align = "center"

  local icon_header = header.add{
    type="label",
    caption="",
    tooltip={"productionDemand.icon_header"}
  }
  icon_header.style.width = 36

  local headers = {
    {name="sort_production", caption={"productionDemand.production_header"}},
    {name="sort_demand", caption={"productionDemand.demand_header"}},
    {name="sort_difference", caption={"productionDemand.difference_header"}}
  }
  for _,h in ipairs(headers) do
    local btn = header.add{
      type="button",
      name=h.name,
      caption=h.caption,
      tooltip={"productionDemand.sort_tooltip"}
    }
    btn.style.horizontally_stretchable = true
    btn.style.horizontal_align = "center"
  end
end

local function build_scroll(parent)
  local scroll = parent.add{
    type="scroll-pane",
    horizontal_scroll_policy="never",
    vertical_scroll_policy="auto"
  }
  scroll.style.maximal_height = 600
  scroll.style.minimal_width = 500
  scroll.style.padding = 2
  return scroll
end
-----------------------------------------------------------------
--  Fill the list
-----------------------------------------------------------------
local function populate_scroll(scroll, data, filter)
  scroll.clear()
  local f = string.lower(filter or "")
  for _, v in ipairs(data) do
    if f == "" or string.find(string.lower(v.name), f, 1, true) then
      local row = scroll.add{type="flow", direction="horizontal"}
      row.style.vertical_align = "center"
      row.style.horizontal_spacing = 8

      -- Tooltip with localised name of item.
      local sprite, tooltip
      if prototypes.item[v.name] then
        sprite = "item/" .. v.name
        tooltip = prototypes.item[v.name].localised_name
      elseif prototypes.fluid[v.name] then
        sprite = "fluid/" .. v.name
        tooltip = prototypes.fluid[v.name].localised_name
      else
        sprite = "utility/questionmark"
        tooltip = v.name
      end

      local icon = row.add{type="sprite", sprite=sprite, tooltip=tooltip}
      icon.style.width = 36

      local prod = row.add{type="label", caption=string.format("%.2f", v.production)}
      local dem  = row.add{type="label", caption=string.format("%.2f", v.demand)}
      local diff = row.add{type="label", caption=string.format("%.2f", v.difference)}

      prod.style.horizontally_stretchable = true
      dem.style.horizontally_stretchable = true
      diff.style.horizontally_stretchable = true

      prod.style.horizontal_align = "right"
      dem.style.horizontal_align = "right"
      diff.style.horizontal_align = "right"
      diff.style.font_color = (v.difference >= 0)
        and {r=0.2, g=1.0, b=0.2}
        or  {r=1.0, g=0.2, b=0.2}
    end
  end
end

-----------------------------------------------------------------
--  Build full GUI
-----------------------------------------------------------------
local function build_gui(player)
  if not (player and player.valid) then return end
  if player.gui.screen.productionDemand then player.gui.screen.productionDemand.destroy() end

  local frame = player.gui.screen.add{
    type="frame",
    name="productionDemand",
    direction="vertical"
  }
  frame.auto_center = true

  -- Title bar
  local titlebar = frame.add{type="flow", direction="horizontal"}
  titlebar.style.vertical_align = "center"
  titlebar.style.horizontal_spacing = 8

  titlebar.add{
    type="label",
    caption={"productionDemand.title"},
    style="frame_title",
    ignored_by_interaction=true
  }

  local filler = titlebar.add{type="empty-widget"}
  filler.style.horizontally_stretchable = true

  titlebar.add{
    type="textfield",
    name="productionDemand_search",
    tooltip={"productionDemand.search_tooltip"}
  }

  titlebar.add{
    type="sprite-button",
    name="productionDemand_close",
    style="frame_action_button",
    sprite="utility/close",
    tooltip={"productionDemand.close"}
  }

  -- Content
  build_header(frame)
  local scroll = build_scroll(frame)

  local data = collect_data(player.force, player.surface)
  sort_data(data)
  populate_scroll(scroll, data, "")
  player.opened = frame
end

-----------------------------------------------------------------
--  Rebuild list (filter/sort)
-----------------------------------------------------------------
local function rebuild(player)
  local frame = player.gui.screen.productionDemand
  if not (frame and frame.valid) then return end
  local scroll = frame.children[#frame.children]
  local data = collect_data(player.force, player.surface)
  sort_data(data)

  local filter = ""
  for _, child in pairs(frame.children[1].children) do
    if child.name == "productionDemand_search" then
      filter = child.text or ""
    end
  end

  populate_scroll(scroll, data, filter)
end

-----------------------------------------------------------------
--  Event handlers
-----------------------------------------------------------------
local function open_gui(player) build_gui(player) end

script.on_event(defines.events.on_lua_shortcut, function(e)
  if e.prototype_name == "productionDemand-toggle" then
    open_gui(game.get_player(e.player_index))
  end
end)

script.on_event("productionDemand-toggle", function(e)
  open_gui(game.get_player(e.player_index))
end)

script.on_event(defines.events.on_gui_click, function(e)
  if not (e.element and e.element.valid) then return end
  local name, player = e.element.name, game.get_player(e.player_index)
  if name == "productionDemand_close" then
    local frame = e.element.parent.parent
    if frame and frame.valid then frame.destroy() end
  elseif string.find(name, "^sort_") then
    local col = string.match(name, "^sort_(.+)")
    if col and col ~= "" then
      if current_sort.column == col then
        current_sort.descending = not current_sort.descending
      else
        current_sort.column, current_sort.descending = col, true
      end
      rebuild(player)
    end
  end
end)

script.on_event(defines.events.on_gui_text_changed, function(e)
  if e.element.name == "productionDemand_search" then
    rebuild(game.get_player(e.player_index))
  end
end)
