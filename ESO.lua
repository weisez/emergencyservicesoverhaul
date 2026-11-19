script_name("Emergency Services Overhaul")
script_description("Многофункциональный скрипт для привнесения иммерсивности при отыгрыше экстренных служб")
script_author("Weisez~")
script_version("v2.0 ESO SYNC")

math.randomseed(os.time())

local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Библиотеки и зависимости
require "lib.moonloader"
local mem = require "memory"
local keys = require "vkeys"
local ev = require "moonloader".audiostream_state
local sampev = require 'lib.samp.events'

-- Облачная синхронизация (общие каллсигны и отчёты подразделений).
local ESO_SYNC_URL = "https://eso-sync.weisez.workers.dev"
local okSync, sync = pcall(require, 'eso_sync')
if not okSync then
    print("[ESO] eso_sync.lua не найден, синхронизация отключена: " .. tostring(sync))
    sync = nil
end

-- :lower() для кириллицы
local lower, sub, char, upper = string.lower, string.sub, string.char, string.upper
local concat = table.concat

local lu_rus, ul_rus = {}, {}
for i = 192, 223 do
    local A, a = char(i), char(i + 32)
    ul_rus[A] = a
    lu_rus[a] = A
end
local E, e = char(168), char(184)
ul_rus[E] = e
lu_rus[e] = E

function string.nlower(s)
    s = lower(s)
    local len, res = #s, {}
    for i = 1, len do
        local ch = sub(s, i, i)
        res[i] = ul_rus[ch] or ch
    end
    return concat(res)
end

function string.nupper(s)
    s = upper(s)
    local len, res = #s, {}
    for i = 1, len do
        local ch = sub(s, i, i)
        res[i] = lu_rus[ch] or ch
    end
    return concat(res)
end

-- имхуи
local imgui = require 'mimgui'
local showSirenPanel = false
local panelAlpha = 0.0
local sirenMode = 0
local myHudFont = nil
local isHornActive = false
local lastVehicleHandle = nil
local lastVehicleSiren = 0
local isPassengerMode = false

-- имхуи, ситуации
local sirepAlert = 0
local sirepAlertText = ""
local sirepAlertTime = 0
local SIREP_DISPLAY_DURATION = 15  -- секунд показа алерта
local pending911CallerId = nil      -- ID того кто вызвал ментов

-- ==================== ESO WARNINGS ====================
local esoWarnings      = {}
local esoWarnShowUntil = 0

local function addEsoWarning(text, duration)
    duration = duration or 15
    table.insert(esoWarnings, { text = text, expire = os.clock() + duration })
    esoWarnShowUntil = math.max(esoWarnShowUntil, os.clock() + duration)
end

-- Глобальные переменные
local countMeg = 0 -- кд для мегафона
local cooldownMeg = os.clock()
local cooldownSitrep = os.clock() -- кд для оповещения по кодам
local playerNickname = "" -- никнейм пользователя для заключения контракта с МО РФ
local activeCallsigns = {}
local vehicleSignRegistry = {}
local currentUnit = "" -- юнит устанавливается через /setunit
local esoHelpOpen = false
local esoHelpTab  = 1

