-- =====================================================================
-- KYÔKA HUB • LINK 1 — CORE
-- Helpers, módulos do jogo, anti-cheat, config
-- =====================================================================

local ok, err = pcall(function()

if _G.__KyokaHub and _G.__KyokaHub.version then
    warn("[Kyôka] Core já carregado.")
    return
end

-- SERVIÇOS
local Services = {}
for _, nome in ipairs({
    "Players","ReplicatedStorage","RunService","UserInputService",
    "TweenService","HttpService","StarterGui","CoreGui",
    "VirtualInputManager","CollectionService","SoundService",
    "Lighting","GuiService","TeleportService"
}) do
    local ok2, s = pcall(function() return game:GetService(nome) end)
    if ok2 and s then Services[nome] = s end
end
Services.Workspace = workspace

local LP = Services.Players and Services.Players.LocalPlayer
if not LP then
    repeat task.wait() until Services.Players.LocalPlayer
    LP = Services.Players.LocalPlayer
end
Services.LocalPlayer = LP

local RS = Services.ReplicatedStorage

-- LOGGER
local Logger = { enable = true, prefix = "[Kyôka]" }
function Logger.log(...) if Logger.enable then pcall(print, Logger.prefix, ...) end end
function Logger.warn(...) if Logger.enable then pcall(warn, Logger.prefix, ...) end end
function Logger.err(...) pcall(warn, Logger.prefix, "ERRO:", ...) end

-- MÓDULOS DO JOGO
local MODULE_PATHS = {
    Utility            = {"CAM","Global","Utility"},
    SignalEvent        = {"Communication","ServerAndClient","Signals","SignalEvent"},
    SignalFunction     = {"Communication","ServerAndClient","Signals","SignalFunction"},
    gameSettings       = {"CAM","Global","gameSettings"},
    MinigameSettings   = {"CAM","Global","MinigameSettings"},
    LiveConfig         = {"CAM","Global","LiveConfig"},
    Items              = {"CAM","Global","Collectibles","Items"},
    Rarities           = {"CAM","Global","Rarities"},
    StatTypes          = {"CAM","Global","Types","StatTypes"},
    Quests             = {"CAM","Global","Subsets","Gameplay","Quests"},
    BossHunts          = {"CAM","Global","Subsets","Gameplay","Quests","BossHunts"},
    Clans              = {"CAM","Clans"},
    Regions            = {"Regions"},
    DayAndNightHandler = {"CAM","Global","DayAndNightHandler"},
    Skill_Controller   = {"CAM","Client","Controllers","Skill_Controller"},
    Skills_Provider    = {"CAM","Client","Controllers","Skills_Provider"},
    Platform_Handler   = {"CAM","Client","Controllers","Platform_Handler"},
    Skill_Info         = {"CAM","Global","PlayerProfile","Skill_Info"},
    SkillStats         = {"CAM","Global","SkillService","Stats"},
    manage_cd          = {"CAM","Global","Subsets","Gameplay","manage_cd"},
    Menum              = {"CAM","Global","Menum"},
}

local moduleCache = {}

local function resolvePath(path)
    if not RS then return nil end
    local node = RS
    for _, p in ipairs(path) do
        if not node then return nil end
        local ok3, child = pcall(function() return node:FindFirstChild(p) end)
        if not ok3 or not child then return nil end
        node = child
    end
    return node
end

local function loadModule(nome)
    if moduleCache[nome] ~= nil then return moduleCache[nome] end
    local path = MODULE_PATHS[nome]
    if not path then moduleCache[nome] = false return false end
    local node = resolvePath(path)
    if not node then
        warn("[Kyôka] Módulo não encontrado: " .. nome)
        moduleCache[nome] = false
        return false
    end
    local ok4, result = pcall(require, node)
    if not ok4 then
        warn("[Kyôka] Erro em " .. nome .. ": " .. tostring(result))
        moduleCache[nome] = false
        return false
    end
    moduleCache[nome] = result
    return result
end

local Game = setmetatable({}, {
    __index = function(t, k)
        local mod = loadModule(k)
        if mod == false then rawset(t, k, nil) return nil end
        rawset(t, k, mod)
        return mod
    end,
})

local PortalEvent = nil
pcall(function()
    local cam = RS:FindFirstChild("CAM")
    local global = cam and cam:FindFirstChild("Global")
    local portal = global and global:FindFirstChild("ServerClientPortal")
    PortalEvent = portal and portal:FindFirstChild("Event")
end)
Game.PortalEvent = PortalEvent

-- HELPERS
local H = {}

function H.char()
    local lp = Services.LocalPlayer
    if not lp then return nil, nil, nil end
    local c = lp.Character
    if not c then return nil, nil, nil end
    return c, c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
end

function H.pos() local _, hrp = H.char() return hrp and hrp.Position or nil end
function H.alive() local _, _, hum = H.char() return hum ~= nil and hum.Health > 0 end
function H.health() local _, _, hum = H.char() return hum and hum.Health or 0 end
function H.maxHealth() local _, _, hum = H.char() return hum and hum.MaxHealth or 100 end
function H.healthPct()
    local _, _, hum = H.char()
    if not hum or hum.MaxHealth <= 0 then return 100 end
    return hum.Health / hum.MaxHealth * 100
end
function H.humanoid() local _, _, hum = H.char() return hum end
function H.root() local _, hrp = H.char() return hrp end

function H.slot()
    local util = Game.Utility
    if not util or not util.GetData then return nil end
    local lp = Services.LocalPlayer
    if not lp then return nil end
    local ok, s = pcall(util.GetData, lp, true)
    return ok and s or nil
end

function H.level()
    local slot = H.slot()
    if not slot then return 0 end
    local exp = slot:FindFirstChild("Exp")
    local goal = exp and exp:FindFirstChild("Goal")
    local gs = Game.gameSettings
    local per = gs and gs.expPerLevel
    if not goal or not per or per == 0 then return 0 end
    return math.floor(goal.Value / per)
end

function H.exp()
    local slot = H.slot()
    if not slot then return 0, 0 end
    local exp = slot:FindFirstChild("Exp")
    local cur = exp and exp:FindFirstChild("Current")
    local goal = exp and exp:FindFirstChild("Goal")
    return (cur and cur.Value or 0), (goal and goal.Value or 0)
end

function H.value(k)
    local slot = H.slot()
    if not slot or not k then return nil end
    local v = slot:FindFirstChild(k)
    return v and v.Value or nil
end

function H.race() return H.value("Race") or "?" end
function H.clan() return H.value("Clan") or "?" end
function H.wen() return H.value("Wen") or 0 end
function H.skillPoints() return H.value("SkillPoints") or 0 end

function H.inventory()
    local slot = H.slot()
    if not slot then return nil, nil end
    local inv = slot:FindFirstChild("Inventory")
    if not inv then return nil, nil end
    return inv:FindFirstChild("Inventory"), inv:FindFirstChild("Toolbar")
end

function H.count(name)
    if not name then return 0 end
    local items = H.inventory()
    if not items then return 0 end
    local item = items:FindFirstChild(name)
    if not item then return 0 end
    local a = item:FindFirstChild("Amount")
    return a and a.Value or 1
end

function H.hotbarIdx(name)
    if not name then return nil end
    local items, bar = H.inventory()
    if not items or not bar then return nil end
    local item = items:FindFirstChild(name)
    if not item then return nil end
    local id = item:FindFirstChild("Id")
    if not id then return nil end
    for i, k in ipairs({"One","Two","Three","Four","Five"}) do
        local e = bar:FindFirstChild(k)
        if e and e.Value == id.Value then return i end
    end
    return nil
end

function H.equip(idx)
    local lp = Services.LocalPlayer
    if not lp or not idx then return false end
    local cfg = lp:FindFirstChild("Items_Config")
    if not cfg then return false end
    local eq = cfg:FindFirstChild("Equipped")
    if not eq then return false end
    if eq.Value == idx then return true end
    if eq.Value ~= 0 then eq.Value = 0 task.wait(0.4) end
    eq.Value = idx
    task.wait(0.4)
    return eq.Value == idx
end

function H.mobs(range)
    local _, hrp = H.char()
    if not hrp then return {} end
    range = range or 100
    local list = {}
    local humFolder = workspace:FindFirstChild("Humanoids")
    local regions = humFolder and humFolder:FindFirstChild("Regions")
    if not regions then return list end
    for _, reg in ipairs(regions:GetChildren()) do
        local active = reg:FindFirstChild("ActiveNpcs")
        if active then
            for _, folder in ipairs(active:GetChildren()) do
                local ok5, rig = pcall(function()
                    return folder:FindFirstChild(folder.Name)
                end)
                if ok5 and rig and rig:GetAttribute("IsMob") == true then
                    local hum = rig:FindFirstChildOfClass("Humanoid")
                    local root = rig:FindFirstChild("HumanoidRootPart")
                    if hum and hum.Health > 0 and root then
                        local d = (root.Position - hrp.Position).Magnitude
                        if d <= range then
                            table.insert(list, {
                                rig = rig, root = root, hum = hum,
                                dist = d, health = hum.Health, maxHealth = hum.MaxHealth,
                            })
                        end
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

function H.bosses(range)
    local mobs = H.mobs(range or 500)
    local list = {}
    for _, m in ipairs(mobs) do
        local parent = m.rig.Parent
        if parent and parent:FindFirstChild("BossInfo") then
            table.insert(list, m)
        end
    end
    return list
end

function H.npcSpawn(name)
    if not name then return nil end
    local regions = Game.Regions
    if not regions or not regions.GetNpcSpawn then return nil end
    local ok, pos = pcall(regions.GetNpcSpawn, name)
    if ok and typeof(pos) == "Vector3" then return pos end
    return nil
end

function H.npcModel(name)
    if not name then return nil end
    local debree = workspace:FindFirstChild("Debree")
    local regions = debree and debree:FindFirstChild("Regions")
    if not regions then return nil end
    for _, reg in ipairs(regions:GetChildren()) do
        local stat = reg:FindFirstChild("StationaryNpcs")
        local m = stat and stat:FindFirstChild(name)
        if m and m:IsA("Model") then return m end
    end
    return nil
end

function H.interactNPC(model)
    if not model then return false end
    local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        if fireproximityprompt then
            local ok = pcall(fireproximityprompt, prompt)
            if ok then return true end
        end
        local hold, sight = prompt.HoldDuration, prompt.RequiresLineOfSight
        local ok2 = pcall(function()
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
            task.wait(0.1)
            prompt:InputHoldBegin()
            task.wait(0.15)
            prompt:InputHoldEnd()
        end)
        pcall(function()
            prompt.HoldDuration = hold
            prompt.RequiresLineOfSight = sight
        end)
        return ok2
    end
    local cd = model:FindFirstChildWhichIsA("ClickDetector", true)
    if cd and fireclickdetector then return pcall(fireclickdetector, cd) end
    return false
end

function H.attack(pos)
    if not pos then return false end
    local se = Game.SignalEvent
    if not se or not se.ToServer then return false end
    pcall(function() se.ToServer("Tool_Mouse", "Down", pos) end)
    task.wait(0.05)
    pcall(function() se.ToServer("Tool_Mouse", "Up", pos) end)
    return true
end

function H.moveTo(pos)
    local _, hum = H.char()
    if not hum or not pos then return false end
    pcall(function() hum:MoveTo(pos) end)
    return true
end

function H.safeTP(pos)
    local _, hrp = H.char()
    if not hrp or not pos then return false end
    local d = (pos - hrp.Position).Magnitude
    if d > 50 then
        local dir = (pos - hrp.Position).Unit
        pcall(function()
            hrp.CFrame = CFrame.new(hrp.Position + dir * 30 + Vector3.new(0, 3, 0))
        end)
        return false
    end
    pcall(function()
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end)
    return true
end

function H.faceTarget(pos)
    local _, hrp = H.char()
    if not hrp or not pos then return end
    local cam = workspace.CurrentCamera
    if cam then
        pcall(function() cam.CFrame = CFrame.new(cam.CFrame.Position, pos) end)
    end
end

function H.isCasting()
    local c = H.char()
    if not c then return false end
    local shc = c:FindFirstChild("SHC") or c:FindFirstChild("SHCS")
    if not shc then return false end
    return shc.Value ~= "" or shc:GetAttribute("en") == true
end

function H.skillBar()
    local sp = Game.Skills_Provider
    if not sp or not sp.get_current_keys then return {} end
    local ok, keys = pcall(sp.get_current_keys)
    if not ok or type(keys) ~= "table" then return {} end
    local bar = {}
    for i = 1, 10 do
        local e = keys[i]
        if type(e) == "table" and e.Name and e.Name ~= "" then
            table.insert(bar, {
                name = e.Name,
                maxHold = tonumber(e.Max_Hold) or 0,
                index = i,
            })
        end
    end
    return bar
end

function H.findWater(radius)
    local _, hrp = H.char()
    if not hrp then return nil end
    radius = radius or 32
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    local lp = Services.LocalPlayer
    if lp and lp.Character then
        p.FilterDescendantsInstances = { lp.Character }
    end
    for r = 8, radius, 4 do
        for i = 0, 15 do
            local a = i * math.pi / 8
            local o = hrp.Position + Vector3.new(math.cos(a)*r, 50, math.sin(a)*r)
            local hit = workspace:Raycast(o, Vector3.new(0,-150,0), p)
            if hit and hit.Material == Enum.Material.Water then
                return hit.Position
            end
        end
    end
    return nil
end

-- ANTI-CHEAT
local AntiCheat = { lastPos = nil, fails = 0, onFail = nil }

function AntiCheat.check()
    local _, hrp = H.char()
    if not hrp then return false end
    if AntiCheat.lastPos then
        local diff = (hrp.Position - AntiCheat.lastPos).Magnitude
        if diff > 100 then
            AntiCheat.lastPos = hrp.Position
            AntiCheat.fails = AntiCheat.fails + 1
            if AntiCheat.onFail then pcall(AntiCheat.onFail) end
            return true
        end
    end
    AntiCheat.lastPos = hrp.Position
    return false
end

function AntiCheat.reset()
    AntiCheat.fails = 0
    AntiCheat.lastPos = nil
end

-- CONFIG
local Config = { data = {}, file = "KyokaHub/config.json" }
function Config.set(k, v) if k then Config.data[k] = v end end
function Config.get(k, default)
    if k and Config.data[k] ~= nil then return Config.data[k] end
    return default
end
function Config.save()
    if not writefile then return false end
    local http = Services.HttpService
    if not http then return false end
    local ok, encoded = pcall(function() return http:JSONEncode(Config.data) end)
    if not ok then return false end
    return pcall(writefile, Config.file, encoded)
end
function Config.load()
    if not readfile or not isfile then return false end
    if not isfile(Config.file) then return false end
    local ok, content = pcall(readfile, Config.file)
    if not ok then return false end
    local http = Services.HttpService
    if not http then return false end
    local ok2, data = pcall(function() return http:JSONDecode(content) end)
    if ok2 and type(data) == "table" then
        Config.data = data
        return true
    end
    return false
end

-- EVENT BUS
local EventBus = { listeners = {} }
function EventBus.on(event, fn)
    if not event or type(fn) ~= "function" then return end
    EventBus.listeners[event] = EventBus.listeners[event] or {}
    table.insert(EventBus.listeners[event], fn)
end
function EventBus.emit(event, ...)
    local list = EventBus.listeners[event]
    if not list then return end
    for _, fn in ipairs(list) do pcall(fn, ...) end
end

-- EXPORTA
local Core = {
    version = "4.0",
    ready = false,
    Services = Services,
    Game = Game,
    H = H,
    Logger = Logger,
    AntiCheat = AntiCheat,
    Config = Config,
    EventBus = EventBus,
}

_G.__KyokaHub = Core
Core.ready = true

Logger.log("core.lua carregado")
Logger.log("Módulos:",
    Game.Utility and "Utility OK" or "Utility X",
    Game.SignalEvent and "SignalEvent OK" or "SignalEvent X")

end)

if not ok then
    warn("[Kyôka] ERRO FATAL em core.lua: " .. tostring(err))
else
    print("[Kyôka] ✅ core.lua pronto")
end
