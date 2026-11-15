-- Velocita active rear wing (by Lincoln)
-- Drives the wing actuators through electrics.values.velocita_wing:
--   -1 = flat ~2deg (low drag)   0 = normal 17.5deg   0.42 = cornering ~23deg   1 = air brake ~31deg
local M = {}
M.type = "auxiliary"

local abs, min, max = math.abs, math.min, math.max

local current = 0
local holdTimer = 0      -- keeps the wing up briefly after a corner / braking zone
local mode = "normal"
local forceLowDrag = false
local fastCorner = 0.42   -- cornering wing position at high speed (lower = less rear downforce = more front bite)

local function setMode(m) mode = m; electrics.values.velocita_wing_mode = m end

local function updateGFX(dt)
  local ev = electrics.values
  local speed = abs(ev.airspeed or ev.wheelspeed or 0)
  local throttle = ev.throttle or 0
  local brake = ev.brake or 0
  local steer = abs(ev.steering_input or 0)
  local latG = abs((sensors and sensors.gx2) or 0) / 9.81

  -- rear-heavy car: at high speed less rear wing in corners keeps the nose biting
  local cornerPos = 0.42 + (fastCorner - 0.42) * min(max((speed - 38) / 22, 0), 1)
  local target
  if speed < 12 then                                  -- under ~27 mph: just sit at the normal angle
    target = 0; setMode("normal"); holdTimer = 0
  elseif brake > 0.25 and speed > 22 then             -- hard braking at speed: air brake
    target = 1; setMode("airbrake"); holdTimer = 0.6
  elseif forceLowDrag then                           -- Top Speed mode: stay flat
    target = -1; setMode("lowdrag"); holdTimer = 0
  elseif latG > 0.3 or steer > 0.12 then              -- cornering: extra downforce
    target = cornerPos; setMode("corner"); holdTimer = max(holdTimer, 0.5)
  elseif holdTimer > 0 then                           -- settle a moment before flattening
    holdTimer = holdTimer - dt
    target = cornerPos
  elseif throttle > 0.6 and speed > 25 and latG < 0.15 then   -- flat out on a straight: low drag
    target = -1; setMode("lowdrag")
  else
    target = 0; setMode("normal")
  end

  -- going up is fast (grip when you need it), flattening is gentler
  local rate = (target > current) and 4.0 or 1.6
  local step = rate * dt
  current = current + min(max(target - current, -step), step)
  ev.velocita_wing = current
end

local function reset()
  current = 0; holdTimer = 0
  electrics.values.velocita_wing = 0
  setMode("normal")
end

local function init(jbeamData)
  reset()
  fastCorner = (jbeamData and jbeamData.fastCorner) or 0.42
end

local function setParameters(p)
  if p.forceLowDrag ~= nil then forceLowDrag = p.forceLowDrag and true or false end
end

M.init = init
M.setParameters = setParameters
M.reset = reset
M.updateGFX = updateGFX
return M