-- ==================== PERSISTENT CALLSIGNS (v1.3 -- функция пока что отключена, массив оставляю на всякий случай ====================
local DEFAULT_CALLSIGNS = {
	-- LVPD
	[2000] = "ESO"
	-- [429] = "UTILITY 1 | LV-ES",
	-- [430] = "UTILITY 2 | LV-ES",
	-- [431] = "3A10 | LV-ES",
	-- [432] = "3A11 | LV-ES",
	-- [433] = "3A12 | LV-ES",
	-- [423] = "3A13 | LV-ES",
	-- [422] = "3A14 | LV-ES",
	-- [421] = "3A15 | LV-ES",
	-- [420] = "3A16 | LV-ES",
	-- [419] = "3H99 | LV-ES",
	-- [434] = "3S01 | LV-ES",
	-- [435] = "3S02 | LV-ES",
	-- [436] = "3S03 | LV-ES",
	-- [437] = "3S04 | LV-ES",
	-- [418] = "3S05 | LV-ES",
	-- [424] = "3M30 | LV-ES",
	-- [425] = "3M31 | LV-ES",
	-- [426] = "3M32 | LV-ES",
	-- [427] = "3M33 | LV-ES",
	-- [428] = "3M34 | LV-ES",
	-- [415] = "TACTICAL 3 | LV-ES",	
	-- [416] = "SPECIAL 1 | LV-ES",
	-- [417] = "SPECIAL 2 | LV-ES",
	-- [438] = "SKYHAWK 3",
	--LSPD
	-- [389] = "UTILITY 1 | LS-ES",
	-- [388] = "UTILITY 2 | LS-ES",
	-- [387] = "1A10 | LS-ES",
	-- [386] = "1A11 | LS-ES",
	-- [385] = "1A12 | LS-ES",
	-- [384] = "1A13 | LS-ES",
	-- [383] = "1A14 | LS-ES",
	-- [382] = "1A15 | LS-ES",
	-- [381] = "1A16 | LS-ES",
	-- [375] = "1H99 | LS-ES",
	-- [380] = "1A17 | LS-ES",
	-- [379] = "1A18 | LS-ES",
	-- [378] = "1A19 | LS-ES",
	-- [377] = "1A20 | LS-ES",
	-- [376] = "1A21 | LS-ES",
	-- [374] = "1M30 | LS-ES",
	-- [373] = "1M31 | LS-ES",
	-- [372] = "1M32 | LS-ES",
	-- [371] = "1M33 | LS-ES",
	-- [370] = "1M34 | LS-ES",
	-- [369] = "TACTICAL 1 | LV-ES",	
	-- [367] = "SPECIAL 1 | LS-ES",
	-- [368] = "SPECIAL 2 | LS-ES",
	-- [390] = "SKYHAWK 1",
	--SFPD
	-- [412] = "UTILITY 1 | SF-ES",
	-- [413] = "UTILITY 2 | SF-ES",
	-- [411] = "2A10 | SF-ES",
	-- [410] = "2A11 | SF-ES",
	-- [409] = "2A12 | SF-ES",
	-- [408] = "2A13 | SF-ES",
	-- [407] = "2A14 | SF-ES",
	-- [406] = "2A15 | SF-ES",
	-- [405] = "2A16 | SF-ES",
	-- [399] = "2H99 | SF-ES",
	-- [404] = "2A17 | SF-ES",
	-- [403] = "2A18 | SF-ES",
	-- [402] = "2A19 | SF-ES",
	-- [401] = "2A20 | SF-ES",
	-- [400] = "2A21 | SF-ES",
	-- [398] = "2M30 | SF-ES",
	-- [397] = "2M31 | SF-ES",
	-- [396] = "2M32 | SF-ES",
	-- [395] = "2M33 | SF-ES",
	-- [394] = "2M34 | SF-ES",
	-- [393] = "TACTICAL 1 | SF-ES",	
	-- [391] = "SPECIAL 1 | SF-ES",
	-- [392] = "SPECIAL 2 | SF-ES",
	-- [414] = "SKYHAWK 2"
}

local userOverriddenCallsigns = {}

-- Загрузка звуков
local SirenToggle = nil
local SirenUntoggle = nil

local PullOver1 = nil
local PullOver2 = nil
local PullOver3 = nil

local soundRadioClickOn = nil
local soundRadioClickEnd = nil

local ambientRadioSounds = {}
local currentAmbientSound = nil

-- ==================== DEPT AMBIENT ====================
local deptAmbientSounds = {}
local currentDeptAmbient = nil
local isDeptAmbientPlaying = false

local DEPT_ZONES = { -- думал, что разные координаты. По факту оказались одни и те же, только в разных виртуалках...
    {
        name = "LVPD",  
        x = 1794.7744,         
        y = -26.9065,        
        z = 1000.9223,         
        radius = 30.0
    },
}

local function isPlayerNearDept()
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    for _, zone in ipairs(DEPT_ZONES) do
        local dx = px - zone.x
        local dy = py - zone.y
        local dz = pz - zone.z
        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
        if dist <= zone.radius then
            return true, zone.name
        end
    end
    return false, nil
end

local CIVILIAN_SERVICE_IDS = {
    -- LVPD
    [429] = true, [430] = true, [419] = true,
    -- LSPD
    [389] = true, [388] = true, [390] = true,
    -- SFPD
    [412] = true, [413] = true, [414] = true,
}

local function isInServiceVehicle(ped)
    if isCharInAnyPoliceVehicle(ped) then return true end
    if not isCharInAnyCar(ped) then return false end
    local veh = storeCarCharIsInNoSave(ped)
    local ok, sampVehId = sampGetVehicleIdByCarHandle(veh)
    if ok and sampVehId ~= -1 then
        return CIVILIAN_SERVICE_IDS[sampVehId] == true
    end
    return false
end

-- ==================== МОСКОВСКОЕ ВРЕМЯ ====================
-- Все даты в докладах пишутся по Москве (UTC+3, без перехода на летнее время), независимо от часового пояса игрока.
function esoMskTime(t) return (t or os.time()) + 10800 end
function esoMskDate(fmt, t) return os.date("!" .. fmt, esoMskTime(t)) end

-- Ссылка из игры: браузер НЕ запускаем.
-- ShellExecute из потока отрисовки GTA SA сворачивает/роняет игру (краш при клике на Discord),
-- поэтому ссылка копируется в буфер обмена, а открыть её можно через Ctrl+V в браузере или Discord.
function esoOpenUrl(url)
    if type(url) ~= "string" or not url:match("^https://") then return false end
    local ok = pcall(function() imgui.SetClipboardText(url) end)
    if not ok then ok = pcall(function() setClipboardText(url) end) end
    if ok then
        sampAddChatMessage("[ESO] Ссылка скопирована в буфер обмена. Вставьте её (Ctrl+V) в браузер или в Discord.", 0x7EC8E3)
    else
        sampAddChatMessage("[ESO] Не удалось скопировать ссылку: " .. url, 0xFF6A00)
    end
    return ok
end

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    wait(300)
    
    local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    playerNickname = sampGetPlayerNickname(myId)
    playerNickname = playerNickname:gsub(' ', '_')

    -- ---- Облачная синхронизация ----
    if sync then
        local okInit, errInit = pcall(sync.init, {
            baseUrl = ESO_SYNC_URL,
            dir = getWorkingDirectory() .. "\\Immersive Siren\\config\\sync\\",
            version = thisScript().version,
            serverKey = function()
                local ip, port = sampGetCurrentServerAddress()
                if ip and ip ~= "" and port then return ip .. ":" .. tostring(port) end
                return nil
            end,
            nick = function() return playerNickname end,
            onCallsigns = esoSyncApplyCallsigns,
            onStatus = esoSyncOnStatus,
            isActive = function()
                local ok, r = pcall(isCharInAnyCar, PLAYER_PED)
                return ok and r and true or false
            end,
            isPaused = function()
                local ok, r = pcall(isGamePaused)
                return ok and r and true or false
            end,
        })
        if not okInit then print("[ESO] Ошибка запуска синхронизации: " .. tostring(errInit)) end
    end

    sampAddChatMessage("<> Emergency Services Overhaul <>", 0x00BFFF)
    sampAddChatMessage("<> Скрипт загружен. Удачной смены! <>", 0x7EC8E3)
    sampAddChatMessage("<> Справка -- /esohelp <>", 0x7EC8E3)

    -- ---- Проверка сервера ----
    local ALLOWED_SERVERS = {
        "185.169.134.239:7777",   -- Advance RP Blue
        "185.169.134.237:7777",   -- Advance RP Red
        "185.169.134.238:7777",   -- Advance RP Green
		"185.169.134.156:7777",   -- Advance RP Lime
		"185.169.134.157:7777",   -- Advance RP Chocolate
    }

    lua_thread.create(function()
        wait(1200)
        local ip, port = sampGetCurrentServerAddress()
        local addr = (ip or "") .. ":" .. tostring(port or "")
        local allowed = false
        for _, s in ipairs(ALLOWED_SERVERS) do
            if addr == s then allowed = true; break end
        end
        if not allowed then
            sampAddChatMessage("[ESO] ВНИМАНИЕ: скрипт оптимизирован для Advance RP.", 0xFF6A00)
            sampAddChatMessage("[ESO] ВНИМАНИЕ: работоспособность на других серверах не гарантируется.", 0xFF6A00)
            addEsoWarning(u8("[ESO] НЕВЕРНЫЙ СЕРВЕР  --  оптимизировано для Advance RP"), 20)
        end
    end)
	
    sampRegisterChatCommand("vsign", function(arg)
        if arg == "" or arg == nil then
            sampAddChatMessage("[ESO] Используйте: /vsign [маркировка]. Используйте \\n для переноса строк.", -1)
            sampAddChatMessage("[ESO] /vsign reset ([ID])  --  сбросить override, вернуть дефолтный каллсигн", -1)
            return
        end

        -- /vsign reset [ID]: снять override, вернуть дефолтный каллсигн
        -- Если ID указан — ресетится та машина, иначе — та, в которой сидишь
        local resetWord, resetIdArg = arg:match("^(%S+)%s*(%d*)$")
        if resetWord and resetWord:lower() == "reset" then
            local sampVehicleId
            if resetIdArg and resetIdArg ~= "" then
                sampVehicleId = tonumber(resetIdArg)
                if not sampVehicleId then
                    sampAddChatMessage("[ESO] Неверный ID авто.", -1)
                    return
                end
            else
                if not isCharInAnyCar(PLAYER_PED) then
                    sampAddChatMessage("[ESO] Вы должны находиться внутри автомобиля.", -1)
                    return
                end
                local currentCar = storeCarCharIsInNoSave(PLAYER_PED)
                local result, id = sampGetVehicleIdByCarHandle(currentCar)
                if not result or id == -1 then
                    sampAddChatMessage("[ESO] Не удалось получить ID авто.", -1)
                    return
                end
                sampVehicleId = id
            end
            userOverriddenCallsigns[sampVehicleId] = nil
            vehicleSignRegistry[sampVehicleId] = nil
            if sync and sync.isEnabled() then sync.deleteCallsign(sampVehicleId) end
            if activeCallsigns[sampVehicleId] and activeCallsigns[sampVehicleId].textId then
                sampDelete3dText(activeCallsigns[sampVehicleId].textId)
                activeCallsigns[sampVehicleId] = nil
            end
            if DEFAULT_CALLSIGNS[sampVehicleId] then
                -- createLocalCallsign(sampVehicleId, DEFAULT_CALLSIGNS[sampVehicleId])
                -- sampSendChat("/n #VSIGN# " .. sampVehicleId .. " | " .. DEFAULT_CALLSIGNS[sampVehicleId])
                sampAddChatMessage("[ESO] Callsign #" .. sampVehicleId .. " reset to default: " .. DEFAULT_CALLSIGNS[sampVehicleId], -1)
            else
				sampDestroy3dText(sampVehicleId)
                sampAddChatMessage("[ESO] Каллсигн #" .. sampVehicleId .. " очищен. Дефолтный для этой машины не задан.", -1)
            end
            return
        end

        setLocalVehicleCallsign(arg)
    end)	

    sampRegisterChatCommand("setunit", function(arg)
        if arg == "" or arg == nil then
            if currentUnit ~= "" then
                sampAddChatMessage("[ESO] Текущий юнит: " .. currentUnit, -1)
            else
                sampAddChatMessage("[ESO] Юнит не задан. Пример: /setunit 3A19", -1)
            end
            return
        end
        currentUnit = arg:upper()
        sampAddChatMessage("[ESO] Юнит установлен: " .. currentUnit, 0x00BFFF)
    end)

    sampRegisterChatCommand("rr", function(arg)
        if currentUnit == "" then
            sampAddChatMessage("[ESO] Юнит не задан. Пример: /setunit 3A19", -1)
            return
        end
        if arg == "" or arg == nil then
            sampAddChatMessage("[ESO] Используйте: /rr [сообщение]", -1)
            return
        end
        sampSendChat("/r " .. currentUnit .. ", " .. arg)
    end)

    sampRegisterChatCommand("ff", function(arg)
        if currentUnit == "" then
            sampAddChatMessage("[ESO] Юнит не задан. Пример: /setunit 3A19", -1)
            return
        end
        if arg == "" or arg == nil then
            sampAddChatMessage("[ESO] Используйте: /ff [сообщение]", -1)
            return
        end
        sampSendChat("/f " .. currentUnit .. ", " .. arg)
    end)

    sampRegisterChatCommand("esohelp", function()
        esoHelpOpen = not esoHelpOpen
    end)

    -- повторно считать данные офицера из /st
    sampRegisterChatCommand("esostat",  function() ESOAuto.statDone = false; ESOAuto.start("manual") end)

    -- повторно считать номер аккаунта (BADGE): /mn -> Донат -> Информация
    sampRegisterChatCommand("esobadge", function() ESOAuto.badgeFound = false; ESOAuto.fetchBadge(true) end)

-- ==================== МАССИВЫ СО ЗВУКАМИ ====================	

	radioClicks = { -- исходящее сообщение в /r (инициатор только юзер)
        loadAudioStream("moonloader\\Immersive Siren\\radioclick1.mp3"),
        loadAudioStream("moonloader\\Immersive Siren\\radioclick2.mp3"),
		loadAudioStream("moonloader\\Immersive Siren\\radioclick3.wav"),
		loadAudioStream("moonloader\\Immersive Siren\\radioclick4.wav")
    }
	
	factionRadioClicks = { -- звуки при написании в /f (инициатор только юзер)
        loadAudioStream("moonloader\\Immersive Siren\\factionradioclick1.mp3"),
        loadAudioStream("moonloader\\Immersive Siren\\factionradioclick2.wav"),
		loadAudioStream("moonloader\\Immersive Siren\\factionradioclick3.wav"),
		loadAudioStream("moonloader\\Immersive Siren\\factionradioclick4.wav")
    }

	dispatchRobberySounds = { -- звуки при ограблении, угоне (инициатор - сервер)
        loadAudioStream("moonloader\\Immersive Siren\\trafficstop.wav")
    }
	
	dispatchCallSounds = { -- звуки при 911 (инициатор - сервер)
        loadAudioStream("moonloader\\Immersive Siren\\1call911.wav"),
		loadAudioStream("moonloader\\Immersive Siren\\2call911.wav")
    }
	
	cuffSounds = { -- звуки браслетов (инициатор только юзер)
        loadAudioStream("moonloader\\Immersive Siren\\cuff1.mp3"),
        loadAudioStream("moonloader\\Immersive Siren\\cuff2.mp3"),
        loadAudioStream("moonloader\\Immersive Siren\\cuff3.mp3")
    }	
	
	putplSounds = { -- звуки заталкивания оппонента в мусорскую тачанку (инициатор только юзер)
        loadAudioStream("moonloader\\Immersive Siren\\putpl1.mp3"),
        loadAudioStream("moonloader\\Immersive Siren\\putpl2.mp3")
    }	
	
	holdSounds = { -- звуки как ведут задержанного (инициатор только юзер)
        loadAudioStream("moonloader\\Immersive Siren\\hold1.m4a"),
        loadAudioStream("moonloader\\Immersive Siren\\hold2.m4a")
    }	
	
	arrestSounds = { -- звуки при выдаче 90 минут отдыха (инициатор только юзер)
        loadAudioStream("moonloader\\Immersive Siren\\arrest1.mp3")
        -- loadAudioStream("moonloader\\Immersive Siren\\radioclick2.mp3")
    }	
	
	searchSounds = { -- звуки при обыске (инициатор только юзер)
        loadAudioStream("moonloader\\Immersive Siren\\search1.mp3"),
        loadAudioStream("moonloader\\Immersive Siren\\search2.mp3"),
        loadAudioStream("moonloader\\Immersive Siren\\search3.mp3")
    }
	
-- ==================== ЗАГРУЗКА ЗВУКОВ ====================

local function loadSound(path)
    local s = loadAudioStream(path)
    local name = path:match("([^\\/]+)$") or path
    if s then
        print("[ESO] [OK] " .. name)
    else
        print("[ESO] [FAIL] " .. name)
    end
    return s
end

print("[ESO] ----- Загрузка звуковых модулей -----")

SirenToggle = loadSound("moonloader\\Immersive Siren\\SirenToggle.wav")
SirenUntoggle = loadSound("moonloader\\Immersive Siren\\SirenSwitch.wav")

PullOver1 = loadSound("moonloader\\Immersive Siren\\1 stop the vehicle.wav")
PullOver2 = loadSound("moonloader\\Immersive Siren\\2 hey im serious stop.wav")
PullOver3 = loadSound("moonloader\\Immersive Siren\\3 this isnt a joke.wav")

sitrepCodeZero = loadSound("moonloader\\Immersive Siren\\code0.mp3")
sitrepCodeOne = {
	loadSound("moonloader\\Immersive Siren\\code1.mp3"),
	loadSound("moonloader\\Immersive Siren\\shotsfired.wav")
}
sitrepCodeThree = {
	loadSound("moonloader\\Immersive Siren\\code3.mp3"),
	loadSound("moonloader\\Immersive Siren\\trafficstop.wav")
}

ambientRadioSounds = { -- эмбиенты для машины
    loadSound("moonloader\\Immersive Siren\\policeChatter1.mp3"),
    -- loadSound("moonloader\\Immersive Siren\\policeChatter2.mp3"),
    loadSound("moonloader\\Immersive Siren\\policeChatter2.mp3")
}

deptAmbientSounds = { -- dept ambients
    loadSound("moonloader\\Immersive Siren\\stationAmbient1.m4a"),
    loadSound("moonloader\\Immersive Siren\\stationAmbient2.mp3"),
    loadSound("moonloader\\Immersive Siren\\stationAmbient3.mp3")
}

print("[ESO] ----- Звуковые модули загружены -----")

megaphoneContexts = {
    {
        audio = PullOver1,
        index = 0,
        groupA = { "останов", "прижмит", "сбавьте", "тормоз" },
        groupB = { "машин", "обоч", "транспорт", "т/с", "автомобиль", "скорость" }
    },
    
    {
        audio = PullOver2,
        index = 1,
        groupA = { "заглуш", "выключ", "глуш", "руки", "оставай" },
        groupB = { "двигатель", "мотор", "зажиган", "руль", "капот", "месте" }
    },
    
    {
        audio = PullOver3,
        index = 2,
        groupA = { "открою", "применю", "будет", "стрелять", "оружие" },
        groupB = { "огонь", "силу", "таран", "пистолет", "крузер" }
    }
}

-- ==================== ЭМБИЕНТ В МАШИНЕ ====================	
    local isAmbientPlaying = false

    lua_thread.create(function()
        while true do
            wait(1000)
            
            local isDriverInPoliceCar = isInServiceVehicle(PLAYER_PED) and getDriverOfCar(storeCarCharIsInNoSave(PLAYER_PED)) == PLAYER_PED
            
            if isDriverInPoliceCar then
                if not isAmbientPlaying and currentAmbientSound == nil then
                    isAmbientPlaying = true
                    currentAmbientSound = ambientRadioSounds[math.random(1, #ambientRadioSounds)]
                    
                    if currentAmbientSound then
                        setAudioStreamVolume(currentAmbientSound, 0.20)
                        setAudioStreamState(currentAmbientSound, ev.PLAY)
                        
                        local playDuration = math.random(5, 12)
                        wait(playDuration * 1000)
                        
                        for vol = 15, 0, -1 do
                            if currentAmbientSound and isInServiceVehicle(PLAYER_PED) then 
                                setAudioStreamVolume(currentAmbientSound, vol / 100) 
                                wait(60)
                            end
                        end
                        
                        if currentAmbientSound then
                            setAudioStreamState(currentAmbientSound, ev.STOP)
                            currentAmbientSound = nil
                        end
                        isAmbientPlaying = false
                        
                        local silenceDuration = math.random(8, 20)
                        wait(silenceDuration * 1000)
                    else
                        isAmbientPlaying = false
                    end
                end
            else
                if currentAmbientSound ~= nil then
                    setAudioStreamVolume(currentAmbientSound, 0.05)
                    wait(50)
                    setAudioStreamState(currentAmbientSound, ev.STOP)

                    currentAmbientSound = nil
                    isAmbientPlaying = false
                end
            end
        end
    end)
	
	
-- ==================== ЭМБИЕНТ НА СТАНЦИЯХ ====================
    lua_thread.create(function()
        while true do
            wait(1000)

            local nearDept, deptName = isPlayerNearDept()

            if nearDept then
                if not isDeptAmbientPlaying and currentDeptAmbient == nil then
                    isDeptAmbientPlaying = true
                    local validSounds = {}
                    for _, s in ipairs(deptAmbientSounds) do
                        if s then validSounds[#validSounds + 1] = s end
                    end
                    if #validSounds > 0 then
                        currentDeptAmbient = validSounds[math.random(1, #validSounds)]
                        local baseVol = 0.20 + math.random() * 0.10
                        setAudioStreamVolume(currentDeptAmbient, baseVol)
                        setAudioStreamState(currentDeptAmbient, ev.PLAY)
                        print("[ESO] STATION AMBIENT vol=" .. string.format("%.2f", baseVol))
                        local playDuration = math.random(8, 18)
                        local elapsed = 0
                        while elapsed < playDuration do
                            wait(2000)
                            elapsed = elapsed + 2
                            local stillNear = isPlayerNearDept()
                            if not stillNear then break end
                            local drift = baseVol + (math.random() - 0.5) * 0.06
                            drift = math.max(0.06, math.min(0.25, drift))
                            setAudioStreamVolume(currentDeptAmbient, drift)
                        end
                        local curVol = baseVol
                        while curVol > 0.0 do
                            curVol = curVol - 0.01
                            if curVol < 0.0 then curVol = 0.0 end
                            if currentDeptAmbient then
                                setAudioStreamVolume(currentDeptAmbient, curVol)
                            end
                            wait(60)
                        end
                        if currentDeptAmbient then
                            setAudioStreamState(currentDeptAmbient, ev.STOP)
                            currentDeptAmbient = nil
                        end
                        isDeptAmbientPlaying = false
                        local silenceDuration = math.random(5, 15)
                        wait(silenceDuration * 1000)
                    else
                        isDeptAmbientPlaying = false
                    end
                end
            else
                if currentDeptAmbient ~= nil then
                    local fadeVol = 0.18
                    while fadeVol > 0.0 do
                        fadeVol = fadeVol - 0.02
                        if fadeVol < 0.0 then fadeVol = 0.0 end
                        setAudioStreamVolume(currentDeptAmbient, fadeVol)
                        wait(40)
                    end
                    setAudioStreamState(currentDeptAmbient, ev.STOP)
                    currentDeptAmbient = nil
                    isDeptAmbientPlaying = false
                end
            end
        end
    end)

-- ==================== дефолтные VSIGN (v1.3 -- убрано из-за обновления на сервере, айдишники автомобилей часто сбиваются ====================
-- ==================== а возможности быстро отслеживать изменения - нет :( ====================
    -- lua_thread.create(function()
        -- wait(3000)
        -- while true do
            -- local allVehIds = {}
            -- for vehId in pairs(DEFAULT_CALLSIGNS) do allVehIds[vehId] = true end
            -- for vehId in pairs(vehicleSignRegistry) do allVehIds[vehId] = true end

            -- for vehId in pairs(allVehIds) do
                -- local success, ok, carHandle = pcall(sampGetCarHandleBySampVehicleId, vehId)
                -- if not success then ok = false; carHandle = nil end
                -- if ok and carHandle and carHandle ~= 0 then
                    -- local wantedSign = vehicleSignRegistry[vehId]
                        -- or (not userOverriddenCallsigns[vehId] and DEFAULT_CALLSIGNS[vehId])
                    -- if wantedSign then
                        -- local active = activeCallsigns[vehId]
                        -- if not active or not active.textId or active.string ~= wantedSign then
                            -- createLocalCallsign(vehId, wantedSign)
                        -- end
                    -- end
                -- else
                    -- if activeCallsigns[vehId] and activeCallsigns[vehId].textId then
                        -- sampDelete3dText(activeCallsigns[vehId].textId)
                        -- activeCallsigns[vehId] = nil
                    -- end
                -- end
            -- end
            -- wait(5000)
        -- end
    -- end)

-- ==================== WHILE TRUE DO ====================		
    while true do 
        wait(0)      
		
        -- облачная синхронизация: внутри только дешёвая проверка по времени
        if sync then
            local okTick, errTick = pcall(sync.tick)
            if not okTick and not esoSyncTickErrShown then
                esoSyncTickErrShown = true
                print("[ESO] Ошибка sync.tick: " .. tostring(errTick))
            end
        end

        -- синхра с AVS
        local isInPoliceCar = isInServiceVehicle(PLAYER_PED)
        local isDriver = isInPoliceCar and (getDriverOfCar(storeCarCharIsInNoSave(PLAYER_PED)) == PLAYER_PED)
        local isPassenger = isInPoliceCar and not isDriver

        if isDriver then
            isPassengerMode = false
            showSirenPanel = true
            
            if panelAlpha < 1.0 then panelAlpha = panelAlpha + 0.05 end
            if panelAlpha > 1.0 then panelAlpha = 1.0 end
			
            -- ============================ Память панельки ===============================            
            local currentCar = storeCarCharIsInNoSave(PLAYER_PED)
            
            if lastVehicleHandle == nil or lastVehicleHandle ~= currentCar then
                lastVehicleHandle = currentCar
                if isCarSirenOn(currentCar) then
                    sirenMode = 2
                    lastVehicleSiren = 2
                else
                    sirenMode = 0
                    lastVehicleSiren = 0
                end
                local ok_id, sampVehId = sampGetVehicleIdByCarHandle(currentCar)
                if ok_id and sampVehId ~= -1 then
                    local defSign = DEFAULT_CALLSIGNS[sampVehId]
                    if defSign then
                        local unitPart = defSign:match("^(.-)%s*|")
                        local isSpecial = defSign:match("^UTILITY") or defSign:match("^TACTICAL")
                            or defSign:match("^SPECIAL") or defSign:match("^SKYHAWK")
                        if unitPart and not isSpecial then
                            currentUnit = unitPart:upper()
                            sampAddChatMessage("[ESO] Юнит установлен по машине: " .. currentUnit, 0x00BFFF)
                        elseif isSpecial then
                            currentUnit = ""
                        end
                    else
                    end
                end
            elseif lastVehicleHandle == currentCar and lastVehicleSiren > 0 then
                sirenMode = lastVehicleSiren
                if sirenMode == 2 and not isCarSirenOn(currentCar) then
                    switchCarSiren(currentCar, true)
                end
            end
            -- ==================================================================

            if not isCarSirenOn(currentCar) and sirenMode == 2 then
                sirenMode = 0
                lastVehicleSiren = 0
            end

            if isKeyDown(VK_H) and not sampIsChatInputActive() and not isSampfuncsConsoleActive() then
                isHornActive = true
            else
                isHornActive = false
            end

            if isKeyJustPressed(VK_X) and not sampIsChatInputActive() and not isSampfuncsConsoleActive() then
                if sirenMode == 2 then
                    switchCarSiren(currentCar, false)
                    if SirenUntoggle then setAudioStreamState(SirenUntoggle, ev.PLAY) end
                    sirenMode = 0
                    lastVehicleSiren = 0
                else
                    if sirenMode == 1 then
                        setVirtualKeyDown(VK_L, true) wait(50) setVirtualKeyDown(VK_L, false) wait(50)
                    end
                    if SirenToggle then setAudioStreamState(SirenToggle, ev.PLAY) end
                    wait(300)
                    switchCarSiren(currentCar, true)
                    sirenMode = 2
                    lastVehicleSiren = 2
                end
            end

            if wasKeyPressed(VK_L) and not sampIsChatInputActive() and not isSampfuncsConsoleActive() then
                if sirenMode == 0 then
                    if SirenToggle then setAudioStreamState(SirenToggle, ev.PLAY) end
                    sirenMode = 1
                    lastVehicleSiren = 1
                elseif sirenMode == 1 then
                    if SirenUntoggle then setAudioStreamState(SirenUntoggle, ev.PLAY) end
                    sirenMode = 0
                    lastVehicleSiren = 0
                elseif sirenMode == 2 then
                    switchCarSiren(currentCar, false)
                    if SirenUntoggle then setAudioStreamState(SirenUntoggle, ev.PLAY) end
                    sirenMode = 1
                    lastVehicleSiren = 1
                end
            end

        elseif isPassenger then
            isPassengerMode = true
            showSirenPanel = true
            if panelAlpha < 1.0 then panelAlpha = panelAlpha + 0.05 end
            if panelAlpha > 1.0 then panelAlpha = 1.0 end
            isHornActive = false

            local currentCar = storeCarCharIsInNoSave(PLAYER_PED)
            if isCarSirenOn(currentCar) then
                sirenMode = 2
            else
                sirenMode = 0
            end

            if lastVehicleHandle == nil or lastVehicleHandle ~= currentCar then
                lastVehicleHandle = currentCar
                local ok_id, sampVehId = sampGetVehicleIdByCarHandle(currentCar)
                if ok_id and sampVehId ~= -1 then
                    local defSign = DEFAULT_CALLSIGNS[sampVehId]
                    if defSign then
                        local unitPart = defSign:match("^(.-)%s*|")
                        local isSpecial = defSign:match("^UTILITY") or defSign:match("^TACTICAL")
                            or defSign:match("^SPECIAL") or defSign:match("^SKYHAWK")
                        if unitPart and not isSpecial then
                            currentUnit = unitPart:upper()
                            sampAddChatMessage("[ESO] Автоматически выставился юнит: " .. currentUnit, 0x00BFFF)
                            sampSendChat("/setunit " .. currentUnit)
                        elseif isSpecial then
                            currentUnit = ""
                        end
                    end
                end
            end

        else
            isPassengerMode = false
            showSirenPanel = false
            if panelAlpha > 0.0 then panelAlpha = panelAlpha - 0.05 end
            if panelAlpha < 0.0 then panelAlpha = 0.0 end
            
            isHornActive = false 
        end






        -- ---- 911 CALL: [Y] TO ACCEPT ----
        if sirepAlert == 5 and pending911CallerId ~= nil then
            if isKeyJustPressed(VK_Y) and not sampIsChatInputActive() and not isSampfuncsConsoleActive() then
                sampSendChat("/to " .. pending911CallerId)
                pending911CallerId = nil
                sirepAlert = 0
            end
        end

    end -- while true do
end -- main

-- ==================== ON SEND CHAT ====================
function sampev.onSendChat(text)
    if text:find("#VSIGN#") then
        sampSendChat(text)
        return false
    end
end

-- ==================== ON SHOW DIALOG / ON INIT GAME ====================
function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if ESOAuto and ESOAuto.onDialog then
        local ok, res = pcall(ESOAuto.onDialog, dialogId, title, text, style)
        if ok and res == false then return false end
    end
end

function sampev.onInitGame()
    if ESOAuto then ESOAuto.statDone = false; ESOAuto.start("join") end
end

-- ==================== ON VEHICLE STREAM IN ====================
-- Машина прогрузилась: перерисовываем её каллсигн, чтобы метка гарантированно висела на ней.
function sampev.onVehicleStreamIn(vehicleId, data)
    local text = vehicleSignRegistry[vehicleId]
    if text then
        lua_thread.create(function()
            wait(300)
            if vehicleSignRegistry[vehicleId] == text then createLocalCallsign(vehicleId, text) end
        end)
    end
end

-- ==================== ON SERVER MESSAGE ====================
local function esoExtractNick(s)

    local n = s:match("%a+_%a+%[%d+%]:")
    if n then return n:match("(.-)%[") end

    n = s:match("^(%a+_%a+)%s")
    if n then return n:gsub(' ', '_') end

    n = s:match("%]%s+(%a+_%a+)%s")
    if n then return n:gsub(' ', '_') end
    return "неизвестно"
end

function sampev.onServerMessage(color, msg)
    if playerNickname == "" then return {color, msg} end

    local cleanMsg = msg:gsub("{%x%x%x%x%x%x}", "")
    local lowMsg = string.nlower(cleanMsg)
    local lowNick = playerNickname:lower()
    if ESOAuto and ESOAuto.onChat then pcall(ESOAuto.onChat, cleanMsg) end
	
	local hasMyNick = lowMsg:find(lowNick)
	local isNotChat = not lowMsg:find("%(%d+%)")
	local isMyAction = hasMyNick and isNotChat
	
    -- ---------------- [ЛОКАЛЬНАЯ СИНХРОНИЗАЦИЯ ЧЕРЕЗ ЧАТ /N] ----------------
    if lowMsg:find("#vsign#") then

        if not lowMsg:find(lowNick) then
            
            if cleanMsg:find("#VSIGN#%s*%d+%s*|%s*.+") then
                local remoteVehicleId, remoteCallsign = cleanMsg:match("#VSIGN#%s*(%d+)%s*|%s*(.-)%s*%)*%s*$")
                
                if remoteVehicleId and remoteCallsign then
                    remoteCallsign = remoteCallsign:gsub("%s*%)%s*%)%s*$", "")
                    
                    local vehIdNum = tonumber(remoteVehicleId)
                    local carResult, remoteCarHandle = sampGetCarHandleBySampVehicleId(vehIdNum)
                    
                    if carResult then

                        local convertedCallsign = remoteCallsign
                        vehicleSignRegistry[vehIdNum] = convertedCallsign
                        createLocalCallsign(vehIdNum, convertedCallsign)
                        print("[ESO] Синхронизирован чужой каллсигн [" .. convertedCallsign .. "] для авто ID: " .. vehIdNum)
                    else

                        vehicleSignRegistry[vehIdNum] = remoteCallsign
                        activeCallsigns[vehIdNum] = {
                            textId = nil,
                            string = remoteCallsign
                        }
                    end
                end
            end
            
        end
        
        return false 
    end



-- ==================== ЗВУКИ ====================

    ---------------- [R] РАЦИЯ (исходящее) ----------------
    if lowMsg:find("%[r%]") and isMyAction then
        if #radioClicks > 0 then
            local randomClick = radioClicks[math.random(1, #radioClicks)]
            if randomClick then setAudioStreamState(randomClick, ev.PLAY) end
        end
    end
	
    ---------------- [F] РАЦИЯ ФРАКЦИИ (исходящее) ----------------
    if lowMsg:find("%[f%]") and isMyAction then
        if #factionRadioClicks > 0 then
            local randomFactionClick = factionRadioClicks[math.random(1, #factionRadioClicks)]
            if randomFactionClick then setAudioStreamState(randomFactionClick, ev.PLAY) end
        end
    end
	
    -------------- [ROBBERY] ЗВУКИ ДИСПЕТЧЕРА: ОГРАБЛЕНИЯ И ТРАФФИК-СТОП ----------------
    if lowMsg:find("всем постам") and (lowMsg:find("хранил") or lowMsg:find("автомоб")) then
		print(lowMsg)
        if #dispatchRobberySounds > 0 then
            local randomDispatchRobberyClick = dispatchRobberySounds[math.random(1, #dispatchRobberySounds)] 
            if randomDispatchRobberyClick then setAudioStreamState(randomDispatchRobberyClick, ev.PLAY) end
        end
        local isRobbery = lowMsg:find("хранил") ~= nil
        sirepAlertText = isRobbery and "ROBBERY IN PROGRESS" or "VEHICLE THEFT IN PROGRESS"
        sirepAlert = 6
        sirepAlertTime = os.clock()
        local robEvent = lowMsg:find("хранил") and "Диспетчер сообщил об ограблении" or "Диспетчер сообщил об угоне транспорта"
        officerAddEvent(robEvent .. " | Подозреваемый: " .. esoExtractNick(cleanMsg))
    end
	
    ---------------- [911] ЗВУКИ ДИСПЕТЧЕРА: ВЫЗОВ 911 ----------------
    if lowMsg:find("/to%s+%d+") and lowMsg:find("обратился") then
        local callerId = cleanMsg:match("/to%s+(%d+)")
        if callerId then
            pending911CallerId = tonumber(callerId)
            if #dispatchCallSounds > 0 then
                local s = dispatchCallSounds[math.random(1, #dispatchCallSounds)]
                if s then setAudioStreamState(s, ev.PLAY) end
            end
            sirepAlert = 5
            sirepAlertText = "NEW 911 CALL  [Y] TO ACCEPT"
            sirepAlertTime = os.clock()
            officerAddEvent("Поступил вызов в 911 с номера " .. callerId .. " | Диспетчер")
        end
    end

    ---------------- [CUFF] ЗВУКИ БРАСЛЕТОВ ----------------
    if (lowMsg:find("надел наручники") or lowMsg:find("надел браслеты") or lowMsg:find("окольцевал") or lowMsg:find("застегнул наручники") or lowMsg:find("снял наручники с пояса")) and isMyAction then
        if #cuffSounds > 0 then
            local randomCuffClick = cuffSounds[math.random(1, #cuffSounds)]
            if randomCuffClick then setAudioStreamState(randomCuffClick, ev.PLAY) end
        end
        officerAddEvent("Применены спецсредства - наручники | Офицер: " .. esoExtractNick(cleanMsg))
    end

    ---------------- [PUTPL] ЗВУКИ PUTPL ----------------
    if (lowMsg:find("посадил") or lowMsg:find("усадил")) and (lowMsg:find("автомобиль") or lowMsg:find("крузер") or lowMsg:find("машин") or lowMsg:find("транспорт")) and isMyAction then
        if #putplSounds > 0 then
            local randomPutplClick = putplSounds[math.random(1, #putplSounds)]
            if randomPutplClick then setAudioStreamState(randomPutplClick, ev.PLAY) end
        end
        officerAddEvent("Подозреваемый помещён в транспорт | Офицер: " .. esoExtractNick(cleanMsg))
    end	
	
    ---------------- [HOLD] ЗВУКИ HOLD ----------------
    if ((lowMsg:find("схватил") or lowMsg:find("подхватил")) and (lowMsg:find("человек") or lowMsg:find("подозреваем") or lowMsg:find("задержан") or lowMsg:find("руку"))) and isMyAction then
        if #holdSounds > 0 then
            local randomHoldClick = holdSounds[math.random(1, #holdSounds)]
            if randomHoldClick then setAudioStreamState(randomHoldClick, ev.PLAY) end
        end
        officerAddEvent("Подозреваемый под контролем | Офицер: " .. esoExtractNick(cleanMsg))
    end

    ---------------- [ARREST] ЗВУКИ ARREST ----------------
    if lowMsg:find("передал") and (lowMsg:find("дежурн") or lowMsg:find("офицер") or lowMsg:find("дело") or lowMsg:find("кпз") or lowMsg:find("участок") or lowMsg:find("станц")) and isMyAction then
        if #arrestSounds > 0 then
            local randomArrestClick = arrestSounds[math.random(1, #arrestSounds)]
            if randomArrestClick then setAudioStreamState(randomArrestClick, ev.PLAY) end
        end
        officerAddEvent("Подозреваемый передан на станцию | Офицер: " .. esoExtractNick(cleanMsg))
    end

    ---------------- [SEARCH] ЗВУКИ SEARCH ----------------
    if lowMsg:find("обыск") and isMyAction then
        if #searchSounds > 0 then
            local randomSearchClick = searchSounds[math.random(1, #searchSounds)]
            if randomSearchClick then setAudioStreamState(randomSearchClick, ev.PLAY) end
        end
        officerAddEvent("Произведён осмотр | Офицер: " .. esoExtractNick(cleanMsg))
    end	
	
    ---------------- [SITREP] ЗВУКИ ПРИ СИТУАЦИЯХ ----------------
    if lowMsg:find("%[r%]") or lowMsg:find("%[f%]") or (lowMsg:find("розыск") and lowMsg:find("SOS")) then
        if os.clock() - cooldownSitrep > 3 then
            

            -- КОД 0 — критическая
            if lowMsg:find("код 0") or lowMsg:find("code 0") or lowMsg:find("офицер ранен") or lowMsg:find("код ноль") or lowMsg:find("c'0") or lowMsg:find("SOS") then
                if sitrepCodeZero then 
                    setAudioStreamState(sitrepCodeZero, ev.PLAY) 
                    cooldownSitrep = os.clock()
                end
                sirepAlert = 3
                sirepAlertText = "CODE 0 OFFICER IN DANGER"
                sirepAlertTime = os.clock()
                officerAddEvent("Объявлен код 0 - офицер в опасности | Инициатор: " .. esoExtractNick(cleanMsg))

            -- похищение / теракт
            elseif lowMsg:find("похищ") or lowMsg:find("захват") or lowMsg:find("заложник") or lowMsg:find("теракт") or lowMsg:find("hostage") or lowMsg:find("kidnap") then
                if sitrepCodeZero then 
                    setAudioStreamState(sitrepCodeZero, ev.PLAY) 
                    cooldownSitrep = os.clock()
                end               
			   sirepAlert = 4
                sirepAlertText = "HIGH RISK SITUATION"
                sirepAlertTime = os.clock()
                officerAddEvent("Объявлен код 0 - заложник/похищение/теракт | Инициатор: " .. esoExtractNick(cleanMsg))

            -- КОД 1 — опасная
            elseif lowMsg:find("код 1") or lowMsg:find("code 1") or lowMsg:find("стрельба") or lowMsg:find("перестрелка") or lowMsg:find("открыт огонь") or lowMsg:find("c'1") then
				if #sitrepCodeOne > 0 then
					local randomSitrepCodeOne = sitrepCodeOne[math.random(1, #sitrepCodeOne)]
					if randomSitrepCodeOne then setAudioStreamState(randomSitrepCodeOne, ev.PLAY) end
					cooldownSitrep = os.clock()
				end
                sirepAlert = 2
                sirepAlertText = "CODE 1 URGENT RESPONSE"
                sirepAlertTime = os.clock()
                officerAddEvent("Объявлен код 1 - срочный выезд | Инициатор: " .. esoExtractNick(cleanMsg))

            -- КОД 3 — стандартная
            elseif lowMsg:find("код 3") or lowMsg:find("code 3") or lowMsg:find("коду 3") or lowMsg:find("погоня") or lowMsg:find("ограбление") or lowMsg:find("10-66") or lowMsg:find("'66") or lowMsg:find("c'3") or lowMsg:find("10-55") or lowMsg:find("'55") or lowMsg:find("'57") or lowMsg:find("'57") then
				if #sitrepCodeThree > 0 then
					local randomSitrepCodeThree = sitrepCodeThree[math.random(1, #sitrepCodeThree)]
					if randomSitrepCodeThree then setAudioStreamState(randomSitrepCodeThree, ev.PLAY) end
					cooldownSitrep = os.clock()
				end				
                sirepAlert = 1
                sirepAlertText = "CODE 3 EMERGENCY RESPONSE"
                sirepAlertTime = os.clock()
                officerAddEvent("Объявлен код 3 - ситуация на смене | Инициатор: " .. esoExtractNick(cleanMsg))
            end
            
        end
    end

    -- ---------------- ОЗВУЧКА МЕГАФОНА ----------------
    if msg:find("<<%s(.+)%s(.+)%[%d+%]:(.+)%s>>") then
        local rangMeg, nicknameMeg, idMeg, contentMeg = msg:match("<<%s(.+)%s(.+)%[(%d+)%]:(.+)%s>>")
        
        nicknameMeg = nicknameMeg:gsub(' ', '_')
        
        if nicknameMeg == playerNickname then
            local content = string.nlower(contentMeg)

            if os.clock() - cooldownMeg > 4 then
                
                for _, context in ipairs(megaphoneContexts) do
                    local matchA = false
                    local matchB = false
                    
                    for _, wordA in ipairs(context.groupA) do
                        if content:find(string.nlower(wordA)) then
                            matchA = true
                            break
                        end
                    end
                    
                    for _, wordB in ipairs(context.groupB) do
                        if content:find(string.nlower(wordB)) then
                            matchB = true
                            break
                        end
                    end
                    
                    if matchA and matchB then
                        if context.audio then 
                            setAudioStreamState(context.audio, ev.PLAY) 
                        end
                        
                        cooldownMeg = os.clock()
                        break
                    end
                end
                
            end
        end
    end
    return {color, msg}
end

-- ==================== VSign (Callsign) ====================

function setLocalVehicleCallsign(text)
    lua_thread.create(function()
        if not isCharInAnyCar(PLAYER_PED) then
            sampAddChatMessage("[ESO] Вы должны находиться внутри автомобиля.", -1)
            return
        end

        local currentCar = storeCarCharIsInNoSave(PLAYER_PED)
        local result, sampVehicleId = sampGetVehicleIdByCarHandle(currentCar)

        if result and sampVehicleId ~= -1 then
            local cleanText = text:upper():gsub("\\n", "\n")

            userOverriddenCallsigns[sampVehicleId] = true

            createLocalCallsign(sampVehicleId, cleanText)

            if sync and sync.isEnabled() then
                sync.pushCallsign(sampVehicleId, cleanText)
            else
                -- сервера синхронизации нет: старый способ через /n
                sampSendChat("/n #VSIGN# " .. sampVehicleId .. " | " .. cleanText)
            end
            
        else
            sampAddChatMessage("[ESO] Транспорт не существует.", -1)
        end
    end)
end

function createLocalCallsign(sampVehicleId, text)

    vehicleSignRegistry[sampVehicleId] = text

    local finalString = "{D3D3D3}" .. text

    if activeCallsigns[sampVehicleId] then
        if activeCallsigns[sampVehicleId].textId then
            sampDelete3dText(activeCallsigns[sampVehicleId].textId)
        end
        activeCallsigns[sampVehicleId] = nil
    end

    local textId = sampCreate3dTextEx(
        sampVehicleId,     
        finalString,
        0xFFFFFFFF,        
        -0.90, -2.40, 0.55, 
        15.0,
        false,
        -1,                
        sampVehicleId      
    )

    if textId then
        activeCallsigns[sampVehicleId] = {
            textId = textId,
            string = text
        }
    end
end

-- ==================== ОБЛАЧНАЯ СИНХРОНИЗАЦИЯ: КАЛЛСИГНЫ ====================
function esoSyncApplyCallsigns(changes)
    for _, ch in ipairs(changes) do
        local veh = ch.veh
        if veh and veh >= 0 and veh <= 1999 then
            if ch.text then
                local active = activeCallsigns[veh]
                if vehicleSignRegistry[veh] ~= ch.text or not (active and active.textId) then
                    createLocalCallsign(veh, ch.text)
                end
            else
                local active = activeCallsigns[veh]
                if active and active.textId then sampDelete3dText(active.textId) end
                activeCallsigns[veh] = nil
                vehicleSignRegistry[veh] = nil
            end
        end
    end
end

local esoSyncWasOffline = false
function esoSyncOnStatus(code, detail)
    if code == "online" then
        if ESOAuto and ESOAuto.start then ESOAuto.start("online") end
        if esoSyncWasOffline then
            sampAddChatMessage("[ESO] Связь с сервером синхронизации восстановлена.", 0x7EC8E3)
        else
            sampAddChatMessage("[ESO] Облачная синхронизация подключена.", 0x7EC8E3)
        end
        esoSyncWasOffline = false
    elseif code == "offline" then
        esoSyncWasOffline = true
        sampAddChatMessage("[ESO] Сервер синхронизации недоступен.", 0xFF6A00)
    elseif code == "nolibs" then
        sampAddChatMessage("[ESO] Синхронизация отключена: не найдены библиотеки effil или requests.", 0xFF6A00)
    elseif code == "update_required" then
        sampAddChatMessage("[ESO] Синхронизация отключена: версия скрипта устарела, обновитесь.", 0xFF6A00)
    elseif code == "banned" then
        sampAddChatMessage("[ESO] Синхронизация отключена для этой установки.", 0xFF6A00)
    elseif code == "rejected" then
        sampAddChatMessage("[ESO] Сервер отклонил данные: " .. tostring(detail), 0xFF6A00)
    elseif code == "motd" and detail and detail ~= "" then
        sampAddChatMessage("[ESO] " .. detail, 0x7EC8E3)
    end
end

-- ==================== ИМХУИ ====================

-- ==================== МАРКИРОВКИ ====================

local UNIT_TYPES = {
    A = "ADAM", M = "MARY", H = "HENRY", L = "LINCOLN", U = "UTILITY"
}

local DEPT_NAMES = {
    ["1"] = "LS", ["2"] = "SF", ["3"] = "LV"
}

local DEPT_STYLES = {
    -- LS
    ["1"] = { bg = imgui.ImVec4(0.10, 0.22, 0.40, 0.88), fg = imgui.ImVec4(0.72, 0.88, 1.00, 1.0) },
    -- SF
    ["2"] = { bg = imgui.ImVec4(0.08, 0.28, 0.18, 0.88), fg = imgui.ImVec4(0.70, 1.00, 0.80, 1.0) },
    -- LV
    ["3"] = { bg = imgui.ImVec4(0.30, 0.24, 0.05, 0.88), fg = imgui.ImVec4(1.00, 0.92, 0.60, 1.0) },
}
local SPEC_STYLE    = { bg = imgui.ImVec4(0.20, 0.14, 0.35, 0.88), fg = imgui.ImVec4(0.88, 0.80, 1.00, 1.0) }
local DEFAULT_STYLE = { bg = imgui.ImVec4(0.14, 0.15, 0.17, 0.75), fg = imgui.ImVec4(0.70, 0.72, 0.75, 1.0) }

local SPECIAL_UNITS = {
    SKYHAWK  = true,
    TACTICAL = true,
    SPECIAL  = true,
}

local function parseCallsign(cs)
    if not cs or cs == "" then return nil end
    local upper = cs:upper()

    for prefix, _ in pairs(SPECIAL_UNITS) do
        if upper:find("^" .. prefix) then
            return { style = SPEC_STYLE, label = upper }
        end
    end

    local dept = upper:match("^([123])[AMHLUS]%d+")
    if dept then
        local style = DEPT_STYLES[dept] or DEFAULT_STYLE
        return { style = style, label = cs }
    end

    return { style = DEFAULT_STYLE, label = upper }
end

local function getCurrentVehicleCallsign()
    if not isCharInAnyCar(PLAYER_PED) then return nil end
    local veh = storeCarCharIsInNoSave(PLAYER_PED)
    local ok, sampVehId = sampGetVehicleIdByCarHandle(veh)
    if not ok or sampVehId == -1 then return nil end
    if vehicleSignRegistry[sampVehId] then
        return vehicleSignRegistry[sampVehId]
    end
    if DEFAULT_CALLSIGNS[sampVehId] then
        return DEFAULT_CALLSIGNS[sampVehId]
    end
    return nil
end

imgui.OnInitialize(function()
    local io = imgui.GetIO()
    local config = imgui.ImFontConfig()
    config.GlyphRanges = io.Fonts:GetGlyphRangesCyrillic() 
    myHudFont = io.Fonts:AddFontFromFileTTF("C:\\Windows\\Fonts\\Arial.ttf", 13.0, config)
end)

local function renderCondition()
    return showSirenPanel or panelAlpha > 0.0
end

local function renderTextCentered(text, color)
    local windowWidth = imgui.GetWindowSize().x
    local textWidth = imgui.CalcTextSize(text).x
    imgui.SetCursorPosX((windowWidth - textWidth) * 0.5)
    imgui.TextColored(color, text)
end

local sirenUI = imgui.OnFrame(renderCondition, function()
    if myHudFont == nil then return end
    
    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, panelAlpha)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 8.0)    
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(10, 10)) 
    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.07, 0.07, 0.09, 0.90)) 

    imgui.SetNextWindowPos(imgui.ImVec2(60, 380), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowSize(imgui.ImVec2(260, 200), imgui.Cond.Always)

    local windowFlags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse -- + imgui.WindowFlags.NoMove 
    
    if imgui.Begin("Siren Control Unit", nil, windowFlags) then
        imgui.PushFont(myHudFont)

        local scuPos = imgui.GetWindowPos()
        local scuSize = imgui.GetWindowSize()
        scuWindowPosX  = scuPos.x
        scuWindowPosY  = scuPos.y
        scuWindowWidth = scuSize.x

        if isPassengerMode then
            renderTextCentered("FEDERAL SIGNAL AMPLIFIER", imgui.ImVec4(0.45, 0.47, 0.52, 1.0))
        else
            renderTextCentered("FEDERAL SIGNAL AMPLIFIER", imgui.ImVec4(0.55, 0.57, 0.60, 1.0))
        end
        imgui.Separator()
        imgui.Spacing()

        local btnSize = imgui.ImVec2(55, 24)
        
        if sirenMode == 0 then
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.10, 0.60, 0.10, 0.80))
            imgui.Button("STBY", btnSize)
            imgui.PopStyleColor(1)
        else
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.15, 0.15, 0.17, 0.40))
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.40, 0.40, 0.42, 0.60))
            imgui.Button("STBY", btnSize)
            imgui.PopStyleColor(2)
        end
        imgui.SameLine()

        if sirenMode == 1 then
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.85, 0.45, 0.0, 0.85))
            imgui.Button("RAD", btnSize)
            imgui.PopStyleColor(1)
        else
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.15, 0.15, 0.17, 0.40))
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.40, 0.40, 0.42, 0.60))
            imgui.Button("RAD", btnSize)
            imgui.PopStyleColor(2)
        end
        imgui.SameLine()

        if sirenMode == 2 then
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.75, 0.10, 0.10, 0.90))
            imgui.Button("MAN", btnSize)
            imgui.PopStyleColor(1)
        else
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.15, 0.15, 0.17, 0.40))
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.40, 0.40, 0.42, 0.60))
            imgui.Button("MAN", btnSize)
            imgui.PopStyleColor(2)
        end
        imgui.SameLine()

        if isHornActive then
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.10, 0.40, 0.85, 0.90))
            imgui.Button("HORN", btnSize)
            imgui.PopStyleColor(1)
        else
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.15, 0.15, 0.17, 0.40))
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.40, 0.40, 0.42, 0.60))
            imgui.Button("HORN", btnSize)
            imgui.PopStyleColor(2)
        end

        imgui.Spacing()
        imgui.Separator()
        
        if isCharInAnyCar(PLAYER_PED) then
            local veh = storeCarCharIsInNoSave(PLAYER_PED)
            local health = getCarHealth(veh)
            
            local pulseAlpha = 0.52 + math.sin(os.clock() * 6.5) * 0.38
            local blinkDiscrete = math.floor(os.clock() * 3) % 2 == 0

            local voltageNum = 11.0 + (health / 1000) * 3.2
            if voltageNum > 14.2 then voltageNum = 14.2 end
            local voltage = string.format("%.1f", voltageNum)
            local engineTemp = math.floor(82 + (math.sin(os.clock() / 10) * 3) + (sirenMode == 2 and 5 or 0) + (health < 400 and 25 or 0))

            imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), "SYS VOLTS:")
            imgui.SameLine()
            if voltageNum < 12.5 then
                if blinkDiscrete then 
                    imgui.TextColored(imgui.ImVec4(1.0, 0.2, 0.2, pulseAlpha), voltage .. " V")
                else 
                    imgui.TextColored(imgui.ImVec4(1.0, 0.5, 0.0, pulseAlpha), "VLT LOW")
                end
            else
                imgui.Text(voltage .. " V")
            end
            
            imgui.SameLine(140)
            imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), "ENG TEMP:")
            imgui.SameLine()
            if engineTemp > 100 then
                imgui.TextColored(imgui.ImVec4(1.0, 0.1, 0.1, pulseAlpha), engineTemp .. " C !")
            else
                imgui.Text(engineTemp .. " C")
            end

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            
            if health > 700 then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.10, 0.50, 0.10, 0.70)) 
                imgui.Button("ENG", btnSize)
            elseif health > 400 then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.75, 0.40, 0.0, 0.75))  
                imgui.Button("ENG", btnSize)
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.75, 0.10, 0.10, pulseAlpha)) 
                imgui.Button("ENG", btnSize)
            end
            imgui.PopStyleColor(1)
            imgui.SameLine()

            if voltageNum >= 13.5 then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.10, 0.50, 0.10, 0.70)) 
                imgui.Button("ELC", btnSize)
            elseif voltageNum >= 12.5 then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.75, 0.40, 0.0, 0.75))  
                imgui.Button("ELC", btnSize)
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.75, 0.10, 0.10, pulseAlpha)) 
                imgui.Button("ELC", btnSize)
            end
            imgui.PopStyleColor(1)
            imgui.SameLine()

            if health > 850 then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.10, 0.50, 0.10, 0.70)) 
                imgui.Button("BDY", btnSize)
            elseif health > 550 then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.75, 0.40, 0.0, 0.75))  
                imgui.Button("BDY", btnSize)
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.75, 0.10, 0.10, 0.90))  
                imgui.Button("BDY", btnSize)
            end
            imgui.PopStyleColor(1)
            imgui.SameLine()

            local isTirePunctured = isCarTireBurst(veh, 0) or isCarTireBurst(veh, 1) or isCarTireBurst(veh, 2) or isCarTireBurst(veh, 3)
            
            if not isTirePunctured then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.10, 0.50, 0.10, 0.70)) 
                imgui.Button("TRS", btnSize)
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.75, 0.10, 0.10, pulseAlpha)) 
                imgui.Button("TRS", btnSize)
            end
            imgui.PopStyleColor(1)
        end

        -- ==================== Маркировка юнита ====================
        do
            local cs = getCurrentVehicleCallsign()
            local parsed = cs and parseCallsign(cs)
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.40, 0.42, 0.45, 1.0), "UNIT CALLSIGN:")
            imgui.SameLine()
            if parsed then
                local dl   = imgui.GetWindowDrawList()
                local p    = imgui.GetCursorScreenPos()
                local tw   = imgui.CalcTextSize(parsed.label).x
                local pad  = imgui.ImVec2(6, 3)
                dl:AddRectFilled(
                    imgui.ImVec2(p.x - pad.x, p.y - pad.y),
                    imgui.ImVec2(p.x + tw + pad.x, p.y + 13 + pad.y),
                    imgui.ColorConvertFloat4ToU32(parsed.style.bg),
                    3.0
                )
                imgui.TextColored(parsed.style.fg, parsed.label)
            else
                imgui.TextColored(imgui.ImVec4(0.28, 0.30, 0.33, 1.0), "---")
            end
        end

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        local elapsed = os.clock() - sirepAlertTime
        if sirepAlert > 0 and elapsed < SIREP_DISPLAY_DURATION then
            local fade = 1.0
            if elapsed > SIREP_DISPLAY_DURATION - 3 then
                fade = (SIREP_DISPLAY_DURATION - elapsed) / 3
            end

            local alertColor
            local doBlink = false
            if sirepAlert == 5 then
                -- 911 CALL: cyan, blinking
                alertColor = imgui.ImVec4(0.05, 0.85, 1.0, fade)
                doBlink = true
            elseif sirepAlert == 4 then
                -- ТЕРАКТ\ПОХИЩЕНИЕ: пурпурный, мигает
                alertColor = imgui.ImVec4(0.85, 0.10, 0.85, fade)
                doBlink = true
            elseif sirepAlert == 3 then
                -- КОД 0: красный, мигает
                alertColor = imgui.ImVec4(1.0, 0.10, 0.10, fade)
                doBlink = true
            elseif sirepAlert == 2 then
                -- КОД 1: оранжевый
                alertColor = imgui.ImVec4(1.0, 0.50, 0.05, fade)
            elseif sirepAlert == 6 then
                -- ОГРАБЛЕНИЕ/УГОН: жёлтый
                alertColor = imgui.ImVec4(1.0, 0.90, 0.05, fade)
                doBlink = true
            else
                -- КОД 3: зелёный
                alertColor = imgui.ImVec4(0.20, 0.85, 0.20, fade)
            end

            local blinkVisible = true
            if doBlink then
                blinkVisible = (math.floor(os.clock() * 2) % 2 == 0)
            end

            if blinkVisible then
                local drawList = imgui.GetWindowDrawList()
                local p = imgui.GetCursorScreenPos()
                local w = imgui.GetContentRegionAvail().x
                local bgAlpha = (sirepAlert >= 3) and (0.18 * fade) or (0.10 * fade)
                drawList:AddRectFilled(
                    imgui.ImVec2(p.x - 4, p.y - 2),
                    imgui.ImVec2(p.x + w + 4, p.y + 18),
                    imgui.ColorConvertFloat4ToU32(imgui.ImVec4(alertColor.x, alertColor.y, alertColor.z, bgAlpha)),
                    3.0
                )
                renderTextCentered(sirepAlertText, alertColor)
            else
                imgui.Spacing()
            end
        else
            if sirepAlert > 0 and elapsed >= SIREP_DISPLAY_DURATION then
                sirepAlert = 0 
            end
            renderTextCentered("--  NO ACTIVE SITUATION  --", imgui.ImVec4(0.25, 0.25, 0.28, 1.0))
        end

        imgui.PopFont()
        imgui.End()
    end
    
    imgui.PopStyleColor(1)
    imgui.PopStyleVar(3)
