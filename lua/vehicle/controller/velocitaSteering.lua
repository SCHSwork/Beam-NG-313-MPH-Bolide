-- Velocita speed-sensitive steering (by Lincoln)
-- Full steering lock at low speed (hairpins, parking), progressively calmer as speed rises.
-- Feeds the scaled value to the steering rack hydros via electrics.values.velocita_steer.

local M = {}
M.type = "auxiliary"

local min, max, abs = math.min, math.max, math.abs

-- {speed in m/s, steering scale}
local curve = {
  {0,  1.00},
  {8,  1.00},  -- ~30 km/h / 18 mph: full lock for hairpins
  {18, 0.82},  -- ~65 km/h / 40 mph
  {30, 0.68},  -- ~110 km/h / 67 mph
  {45, 0.58},  -- ~160 km/h / 100 mph
  {70, 0.51},  -- ~250 km/h / 155 mph
  {90, 0.48},  -- ~325 km/h / 200 mph and up
}

local function scaleFor(speed)
  if speed <= curve[1][1] then return curve[1][2] end
  for i = 2, #curve do
    local a, b = curve[i - 1], curve[i]
    if speed <= b[1] then
      local t = (speed - a[1]) / (b[1] - a[1])
      return a[2] + (b[2] - a[2]) * t
    end
  end
  return curve[#curve][2]
end

-- steering rate limit (full-lock units per second): quick at low speed, gentle at speed,
-- so a fast correction tap can't whip the rear around
local function rateFor(speed)
  local t = min(max((speed - 8) / 37, 0), 1)   -- 8 m/s .. 45 m/s
  return 5.0 + (2.3 - 5.0) * t
end

local current = 0
local sensitivity = 1

local function updateGFX(dt)
  local ev = electrics.values
  local speed = abs(ev.wheelspeed or ev.airspeed or 0)
  local scale = 1 - (1 - scaleFor(speed)) * sensitivity
  local target = (ev.steering_input or 0) * scale
  local rate = rateFor(speed)
  -- returning toward center is allowed to be quicker than turning in
  if abs(target) < abs(current) and target * current >= 0 then rate = rate * 1.6 end
  local step = rate * dt
  current = current + min(max(target - current, -step), step)
  ev.velocita_steer = current
  ev.velocita_steer_scale = scale
end

local function reset(jbeamData)
  current = 0
  electrics.values.velocita_steer = 0
end

local function init(jbeamData)
  current = 0
  sensitivity = (jbeamData and jbeamData.speedSensitivity) or 1
  electrics.values.velocita_steer = 0
end

M.init = init
M.reset = reset
M.updateGFX = updateGFX

return M
