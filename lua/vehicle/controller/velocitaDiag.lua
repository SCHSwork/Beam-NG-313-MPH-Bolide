-- Velocita diagnostics (temporary): logs twice per second above ~20 mph. Search beamng.log for "velocitaDiag".
local M = {}
M.type = "auxiliary"
local timer = 0
local fmt = string.format
local function wheelInfo()
  local parts = {}
  for _, wd in pairs(wheels.wheels or {}) do
    parts[#parts + 1] = fmt("%s[av=%.1f prop=%.0f brk=%.0f down=%.0f slip=%.3f]", tostring(wd.name), wd.angularVelocity or 0,
      wd.propulsionTorque or 0, wd.brakingTorque or 0, wd.downForce or 0, wd.lastSlip or 0)
  end
  table.sort(parts)
  return table.concat(parts, " ")
end
local function updateGFX(dt)
  timer = timer + dt
  if timer < 0.5 then return end
  timer = 0
  local ev = electrics.values
  local speed = math.abs(ev.airspeed or ev.wheelspeed or 0)
  if speed < 9 then return end
  local roll, pitch, yaw = obj:getRollPitchYawAngularVelocity()
  log("I", "velocitaDiag", fmt("mph=%.0f thr=%.2f brk=%.2f steerIn=%.3f steerOut=%.3f wing=%.2f latG=%.3f yawAV=%.4f esc=%s tcs=%s | %s",
    speed * 2.237, ev.throttle or 0, ev.brake or 0, ev.steering_input or 0, ev.velocita_steer or 0, ev.velocita_wing or 0,
    ((sensors and sensors.gx2) or 0) / 9.81, yaw or 0, tostring(ev.esc or ev.escActive or ""), tostring(ev.tcs or ev.tcsActive or ""), wheelInfo()))
end
local function init() timer = 0 end
M.init = init
M.updateGFX = updateGFX
return M
