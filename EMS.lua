script_name("Emergency Services Overhaul")
script_description("Многофункциональный скрипт для привнесения иммерсивности при отыгрыше экстренных служб")
script_author("Weisez~")
script_version("v1.3 MDC extended p2")

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

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    wait(300)
    
    local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    playerNickname = sampGetPlayerNickname(myId)
    playerNickname = playerNickname:gsub(' ', '_')

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
                sampAddChatMessage("[ESO] Юнит не задан. Пример: /setunit 3A19 | LV-ES", -1)
            end
            return
        end
        currentUnit = arg:upper()
        sampAddChatMessage("[ESO] Юнит установлен: " .. currentUnit, 0x00BFFF)
    end)

    sampRegisterChatCommand("rr", function(arg)
        if currentUnit == "" then
            sampAddChatMessage("[ESO] Юнит не задан. Пример: /setunit 3A19 | LV-ES", -1)
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
            sampAddChatMessage("[ESO] Юнит не задан. Пример: /setunit 3A19 | LV-ES", -1)
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
                        setVirtualKeyDown(VK_RSHIFT, true) wait(50) setVirtualKeyDown(VK_RSHIFT, false) wait(50)
                    end
                    if SirenToggle then setAudioStreamState(SirenToggle, ev.PLAY) end
                    wait(300)
                    switchCarSiren(currentCar, true)
                    sirenMode = 2
                    lastVehicleSiren = 2
                end
            end

            if wasKeyPressed(VK_RSHIFT) and not sampIsChatInputActive() and not isSampfuncsConsoleActive() then
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

            sampSendChat("/n #VSIGN# " .. sampVehicleId .. " | " .. cleanText)
            
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
    mdcOsLastApp = "home",
}