end)

sirenUI.LockPlayer = false 
sirenUI.HideCursor = true

-- =============================== Борткомпьютер ===========================================

local mdcSampVehpoolPtr = 0

local mdcVehpoolOffsets = {0x26EEC8, 0x26E888, 0x26E6E0}  -- R5, R3, R1

local function mdcGetVehpoolPtr()
    if mdcSampVehpoolPtr ~= 0 then return mdcSampVehpoolPtr end
    local base = sampGetBase()
    if not base or base == 0 then return 0 end
    for _, off in ipairs(mdcVehpoolOffsets) do
        local ptr = readMemory(base + off, 4, false)
        if ptr and ptr ~= 0 then
            mdcSampVehpoolPtr = ptr
            return ptr
        end
    end
    return 0
end

local function mdcGetPlate(sampId)
    if sampId < 0 or sampId > 1999 then return nil end
    local pool = mdcGetVehpoolPtr()
    if pool == 0 then return nil end
    local objPtr = mem.getint32(pool + 0x1134 + sampId * 4, false)
    if not objPtr or objPtr == 0 then return nil end
    local plate = mem.tostring(objPtr + 0x93, 32, false)
    if plate and #plate > 0 then
        return plate:upper()
    end
    return nil
end

local mdcPoliceModels = {
    [416]=true, [427]=true, [490]=true, [523]=true,
    [528]=true, [596]=true, [597]=true, [598]=true,
    [599]=true, [601]=true,
}

-- ==================== Борткомпьютер: данные ====================

local mdcActive       = false
local mdcData         = nil
local mdcShowWindow   = false
local mdcWindowAlpha  = 0.0
local mdcScanCooldown = 0
local mdcIsAllyUnit   = false
local mdcWindowExpiry = 0
local mdcHistory      = {}
local mdcQuickMode    = false

scuWindowPosX  = 60
scuWindowPosY  = 380
scuWindowWidth = 260

local vehicleColorNames = {
    [0]  = "BLACK",       [1]  = "GARCIA BLUE",  [2]  = "MIDNIGHT BLUE",
    [3]  = "MIDNIGHT BLUE",[4] = "DARK NAVY",    [5]  = "MAROON",
    [6]  = "DARK RED",    [7]  = "DARK RED",     [8]  = "DARK RED",
    [9]  = "DARK RED",    [10] = "RED",          [11] = "RED",
    [12] = "LIGHT RED",   [13] = "PINK",         [14] = "PINK",
    [15] = "LIGHT PINK",  [16] = "DARK YELLOW",  [17] = "CREAM",
    [18] = "DARK YELLOW", [19] = "TAN",          [20] = "LIGHT TAN",
    [21] = "DARK SAND",   [22] = "LIGHT TAN",    [23] = "BEIGE",
    [24] = "OLIVE",       [25] = "DARK OLIVE",   [26] = "OLIVE GREEN",
    [27] = "DARK GREEN",  [28] = "DARK GREEN",   [29] = "DARK GREEN",
    [30] = "DARK GREEN",  [31] = "DARK GREEN",   [32] = "GREEN",
    [33] = "GREEN",       [34] = "GREEN",        [35] = "GREEN",
    [36] = "GREEN",       [37] = "LIGHT GREEN",  [38] = "SEAFOAM",
    [39] = "SEAFOAM",     [40] = "TEAL",         [41] = "TEAL",
    [42] = "DARK TEAL",   [43] = "TURQUOISE",    [44] = "DARK BLUE",
    [45] = "DARK BLUE",   [46] = "DARK BLUE",    [47] = "DARK BLUE",
    [48] = "DARK BLUE",   [49] = "DARK BLUE",    [50] = "BLUE",
    [51] = "BLUE",        [52] = "POLICE BLUE",  [53] = "LIGHT BLUE",
    [54] = "LIGHT BLUE",  [55] = "LIGHT BLUE",   [56] = "LIGHT BLUE",
    [57] = "ROYAL BLUE",  [58] = "PURPLE",       [59] = "PURPLE",
    [60] = "PURPLE",      [61] = "DARK PURPLE",  [62] = "LILAC",
    [63] = "DARK PURPLE", [64] = "LIGHT PURPLE", [65] = "LIGHT PINK",
    [66] = "DARK BROWN",  [67] = "BROWN",        [68] = "BROWN",
    [69] = "DARK BROWN",  [70] = "BROWN",        [71] = "LIGHT BROWN",
    [72] = "LIGHT BROWN", [73] = "LIGHT TAN",    [74] = "CREAM",
    [75] = "GRAY",        [76] = "GRAY",         [77] = "GRAY",
    [78] = "GRAY",        [79] = "LIGHT GRAY",   [80] = "LIGHT GRAY",
    [81] = "LIGHT GRAY",  [82] = "WHITE",        [83] = "WHITE",
    [84] = "LIGHT GRAY",  [85] = "DARK GRAY",    [86] = "DARK GRAY",
    [87] = "DARK GRAY",   [88] = "DARK GRAY",    [89] = "DARK GRAY",
    [90] = "DARK GRAY",   [91] = "DARK GRAY",    [92] = "DARK GRAY",
    [93] = "ORANGE",      [94] = "ORANGE",       [95] = "LIGHT ORANGE",
    [96] = "BRIGHT ORANGE",[97]= "YELLOW",       [98] = "YELLOW",
    [99] = "YELLOW",      [100]= "YELLOW",       [101]= "LIGHT YELLOW",
    [102]= "METALLIC GRAY",[103]="METALLIC GRAY",[104]="METALLIC GRAY",
    [105]= "METALLIC BLUE",[106]="METALLIC BLUE",[107]="METALLIC BLUE",
    [108]= "SILVER",      [109]= "SILVER",       [110]= "METALLIC BLUE",
    [111]= "METALLIC BLUE",[112]="METALLIC BLUE",[113]="METALLIC BLUE",
    [114]= "MIDNIGHT BLUE",[115]="POLICE BLUE",  [116]="NIGHT BLUE",
    [117]= "DARK BLUE",   [118]= "METALLIC TEAL",[119]="METALLIC TEAL",
    [120]= "METALLIC TEAL",[121]="DARK GREEN",   [122]="DARK GREEN",
    [123]= "METALLIC GREEN",[124]="ARMY GREEN",  [125]="ARMY GREEN",
    [126]= "ARMY GREEN",  [127]= "LIGHT OLIVE",
}

local function mdcGetColorName(colorId)
    return vehicleColorNames[colorId] or ("CLR#" .. tostring(colorId))
end

-- ==================== Борткомпьютер: скан ====================

