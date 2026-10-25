-- Gleba Cold Storage: runtime half.
--
-- Factorio has no per-container spoil rate, so cold storage works by moving
-- each stack's spoil_tick. Every tracked container has a temperature that
-- drifts towards a target: its cooling target while it is cooled, the
-- planet's ambient temperature while it is not. Spoilage speed follows the
-- temperature (twice as slow per 12.6 degrees below 20 C), and a visit pushes
-- spoil ticks by dt * (1 - 1/k) for the average slowdown k over the interval.
-- Above 20 C k drops below 1 and items spoil faster than in the open.
--
-- Visits are spread evenly over the period, so the per-tick cost stays flat
-- however many containers exist, and nothing ever scans a whole surface
-- outside init and migration.

local CHAMBER = { cooler = "gcs-cold-chamber-cooler", cap = "gcs-chamber-slowdown", inventory = defines.inventory.chest,
                  target = 0, reach = 25, cool_tau = 60, warm_tau = 300 }
local WAGON = { wagon = true, cap = "gcs-wagon-slowdown", inventory = defines.inventory.cargo_wagon,
                target = -10, reach = 35, cool_tau = 60, warm_tau = 300 }

--- Every vault variant has its own cooler, which carries its coloured glow.
local function vault(name)
  return { cooler = name .. "-cooler", cap = "gcs-vault-slowdown", inventory = defines.inventory.chest,
           target = -35, reach = 60, cool_tau = 120, warm_tau = 600, cells = true }
end

local KINDS = {
  ["gcs-cold-chamber"] = CHAMBER,
  ["gcs-refrigerated-wagon"] = WAGON,
}
for _, suffix in pairs({ "", "-passive-provider", "-requester", "-buffer" }) do
  KINDS["gcs-cryo-vault" .. suffix] = vault("gcs-cryo-vault" .. suffix)
end

local COOLERS = {}
for _, kind in pairs(KINDS) do
  if kind.cooler then COOLERS[kind.cooler] = true end
end

-- Ambient temperature per planet, degrees C. Platforms are climate controlled.
local AMBIENT = { nauvis = 15, gleba = 25, vulcanus = 45, fulgora = 10, aquilo = -40 }
local DEFAULT_AMBIENT = 20
local REFERENCE_TEMPERATURE = 20 -- spoilage runs at its normal speed here
local DOUBLING_DEGREES = 12.6    -- every this many degrees colder halves spoilage speed
local MIN_SLOWDOWN = 0.5

local CELL = "gcs-cryo-cell"
local EMPTY_CELL = "gcs-empty-cryo-cell"

-- Joules per tick a refrigerated wagon needs from its grid (150 kW).
local WAGON_JOULES_PER_TICK = 150000 / 60