local esoOfficerData = {
    nickname    = "",
    badgeNumber = "N/A",
    rank        = "Officer",
    department  = "N/A",
    unit        = "N/A",
    assignment  = "N/A",
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
    if s.mdcOsLastApp then esoSettings.mdcOsLastApp = tostring(s.mdcOsLastApp) end
    print("[ESO] [INI] Настройки загружены.")
end

local function settingsSave()
    local d = { settings = {
        mdcOsWindowX = esoSettings.mdcOsWindowX,
        mdcOsWindowY = esoSettings.mdcOsWindowY,
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
    iniSave(filepath, d)
    print("[ESO] [SITU] Отчёт сохранён: " .. filepath)
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


-- ¦                    MDC OS  CORE                         ¦

local mdcOsOpen       = false
local mdcOsAlpha      = 0.0
local mdcOsActiveApp  = nil
local mdcOsTaskbarTime= ""

local MDC_OS_W = 860
local MDC_OS_H = 540

local MDC_COL = {
    bg          = imgui.ImVec4(0.06, 0.07, 0.09, 0.98),
    header      = imgui.ImVec4(0.08, 0.10, 0.14, 1.00),
    headerText  = imgui.ImVec4(0.45, 0.72, 1.00, 1.00),
    taskbar     = imgui.ImVec4(0.04, 0.05, 0.07, 1.00),
    taskbarText = imgui.ImVec4(0.55, 0.60, 0.68, 1.00),
    sidebar     = imgui.ImVec4(0.05, 0.06, 0.08, 1.00),
    appBg       = imgui.ImVec4(0.07, 0.09, 0.11, 1.00),
    accent      = imgui.ImVec4(0.25, 0.55, 1.00, 1.00),
    accentDim   = imgui.ImVec4(0.15, 0.25, 0.50, 0.70),
    textMain    = imgui.ImVec4(0.85, 0.87, 0.90, 1.00),
    textDim     = imgui.ImVec4(0.38, 0.40, 0.45, 1.00),
    textLabel   = imgui.ImVec4(0.45, 0.48, 0.54, 1.00),
    iconBg      = imgui.ImVec4(0.10, 0.13, 0.18, 0.85),
    iconBgHov   = imgui.ImVec4(0.15, 0.20, 0.32, 0.95),
    iconBgSel   = imgui.ImVec4(0.20, 0.40, 0.80, 0.80),
    sep         = imgui.ImVec4(0.14, 0.16, 0.20, 1.00),
    green       = imgui.ImVec4(0.25, 0.80, 0.40, 1.00),
    red         = imgui.ImVec4(0.90, 0.25, 0.20, 1.00),
    yellow      = imgui.ImVec4(1.00, 0.85, 0.20, 1.00),
    closeBtn    = imgui.ImVec4(0.70, 0.20, 0.20, 0.85),
    closeBtnHov = imgui.ImVec4(0.90, 0.25, 0.20, 1.00),
}

local function mdcCol(v4)
    return imgui.ColorConvertFloat4ToU32(v4)
end

-- ¦              МОДУЛЬНАЯ СИСТЕМА               ¦

local MDC_APPS = {
    { id = "home",  label = "HOME",     icon = "[H]" },
    { id = "about", label = "ABOUT",    icon = "[?]" },
    -- { id = "cad",   label = "CAD",      icon = "[C]" },
    -- { id = "veh",   label = "VEH",      icon = "[V]" },
    -- { id = "fto",   label = "FTO",      icon = "[F]" },
    -- { id = "penal", label = "PENAL",    icon = "[P]" },
}
-- ¦           ПРИЛОЖЕНИЕ: HOME (Информация об офицере)      ¦

local HOME_VIEW_MAIN          = 0
local HOME_VIEW_UOF_LIST      = 1
local HOME_VIEW_UOF_READ      = 2
local HOME_VIEW_UOF_FORM      = 3
local HOME_VIEW_ARREST_LIST   = 4
local HOME_VIEW_ARREST_READ   = 5
local HOME_VIEW_ARREST_FORM   = 6
local HOME_VIEW_SITU_LIST     = 7
local HOME_VIEW_SITU_READ     = 8
local HOME_VIEW_SITU_FORM     = 9

local homeCurrentView    = HOME_VIEW_MAIN
local homeEditMode       = false
local homeEditBuf        = {}
local HOME_FIELDS        = { "badgeNumber", "rank", "department", "unit", "assignment" }
local HOME_LABELS        = { "BADGE:", "RANK:", "DEPT.:", "UNIT:", "ASSIGN.:" }

-- Стейты для UOF
local currentUofId = 0
local uofEditMode  = false
local uofBuf       = nil

-- Стейты для ARRESTS
local currentArrestId = 0
local arrestEditMode  = false
local arrestBuf       = nil

-- Стейты для SITUATIONS
local currentSituId = 0
local situEditMode  = false
local situBuf       = nil

local function homeInitEditBuf()
    local ffi = require 'ffi'
    homeEditBuf = {
        badgeNumber = imgui.new.char[64](u8(esoOfficerData.badgeNumber)),
        rank        = imgui.new.char[64](u8(esoOfficerData.rank)),
        department  = imgui.new.char[64](u8(esoOfficerData.department)),
        unit        = imgui.new.char[64](u8(esoOfficerData.unit)),
        assignment  = imgui.new.char[64](u8(esoOfficerData.assignment)),
    }
end

local function homeApplyEdit()
    local ffi = require 'ffi'
    esoOfficerData.badgeNumber = u8:decode(ffi.string(homeEditBuf.badgeNumber))
    esoOfficerData.rank        = u8:decode(ffi.string(homeEditBuf.rank))
    esoOfficerData.department  = u8:decode(ffi.string(homeEditBuf.department))
    esoOfficerData.unit        = u8:decode(ffi.string(homeEditBuf.unit))
    esoOfficerData.assignment  = u8:decode(ffi.string(homeEditBuf.assignment))
    officerSave()
    homeEditMode = false
end

local function initUofForm(idx)
    local ffi = require 'ffi'
    if not uofBuf then
        uofBuf = {
            location = imgui.new.char[128](),
            datetime = imgui.new.char[64](),
            weapon = imgui.new.char[128](),
            equipment = imgui.new.char[128](),
            officersCount = imgui.new.char[32](),
            seniorOfficer = imgui.new.char[64](),
            details = imgui.new.char[2048](),
        }
    end

    if idx and esoOfficerData.uofReports[idx] then
        local r = esoOfficerData.uofReports[idx]
        ffi.copy(uofBuf.location, u8(r.location))
        ffi.copy(uofBuf.datetime, u8(r.datetime))
        ffi.copy(uofBuf.weapon, u8(r.weapon))
        ffi.copy(uofBuf.equipment, u8(r.equipment))
        ffi.copy(uofBuf.officersCount, u8(r.officersCount))
        ffi.copy(uofBuf.seniorOfficer, u8(r.seniorOfficer))
        ffi.copy(uofBuf.details, u8(r.details))
        currentUofId = idx
        uofEditMode = true
    else
        ffi.fill(uofBuf.location, 128)
        ffi.copy(uofBuf.datetime, u8(os.date("%d.%m.%Y - %H:%M")))
        ffi.fill(uofBuf.weapon, 128)
        ffi.fill(uofBuf.equipment, 128)
        ffi.fill(uofBuf.officersCount, 32)
        ffi.fill(uofBuf.seniorOfficer, 64)
        ffi.fill(uofBuf.details, 2048)
        currentUofId = 0
        uofEditMode = false
    end
end

local function initArrestForm(idx)
    local ffi = require 'ffi'
    if not arrestBuf then
        arrestBuf = {
            suspectName = imgui.new.char[128](),
            datetime    = imgui.new.char[64](),
            charges     = imgui.new.char[256](),
            location    = imgui.new.char[128](),
            forceUsed   = imgui.new.char[32](),
            witnesses   = imgui.new.char[128](),
            details     = imgui.new.char[2048](),
        }
    end
    if idx and esoOfficerData.arrestReports[idx] then
        local r = esoOfficerData.arrestReports[idx]
        ffi.copy(arrestBuf.suspectName, u8(r.suspectName))
        ffi.copy(arrestBuf.datetime,    u8(r.datetime))
        ffi.copy(arrestBuf.charges,     u8(r.charges))
        ffi.copy(arrestBuf.location,    u8(r.location))
        ffi.copy(arrestBuf.forceUsed,   u8(r.forceUsed))
        ffi.copy(arrestBuf.witnesses,   u8(r.witnesses))
        ffi.copy(arrestBuf.details,     u8(r.details))
        currentArrestId = idx
        arrestEditMode = true
    else
        ffi.fill(arrestBuf.suspectName, 128)
        ffi.copy(arrestBuf.datetime,    u8(os.date("%d.%m.%Y - %H:%M")))
        ffi.fill(arrestBuf.charges,     256)
        ffi.fill(arrestBuf.location,    128)
        ffi.fill(arrestBuf.forceUsed,   32)
        ffi.fill(arrestBuf.witnesses,   128)
        ffi.fill(arrestBuf.details,     2048)
        currentArrestId = 0
        arrestEditMode = false
    end
end

local function initSituForm(idx)
    local ffi = require 'ffi'
    if not situBuf then
        situBuf = {
            situationType = imgui.new.char[128](),
            datetime      = imgui.new.char[64](),
            location      = imgui.new.char[128](),
            unitsInvolved = imgui.new.char[128](),
            outcome       = imgui.new.char[128](),
            casualties    = imgui.new.char[64](),
            details       = imgui.new.char[2048](),
        }
    end
    if idx and esoOfficerData.situationReports[idx] then
        local r = esoOfficerData.situationReports[idx]
        ffi.copy(situBuf.situationType, u8(r.situationType))
        ffi.copy(situBuf.datetime,      u8(r.datetime))
        ffi.copy(situBuf.location,      u8(r.location))
        ffi.copy(situBuf.unitsInvolved, u8(r.unitsInvolved))
        ffi.copy(situBuf.outcome,       u8(r.outcome))
        ffi.copy(situBuf.casualties,    u8(r.casualties))
        ffi.copy(situBuf.details,       u8(r.details))
        currentSituId = idx
        situEditMode = true
    else
        ffi.fill(situBuf.situationType, 128)
        ffi.copy(situBuf.datetime,      u8(os.date("%d.%m.%Y - %H:%M")))
        ffi.fill(situBuf.location,      128)
        ffi.fill(situBuf.unitsInvolved, 128)
        ffi.fill(situBuf.outcome,       128)
        ffi.fill(situBuf.casualties,    64)
        ffi.fill(situBuf.details,       2048)
        currentSituId = 0
        situEditMode = false
    end
end

-- =========================== ВИДЫ HOME ===========================

local function mdcRenderHomeMain()
    local ffi = require 'ffi'
    local C   = MDC_COL

    if not imgui.BeginChild("##home_scroll", imgui.ImVec2(0, 0), false, imgui.WindowFlags.HorizontalScrollbar) then
        imgui.EndChild()
        return
    end
    local dl  = imgui.GetWindowDrawList()
    local ww  = imgui.GetContentRegionAvail().x

    local cardW = math.floor(ww * 0.42)
    local cardH = 170

    local cp  = imgui.GetCursorScreenPos()
    dl:AddRectFilled(
        imgui.ImVec2(cp.x, cp.y),
        imgui.ImVec2(cp.x + cardW, cp.y + cardH),
        mdcCol(C.iconBg), 6.0)
    dl:AddRect(
        imgui.ImVec2(cp.x, cp.y),
        imgui.ImVec2(cp.x + cardW, cp.y + cardH),
        mdcCol(C.accentDim), 6.0, 0, 1.0)

    imgui.BeginGroup()
    imgui.Dummy(imgui.ImVec2(8, 6))

    local nick = esoOfficerData.nickname
    local initials = (nick ~= "" and nick:sub(1,1):upper()) or "?"
    local avatarP = imgui.GetCursorScreenPos()
    local avatarSz = 40
    dl:AddRectFilled(
        imgui.ImVec2(avatarP.x + 10, avatarP.y),
        imgui.ImVec2(avatarP.x + 10 + avatarSz, avatarP.y + avatarSz),
        mdcCol(C.accentDim), 4.0)
    dl:AddRect(
        imgui.ImVec2(avatarP.x + 10, avatarP.y),
        imgui.ImVec2(avatarP.x + 10 + avatarSz, avatarP.y + avatarSz),
        mdcCol(C.accent), 4.0, 0, 1.0)

    local initW = imgui.CalcTextSize(initials).x
    imgui.SetCursorPos(imgui.ImVec2(imgui.GetCursorPos().x + 10 + (avatarSz - initW) * 0.5, imgui.GetCursorPos().y + 12))
    imgui.TextColored(C.accent, u8(initials))

    imgui.SetCursorPos(imgui.ImVec2(imgui.GetCursorPos().x + 10 + avatarSz + 8, avatarP.y - cp.y + 4))
    imgui.TextColored(C.textMain, u8(nick ~= "" and nick:gsub("_", " ") or "— N/A —"))

    imgui.SetCursorScreenPos(imgui.ImVec2(cp.x + 8, cp.y + avatarSz + 14))
    imgui.Dummy(imgui.ImVec2(4, 4))
    imgui.SetCursorScreenPos(imgui.ImVec2(cp.x + 8, cp.y + avatarSz + 14))

    if homeEditMode then
        imgui.TextColored(C.textLabel, u8("BADGE:")) imgui.SameLine()
        imgui.PushItemWidth(cardW - 80) imgui.InputText("##badge", homeEditBuf.badgeNumber, 64) imgui.PopItemWidth()
        imgui.TextColored(C.textLabel, u8("RANK:")) imgui.SameLine()
        imgui.PushItemWidth(cardW - 80) imgui.InputText("##rank", homeEditBuf.rank, 64) imgui.PopItemWidth()
        imgui.TextColored(C.textLabel, u8("DEPT.:")) imgui.SameLine()
        imgui.PushItemWidth(cardW - 80) imgui.InputText("##dept", homeEditBuf.department, 64) imgui.PopItemWidth()
        imgui.TextColored(C.textLabel, u8("UNIT:")) imgui.SameLine()
        imgui.PushItemWidth(cardW - 80) imgui.InputText("##unit", homeEditBuf.unit, 64) imgui.PopItemWidth()
        imgui.TextColored(C.textLabel, u8("ASSIGN.:")) imgui.SameLine()
        imgui.PushItemWidth(cardW - 80) imgui.InputText("##assignment", homeEditBuf.assignment, 64) imgui.PopItemWidth()

        imgui.Spacing()
        imgui.PushStyleColor(imgui.Col.Button, C.green)
        if imgui.Button(u8("SAVE##home_save"), imgui.ImVec2(60, 18)) then homeApplyEdit() end
        imgui.PopStyleColor()
        imgui.SameLine()
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.25, 0.25, 0.28, 0.80))
        if imgui.Button(u8("CANCEL##home_cancel"), imgui.ImVec2(60, 18)) then homeEditMode = false end
        imgui.PopStyleColor()
    else
        local lblX = cp.x + 8
        local valX = cp.x + 68
        local function infoRow(lbl, val)
            local rowY = imgui.GetCursorScreenPos().y
            imgui.SetCursorScreenPos(imgui.ImVec2(lblX, rowY))
            imgui.TextColored(C.textLabel, u8(lbl))
            imgui.SetCursorScreenPos(imgui.ImVec2(valX, rowY))
            imgui.TextColored(C.textMain, u8(val ~= "" and val or "N/A"))
        end
        infoRow("BADGE:", esoOfficerData.badgeNumber)
        infoRow("RANK:", esoOfficerData.rank)
        infoRow("DEPT.:", esoOfficerData.department)
        infoRow("UNIT:", esoOfficerData.unit)
        infoRow("ASSIGN.:", esoOfficerData.assignment)
        imgui.SetCursorScreenPos(imgui.ImVec2(lblX, imgui.GetCursorScreenPos().y))

        imgui.Spacing()
        imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
        if imgui.Button(u8("EDIT##home_edit"), imgui.ImVec2(50, 16)) then
            homeInitEditBuf()
            homeEditMode = true
        end
        imgui.PopStyleColor()
    end
    imgui.EndGroup()
    imgui.SameLine(cardW + 16)

    -- === ВЕРХНЯЯ ПРАВАЯ: Статистика ===
    local statW = ww - cardW - 20
    local statH = cardH

    local sp = imgui.GetCursorScreenPos()
    dl:AddRectFilled(
        imgui.ImVec2(sp.x, sp.y),
        imgui.ImVec2(sp.x + statW, sp.y + statH),
        mdcCol(C.iconBg), 6.0)
    dl:AddRect(
        imgui.ImVec2(sp.x, sp.y),
        imgui.ImVec2(sp.x + statW, sp.y + statH),
        mdcCol(C.sep), 6.0, 0, 1.0)

    imgui.BeginGroup()
    imgui.Dummy(imgui.ImVec2(8, 4))
    imgui.SetCursorScreenPos(imgui.ImVec2(sp.x + 10, sp.y + 8))
    imgui.TextColored(C.textLabel, u8("DUTY STATISTICS & REPORTS"))
    imgui.SetCursorScreenPos(imgui.ImVec2(sp.x + 10, sp.y + 26))
    imgui.TextColored(C.sep, u8(string.rep("-", 28)))

    -- Интерактивные статбоксы
    local boxes = {
        { label = "ARRESTS",    val = tostring(#esoOfficerData.arrestReports),   col = C.accent },
        { label = "SITUATIONS", val = tostring(#esoOfficerData.situationReports), col = C.yellow },
        { label = "UOF",        val = tostring(#esoOfficerData.uofReports),       col = C.red },
    }
    local boxW = math.floor((statW - 20) / 3) - 4
    for i, box in ipairs(boxes) do
        local bx = sp.x + 10 + (i - 1) * (boxW + 4)
        local by = sp.y + 42

        imgui.SetCursorScreenPos(imgui.ImVec2(bx, by))
        if imgui.InvisibleButton("btn_" .. box.label, imgui.ImVec2(boxW, 52)) then
            if box.label == "UOF" then
                homeCurrentView = HOME_VIEW_UOF_LIST
            elseif box.label == "ARRESTS" then
                homeCurrentView = HOME_VIEW_ARREST_LIST
            elseif box.label == "SITUATIONS" then
                homeCurrentView = HOME_VIEW_SITU_LIST
            end
        end

        local isHovered = imgui.IsItemHovered()
        local bgAlpha = isHovered and 0.35 or 0.18

        dl:AddRectFilled(
            imgui.ImVec2(bx, by),
            imgui.ImVec2(bx + boxW, by + 52),
            mdcCol(imgui.ImVec4(box.col.x * bgAlpha, box.col.y * bgAlpha, box.col.z * bgAlpha, 0.85)),
            4.0)
        dl:AddRect(
            imgui.ImVec2(bx, by),
            imgui.ImVec2(bx + boxW, by + 52),
            mdcCol(imgui.ImVec4(box.col.x, box.col.y, box.col.z, isHovered and 0.8 or 0.40)),
            4.0, 0, 1.0)

        local valW = imgui.CalcTextSize(box.val).x
        imgui.SetCursorScreenPos(imgui.ImVec2(bx + (boxW - valW) * 0.5, by + 8))
        imgui.TextColored(box.col, u8(box.val))

        local lblW = imgui.CalcTextSize(box.label).x
        imgui.SetCursorScreenPos(imgui.ImVec2(bx + (boxW - lblW) * 0.5, by + 30))
        imgui.TextColored(C.textDim, u8(box.label))
    end

    imgui.SetCursorScreenPos(imgui.ImVec2(sp.x + 10, sp.y + 118))
    imgui.TextColored(C.textDim, u8("Нажмите на соответствующую кнопку для перехода к списку докладов"))
    imgui.EndGroup()

    imgui.SetCursorScreenPos(imgui.ImVec2(cp.x, cp.y + cardH + 10))

    -- === СРЕДНИЙ БЛОК: Последние доклады ===
    do
        local rdl = imgui.GetWindowDrawList()

        local allReports = {}
        for i, r in ipairs(esoOfficerData.uofReports) do
            local dept = (r.department and r.department ~= "") and r.department or "N/A"
            local unit = (r.unit and r.unit ~= "") and r.unit or "N/A"
            table.insert(allReports, {
                kind     = "uof",
                srcIndex = i,
                datetime = r.datetime or "",
                title    = string.format("USE OF FORCE REPORT - %s - %s", dept, unit),
                subtitle = string.format("[%s] Локация: %s | Офицер: %s", r.datetime, r.location, r.seniorOfficer),
                color    = C.red,
            })
        end
        for i, r in ipairs(esoOfficerData.arrestReports) do
            local dept = (r.department and r.department ~= "") and r.department or "N/A"
            local unit = (r.unit and r.unit ~= "") and r.unit or "N/A"
            table.insert(allReports, {
                kind     = "arrest",
                srcIndex = i,
                datetime = r.datetime or "",
                title    = string.format("ARREST REPORT - %s - %s | %s", dept, unit, r.suspectName ~= "" and r.suspectName or "N/A"),
                subtitle = string.format("[%s] Локация: %s", r.datetime, r.location),
                color    = C.accent,
            })
        end
        for i, r in ipairs(esoOfficerData.situationReports) do
            local dept = (r.department and r.department ~= "") and r.department or "N/A"
            local unit = (r.unit and r.unit ~= "") and r.unit or "N/A"
            local siType = r.situationType ~= "" and r.situationType or "N/A"
            table.insert(allReports, {
                kind     = "situ",
                srcIndex = i,
                datetime = r.datetime or "",
                title    = string.format("SITUATION REPORT - %s - %s | %s", dept, unit, siType),
                subtitle = string.format("[%s] Локация: %s", r.datetime, r.location),
                color    = C.yellow,
            })
        end

        table.sort(allReports, function(a, b) return a.datetime > b.datetime end)

        local recentCount = math.min(3, #allReports)
        local itemH       = 75
        local itemGap     = 6
        local headerH     = 28
        local footerPad   = 8
        local innerH      = recentCount > 0 and (recentCount * (itemH + itemGap) - itemGap) or 32
        local blockH      = headerH + innerH + footerPad
        local itemW2      = ww - 24

        local blkP = imgui.GetCursorScreenPos()

        -- Фон блока на всю ширину ww
        rdl:AddRectFilled(
            imgui.ImVec2(blkP.x, blkP.y),
            imgui.ImVec2(blkP.x + ww, blkP.y + blockH),
            mdcCol(C.iconBg), 6.0)
        rdl:AddRect(
            imgui.ImVec2(blkP.x, blkP.y),
            imgui.ImVec2(blkP.x + ww, blkP.y + blockH),
            mdcCol(C.sep), 6.0, 0, 1.0)

        -- Заголовок блока
        imgui.SetCursorScreenPos(imgui.ImVec2(blkP.x + 12, blkP.y + 8))
        imgui.TextColored(C.textLabel, u8("LAST REPORTS"))

        if recentCount == 0 then
            -- Надпись по центру
            local emptyTxt = u8("No last reports found")
            local tw = imgui.CalcTextSize(emptyTxt).x
            local ty = blkP.y + headerH + (32 - 13) * 0.5
            imgui.SetCursorScreenPos(imgui.ImVec2(blkP.x + (ww - tw) * 0.5, ty))
            imgui.TextColored(C.textDim, emptyTxt)
        else
            for j = 1, recentCount do
                local rep = allReports[j]
                local iy  = blkP.y + headerH + (j - 1) * (itemH + itemGap)
                local cpI = imgui.ImVec2(blkP.x + 12, iy)

                imgui.SetCursorScreenPos(cpI)
                if imgui.InvisibleButton("recent_rep_" .. j, imgui.ImVec2(itemW2, itemH)) then
                    if rep.kind == "uof" then
                        currentUofId = rep.srcIndex
                        homeCurrentView = HOME_VIEW_UOF_READ
                    elseif rep.kind == "arrest" then
                        currentArrestId = rep.srcIndex
                        homeCurrentView = HOME_VIEW_ARREST_READ
                    elseif rep.kind == "situ" then
                        currentSituId = rep.srcIndex
                        homeCurrentView = HOME_VIEW_SITU_READ
                    end
                end

                local hov   = imgui.IsItemHovered()
                local bgCol = hov and C.iconBgHov or C.iconBg

                rdl:AddRectFilled(cpI, imgui.ImVec2(cpI.x + itemW2, cpI.y + itemH), mdcCol(bgCol), 4.0)
                rdl:AddRect(cpI, imgui.ImVec2(cpI.x + itemW2, cpI.y + itemH), mdcCol(C.sep), 4.0, 0, 1.0)

                imgui.SetCursorScreenPos(imgui.ImVec2(cpI.x + 14, cpI.y + 18))
                imgui.TextColored(rep.color, u8(rep.title))

                imgui.SetCursorScreenPos(imgui.ImVec2(cpI.x + 14, cpI.y + 40))
                imgui.TextColored(C.textDim, u8(rep.subtitle))
            end
        end

        -- Двигаем курсор за блок чтобы EVENT LOG начался сразу под ним
        imgui.SetCursorScreenPos(imgui.ImVec2(blkP.x, blkP.y + blockH + 8))
    end

    -- === НИЖНИЙ БЛОК: Лог событий ===
    imgui.Separator()
    imgui.Spacing()
    imgui.TextColored(C.textLabel, u8("EVENT LOG"))
    imgui.SameLine(ww - 100)

    imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
    -- if imgui.Button(u8("[+] TEST ENTRY##homeLog"), imgui.ImVec2(96, 16)) then officerAddEvent("Manual test entry") end
    imgui.PopStyleColor()
    imgui.Separator()

    -- Фиксированная высота лога — внутри скроллируемого child растягиваться не нужно
    local logLineH = 18
    local logLines = math.max(1, #esoOfficerData.eventLog)
    local logH = math.min(logLines * logLineH + 8, 120)
    if imgui.BeginChild("##home_log", imgui.ImVec2(0, logH), false) then
        if #esoOfficerData.eventLog == 0 then
            imgui.TextColored(C.textDim, u8("  -- no events logged --"))
        else
            for _, ev in ipairs(esoOfficerData.eventLog) do
                imgui.TextColored(C.textDim, u8("> "))
                imgui.SameLine()
                imgui.TextColored(C.textMain, u8(ev))
            end
        end
        imgui.EndChild()
    end

    imgui.EndChild()  -- ##home_scroll
end

-- =========================== ВИД UOF: СПИСОК ===========================

local function mdcRenderUofList()
    local C = MDC_COL
    local ww = imgui.GetContentRegionAvail().x

    imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
    if imgui.Button(u8("<- BACK"), imgui.ImVec2(130, 24)) then
        homeCurrentView = HOME_VIEW_MAIN
    end
    imgui.PopStyleColor()
    
    imgui.SameLine(ww - 140) 
    
    imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
    if imgui.Button(u8("NEW REPORT"), imgui.ImVec2(140, 24)) then
        initUofForm()
        homeCurrentView = HOME_VIEW_UOF_FORM
    end
    imgui.PopStyleColor()

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    local childH = imgui.GetContentRegionAvail().y
    if imgui.BeginChild("##uof_list", imgui.ImVec2(0, childH), false) then
        if #esoOfficerData.uofReports == 0 then
            local txt = u8("Nothing found")
            local tw = imgui.CalcTextSize(txt).x
            imgui.SetCursorPosY(childH * 0.4)
            imgui.SetCursorPosX((ww - tw) * 0.5)
            imgui.TextColored(C.textDim, txt)
        else
            local dl = imgui.GetWindowDrawList()
            
            for i, rep in ipairs(esoOfficerData.uofReports) do
                local itemW = ww - 12
                local itemH = 75
                local cp = imgui.GetCursorScreenPos()
                
                imgui.SetCursorScreenPos(cp)
                if imgui.InvisibleButton("uof_rep_id_" .. i, imgui.ImVec2(itemW, itemH)) then
                    currentUofId = i
                    homeCurrentView = HOME_VIEW_UOF_READ
                end
                
                local isHovered = imgui.IsItemHovered()
                local bgCol = isHovered and C.iconBgHov or C.iconBg
                
                dl:AddRectFilled(imgui.ImVec2(cp.x, cp.y), imgui.ImVec2(cp.x + itemW, cp.y + itemH), mdcCol(bgCol), 4.0)
                dl:AddRect(imgui.ImVec2(cp.x, cp.y), imgui.ImVec2(cp.x + itemW, cp.y + itemH), mdcCol(C.sep), 4.0, 0, 1.0)
                
                local reportNum = #esoOfficerData.uofReports - i + 1
                
                -- ИЗМЕНЕНО: Теперь читаем DEPT и UNIT прямо из объекта доклада (rep), а не из глобального esoOfficerData
                local dept = (rep.department and rep.department ~= "") and rep.department or "N/A"
                local unit = (rep.unit and rep.unit ~= "") and rep.unit or "N/A"
                
                local titleText = string.format("[#%d] USE OF FORCE REPORT - %s - %s", reportNum, dept, unit)
                imgui.SetCursorScreenPos(imgui.ImVec2(cp.x + 14, cp.y + 18))
                imgui.TextColored(C.accent, u8(titleText))
                
                local subtitleText = string.format("[%s] Локация: %s | Офицер: %s", rep.datetime, rep.location, rep.seniorOfficer)
                imgui.SetCursorScreenPos(imgui.ImVec2(cp.x + 14, cp.y + 40))
                imgui.TextColored(C.textDim, u8(subtitleText))
                
                imgui.SetCursorScreenPos(imgui.ImVec2(cp.x, cp.y + itemH + 6))
            end
        end
        imgui.EndChild()
    end
end

-- =========================== ВИД UOF: ФОРМА СОЗДАНИЯ/РЕДАКТИРОВАНИЯ ===========================

local function mdcRenderUofForm()
    local C = MDC_COL
    local ww = imgui.GetContentRegionAvail().x
    local ffi = require 'ffi'

    imgui.TextColored(C.headerText, u8(uofEditMode and "РЕДАКТИРОВАНИЕ ДОКЛАДА UOF" or "НОВЫЙ ДОКЛАД UOF"))
    imgui.Separator()
    imgui.Spacing()

    if imgui.BeginChild("##uof_form_child", imgui.ImVec2(0, imgui.GetContentRegionAvail().y - 45), false) then
        -- Блок 1: Автозаполнение
        imgui.TextColored(C.accent, u8("ИНФОРМАЦИЯ ОБ ОФИЦЕРЕ"))
        imgui.TextColored(C.textDim, u8(string.format("Офицер: %s | Жетон: %s | Ранг: %s", esoOfficerData.nickname:gsub("_", " "), esoOfficerData.badgeNumber, esoOfficerData.rank)))
        imgui.TextColored(C.textDim, u8(string.format("Департамент: %s | Юнит: %s", esoOfficerData.department, esoOfficerData.unit)))
        
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        -- Блок 2: Ввод данных
        imgui.TextColored(C.accent, u8("ДЕТАЛИ ИНЦИДЕНТА"))
        local function inputRow(lbl, buf, size)
            imgui.TextColored(C.textLabel, u8(lbl))
            imgui.SameLine(180)
            imgui.PushItemWidth(ww - 200)
            imgui.InputText("##" .. lbl, buf, size)
            imgui.PopItemWidth()
        end

        inputRow("Локация", uofBuf.location, 128)
        inputRow("Время и дата", uofBuf.datetime, 64)
        inputRow("Применяемое оружие", uofBuf.weapon, 128)
        inputRow("Спецсредства", uofBuf.equipment, 128)
        inputRow("Кол-во офицеров", uofBuf.officersCount, 32)
        inputRow("Старший офицер", uofBuf.seniorOfficer, 64)

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        -- Блок 3: Описание
        imgui.TextColored(C.accent, u8("ПОДРОБНОЕ ОПИСАНИЕ СИТУАЦИИ"))
        imgui.InputTextMultiline("##uof_details", uofBuf.details, 2048, imgui.ImVec2(ww - 15, 120))

        imgui.EndChild()
    end

    -- Кнопки сохранения
    imgui.Separator()
    imgui.Spacing()
    imgui.PushStyleColor(imgui.Col.Button, C.green)
    if imgui.Button(u8("СОХРАНИТЬ"), imgui.ImVec2(120, 26)) then
        local rep = {
            location = u8:decode(ffi.string(uofBuf.location)),
            datetime = u8:decode(ffi.string(uofBuf.datetime)),
            weapon = u8:decode(ffi.string(uofBuf.weapon)),
            equipment = u8:decode(ffi.string(uofBuf.equipment)),
            officersCount = u8:decode(ffi.string(uofBuf.officersCount)),
            seniorOfficer = u8:decode(ffi.string(uofBuf.seniorOfficer)),
            details = u8:decode(ffi.string(uofBuf.details)),
			department = esoOfficerData.department,
			unit = esoOfficerData.unit,
			officerBadge = esoOfficerData.badgeNumber,
			officerRank = esoOfficerData.rank,
			officerNick = esoOfficerData.nickname:gsub("_", " ")
        }
        if uofEditMode then
            -- Сохраняем в тот же файл (переносим _file из старого отчёта)
            local existing = esoOfficerData.uofReports[currentUofId]
            if existing and existing._file then
                rep._file = existing._file
            end
            uofSaveReport(rep)
            esoOfficerData.uofReports[currentUofId] = rep
        else
            -- Новый отчёт — создаём новый файл
            rep._file = ""
            uofSaveReport(rep)
            table.insert(esoOfficerData.uofReports, 1, rep)
        end
        homeCurrentView = HOME_VIEW_UOF_LIST
    end
    imgui.PopStyleColor()
    imgui.SameLine()
    imgui.PushStyleColor(imgui.Col.Button, C.closeBtn)
    if imgui.Button(u8("ОТМЕНА"), imgui.ImVec2(120, 26)) then
        homeCurrentView = HOME_VIEW_UOF_LIST
    end
    imgui.PopStyleColor()
end

-- =========================== ВИД UOF: ЧТЕНИЕ ДОКЛАДА ===========================

local function mdcRenderUofRead()
    local C = MDC_COL
    local ww = imgui.GetContentRegionAvail().x
    local rep = esoOfficerData.uofReports[currentUofId]

    if not rep then
        homeCurrentView = HOME_VIEW_UOF_LIST
        return
    end

    imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
    if imgui.Button(u8("<- BACK"), imgui.ImVec2(130, 24)) then
        homeCurrentView = HOME_VIEW_UOF_LIST
    end
    imgui.PopStyleColor()
    
    imgui.SameLine(ww - 260)
    imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
    if imgui.Button(u8("EDIT"), imgui.ImVec2(125, 24)) then
        initUofForm(currentUofId)
        homeCurrentView = HOME_VIEW_UOF_FORM
    end
    imgui.PopStyleColor()
    
    imgui.SameLine()
    imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
    if imgui.Button(u8("DELETE"), imgui.ImVec2(125, 24)) then
        local rep = esoOfficerData.uofReports[currentUofId]
        uofDeleteReport(rep)
        table.remove(esoOfficerData.uofReports, currentUofId)
        homeCurrentView = HOME_VIEW_UOF_LIST
    end
    imgui.PopStyleColor()

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    if imgui.BeginChild("##uof_read_child", imgui.ImVec2(0, 0), false) then
        local function readRow(lbl, val)
            imgui.TextColored(C.textLabel, u8(lbl .. ":"))
            imgui.SameLine(180)
            imgui.TextColored(C.textMain, u8(val ~= "" and val or "N/A"))
        end

        -- === ВСТАВЛЯЕМ ЭТОТ БЛОК ПЕРЕД СВОДКОЙ ИНЦИДЕНТА ===
		imgui.TextColored(C.accent, u8("ИНФОРМАЦИЯ ОБ ОФИЦЕРЕ (НА МОМЕНТ ПОДАЧИ):"))
		imgui.Spacing()

		local oRank = (rep.officerRank and rep.officerRank ~= "") and rep.officerRank or "N/A"
		local oName = (rep.officerNick and rep.officerNick ~= "") and rep.officerNick or "N/A"
		local oBadge = (rep.officerBadge and rep.officerBadge ~= "") and rep.officerBadge or "---"

		imgui.Text(u8(string.format("Офицер: %s %s", oRank, oName)))
		imgui.Text(u8(string.format("Номер жетона: #%s", oBadge)))
		imgui.Text(u8(string.format("Подразделение: %s | Юнит: %s", rep.department or "N/A", rep.unit or "N/A")))

		imgui.Spacing()
		imgui.Separator()
		imgui.Spacing()
-- ===================================================
		
		imgui.TextColored(C.accent, u8("СВОДКА ИНЦИДЕНТА"))
        readRow("Время и дата", rep.datetime)
        readRow("Локация", rep.location)
        readRow("Старший офицер", rep.seniorOfficer)
        readRow("Кол-во офицеров", rep.officersCount)
        readRow("Применяемое оружие", rep.weapon)
        readRow("Спецсредства", rep.equipment)

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        imgui.TextColored(C.accent, u8("ДЕТАЛИ СИТУАЦИИ"))
        imgui.TextWrapped(u8(rep.details ~= "" and rep.details or "Нет описания."))

        imgui.EndChild()
    end
end

-- =========================== ВИД ARRESTS: СПИСОК ===========================

local function mdcRenderArrestList()
    local C = MDC_COL
    local ww = imgui.GetContentRegionAvail().x

    imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
    if imgui.Button(u8("<- BACK"), imgui.ImVec2(130, 24)) then
        homeCurrentView = HOME_VIEW_MAIN
    end
    imgui.PopStyleColor()

    imgui.SameLine(ww - 140)
    imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
    if imgui.Button(u8("NEW REPORT"), imgui.ImVec2(140, 24)) then
        initArrestForm()
        homeCurrentView = HOME_VIEW_ARREST_FORM
    end
    imgui.PopStyleColor()

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    local childH = imgui.GetContentRegionAvail().y
    if imgui.BeginChild("##arrest_list", imgui.ImVec2(0, childH), false) then
        if #esoOfficerData.arrestReports == 0 then
            local txt = u8("Ничего не найдено")
            local tw = imgui.CalcTextSize(txt).x
            imgui.SetCursorPosY(childH * 0.4)
            imgui.SetCursorPosX((ww - tw) * 0.5)
            imgui.TextColored(C.textDim, txt)
        else
            local dl = imgui.GetWindowDrawList()
            for i, rep in ipairs(esoOfficerData.arrestReports) do
                local itemW = ww - 12
                local itemH = 75
                local cp = imgui.GetCursorScreenPos()

                imgui.SetCursorScreenPos(cp)
                if imgui.InvisibleButton("arrest_rep_id_" .. i, imgui.ImVec2(itemW, itemH)) then
                    currentArrestId = i
                    homeCurrentView = HOME_VIEW_ARREST_READ
                end

                local isHovered = imgui.IsItemHovered()
                local bgCol = isHovered and C.iconBgHov or C.iconBg

                dl:AddRectFilled(imgui.ImVec2(cp.x, cp.y), imgui.ImVec2(cp.x + itemW, cp.y + itemH), mdcCol(bgCol), 4.0)
                dl:AddRect(imgui.ImVec2(cp.x, cp.y), imgui.ImVec2(cp.x + itemW, cp.y + itemH), mdcCol(C.sep), 4.0, 0, 1.0)

                local reportNum = #esoOfficerData.arrestReports - i + 1
                local aDept = (rep.department and rep.department ~= "") and rep.department or "N/A"
                local aUnit = (rep.unit and rep.unit ~= "") and rep.unit or "N/A"
                local titleText = string.format("[#%d] ARREST REPORT - %s - %s | %s", reportNum, aDept, aUnit, rep.suspectName ~= "" and rep.suspectName or "N/A")
                imgui.SetCursorScreenPos(imgui.ImVec2(cp.x + 14, cp.y + 18))
                imgui.TextColored(C.accent, u8(titleText))

                local subtitleText = string.format("[%s] Локация: %s", rep.datetime, rep.location)
                imgui.SetCursorScreenPos(imgui.ImVec2(cp.x + 14, cp.y + 40))
                imgui.TextColored(C.textDim, u8(subtitleText))

                imgui.SetCursorScreenPos(imgui.ImVec2(cp.x, cp.y + itemH + 6))
            end
        end
        imgui.EndChild()
    end
end

-- =========================== ВИД ARRESTS: ФОРМА ===========================

local function mdcRenderArrestForm()
    local C = MDC_COL
    local ww = imgui.GetContentRegionAvail().x
    local ffi = require 'ffi'

    imgui.TextColored(C.headerText, u8(arrestEditMode and "РЕДАКТИРОВАНИЕ ДОКЛАДА ОБ АРЕСТЕ" or "НОВЫЙ ДОКЛАД ОБ АРЕСТЕ"))
    imgui.Separator()
    imgui.Spacing()

    if imgui.BeginChild("##arrest_form_child", imgui.ImVec2(0, imgui.GetContentRegionAvail().y - 45), false) then
        imgui.TextColored(C.accent, u8("ИНФОРМАЦИЯ ОБ ОФИЦЕРЕ"))
        imgui.TextColored(C.textDim, u8(string.format("Офицер: %s | Жетон: %s | Ранг: %s", esoOfficerData.nickname:gsub("_", " "), esoOfficerData.badgeNumber, esoOfficerData.rank)))
        imgui.TextColored(C.textDim, u8(string.format("Департамент: %s | Юнит: %s", esoOfficerData.department, esoOfficerData.unit)))

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        imgui.TextColored(C.accent, u8("ДЕТАЛИ ЗАДЕРЖАНИЯ"))
        local function inputRow(lbl, buf, size)
            imgui.TextColored(C.textLabel, u8(lbl))
            imgui.SameLine(180)
            imgui.PushItemWidth(ww - 200)
            imgui.InputText("##arrest_" .. lbl, buf, size)
            imgui.PopItemWidth()
        end

        inputRow("Задержанный",       arrestBuf.suspectName, 128)
        inputRow("Дата и время",      arrestBuf.datetime,    64)
        inputRow("Статья / нарушение",arrestBuf.charges,     256)
        inputRow("Место задержания",  arrestBuf.location,    128)
        inputRow("Применение силы",   arrestBuf.forceUsed,   32)
        inputRow("Свидетели/офицеры", arrestBuf.witnesses,   128)

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        imgui.TextColored(C.accent, u8("ПОДРОБНОЕ ОПИСАНИЕ"))
        imgui.InputTextMultiline("##arrest_details", arrestBuf.details, 2048, imgui.ImVec2(ww - 15, 120))

        imgui.EndChild()
    end

    imgui.Separator()
    imgui.Spacing()
    imgui.PushStyleColor(imgui.Col.Button, C.green)
    if imgui.Button(u8("СОХРАНИТЬ"), imgui.ImVec2(120, 26)) then
        local rep = {
            suspectName  = u8:decode(ffi.string(arrestBuf.suspectName)),
            datetime     = u8:decode(ffi.string(arrestBuf.datetime)),
            charges      = u8:decode(ffi.string(arrestBuf.charges)),
            location     = u8:decode(ffi.string(arrestBuf.location)),
            forceUsed    = u8:decode(ffi.string(arrestBuf.forceUsed)),
            witnesses    = u8:decode(ffi.string(arrestBuf.witnesses)),
            details      = u8:decode(ffi.string(arrestBuf.details)),
            department   = esoOfficerData.department,
            unit         = esoOfficerData.unit,
            officerBadge = esoOfficerData.badgeNumber,
            officerRank  = esoOfficerData.rank,
            officerNick  = esoOfficerData.nickname:gsub("_", " "),
        }
        if arrestEditMode then
            local existing = esoOfficerData.arrestReports[currentArrestId]
            if existing and existing._file then rep._file = existing._file end
            arrestSaveReport(rep)
            esoOfficerData.arrestReports[currentArrestId] = rep
        else
            rep._file = ""
            arrestSaveReport(rep)
            table.insert(esoOfficerData.arrestReports, 1, rep)
        end
        homeCurrentView = HOME_VIEW_ARREST_LIST
    end
    imgui.PopStyleColor()
    imgui.SameLine()
    imgui.PushStyleColor(imgui.Col.Button, C.closeBtn)
    if imgui.Button(u8("ОТМЕНА"), imgui.ImVec2(120, 26)) then
        homeCurrentView = HOME_VIEW_ARREST_LIST
    end
    imgui.PopStyleColor()
end

-- =========================== ВИД ARRESTS: ЧТЕНИЕ ===========================

local function mdcRenderArrestRead()
    local C = MDC_COL
    local ww = imgui.GetContentRegionAvail().x
    local rep = esoOfficerData.arrestReports[currentArrestId]

    if not rep then homeCurrentView = HOME_VIEW_ARREST_LIST; return end

    imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
    if imgui.Button(u8("<- BACK"), imgui.ImVec2(130, 24)) then
        homeCurrentView = HOME_VIEW_ARREST_LIST
    end
    imgui.PopStyleColor()

    imgui.SameLine(ww - 260)
    imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
    if imgui.Button(u8("EDIT"), imgui.ImVec2(125, 24)) then
        initArrestForm(currentArrestId)
        homeCurrentView = HOME_VIEW_ARREST_FORM
    end
    imgui.PopStyleColor()

    imgui.SameLine()
    imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
    if imgui.Button(u8("DELETE"), imgui.ImVec2(125, 24)) then
        arrestDeleteReport(rep)
        table.remove(esoOfficerData.arrestReports, currentArrestId)
        homeCurrentView = HOME_VIEW_ARREST_LIST
    end
    imgui.PopStyleColor()

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    if imgui.BeginChild("##arrest_read_child", imgui.ImVec2(0, 0), false) then
        local function readRow(lbl, val)
            imgui.TextColored(C.textLabel, u8(lbl .. ":"))
            imgui.SameLine(180)
            imgui.TextColored(C.textMain, u8(val ~= "" and val or "N/A"))
        end

        imgui.TextColored(C.accent, u8("ИНФОРМАЦИЯ ОБ ОФИЦЕРЕ (НА МОМЕНТ ПОДАЧИ):"))
        imgui.Spacing()
        imgui.Text(u8(string.format("Офицер: %s %s", rep.officerRank or "N/A", rep.officerNick or "N/A")))
        imgui.Text(u8(string.format("Номер жетона: #%s", rep.officerBadge or "---")))
        imgui.Text(u8(string.format("Подразделение: %s | Юнит: %s", rep.department or "N/A", rep.unit or "N/A")))
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        imgui.TextColored(C.accent, u8("СВОДКА ЗАДЕРЖАНИЯ"))
        readRow("Дата и время",       rep.datetime)
        readRow("Задержанный",        rep.suspectName)
        readRow("Место задержания",   rep.location)
        readRow("Статья / нарушение", rep.charges)
        readRow("Применение силы",    rep.forceUsed)
        readRow("Свидетели/офицеры",  rep.witnesses)

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        imgui.TextColored(C.accent, u8("ОПИСАНИЕ"))
        imgui.TextWrapped(u8(rep.details ~= "" and rep.details or "Нет описания."))

        imgui.EndChild()
    end
end

-- =========================== ВИД SITUATIONS: СПИСОК ===========================

local function mdcRenderSituList()
    local C = MDC_COL
    local ww = imgui.GetContentRegionAvail().x

    imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
    if imgui.Button(u8("<- BACK"), imgui.ImVec2(130, 24)) then
        homeCurrentView = HOME_VIEW_MAIN
    end
    imgui.PopStyleColor()

    imgui.SameLine(ww - 140)
    imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
    if imgui.Button(u8("NEW REPORT"), imgui.ImVec2(140, 24)) then
        initSituForm()
        homeCurrentView = HOME_VIEW_SITU_FORM
    end
    imgui.PopStyleColor()

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    local childH = imgui.GetContentRegionAvail().y
    if imgui.BeginChild("##situ_list", imgui.ImVec2(0, childH), false) then
        if #esoOfficerData.situationReports == 0 then
            local txt = u8("Ничего не найдено")
            local tw = imgui.CalcTextSize(txt).x
            imgui.SetCursorPosY(childH * 0.4)
            imgui.SetCursorPosX((ww - tw) * 0.5)
            imgui.TextColored(C.textDim, txt)
        else
            local dl = imgui.GetWindowDrawList()
            for i, rep in ipairs(esoOfficerData.situationReports) do
                local itemW = ww - 12
                local itemH = 75
                local cp = imgui.GetCursorScreenPos()

                imgui.SetCursorScreenPos(cp)
                if imgui.InvisibleButton("situ_rep_id_" .. i, imgui.ImVec2(itemW, itemH)) then
                    currentSituId = i
                    homeCurrentView = HOME_VIEW_SITU_READ
                end

                local isHovered = imgui.IsItemHovered()
                local bgCol = isHovered and C.iconBgHov or C.iconBg

                dl:AddRectFilled(imgui.ImVec2(cp.x, cp.y), imgui.ImVec2(cp.x + itemW, cp.y + itemH), mdcCol(bgCol), 4.0)
                dl:AddRect(imgui.ImVec2(cp.x, cp.y), imgui.ImVec2(cp.x + itemW, cp.y + itemH), mdcCol(C.sep), 4.0, 0, 1.0)

                local reportNum = #esoOfficerData.situationReports - i + 1
                local sDept = (rep.department and rep.department ~= "") and rep.department or "N/A"
                local sUnit = (rep.unit and rep.unit ~= "") and rep.unit or "N/A"
                local siType = rep.situationType ~= "" and rep.situationType or "N/A"
                local titleText = string.format("[#%d] SITUATION REPORT - %s - %s | %s", reportNum, sDept, sUnit, siType)
                imgui.SetCursorScreenPos(imgui.ImVec2(cp.x + 14, cp.y + 18))
                imgui.TextColored(C.yellow, u8(titleText))

                local subtitleText = string.format("[%s] Локация: %s", rep.datetime, rep.location)
                imgui.SetCursorScreenPos(imgui.ImVec2(cp.x + 14, cp.y + 40))
                imgui.TextColored(C.textDim, u8(subtitleText))

                imgui.SetCursorScreenPos(imgui.ImVec2(cp.x, cp.y + itemH + 6))
            end
        end
        imgui.EndChild()
    end
end

-- =========================== ВИД SITUATIONS: ФОРМА ===========================

local function mdcRenderSituForm()
    local C = MDC_COL
    local ww = imgui.GetContentRegionAvail().x
    local ffi = require 'ffi'

    imgui.TextColored(C.headerText, u8(situEditMode and "РЕДАКТИРОВАНИЕ ДОКЛАДА ОБ ИНЦИДЕНТЕ" or "НОВЫЙ ДОКЛАД ОБ ИНЦИДЕНТЕ"))
    imgui.Separator()
    imgui.Spacing()

    if imgui.BeginChild("##situ_form_child", imgui.ImVec2(0, imgui.GetContentRegionAvail().y - 45), false) then
        imgui.TextColored(C.accent, u8("ИНФОРМАЦИЯ ОБ ОФИЦЕРЕ"))
        imgui.TextColored(C.textDim, u8(string.format("Офицер: %s | Жетон: %s | Ранг: %s", esoOfficerData.nickname:gsub("_", " "), esoOfficerData.badgeNumber, esoOfficerData.rank)))
        imgui.TextColored(C.textDim, u8(string.format("Департамент: %s | Юнит: %s", esoOfficerData.department, esoOfficerData.unit)))

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        imgui.TextColored(C.accent, u8("ДЕТАЛИ ИНЦИДЕНТА"))
        local function inputRow(lbl, buf, size)
            imgui.TextColored(C.textLabel, u8(lbl))
            imgui.SameLine(180)
            imgui.PushItemWidth(ww - 200)
            imgui.InputText("##situ_" .. lbl, buf, size)
            imgui.PopItemWidth()
        end

        inputRow("Тип ситуации",       situBuf.situationType, 128)
        inputRow("Дата и время",        situBuf.datetime,      64)
        inputRow("Место",               situBuf.location,      128)
        inputRow("Задейств. юниты",     situBuf.unitsInvolved, 128)
        inputRow("Исход",               situBuf.outcome,       128)
        inputRow("Пострадавшие",        situBuf.casualties,    64)

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        imgui.TextColored(C.accent, u8("ПОДРОБНОЕ ОПИСАНИЕ"))
        imgui.InputTextMultiline("##situ_details", situBuf.details, 2048, imgui.ImVec2(ww - 15, 120))

        imgui.EndChild()
    end

    imgui.Separator()
    imgui.Spacing()
    imgui.PushStyleColor(imgui.Col.Button, C.green)
    if imgui.Button(u8("СОХРАНИТЬ"), imgui.ImVec2(120, 26)) then
        local rep = {
            situationType = u8:decode(ffi.string(situBuf.situationType)),
            datetime      = u8:decode(ffi.string(situBuf.datetime)),
            location      = u8:decode(ffi.string(situBuf.location)),
            unitsInvolved = u8:decode(ffi.string(situBuf.unitsInvolved)),
            outcome       = u8:decode(ffi.string(situBuf.outcome)),
            casualties    = u8:decode(ffi.string(situBuf.casualties)),
            details       = u8:decode(ffi.string(situBuf.details)),
            department    = esoOfficerData.department,
            unit          = esoOfficerData.unit,
            officerBadge  = esoOfficerData.badgeNumber,
            officerRank   = esoOfficerData.rank,
            officerNick   = esoOfficerData.nickname:gsub("_", " "),
        }
        if situEditMode then
            local existing = esoOfficerData.situationReports[currentSituId]
            if existing and existing._file then rep._file = existing._file end
            situSaveReport(rep)
            esoOfficerData.situationReports[currentSituId] = rep
        else
            rep._file = ""
            situSaveReport(rep)
            table.insert(esoOfficerData.situationReports, 1, rep)
        end
        homeCurrentView = HOME_VIEW_SITU_LIST
    end
    imgui.PopStyleColor()
    imgui.SameLine()
    imgui.PushStyleColor(imgui.Col.Button, C.closeBtn)
    if imgui.Button(u8("ОТМЕНА"), imgui.ImVec2(120, 26)) then
        homeCurrentView = HOME_VIEW_SITU_LIST
    end
    imgui.PopStyleColor()
end

-- =========================== ВИД SITUATIONS: ЧТЕНИЕ ===========================

local function mdcRenderSituRead()
    local C = MDC_COL
    local ww = imgui.GetContentRegionAvail().x
    local rep = esoOfficerData.situationReports[currentSituId]

    if not rep then homeCurrentView = HOME_VIEW_SITU_LIST; return end

    imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
    if imgui.Button(u8("<- BACK"), imgui.ImVec2(130, 24)) then
        homeCurrentView = HOME_VIEW_SITU_LIST
    end
    imgui.PopStyleColor()

    imgui.SameLine(ww - 260)
    imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
    if imgui.Button(u8("EDIT"), imgui.ImVec2(125, 24)) then
        initSituForm(currentSituId)
        homeCurrentView = HOME_VIEW_SITU_FORM
    end
    imgui.PopStyleColor()

    imgui.SameLine()
    imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
    if imgui.Button(u8("DELETE"), imgui.ImVec2(125, 24)) then
        situDeleteReport(rep)
        table.remove(esoOfficerData.situationReports, currentSituId)
        homeCurrentView = HOME_VIEW_SITU_LIST
    end
    imgui.PopStyleColor()

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    if imgui.BeginChild("##situ_read_child", imgui.ImVec2(0, 0), false) then
        local function readRow(lbl, val)
            imgui.TextColored(C.textLabel, u8(lbl .. ":"))
            imgui.SameLine(180)
            imgui.TextColored(C.textMain, u8(val ~= "" and val or "N/A"))
        end

        imgui.TextColored(C.accent, u8("ИНФОРМАЦИЯ ОБ ОФИЦЕРЕ (НА МОМЕНТ ПОДАЧИ):"))
        imgui.Spacing()
        imgui.Text(u8(string.format("Офицер: %s %s", rep.officerRank or "N/A", rep.officerNick or "N/A")))
        imgui.Text(u8(string.format("Номер жетона: #%s", rep.officerBadge or "---")))
        imgui.Text(u8(string.format("Подразделение: %s | Юнит: %s", rep.department or "N/A", rep.unit or "N/A")))
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        imgui.TextColored(C.accent, u8("СВОДКА ИНЦИДЕНТА"))
        readRow("Тип ситуации",    rep.situationType)
        readRow("Дата и время",    rep.datetime)
        readRow("Место",           rep.location)
        readRow("Задейств. юниты", rep.unitsInvolved)
        readRow("Исход",           rep.outcome)
        readRow("Пострадавшие",    rep.casualties)

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        imgui.TextColored(C.accent, u8("ОПИСАНИЕ"))
        imgui.TextWrapped(u8(rep.details ~= "" and rep.details or "Нет описания."))

        imgui.EndChild()
    end
end

-- =========================== РОУТИНГ ПРИЛОЖЕНИЯ HOME ===========================

local function mdcRenderHome()
    if homeCurrentView == HOME_VIEW_MAIN then
        mdcRenderHomeMain()
    elseif homeCurrentView == HOME_VIEW_UOF_LIST then
        mdcRenderUofList()
    elseif homeCurrentView == HOME_VIEW_UOF_FORM then
        mdcRenderUofForm()
    elseif homeCurrentView == HOME_VIEW_UOF_READ then
        mdcRenderUofRead()
    elseif homeCurrentView == HOME_VIEW_ARREST_LIST then
        mdcRenderArrestList()
    elseif homeCurrentView == HOME_VIEW_ARREST_FORM then
        mdcRenderArrestForm()
    elseif homeCurrentView == HOME_VIEW_ARREST_READ then
        mdcRenderArrestRead()
    elseif homeCurrentView == HOME_VIEW_SITU_LIST then
        mdcRenderSituList()
    elseif homeCurrentView == HOME_VIEW_SITU_FORM then
        mdcRenderSituForm()
    elseif homeCurrentView == HOME_VIEW_SITU_READ then
        mdcRenderSituRead()
    end
end

-- ¦         ПРИЛОЖЕНИЕ: ABOUT (Информация о скрипте)        ¦

local function mdcRenderAbout()
    local dl = imgui.GetWindowDrawList()
    local ww = imgui.GetContentRegionAvail().x
    local C  = MDC_COL

    imgui.Spacing()

    -- Лого / баннер
    local bannerH = 36
    local bp = imgui.GetCursorScreenPos()
    dl:AddRectFilled(
        imgui.ImVec2(bp.x, bp.y),
        imgui.ImVec2(bp.x + ww, bp.y + bannerH),
        mdcCol(imgui.ImVec4(0.08, 0.13, 0.24, 1.0)), 5.0)

    local titleStr = "ESO  //  EMERGENCY SERVICES OVERHAUL"
    local tw = imgui.CalcTextSize(titleStr).x
    imgui.SetCursorScreenPos(imgui.ImVec2(bp.x + (ww - tw) * 0.5, bp.y + 10))
    imgui.TextColored(C.headerText, u8(titleStr))
    imgui.Dummy(imgui.ImVec2(0, bannerH + 4))

    -- Инфо-блок
    local function row(lbl, val, valCol)
        valCol = valCol or C.textMain
        imgui.TextColored(C.textLabel, u8(lbl))
        imgui.SameLine(130)
        imgui.TextColored(valCol, u8(val))
    end

    row("Версия:",      "v1.3", C.accent)
    row("Наименование:",       "MDC extended p2",               C.textMain)
    row("Статус версии:",   "релиз",    C.textDim)
    row("Обратная связь:",   "DS: strangelovesendsherregards",    C.textDim)
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    row("Компилятор:",  _VERSION,                C.textDim)
    row("os.clock():",  string.format("%.1f s",  os.clock()), C.textDim)
    row("Дата запуска:", os.date("%Y-%m-%d %H:%M"), C.textDim)

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    -- Список модулей MDC OS
    imgui.TextColored(C.textLabel, u8("Зарегистрированные модули борткомпьютера:"))
    imgui.Spacing()
    for i, app in ipairs(MDC_APPS) do
        local bullet = "[" .. i .. "]"
        imgui.TextColored(C.accentDim, u8(bullet))
        imgui.SameLine()
        imgui.TextColored(C.textMain, u8(app.label))
        imgui.SameLine()
        imgui.TextColored(C.textDim, u8("  id=" .. app.id))
    end

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    -- Фиче-лист
    imgui.TextColored(C.textLabel, u8("Планируемые модули:"))
    imgui.Spacing()
    local feats = {
        "[INFO] Информация об офицере, статистика, логи",
        "[CAD] Диспетчер, обработка вызовов",
        "[VEH] Расширенная информация об опросе транспорта",
        "[FTO] Справочник и чек-лист для офицера академии",
        "[PENAL] Сборник УК, АК, ПК",
        -- "[REPORT] Генератор отчётов об инцидентах, арестах, штрафах",
        "[ABOUT] Информация о скрипте",
    }
    for _, f in ipairs(feats) do
        imgui.TextColored(C.accent, u8("> "))
        imgui.SameLine()
        imgui.TextColored(C.textMain, u8(f))
    end
	imgui.Spacing()
    imgui.TextColored(C.textLabel, u8("Сноска про иммерсивность:"))
    imgui.Spacing()
    local feats = {
        "Основная функция скрипта - реализована.",
        "Всё, что привносят обновления, начиная с v1.2, это",
        "лишь дополнительный функционал для иммерсивности.",
        "Использовать его или нет - решает сам игрок.",
    }
    for _, f in ipairs(feats) do
        imgui.TextColored(C.accent, u8("> "))
        imgui.SameLine()
        imgui.TextColored(C.textMain, u8(f))
    end
	
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
    imgui.TextColored(C.textDim, u8("Файл с настройками:  " .. ESO_SETTINGS_FILE))
    imgui.TextColored(C.textDim, u8("Файл с личным делом:   " .. ESO_OFFICER_FILE))
end


-- ¦          ДИСПЕТЧЕР ПРИЛОЖЕНИЙ (роутер)                  ¦

local function mdcOsRenderApp(appId)
    if appId == "home"  then mdcRenderHome()  return end
    if appId == "about" then mdcRenderAbout() return end
    -- if appId == "cad"   then mdcRenderCAD()   return end
    -- if appId == "veh"   then mdcRenderVEH()   return end
    -- if appId == "fto"   then mdcRenderFTO()   return end
    -- if appId == "penal" then mdcRenderPenal() return end
    -- Placeholder для новых приложений
    imgui.Spacing()
    imgui.TextColored(MDC_COL.textDim, "  [Приложение не реализовано: " .. tostring(appId) .. "]")
end


-- ¦                  MDC OS UI (imgui frame)                ¦

local mdcOsUI = imgui.OnFrame(
    function() return mdcOsOpen or mdcOsAlpha > 0.01 end,
    function()
        if myHudFont == nil then return end

        if mdcOsOpen then
            if mdcOsAlpha < 1.0 then mdcOsAlpha = mdcOsAlpha + 0.07 end
            if mdcOsAlpha > 1.0 then mdcOsAlpha = 1.0 end
        else
            if mdcOsAlpha > 0.0 then mdcOsAlpha = mdcOsAlpha - 0.07 end
            if mdcOsAlpha < 0.0 then mdcOsAlpha = 0.0 end
            if mdcOsAlpha <= 0.0 then return end
        end

        local C   = MDC_COL
        local io_ = imgui.GetIO()
        local sw, sh = io_.DisplaySize.x, io_.DisplaySize.y

        local wx = esoSettings.mdcOsWindowX >= 0 and esoSettings.mdcOsWindowX or (sw * 0.5 - MDC_OS_W * 0.5)
        local wy = esoSettings.mdcOsWindowY >= 0 and esoSettings.mdcOsWindowY or (sh * 0.5 - MDC_OS_H * 0.5)

        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha,           mdcOsAlpha)
        imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding,  6.0)
        imgui.PushStyleVarVec2 (imgui.StyleVar.WindowPadding,   imgui.ImVec2(0, 0))
        imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 1.2)
        imgui.PushStyleColor(imgui.Col.WindowBg, C.bg)
        imgui.PushStyleColor(imgui.Col.Border,   imgui.ImVec4(0.18, 0.22, 0.32, 0.90))

        imgui.SetNextWindowPos(imgui.ImVec2(wx, wy), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowSize(imgui.ImVec2(MDC_OS_W, MDC_OS_H), imgui.Cond.Always)

        local wFlags = imgui.WindowFlags.NoTitleBar
                     + imgui.WindowFlags.NoResize
                     + imgui.WindowFlags.NoScrollbar
                     + imgui.WindowFlags.NoScrollWithMouse

        if imgui.Begin("MDC_OS_MAIN", nil, wFlags) then
            imgui.PushFont(myHudFont)

            local dl = imgui.GetWindowDrawList()
            local wp = imgui.GetWindowPos()
            local ws = imgui.GetWindowSize()

            if wp.x ~= esoSettings.mdcOsWindowX or wp.y ~= esoSettings.mdcOsWindowY then
                esoSettings.mdcOsWindowX = wp.x
                esoSettings.mdcOsWindowY = wp.y
            end

            local HEADER_H = 28
            local TASKBAR_H= 24
            local SIDEBAR_W= 110

            dl:AddRectFilled(
                imgui.ImVec2(wp.x, wp.y),
                imgui.ImVec2(wp.x + ws.x, wp.y + HEADER_H),
                mdcCol(C.header))
            dl:AddLine(
                imgui.ImVec2(wp.x, wp.y + HEADER_H),
                imgui.ImVec2(wp.x + ws.x, wp.y + HEADER_H),
                mdcCol(C.accent), 1.0)

            imgui.SetCursorPos(imgui.ImVec2(14, 8))
            imgui.TextColored(C.headerText, u8("ESO  //  МОБИЛЬНЫЙ ТЕРМИНАЛ ДАННЫХ"))

            imgui.SameLine(ws.x - 30)
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0,0,0,0))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, C.closeBtn)
            imgui.PushStyleColor(imgui.Col.ButtonActive,  C.closeBtnHov)
            imgui.PushStyleColor(imgui.Col.Text,          imgui.ImVec4(0.65, 0.30, 0.30, 1.0))
            if imgui.Button("X##mdcos_close", imgui.ImVec2(22, 18)) then
                mdcOsOpen = false
                esoSettings.mdcOsLastApp = mdcOsActiveApp or "home"
                settingsSave()
                local hRaw = readMemory(0xB6F258, 4, false)
                local vRaw = readMemory(0xB6F250, 4, false)
                showCursor(false)
                writeMemory(0xB6F258, 4, hRaw, false)
                writeMemory(0xB6F250, 4, vRaw, false)
            end
            imgui.PopStyleColor(4)

            dl:AddRectFilled(
                imgui.ImVec2(wp.x, wp.y + HEADER_H),
                imgui.ImVec2(wp.x + SIDEBAR_W, wp.y + ws.y - TASKBAR_H),
                mdcCol(C.sidebar))
            dl:AddLine(
                imgui.ImVec2(wp.x + SIDEBAR_W, wp.y + HEADER_H),
                imgui.ImVec2(wp.x + SIDEBAR_W, wp.y + ws.y - TASKBAR_H),
                mdcCol(C.sep), 1.0)

            local ICON_W = SIDEBAR_W - 16
            local ICON_H = 54
            local iconStartY = HEADER_H + 10

            for i, app in ipairs(MDC_APPS) do
                local isActive = (mdcOsActiveApp == app.id)
                local iy = iconStartY + (i - 1) * (ICON_H + 8)

                local ibgColor = isActive and C.iconBgSel or C.iconBg
                local ibgRect0 = imgui.ImVec2(wp.x + 8, wp.y + iy)
                local ibgRect1 = imgui.ImVec2(wp.x + 8 + ICON_W, wp.y + iy + ICON_H)

                dl:AddRectFilled(ibgRect0, ibgRect1, mdcCol(ibgColor), 5.0)
                if isActive then
                    dl:AddRect(ibgRect0, ibgRect1, mdcCol(C.accent), 5.0, 0, 1.2)
                end

                local iconTextW = imgui.CalcTextSize(app.icon).x
                imgui.SetCursorPos(imgui.ImVec2(8 + (ICON_W - iconTextW) * 0.5, iy + 8))
                imgui.TextColored(isActive and C.accent or C.textDim, app.icon)

                local lblW = imgui.CalcTextSize(app.label).x
                imgui.SetCursorPos(imgui.ImVec2(8 + (ICON_W - lblW) * 0.5, iy + 26))
                imgui.TextColored(isActive and C.textMain or C.textDim, app.label)

                imgui.SetCursorPos(imgui.ImVec2(8, iy))
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0,0,0,0))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1,1,1,0.05))
                imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(1,1,1,0.10))
                if imgui.Button("##icon_" .. app.id, imgui.ImVec2(ICON_W, ICON_H)) then
                    mdcOsActiveApp = app.id
                    esoSettings.mdcOsLastApp = app.id
                end
                imgui.PopStyleColor(3)
            end

            local appAreaX = SIDEBAR_W
            local appAreaY = HEADER_H
            local appAreaW = ws.x - SIDEBAR_W
            local appAreaH = ws.y - HEADER_H - TASKBAR_H

            dl:AddRectFilled(
                imgui.ImVec2(wp.x + appAreaX, wp.y + appAreaY),
                imgui.ImVec2(wp.x + appAreaX + appAreaW, wp.y + appAreaY + appAreaH),
                mdcCol(C.appBg))

            local appTitle = "—"
            for _, a in ipairs(MDC_APPS) do
                if a.id == mdcOsActiveApp then appTitle = a.label; break end
            end
            local appSubHeaderH = 22
            dl:AddRectFilled(
                imgui.ImVec2(wp.x + appAreaX, wp.y + appAreaY),
                imgui.ImVec2(wp.x + appAreaX + appAreaW, wp.y + appAreaY + appSubHeaderH),
                mdcCol(imgui.ImVec4(0.08, 0.09, 0.13, 1.0)))
            dl:AddLine(
                imgui.ImVec2(wp.x + appAreaX, wp.y + appAreaY + appSubHeaderH),
                imgui.ImVec2(wp.x + ws.x, wp.y + appAreaY + appSubHeaderH),
                mdcCol(C.sep), 1.0)

            imgui.SetCursorPos(imgui.ImVec2(appAreaX + 10, appAreaY + 5))
            imgui.TextColored(C.textDim, appTitle)

            local contentPad = 10
            imgui.SetCursorPos(imgui.ImVec2(
                appAreaX + contentPad,
                appAreaY + appSubHeaderH + contentPad
            ))
            local childW = appAreaW - contentPad * 2
            local childH = appAreaH - appSubHeaderH - contentPad * 2

            if imgui.BeginChild("##mdc_app_content", imgui.ImVec2(childW, childH), false) then
                if mdcOsActiveApp then
                    mdcOsRenderApp(mdcOsActiveApp)
                else
                    imgui.Dummy(imgui.ImVec2(0, childH * 0.3))
                    local hint = u8("Выберите приложение в панели слева")
                    local hw   = imgui.CalcTextSize(hint).x
                    imgui.SetCursorPosX((childW - hw) * 0.5)
                    imgui.TextColored(C.textDim, hint)
                end
                imgui.EndChild()
            end

            local tbY = ws.y - TASKBAR_H
            dl:AddRectFilled(
                imgui.ImVec2(wp.x, wp.y + tbY),
                imgui.ImVec2(wp.x + ws.x, wp.y + ws.y),
                mdcCol(C.taskbar))
            dl:AddLine(
                imgui.ImVec2(wp.x, wp.y + tbY),
                imgui.ImVec2(wp.x + ws.x, wp.y + tbY),
                mdcCol(C.accent), 1.0)

            imgui.SetCursorPos(imgui.ImVec2(4, tbY + 4))
            imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, C.iconBgSel)
            if imgui.Button(" Desktop ", imgui.ImVec2(0, 16)) then
                mdcOsActiveApp = nil
            end
            imgui.PopStyleColor(2)

            if mdcOsActiveApp then
                imgui.SameLine(90)
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.12, 0.18, 0.30, 0.80))
                imgui.Button("  " .. appTitle .. "  ##tb_app", imgui.ImVec2(0, 16))
                imgui.PopStyleColor()
            end

            mdcOsTaskbarTime = os.date("%H:%M")
            local timeW = imgui.CalcTextSize(mdcOsTaskbarTime).x
            imgui.SetCursorPos(imgui.ImVec2(ws.x - timeW - 10, tbY + 5))
            imgui.TextColored(C.taskbarText, mdcOsTaskbarTime)

            imgui.PopFont()
            imgui.End()
        end

        imgui.PopStyleColor(2)
        imgui.PopStyleVar(4)
    end
)
mdcOsUI.LockPlayer = false
mdcOsUI.HideCursor = false