local function mdcScanVehicleUnderCursor()

    if os.clock() - mdcScanCooldown < 0.5 then return end
    mdcScanCooldown = os.clock()

    local cx, cy, cz = getActiveCameraCoordinates()

    local lx, ly, lz = getActiveCameraPointAt()
    local fwdX = lx - cx
    local fwdY = ly - cy
    local fwdZ = lz - cz
    local fwdLen = math.sqrt(fwdX*fwdX + fwdY*fwdY + fwdZ*fwdZ)
    if fwdLen < 0.001 then return end
    fwdX = fwdX / fwdLen
    fwdY = fwdY / fwdLen
    fwdZ = fwdZ / fwdLen

    local scrW, scrH = getScreenResolution()
    local mx, my = getCursorPos()
    if not mx then
        mx = scrW * 0.5
        my = scrH * 0.5
    end

    local fovDeg = 70.0
    local fovRaw = readMemory(0xB6F03C, 4, false)
    local fov_val = representIntAsFloat(fovRaw)
    if fov_val and fov_val > 1.0 and fov_val < 179.0 then
        fovDeg = fov_val
    end
    local fovRad = math.rad(fovDeg) * 0.5
    local aspect = scrW / scrH

    local ndcX =  (mx / scrW) * 2.0 - 1.0
    local ndcY = -(  (my / scrH) * 2.0 - 1.0)

    local tanV = math.tan(fovRad)
    local tanH = tanV * aspect

    local rightX =  fwdY
    local rightY = -fwdX
    local rightZ =  0.0
    local rightLen = math.sqrt(rightX*rightX + rightY*rightY)
    if rightLen < 0.001 then
        rightX = 1.0; rightY = 0.0; rightZ = 0.0
    else
        rightX = rightX / rightLen
        rightY = rightY / rightLen
    end

    local upX = rightY * fwdZ - rightZ * fwdY
    local upY = rightZ * fwdX - rightX * fwdZ
    local upZ = rightX * fwdY - rightY * fwdX

    local rayX = fwdX + rightX * ndcX * tanH + upX * ndcY * tanV
    local rayY = fwdY + rightY * ndcX * tanH + upY * ndcY * tanV
    local rayZ = fwdZ + rightZ * ndcX * tanH + upZ * ndcY * tanV
    local rayLen = math.sqrt(rayX*rayX + rayY*rayY + rayZ*rayZ)
    if rayLen < 0.001 then return end
    rayX = rayX / rayLen
    rayY = rayY / rayLen
    rayZ = rayZ / rayLen

    local playerCar = isCharInAnyCar(PLAYER_PED) and storeCarCharIsInNoSave(PLAYER_PED) or nil
    local bestVeh  = nil
    local bestDist = 9999.0

    for sampId = 0, 1999 do
        local ok, carHandle = sampGetCarHandleBySampVehicleId(sampId)
        if ok and carHandle and carHandle ~= 0 and carHandle ~= playerCar
            and doesVehicleExist(carHandle)
        then
            local vx, vy, vz = getCarCoordinates(carHandle)
            local dx = vx - cx
            local dy = vy - cy
            local dz = vz - cz
            local dot = dx*rayX + dy*rayY + dz*rayZ
            if dot > 0 then
                local perpX = dx - dot*rayX
                local perpY = dy - dot*rayY
                local perpZ = dz - dot*rayZ
                local perpDist = math.sqrt(perpX*perpX + perpY*perpY + perpZ*perpZ)
                local camDist  = math.sqrt(dx*dx + dy*dy + dz*dz)
                if perpDist < 4.0 and camDist < 65.0 and camDist < bestDist then
                    bestDist = camDist
                    bestVeh  = carHandle
                end
            end
        end
    end

    if bestVeh == nil then
        mdcData       = nil
        mdcShowWindow = false
        mdcIsAllyUnit = false
        return
    end

    local modelId = getCarModel(bestVeh)

    local modelName = getNameOfVehicleModel(modelId) or ("ID_" .. modelId)

    local speedMs  = getCarSpeed(bestVeh) or 0.0
    local speedKph = math.floor(speedMs * 3.6 + 0.5)

    local col1, col2 = 0, 0
    if bestVeh and bestVeh ~= 0 then
        col1, col2 = getCarColours(bestVeh)
        col1 = col1 or 0
        col2 = col2 or 0
    end
    local colorStr = mdcGetColorName(col1)
    if col2 ~= col1 then
        colorStr = colorStr .. " / " .. mdcGetColorName(col2)
    end

    local sampVehId = -1
    local idok, svid = sampGetVehicleIdByCarHandle(bestVeh)
    if idok and svid and svid >= 0 then
        sampVehId = svid
    end

    local plateTxt = "N/A"
    local hasPlate = false
    if sampVehId >= 0 then
        local mid = string.format("%02d%02d", modelId % 100, sampVehId % 100)
        local letters = "ABCDEFGHJKLMNPRSTUVWXYZ"
        local sfxA = letters:sub((modelId % #letters) + 1, (modelId % #letters) + 1)
        local sfxB = letters:sub((sampVehId % #letters) + 1, (sampVehId % #letters) + 1)
        plateTxt = "SA" .. mid .. sfxA .. sfxB
        hasPlate = true
    end

    local driverName   = "NO DRIVER"
    local driverSampId = -1
    local driverPed = getDriverOfCar(bestVeh)
    if driverPed and driverPed ~= 0 then
        local dok, dpid = sampGetPlayerIdByCharHandle(driverPed)
        if dok and dpid and dpid >= 0 then
            driverSampId = dpid
            driverName   = sampGetPlayerNickname(dpid) or "UNKNOWN"
        end
    end

    local px0, py0, pz0 = getCharCoordinates(PLAYER_PED)
    local vx0, vy0, vz0 = getCarCoordinates(bestVeh)
    local scanDist = math.floor(math.sqrt((vx0-px0)^2 + (vy0-py0)^2 + (vz0-pz0)^2))

    local callsignStr = nil
    local isAlly      = false

    if sampVehId >= 0 then
        if vehicleSignRegistry[sampVehId] then
            callsignStr = vehicleSignRegistry[sampVehId]
            isAlly = true
        elseif activeCallsigns[sampVehId] then
            callsignStr = activeCallsigns[sampVehId].string
            isAlly = true
        end
    end

    if mdcPoliceModels[modelId] then
        isAlly = true
    end

    if soundRadioClickOn then
        setAudioStreamState(soundRadioClickOn, ev.PLAY)
    else
        if radioClicks and #radioClicks > 0 then
            setAudioStreamState(radioClicks[1], ev.PLAY)
        end
    end

    local parsedCS = callsignStr and parseCallsign(callsignStr) or nil

    if mdcData then
        table.insert(mdcHistory, 1, mdcData)
        if #mdcHistory > 3 then table.remove(mdcHistory) end
    end

    mdcData = {
        modelName      = modelName,
        modelId        = modelId,
        sampVehId      = sampVehId,
        targetVeh      = bestVeh,
        plate          = plateTxt,
        hasPlate       = hasPlate,
        color          = colorStr,
        speedKph       = speedKph,
        callsign       = callsignStr,
        parsedCallsign = parsedCS,
        isAlly         = isAlly,
        driverName     = driverName,
        driverSampId   = driverSampId,
        scanDist       = scanDist,
        timestamp      = os.clock(),
    }
    mdcIsAllyUnit = isAlly
    mdcShowWindow = true
    mdcWindowExpiry = os.clock() + 25
end

-- ==================== Борткомпьютер: быстрый скан ====================

local function mdcScanVehicleAhead()
    if os.clock() - mdcScanCooldown < 0.5 then return end
    mdcScanCooldown = os.clock()

    if not isCharInAnyCar(PLAYER_PED) then return end
    local playerCar = storeCarCharIsInNoSave(PLAYER_PED)

    local cx, cy, cz = getCarCoordinates(playerCar)
    local heading = math.rad(getCarHeading(playerCar))

    local fwdX = -math.sin(heading)
    local fwdY =  math.cos(heading)

    local bestVeh  = nil
    local bestDist = 9999.0

    for sampId = 0, 1999 do
        local ok, carHandle = sampGetCarHandleBySampVehicleId(sampId)
        if ok and carHandle and carHandle ~= 0 and carHandle ~= playerCar
            and doesVehicleExist(carHandle)
        then
            local vx, vy, vz = getCarCoordinates(carHandle)
            local dx = vx - cx
            local dy = vy - cy
            local dz = vz - cz
            local dot = dx*fwdX + dy*fwdY
            if dot > 0 then
                local perpX    = dx - dot*fwdX
                local perpY    = dy - dot*fwdY
                local perpDist = math.sqrt(perpX*perpX + perpY*perpY)
                local camDist  = math.sqrt(dx*dx + dy*dy + dz*dz)
                if perpDist < 6.0 and camDist < 80.0 and camDist < bestDist then
                    bestDist = camDist
                    bestVeh  = carHandle
                end
            end
        end
    end

    if bestVeh == nil then
        mdcData       = nil
        mdcShowWindow = false
        mdcIsAllyUnit = false
        return
    end

    local modelId   = getCarModel(bestVeh)
    local modelName = getNameOfVehicleModel(modelId) or ("ID_" .. modelId)
    local speedMs   = getCarSpeed(bestVeh) or 0.0
    local speedKph  = math.floor(speedMs * 3.6 + 0.5)

    local col1, col2 = getCarColours(bestVeh)
    col1 = col1 or 0; col2 = col2 or 0
    local colorStr = mdcGetColorName(col1)
    if col2 ~= col1 then colorStr = colorStr .. " / " .. mdcGetColorName(col2) end

    local sampVehId = -1
    local idok, svid = sampGetVehicleIdByCarHandle(bestVeh)
    if idok and svid and svid >= 0 then sampVehId = svid end

    local plateTxt = "N/A"
    local hasPlate = false
    if sampVehId >= 0 then
        local mid = string.format("%02d%02d", modelId % 100, sampVehId % 100)
        local letters = "ABCDEFGHJKLMNPRSTUVWXYZ"
        local sfxA = letters:sub((modelId % #letters) + 1, (modelId % #letters) + 1)
        local sfxB = letters:sub((sampVehId % #letters) + 1, (sampVehId % #letters) + 1)
        plateTxt = "SA" .. mid .. sfxA .. sfxB
        hasPlate = true
    end

    local driverName   = "NO DRIVER"
    local driverSampId = -1
    local driverPed = getDriverOfCar(bestVeh)
    if driverPed and driverPed ~= 0 then
        local dok, dpid = sampGetPlayerIdByCharHandle(driverPed)
        if dok and dpid and dpid >= 0 then
            driverSampId = dpid
            driverName   = sampGetPlayerNickname(dpid) or "UNKNOWN"
        end
    end

    local px0, py0, pz0 = getCharCoordinates(PLAYER_PED)
    local vx0, vy0, vz0 = getCarCoordinates(bestVeh)
    local scanDist = math.floor(math.sqrt((vx0-px0)^2+(vy0-py0)^2+(vz0-pz0)^2))

    local callsignStr = nil
    local isAlly      = false
    if sampVehId >= 0 then
        if vehicleSignRegistry[sampVehId] then
            callsignStr = vehicleSignRegistry[sampVehId]; isAlly = true
        elseif activeCallsigns[sampVehId] then
            callsignStr = activeCallsigns[sampVehId].string; isAlly = true
        end
    end
    if mdcPoliceModels[modelId] then isAlly = true end

    if radioClicks and #radioClicks > 0 then
        setAudioStreamState(radioClicks[1], ev.PLAY)
    end

    local parsedCS = callsignStr and parseCallsign(callsignStr) or nil

    if mdcData then
        table.insert(mdcHistory, 1, mdcData)
        if #mdcHistory > 3 then table.remove(mdcHistory) end
    end

    mdcData = {
        modelName      = modelName,
        modelId        = modelId,
        sampVehId      = sampVehId,
        targetVeh      = bestVeh,
        plate          = plateTxt,
        hasPlate       = hasPlate,
        color          = colorStr,
        speedKph       = speedKph,
        callsign       = callsignStr,
        parsedCallsign = parsedCS,
        isAlly         = isAlly,
        driverName     = driverName,
        driverSampId   = driverSampId,
        scanDist       = scanDist,
        timestamp      = os.clock(),
    }
    mdcIsAllyUnit = isAlly
    mdcShowWindow = true
    mdcWindowExpiry = os.clock() + 25
end

-- ==================== Борткомпьютер: хоткеи ====================

lua_thread.create(function()
    while true do
        wait(0)

        if isKeyDown(VK_LMENU) and isKeyJustPressed(VK_B)
            and not sampIsChatInputActive()
            and not isSampfuncsConsoleActive()
            and isCharInAnyCar(PLAYER_PED)
        then
            if mdcQuickMode then
                mdcQuickMode = false
                mdcActive    = true
                showCursor(true)
            else
                mdcActive = not mdcActive
                if mdcActive then
                    showCursor(true)
                else
                    local hRaw = readMemory(0xB6F258, 4, false)
                    local vRaw = readMemory(0xB6F250, 4, false)
                    showCursor(false)
                    writeMemory(0xB6F258, 4, hRaw, false)
                    writeMemory(0xB6F250, 4, vRaw, false)
                    if mdcShowWindow then
                        mdcWindowExpiry = os.clock() + 7
                    end
                end
            end
        end

        if isKeyJustPressed(0xBD)  -- VK_OEM_MINUS (клавиша "-")
            and isCharInAnyCar(PLAYER_PED)
            and not sampIsChatInputActive()
            and not isSampfuncsConsoleActive()
        then
            if mdcActive then
                local hRaw = readMemory(0xB6F258, 4, false)
                local vRaw = readMemory(0xB6F250, 4, false)
                showCursor(false)
                writeMemory(0xB6F258, 4, hRaw, false)
                writeMemory(0xB6F250, 4, vRaw, false)
                mdcActive = false
            end
            mdcQuickMode = true
            mdcScanVehicleAhead()
        end

        if isKeyJustPressed(VK_DELETE)
            and mdcShowWindow
            and not sampIsChatInputActive()
        then
            mdcShowWindow   = false
            mdcData         = nil
            mdcWindowExpiry = 0
            mdcQuickMode    = false
            if mdcActive then
                local hRaw = readMemory(0xB6F258, 4, false)
                local vRaw = readMemory(0xB6F250, 4, false)
                showCursor(false)
                writeMemory(0xB6F258, 4, hRaw, false)
                writeMemory(0xB6F250, 4, vRaw, false)
                mdcActive = false
            end
        end

        if mdcShowWindow and mdcWindowExpiry > 0 and os.clock() > mdcWindowExpiry then
            mdcShowWindow   = false
            mdcWindowExpiry = 0
            mdcActive       = false
        end

        if mdcActive and isKeyJustPressed(VK_LBUTTON)
            and not sampIsChatInputActive()
        then
            mdcScanVehicleUnderCursor()
        end
    end
end)

-- ==================== Борткомпьютер: имгуи ====================

local function mdcRenderWindow()
    if myHudFont == nil then return end
    if mdcWindowAlpha <= 0.01 then return end
    if mdcData == nil then return end

    local headerColor, borderColor
    if mdcIsAllyUnit then
        headerColor = imgui.ImVec4(0.20, 0.55, 1.00, 1.0)
        borderColor = imgui.ImVec4(0.20, 0.50, 0.95, 0.85)
    else
        headerColor = imgui.ImVec4(0.40, 0.70, 0.40, 1.0)
        borderColor = imgui.ImVec4(0.25, 0.55, 0.25, 0.70)
    end

    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha,         mdcWindowAlpha)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 6.0)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding,  imgui.ImVec2(12, 10))
    imgui.PushStyleColor(imgui.Col.WindowBg,     imgui.ImVec4(0.04, 0.06, 0.08, 0.95))
    imgui.PushStyleColor(imgui.Col.Border,       borderColor)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 1.5)

    local mdcX = 20
    local mdcY = 480
    imgui.SetNextWindowPos(imgui.ImVec2(mdcX, mdcY), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowSize(imgui.ImVec2(290, 0), imgui.Cond.Always)

    local wFlags = imgui.WindowFlags.NoTitleBar
                 + imgui.WindowFlags.NoResize
                 + imgui.WindowFlags.NoCollapse
                 + imgui.WindowFlags.NoScrollbar
                 + imgui.WindowFlags.AlwaysAutoResize

    if imgui.Begin("MDC_RESULT", nil, wFlags) then
        imgui.PushFont(myHudFont)

        local titleStr
        if mdcIsAllyUnit then
            if mdcData.callsign then
                titleStr = "  MDC // BLUE FORCE UNIT"
            else
                titleStr = "  MDC // POLICE UNIT"
            end
        else
            titleStr = "  MDC // VEHICLE QUERY"
        end
        local drawList = imgui.GetWindowDrawList()
        local p       = imgui.GetCursorScreenPos()
        local ww      = imgui.GetWindowSize().x

        drawList:AddRectFilled(
            imgui.ImVec2(p.x - 12, p.y - 4),
            imgui.ImVec2(p.x + ww + 12, p.y + 16),
            imgui.ColorConvertFloat4ToU32(
                mdcIsAllyUnit
                and imgui.ImVec4(0.08, 0.16, 0.35, 0.90)
                or  imgui.ImVec4(0.06, 0.15, 0.06, 0.90)
            ),
            0.0
        )
        imgui.TextColored(headerColor, titleStr)
        imgui.Separator()
        imgui.Spacing()

        -- ---- VEHICLE MODEL ----
        imgui.TextColored(imgui.ImVec4(0.45, 0.48, 0.52, 1.0), "VEHICLE MODEL:")
        imgui.SameLine(115)
        imgui.TextColored(imgui.ImVec4(0.90, 0.92, 1.00, 1.0),
            mdcData.modelName .. "  [ID:" .. mdcData.modelId .. "]")

        imgui.Spacing()

        -- ---- VEHICLE ID ----
        imgui.TextColored(imgui.ImVec4(0.45, 0.48, 0.52, 1.0), "LICENSE PLATE:")
        imgui.SameLine(115)
        if mdcData.hasPlate then
            imgui.TextColored(imgui.ImVec4(0.98, 0.94, 0.30, 1.0), mdcData.plate)
        else
            imgui.TextColored(imgui.ImVec4(0.65, 0.25, 0.25, 1.0), mdcData.plate)
        end

        imgui.Spacing()

        -- ---- COLOR ----
        imgui.TextColored(imgui.ImVec4(0.45, 0.48, 0.52, 1.0), "COLOR:")
        imgui.SameLine(115)
        imgui.TextColored(imgui.ImVec4(0.82, 0.82, 0.84, 1.0), mdcData.color)

        imgui.Spacing()

        -- ---- DRIVER ----
        imgui.TextColored(imgui.ImVec4(0.45, 0.48, 0.52, 1.0), "DRIVER:")
        imgui.SameLine(115)
        if mdcData.driverSampId >= 0 then
            imgui.TextColored(imgui.ImVec4(1.0, 0.85, 0.30, 1.0),
                mdcData.driverName .. "  [" .. mdcData.driverSampId .. "]")
        else
            imgui.TextColored(imgui.ImVec4(0.35, 0.37, 0.40, 1.0), mdcData.driverName)
        end

        imgui.Spacing()

        -- ---- SPEED ----
        imgui.TextColored(imgui.ImVec4(0.45, 0.48, 0.52, 1.0), "SPEED:")
        imgui.SameLine(115)

        local speedVal    = mdcData.speedKph
        local isOverSpeed = speedVal > 60

        if isOverSpeed then
            local blinkOn = (math.floor(os.clock() * 3.5) % 2 == 0)
            if blinkOn then
                imgui.TextColored(imgui.ImVec4(1.0, 0.10, 0.10, 1.0),
                    speedVal .. " KM/H  [SPEED DANGEROUS]")
            else
                imgui.TextColored(imgui.ImVec4(0.55, 0.05, 0.05, 0.40),
                    speedVal .. " KM/H  [SPEED DANGEROUS]")
            end
        else
            imgui.TextColored(imgui.ImVec4(0.88, 0.90, 0.92, 1.0),
                speedVal .. " KM/H")
        end

        imgui.Spacing()

        imgui.TextColored(imgui.ImVec4(0.45, 0.48, 0.52, 1.0), "DISTANCE:")
        imgui.SameLine(115)
        do
            local liveDist = mdcData.scanDist .. " M"
            if mdcData.targetVeh and doesVehicleExist(mdcData.targetVeh) then
                local px2, py2, pz2 = getCharCoordinates(PLAYER_PED)
                local vx2, vy2, vz2 = getCarCoordinates(mdcData.targetVeh)
                liveDist = math.floor(math.sqrt((vx2-px2)^2+(vy2-py2)^2+(vz2-pz2)^2)) .. " M"
            end
            local distColor = imgui.ImVec4(0.55, 0.90, 0.55, 1.0)
            imgui.TextColored(distColor, liveDist)
        end

        imgui.Spacing()

        if mdcData.targetVeh and doesVehicleExist(mdcData.targetVeh) then
            local vhp   = getCarHealth(mdcData.targetVeh)
            local ratio = math.max(0.0, math.min(1.0, (vhp - 250) / 750))
            local barW  = imgui.GetContentRegionAvail().x
            local bp    = imgui.GetCursorScreenPos()
            local dlhp  = imgui.GetWindowDrawList()
            dlhp:AddRectFilled(
                imgui.ImVec2(bp.x, bp.y + 2),
                imgui.ImVec2(bp.x + barW, bp.y + 9),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.12, 0.12, 0.14, 0.85)), 3)
            local rr = ratio < 0.5 and 1.0 or math.max(0, 2.0 - ratio * 2.0)
            local gg = ratio > 0.5 and 1.0 or ratio * 2.0
            dlhp:AddRectFilled(
                imgui.ImVec2(bp.x, bp.y + 2),
                imgui.ImVec2(bp.x + barW * ratio, bp.y + 9),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(rr, gg, 0.0, 0.90)), 3)
            imgui.Dummy(imgui.ImVec2(0, 11))
        end

        imgui.Separator()
        imgui.Spacing()

        if mdcIsAllyUnit then
            if mdcData.callsign then
                imgui.TextColored(imgui.ImVec4(0.45, 0.48, 0.52, 1.0), "UNIT CALLSIGN:")
                imgui.SameLine(115)

                local parsed = mdcData.parsedCallsign
                if parsed then
                    local dl2   = imgui.GetWindowDrawList()
                    local cp    = imgui.GetCursorScreenPos()
                    local tw    = imgui.CalcTextSize(parsed.label).x
                    local pad   = imgui.ImVec2(6, 3)
                    dl2:AddRectFilled(
                        imgui.ImVec2(cp.x - pad.x, cp.y - pad.y),
                        imgui.ImVec2(cp.x + tw + pad.x, cp.y + 13 + pad.y),
                        imgui.ColorConvertFloat4ToU32(parsed.style.bg),
                        3.0
                    )
                    imgui.TextColored(parsed.style.fg, parsed.label)
                else
                    imgui.TextColored(imgui.ImVec4(0.35, 0.75, 1.00, 1.0),
                        "[" .. mdcData.callsign .. "]")
                end

                -- строка принадлежности (LS / SF / LV) из каллсигна
                local deptLabel = nil
                local deptStyle = nil
                if parsed then
                    local upper = mdcData.callsign:upper()
                    local deptChar = upper:match("^([123])[AMHLUS]%d+")
                    if deptChar then
                        local DEPT_FULL = { ["1"] = "LOS SANTOS", ["2"] = "SAN FIERRO", ["3"] = "LAS VENTURAS" }
                        deptLabel = DEPT_FULL[deptChar] or nil
                        deptStyle = DEPT_STYLES[deptChar] or nil
                    elseif upper:find("^SKYHAWK") or upper:find("^TACTICAL") or upper:find("^SPECIAL") then
                        local sfx = upper:match("%|%s*([A-Z]+)%-ES%s*$")
                        if sfx then
                            local sfxMap = { LS = "1", SF = "2", LV = "3" }
                            local dc = sfxMap[sfx]
                            if dc then
                                local DEPT_FULL = { ["1"] = "LOS SANTOS", ["2"] = "SAN FIERRO", ["3"] = "LAS VENTURAS" }
                                deptLabel = DEPT_FULL[dc]
                                deptStyle = DEPT_STYLES[dc]
                            end
                        end
                    end
                end

                if deptLabel and deptStyle then
                    imgui.Spacing()
                    imgui.TextColored(imgui.ImVec4(0.45, 0.48, 0.52, 1.0), "DEPARTMENT:")
                    imgui.SameLine(115)
                    local dl3 = imgui.GetWindowDrawList()
                    local dp  = imgui.GetCursorScreenPos()
                    local dtw = imgui.CalcTextSize(deptLabel).x
                    local dpad = imgui.ImVec2(6, 3)
                    dl3:AddRectFilled(
                        imgui.ImVec2(dp.x - dpad.x, dp.y - dpad.y),
                        imgui.ImVec2(dp.x + dtw + dpad.x, dp.y + 13 + dpad.y),
                        imgui.ColorConvertFloat4ToU32(deptStyle.bg),
                        3.0
                    )
                    imgui.TextColored(deptStyle.fg, deptLabel)
                end

                imgui.Spacing()
            end

            local allyP  = imgui.GetCursorScreenPos()
            local allyW  = imgui.GetContentRegionAvail().x
            local pulse  = 0.55 + math.sin(os.clock() * 2.5) * 0.25
            drawList:AddRectFilled(
                imgui.ImVec2(allyP.x - 4, allyP.y - 2),
                imgui.ImVec2(allyP.x + allyW + 4, allyP.y + 16),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.10, 0.20, 0.50, 0.25 * pulse)),
                3.0
            )
            local statusLabel = mdcData.callsign and "BLUE FORCE / ALLIED UNIT" or "POLICE / ALLIED UNIT"
            local statusW = imgui.CalcTextSize(statusLabel).x
            imgui.SetCursorPosX((imgui.GetWindowSize().x - statusW) * 0.5)
            imgui.TextColored(imgui.ImVec4(0.30, 0.70, 1.00, pulse), statusLabel)
        else
            local stW = imgui.CalcTextSize("NO CALLSIGN").x
            imgui.SetCursorPosX((imgui.GetWindowSize().x - stW) * 0.5)
            imgui.TextColored(imgui.ImVec4(0.28, 0.30, 0.33, 1.0), "NO CALLSIGN")
        end

        imgui.Spacing()

        if #mdcHistory > 0 then
            imgui.Separator()
            imgui.Spacing()
            local C_DIM  = imgui.ImVec4(0.25, 0.27, 0.30, 1.0)
            local C_HIST = imgui.ImVec4(0.50, 0.52, 0.55, 1.0)
            imgui.TextColored(C_DIM, "PREV QUERIES:")
            for i, h in ipairs(mdcHistory) do
                if i > 3 then break end
                local ago = string.format("%.0fs", os.clock() - h.timestamp)
                local drvStr = (h.driverSampId >= 0) and (" | " .. h.driverName .. " [" .. h.driverSampId .. "]") or ""
                imgui.TextColored(C_HIST, "  " .. h.modelName .. drvStr .. "  +" .. ago)
            end
            imgui.Spacing()
        end

        local elapsed   = os.clock() - mdcData.timestamp
        local footerStr = string.format("SCAN: +%.1fs AGO  |  [-] RESCAN  [DEL] CLOSE", elapsed)
        local footerW   = imgui.CalcTextSize(footerStr).x
        imgui.SetCursorPosX((imgui.GetWindowSize().x - footerW) * 0.5)
        imgui.TextColored(imgui.ImVec4(0.22, 0.24, 0.27, 1.0), footerStr)

        imgui.PopFont()
        imgui.End()
    end

    imgui.PopStyleColor(2)
    imgui.PopStyleVar(4)
end

local mdcUI = imgui.OnFrame(
    function() return mdcActive or (mdcQuickMode and mdcShowWindow) or (not mdcActive and not mdcQuickMode and mdcWindowAlpha > 0.0) end,
    function()
        if myHudFont == nil then return end
        if mdcShowWindow then
            if mdcWindowAlpha < 1.0 then mdcWindowAlpha = mdcWindowAlpha + 0.06 end
            if mdcWindowAlpha > 1.0 then mdcWindowAlpha = 1.0 end
        else
            if mdcWindowAlpha > 0.0 then mdcWindowAlpha = mdcWindowAlpha - 0.06 end
            if mdcWindowAlpha < 0.0 then mdcWindowAlpha = 0.0 end
        end
        mdcRenderWindow()
    end
)
mdcUI.LockPlayer = false
mdcUI.HideCursor = true

-- ¦           СИСТЕМА НАСТРОЕК / ДАННЫХ  (.ini)             ¦

local ESO_BASE_DIR      = getWorkingDirectory() .. "\\Immersive Siren\\config\\"
local ESO_DATA_DIR      = ESO_BASE_DIR
local ESO_SETTINGS_FILE = ESO_BASE_DIR .. "settings.ini"
local ESO_OFFICER_FILE  = ESO_BASE_DIR .. "officer.ini"
local ESO_UOF_DIR       = ""
local ESO_ARREST_DIR    = ""
local ESO_SITU_DIR      = ""

local function ensureDir(path)
    local lfs = require 'lfs'
    local p = path:gsub("[\\/]+$", "")
    if p == "" then return end
    local attr = lfs.attributes(p)
    if attr and attr.mode == "directory" then return end
    os.execute('mkdir "' .. p .. '" 2>nul')
end

local function safeLfsDir(dirPath)
    local lfs = require 'lfs'
    ensureDir(dirPath)
    local p = dirPath:gsub("[\\/]+$", "")
    local iter, state, init = lfs.dir(p)
    if iter == nil then
        return function() return nil end
    end
    return iter, state, init
end

local function esoInitProfileForNick(nick)
    local safeNick = (nick or "unknown"):gsub("[^%w_%-]", "_")
    if safeNick == "" then safeNick = "unknown" end

    ESO_DATA_DIR      = ESO_BASE_DIR .. safeNick .. "\\"
    ESO_SETTINGS_FILE = ESO_DATA_DIR .. "settings.ini"
    ESO_OFFICER_FILE  = ESO_DATA_DIR .. "officer.ini"
    ESO_UOF_DIR       = ESO_DATA_DIR .. "uof_reports\\"
    ESO_ARREST_DIR    = ESO_DATA_DIR .. "arrests_reports\\"
    ESO_SITU_DIR      = ESO_DATA_DIR .. "situations_reports\\"

    ensureDir(ESO_BASE_DIR)
    ensureDir(ESO_DATA_DIR)
    ensureDir(ESO_UOF_DIR)
    ensureDir(ESO_ARREST_DIR)
    ensureDir(ESO_SITU_DIR)

    local probe = io.open(ESO_OFFICER_FILE, "r")
    if probe then probe:close(); return false end
    return true
end

local function iniEnsureDir(path)
    ensureDir(path)
end

local function iniLoad(filepath)
    local data = {}
    local currentSection = "__root__"
    local f = io.open(filepath, "r")
    if not f then return data end
    for line in f:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and not line:match("^;") and not line:match("^#") then
            local sec = line:match("^%[(.-)%]$")
            if sec then
                currentSection = sec
                data[currentSection] = data[currentSection] or {}
            else
                local k, v = line:match("^(.-)%s*=%s*(.-)%s*$")
                if k and k ~= "" then
                    data[currentSection] = data[currentSection] or {}
                    if v == "true" then v = true
                    elseif v == "false" then v = false
                    elseif tonumber(v) then v = tonumber(v)
                    end
                    data[currentSection][k] = v
                end
            end
        end
    end
    f:close()
    return data
end

local function iniSave(filepath, data)
    local f = io.open(filepath, "w")
    if not f then
        print("[ESO] [INI] Не удалось открыть файл для записи: " .. filepath)
        return false
    end
    if data["__root__"] then
        for k, v in pairs(data["__root__"]) do
            f:write(tostring(k) .. "=" .. tostring(v) .. "\n")
        end
        f:write("\n")
    end
    for sec, kvs in pairs(data) do
        if sec ~= "__root__" then
            f:write("[" .. sec .. "]\n")
            for k, v in pairs(kvs) do
                f:write(tostring(k) .. "=" .. tostring(v) .. "\n")
            end
            f:write("\n")
        end
    end
    f:close()
    return true
end

local function ensureDataDir()
    ensureDir(ESO_BASE_DIR)
    ensureDir(ESO_DATA_DIR)
end

local esoSettings = {
    mdcOsWindowX = -1,
    mdcOsWindowY = -1,
    mdcOsWindowW = -1,
    mdcOsWindowH = -1,
    mdcOsLastApp = "home",
}

local esoOfficerData = {
    nickname    = "",
    badgeNumber = "N/A",
    rank        = "Officer",
    department  = "N/A",
    unit        = "N/A",
    assignment  = "N/A",
    autoLocks   = {},   -- поля, подтянутые из /st
    -- Лог событий (список строк)
    eventLog = {},
	-- Доклады
	uofReports = {},
    arrestReports = {},
    situationReports = {},
}

local function settingsLoad()
    ensureDataDir()
    local d = iniLoad(ESO_SETTINGS_FILE)
    local s = d["settings"] or {}
    if s.mdcOsWindowX then esoSettings.mdcOsWindowX = s.mdcOsWindowX end
    if s.mdcOsWindowY then esoSettings.mdcOsWindowY = s.mdcOsWindowY end
    if s.mdcOsWindowW then esoSettings.mdcOsWindowW = tonumber(s.mdcOsWindowW) or -1 end
    if s.mdcOsWindowH then esoSettings.mdcOsWindowH = tonumber(s.mdcOsWindowH) or -1 end
    if s.mdcOsLastApp then esoSettings.mdcOsLastApp = tostring(s.mdcOsLastApp) end
    print("[ESO] [INI] Настройки загружены.")
end

local function settingsSave()
    local d = { settings = {
        mdcOsWindowX = esoSettings.mdcOsWindowX,
        mdcOsWindowY = esoSettings.mdcOsWindowY,
        mdcOsWindowW = esoSettings.mdcOsWindowW,
        mdcOsWindowH = esoSettings.mdcOsWindowH,
        mdcOsLastApp = esoSettings.mdcOsLastApp,
    }}
    iniSave(ESO_SETTINGS_FILE, d)
end

-- ==================== UOF ====================

local function uofEnsureDir()
    if ESO_UOF_DIR ~= "" then
        ensureDir(ESO_UOF_DIR)
    end
end

local function uofGenFilename()
    return ESO_UOF_DIR .. "uof_" .. os.date("%Y%m%d_%H%M%S") .. "_" .. tostring(math.random(1000, 9999)) .. ".ini"
end

local function uofSaveReport(rep)
    uofEnsureDir()
    if (rep.syncId == nil or rep.syncId == "") and sync then rep.syncId = sync.newId() end
    local filepath = rep._file
    if not filepath or filepath == "" then
        filepath = uofGenFilename()
        rep._file = filepath
    end
    local d = {
        uof = {
            location      = rep.location      or "",
            datetime      = rep.datetime      or "",
            weapon        = rep.weapon        or "",
            equipment     = rep.equipment     or "",
            officersCount = rep.officersCount or "",
            seniorOfficer = rep.seniorOfficer or "",
            department    = rep.department    or "",
            unit          = rep.unit          or "",
            officerBadge  = rep.officerBadge  or "",
            officerRank   = rep.officerRank   or "",
            officerNick   = rep.officerNick   or "",
            details       = string.gsub(rep.details or "", "\n", "\\n"),
        }
    }
    d.uof.syncId = rep.syncId or ""
    iniSave(filepath, d)
    print("[ESO] [UOF] Отчёт сохранён: " .. filepath)
end

local function uofDeleteReport(rep)
    if rep and rep._file and rep._file ~= "" then
        os.remove(rep._file)
        print("[ESO] [UOF] Файл отчёта удалён: " .. rep._file)
    end
end

