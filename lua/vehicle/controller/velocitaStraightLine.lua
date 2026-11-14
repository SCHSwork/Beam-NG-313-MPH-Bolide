-- Velocita high-speed straight-line stability (by Lincoln)
-- At very high speed the left side of the car carries more load, so the front limited-slip diff
-- sends it more torque and the car pulls right. Above ~125 mph this blends the front diff toward
-- fully open (equal torque left/right). Below that it behaves as a normal LSD for traction.
local M = {}
M.type = "auxiliary"

local front
local orig = {}
local startSpeed, fullSpeed = 56, 67   -- m/s (~125 mph -> ~150 mph)

local function findDevice()
  front = powertrain.getDevice("differential_F")
  if front and orig.preload == nil then
    orig.preload = front.lsdPreload
    orig.lock = front.lsdLockCoef
    orig.revLock = front.lsdRevLockCoef
  end
end

local function updateGFX(dt)
  if not front then findDevice() end
  if not front or orig.preload == nil then return end
  local speed = math.abs(electrics.values.airspeed or electrics.values.wheelspeed or 0)
  local k = math.min(math.max((speed - startSpeed) / (fullSpeed - startSpeed), 0), 1)  -- 0 = normal LSD, 1 = open
  front.lsdPreload = orig.preload * (1 - k)
  front.lsdLockCoef = (orig.lock or 0) * (1 - k)
  if orig.revLock then front.lsdRevLockCoef = orig.revLock * (1 - k) end
  electrics.values.velocita_frontdiff_open = k
end

local function init() front = nil; orig = {} end
local function reset() if front and orig.preload then front.lsdPreload = orig.preload; front.lsdLockCoef = orig.lock end end

M.init = init
M.reset = reset
M.updateGFX = updateGFX
return M
