-- Velocita diagnostics (temporary): logs one line per second above ~150 mph so we can find
-- what makes the car pull right at very high speed. Search beamng.log for "velocitaDiag".
local M = {}
M.type = "auxiliary"

local timer = 0
local fmt = string.format

local function wheelInfo()
  local parts = {}
  for _, wd in pairs(wheels.wheels or {}) do
    parts[#parts + 1] = fmt("%s[av=%.1f prop=%.0f brk=%.0f down=%.0f]",
      tostring(wd.name), wd.angularVelocity or 0, wd.propulsionTorque or 0, wd.brakingTorque or 0, wd.downForce or 0)
  end
  table.sort(parts)
  return table.concat(parts, " ")
end

local function updateGFX(dt)
  timer = timer + dt
  if timer < 1 then return end
  timer = 0
  local ev = electrics.values
  local speed = math.abs(ev.airspeed or ev.wheelspeed or 0)
  if speed < 67 then return end   -- ~150 mph
  local roll, pitch, yaw = obj:getRollPitchYawAngularVelocity()
  local center = powertrain.getDevice("transfercase")
  local rear = powertrain.getDevice("differential_R")
  log("I", "velocitaDiag", fmt(
    "mph=%.0f thr=%.2f steerIn=%.3f steerOut=%.3f wing=%.2f latG=%.3f yawAV=%.4f roll=%.3f split=%s rearSplitA=%s | %s",
    speed * 2.237, ev.throttle or 0, ev.steering_input or 0, ev.velocita_steer or 0, ev.velocita_wing or 0,
    ((sensors and sensors.gx2) or 0) / 9.81, yaw or 0, roll or 0,
    center and fmt("%.2f", center.diffTorqueSplitA) or "n/a", rear and fmt("%.2f", rear.diffTorqueSplitA) or "n/a",
    wheelInfo()))
end

local function init() timer = 0 end

M.init = init
M.updateGFX = updateGFX
return M
