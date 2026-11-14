-- Velocita AWD drift mode (by Lincoln)
-- When enabled (via the TCS / ESC drive-mode button), shifts the center diff heavily to the rear
-- and tightens the rear LSD so the car can hold slides. Restores the normal setup when disabled.
local M = {}
M.type = "auxiliary"

local enabled = false
local wasEnabled = false
local center, rear
local orig = {}
local params = {split = 0.88, rearLock = 0.45, rearPreload = 250}

local function restore()
  if center and orig.split then
    center.diffTorqueSplitA = orig.split
    center.diffTorqueSplitB = 1 - orig.split
  end
  if rear and orig.rearLock then
    rear.lsdLockCoef = orig.rearLock
    rear.lsdPreload = orig.rearPreload
  end
end

local function applyDrift()
  if center then
    center.diffTorqueSplitA = params.split          -- output 1 = rear axle
    center.diffTorqueSplitB = 1 - params.split
  end
  if rear and rear.lsdLockCoef then
    rear.lsdLockCoef = params.rearLock
    rear.lsdPreload = params.rearPreload
  end
end

local function findDevices()
  center = center or powertrain.getDevice("transfercase")
  rear = rear or powertrain.getDevice("differential_R")
  if center and not orig.split then orig.split = center.diffTorqueSplitA end
  if rear and not orig.rearLock then orig.rearLock = rear.lsdLockCoef; orig.rearPreload = rear.lsdPreload end
end

local function updateGFX(dt)
  if not center then findDevices() end
  if enabled then
    applyDrift()
  elseif wasEnabled then
    restore()
  end
  wasEnabled = enabled
  electrics.values.velocita_drift = enabled and 1 or 0
end

local function setParameters(p)
  if p.isEnabled ~= nil then enabled = p.isEnabled and true or false end
end

local function initSecondStage(jbeamData)
  findDevices()
  if not center then log("W", "velocitaDrift", "No center differential found; drift mode disabled") end
end

local function init(jbeamData)
  params.split = jbeamData.driftSplit or params.split
  params.rearLock = jbeamData.driftRearLock or params.rearLock
  params.rearPreload = jbeamData.driftRearPreload or params.rearPreload
  enabled = false; wasEnabled = false
end

local function reset()
  wasEnabled = enabled
end

M.init = init
M.initSecondStage = initSecondStage
M.reset = reset
M.updateGFX = updateGFX
M.setParameters = setParameters
return M