local TRACKED_NAMES, COOLER_NAMES = {}, {}
for name in pairs(KINDS) do TRACKED_NAMES[#TRACKED_NAMES + 1] = name end
for name in pairs(COOLERS) do COOLER_NAMES[#COOLER_NAMES + 1] = name end

local floor, ceil, exp = math.floor, math.ceil, math.exp
local status = defines.entity_status
local diode = defines.entity_status_diode

---- Settings ----

local config = {}

local function read_settings()
  local global = settings.global
  config.cap = {}
  for name, kind in pairs(KINDS) do
    config.cap[name] = global[kind.cap].value
  end
  config.cell_ticks = global["gcs-cell-minutes"].value * 3600
  config.period = global["gcs-update-period"].value
  config.preserve_science = settings.startup["gcs-preserve-science"].value
end

-- Item names any technology consumes; built lazily since prototypes are
-- not available while settings are first read in on_load.
local science

--- Items cold storage leaves alone: science (unless allowed) and cryo cells,
--- which keep thawing wherever they are stored.
local function is_skipped(name)
  if name == CELL then return true end
  if config.preserve_science then return false end
  if not science then
    science = {}
    for _, technology in pairs(prototypes.technology) do
      for _, ingredient in pairs(technology.research_unit_ingredients or {}) do
        science[ingredient.name] = true
      end
    end
  end
  return science[name]
end

---- Spoilage ----

--- Move every perishable stack's spoil tick by `delta` ticks.
-- Positive delta never makes an item fresher than brand new; negative delta
-- spoils items whose new spoil tick is already in the past.
--
-- This is the hot loop, so it keeps API calls per stack to a minimum: the
-- "fresher than new" ceiling is derived from spoil_percent instead of looking
-- up the item's full shelf life by name and quality.
local function shift_inventory(inventory, delta, tick)
  if not inventory or inventory.is_empty() then return end
  -- Only pay for a per-stack name check when a skipped item is present.
  local check_names = false
  for _, item in pairs(inventory.get_contents()) do
    if is_skipped(item.name) then
      check_names = true
      break
    end
  end
  for i = 1, #inventory do
    local stack = inventory[i]
    if stack.valid_for_read then
      -- 0 for items that never spoil (and for brand-new ones, which have
      -- nothing to recover and lose at most one visit of penalty).
      local percent = stack.spoil_percent
      if percent > 0 and not (check_names and is_skipped(stack.name)) then
        local spoil_tick = stack.spoil_tick
        if delta > 0 then
          -- Ticks of shelf life used so far: remaining * p / (1 - p).
          local shift = delta
          if percent < 1 then
            local used = (spoil_tick - tick) * percent / (1 - percent)
            if used < shift then shift = floor(used) end
          end
          if shift > 0 then stack.spoil_tick = spoil_tick + shift end
        elseif spoil_tick + delta <= tick then
          stack.spoil()
        else
          stack.spoil_tick = spoil_tick + delta
        end
      end
    end
  end
end

---- Temperature ----

local ambient_cache = {}

local function ambient_of(surface)
  local t = ambient_cache[surface.index]
  if not t then
    local planet = surface.planet
    t = planet and AMBIENT[planet.name] or DEFAULT_AMBIENT
    ambient_cache[surface.index] = t
  end
  return t
end

local function slowdown_at(temperature, cap)
  local k = 2 ^ ((REFERENCE_TEMPERATURE - temperature) / DOUBLING_DEGREES)
  if k > cap then return cap end
  if k < MIN_SLOWDOWN then return MIN_SLOWDOWN end
  return k
end

---- Cooling sources ----

--- Is the hidden cooler running (power, and water for a chamber)?
local function cooler_running(cooler)
  if not (cooler and cooler.valid) or cooler.disabled_by_script then return false end
  local s = cooler.status
  return s == status.working or s == status.low_power
end

local function cooler_reason(cooler)
  if not (cooler and cooler.valid) then return "no-power" end
  local s = cooler.status
  if s == status.no_power then return "no-power" end
  if s == status.full_output then return "steam-blocked" end
  return "no-water"
end

--- Load one cryo cell from the vault's own inventory into its charge. A cell
--- gives cell_ticks of cooling scaled by how much of it has not thawed yet;
--- the empty cell goes back into the vault (or onto the ground if full).
local function load_cell(entry, inventory)
  local stack = inventory.find_item_stack(CELL)
  if not stack then return false end
  entry.charge = (entry.charge or 0) + floor(config.cell_ticks * (1 - stack.spoil_percent))
  if stack.count > 1 then stack.count = stack.count - 1 else stack.clear() end
  if inventory.insert({ name = EMPTY_CELL, count = 1 }) == 0 then
    local entity = entry.entity
    entity.surface.spill_item_stack({ position = entity.position, stack = { name = EMPTY_CELL, count = 1 } })
  end
  return true
end

--- A wagon is cold if its grid generates enough power, or its batteries can
--- pay for the elapsed time (they are drained by that much).
local function wagon_powered(entity, dt)
  local grid = entity.grid
  if not grid then return false end
  local needed = WAGON_JOULES_PER_TICK * dt
  if grid.get_generator_energy() >= WAGON_JOULES_PER_TICK then return true end
  if grid.available_in_batteries < needed then return false end
  for _, equipment in pairs(grid.equipment) do
    if equipment.type == "battery-equipment" then
      local take = math.min(equipment.energy, needed)
      equipment.energy = equipment.energy - take
      needed = needed - take
      if needed <= 0 then break end
    end
  end
  return true
end

local function format_factor(k)
  if k >= 10 then return string.format("%.0f", k) end
  return string.format("%.1f", k)
end

local function format_temperature(t)
  local rounded = floor(t + 0.5)
  if rounded == 0 then return "0" end
  return string.format("%+d", rounded)
end

local function format_time(ticks)
  local seconds = floor(ticks / 60)
  return string.format("%d:%02d", floor(seconds / 60), seconds % 60)
end

local function rate_text(k)
  if k >= 1.05 then return { "gcs-status.slower", format_factor(k) } end
  if k <= 0.95 then return { "gcs-status.faster", format_factor(1 / k) } end
  return { "gcs-status.normal" }
end

local function show_state(entry, mode, reason, k)
  local label = { "", { "gcs-status.temperature", format_temperature(entry.temperature) }, " · " }
  local light
  if mode == "ambient" then
    label[#label + 1] = { "gcs-status.ambient" }
    label[#label + 1] = " · "
    light = diode.green
  elseif mode == "cooling" then
    light = diode.green
  else
    label[#label + 1] = { "gcs-status.warming", { "gcs-status." .. reason } }
    label[#label + 1] = " · "
    light = k < 1 and diode.red or diode.yellow
  end
  label[#label + 1] = rate_text(k)
  if mode == "cooling" and entry.charge then
    label[#label + 1] = " · "
    label[#label + 1] = { "gcs-status.cell", format_time(entry.charge) }
  end
  entry.entity.custom_status = { diode = light, label = label }
end

---- Registry ----
--
-- storage.entries is a dense array walked round-robin; storage.by_unit maps a
-- unit_number to its entry; entry.index is its slot in the array.

local function create_cooler(entity, name)
  local cooler = entity.surface.create_entity({
    name = name,
    position = entity.position,
    force = entity.force,
    create_build_effect_smoke = false,
  })
  if cooler then
    cooler.destructible = false
    cooler.operable = false
  end
  return cooler
end

local function register(entity)
  local kind = KINDS[entity.name]
  if not kind or storage.by_unit[entity.unit_number] then return end
  local entry = {
    entity = entity,
    unit = entity.unit_number,
    name = entity.name,
    last = game.tick,
    temperature = ambient_of(entity.surface),
  }
  if kind.cooler then
    entry.cooler = create_cooler(entity, kind.cooler)
    -- Cell-cooled vaults start idle until their first visit loads a cell.
    if kind.cells and entry.cooler then entry.cooler.disabled_by_script = true end
  end
  entry.size = #entity.get_inventory(kind.inventory)
  storage.slots = storage.slots + entry.size
  local entries = storage.entries
  entries[#entries + 1] = entry
  entry.index = #entries
  storage.by_unit[entry.unit] = entry
  script.register_on_object_destroyed(entity)
end

local function unregister(entry)
  if entry.cooler and entry.cooler.valid then entry.cooler.destroy() end
  local entries = storage.entries
  local last = entries[#entries]
  entries[entry.index] = last
  last.index = entry.index
  entries[#entries] = nil
  storage.by_unit[entry.unit] = nil
  storage.slots = storage.slots - entry.size
end

---- Visits ----

--- Process one entry. Returns false if the entry was removed, in which case
--- its slot now holds a different entry that still needs a visit.
local function visit(entry, tick)
  local entity = entry.entity
  if not entity.valid then
    unregister(entry)
    return false
  end
  local dt = tick - entry.last
  entry.last = tick
  if dt <= 0 then return true end

  local kind = KINDS[entry.name]
  local inventory = entity.get_inventory(kind.inventory)
  local ambient = ambient_of(entity.surface)
  local free_cold = ambient <= kind.target

  -- Was it actively cooled over the interval that just ended?
  local cooled, reason = false, nil
  local cooler = entry.cooler
  if kind.wagon then
    if not free_cold then
      cooled = wagon_powered(entity, dt)
      reason = "no-grid-power"
    end
  else
    if not (cooler and cooler.valid) then
      cooler = create_cooler(entity, kind.cooler)
      entry.cooler = cooler
    elseif cooler.surface == entity.surface then
      -- Follow the container if a mod teleported it.
      local p, c = entity.position, cooler.position
      if p.x ~= c.x or p.y ~= c.y then cooler.teleport(p) end
    end
    if not free_cold then
      cooled = cooler_running(cooler)
      if cooled and kind.cells then
        entry.charge = math.max(0, (entry.charge or 0) - dt)
      end
      if not cooled then
        reason = (kind.cells and cooler and cooler.valid and cooler.disabled_by_script) and "no-cells" or cooler_reason(cooler)
      end
    end
  end

  -- Temperature drifts towards the cooling target or towards ambient.
  local old_t = entry.temperature or ambient
  local target, tau = ambient, kind.warm_tau
  if cooled then
    target = math.max(kind.target, ambient - kind.reach)
    tau = kind.cool_tau
  end
  local new_t = target + (old_t - target) * exp(-dt / (tau * 60))
  entry.temperature = new_t

  local cap = config.cap[entry.name]
  local k = (slowdown_at(old_t, cap) + slowdown_at(new_t, cap)) / 2
  show_state(entry, free_cold and "ambient" or (cooled and "cooling" or "warming"), reason, k)

  -- Decide whether the cooler runs during the next interval.
  if cooler and cooler.valid then
    local run = not free_cold
    if run and kind.cells and (entry.charge or 0) <= 0 then
      run = load_cell(entry, inventory)
    end
    cooler.disabled_by_script = not run
  end

  -- Spoil ticks are integers; the fractional part of each shift is carried
  -- to the next visit so small periods do not round the effect away.
  local exact = dt * (1 - 1 / k) + (entry.carry or 0)
  local delta = exact >= 0 and floor(exact) or -floor(-exact)
  entry.carry = exact - delta
  if delta ~= 0 then
    shift_inventory(inventory, delta, tick)
  end
  return true
end

-- Hard cap on inventory slots walked per tick. A normal base never reaches
-- it; a huge one stretches the effective period instead of eating UPS.
local MAX_SLOTS_PER_TICK = 60

local function on_tick(event)
  local entries = storage.entries
  if #entries == 0 then return end
  local tick = event.tick
  local period = config.period
  local budget = ceil(storage.slots / period)
  if budget > MAX_SLOTS_PER_TICK then budget = MAX_SLOTS_PER_TICK end
  local cursor = storage.cursor
  local visited = 0
  while budget > 0 and #entries > 0 and visited < #entries do
    if cursor > #entries then cursor = 1 end
    local entry = entries[cursor]
    -- Stop at the first container that is not due yet instead of lapping
    -- the array every tick.
    if tick - entry.last < period and entry.entity.valid then break end
    budget = budget - entry.size
    visited = visited + 1
    if visit(entry, tick) then cursor = cursor + 1 end
  end
  storage.cursor = cursor
end

---- Events ----

local function on_built(event)
  local entity = event.entity or event.destination
  if not (entity and entity.valid) then return end
  if COOLERS[entity.name] then
    -- A cloned cooler: the cloned container gets a fresh one of its own.
    entity.destroy()
    return
  end
  register(entity)
end

local function on_object_destroyed(event)
  if event.type ~= defines.target_type.entity or not event.useful_id then return end
  local entry = storage.by_unit[event.useful_id]
  if entry then unregister(entry) end
end

--- Rebuild the registry from the world: register missed containers, drop
--- dead entries and destroy coolers nobody owns.
local function rescan()
  storage.entries = storage.entries or {}
  storage.by_unit = storage.by_unit or {}
  storage.cursor = storage.cursor or 1
  storage.slots = storage.slots or 0

  for i = #storage.entries, 1, -1 do
    local entry = storage.entries[i]
    if not entry.entity.valid then
      unregister(entry)
    elseif entry.cooler and entry.cooler.valid and entry.cooler.name ~= KINDS[entry.name].cooler then
      entry.cooler.destroy() -- the next visit builds the right one
    end
  end

  local owned = {}
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered({ name = TRACKED_NAMES })) do
      register(entity)
    end
  end
  for _, entry in pairs(storage.entries) do
    if entry.cooler and entry.cooler.valid then owned[entry.cooler.unit_number] = true end
  end
  for _, surface in pairs(game.surfaces) do
    for _, cooler in pairs(surface.find_entities_filtered({ name = COOLER_NAMES })) do
      if not owned[cooler.unit_number] then cooler.destroy() end
    end
  end
end

local filter = {}
for _, name in pairs(TRACKED_NAMES) do filter[#filter + 1] = { filter = "name", name = name } end
local clone_filter = {}
for _, f in pairs(filter) do clone_filter[#clone_filter + 1] = f end
for _, name in pairs(COOLER_NAMES) do clone_filter[#clone_filter + 1] = { filter = "name", name = name } end

script.on_event(defines.events.on_built_entity, on_built, filter)
script.on_event(defines.events.on_robot_built_entity, on_built, filter)
script.on_event(defines.events.on_space_platform_built_entity, on_built, filter)
script.on_event(defines.events.script_raised_built, on_built, filter)
script.on_event(defines.events.script_raised_revive, on_built, filter)
script.on_event(defines.events.on_entity_cloned, on_built, clone_filter)
script.on_event(defines.events.on_object_destroyed, on_object_destroyed)
script.on_event(defines.events.on_tick, on_tick)

script.on_event(defines.events.on_runtime_mod_setting_changed, read_settings)

script.on_init(function()
  read_settings()
  rescan()
end)

script.on_configuration_changed(function()
  read_settings()
  rescan()
end)

script.on_load(read_settings)

remote.add_interface("gleba-cold-storage", {
  --- Number of tracked containers, for tests and debugging.
  count = function() return #storage.entries end,
  --- Temperature and cell charge of a tracked container, for tests and debugging.
  inspect = function(unit_number)
    local entry = storage.by_unit[unit_number]
    return entry and { temperature = entry.temperature, charge = entry.charge }
  end,
})
