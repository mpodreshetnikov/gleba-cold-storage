-- In-game integration tests for gleba-cold-storage. Run headless with
-- --benchmark; results are logged as "GCS-TEST PASS|FAIL <name>: details".
--
-- Expected slowdowns come from the mod's temperature model run over the same
-- interval (see sim.py next to the test notes): containers start at the
-- planet's temperature and cool down over a couple of minutes, so a
-- five-minute run averages less than the cap.

local DURATION = 18000 -- five minutes of game time for the rate checks
local results = {}

local function report(name, ok, details)
  results[#results + 1] = { name = name, ok = ok }
  log(string.format("GCS-TEST %s %s: %s", ok and "PASS" or "FAIL", name, details or ""))
end

local function approx(name, value, low, high, what)
  report(name, value ~= nil and value >= low and value <= high,
    string.format("%s = %s (expected %.2f..%.2f)", what or "value", value and string.format("%.3f", value) or "nil", low, high))
end

local nauvis
local function prepare(surface, area)
  for _, e in pairs(surface.find_entities_filtered({ area = area })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
  local tiles = {}
  for x = area[1][1], area[2][1] - 1 do
    for y = area[1][2], area[2][2] - 1 do
      tiles[#tiles + 1] = { name = "lab-dark-1", position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
end

local function create(name, position, extra, surface)
  local spec = { name = name, position = position, force = "player", raise_built = true }
  for k, v in pairs(extra or {}) do spec[k] = v end
  local e = (surface or nauvis).create_entity(spec)
  assert(e, "could not create " .. name .. " at " .. serpent.line(position))
  return e
end

local function infinity_pipe(position, fluid, surface)
  local pipe = create("infinity-pipe", position, nil, surface)
  pipe.set_infinity_pipe_filter(fluid)
  return pipe
end

local WATER = { name = "water", percentage = 1, mode = "at-least" }
local STEAM_SINK = { name = "steam", percentage = 0, mode = "exactly", temperature = 100 }

local function power(position, surface)
  local eei = create("electric-energy-interface", position, nil, surface)
  eei.power_production = 1e9
  eei.electric_buffer_size = 1e9
  create("substation", { position[1] + 2, position[2] }, nil, surface)
end

--- A 2x2 chamber centred at (x, y) with water on its north inlet and, if
--- `sink`, an infinite steam sink on its south outlet.
local function chamber(x, y, sink, surface)
  local c = create("gcs-cold-chamber", { x, y }, nil, surface)
  infinity_pipe({ x - 0.5, y - 1.5 }, WATER, surface)
  if sink then infinity_pipe({ x + 0.5, y + 1.5 }, STEAM_SINK, surface) end
  return c
end

--- Ticks of shelf life an item stack has used up.
local function used(stack)
  return stack.prototype.get_spoil_ticks(stack.quality) - (stack.spoil_tick - game.tick)
end

local function find_stack(entity, name, inventory)
  local inv = entity.get_inventory(inventory or defines.inventory.chest)
  for i = 1, #inv do
    if inv[i].valid_for_read and inv[i].name == (name or "yumako") then return inv[i] end
  end
end

local function count(entity, name)
  return entity.get_inventory(defines.inventory.chest).get_item_count(name)
end

local function inspect(entity)
  return remote.call("gleba-cold-storage", "inspect", entity.unit_number) or {}
end

--- Flatten a custom_status label to a string of locale keys and values.
local function label_text(entity)
  local s = entity.custom_status
  if not s then return "" end
  local out = {}
  local function walk(l)
    if type(l) == "table" then
      if type(l[1]) == "string" and l[1] ~= "" then out[#out + 1] = l[1] end
      for i = 2, #l do walk(l[i]) end
    elseif l ~= nil then
      out[#out + 1] = tostring(l)
    end
  end
  walk(s.label)
  return table.concat(out, " ")
end

local function has_label(entity, key)
  return label_text(entity):find(key, 1, true) ~= nil
end

local T = {}
local planet_surfaces = {}

local function planet_surface(name)
  local planet = game.planets[name]
  local surface = planet.surface or planet.create_surface()
  surface.request_to_generate_chunks({ 0, 0 }, 2)
  surface.force_generate_chunk_requests()
  prepare(surface, { { -20, -20 }, { 20, 20 } })
  planet_surfaces[name] = surface
  return surface
end

local function setup()
  nauvis = game.surfaces.nauvis
  prepare(nauvis, { { -60, -60 }, { 60, 60 } })
  for _, name in pairs({ "gcs-cold-chamber", "gcs-cryo-vault", "gcs-cryo-encapsulation" }) do
    game.forces.player.technologies[name].researched = true
  end

  -- Powered area: one substation at (2,-2) covers -7..11 x -11..7.
  power({ 0, -2 })
  T.control = create("iron-chest", { -8.5, -8.5 })
  T.control.insert({ name = "yumako", count = 50 })
  T.control.insert({ name = "agricultural-science-pack", count = 10 })

  T.chamber = chamber(-6, -6, true)
  T.chamber.insert({ name = "yumako", count = 50 })
  T.chamber.insert({ name = "agricultural-science-pack", count = 10 })

  T.blocked = chamber(-2, -6, false) -- water in, steam has nowhere to go
  T.blocked.insert({ name = "yumako", count = 50 })

  T.dry = create("gcs-cold-chamber", { 2, -6 }) -- powered, no water
  T.dry.insert({ name = "yumako", count = 50 })

  T.vault = create("gcs-cryo-vault", { -5.5, 1.5 })
  T.vault.insert({ name = "yumako", count = 50 })
  T.vault.insert({ name = "gcs-cryo-cell", count = 3 })

  T.requester = create("gcs-cryo-vault-requester", { -1.5, 1.5 })
  T.requester.insert({ name = "yumako", count = 50 })
  T.requester.insert({ name = "gcs-cryo-cell", count = 2 })

  T.no_cells = create("gcs-cryo-vault", { 2.5, 1.5 })
  T.no_cells.insert({ name = "yumako", count = 50 })

  T.thawed_cell = create("gcs-cryo-vault", { 6.5, 1.5 })
  T.thawed_cell.insert({ name = "yumako", count = 50 })
  T.thawed_cell.insert({ name = "gcs-cryo-cell", count = 1 })
  find_stack(T.thawed_cell, "gcs-cryo-cell").spoil_percent = 0.75

  T.doomed = chamber(-6, 6, false)
  T.legendary = create("gcs-cold-chamber", { 6, 7 }, { quality = "legendary" })

  -- Unpowered chamber with water, far from the substation.
  T.unpowered = chamber(-40, -40, true)
  T.unpowered.insert({ name = "yumako", count = 50 })

  -- Encapsulators, powered by their own substation.
  power({ 30, 0 })
  T.freezer = create("gcs-cryo-encapsulator", { 26.5, -4.5 })
  T.freezer.set_recipe("gcs-freeze-yumako")
  T.freezer.insert({ name = "ice", count = 2 })
  local input = T.freezer.get_inventory(defines.inventory.crafter_input)
  input.insert({ name = "yumako", count = 10 })
  for i = 1, #input do
    if input[i].valid_for_read and input[i].name == "yumako" then input[i].spoil_percent = 0.4 end
  end

  T.thawer = create("gcs-cryo-encapsulator", { 33.5, -4.5 })
  T.thawer.set_recipe("gcs-thaw-yumako")
  T.thawer.get_inventory(defines.inventory.crafter_input).insert({ name = "gcs-frozen-yumako", count = 1 })
  T.thawer.get_inventory(defines.inventory.crafter_input)[1].spoil_percent = 0.3

  T.ice_maker = create("gcs-cryo-encapsulator", { 26.5, 4.5 })
  T.ice_maker.set_recipe("gcs-freeze-water")
  infinity_pipe({ 26.5, 2.5 }, WATER)

  -- Wagons on a straight track.
  for y = -51, -21, 2 do
    create("straight-rail", { 41, y }, { direction = defines.direction.north })
  end
  T.wagon = create("gcs-refrigerated-wagon", { 41, -36 }, { direction = defines.direction.north })
  T.wagon.grid.put({ name = "fission-reactor-equipment" })
  T.wagon.get_inventory(defines.inventory.cargo_wagon).insert({ name = "yumako", count = 50 })
  T.wagon_cold_off = create("gcs-refrigerated-wagon", { 41, -27 }, { direction = defines.direction.north })
  T.wagon_cold_off.get_inventory(defines.inventory.cargo_wagon).insert({ name = "yumako", count = 50 })

  T.wagon_battery = create("gcs-refrigerated-wagon", { 41, -45 }, { direction = defines.direction.north })
  local battery = T.wagon_battery.grid.put({ name = "battery-mk2-equipment" })
  battery.energy = battery.max_energy
  T.battery_start = battery.energy
  T.wagon_battery.get_inventory(defines.inventory.cargo_wagon).insert({ name = "yumako", count = 50 })

  -- Aquilo: the cold is free, nothing is plugged in.
  local aquilo = planet_surface("aquilo")
  T.aq_chamber = create("gcs-cold-chamber", { -3, 0 }, nil, aquilo)
  T.aq_chamber.insert({ name = "yumako", count = 50 })
  T.aq_vault = create("gcs-cryo-vault", { 3.5, 0.5 }, nil, aquilo)
  T.aq_vault.insert({ name = "yumako", count = 50 })
  T.aq_vault.insert({ name = "gcs-cryo-cell", count = 1 })

  -- Gleba: an idle chamber is just a warm box.
  local gleba = planet_surface("gleba")
  T.gleba_chamber = create("gcs-cold-chamber", { 0, 0 }, nil, gleba)
  T.gleba_chamber.insert({ name = "yumako", count = 50 })

  T.start = game.tick
  log("GCS-TEST setup done at tick " .. game.tick .. ", tracked " .. remote.call("gleba-cold-storage", "count"))
end

local function check_static()
  approx("legendary chamber has bigger inventory", #T.legendary.get_inventory(defines.inventory.chest), 13, 100, "slots")
  report("eggs are not freezable", prototypes.recipe["gcs-freeze-pentapod-egg"] == nil
    and prototypes.recipe["gcs-freeze-biter-egg"] == nil, "")
  report("science is not freezable by default", prototypes.recipe["gcs-freeze-agricultural-science-pack"] == nil, "")
  report("cryo cells are not freezable", prototypes.recipe["gcs-freeze-gcs-cryo-cell"] == nil, "")
  local frozen = prototypes.item["gcs-frozen-yumako"]
  approx("frozen yumako keeps 10x longer", frozen.get_spoil_ticks() / prototypes.item["yumako"].get_spoil_ticks(), 10, 10, "ratio")
  local recycling = prototypes.recipe["gcs-frozen-yumako-recycling"]
  local ok = true
  if recycling then
    for _, p in pairs(recycling.products) do
      if p.name ~= "gcs-frozen-yumako" then ok = false end
    end
  end
  report("recycling a frozen block gives no fresh items", ok, recycling and serpent.line(recycling.products) or "no recycling recipe")
  local enc = prototypes.entity["gcs-cryo-encapsulator"]
  report("encapsulator takes no modules", (enc.module_inventory_size or 0) == 0, "")
  local n = 0
  for _, effect in pairs(prototypes.technology["gcs-cryo-encapsulation"].effects) do
    if effect.type == "unlock-recipe" then n = n + 1 end
  end
  report("encapsulation unlocks per-item recipes", n > 10, n .. " recipes")
  local own = nauvis.find_entities_filtered({ name = "gcs-cryo-vault-requester-cooler", position = T.requester.position })
  report("logistic vault gets its own coloured cooler", #own == 1, #own .. " coolers")
  local cell_recipe = prototypes.recipe["gcs-cryo-cell"]
  report("cryo cells charge only on Aquilo", cell_recipe.surface_conditions ~= nil
    and cell_recipe.surface_conditions[1].property == "pressure", serpent.line(cell_recipe.surface_conditions))
  report("ambient starts at planet temperature", math.abs((inspect(T.aq_vault).temperature or 0) + 40) < 0.01
    and math.abs((inspect(T.gleba_chamber).temperature or 0) - 25) < 0.01,
    serpent.line({ inspect(T.aq_vault), inspect(T.gleba_chamber) }))
end

local function remove_doomed()
  T.doomed.destroy({ raise_destroy = true })
end

local function check_removed()
  local coolers = nauvis.find_entities_filtered({ name = "gcs-cold-chamber-cooler", position = { -6, 6 } })
  report("cooler removed with its chamber", #coolers == 0, #coolers .. " coolers left")
end

local function clone()
  nauvis.clone_area({
    source_area = { { 1, -7 }, { 3, -5 } },
    destination_area = { { 1, 13 }, { 3, 15 } },
    clone_entities = true, clone_tiles = false,
  })
end

local function check_cloned()
  local area = { { 1, 13 }, { 3, 15 } }
  local chambers = nauvis.find_entities_filtered({ name = "gcs-cold-chamber", area = area })
  local coolers = nauvis.find_entities_filtered({ name = "gcs-cold-chamber-cooler", area = area })
  report("cloned chamber gets exactly one cooler", #chambers == 1 and #coolers == 1, #chambers .. " chambers, " .. #coolers .. " coolers")
end

local function check_minute()
  -- A minute in: the blocked chamber filled its steam output and gave up.
  report("blocked steam stops the chamber", has_label(T.blocked, "gcs-status.steam-blocked"), label_text(T.blocked))
  report("plumbed chamber keeps cooling", not has_label(T.chamber, "gcs-status.warming"), label_text(T.chamber))
  report("dry chamber reports no water", has_label(T.dry, "gcs-status.no-water"), label_text(T.dry))
  report("vault without cells reports it", has_label(T.no_cells, "gcs-status.no-cells"), label_text(T.no_cells))
  -- A cell three quarters thawed gives a quarter of its cooling (45 s).
  report("a thawed-out cell runs out early", count(T.thawed_cell, "gcs-cryo-cell") == 0
    and count(T.thawed_cell, "gcs-empty-cryo-cell") == 1 and has_label(T.thawed_cell, "gcs-status.no-cells"),
    count(T.thawed_cell, "gcs-cryo-cell") .. " cells, " .. count(T.thawed_cell, "gcs-empty-cryo-cell") .. " empty, " .. label_text(T.thawed_cell))
  report("cooled vault shows remaining cell time", has_label(T.vault, "gcs-status.cell"), label_text(T.vault))
  T.minute_used = used(find_stack(T.control))
end

local function check_rates()
  local base = used(find_stack(T.control))
  log(string.format("GCS-TEST info control used %d ticks over %d", base, game.tick - T.start))
  local function slowdown(entity, inventory) return base / used(find_stack(entity, "yumako", inventory)) end

  -- Model predictions for five minutes from planet temperature (sim.py).
  approx("cold chamber: ~2.5x over the first 5 min", slowdown(T.chamber), 2.3, 2.7, "slowdown")
  approx("cold chamber reaches 0 C", inspect(T.chamber).temperature, -0.5, 1, "temperature")
  approx("blocked chamber warms back up", inspect(T.blocked).temperature, 9, 15, "temperature")
  approx("dry chamber on Nauvis (+15 C) is a cool box", slowdown(T.dry), 1.25, 1.38, "slowdown")
  approx("unpowered chamber on Nauvis is a cool box", slowdown(T.unpowered), 1.25, 1.38, "slowdown")
  approx("cryo vault: ~5.6x over the first 5 min", slowdown(T.vault), 5.0, 6.2, "slowdown")
  approx("cryo vault heads for -35 C", inspect(T.vault).temperature, -32.5, -29, "temperature")
  approx("requester vault cools like a vault", slowdown(T.requester), 5.0, 6.2, "slowdown")
  report("vault burned two cells in five minutes", count(T.vault, "gcs-cryo-cell") == 1 and count(T.vault, "gcs-empty-cryo-cell") == 2,
    count(T.vault, "gcs-cryo-cell") .. " cells, " .. count(T.vault, "gcs-empty-cryo-cell") .. " empty")
  -- Cell 2 went in ~3 min after start, 5% thawed, so 171 s of charge; ~120 s are used.
  approx("cell charge counts down", (inspect(T.vault).charge or 0) / 60, 40, 60, "seconds left")
  approx("Aquilo chamber is cold for free", slowdown(T.aq_chamber), 2.9, 3.1, "slowdown")
  approx("Aquilo vault is cold for free", slowdown(T.aq_vault), 19, 21, "slowdown")
  report("Aquilo vault keeps its cell", count(T.aq_vault, "gcs-cryo-cell") == 1, count(T.aq_vault, "gcs-cryo-cell") .. " cells")
  report("Aquilo storage shows the outdoor cold", has_label(T.aq_vault, "gcs-status.ambient"), label_text(T.aq_vault))
  approx("idle chamber on Gleba (+25 C) spoils faster", 1 / slowdown(T.gleba_chamber), 1.25, 1.38, "speed-up")
  report("warm Gleba chamber shows red", T.gleba_chamber.custom_status and T.gleba_chamber.custom_status.diode == defines.entity_status_diode.red,
    serpent.line(T.gleba_chamber.custom_status and T.gleba_chamber.custom_status.diode))

  local science = find_stack(T.chamber, "agricultural-science-pack")
  local science_control = find_stack(T.control, "agricultural-science-pack")
  approx("science pack in chamber is not preserved", used(science) / used(science_control), 0.95, 1.05, "ratio")

  approx("powered wagon: ~3.7x over the first 5 min", slowdown(T.wagon, defines.inventory.cargo_wagon), 3.3, 4.0, "slowdown")
  approx("wagon without grid power is a cool box", slowdown(T.wagon_cold_off, defines.inventory.cargo_wagon), 1.25, 1.38, "slowdown")
  approx("battery-powered wagon cools", slowdown(T.wagon_battery, defines.inventory.cargo_wagon), 3.3, 4.0, "slowdown")
  local drained = (T.battery_start - T.wagon_battery.grid.available_in_batteries) / ((game.tick - T.start) / 60)
  approx("wagon cooling drains ~150 kW from batteries", drained / 1000, 140, 160, "kW")

  local life = prototypes.item["yumako"].get_spoil_ticks()
  report("cooling never makes items fresher than new", find_stack(T.aq_vault).spoil_tick - game.tick <= life, "")

  -- Encapsulation.
  local out = T.freezer.get_inventory(defines.inventory.crafter_output)[1]
  report("encapsulator freezes yumako", out.valid_for_read and out.name == "gcs-frozen-yumako", out.valid_for_read and out.name or "empty")
  if out.valid_for_read then
    approx("frozen block keeps freshness", out.spoil_percent, 0.38, 0.41, "spoil percent")
  end
  local thawed = T.thawer.get_inventory(defines.inventory.crafter_output)[1]
  report("encapsulator thaws a block into 10 yumako", thawed.valid_for_read and thawed.name == "yumako" and thawed.count == 10,
    thawed.valid_for_read and (thawed.name .. " x" .. thawed.count) or "empty")
  if thawed.valid_for_read then
    -- 0.3 at thaw time, then it ages normally in the output slot until now.
    approx("thawed yumako keeps freshness", thawed.spoil_percent, 0.3 + (DURATION - 400) / 216000, 0.3 + DURATION / 216000 + 0.001, "spoil percent")
  end
  local ice = T.ice_maker.get_inventory(defines.inventory.crafter_output)[1]
  report("encapsulator makes ice from water", ice.valid_for_read and ice.name == "ice", ice.valid_for_read and (ice.name .. " x" .. ice.count) or "empty")

  local passed, failed = 0, 0
  for _, r in pairs(results) do if r.ok then passed = passed + 1 else failed = failed + 1 end end
  log(string.format("GCS-TEST SUMMARY %d passed, %d failed", passed, failed))
end

local SCHEDULE = {
  { at = 120, run = check_static },
  { at = 200, run = remove_doomed },
  { at = 300, run = check_removed },
  { at = 300, run = clone },
  { at = 400, run = check_cloned },
  { at = 3600, run = check_minute },
  { at = DURATION, run = check_rates },
}

script.on_event(defines.events.on_tick, function(event)
  if not storage.started then
    storage.started = true
    local ok, err = pcall(setup)
    if not ok then report("setup", false, err) end
    return
  end
  if not T.start then return end
  for _, step in pairs(SCHEDULE) do
    if not step.done and event.tick - T.start >= step.at then
      step.done = true
      local ok, err = pcall(step.run)
      if not ok then report("step at +" .. step.at, false, err) end
    end
  end
end)