-- ¦            MDC OS: хоткей и команда /mdc                ¦

-- Хоткей Alt+M (только в полицейской машине)
lua_thread.create(function()
    while true do
        wait(0)

        if isKeyDown(VK_LMENU) and isKeyJustPressed(0x4D) -- M
            and not sampIsChatInputActive()
            and not isSampfuncsConsoleActive()
            and isInServiceVehicle(PLAYER_PED)
        then
            mdcOsOpen = not mdcOsOpen
            if mdcOsOpen then
                mdcOsActiveApp = esoSettings.mdcOsLastApp or "home"
                showCursor(true)
            else
                esoSettings.mdcOsLastApp = mdcOsActiveApp or "home"
                settingsSave()
                local hRaw = readMemory(0xB6F258, 4, false)
                local vRaw = readMemory(0xB6F250, 4, false)
                showCursor(false)
                writeMemory(0xB6F258, 4, hRaw, false)
                writeMemory(0xB6F250, 4, vRaw, false)
            end
        end
    end
end)

sampRegisterChatCommand("mdc", function()
    if not isInServiceVehicle(PLAYER_PED) then
        sampAddChatMessage("[ESO] MDC доступен только в служебном транспорте.", 0xFF6A00)
        return
    end
    mdcOsOpen = not mdcOsOpen
    if mdcOsOpen then
        mdcOsActiveApp = esoSettings.mdcOsLastApp or "home"
        showCursor(true)
    else
        esoSettings.mdcOsLastApp = mdcOsActiveApp or "home"
        settingsSave()
        local hRaw = readMemory(0xB6F258, 4, false)
        local vRaw = readMemory(0xB6F250, 4, false)
        showCursor(false)
        writeMemory(0xB6F258, 4, hRaw, false)
        writeMemory(0xB6F250, 4, vRaw, false)
    end
end)

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
                imgui.TextColored(C_TXT, u8('  by Weisez~   |   v1.3 MDC extended p2'))
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
                row('[RShift]', u8('Вкл / Выкл тихую сирену (только с AVS)'))
                row(u8'Важно:', u8('В конфиге AVS необходимо поменять хоткей тихой сирены'))
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
