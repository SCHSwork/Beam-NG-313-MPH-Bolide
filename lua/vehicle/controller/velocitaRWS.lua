-- Velocita rear-wheel steering (by Lincoln)
-- Low/medium speed: rear wheels steer opposite to the fronts (tighter turns, more rotation).
-- High speed: fades out, then a touch of same-direction steer for stability.
-- Drives the rear toe-link hydros through electrics velocita_rws_l / velocita_rws_r.
local M = {}
M.type = "auxiliary"

local min, max, abs = math.min, math.max, math.abs

local range = 0.05        -- hydro travel (length ratio) at input +-1; must match the jbeam limits
local maxSteer = 0.039    -- length ratio at full rear steer (~3 degrees)
local toe = 0.992         -- static rear toe (length ratio), kept as the hydro centre
local fullUntil, zeroAt, inPhaseAt, inPhase = 18, 42, 65, -0.15
local direction = 1
local current = 0

local function gain(speed)
  local g
  if speed <= fullUntil then g = 1
  elseif speed <= zeroAt then g = 1 - (speed - fullUntil) / (zeroAt - fullUntil)
  else g = inPhase * min((speed - zeroAt) / (inPhaseAt - zeroAt), 1) end
  -- nothing while parked: tyre scrub loads are highest at a standstill
  return g * min(max((speed - 1) / 3, 0), 1)
end

local function updateGFX(dt)
  local ev = electrics.values
  local speed = abs(ev.wheelspeed or ev.airspeed or 0)
  local target = (ev.steering_input or 0) * gain(speed) * direction
  local step = 3 * dt
  current = current + min(max(target - current, -step), step)
  local base = (toe - 1) / range
  local steer = current * maxSteer / range
  ev.velocita_rws_l = min(max(base + steer, -1), 1)
  ev.velocita_rws_r = min(max(base - steer, -1), 1)
  ev.velocita_rws = current
end

local function reset()
  current = 0
end

local function init(jbeamData)
  current = 0
  if type(jbeamData.toe) == "number" then toe = jbeamData.toe end
  maxSteer = jbeamData.maxSteer or maxSteer
  fullUntil = jbeamData.fullUntil or fullUntil
  zeroAt = jbeamData.zeroAt or zeroAt
  direction = jbeamData.direction or 1
  local base = (toe - 1) / range
  electrics.values.velocita_rws_l = base
  electrics.values.velocita_rws_r = base
end

M.init = init
M.reset = reset
M.updateGFX = updateGFX
return M