local function uofLoadAllReports(officerIniData)
    uofEnsureDir()
    esoOfficerData.uofReports = {}

    local o = officerIniData["officer"] or {}
    local uofCount = tonumber(o.uofCount) or 0
    if uofCount > 0 then
        print("[ESO] [UOF] Найдено " .. uofCount .. " старых отчётов в officer.ini — мигрируем в файлы...")
        for i = 1, uofCount do
            local u = officerIniData["uof_" .. i]
            if u then
                local rep = {
                    location      = tostring(u.location      or ""),
                    datetime      = tostring(u.datetime      or ""),
                    weapon        = tostring(u.weapon        or ""),
                    equipment     = tostring(u.equipment     or ""),
                    officersCount = tostring(u.officersCount or ""),
                    seniorOfficer = tostring(u.seniorOfficer or ""),
                    department    = tostring(u.department    or ""),
                    unit          = tostring(u.unit          or ""),
                    officerBadge  = tostring(u.officerBadge  or ""),
                    officerRank   = tostring(u.officerRank   or ""),
                    officerNick   = tostring(u.officerNick   or ""),
                    details       = string.gsub(tostring(u.details or ""), "\\n", "\n"),
                    _file         = "",
                }
                rep._file = ESO_UOF_DIR .. "uof_migrated_" .. string.format("%03d", i) .. ".ini"
                uofSaveReport(rep)
                table.insert(esoOfficerData.uofReports, rep)
            end
        end
    end

    local lfs = require 'lfs'
    local loadedFiles = {}
    for _, r in ipairs(esoOfficerData.uofReports) do
        loadedFiles[r._file] = true
    end
    ensureDir(ESO_UOF_DIR)
    for filename in safeLfsDir(ESO_UOF_DIR) do
        if filename:match("^uof_.*%.ini$") then
            local fullPath = ESO_UOF_DIR .. filename
            if not loadedFiles[fullPath] then
                local d = iniLoad(fullPath)
                local u = d["uof"]
                if u then
                    local rep = {
                        location      = tostring(u.location      or ""),
                        datetime      = tostring(u.datetime      or ""),
                        weapon        = tostring(u.weapon        or ""),
                        equipment     = tostring(u.equipment     or ""),
                        officersCount = tostring(u.officersCount or ""),
                        seniorOfficer = tostring(u.seniorOfficer or ""),
                        department    = tostring(u.department    or ""),
                        unit          = tostring(u.unit          or ""),
                        officerBadge  = tostring(u.officerBadge  or ""),
                        officerRank   = tostring(u.officerRank   or ""),
                        officerNick   = tostring(u.officerNick   or ""),
                        details       = string.gsub(tostring(u.details or ""), "\\n", "\n"),
                        _file         = fullPath,
                    syncId = tostring(u.syncId or ""),
                    }
                    table.insert(esoOfficerData.uofReports, rep)
                end
            end
        end
    end

    table.sort(esoOfficerData.uofReports, function(a, b)
        local fa = (a._file or ""):match("([^\\]+)$") or ""
        local fb = (b._file or ""):match("([^\\]+)$") or ""
        return fa > fb
    end)

    print("[ESO] [UOF] Загружено отчётов: " .. #esoOfficerData.uofReports)
end

-- ==================== ARRESTS: ОТДЕЛЬНЫЕ ФАЙЛЫ ====================

local function arrestEnsureDir()
    if ESO_ARREST_DIR ~= "" then ensureDir(ESO_ARREST_DIR) end
end

local function arrestGenFilename()
    return ESO_ARREST_DIR .. "arrest_" .. os.date("%Y%m%d_%H%M%S") .. "_" .. tostring(math.random(1000, 9999)) .. ".ini"
end

local function arrestSaveReport(rep)
    arrestEnsureDir()
    if (rep.syncId == nil or rep.syncId == "") and sync then rep.syncId = sync.newId() end
    local filepath = rep._file
    if not filepath or filepath == "" then
        filepath = arrestGenFilename()
        rep._file = filepath
    end
    local d = {
        arrest = {
            suspectName  = rep.suspectName  or "",
            datetime     = rep.datetime     or "",
            charges      = rep.charges      or "",
            location     = rep.location     or "",
            forceUsed    = rep.forceUsed    or "",
            witnesses    = rep.witnesses    or "",
            details      = string.gsub(rep.details or "", "\n", "\\n"),
            department   = rep.department   or "",
            unit         = rep.unit         or "",
            officerBadge = rep.officerBadge or "",
            officerRank  = rep.officerRank  or "",
            officerNick  = rep.officerNick  or "",
        }
    }
    d.arrest.syncId = rep.syncId or ""
    iniSave(filepath, d)
    print("[ESO] [ARREST] Отчёт сохранён: " .. filepath)
end

local function arrestDeleteReport(rep)
    if rep and rep._file and rep._file ~= "" then
        os.remove(rep._file)
        print("[ESO] [ARREST] Файл удалён: " .. rep._file)
    end
end

local function arrestLoadAllReports()
    arrestEnsureDir()
    esoOfficerData.arrestReports = {}
    local lfs = require 'lfs'
    ensureDir(ESO_ARREST_DIR)
    for filename in safeLfsDir(ESO_ARREST_DIR) do
        if filename:match("^arrest_.*%.ini$") then
            local fullPath = ESO_ARREST_DIR .. filename
            local d = iniLoad(fullPath)
            local u = d["arrest"]
            if u then
                local rep = {
                    suspectName  = tostring(u.suspectName  or ""),
                    datetime     = tostring(u.datetime     or ""),
                    charges      = tostring(u.charges      or ""),
                    location     = tostring(u.location     or ""),
                    forceUsed    = tostring(u.forceUsed    or ""),
                    witnesses    = tostring(u.witnesses    or ""),
                    details      = string.gsub(tostring(u.details or ""), "\\n", "\n"),
                    department   = tostring(u.department   or ""),
                    unit         = tostring(u.unit         or ""),
                    officerBadge = tostring(u.officerBadge or ""),
                    officerRank  = tostring(u.officerRank  or ""),
                    officerNick  = tostring(u.officerNick  or ""),
                    _file        = fullPath,
                    syncId = tostring(u.syncId or ""),
                }
                table.insert(esoOfficerData.arrestReports, rep)
            end
        end
    end
    table.sort(esoOfficerData.arrestReports, function(a, b)
        local fa = (a._file or ""):match("([^\\]+)$") or ""
        local fb = (b._file or ""):match("([^\\]+)$") or ""
        return fa > fb
    end)
    print("[ESO] [ARREST] Загружено отчётов: " .. #esoOfficerData.arrestReports)
end

-- ==================== SITUATIONS: ОТДЕЛЬНЫЕ ФАЙЛЫ ====================

local function situEnsureDir()
    if ESO_SITU_DIR ~= "" then ensureDir(ESO_SITU_DIR) end
end

local function situGenFilename()
    return ESO_SITU_DIR .. "situation_" .. os.date("%Y%m%d_%H%M%S") .. "_" .. tostring(math.random(1000, 9999)) .. ".ini"
end

local function situSaveReport(rep)
    situEnsureDir()
    if (rep.syncId == nil or rep.syncId == "") and sync then rep.syncId = sync.newId() end
    local filepath = rep._file
    if not filepath or filepath == "" then
        filepath = situGenFilename()
        rep._file = filepath
    end
    local d = {
        situation = {
            situationType  = rep.situationType  or "",
            datetime       = rep.datetime       or "",
            location       = rep.location       or "",
            unitsInvolved  = rep.unitsInvolved  or "",
            outcome        = rep.outcome        or "",
            casualties     = rep.casualties     or "",
            details        = string.gsub(rep.details or "", "\n", "\\n"),
            department     = rep.department     or "",
            unit           = rep.unit           or "",
            officerBadge   = rep.officerBadge   or "",
            officerRank    = rep.officerRank    or "",
            officerNick    = rep.officerNick    or "",
        }
    }
    d.situation.syncId = rep.syncId or ""
    iniSave(filepath, d)
    print("[ESO] [SITU] Отчёт сохранён: " .. filepath)
end

-- ==================== ОБЛАЧНАЯ СИНХРОНИЗАЦИЯ: ОТЧЁТЫ ====================
function esoSyncPublish(kind, rep)
    if not (sync and sync.isEnabled()) then return end
    local ok, why = sync.pushReport(kind, rep)
    if ok then
        sampAddChatMessage("[ESO] Отчёт сохранён и отправляется в общую базу (" .. (sync.normalizeDept(rep.department) or "?") .. ").", 0x7EC8E3)
    elseif why == "dept" then
        sampAddChatMessage("[ESO] Отчёт сохранён локально. В общую базу не отправлен: укажите DEPT в HOME (LSPD, SFPD, LVPD или FBI).", 0xFF6A00)
    end
end

-- Удаление отчёта у себя убирает его и из общей базы.
function esoSyncRetract(rep)
    if sync and sync.isEnabled() and rep and rep.syncId and rep.syncId ~= "" then sync.deleteReport(rep.syncId) end
end

local function situDeleteReport(rep)
    if rep and rep._file and rep._file ~= "" then
        os.remove(rep._file)
        print("[ESO] [SITU] Файл удалён: " .. rep._file)
    end
end

local function situLoadAllReports()
    situEnsureDir()
    esoOfficerData.situationReports = {}
    local lfs = require 'lfs'
    ensureDir(ESO_SITU_DIR)
    for filename in safeLfsDir(ESO_SITU_DIR) do
        if filename:match("^situation_.*%.ini$") then
            local fullPath = ESO_SITU_DIR .. filename
            local d = iniLoad(fullPath)
            local u = d["situation"]
            if u then
                local rep = {
                    situationType  = tostring(u.situationType  or ""),
                    datetime       = tostring(u.datetime       or ""),
                    location       = tostring(u.location       or ""),
                    unitsInvolved  = tostring(u.unitsInvolved  or ""),
                    outcome        = tostring(u.outcome        or ""),
                    casualties     = tostring(u.casualties     or ""),
                    details        = string.gsub(tostring(u.details or ""), "\\n", "\n"),
                    department     = tostring(u.department     or ""),
                    unit           = tostring(u.unit           or ""),
                    officerBadge   = tostring(u.officerBadge   or ""),
                    officerRank    = tostring(u.officerRank    or ""),
                    officerNick    = tostring(u.officerNick    or ""),
                    _file          = fullPath,
                    syncId = tostring(u.syncId or ""),
                }
                table.insert(esoOfficerData.situationReports, rep)
            end
        end
    end
    table.sort(esoOfficerData.situationReports, function(a, b)
        local fa = (a._file or ""):match("([^\\]+)$") or ""
        local fb = (b._file or ""):match("([^\\]+)$") or ""
        return fa > fb
    end)
    print("[ESO] [SITU] Загружено отчётов: " .. #esoOfficerData.situationReports)
end

-- ==================== КОНЕЦ UOF ====================

local function officerLoad()
    ensureDataDir()
    local d = iniLoad(ESO_OFFICER_FILE)
    local o = d["officer"] or {}
    if o.badgeNumber then esoOfficerData.badgeNumber = tostring(o.badgeNumber) end
    if o.rank        then esoOfficerData.rank        = tostring(o.rank) end
    if o.department  then esoOfficerData.department  = tostring(o.department) end
    if o.unit        then esoOfficerData.unit        = tostring(o.unit) end
    if o.assignment  then esoOfficerData.assignment  = tostring(o.assignment) end
    esoOfficerData.autoLocks = ESOAuto.locksFromString(o.autoLocks)

    local el = d["eventlog"] or {}
    esoOfficerData.eventLog = {}
    for i = 1, 20 do
        local v = el["e" .. i]
        if v then table.insert(esoOfficerData.eventLog, tostring(v)) end
    end

    uofLoadAllReports(d)
    arrestLoadAllReports()
    situLoadAllReports()

    print("[ESO] [INI] Данные офицера загружены.")
end

local function officerSave()
    local d = {
        officer = {
            badgeNumber  = esoOfficerData.badgeNumber,
            rank         = esoOfficerData.rank,
            department   = esoOfficerData.department,
            unit         = esoOfficerData.unit,
            assignment   = esoOfficerData.assignment,
            autoLocks    = ESOAuto.locksToString(),
        },
        eventlog = {}
    }
    for i, v in ipairs(esoOfficerData.eventLog) do
        d["eventlog"]["e" .. i] = v
        if i >= 20 then break end
    end
    iniSave(ESO_OFFICER_FILE, d)
end

function officerAddEvent(text)
    local timeStr = os.date("%d.%m.%Y - %H:%M")
    table.insert(esoOfficerData.eventLog, 1, "[" .. timeStr .. "] " .. text)
    if #esoOfficerData.eventLog > 20 then
        table.remove(esoOfficerData.eventLog)
    end
    officerSave()
end

-- ==================== АВТОМАТИКА: /st, АВТО-UOF ====================
ESOAuto = ESOAuto or {}
do
    local A = ESOAuto
    A.statDone, A.fetching, A.gotDialog, A.statWait = false, false, false, 0
    A.lastWeapon, A.lastWeaponAt = 0, 0
    A.lastKill = { key = "", at = 0 }
    A.LOCK_KEYS = { "badgeNumber", "rank", "department" }

    A.WEAPONS = {
        [2] = "Golf Club", [3] = "Nightstick", [4] = "Knife", [5] = "Baseball Bat", [6] = "Shovel", [7] = "Pool Cue",
        [8] = "Katana", [9] = "Chainsaw", [16] = "Grenade", [17] = "Tear Gas", [18] = "Molotov Cocktail",
        [22] = "Colt 45", [23] = "Silenced Pistol", [24] = "Desert Eagle", [25] = "Shotgun", [26] = "Sawn-off Shotgun",
        [27] = "Combat Shotgun", [28] = "Micro SMG", [29] = "MP5", [30] = "AK-47", [31] = "M4", [32] = "Tec-9",
        [33] = "Country Rifle", [34] = "Sniper Rifle", [41] = "Spray Can", [42] = "Fire Extinguisher",
    }

    function A.locksToString()
        local out = {}
        local L = esoOfficerData.autoLocks or {}
        for _, k in ipairs(A.LOCK_KEYS) do if L[k] then out[#out + 1] = k end end
        return table.concat(out, ",")
    end

    function A.locksFromString(str)
        local t = {}
        for k in tostring(str or ""):gmatch("%w+") do t[k] = true end
        return t
    end

    -- Подразделение из /st -> код департамента
    function A.normDept(str)
        if type(str) ~= "string" or str == "" then return nil end
        local p = " " .. string.nlower(str) .. " "
        if p:find("фбр") or p:find("федерал") or p:find("fbi") then return "FBI" end
        if p:find("лспд") or p:find("lspd") or p:find("лос[%s%-]*сантос") or p:find("los%s*santos") or p:find("[%s%p]лс[%s%p]") then return "LSPD" end
        if p:find("сфпд") or p:find("sfpd") or p:find("сан[%s%-]*фиерро") or p:find("san%s*fierro") or p:find("[%s%p]сф[%s%p]") then return "SFPD" end
        if p:find("лвпд") or p:find("lvpd") or p:find("лас[%s%-]*вентурас") or p:find("las%s*venturas") or p:find("[%s%p]лв[%s%p]") then return "LVPD" end
        return nil
    end

    -- Разбор текста диалога "Статистика игрока"
    function A.parseStats(text)
        text = tostring(text or ""):gsub("{%x%x%x%x%x%x}", "")
        local r = {}
        for line in (text .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
            local label, val = line:match("^%s*([^\t:]-)%s*:%s*(.-)%s*$")
            if not label then label, val = line:match("^%s*([^\t]-)%s*\t+%s*(.-)%s*$") end
            if label and val and val ~= "" then
                label = string.nlower(label)
                if label == "должность" then
                    r.rank = val:gsub("^%[[^%]]*%]%s*", "")      -- убираем тег [LS] / [SF] / [LV]
                elseif label == "подразделение" then
                    r.deptRaw = val
                    r.dept = A.normDept(val)
                elseif label:find("аккаунт") or label:find("жетон") then
                    r.badge = val:match("%d+") or val
                end
            end
        end
        return r
    end

    function A.applyStats(text)
        local r = A.parseStats(text)
        local o = esoOfficerData
        o.autoLocks = o.autoLocks or {}
        if r.rank and r.rank ~= "" then o.rank = r.rank; o.autoLocks.rank = true end
        if r.dept then o.department = r.dept; o.autoLocks.department = true end
        if r.badge then o.badgeNumber = r.badge; o.autoLocks.badgeNumber = true end
        if r.rank or r.dept or r.badge then
            officerSave()
            A.statDone = true
        end

        if not r.badge then
            local have = tostring(o.badgeNumber or ""):match("^%d+$")
            if have and o.autoLocks.badgeNumber then
                A.badgeFound = true
            else
                A.fetchBadge()
            end
        end
        if not (r.rank and r.dept and r.badge) then
            print("[ESO] /st, текст диалога для отладки:\n" .. tostring(text))
        end
    end

    function A.onDialog(dialogId, title, text, style)
        local r = A.onBadgeDialog(dialogId, title, text, style)
        if r ~= nil then return r end
        return A.onStatDialog(dialogId, title, text)
    end

    function A.onStatDialog(dialogId, title, text)
        if os.clock() >= A.statWait then return nil end
        local t = string.nlower((tostring(title):gsub("{%x%x%x%x%x%x}", "")))
        if not t:find("статистика игрока", 1, true) then return nil end
        A.gotDialog = true
        local ok, err = pcall(A.applyStats, text)
        if not ok then print("[ESO] Ошибка разбора /st: " .. tostring(err)) end
        lua_thread.create(function()
            wait(30)
            sampSendDialogResponse(dialogId, 1, 0, "")
        end)
        return false
    end

    A.badgeStage, A.badgeWait, A.badgeBusy, A.badgeFound, A.badgeLast = 0, 0, false, false, nil

    local function dlgTitle(title) return string.nlower((tostring(title or ""):gsub("{%x%x%x%x%x%x}", ""))) end

    local function findItem(text, style, needle, fallback)
        local idx, header = -1, (style == 5)
        for line in (tostring(text or "") .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
            if line ~= "" then
                if header then
                    header = false
                else
                    idx = idx + 1
                    local l = string.nlower((line:gsub("{%x%x%x%x%x%x}", "")))
                    if l:find(needle, 1, true) then return idx end
                end
            end
        end
        return fallback
    end

    local function badgeReply(dialogId, button, item)
        A.badgeLast = dialogId
        lua_thread.create(function()
            wait(80)
            pcall(sampSendDialogResponse, dialogId, button, item, "")
        end)
    end

    function A.applyBadge(num)
        local o = esoOfficerData
        o.autoLocks = o.autoLocks or {}
        o.badgeNumber = tostring(num)
        o.autoLocks.badgeNumber = true
        A.badgeFound = true
        officerSave()
    end

    function A.onBadgeDialog(dialogId, title, text, style)
        if A.badgeStage == 0 or os.clock() > A.badgeWait then return nil end
        local t = dlgTitle(title)

        local body = string.nlower((tostring(text or ""):gsub("{%x%x%x%x%x%x}", "")))
        local num = body:match("номер%s+аккаунта%s*:?%s*(%d+)")
        if num and A.badgeStage >= 2 and A.badgeStage < 4 then
            A.applyBadge(num)
            A.badgeStage = 4
            A.badgeWait = os.clock() + 2
            badgeReply(dialogId, 0, -1)
            return false
        end

        if A.badgeStage == 1 and t:find("меню игрока", 1, true) then
            A.badgeStage = 2
            badgeReply(dialogId, 1, findItem(text, style, "донат", 11)) -- 12-й пункт
            return false
        elseif A.badgeStage == 2 and t:find("донат", 1, true) then
            A.badgeStage = 3
            badgeReply(dialogId, 1, findItem(text, style, "информация", 0)) -- 1-й пункт
            return false
        elseif A.badgeStage == 4 and (t:find("донат", 1, true) or t:find("меню игрока", 1, true)) then
            badgeReply(dialogId, 0, -1)
            return false
        end
        return nil
    end

    function A.fetchBadge(manual)
        if A.badgeBusy or A.badgeFound then return end
        A.badgeBusy = true
        lua_thread.create(function()
            if not manual then

            end
            wait(1500)
            local tries = 0
            while not A.badgeFound and tries < 2 do
                while not A.ready() do wait(500) end
                A.badgeStage, A.badgeWait = 1, os.clock() + 12
                sampSendChat("/mn")
                local t0 = os.clock()
                while os.clock() - t0 < 12 and A.badgeStage ~= 4 and not A.badgeFound do wait(100) end
                if A.badgeFound then break end
                if A.badgeLast then pcall(sampSendDialogResponse, A.badgeLast, 0, -1, "") A.badgeLast = nil end
                A.badgeStage = 0
                tries = tries + 1
                wait(3000)
            end
            if A.badgeFound then wait(2200) end
            A.badgeStage, A.badgeBusy = 0, false
            if not A.badgeFound then
                sampAddChatMessage("[ESO] Не удалось считать номер аккаунта. Впишите BADGE вручную во вкладке HOME.", 0xFF6A00)
            end
        end)
    end

    function A.ready()
        local ok, sp = pcall(sampIsLocalPlayerSpawned)
        return ok and sp and (esoOfficerData.nickname or "") ~= ""
    end

    function A.start(reason)
        if A.fetching or A.statDone then return end
        A.fetching = true
        lua_thread.create(function()
            local tries = 0
            while not A.statDone and tries < 5 do
                while not A.ready() do wait(500) end
                wait(3000)
                if A.statDone then break end
                A.gotDialog = false
                A.statWait = os.clock() + 7
                sampSendChat("/st")
                local t0 = os.clock()
                while os.clock() - t0 < 7 and not A.gotDialog do wait(100) end
                A.statWait = 0
                if A.gotDialog then break end
                tries = tries + 1
                wait(10000)
            end
            A.fetching = false
        end)
    end

    lua_thread.create(function()
        wait(2000)
        while true do
            wait(250)
            local ok, w = pcall(getCurrentCharWeapon, PLAYER_PED)
            if ok and tonumber(w) and w > 1 then A.lastWeapon, A.lastWeaponAt = w, os.clock() end
        end
    end)

    function A.weaponName()
        local ok, w = pcall(getCurrentCharWeapon, PLAYER_PED)
        w = (ok and tonumber(w)) or 0
        if w <= 1 and A.lastWeapon > 1 and os.clock() - A.lastWeaponAt < 8 then w = A.lastWeapon end
        if w <= 1 then return "Без оружия" end
        return A.WEAPONS[w] or ("Weapon #" .. w)
    end

    function A.district()
        local ok, name = pcall(function()
            local x, y, z = getCharCoordinates(PLAYER_PED)
            local key = getNameOfZone(x, y, z)
            local txt = getGxtText(key)
            if txt and txt ~= "" then return txt end
            return key
        end)
        if ok and name and name ~= "" then return name end
        return "Неизвестный район"
    end

    -- "[Всем постам] [LS] Лейтенант Nick_Name нейтрализовал преступника Suspect_Name."
    function A.onChat(clean)
        local nick = playerNickname
        if not nick or nick == "" then return end
        if not string.nlower(clean):find("всем постам", 1, true) then return end
        local who, target = clean:match("(%S+)%s+нейтрализовал[\224-\255]*%s+%S+%s+(%S+)")
        if not who or who:lower() ~= nick:lower() then return end
        target = target:gsub("[%.,!]+$", "")
        local t = os.clock()
        if A.lastKill.key == target and t - A.lastKill.at < 10 then return end
        A.lastKill = { key = target, at = t }

        local o = esoOfficerData
        local officer = ((o.nickname ~= "" and o.nickname or nick):gsub("_", " "))
        local district = A.district()
        local rep = {
            location = district,
            datetime = esoMskDate("%d.%m.%Y - %H:%M"),
            weapon = A.weaponName(),
            equipment = "", officersCount = "", seniorOfficer = "",
            department = o.department, unit = o.unit,
            officerBadge = o.badgeNumber, officerRank = o.rank, officerNick = officer,
            details = "Офицер " .. officer .. " произвёл нейтрализацию подозреваемого в районе " .. district
                .. " в " .. esoMskDate("%H:%M %d.%m.%Y") .. " (МСК).",
            _file = "",
        }
        uofSaveReport(rep)
        table.insert(o.uofReports, 1, rep)
        esoSyncPublish("uof", rep)
        sampAddChatMessage("[ESO] Нейтрализация: UOF-доклад составлен автоматически.", 0x7EC8E3)
    end

end

lua_thread.create(function()
    wait(500)

    local myId
    repeat
        wait(200)
        local ok, id = pcall(function()
            local _, pid = sampGetPlayerIdByCharHandle(PLAYER_PED)
            return pid
        end)
        if ok and type(id) == "number" and id >= 0 then
            myId = id
        end
    until myId ~= nil

    local nick = sampGetPlayerNickname(myId) or "unknown"
    nick = nick:gsub(" ", "_")

    local isNewProfile = esoInitProfileForNick(nick)

    settingsLoad()
    officerLoad()

    esoOfficerData.nickname = nick

    if isNewProfile then
        print("[ESO] НОВЫЙ ПРОФИЛЬ: " .. nick)
        print("[ESO] Данные профиля не найдены в папке конфига. Установлены дефолтные значения.")
    else
        print("[ESO] Профиль считан: " .. nick)
    end
end)


-- ============================================================================
--  MDC OS 2.0
-- ============================================================================
do
local ffi = require 'ffi'
local V2  = imgui.ImVec2
local M   = {}

local function v4(r, g, b, a) return imgui.ImVec4(r, g, b, a or 1.0) end

local u8cache, u8count = {}, 0
local function T(s)
    local r = u8cache[s]
    if r == nil then
        if u8count > 1500 then u8cache, u8count = {}, 0 end
        r = u8(s)
        u8cache[s] = r
        u8count = u8count + 1
    end
    return r
end

local lblCache = {}
local function L(s, id)
    local t = lblCache[s]
    if not t then t = {}; lblCache[s] = t end
    local r = t[id]
    if not r then r = T(s) .. "##" .. id; t[id] = r end
    return r
end

-- ---------------------------------------------------------------------------
--  Состояние
-- ---------------------------------------------------------------------------
M.open      = false
M.alpha     = 0.0
M.app       = nil
M.rev       = 0                    
M.nav       = { view = "main", kind = nil, id = 0 }
M.homeEdit  = false
M.editBuf   = nil
M.armed     = 0               
M.bufs      = {}               
M.form      = { kind = nil, idx = 0 }
M.search    = imgui.new.char[64]()
M.rowC      = setmetatable({}, { __mode = "k" })  
M.W, M.H    = 940, 590
M.noScroll  = imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse

M.padFlag   = imgui.WindowFlags.AlwaysUseWindowPadding or 0

M.apps = {
    { id = "home",  label = "HOME",  icon = "home" },
    { id = "depts", label = "DEPTS", icon = "grid" },
    { id = "about", label = "ABOUT", icon = "info" },
}

-- ---------------------------------------------------------------------------
M.C = {
    bg      = v4(0.050, 0.058, 0.078, 0.985),
    header  = v4(0.070, 0.082, 0.115),
    side    = v4(0.042, 0.049, 0.066),
    app     = v4(0.062, 0.074, 0.098),
    panel   = v4(0.092, 0.108, 0.145),
    panelHi = v4(0.125, 0.150, 0.205),
    border  = v4(0.165, 0.195, 0.265),
    sep     = v4(0.135, 0.158, 0.215),
    accent  = v4(0.30, 0.60, 1.00),
    text    = v4(0.89, 0.91, 0.94),
    dim     = v4(0.52, 0.56, 0.64),
    faint   = v4(0.34, 0.38, 0.45),
    green   = v4(0.30, 0.80, 0.50),
    red     = v4(0.93, 0.36, 0.33),
    yellow  = v4(1.00, 0.79, 0.28),
}
-- цвета видов докладов
M.KC = {
    uof    = v4(0.93, 0.36, 0.33),
    arrest = v4(0.32, 0.62, 1.00),
    situ   = v4(1.00, 0.79, 0.28),
    accent = v4(0.30, 0.60, 1.00),
    green  = v4(0.30, 0.80, 0.50),
    red    = v4(0.93, 0.36, 0.33),
}
-- кнопки
M.B = {
    primary = { v4(0.22, 0.48, 0.95), v4(0.30, 0.56, 1.00), v4(0.18, 0.40, 0.82) },
    ghost   = { v4(1, 1, 1, 0.06),    v4(1, 1, 1, 0.12),    v4(1, 1, 1, 0.18)   },
    success = { v4(0.18, 0.60, 0.36), v4(0.22, 0.70, 0.42), v4(0.15, 0.50, 0.30) },
    danger  = { v4(0.78, 0.26, 0.26), v4(0.90, 0.32, 0.30), v4(0.66, 0.20, 0.20) },
    quiet   = { v4(0.93, 0.36, 0.33, 0.10), v4(0.93, 0.36, 0.33, 0.28), v4(0.93, 0.36, 0.33, 0.40) },
}

function M.rebuildU()
    local a = M.alpha
    local U = M.U or {}
    for k, c in pairs(M.C) do
        U[k] = imgui.ColorConvertFloat4ToU32(v4(c.x, c.y, c.z, c.w * a))
    end
    for k, c in pairs(M.KC) do
        U[k]           = imgui.ColorConvertFloat4ToU32(v4(c.x, c.y, c.z, a))
        U[k .. "_soft"] = imgui.ColorConvertFloat4ToU32(v4(c.x, c.y, c.z, 0.14 * a))
        U[k .. "_mid"]  = imgui.ColorConvertFloat4ToU32(v4(c.x, c.y, c.z, 0.55 * a))
    end
    M.U, M.uA = U, a
end

-- ---------------------------------------------------------------------------
--  Утилиты
-- ---------------------------------------------------------------------------
function M.raw(s)
    if imgui.TextUnformatted then imgui.TextUnformatted(s)
    else imgui.Text((s:gsub("%%", "%%%%"))) end
end

function M.txt(col, s)
    imgui.PushStyleColor(imgui.Col.Text, col)
    M.raw(s)
    imgui.PopStyleColor()
end

function M.wrapped(col, s)
    imgui.PushStyleColor(imgui.Col.Text, col)
    imgui.PushTextWrapPos(0.0)
    M.raw(s)
    imgui.PopTextWrapPos()
    imgui.PopStyleColor()
end

function M.big(col, s, scale)
    imgui.SetWindowFontScale(scale)
    M.txt(col, s)
    imgui.SetWindowFontScale(1.0)
end

-- обрезка UTF-8 строки до n байт без разрыва символа (для буферов imgui)
function M.fit(s, n)
    if #s <= n then return s end
    s = s:sub(1, n)
    local i = #s
    while i > 0 do
        local b = s:byte(i)
        if b < 0x80 or b >= 0xC0 then break end
        i = i - 1
    end
    local b = s:byte(i) or 0
    local need = b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
    if i + need - 1 > #s then s = s:sub(1, i - 1) end
    return s
end

function M.plural(n, one, few, many)
    local m10, m100 = n % 10, n % 100
    if m10 == 1 and m100 ~= 11 then return one end
    if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14) then return few end
    return many
end

-- "12.03.2026 - 18:40" -> unix time (для правильной сортировки; строка сортируется неверно)
function M.parseTs(s)
    if type(s) ~= "string" then return 0 end
    local d, mo, y, h, mi = s:match("(%d+)%.(%d+)%.(%d+)%D+(%d+):(%d+)")
    if not d then return 0 end
    local ok, t = pcall(os.time, { day = tonumber(d), month = tonumber(mo), year = tonumber(y),
                                   hour = tonumber(h), min = tonumber(mi) })
    return (ok and t) or 0
end

local function nz(s, alt)
    if s == nil or s == "" then return alt or "N/A" end
    return s
end

-- показ/скрытие курсора (раньше этот блок был скопирован в 3 местах)
function M.setOpen(v)
    if v == M.open then return end
    M.open = v
    if v then
        local last = esoSettings.mdcOsLastApp
        M.app = "home"
        for _, a in ipairs(M.apps) do if a.id == last then M.app = last end end
        showCursor(true)
    else
        esoSettings.mdcOsLastApp = M.app or "home"
        settingsSave()
        local hRaw = readMemory(0xB6F258, 4, false)
        local vRaw = readMemory(0xB6F250, 4, false)
        showCursor(false)
        writeMemory(0xB6F258, 4, hRaw, false)
        writeMemory(0xB6F250, 4, vRaw, false)
    end
end

function M.go(view, kind, id)
    M.nav.view, M.nav.kind, M.nav.id = view, kind, id or 0
    M.armed = 0
    if view == "main" then ffi.fill(M.search, 64) end
end

-- ---------------------------------------------------------------------------
--  Базовые виджеты
-- ---------------------------------------------------------------------------
function M.btn(label, w, h, kind)
    local B = M.B[kind or "ghost"]
    imgui.PushStyleColor(imgui.Col.Button,        B[1])
    imgui.PushStyleColor(imgui.Col.ButtonHovered, B[2])
    imgui.PushStyleColor(imgui.Col.ButtonActive,  B[3])
    local r = imgui.Button(label, V2(w, h))
    imgui.PopStyleColor(3)
    return r
end

function M.chevron(dl, x, y, dir, s, col)
    -- dir: -1 влево, 1 вправо
    dl:AddLine(V2(x - dir * s * 0.5, y - s), V2(x + dir * s * 0.5, y), col, 1.8)
    dl:AddLine(V2(x + dir * s * 0.5, y), V2(x - dir * s * 0.5, y + s), col, 1.8)
end

function M.beginCard(id, w, h, scroll)
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 8.0)
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.0)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(14, 12))
    imgui.PushStyleColor(M.childBg, M.C.panel)
    imgui.PushStyleColor(imgui.Col.Border, M.C.border)
    local flags = scroll and 0 or (imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
    local ok = imgui.BeginChild(id, V2(w, h), true, flags)
    imgui.PopStyleColor(2)
    imgui.PopStyleVar(3)
    return ok
end

-- Заголовок секции: акцентная метка + название + линия до края
function M.section(title, noLine)
    local dl = imgui.GetWindowDrawList()
    local p  = imgui.GetCursorScreenPos()
    local w  = imgui.GetContentRegionAvail().x
    local s  = T(title)
    local tw = imgui.CalcTextSize(s).x
    dl:AddRectFilled(V2(p.x, p.y + 2), V2(p.x + 3, p.y + 14), M.U.accent, 2)
    imgui.SetCursorScreenPos(V2(p.x + 11, p.y))
    M.txt(M.C.text, s)
    if not noLine then
        dl:AddLine(V2(p.x + 11 + tw + 12, p.y + 8), V2(p.x + w, p.y + 8), M.U.sep, 1.0)
    end
end

function M.tip(title, text)
    if not imgui.IsItemHovered() then return end
    imgui.BeginTooltip()
    imgui.PushTextWrapPos(300)
    M.txt(M.C.accent, T(title))
    M.txt(M.C.text, T(text))
    imgui.PopTextWrapPos()
    imgui.EndTooltip()
end

function M.kv(label, value, labelW, tip)
    local x = imgui.GetCursorPosX()
    M.txt(M.C.dim, T(label))
    if tip then M.tip(label, tip) end
    imgui.SameLine(x + labelW)
    imgui.PushStyleColor(imgui.Col.Text, M.C.text)
    imgui.PushTextWrapPos(0.0)
    M.raw(value)
    imgui.PopTextWrapPos()
    imgui.PopStyleColor()
end

function M.pageHeader(title, sub, backView, backKind, rightW, rightFn, backId)
    local dl = imgui.GetWindowDrawList()
    local U  = M.U
    local x0, y0 = imgui.GetCursorPosX(), imgui.GetCursorPosY()
    local maxX = x0 + imgui.GetContentRegionAvail().x
    local tx = x0

    if backView then
        imgui.SetCursorPos(V2(x0, y0 + 2))
        local p = imgui.GetCursorScreenPos()
        if imgui.InvisibleButton("##back", V2(36, 36)) then
            if type(backView) == "function" then backView() else M.go(backView, backKind, backId) end
        end
        local hov = imgui.IsItemHovered()
        dl:AddRectFilled(p, V2(p.x + 36, p.y + 36), hov and U.panelHi or U.panel, 9)
        dl:AddRect(p, V2(p.x + 36, p.y + 36), U.border, 9, 15, 1)
        M.chevron(dl, p.x + 18, p.y + 18, -1, 5, hov and U.text or U.dim)
        tx = x0 + 48
    end

    imgui.SetCursorPos(V2(tx, y0))
    M.big(M.C.text, title, 1.25)
    imgui.SetCursorPos(V2(tx, y0 + 26))
    M.txt(M.C.dim, sub)

    if rightFn then
        imgui.SetCursorPos(V2(maxX - rightW, y0 + 5))
        rightFn()
    end

    imgui.SetCursorPos(V2(x0, y0 + 52))
    local p = imgui.GetCursorScreenPos()
    dl:AddLine(V2(p.x, p.y), V2(p.x + (maxX - x0), p.y), U.sep, 1.0)
    imgui.SetCursorPos(V2(x0, y0 + 66))
end

function M.entry(id, w, h, kcol, num, title, sub, badge)
    local dl  = imgui.GetWindowDrawList()
    local U   = M.U
    local p   = imgui.GetCursorScreenPos()
    local clicked = imgui.InvisibleButton(id, V2(w, h))
    local hov = imgui.IsItemHovered()
    local x1, y1 = p.x + w, p.y + h

    dl:AddRectFilled(p, V2(x1, y1), hov and U.panelHi or U.panel, 8)
    dl:AddRect(p, V2(x1, y1), hov and U[kcol .. "_mid"] or U.border, 8, 15, 1)
    dl:AddRectFilled(V2(p.x, p.y + 10), V2(p.x + 3, y1 - 10), U[kcol], 2)

    local tx = p.x + 16
    if num then
        local nw = imgui.CalcTextSize(num).x
        dl:AddRectFilled(V2(tx, p.y + 9), V2(tx + nw + 12, p.y + 27), U[kcol .. "_soft"], 5)
        dl:AddText(V2(tx + 6, p.y + 10), U[kcol], num)
        tx = tx + nw + 20
    end

    dl:PushClipRect(V2(p.x + 8, p.y), V2(x1 - 34, y1), true)
    dl:AddText(V2(tx, p.y + 10), U.text, title)
    dl:AddText(V2(p.x + 16, p.y + h - 25), U.dim, sub)
    dl:PopClipRect()

    if badge then
        local bw = imgui.CalcTextSize(badge).x
        local bx = x1 - 36 - bw - 10
        dl:AddRectFilled(V2(bx, p.y + 9), V2(bx + bw + 10, p.y + 27), U.green_soft, 5)
        dl:AddText(V2(bx + 5, p.y + 10), U.green, badge)
    end
    M.chevron(dl, x1 - 18, p.y + h * 0.5, 1, 5, hov and U.text or U.faint)
    return clicked
end

function M.vlist(n, stride, drawItem)
    local gap   = 7
    local viewH = imgui.GetWindowHeight()
    local sy    = imgui.GetScrollY()
    local first = math.max(1, math.floor(sy / stride))
    local last  = math.min(n, math.ceil((sy + viewH) / stride) + 1)
    if first > 1 then imgui.Dummy(V2(1, (first - 1) * stride - gap)) end
    for i = first, last do drawItem(i) end
    if last < n then imgui.Dummy(V2(1, (n - last) * stride - gap)) end
end

function M.empty(title, hint)
    local aw = imgui.GetContentRegionAvail().x
    local ah = imgui.GetContentRegionAvail().y
    local dl = imgui.GetWindowDrawList()
    local p  = imgui.GetCursorScreenPos()
    local cx, cy = p.x + aw * 0.5, p.y + math.min(ah * 0.35, 120)
    dl:AddCircle(V2(cx, cy), 22, M.U.faint, 32, 1.6)
    dl:AddLine(V2(cx - 8, cy), V2(cx + 8, cy), M.U.faint, 1.6)
    imgui.SetCursorPosY(imgui.GetCursorPosY() + math.min(ah * 0.35, 120) + 36)
    local tw = imgui.CalcTextSize(title).x
    imgui.SetCursorPosX(imgui.GetCursorPosX() + (aw - tw) * 0.5)
    M.txt(M.C.dim, title)
    if hint then
        local hw = imgui.CalcTextSize(hint).x
        imgui.SetCursorPosX(imgui.GetCursorPosX() + (aw - hw) * 0.5)
        M.txt(M.C.faint, hint)
    end
end

function M.searchBox(id, buf, w, hint)
    local dl = imgui.GetWindowDrawList()
    imgui.PushItemWidth(w)
    imgui.InputText(id, buf, 64)
    imgui.PopItemWidth()
    local mn, mx = imgui.GetItemRectMin(), imgui.GetItemRectMax()
    if buf[0] == 0 and not imgui.IsItemActive() then
        dl:AddText(V2(mn.x + 10, mn.y + 5), M.U.faint, hint)
    end
    local cx, cy = mx.x - 16, (mn.y + mx.y) * 0.5 - 1
    dl:AddCircle(V2(cx, cy), 4.5, M.U.faint, 14, 1.4)
    dl:AddLine(V2(cx + 3.5, cy + 3.5), V2(cx + 7, cy + 7), M.U.faint, 1.4)
end

function M.segmented(id, opts, cur)
    local dl, U = imgui.GetWindowDrawList(), M.U
    local h, padX = 26, 13
    local p = imgui.GetCursorScreenPos()
    local total = 0
    for i, o in ipairs(opts) do
        if not o.w then o.w = imgui.CalcTextSize(o.t).x + padX * 2; o.id = "##seg_" .. id .. "_" .. i end
        total = total + o.w
    end
    dl:AddRectFilled(p, V2(p.x + total, p.y + h), U.panel, 7)
    dl:AddRect(p, V2(p.x + total, p.y + h), U.border, 7, 15, 1)
    local x, res = p.x, nil
    local ty = p.y + (h - imgui.GetTextLineHeight()) * 0.5
    for _, o in ipairs(opts) do
        imgui.SetCursorScreenPos(V2(x, p.y))
        if imgui.InvisibleButton(o.id, V2(o.w, h)) then res = o.v end
        local act, hov = (o.v == cur), imgui.IsItemHovered()
        if act then
            dl:AddRectFilled(V2(x + 2, p.y + 2), V2(x + o.w - 2, p.y + h - 2), U.accent_mid, 5)
        elseif hov then
            dl:AddRectFilled(V2(x + 2, p.y + 2), V2(x + o.w - 2, p.y + h - 2), U.accent_soft, 5)
        end
        dl:AddText(V2(x + padX, ty), (act or hov) and U.text or U.dim, o.t)
        x = x + o.w
    end
    imgui.SetCursorScreenPos(p)
    imgui.Dummy(V2(total, h))
    return res
end

M.icons = {}
function M.icons.home(dl, cx, cy, col)
    dl:AddLine(V2(cx - 11, cy), V2(cx, cy - 10), col, 1.7)
    dl:AddLine(V2(cx, cy - 10), V2(cx + 11, cy), col, 1.7)
    dl:AddRect(V2(cx - 7, cy - 1), V2(cx + 7, cy + 9), col, 2, 15, 1.7)
    dl:AddRect(V2(cx - 2, cy + 3), V2(cx + 2, cy + 9), col, 1, 15, 1.4)
end
function M.icons.grid(dl, cx, cy, col)
    for gx = 0, 1 do
        for gy = 0, 1 do
            local x, y = cx - 10 + gx * 11, cy - 10 + gy * 11
            dl:AddRect(V2(x, y), V2(x + 9, y + 9), col, 2, 15, 1.7)
        end
    end
end
function M.icons.info(dl, cx, cy, col)
    dl:AddCircle(V2(cx, cy), 10.5, col, 28, 1.7)
    dl:AddLine(V2(cx, cy - 1), V2(cx, cy + 5), col, 1.9)
    dl:AddCircleFilled(V2(cx, cy - 5), 1.5, col, 8)
end

M.childBg = imgui.Col.ChildBg or imgui.Col.ChildWindowBg

M.K = {
    uof = {
        key = "uof", coll = "uofReports", name = "USE OF FORCE", short = "UOF",
        newTitle = "Новый доклад UOF", editTitle = "Редактирование доклада UOF",
        tipTitle = "USE OF FORCE", tip = "Доклады о применении оружия.",
        sumTitle = "СВОДКА ИНЦИДЕНТА", descTitle = "ПОДРОБНОЕ ОПИСАНИЕ СИТУАЦИИ",
        fields = {
            { "datetime", "Время и дата", 64 },       { "location", "Локация", 128 },
            { "weapon", "Применяемое оружие", 128 },  { "equipment", "Спецсредства", 128 },
            { "officersCount", "Кол-во офицеров", 32 }, { "seniorOfficer", "Старший офицер", 64 },
        },
        sub = { "datetime", "location", "seniorOfficer" },
        save = uofSaveReport, del = uofDeleteReport,
    },
    arrest = {
        key = "arrest", coll = "arrestReports", name = "ARREST", short = "ARREST",
        newTitle = "Новый доклад об аресте", editTitle = "Редактирование доклада об аресте",
        tipTitle = "ARREST", tip = "Доклады о передаче подозреваемых в ИВС / СИЗО.",
        sumTitle = "СВОДКА ЗАДЕРЖАНИЯ", descTitle = "ПОДРОБНОЕ ОПИСАНИЕ",
        titleExtra = "suspectName",
        fields = {
            { "suspectName", "Задержанный", 128 },     { "datetime", "Дата и время", 64 },
            { "charges", "Статья / нарушение", 256 },  { "location", "Место задержания", 128 },
            { "forceUsed", "Применение силы", 32 },    { "witnesses", "Свидетели / офицеры", 128 },
        },
        sub = { "datetime", "location", "charges" },
        save = arrestSaveReport, del = arrestDeleteReport,
    },
    situ = {
        key = "situ", coll = "situationReports", name = "SITUATION", short = "SITUATIONS",
        newTitle = "Новый доклад об инциденте", editTitle = "Редактирование доклада об инциденте",
        tipTitle = "SITUATIONS", tip = "Все другие ситуации на смене.",
        sumTitle = "СВОДКА ИНЦИДЕНТА", descTitle = "ПОДРОБНОЕ ОПИСАНИЕ",
        titleExtra = "situationType",
        fields = {
            { "situationType", "Тип ситуации", 128 },  { "datetime", "Дата и время", 64 },
            { "location", "Место", 128 },              { "unitsInvolved", "Задействованные юниты", 128 },
            { "outcome", "Исход", 128 },               { "casualties", "Пострадавшие", 64 },
        },
        sub = { "datetime", "location", "outcome" },
        save = situSaveReport, del = situDeleteReport,
    },
}
M.KINDS = { "uof", "arrest", "situ" }

function M.rowInfo(kind, rep)
    local c = M.rowC[rep]
    if c then return c[1], c[2], c[3] end
    local K = M.K[kind]
    local title = K.name .. "  ·  " .. nz(rep.department) .. "  ·  " .. nz(rep.unit)
    if K.titleExtra and nz(rep[K.titleExtra], "") ~= "" then
        title = title .. "  |  " .. rep[K.titleExtra]
    end
    local parts = {}
    for _, f in ipairs(K.sub) do
        if nz(rep[f], "") ~= "" then parts[#parts + 1] = rep[f] end
    end
    local sub = table.concat(parts, "  ·  ")
    local all = { title, sub, rep.details or "", rep.officerNick or "" }
    for _, f in ipairs(K.fields) do all[#all + 1] = rep[f[1]] or "" end
    c = { u8(title), u8(sub ~= "" and sub or "-"), string.nlower(table.concat(all, " ")) }
    M.rowC[rep] = c
    return c[1], c[2], c[3]
end

function M.ensureBuf(kind)
    local B = M.bufs[kind]
    if not B then
        B = { details = imgui.new.char[2048]() }
        for _, f in ipairs(M.K[kind].fields) do B[f[1]] = imgui.new.char[f[3]]() end
        M.bufs[kind] = B
    end
    return B
end

function M.initForm(kind, idx)
    local K, B = M.K[kind], M.ensureBuf(kind)
    local rep  = idx and esoOfficerData[K.coll][idx] or nil
    for _, f in ipairs(K.fields) do
        ffi.fill(B[f[1]], f[3])
        local v = rep and rep[f[1]] or ""
        if not rep and f[1] == "datetime" then v = esoMskDate("%d.%m.%Y - %H:%M") end
        if v ~= "" then ffi.copy(B[f[1]], M.fit(u8(v), f[3] - 1)) end
    end
    ffi.fill(B.details, 2048)
    if rep and rep.details and rep.details ~= "" then ffi.copy(B.details, M.fit(u8(rep.details), 2047)) end
    M.form.kind, M.form.idx = kind, rep and idx or 0
    M.go("form", kind, M.form.idx)
end

function M.saveForm()
    local kind = M.form.kind
    local K, B = M.K[kind], M.bufs[kind]
    local o    = esoOfficerData
    local rep  = {}
    for _, f in ipairs(K.fields) do rep[f[1]] = u8:decode(ffi.string(B[f[1]])) end
    rep.details      = u8:decode(ffi.string(B.details))
    rep.department   = o.department
    rep.unit         = o.unit
    rep.officerBadge = o.badgeNumber
    rep.officerRank  = o.rank
    rep.officerNick  = (o.nickname:gsub("_", " "))

    local list, id = o[K.coll], 1
    local old = M.form.idx > 0 and list[M.form.idx] or nil
    if old then
        if old._file then rep._file = old._file end
        rep.syncId = old.syncId
        K.save(rep)
        list[M.form.idx] = rep
        id = M.form.idx
    else
        rep._file = ""
        K.save(rep)
        table.insert(list, 1, rep)
    end
    esoSyncPublish(kind, rep)
    M.rev = M.rev + 1
    M.go("read", kind, id)      
end

function M.viewList(kind)
    local K    = M.K[kind]
    local list = esoOfficerData[K.coll]
    local n    = #list

    M.pageHeader(T(K.name .. " REPORTS"), n .. " " .. T(M.plural(n, "доклад", "доклада", "докладов")),
        "main", nil, 150, function()
            if M.btn(L("+  NEW REPORT", "new_" .. kind), 150, 30, "primary") then M.initForm(kind) end
        end)

    local aw = imgui.GetContentRegionAvail().x
    M.searchBox("##srch_" .. kind, M.search, aw, T("Поиск по докладам..."))
    imgui.Spacing()

    -- фильтр пересобирается только при смене запроса / данных
    local needle = ffi.string(M.search)
    local F = M.filt
    if not F or F.kind ~= kind or F.rev ~= M.rev or F.n ~= n or F.needle ~= needle or F.list ~= list then
        local nd = needle ~= "" and string.nlower(u8:decode(needle)) or nil
        local idx = {}
        for i, rep in ipairs(list) do
            if not nd or select(3, M.rowInfo(kind, rep)):find(nd, 1, true) then idx[#idx + 1] = i end
        end
        F = { kind = kind, rev = M.rev, n = n, needle = needle, list = list, idx = idx }
        M.filt = F
    end

    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(0, 0))
    if imgui.BeginChild("##list_" .. kind, V2(0, 0), false) then
        if #F.idx == 0 then
            if n == 0 then M.empty(T("Докладов пока нет"), T("Нажмите NEW REPORT, чтобы создать первый"))
            else M.empty(T("Ничего не найдено"), T("Измените запрос")) end
        else
            local w = imgui.GetContentRegionAvail().x
            M.vlist(#F.idx, 63, function(j)
                local i   = F.idx[j]
                local rep = list[i]
                local title, sub = M.rowInfo(kind, rep)
                local badge = (rep.syncId and rep.syncId ~= "") and "SYNC" or nil
                if M.entry("##e_" .. kind .. "_" .. i, w, 56, kind, "#" .. (n - i + 1), title, sub, badge) then
                    M.go("read", kind, i)
                end
            end)
        end
    end
    imgui.EndChild()
    imgui.PopStyleVar()
end

function M.viewRead(kind, idx)
    local K    = M.K[kind]
    local list = esoOfficerData[K.coll]
    local rep  = list[idx]
    if not rep then M.go("list", kind); return end

    local C, dl = M.C, imgui.GetWindowDrawList()
    local num   = #list - idx + 1
    local armed = M.armed > os.clock()

    M.pageHeader(T(K.name .. " REPORT") .. "  #" .. num,
        T(nz(rep.department) .. "  ·  " .. nz(rep.unit) .. "  ·  " .. nz(rep.datetime, "")),
        "list", kind, 200, function()
            if armed then
                if M.btn(L("ОТМЕНА", "dno"), 92, 30, "ghost") then M.armed = 0 end
                imgui.SameLine(0, 8)
                if M.btn(L("УДАЛИТЬ?", "dyes"), 100, 30, "danger") then
                    esoSyncRetract(rep)
                    K.del(rep)
                    table.remove(list, idx)
                    M.rev = M.rev + 1
                    M.go("list", kind)
                end
            else
                if M.btn(L("EDIT", "edit"), 92, 30, "ghost") then M.initForm(kind, idx) end
                imgui.SameLine(0, 8)
                if M.btn(L("DELETE", "del"), 100, 30, "quiet") then M.armed = os.clock() + 4 end
            end
        end)

    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(0, 0))
    if imgui.BeginChild("##read_" .. kind, V2(0, 0), false) then
        local aw = imgui.GetContentRegionAvail().x
        local labelW = 170

        -- Автор на момент подачи
        M.section("ОФИЦЕР НА МОМЕНТ ПОДАЧИ")
        imgui.Spacing()
        local p = imgui.GetCursorScreenPos()
        local nick = nz(rep.officerNick)
        local ini  = T(nick:sub(1, 1):upper())
        dl:AddCircleFilled(V2(p.x + 17, p.y + 17), 17, M.U[kind .. "_soft"], 28)
        dl:AddCircle(V2(p.x + 17, p.y + 17), 17, M.U[kind], 28, 1.4)
        dl:AddText(V2(p.x + 17 - imgui.CalcTextSize(ini).x * 0.5, p.y + 10), M.U[kind], ini)
        imgui.SetCursorScreenPos(V2(p.x + 46, p.y))
        M.txt(C.text, T(nz(rep.officerRank, "") .. " " .. nick))
        imgui.SetCursorScreenPos(V2(p.x + 46, p.y + 19))
        M.txt(C.dim, T("Жетон #" .. nz(rep.officerBadge, "---") .. "  ·  " .. nz(rep.department) .. "  ·  " .. nz(rep.unit)))
        imgui.SetCursorScreenPos(V2(p.x, p.y + 44))
        if rep.syncId and rep.syncId ~= "" then
            M.txt(C.green, T("Опубликован в общей базе подразделений"))
        end
        imgui.Spacing(); imgui.Spacing()

        -- Сводка
        M.section(K.sumTitle)
        imgui.Spacing()
        for _, f in ipairs(K.fields) do
            local sp = imgui.GetCursorScreenPos()
            M.kv(f[2], T(nz(rep[f[1]])), labelW)
            local ep = imgui.GetCursorScreenPos()
            dl:AddLine(V2(sp.x, ep.y + 1), V2(sp.x + aw, ep.y + 1), M.U.sep, 1.0)
            imgui.Dummy(V2(1, 2))
        end
        imgui.Spacing(); imgui.Spacing()

        -- Описание
        M.section("ОПИСАНИЕ")
        imgui.Spacing()
        local d0 = imgui.GetCursorScreenPos()
        imgui.SetCursorScreenPos(V2(d0.x + 12, d0.y))
        imgui.PushTextWrapPos(imgui.GetCursorPosX() + aw - 12)
        local desc = nz(rep.details, "")
        if desc == "" then M.txt(C.faint, T("Описание не заполнено."))
        else M.txt(C.text, u8(desc)) end
        imgui.PopTextWrapPos()
        local d1 = imgui.GetCursorScreenPos()
        dl:AddRectFilled(V2(d0.x, d0.y), V2(d0.x + 3, d1.y), M.U[kind], 2)
        imgui.Dummy(V2(1, 12))
    end
    imgui.EndChild()
    imgui.PopStyleVar()
end

function M.viewForm(kind)
    local K, B = M.K[kind], M.ensureBuf(kind)
    local C, o = M.C, esoOfficerData
    local isEdit = M.form.idx > 0
    local backView, backId = "list", 0
    if isEdit then backView, backId = "read", M.form.idx end

    M.pageHeader(T(isEdit and K.editTitle or K.newTitle),
        T("Данные офицера подставляются автоматически"), backView, kind, 0, nil, backId)

    local footerH = 46
    local ah = imgui.GetContentRegionAvail().y
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(0, 0))
    if imgui.BeginChild("##form_" .. kind, V2(0, ah - footerH), false) then
        local aw = imgui.GetContentRegionAvail().x

        M.section("ОФИЦЕР")
        imgui.Spacing()
        M.txt(C.text, T(nz(o.rank, "") .. "  " .. (o.nickname:gsub("_", " "))))
        M.txt(C.dim, T("Жетон: " .. nz(o.badgeNumber) .. "  ·  Департамент: " .. nz(o.department)
            .. "  ·  Юнит: " .. nz(o.unit)))
        imgui.Spacing(); imgui.Spacing()

        M.section("ДЕТАЛИ")
        imgui.Spacing()
        local cols = aw >= 560 and 2 or 1
        imgui.Columns(cols, "##fc_" .. kind, false)
        for _, f in ipairs(K.fields) do
            M.txt(C.dim, T(f[2]))
            imgui.PushItemWidth(-1)
            imgui.InputText("##f_" .. kind .. f[1], B[f[1]], f[3])
            imgui.PopItemWidth()
            imgui.Spacing()
            imgui.NextColumn()
        end
        imgui.Columns(1)
        imgui.Spacing()

        M.section(K.descTitle)
        imgui.Spacing()
        local mh = math.max(150, imgui.GetContentRegionAvail().y - 30)
        imgui.InputTextMultiline("##fd_" .. kind, B.details, 2048, V2(-1, mh))
        local len = #ffi.string(B.details)
        M.txt(len > 1900 and C.yellow or C.faint, len .. " / 2047")
    end
    imgui.EndChild()
    imgui.PopStyleVar()

    -- Нижняя панель действий
    local dl = imgui.GetWindowDrawList()
    local p  = imgui.GetCursorScreenPos()
    dl:AddLine(V2(p.x, p.y + 2), V2(p.x + imgui.GetContentRegionAvail().x, p.y + 2), M.U.sep, 1.0)
    imgui.Dummy(V2(1, 6))
    if M.btn(L("СОХРАНИТЬ", "save_" .. kind), 150, 32, "success") then M.saveForm() end
    imgui.SameLine(0, 8)
    if M.btn(L("ОТМЕНА", "cancel_" .. kind), 110, 32, "ghost") then
        if isEdit then M.go("read", kind, M.form.idx) else M.go("list", kind) end
    end
end

M.HF = {
    { "badgeNumber", "BADGE",  "Номер вашего аккаунта / личного дела на форуме." },
    { "rank",        "RANK",   "Ваше текущее звание." },
    { "department",  "DEPT",   "Ваш департамент." },
    { "unit",        "UNIT",   "Ваше подразделение (патруль, спецназ и т.д.)." },
    { "assignment",  "ASSIGN", "Ваша должность в подразделении." },
}
M.DEPT_LIST = { "LSPD", "SFPD", "LVPD", "FBI" }

function M.isLocked(key)
    local lk = esoOfficerData.autoLocks
    return (lk and lk[key]) and true or false
end
M.editDept  = ""

function M.homeBegin()
    M.editBuf = {}
    for _, f in ipairs(M.HF) do
        if f[1] ~= "department" and not M.isLocked(f[1]) then
            local b = imgui.new.char[64]()
            ffi.copy(b, M.fit(u8(esoOfficerData[f[1]] or ""), 63))
            M.editBuf[f[1]] = b
        end
    end
    -- если текущее значение не из списка, выпадающий список стартует с "Не выбрано", а старое значение не трогаем
    M.editDept = ""
    for _, nm in ipairs(M.DEPT_LIST) do
        if esoOfficerData.department == nm then M.editDept = nm end
    end
    M.homeEdit = true
end

function M.homeApply()
    for _, f in ipairs(M.HF) do
        if f[1] ~= "department" and not M.isLocked(f[1]) and M.editBuf[f[1]] then
            esoOfficerData[f[1]] = u8:decode(ffi.string(M.editBuf[f[1]]))
        end
    end
    if M.editDept ~= "" and not M.isLocked("department") then esoOfficerData.department = M.editDept end
    officerSave()
    M.homeEdit = false
    M.rev = M.rev + 1
end

-- Последние доклады всех видов, по реальному времени (а не по строке даты)
function M.recents()
    local d = esoOfficerData
    local nu, na, ns = #d.uofReports, #d.arrestReports, #d.situationReports
    local R = M.rc
    if not R or R.rev ~= M.rev or R.nu ~= nu or R.na ~= na or R.ns ~= ns
        or R.u ~= d.uofReports or R.a ~= d.arrestReports or R.s ~= d.situationReports then
        local all = {}
        for _, kind in ipairs(M.KINDS) do
            for i, rep in ipairs(d[M.K[kind].coll]) do
                all[#all + 1] = { kind = kind, idx = i, ts = M.parseTs(rep.datetime), rep = rep }
            end
        end
        table.sort(all, function(a, b)
            if a.ts ~= b.ts then return a.ts > b.ts end
            if a.kind ~= b.kind then return a.kind < b.kind end
            return a.idx < b.idx
        end)
        R = { rev = M.rev, nu = nu, na = na, ns = ns, u = d.uofReports, a = d.arrestReports,
              s = d.situationReports, all = all }
        M.rc = R
    end
    return R.all
end

function M.officerCard(w, h)
    local C, U, d = M.C, M.U, esoOfficerData
    if M.beginCard("##officer", w, h) then
        local dl   = imgui.GetWindowDrawList()
        local p    = imgui.GetCursorScreenPos()
        local nick = d.nickname or ""
        local ini  = T(nick ~= "" and nick:sub(1, 1):upper() or "?")
        dl:AddCircleFilled(V2(p.x + 23, p.y + 23), 23, U.accent_soft, 32)
        dl:AddCircle(V2(p.x + 23, p.y + 23), 23, U.accent, 32, 1.5)
        dl:AddText(V2(p.x + 23 - imgui.CalcTextSize(ini).x * 0.5, p.y + 16), U.accent, ini)

        imgui.SetCursorScreenPos(V2(p.x + 58, p.y))
        M.big(C.text, T(nick ~= "" and (nick:gsub("_", " ")) or "N/A"), 1.15)
        imgui.SetCursorScreenPos(V2(p.x + 58, p.y + 26))
        M.txt(C.dim, T(nz(d.rank)))
        imgui.SetCursorScreenPos(V2(p.x, p.y + 62))

        if M.homeEdit then
            for _, f in ipairs(M.HF) do
              if M.isLocked(f[1]) then
                M.kv(f[2], T(nz(d[f[1]])), 66, f[3])
              else
                local x = imgui.GetCursorPosX()
                M.txt(C.dim, T(f[2]))
                M.tip(f[2], f[3])
                imgui.SameLine(x + 66)
                imgui.PushItemWidth(-1)
                if f[1] == "department" then
                    local cur = M.editDept
                    if imgui.BeginCombo("##home_dept", cur ~= "" and cur or T("Не выбрано")) then
                        for _, nm in ipairs(M.DEPT_LIST) do
                            if imgui.Selectable(nm .. "##dpt_" .. nm, cur == nm) then M.editDept = nm end
                        end
                        imgui.EndCombo()
                    end
                else
                    imgui.InputText("##home_" .. f[1], M.editBuf[f[1]], 64)
                end
                imgui.PopItemWidth()
              end
            end
            if next(d.autoLocks or {}) then
                M.txt(C.faint, T("BADGE, RANK и DEPT берутся из /st автоматически"))
            end
            imgui.Spacing()
            if M.btn(L("СОХРАНИТЬ", "h_save"), 110, 28, "success") then M.homeApply() end
            imgui.SameLine(0, 8)
            if M.btn(L("ОТМЕНА", "h_cancel"), 90, 28, "ghost") then M.homeEdit = false end
        else
            for _, f in ipairs(M.HF) do M.kv(f[2], T(nz(d[f[1]])), 66, f[3]) end
            imgui.Spacing()
            if M.btn(L("EDIT", "h_edit"), 90, 28, "ghost") then M.homeBegin() end
        end
    end
    imgui.EndChild()
end

function M.statsCard(w, h)
    local C, U, d = M.C, M.U, esoOfficerData
    if M.beginCard("##stats", w, h) then
        local dl = imgui.GetWindowDrawList()
        M.section("ДОКЛАДЫ", true)
        imgui.Spacing()
        local aw  = imgui.GetContentRegionAvail().x
        local gap = 8
        local tw  = math.floor((aw - gap * 2) / 3)
        local th  = 74
        local p   = imgui.GetCursorScreenPos()
        for i, kind in ipairs(M.KINDS) do
            local K  = M.K[kind]
            local n  = #d[K.coll]
            local x  = p.x + (i - 1) * (tw + gap)
            imgui.SetCursorScreenPos(V2(x, p.y))
            if imgui.InvisibleButton("##st_" .. kind, V2(tw, th)) then M.go("list", kind) end
            M.tip(K.tipTitle, K.tip)
            local hov = imgui.IsItemHovered()
            dl:AddRectFilled(V2(x, p.y), V2(x + tw, p.y + th), U[kind .. "_soft"], 8)
            dl:AddRect(V2(x, p.y), V2(x + tw, p.y + th), hov and U[kind] or U[kind .. "_mid"], 8, 15, hov and 1.6 or 1.0)
            imgui.SetCursorScreenPos(V2(x + 12, p.y + 6))
            M.big(M.KC[kind], tostring(n), 1.9)
            dl:AddText(V2(x + 12, p.y + th - 22), U.dim, K.short)
        end
        imgui.SetCursorScreenPos(V2(p.x, p.y + th + 10))
        for i, kind in ipairs(M.KINDS) do
            if i > 1 then imgui.SameLine(0, gap) end
            if M.btn(L("+  NEW", "q_" .. kind), tw, 28, "ghost") then M.initForm(kind) end
        end
        imgui.Spacing()
        M.txt(C.faint, T("Нажмите на плитку, чтобы открыть список"))
    end
    imgui.EndChild()
end

M.logC, M.logN = {}, 0
function M.logLine(line)
    local c = M.logC[line]
    if not c then
        if M.logN > 200 then M.logC, M.logN = {}, 0 end
        local ts, msg = line:match("^(%[.-%])%s*(.*)$")
        c = { u8(ts or ""), u8(msg or line), 0 }
        c[3] = imgui.CalcTextSize(c[1]).x
        M.logC[line] = c
        M.logN = M.logN + 1
    end
    return c[1], c[2], c[3]
end

function M.viewHome()
    local C, U, d = M.C, M.U, esoOfficerData
    M.pageHeader(T("Личное дело"), T("Сводка по службе, последние доклады и журнал событий"), nil, nil, 0, nil)

    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(0, 0))
    if imgui.BeginChild("##home_scroll", V2(0, 0), false) then
        local aw   = imgui.GetContentRegionAvail().x
        local wide = aw >= 650
        local gap  = 10
        local cardH = M.homeEdit and 300 or 236
        local lw   = wide and math.floor(aw * 0.40) or aw
        M.officerCard(lw, cardH)
        if wide then imgui.SameLine(0, gap) end
        M.statsCard(wide and (aw - lw - gap) or aw, wide and cardH or 176)

        imgui.Spacing()
        M.section("ПОСЛЕДНИЕ ДОКЛАДЫ")
        imgui.Spacing()
        local rc  = M.recents()
        local cnt = math.min(3, #rc)
        if cnt == 0 then
            M.txt(C.faint, T("Докладов пока нет. Создайте первый кнопкой + NEW."))
        else
            for j = 1, cnt do
                local r = rc[j]
                local title, sub = M.rowInfo(r.kind, r.rep)
                local n = #d[M.K[r.kind].coll]
                if M.entry("##rc" .. j, aw, 56, r.kind, "#" .. (n - r.idx + 1), title, sub) then
                    M.go("read", r.kind, r.idx)
                end
            end
        end

        imgui.Spacing()
        M.section("ЖУРНАЛ СОБЫТИЙ")
        imgui.Spacing()
        local log = d.eventLog
        local lh  = math.min(math.max(#log, 1) * 20 + 26, 210)
        if M.beginCard("##evlog", aw, lh, true) then
            if #log == 0 then
                M.txt(C.faint, T("Событий пока нет"))
            else
                local tsw = 0
                for _, line in ipairs(log) do
                    local _, _, w = M.logLine(line)
                    if w > tsw then tsw = w end
                end
                for _, line in ipairs(log) do
                    local ts, msg = M.logLine(line)
                    local x = imgui.GetCursorPosX()
                    M.txt(C.accent, ts)
                    imgui.SameLine(x + tsw + 12)
                    M.txt(C.text, msg)
                end
            end
        end
        imgui.EndChild()
        imgui.Dummy(V2(1, 8))
    end
    imgui.EndChild()
    imgui.PopStyleVar()
end

function M.routeHome()
    local nv = M.nav
    local kind = nv.kind
    if nv.view ~= "main" and not (kind and M.K[kind]) then M.go("main") end
    if     nv.view == "main" then M.viewHome()
    elseif nv.view == "list" then M.viewList(kind)
    elseif nv.view == "read" then M.viewRead(kind, nv.id)
    elseif nv.view == "form" then M.viewForm(kind)
    end
end


M.depts = { dept = nil, kind = nil, sel = nil, search = imgui.new.char[64](), F = nil }
M.DEPT_OPTS = {
    { t = "ALL", v = "ALL" }, { t = "LSPD", v = "LSPD" }, { t = "SFPD", v = "SFPD" },
    { t = "LVPD", v = "LVPD" }, { t = "FBI", v = "FBI" },
}
M.KIND_OPTS = {
    { t = "ALL", v = "ALL" }, { t = "UOF", v = "uof" }, { t = "ARREST", v = "arrest" }, { t = "SITU", v = "situ" },
}
M.DK_NAME = { uof = "UOF", arrest = "ARREST", situ = "SITUATION" }
M.DK_FIELDS = {
    uof = {
        { "datetime", "Дата и время" }, { "location", "Локация" }, { "weapon", "Оружие" },
        { "equipment", "Спецсредства" }, { "officersCount", "Кол-во офицеров" }, { "seniorOfficer", "Старший" },
    },
    arrest = {
        { "suspectName", "Подозреваемый" }, { "datetime", "Дата и время" }, { "charges", "Обвинения" },
        { "location", "Локация" }, { "forceUsed", "Сила" }, { "witnesses", "Свидетели" },
    },
    situ = {
        { "situationType", "Тип ситуации" }, { "datetime", "Дата и время" }, { "location", "Локация" },
        { "unitsInvolved", "Юниты" }, { "outcome", "Исход" }, { "casualties", "Пострадавшие" },
    },
}

function M.clip(s, n)
    s = tostring(s or "")
    local out, count = {}, 0
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > n then out[#out + 1] = "..."; break end
        out[#out + 1] = ch
    end
    return table.concat(out)
end

function M.msTime(ms)
    return esoMskDate("%d.%m.%Y %H:%M", math.floor((tonumber(ms) or 0) / 1000))
end

function M.deptInfo(it)
    local c = M.rowC[it]
    if c and c[4] == it.updated_at then return c[1], c[2], c[3] end
    local d   = it.data or {}
    local who = nz(d.officerNick, it.author or "")
    local title = "[" .. (M.DK_NAME[it.kind] or "?") .. "]  " .. (it.dept or "?") .. "  |  "
        .. nz(d.unit) .. "  |  " .. M.clip(who, 28)

    local sub = M.msTime(it.created_at) .. "  \194\183  " .. M.clip(d.location or "", 60)
    local all = { title, sub, d.details or "", who }
    for _, f in ipairs(M.DK_FIELDS[it.kind] or {}) do all[#all + 1] = d[f[1]] or "" end
    local joined = table.concat(all, " ")
    local ok, dec = pcall(function() return u8:decode(joined) end)
    c = { title, sub, string.nlower(ok and dec or joined), it.updated_at }
    M.rowC[it] = c
    return c[1], c[2], c[3]
end

function M.viewDeptsRead()
    local C, D = M.C, M.depts
    local it   = D.sel
    local d    = it.data or {}
    local dl   = imgui.GetWindowDrawList()
    local kind = M.K[it.kind] and it.kind or "accent"

    M.pageHeader(T(M.DK_NAME[it.kind] or "REPORT") .. " REPORT",
        nz(it.dept, "?") .. "  \194\183  " .. nz(d.unit), function() D.sel = nil end, nil, 0, nil)

    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(0, 0))
    if imgui.BeginChild("##depts_read", V2(0, 0), false) then
        local aw = imgui.GetContentRegionAvail().x
        M.section("АВТОР")
        imgui.Spacing()
        M.txt(C.text, (d.officerRank or "") .. " " .. (d.officerNick or it.author or ""))
        M.txt(C.dim, T("Жетон: ") .. nz(d.officerBadge, "---") .. "   " .. T("Опубликован (МСК): ") .. M.msTime(it.created_at)
            .. (((it.updated_at or 0) - (it.created_at or 0)) > 1000 and ("   " .. T("Изменён: ") .. M.msTime(it.updated_at)) or ""))
        imgui.Spacing(); imgui.Spacing()

        M.section("СВОДКА")
        imgui.Spacing()
        for _, f in ipairs(M.DK_FIELDS[it.kind] or {}) do
            local v = d[f[1]]
            if v and v ~= "" then
                M.kv(f[2], v, 160)
                local ep = imgui.GetCursorScreenPos()
                dl:AddLine(V2(ep.x, ep.y + 1), V2(ep.x + aw, ep.y + 1), M.U.sep, 1.0)
                imgui.Dummy(V2(1, 2))
            end
        end
        imgui.Spacing(); imgui.Spacing()

        M.section("ОПИСАНИЕ")
        imgui.Spacing()
        local d0 = imgui.GetCursorScreenPos()
        imgui.SetCursorScreenPos(V2(d0.x + 12, d0.y))
        imgui.PushTextWrapPos(imgui.GetCursorPosX() + aw - 12)
        if d.details and d.details ~= "" then M.txt(C.text, d.details)
        else M.txt(C.faint, T("Описание не заполнено.")) end
        imgui.PopTextWrapPos()
        local d1 = imgui.GetCursorScreenPos()
        dl:AddRectFilled(V2(d0.x, d0.y), V2(d0.x + 3, d1.y), M.U[kind], 2)
        imgui.Dummy(V2(1, 12))
    end
    imgui.EndChild()
    imgui.PopStyleVar()
end

function M.viewDepts()
    local C, D = M.C, M.depts
    if not sync then
        M.pageHeader(T("Отчёты подразделений"), T("Общая база сервера"), nil, nil, 0, nil)
        M.txt(C.dim, T("Модуль синхронизации не загружен (нужен moonloader/lib/eso_sync.lua)."))
        return
    end
    if D.sel then M.viewDeptsRead(); return end

    local rec = sync.getReports(D.dept, D.kind)

    if not rec.loading and not rec.err then
        if not rec.at or (os.clock() - rec.at) > 60 then sync.refreshReports(D.dept, D.kind) end
    end

    M.pageHeader(T("Отчёты подразделений"), T("Общая база сервера. Подразделение - только фильтр показа"),
        nil, nil, 120, function()
            if M.btn(L("REFRESH", "depts_refresh"), 120, 30, "ghost") then sync.refreshReports(D.dept, D.kind) end
        end)

    local aw = imgui.GetContentRegionAvail().x
    local r1 = M.segmented("dept", M.DEPT_OPTS, D.dept or "ALL")
    if r1 then D.dept = (r1 ~= "ALL") and r1 or nil; D.sel = nil end
    imgui.SameLine(0, 14)
    local r2 = M.segmented("kind", M.KIND_OPTS, D.kind or "ALL")
    if r2 then D.kind = (r2 ~= "ALL") and r2 or nil; D.sel = nil end
    imgui.Spacing()

    M.searchBox("##srch_depts", D.search, aw, T("Поиск по отчётам..."))
    local stt = sync.status()
    if rec.loading then M.txt(C.dim, T("Загрузка..."))
    elseif rec.err then M.txt(C.red, T("Ошибка: ") .. tostring(rec.err))
    else M.txt(C.faint, T("Отчётов: ") .. #rec.items .. (rec.more and "+" or "") .. "   [" .. tostring(stt.state) .. "]") end
    imgui.Spacing()

    local items  = rec.items
    local needle = ffi.string(D.search)
    local F = D.F
    if not F or F.items ~= items or F.n ~= #items or F.needle ~= needle or F.at ~= rec.at then
        local nd = needle ~= "" and string.nlower(u8:decode(needle)) or nil
        local idx = {}
        for i, it in ipairs(items) do
            if not nd or select(3, M.deptInfo(it)):find(nd, 1, true) then idx[#idx + 1] = i end
        end
        F = { items = items, n = #items, needle = needle, at = rec.at, idx = idx }
        D.F = F
    end

    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(0, 0))
    if imgui.BeginChild("##depts_list", V2(0, 0), false) then
        if #F.idx == 0 then
            M.empty(T(rec.loading and "Загрузка..." or "Ничего не найдено"), nil)
        else
            local w = imgui.GetContentRegionAvail().x
            M.vlist(#F.idx, 63, function(j)
                local it = items[F.idx[j]]
                local title, sub = M.deptInfo(it)
                local kcol = M.K[it.kind] and it.kind or "accent"
                if M.entry("##dc_" .. j, w, 56, kcol, nil, title, sub, it.mine and "MINE" or nil) then
                    D.sel = it
                end
            end)
            if rec.more then
                imgui.Spacing()
                if M.btn(L("LOAD MORE", "depts_more"), 160, 30, "ghost") then sync.moreReports(D.dept, D.kind) end
            end
        end
    end
    imgui.EndChild()
    imgui.PopStyleVar()
end

function M.link(label, url)
    imgui.PushStyleColor(imgui.Col.Text, M.C.accent)
    M.raw(label)
    imgui.PopStyleColor()
    local mn, mx = imgui.GetItemRectMin(), imgui.GetItemRectMax()
    local hov = imgui.IsItemHovered()
    imgui.GetWindowDrawList():AddLine(V2(mn.x, mx.y), V2(mx.x, mx.y), M.U.accent, hov and 2.0 or 1.0)
    if hov then
        pcall(imgui.SetMouseCursor, imgui.MouseCursor.Hand)
        imgui.SetTooltip(T("Скопировать ссылку на профиль Discord (Ctrl+V - вставить)"))
        if imgui.IsMouseClicked(0) then esoOpenUrl(url) end
    end
end

function M.viewAbout()
    local C, dl = M.C, imgui.GetWindowDrawList()
    M.pageHeader("ESO  //  EMERGENCY SERVICES OVERHAUL", T("Информация о скрипте"), nil, nil, 0, nil)

    local sc
    pcall(function() sc = thisScript() end)

    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(0, 0))
    if imgui.BeginChild("##about_scroll", V2(0, 0), false) then
        M.section("СКРИПТ")
        imgui.Spacing()
        M.kv("Версия", sc and T(tostring(sc.version)) or "?", 150)
        do
            local x = imgui.GetCursorPosX()
            M.txt(C.dim, T("Обратная связь"))
            imgui.SameLine(x + 150)
            M.txt(C.text, "DS: ")
            imgui.SameLine(0, 0)
            M.link("strangelovesendsherregards", "https://discord.com/users/980671613240496170")
        end
        M.kv("Lua", _VERSION, 150)
        M.kv("Время сессии", string.format("%.0f min", os.clock() / 60), 150)
        imgui.Spacing(); imgui.Spacing()

        M.section("МОДУЛИ БОРТКОМПЬЮТЕРА")
        imgui.Spacing()
        for i, app in ipairs(M.apps) do
            M.txt(C.accent, "[" .. i .. "]")
            imgui.SameLine()
            M.txt(C.text, app.label)
            imgui.SameLine()
            M.txt(C.faint, "id=" .. app.id)
        end
        imgui.Spacing(); imgui.Spacing()

        M.section("ПЛАНИРУЕМЫЕ МОДУЛИ")
        imgui.Spacing()
        for _, f in ipairs({
            "[INFO] Информация об офицере, статистика, логи",
            "[CAD] Диспетчер, обработка вызовов",
            "[VEH] Расширенная информация об опросе транспорта",
            "[FTO] Справочник и чек-лист для офицера академии",
            "[PENAL] Сборник УК, АК, ПК",
        }) do
            M.txt(C.accent, ">")
            imgui.SameLine()
            M.txt(C.text, T(f))
        end
        imgui.Spacing(); imgui.Spacing()

        M.section("ПРО ИММЕРСИВНОСТЬ")
        imgui.Spacing()
        local p0 = imgui.GetCursorScreenPos()
        imgui.SetCursorScreenPos(V2(p0.x + 12, p0.y))
        M.wrapped(C.dim, T("Основная функция скрипта реализована. Всё, что привносят обновления, начиная с v1.2, - "
            .. "лишь дополнительный функционал для иммерсивности. Использовать его или нет, решает сам игрок."))
        local p1 = imgui.GetCursorScreenPos()
        dl:AddRectFilled(V2(p0.x, p0.y), V2(p0.x + 3, p1.y), M.U.accent, 2)
        imgui.Spacing(); imgui.Spacing()

        M.section("ФАЙЛЫ")
        imgui.Spacing()
        M.txt(C.faint, T("Настройки:  " .. tostring(ESO_SETTINGS_FILE)))
        M.txt(C.faint, T("Личное дело: " .. tostring(ESO_OFFICER_FILE)))
        imgui.Dummy(V2(1, 12))
    end
    imgui.EndChild()
    imgui.PopStyleVar()
end

function M.clock()
    local t = os.time()
    if M.clockT ~= t then M.clockT, M.clockS = t, os.date("%H:%M") end
    return M.clockS
end

function M.syncInfo()
    local t = os.time()
    if M.syncT ~= t then
        M.syncT, M.syncTxt, M.syncOn = t, "SYNC OFF", false
        if sync then
            local ok, st = pcall(sync.status)
            if ok and type(st) == "table" then M.syncTxt = "SYNC " .. tostring(st.state or "?"):upper() end
            local ok2, en = pcall(sync.isEnabled)
            M.syncOn = (ok2 and en) and true or false
        end
    end
    return M.syncTxt, M.syncOn
end

function M.crumb()
    local nv, D = M.nav, M.depts
    local a, v, k, id = M.app, nv.view, nv.kind, nv.id
    local sel = D.sel
    local c = M.cr
    if c and c.a == a and c.v == v and c.k == k and c.id == id and c.sel == sel and c.f == M.form.idx then return c.s end
    local s = "HOME"
    if a == "depts" then s = sel and "DEPTS  /  REPORT" or "DEPTS"
    elseif a == "about" then s = "ABOUT"
    elseif v ~= "main" and k and M.K[k] then
        s = "HOME  /  " .. M.K[k].short
        if v == "read" then s = s .. "  /  #" .. #esoOfficerData[M.K[k].coll] - id + 1
        elseif v == "form" then s = s .. (M.form.idx > 0 and "  /  EDIT" or "  /  NEW") end
    end
    M.cr = { a = a, v = v, k = k, id = id, sel = sel, f = M.form.idx, s = s }
    return s
end

function M.drawHeader(dl, wp, ws, hh)
    local U, C = M.U, M.C
    dl:AddRectFilled(wp, V2(wp.x + ws.x, wp.y + hh), U.header, 9)
    dl:AddRectFilled(V2(wp.x, wp.y + 12), V2(wp.x + ws.x, wp.y + hh), U.header, 0)
    dl:AddLine(V2(wp.x, wp.y + hh), V2(wp.x + ws.x, wp.y + hh), U.accent_mid, 1.0)

    local lx, ly = wp.x + 14, wp.y + 9
    dl:AddRectFilled(V2(lx, ly), V2(lx + 22, ly + 22), U.accent_soft, 6)
    dl:AddRect(V2(lx, ly), V2(lx + 22, ly + 22), U.accent, 6, 15, 1.3)
    dl:AddText(V2(lx + 7, ly + 4), U.accent, "E")
    dl:AddText(V2(lx + 32, wp.y + 13), U.text, "ESO MDC")
    local leftEnd = lx + 32 + imgui.CalcTextSize("ESO MDC").x + 10
    local sub = T("МОБИЛЬНЫЙ ТЕРМИНАЛ ДАННЫХ")
    dl:AddText(V2(leftEnd, wp.y + 13), U.faint, sub)
    leftEnd = leftEnd + imgui.CalcTextSize(sub).x + 24

    local rx = wp.x + ws.x - 14
    imgui.SetCursorScreenPos(V2(rx - 26, wp.y + 7))
    if imgui.InvisibleButton("##mdc_close", V2(26, 26)) then M.setOpen(false) end
    local hov = imgui.IsItemHovered()
    if hov then dl:AddRectFilled(V2(rx - 26, wp.y + 7), V2(rx, wp.y + 33), U.red_mid, 7) end
    local cx, cy = rx - 13, wp.y + 20
    local xc = hov and U.text or U.dim
    dl:AddLine(V2(cx - 5, cy - 5), V2(cx + 5, cy + 5), xc, 1.8)
    dl:AddLine(V2(cx - 5, cy + 5), V2(cx + 5, cy - 5), xc, 1.8)
    rx = rx - 42

    local ct = M.clock()
    local cw = imgui.CalcTextSize(ct).x
    dl:AddText(V2(rx - cw, wp.y + 13), U.dim, ct)
    rx = rx - cw - 20

    local st, on = M.syncInfo()
    local sw = imgui.CalcTextSize(st).x
    dl:AddText(V2(rx - sw, wp.y + 13), on and U.green or U.faint, st)
    dl:AddCircleFilled(V2(rx - sw - 10, wp.y + 20), 3.5, on and U.green or U.faint, 10)
    rx = rx - sw - 32

    local nick = esoOfficerData.nickname or ""
    if nick ~= "" then
        local chip = T((nick:gsub("_", " ")) .. "  ·  #" .. nz(esoOfficerData.badgeNumber, "-"))
        local cw2 = imgui.CalcTextSize(chip).x + 22
        if rx - cw2 > leftEnd then
            dl:AddRectFilled(V2(rx - cw2, wp.y + 8), V2(rx, wp.y + 32), U.panel, 12)
            dl:AddRect(V2(rx - cw2, wp.y + 8), V2(rx, wp.y + 32), U.border, 12, 15, 1)
            dl:AddText(V2(rx - cw2 + 11, wp.y + 13), U.text, chip)
        end
    end
end

function M.drawSidebar(w, h)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(0, 0))
    imgui.PushStyleColor(M.childBg, M.C.side)
    imgui.BeginChild("##mdc_side", V2(w, h), false, M.noScroll)
    imgui.PopStyleColor(1)
    imgui.PopStyleVar(1)

    local dl, U = imgui.GetWindowDrawList(), M.U
    local iH = 68
    imgui.SetCursorPos(V2(0, 8))
    for _, app in ipairs(M.apps) do
        local p = imgui.GetCursorScreenPos()
        if imgui.InvisibleButton("##app_" .. app.id, V2(w, iH)) then
            if M.app == app.id then
                if app.id == "home" then M.go("main") end
                M.depts.sel = nil
            else
                M.app = app.id
                esoSettings.mdcOsLastApp = app.id
            end
        end
        local act, hov = (M.app == app.id), imgui.IsItemHovered()
        if act then
            dl:AddRectFilled(V2(p.x + 7, p.y + 3), V2(p.x + w - 7, p.y + iH - 3), U.accent_soft, 9)
            dl:AddRectFilled(V2(p.x, p.y + 14), V2(p.x + 3, p.y + iH - 14), U.accent, 2)
        elseif hov then
            dl:AddRectFilled(V2(p.x + 7, p.y + 3), V2(p.x + w - 7, p.y + iH - 3), U.panel, 9)
        end
        local col = act and U.accent or (hov and U.text or U.dim)
        M.icons[app.icon](dl, p.x + w * 0.5, p.y + 26, col)
        local lw = imgui.CalcTextSize(app.label).x
        dl:AddText(V2(p.x + (w - lw) * 0.5, p.y + 46), col, app.label)
    end
    imgui.EndChild()
end

function M.drawContent(w, h)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(20, 14))
    imgui.PushStyleColor(M.childBg, M.C.app)
    imgui.BeginChild("##mdc_content", V2(w, h), false, M.noScroll + M.padFlag)
    imgui.PopStyleColor(1)
    imgui.PopStyleVar(1)

    local app = M.app or "home"
    if     app == "home"  then M.routeHome()
    elseif app == "depts" then M.viewDepts()
    elseif app == "about" then M.viewAbout()
    end
    imgui.EndChild()
end

function M.drawStatus(dl, wp, ws, sh_)
    local U = M.U
    local y0 = wp.y + ws.y - sh_
    dl:AddRectFilled(V2(wp.x, y0), V2(wp.x + ws.x, wp.y + ws.y), U.header, 9)
    dl:AddRectFilled(V2(wp.x, y0), V2(wp.x + ws.x, y0 + 10), U.header, 0)
    dl:AddLine(V2(wp.x, y0), V2(wp.x + ws.x, y0), U.sep, 1.0)
    dl:AddText(V2(wp.x + 16, y0 + 6), U.dim, M.crumb())
    local hint = T("Alt+M или /mdc - закрыть")
    dl:AddText(V2(wp.x + ws.x - imgui.CalcTextSize(hint).x - 30, y0 + 6), U.faint, hint)
end

function M.tick()
    local now = os.clock()
    local dt  = now - (M.t0 or now)
    if dt > 0.1 then dt = 0.1 end
    M.t0 = now
    if M.open then M.alpha = math.min(1.0, M.alpha + dt * 7.0)
    else           M.alpha = math.max(0.0, M.alpha - dt * 7.0) end
end

function M.frame()
    if myHudFont == nil then return end
    M.tick()
    if M.alpha <= 0.001 then return end
    if M.uA ~= M.alpha then M.rebuildU() end

    local C, S = M.C, esoSettings
    local io   = imgui.GetIO()
    local sw, sh = io.DisplaySize.x, io.DisplaySize.y

    local w = tonumber(S.mdcOsWindowW) or -1
    local h = tonumber(S.mdcOsWindowH) or -1
    if w <= 0 then w = M.W end
    if h <= 0 then h = M.H end
    w, h = math.min(w, sw - 20), math.min(h, sh - 20)
    local x, y = tonumber(S.mdcOsWindowX) or -1, tonumber(S.mdcOsWindowY) or -1
    if x < 0 or x > sw - 80 then x = (sw - w) * 0.5 end   -- защита от окна за краем экрана
    if y < 0 or y > sh - 60 then y = (sh - h) * 0.5 end

    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, M.alpha)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 9.0)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(0, 0))
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 1.0)
    imgui.PushStyleColor(imgui.Col.WindowBg, C.bg)
    imgui.PushStyleColor(imgui.Col.Border, C.border)

    imgui.SetNextWindowPos(V2(x, y), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowSize(V2(w, h), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowSizeConstraints(V2(780, 480), V2(sw, sh))

    local flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoScrollbar
                + imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoCollapse
    if imgui.Begin("MDC_OS_MAIN", nil, flags) then
        local dl = imgui.GetWindowDrawList()
        local wp, ws = imgui.GetWindowPos(), imgui.GetWindowSize()
        -- запоминаем позицию и размер (на диск пишется при закрытии)
        if wp.x ~= S.mdcOsWindowX or wp.y ~= S.mdcOsWindowY then S.mdcOsWindowX, S.mdcOsWindowY = wp.x, wp.y end
        if ws.x ~= S.mdcOsWindowW or ws.y ~= S.mdcOsWindowH then S.mdcOsWindowW, S.mdcOsWindowH = ws.x, ws.y end

        imgui.PushFont(myHudFont)
        imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 6.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.ScrollbarSize, 9.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.ScrollbarRounding, 6.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.GrabRounding, 4.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.PopupRounding, 7.0)
        imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, V2(9, 5))
        imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, V2(8, 7))
        imgui.PushStyleColor(imgui.Col.FrameBg,              v4(0.045, 0.054, 0.074))
        imgui.PushStyleColor(imgui.Col.FrameBgHovered,       v4(0.075, 0.092, 0.128))
        imgui.PushStyleColor(imgui.Col.FrameBgActive,        v4(0.090, 0.112, 0.160))
        imgui.PushStyleColor(imgui.Col.ScrollbarBg,          v4(0, 0, 0, 0))
        imgui.PushStyleColor(imgui.Col.ScrollbarGrab,        v4(1, 1, 1, 0.14))
        imgui.PushStyleColor(imgui.Col.ScrollbarGrabHovered, v4(1, 1, 1, 0.24))
        imgui.PushStyleColor(imgui.Col.ScrollbarGrabActive,  v4(1, 1, 1, 0.34))
        imgui.PushStyleColor(imgui.Col.Separator,            C.sep)
        imgui.PushStyleColor(imgui.Col.Text,                 C.text)
        imgui.PushStyleColor(imgui.Col.TextSelectedBg,       v4(0.30, 0.60, 1.00, 0.35))
        imgui.PushStyleColor(imgui.Col.PopupBg,              v4(0.070, 0.083, 0.115, 0.98))
        imgui.PushStyleColor(imgui.Col.Header,               v4(0.30, 0.60, 1.00, 0.20))
        imgui.PushStyleColor(imgui.Col.HeaderHovered,        v4(0.30, 0.60, 1.00, 0.32))
        imgui.PushStyleColor(imgui.Col.HeaderActive,         v4(0.30, 0.60, 1.00, 0.45))
        imgui.PushStyleColor(imgui.Col.Button,               v4(1, 1, 1, 0.06))
        imgui.PushStyleColor(imgui.Col.ButtonHovered,        v4(1, 1, 1, 0.12))
        imgui.PushStyleColor(imgui.Col.ButtonActive,         v4(1, 1, 1, 0.18))

        local HEADER_H, STATUS_H, SIDE_W = 40, 26, 86
        local bodyH = ws.y - HEADER_H - STATUS_H
        M.drawHeader(dl, wp, ws, HEADER_H)
        imgui.SetCursorPos(V2(0, HEADER_H))
        M.drawSidebar(SIDE_W, bodyH)
        imgui.SetCursorPos(V2(SIDE_W, HEADER_H))
        M.drawContent(ws.x - SIDE_W, bodyH)
        M.drawStatus(dl, wp, ws, STATUS_H)

        imgui.PopStyleColor(17)
        imgui.PopStyleVar(7)
        imgui.PopFont()
    end
    imgui.End()
    imgui.PopStyleColor(2)
    imgui.PopStyleVar(4)
end

M.ui = imgui.OnFrame(
    function() return M.open or M.alpha > 0.01 end,
    function() M.frame() end
)
M.ui.LockPlayer = false
M.ui.HideCursor = false

lua_thread.create(function()
    while true do
        wait(0)
        if isKeyDown(VK_LMENU) and isKeyJustPressed(0x4D)           -- Alt + M
            and not sampIsChatInputActive()
            and not isSampfuncsConsoleActive()
            and isInServiceVehicle(PLAYER_PED)
        then
            M.setOpen(not M.open)
        elseif M.open and not isInServiceVehicle(PLAYER_PED) then
            M.setOpen(false)         
        end
    end
end)

sampRegisterChatCommand("mdc", function()
    if not isInServiceVehicle(PLAYER_PED) then
        sampAddChatMessage("[ESO] MDC доступен только в служебном транспорте.", 0xFF6A00)
        return
    end
    M.setOpen(not M.open)
end)

end -- MDC OS 2.0

-- ==================== Проверка на сервер (имгуи) ====================

local esoWarnUI = imgui.OnFrame(
    function() return #esoWarnings > 0 and os.clock() < esoWarnShowUntil end,
    function()
        if myHudFont == nil then return end
        local now = os.clock()
        for i = #esoWarnings, 1, -1 do
            if now >= esoWarnings[i].expire then table.remove(esoWarnings, i) end
        end
        if #esoWarnings == 0 then return end

        local io_    = imgui.GetIO()
        local sw, sh = io_.DisplaySize.x, io_.DisplaySize.y
        local warnW  = 420
        local lineH  = 22
        local padV   = 10
        local totalH = #esoWarnings * lineH + padV * 2

        imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding,  6.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 1.2)
        imgui.PushStyleVarVec2 (imgui.StyleVar.WindowPadding,   imgui.ImVec2(14, padV))
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.10, 0.06, 0.02, 0.93))
        imgui.PushStyleColor(imgui.Col.Border,   imgui.ImVec4(0.80, 0.45, 0.05, 0.80))
        imgui.SetNextWindowSize(imgui.ImVec2(warnW, totalH), imgui.Cond.Always)
        imgui.SetNextWindowPos(
            imgui.ImVec2(sw * 0.5 - warnW * 0.5, sh - totalH - 80),
            imgui.Cond.Always
        )
        local wFlags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize
                     + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoMove
                     + imgui.WindowFlags.NoScrollbar
        if imgui.Begin("ESO_WARN", nil, wFlags) then
            imgui.PushFont(myHudFont)
            local dl    = imgui.GetWindowDrawList()
            local pulse = 0.75 + math.sin(os.clock() * 3.0) * 0.20
            for _, w in ipairs(esoWarnings) do
                local lp = imgui.GetCursorScreenPos()
                dl:AddRectFilled(
                    imgui.ImVec2(lp.x - 14, lp.y - 1),
                    imgui.ImVec2(lp.x - 10, lp.y + 15),
                    imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.0, 0.55, 0.05, pulse)), 2.0
                )
                imgui.TextColored(imgui.ImVec4(1.00, 0.55, 0.05, pulse), u8("[!] "))
                imgui.SameLine()
                imgui.TextColored(imgui.ImVec4(0.98, 0.82, 0.55, 1.0), w.text)
            end
            imgui.PopFont()
            imgui.End()
        end
        imgui.PopStyleColor(2)
        imgui.PopStyleVar(3)
    end
)
esoWarnUI.LockPlayer = false
esoWarnUI.HideCursor = true

