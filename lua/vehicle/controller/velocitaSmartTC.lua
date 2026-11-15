-- Velocita smart traction control (by Lincoln)
-- Adjusts how much wheelspin the stock traction control allows, many times a second:
--   * steering-aware : more slip in a straight line, less mid-corner
--   * speed-aware    : looser at low speed for launches, tighter at high speed
--   * grip-aware     : looser on dirt/gravel/grass/sand, tighter on wet asphalt/ice
-- Also drives a flashing dash light (electric "velocita_tc") and an on-screen "TC" tag
-- whenever traction control is cutting power.
local M = {}
M.type = "auxiliary"

local abs, min, max, floor = math.abs, math.min, math.max, math.floor

local enabled = true
local baseSlip = 0.11
local p = {
  straightBoost = 1.25, cornerCut = 0.7,          -- steering multipliers
  lowSpeedBoost = 1.3, lowSpeedEnd = 30,          -- m/s; boost fades out by lowSpeedEnd
  highSpeedStart = 45, highSpeedEnd = 80, highSpeedCut = 0.75,
  showMessage = true,
}

-- ground model id -> slip multiplier (ids from lua/common/particles.json)
local surface = {
  [11] = 0.8,  -- wet asphalt
  [12] = 0.6,  -- slippery
  [14] = 1.5,  -- dusty dirt
  [15] = 1.6,  -- dirt
  [16] = 2.0,  -- sand
  [17] = 1.4,  -- sandy road
  [18] = 2.0,  -- mud
  [19] = 1.6,  -- gravel
  [20] = 1.4,  -- grass
  [21] = 0.6,  -- ice
  [22] = 0.85, -- snow
}
local surfaceNames = {[11] = "wet", [12] = "slippery", [14] = "dirt", [15] = "dirt", [16] = "sand", [17] = "sandy road",
  [18] = "mud", [19] = "gravel", [20] = "grass", [21] = "ice", [22] = "snow"}

local mtc
local sentSlip = -1
local sendTimer = 0
local surfaceMult, surfaceMultSmoothed = 1, 1
local lastSurfaceName
local flashTimer = 0
local msgTimer = 0
local surfaceMsgCooldown = 0

local function lerpClamp(x, x0, x1, y0, y1)
  if x1 == x0 then return y1 end
  local t = min(max((x - x0) / (x1 - x0), 0), 1)
  return y0 + (y1 - y0) * t
end

local function readSurface()
  local total, n, best = 0, 0, nil
  local ws = wheels and wheels.wheels
  if not ws then return 1, nil end
  for _, wd in pairs(ws) do
    if not wd.isBroken and (wd.downForceRaw or 0) > 0 then
      local id = wd.contactMaterialID1 or -1
      local m = surface[id] or 1
      total = total + m; n = n + 1
      if surface[id] and (not best or abs(m - 1) > abs((surface[best] or 1) - 1)) then best = id end
    end
  end
  if n == 0 then return surfaceMult, lastSurfaceName end
  return total / n, best and surfaceNames[best] or nil
end

local function updateGFX(dt)
  mtc = mtc or controller.getController("motorTorqueControl")
  local ev = electrics.values
  local speed = abs(ev.airspeed or ev.wheelspeed or 0)

  -- grip
  local sName
  surfaceMult, sName = readSurface()
  surfaceMultSmoothed = surfaceMultSmoothed + (surfaceMult - surfaceMultSmoothed) * min(dt * 3, 1)
  surfaceMsgCooldown = surfaceMsgCooldown - dt
  if sName ~= lastSurfaceName then
    if enabled and p.showMessage and sName and surfaceMsgCooldown <= 0 then
      surfaceMsgCooldown = 3
      guihooks.message("Smart TC: " .. sName .. " detected", 2, "velocitaSmartTCSurface")
    end
    lastSurfaceName = sName
  end

  if enabled and mtc and mtc.setParameters then
    local steer = abs(ev.steering_input or 0)
    local steerMult = lerpClamp(steer, 0.05, 0.35, p.straightBoost, p.cornerCut)
    -- stock TC under-reads slip with big steering inputs (0.3-0.5); cancel that out
    steerMult = steerMult * lerpClamp(steer, 0.3, 0.5, 1, 0.5)
    local speedMult = lerpClamp(speed, 0, p.lowSpeedEnd, p.lowSpeedBoost, 1)
    speedMult = speedMult * lerpClamp(speed, p.highSpeedStart, p.highSpeedEnd, 1, p.highSpeedCut)

    local slip = min(max(baseSlip * steerMult * speedMult * surfaceMultSmoothed, 0.04), 0.45)
    ev.velocita_tcSlip = slip

    sendTimer = sendTimer - dt
    if abs(slip - sentSlip) > 0.004 and sendTimer <= 0 then
      mtc.setParameters({["tractionControl.wheelGroupSettings.mainEngine.slipThreshold"] = slip})
      sentSlip = slip
      sendTimer = 0.05
    end
  end

  -- warning light + on-screen tag
  local acting = enabled and ev.tcsActive
  if acting then
    flashTimer = flashTimer + dt
    ev.velocita_tc = (floor(flashTimer * 8) % 2 == 0) and 1 or 0
    msgTimer = msgTimer - dt
    if p.showMessage and msgTimer <= 0 then
      guihooks.message("TC", 0.4, "velocitaSmartTC", "powertrain_esc")
      msgTimer = 0.25
    end
  else
    flashTimer = 0
    msgTimer = 0
    ev.velocita_tc = 0
  end
end

local function setParameters(params)
  if params.isEnabled ~= nil then
    enabled = params.isEnabled and true or false
  end
  if type(params.baseSlip) == "number" then
    baseSlip = params.baseSlip
  end
  sentSlip = -1
end

local function init(jbeamData)
  for k, v in pairs(p) do
    if jbeamData[k] ~= nil then p[k] = jbeamData[k] end
  end
  baseSlip = jbeamData.baseSlip or baseSlip
  enabled = true
  sentSlip = -1
  surfaceMultSmoothed = 1
  electrics.values.velocita_tc = 0
end

local function reset()
  sentSlip = -1
  surfaceMultSmoothed = 1
  flashTimer = 0
  electrics.values.velocita_tc = 0
end

M.init = init
M.reset = reset
M.updateGFX = updateGFX
M.setParameters = setParameters
return M
