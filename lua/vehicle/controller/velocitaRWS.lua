-- Velocita rear-wheel steering (by Lincoln)
-- Low/medium speed: rear wheels steer opposite to the fronts (tighter turns, more rotation).
-- High speed: fades out, then a touch of same-direction steer for stability.
-- Drives the rear toe-link hydros through electrics velocita_rws_l / velocita_rws_r.
local M = {}
M.type = "auxiliary"

local min, max, abs = math.min, math.max, math.abs

local range = 0.08        -- hydro travel (length ratio) at input +-1; must match the jbeam limits
local maxSteer = 0.039    -- length ratio at full rear steer (~3 degrees)
local toe = 0.992         -- static rear toe (length ratio), kept as the hydro centre
local fullUntil, zeroAt, inPhaseAt, inPhase = 18, 58, 80, 0
local direction = 1
local current = 0
local lowBoost, boostUntil = 1.5, 12   -- extra rear steer (x maxSteer) below boostUntil m/s
local calm = 1            -- drops toward 0 while stability control is catching a slide

local function gain(speed)
  local g
  if speed <= boostUntil then g = lowBoost
  elseif speed <= fullUntil then g = lowBoost + (1 - lowBoost) * (speed - boostUntil) / (fullUntil - boostUntil)
  elseif speed <= zeroAt then g = 1 - (speed - fullUntil) / (zeroAt - fullUntil)
  else g = inPhase * min((speed - zeroAt) / (inPhaseAt - zeroAt), 1) end
  -- nothing while parked: tyre scrub loads are highest at a standstill
  return g * min(max((speed - 1) / 3, 0), 1)
end

local function updateGFX(dt)
  local ev = electrics.values
  local speed = abs(ev.wheelspeed or ev.airspeed or 0)
  -- if stability control is working (car is sliding), take the rear steer out fast, bring it back slowly
  local sliding = ev.escActive == true or ev.escActive == 1
  if sliding then calm = max(calm - 6 * dt, 0) else calm = min(calm + 1.2 * dt, 1) end
  local g = gain(speed)
  if g > 0 then g = g * calm end
  local target = (ev.steering_input or 0) * g * direction
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
  calm = 1
end

local function init(jbeamData)
  current = 0
  if type(jbeamData.toe) == "number" then toe = jbeamData.toe end
  maxSteer = jbeamData.maxSteer or maxSteer
  fullUntil = jbeamData.fullUntil or fullUntil
  zeroAt = jbeamData.zeroAt or zeroAt
  direction = jbeamData.direction or 1
  lowBoost = jbeamData.lowBoost or lowBoost
  calm = 1
  local base = (toe - 1) / range
  electrics.values.velocita_rws_l = base
  electrics.values.velocita_rws_r = base
end

M.init = init
M.reset = reset
M.updateGFX = updateGFX
return M
