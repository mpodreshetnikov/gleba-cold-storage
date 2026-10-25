-- 1000 cold chambers (12 full slots) + 300 cryo vaults (48 full slots), all cooled.
local CHAMBER, VAULT = ...
script.on_event(defines.events.on_tick, function()
  if storage.done then return end
  storage.done = true

  local s = game.surfaces.nauvis
  for _, t in pairs({ "gcs-cold-chamber", "gcs-cryo-vault" }) do game.forces.player.technologies[t == "gcs-cold-chamber" and "gcs-cold-chamber" or "gcs-cryo-vault"].researched = true end
  local tiles = {}
  for x = -150, 150 do for y = -150, 150 do tiles[#tiles+1] = {name="lab-dark-1", position={x,y}} end end
  s.set_tiles(tiles)
  for _, e in pairs(s.find_entities_filtered{area={{-150,-150},{150,150}}}) do if e.type ~= "character" then e.destroy() end end
  local function fill(e) local inv = e.get_inventory(defines.inventory.chest); for i=1,#inv do inv[i].set_stack{name="yumako", count=50} end end
  local n = 0
  for gx = 0, 39 do for gy = 0, 24 do
    local x, y = -140 + gx * 6, -140 + gy * 4
    local name = (n % 10 < 3 and n < 1000 and false) and "x" or "gcs-cold-chamber"
    local e = s.create_entity{name="gcs-cold-chamber", position={x, y}, force="player", raise_built=true}
    fill(e)
    local p = s.create_entity{name="infinity-pipe", position={x-0.5, y-1.5}, force="player"}
    p.set_infinity_pipe_filter{name="water", percentage=1, mode="at-least"}
    n = n + 1
  end end
  for gx = 0, 19 do for gy = 0, 14 do
    local x, y = -140.5 + gx * 7, 20.5 + gy * 6
    local e = s.create_entity{name="gcs-cryo-vault", position={x, y}, force="player", raise_built=true}
    fill(e)
    local p = s.create_entity{name="infinity-pipe", position={x, y-2}, force="player"}
    p.set_infinity_pipe_filter{name="water", percentage=1, mode="at-least"}
  end end
  -- power everything
  for x = -144, 150, 18 do for y = -144, 150, 18 do
    s.create_entity{name="substation", position={x, y}, force="player"}
  end end
  local eei = s.create_entity{name="electric-energy-interface", position={-148,-148}, force="player"}
  eei.power_production = 1e10; eei.electric_buffer_size = 1e10
  log("BENCH setup tracked " .. remote.call("gleba-cold-storage", "count"))
end)