-- ==================== /ESOHELP ====================

local esoHelpUI = imgui.OnFrame(
    function() return esoHelpOpen end,
    function()
        if myHudFont == nil then return end

        imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding,  8.0)
        imgui.PushStyleVarVec2 (imgui.StyleVar.WindowPadding,   imgui.ImVec2(14, 12))
        imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 1.2)
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.05, 0.06, 0.08, 0.97))
        imgui.PushStyleColor(imgui.Col.Border,   imgui.ImVec4(0.20, 0.22, 0.28, 0.90))

        imgui.SetNextWindowSize(imgui.ImVec2(500, 460), imgui.Cond.Always)
        imgui.SetNextWindowPos(
            imgui.ImVec2(
                imgui.GetIO().DisplaySize.x * 0.5 - 210,
                imgui.GetIO().DisplaySize.y * 0.5 - 230
            ),
            imgui.Cond.FirstUseEver
        )

        local wFlags = imgui.WindowFlags.NoTitleBar
                     + imgui.WindowFlags.NoResize
                     + imgui.WindowFlags.NoCollapse
                     + imgui.WindowFlags.NoScrollbar

        if imgui.Begin('ESO_HELP', nil, wFlags) then
            imgui.PushFont(myHudFont)
            local dl = imgui.GetWindowDrawList()
            local ww = imgui.GetWindowSize().x

            local hcp = imgui.GetCursorScreenPos()
            dl:AddRectFilled(
                imgui.ImVec2(hcp.x - 14, hcp.y - 12),
                imgui.ImVec2(hcp.x + ww,  hcp.y + 20),
                imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.07, 0.13, 0.24, 1.0)), 0.0
            )
            local titleText = 'ESO  //  EMERGENCY SERVICES OVERHAUL'
            local titleW = imgui.CalcTextSize(titleText).x
            imgui.SetCursorPosX((ww - titleW) * 0.5)
            imgui.TextColored(imgui.ImVec4(0.45, 0.72, 1.00, 1.0), titleText)
            imgui.SameLine(ww - 30)
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.0,  0.0,  0.0,  0.0))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.6,  0.1,  0.1,  0.6))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.8,  0.1,  0.1,  0.8))
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0.70, 0.30, 0.30, 1.0))
            if imgui.Button('X##close_eso', imgui.ImVec2(20, 16)) then
                esoHelpOpen = false
            end
            imgui.PopStyleColor(4)

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            local authorText = 'by Weisez~   |   v1.3 MDC extended p2'
            local authorW = imgui.CalcTextSize(authorText).x
            imgui.SetCursorPosX((ww - authorW) * 0.5)
            imgui.TextColored(imgui.ImVec4(0.30, 0.33, 0.38, 1.0), authorText)
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            local tabs = { u8('О СКРИПТЕ'), u8('КОМАНДЫ'), u8('ОСОБЕННОСТИ'), u8('МАРКИРОВКИ') }
            local tabBg = {
                imgui.ImVec4(0.18, 0.14, 0.26, 0.95),
                imgui.ImVec4(0.10, 0.22, 0.40, 0.95),
                imgui.ImVec4(0.08, 0.28, 0.18, 0.95),
                imgui.ImVec4(0.28, 0.22, 0.05, 0.95),
            }
            local tabFg = {
                imgui.ImVec4(0.85, 0.75, 1.00, 1.0),
                imgui.ImVec4(0.72, 0.88, 1.00, 1.0),
                imgui.ImVec4(0.70, 1.00, 0.80, 1.0),
                imgui.ImVec4(1.00, 0.90, 0.55, 1.0),
            }
            local itemSpX = imgui.GetStyle().ItemSpacing.x
            local tabW = (imgui.GetContentRegionAvail().x - itemSpX * 3) / 4
            for i = 1, 4 do
                if i > 1 then imgui.SameLine() end
                local active = (esoHelpTab == i)
                if active then
                    imgui.PushStyleColor(imgui.Col.Button,        tabBg[i])
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, tabBg[i])
                    imgui.PushStyleColor(imgui.Col.Text,          tabFg[i])
                else
                    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.10, 0.11, 0.14, 0.60))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.14, 0.16, 0.20, 0.80))
                    imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0.40, 0.42, 0.46, 1.0))
                end
                if imgui.Button(tabs[i] .. '##t' .. i, imgui.ImVec2(tabW, 20)) then
                    esoHelpTab = i
                end
                imgui.PopStyleColor(3)
            end

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            local childH = imgui.GetContentRegionAvail().y
            if imgui.BeginChild('##eso_content', imgui.ImVec2(0, childH), false) then

            if esoHelpTab == 1 then
                local C_DIM  = imgui.ImVec4(0.28, 0.30, 0.34, 1.0)
                local C_TXT  = imgui.ImVec4(0.70, 0.72, 0.76, 1.0)
                local C_ACC  = imgui.ImVec4(0.85, 0.75, 1.00, 1.0)

                local function asection(lbl)
                    imgui.Spacing()
                    imgui.TextColored(C_DIM, lbl)
                    imgui.Spacing()
                end

                imgui.TextColored(C_ACC, u8('Emergency Services Overhaul'))
                imgui.TextColored(C_TXT, u8('  by Weisez~   |   v2 ESO SYNC'))
                imgui.Spacing()
                imgui.Separator()

                asection(u8('ОПИСАНИЕ'))
                imgui.TextColored(C_TXT, u8('  ESO - многофункциональный скрипт для'))
                imgui.TextColored(C_TXT, u8('  привнесения иммерсивности при'))
                imgui.TextColored(C_TXT, u8('  отыгрыше экстренных служб.'))

                asection(u8('КЛЮЧЕВЫЕ МОДУЛИ'))
                imgui.TextColored(C_TXT, u8('  > Сирена -- статусы MAN/STBY/RAD + Horn'))
                imgui.TextColored(C_TXT, u8('  > Звуки -- рация, взаимодействия, диспетчер'))
                imgui.TextColored(C_TXT, u8('  > Каллсигны -- /vsign, маркировки юнитов'))
                imgui.TextColored(C_TXT, u8('  > SITREP-алерты -- Коды, ситуации, вызов 911'))
                imgui.TextColored(C_TXT, u8('  > Борткомпьютер -- Alt+B, опрос авто (LMB)'))
				imgui.TextColored(C_TXT, u8('  > Мобильный терминал -- Alt+M, статистика и доклады'))

                asection(u8('СПРАВКА'))
                imgui.TextColored(C_TXT, u8('  Навигация по вкладкам: КОМАНДЫ / ОСОБЕННОСТИ /'))
                imgui.TextColored(C_TXT, u8('  МАРКИРОВКИ. Закрыть: /esohelp или кнопка [X].'))

            elseif esoHelpTab == 2 then
                local C_KEY  = imgui.ImVec4(0.90, 0.75, 0.35, 1.0)
                local C_DESC = imgui.ImVec4(0.72, 0.74, 0.78, 1.0)
                local C_DIM  = imgui.ImVec4(0.28, 0.30, 0.34, 1.0)

                local function section(lbl)
                    imgui.Spacing()
                    imgui.TextColored(C_DIM, lbl)
                    imgui.Spacing()
                end
                local function row(cmd, desc)
                    local rp = imgui.GetCursorScreenPos()
                    local rw = imgui.GetContentRegionAvail().x
                    dl:AddRectFilled(
                        imgui.ImVec2(rp.x - 4, rp.y - 2),
                        imgui.ImVec2(rp.x + rw + 4, rp.y + 14),
                        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.08,0.09,0.12,0.55)), 3.0)
                    imgui.TextColored(C_KEY, cmd)
                    imgui.SameLine(140)
                    imgui.TextColored(C_DESC, desc)
                end

                section(u8'ЮНИТЫ & РАЦИЯ')
                row('/setunit [unit]',  u8('Установить юнит для рации (напр.: 3A19)'))
                -- row(u8'Важно:',         u8('Юнит устанавливается сам при посадке в авто.'))
                row('/rr [msg]',        u8('Отправить /r с префиксом юнита'))
                row('/ff [msg]',        u8('Отправить /f с префиксом юнита'))

                section(u8'МАРКИРОВКИ')
                row('/vsign [text]', u8('Установить маркировку на авто '))
                row('/vsign reset ([id])',  u8('Сбросить на стандартную (ID машины - опционально)'))

                section(u8'Сирена  [в машине]')
                row('[X]',      u8('Вкл / Выкл сирену (MAN)'))
                row('[L]', u8('Вкл / Выкл тихую сирену (только с AVS/AELS/Model Extras)'))
                row(u8'Важно:', u8('В конфиге конкретного мода необходимо поменять хоткей тихой сирены'))
                row('[H]',      u8('Усилитель (удержать)'))

                section(u8'Борткомпьютер  [в машине]')
                row('[Alt+B]',  u8('Открыть БК'))
                row('[LMB]',    u8('Опросить машину под курсором'))
                row('[-]',      u8('Опросить машину перед своей машиной (быстрый скан)'))
                row('[DEL]',    u8('Закрыть БК'))
				row('[Alt+M]',  u8('Открыть MDC (/mdc)'))
                section(u8'Помощь')
                row('/esohelp', u8('Открыть / закрыть эту справку'))

            elseif esoHelpTab == 3 then
                local C_IC  = imgui.ImVec4(0.35, 0.80, 0.55, 1.0)
                local C_TXT = imgui.ImVec4(0.70, 0.72, 0.76, 1.0)
                local C_DIM = imgui.ImVec4(0.28, 0.30, 0.34, 1.0)
                local function section(lbl)
                    imgui.Spacing()
                    imgui.TextColored(C_DIM, lbl)
                    imgui.Spacing()
                end
                local function feat(txt)
                    imgui.TextColored(C_IC,  '>')
                    imgui.SameLine()
                    imgui.TextColored(C_TXT, txt)
                end

                section(u8'FEDERAL SIGNAL AMPLIFIER (Сигнальная громкоговорящая установка)')
                feat(u8('Панель системы: STBY / RAD / MAN / HORN'))
                feat(u8('Сирены выключены / Тихая сирена / Стандартная сирена / Усилитель (гудок)'))
                feat(u8('Индикаторы ENG / ELC / BDY / TRS'))
                feat(u8('Позволяют отслеживать состояние автомобиля:'))
                feat(u8('Двигатель / Электроника / Кузов / Шины'))

                section(u8('ЗВУКОВОЕ ОФОРМЛЕНИЕ'))
                feat(u8('Звук включения сирены'))
                feat(u8('Звуковое сопровождение рации, эмбиенты (в машине и в департаменте)'))
                feat(u8('При взаимодействиях (наручники, обыск, арест и т.д.)'))
                feat(u8('Диспечер: 911, ограбление, трафик-стоп, опасная ситуация'))

                section(u8('Коды ситуаций'))
                feat(u8('CODE 3  --  стандартная ситуация'))
                feat(u8('CODE 1  --  опасная ситуация'))
                feat(u8('CODE 0  --  офицер под угрозой'))
                feat(u8('Вызов 911  -- нажмите [Y] для ответа на вызов'))
                feat(u8('HIGH RISK SITUATION  -- теракт/похищение/захват заложников'))

                section(u8'Борткомпьютер')
                feat(u8('[Alt+B] в авто: включить режим борткомпьютера'))
                feat(u8('[ЛКМ]: опрос модели, номера, скорости, маркировки и принадлежности авто'))
                feat(u8('[-]: быстрый опрос впередистоящего транспорта'))
                feat(u8('[DEL]: принудительное закрытие борткомпьютера'))
				feat(u8('[Alt+M]: открыть MDC, позволяет смотреть и дополнять статистику'))

            elseif esoHelpTab == 4 then
                local C_DIM  = imgui.ImVec4(0.28, 0.30, 0.34, 1.0)
                local C_GRAY = imgui.ImVec4(0.58, 0.60, 0.63, 1.0)

                imgui.TextColored(C_DIM, u8('СТАНДАРТНЫЙ ФОРМАТ: [1-3][A|M|H|S][00-99]  +  " | LS/SF/LV-ES" (опц.)'))
                imgui.TextColored(C_DIM, u8('ПРИМЕР: 3A19 | LV-ES  /  2H99 | SF-ES  /  1M30 | LS-ES'))
                imgui.Spacing()

                local depts = {
                    { lbl='LS-ES (1xx)', bg=imgui.ImVec4(0.10,0.22,0.40,0.88), fg=imgui.ImVec4(0.72,0.88,1.00,1.0), units='1A10-1A21  1M30-1M34  1H99  1S01+' },
                    { lbl='SF-ES (2xx)', bg=imgui.ImVec4(0.08,0.28,0.18,0.88), fg=imgui.ImVec4(0.70,1.00,0.80,1.0), units='2A10-2A21  2M30-2M34  2H99  2S01+' },
                    { lbl='LV-ES (3xx)', bg=imgui.ImVec4(0.30,0.24,0.05,0.88), fg=imgui.ImVec4(1.00,0.92,0.60,1.0), units='3A10-3A16  3M30-3M34  3H99  3S01-3S05' },
                    { lbl='SPECIAL',     bg=imgui.ImVec4(0.20,0.14,0.35,0.88), fg=imgui.ImVec4(0.88,0.80,1.00,1.0), units='SKYHAWK  TACTICAL  SPECIAL  UTILITY' },
                }
                for _, d in ipairs(depts) do
                    local bp = imgui.GetCursorScreenPos()
                    local bw = imgui.CalcTextSize(d.lbl).x
                    dl:AddRectFilled(
                        imgui.ImVec2(bp.x - 5, bp.y - 2),
                        imgui.ImVec2(bp.x + bw + 5, bp.y + 14),
                        imgui.ColorConvertFloat4ToU32(d.bg), 3.0)
                    imgui.TextColored(d.fg, d.lbl)
                    imgui.SameLine(110)
                    imgui.TextColored(C_GRAY, d.units)
                    imgui.Spacing()
                end

                imgui.Separator()
                imgui.Spacing()
				imgui.TextColored(C_DIM, u8('Cпециальные маркировки: TACTICAL (1-3) - биркет, SPECIAL - энфорсер,'))
				imgui.TextColored(C_DIM, u8('SKYHAWK (1-3) - вертолёт, UTILITY - Towtruck'))
                imgui.Spacing()
                imgui.TextColored(C_DIM, u8('СУФФИКС: " | LS-ES"  " | SF-ES"  " | LV-ES"  -- не влияет на цвет'))
                imgui.Spacing()
                imgui.TextColored(C_DIM, u8('/vsign reset  --  восстановить стандартный каллсигн'))
                imgui.Spacing()
                imgui.TextColored(C_DIM, u8('A(DAM) - юнит из 2-3 офицеров, M(ARY) - юнит на мотоцикле'))
                imgui.Spacing()
                imgui.TextColored(C_DIM, u8('H(ENRY) - высокоскоростной юнит, S(PECIAL) - спецюнит (супервайзер и т.д.)'))
            end

            imgui.Spacing()
            end
            imgui.EndChild()
            imgui.PopFont()
            imgui.End()
        end

        imgui.PopStyleColor(2)
        imgui.PopStyleVar(3)
    end
)
esoHelpUI.LockPlayer = false
esoHelpUI.HideCursor = false
