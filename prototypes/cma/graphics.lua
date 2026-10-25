-- Layers for the CMA Graphics sprites bundled in graphics/entity/cma (CC0,
-- by trentmkelly; see CREDITS.md). A trimmed copy of that pack's
-- lib/machine_graphics.lua, pointed at this mod's own copies.

local ENT = "__gleba-cold-storage__/graphics/entity/cma/"

--- @param name string machine family, e.g. "process-reactor"
--- @param tag string sprite set, e.g. "mk2-north"
--- @param opts table? {animation_speed, emission (file suffix for a recoloured glow)}
return function(name, tag, opts)
  opts = opts or {}
  local S = require("prototypes.cma." .. name)[tag]
  local prefix = ENT .. name .. "-" .. tag .. "-hr-"
  local speed = opts.animation_speed or 0.5
  local n = S.main.frame_count

  local function sheet(file, m, extra)
    local l = { filename = prefix .. file, width = m.width, height = m.height, shift = m.shift, scale = 0.5,
                frame_count = m.frame_count or 1, line_length = m.line_length or 1, animation_speed = speed }
    for k, v in pairs(extra or {}) do l[k] = v end
    return l
  end

  local G = {}
  G.base = sheet("animation.png", S.main)
  G.emission = sheet("emission" .. (opts.emission or "") .. ".png", S.emission, { draw_as_glow = true, blend_mode = "additive" })
  G.shadow = { filename = prefix .. "shadow.png", width = S.shadow.width, height = S.shadow.height, shift = S.shadow.shift,
               scale = 0.5, draw_as_shadow = true, frame_count = 1, repeat_count = n, animation_speed = speed }
  G.idle = { filename = prefix .. "idle.png", width = S.idle.width, height = S.idle.height, shift = S.idle.shift, scale = 0.5 }
  if S.tint then G.tint = sheet("tint.png", S.tint) end
  if S.frozen then
    G.frozen = { filename = prefix .. "frozen.png", width = S.frozen.width, height = S.frozen.height, shift = S.frozen.shift, scale = 0.5 }
  end
  return G
end
