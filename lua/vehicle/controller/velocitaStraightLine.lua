-- Velocita high-speed straight-line stability (by Lincoln)
-- At very high speed the left side of the car carries more load, so limited-slip diffs send the
-- left wheels more torque and the car pulls right. Above ~125 mph this blends the front and rear
-- LSDs toward fully open (equal torque left/right). Below that they behave as normal LSDs.
-- In drift mode the rear diff is left alone (the drift controller owns it).
local M = {}
M.type = "auxiliary"

local diffs = {}          -- name -> {dev=, preload=, lock=, revLock=}
local startSpeed, fullSpeed = 56, 67   -- m/s (~125 mph -> ~150 mph)

local function track(name)
  if diffs[name] then return end
  local d = powertrain.getDevice(name)
  if d and d.lsdPreload ~= nil then
    diffs[name] = {dev = d, preload = d.lsdPreload, lock = d.lsdLockCoef, revLock = d.lsdRevLockCoef}
  end
end

local function updateGFX(dt)
  track("differential_F"); track("differential_R")
  local speed = math.abs(electrics.values.airspeed or electrics.values.wheelspeed or 0)
  local k = math.min(math.max((speed - startSpeed) / (fullSpeed - startSpeed), 0), 1)  -- 0 = normal LSD, 1 = open
  local drifting = (electrics.values.velocita_drift or 0) > 0.5
  for name, s in pairs(diffs) do
    if not (drifting and name == "differential_R") then
      s.dev.lsdPreload = s.preload * (1 - k)
      s.dev.lsdLockCoef = (s.lock or 0) * (1 - k)
      if s.revLock then s.dev.lsdRevLockCoef = s.revLock * (1 - k) end
    end
  end
  electrics.values.velocita_diff_open = k
end

local function init(jbeamData)
  diffs = {}
  startSpeed = (jbeamData and jbeamData.startSpeed) or 56
  fullSpeed = (jbeamData and jbeamData.fullSpeed) or 67
end

M.init = init
M.updateGFX = updateGFX
return M
