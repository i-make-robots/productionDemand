-- ==============================================================
--  productionDemand  --  Factorio 2.0 clean numeric dashboard
-- ==============================================================


local crafting_entity_types
local current_sort = {column = "difference", descending = true}

-----------------------------------------------------------------
--  Persistent data setup  (Factorio 2.0)
-----------------------------------------------------------------
script.on_init(function()
  storage.open_players = {}
end)

script.on_configuration_changed(function()
  storage.open_players = storage.open_players or {}
end)

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
--  Fill the table with live data
-----------------------------------------------------------------
local function populate_table(tbl, data, filter)
  tbl.clear()
  local f = string.lower(filter or "")

  for _, v in ipairs(data) do
    if f == "" or string.find(string.lower(v.name), f, 1, true) then
      -- Sprite + tooltip
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

                   tbl.add{type = "sprite", sprite = sprite, tooltip = tooltip}
      local prod = tbl.add{type = "label", caption = string.format("%.2f", v.production)}
      local dema = tbl.add{type = "label", caption = string.format("%.2f", v.demand)}
      local diff = tbl.add{type = "label", caption = string.format("%.2f", v.difference) }

      prod.style.horizontally_stretchable = true
      dema.style.horizontally_stretchable = true
      diff.style.horizontally_stretchable = true

      diff.style.font_color = (v.difference >= 0)
        and {r=0.2, g=1.0, b=0.2}
        or  {r=1.0, g=0.2, b=0.2}
    end
  end
end


-----------------------------------------------------------------
--  Build table inside scroll container
-----------------------------------------------------------------
local function build_table(parent)
  local scroll = parent.add{
    type = "scroll-pane",
    horizontal_scroll_policy = "never",
    vertical_scroll_policy = "auto"
  }
  scroll.style.maximal_height = 600
  scroll.style.minimal_width = 500

  local tbl = scroll.add{
    type = "table",
    name = "productionDemand_table",
    style = "productionDemand_table",  -- use our custom data-stage style
    column_count = 4
  }

  return tbl
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
--  Gather real production + consumption data (items + fluids)
-----------------------------------------------------------------
local function collect_data(force, surface)
  local item_stats  = force.get_item_production_statistics(surface)
  local fluid_stats = force.get_fluid_production_statistics(surface)
  local window = defines.flow_precision_index.one_minute

  local production, demand = {}, {}

  -- === ITEMS ===
  for name, _ in pairs(item_stats.input_counts) do
    local prod = item_stats.get_flow_count{
      name = name,
      precision_index = window,
      category = "input"
    }
    local cons = item_stats.get_flow_count{
      name = name,
      precision_index = window,
      category = "output"
    }
    if prod and prod > 0 then production[name] = prod end
    if cons and cons > 0 then demand[name] = cons end
  end

  -- === FLUIDS ===
  for name, _ in pairs(fluid_stats.input_counts) do
    local prod = fluid_stats.get_flow_count{
      name = name,
      precision_index = window,
      category = "input"
    }
    local cons = fluid_stats.get_flow_count{
      name = name,
      precision_index = window,
      category = "output"
    }
    if prod and prod > 0 then production[name] = prod end
    if cons and cons > 0 then demand[name] = cons end
  end

  -- === Combine ===
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
--  Build full GUI
-----------------------------------------------------------------
local function build_gui(player)
  if not (player and player.valid) then return end
  if player.gui.screen.productionDemand then player.gui.screen.productionDemand.destroy() end

  -- Make sure our persistent table exists even if on_init() hasn't fired yet
  storage.open_players = storage.open_players or {}
  storage.open_players[player.index] = true

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
  local tbl = build_table(frame)
  local data = collect_data(player.force, player.surface)
  sort_data(data)
  populate_table(tbl, data, "")
  player.opened = frame

  storage.open_players[player.index] = true
end

-----------------------------------------------------------------
--  Rebuild list (filter/sort)
-----------------------------------------------------------------
local function rebuild(player)
  local frame = player.gui.screen.productionDemand
  if not (frame and frame.valid) then return end

  local tbl = frame.children[#frame.children].children[1]

  local data = collect_data(player.force, player.surface)
  sort_data(data)

  local filter = ""
  for _, child in pairs(frame.children[1].children) do
    if child.name == "productionDemand_search" then
      filter = child.text or ""
    end
  end

  populate_table(tbl, data, filter)
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
    storage.open_players[player.index] = nil
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

-----------------------------------------------------------------
--  Periodic refresh (once per second)
-----------------------------------------------------------------
script.on_event(defines.events.on_tick, function(e)
  -- In case this runs before on_init (rare on first load)
  if not storage then return end
  if not storage.open_players then return end

  if (e.tick % 60) ~= 0 then return end   -- every 60 ticks = 1 s

  for index in pairs(storage.open_players) do
    local player = game.get_player(index)
    if player and player.valid then
      local frame = player.gui.screen.productionDemand
      if frame and frame.valid then
        -- Use your rebuild() to update live data
        rebuild(player)
      else
        -- GUI was closed manually or by another mod
        storage.open_players[index] = nil
      end
    else
      storage.open_players[index] = nil
    end
  end
end)
