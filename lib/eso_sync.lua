-- eso_sync.lua: облачная синхронизация для Emergency Services Overhaul.
-- Кладётся в moonloader/lib/. Код ASCII, кириллица только в комментариях (UTF-8);
-- тексты для чата формирует EMS.lua через opts.onStatus.
--
-- Транспорт: основной это поток effil + готовый requests (его вы поставляете вместе со скриптом),
-- запасной это curl.exe (Windows 10 1803+), если библиотек нет.
-- ВАЖНО: requests вызывает LuaSec без параметров, а у LuaSec по умолчанию verify = "none".
-- Соединение зашифровано, но сертификат сервера НЕ проверяется (осознанное решение, см. README).
-- Каллсигны: клиент забирает изменения по курсору updated_at. Период адаптивный: 6 с в машине или
-- сразу после событий, 15 с пешком, на паузе игры опроса нет.
-- Отчёты: пишутся в локальный outbox и уходят на сервер, пока не придёт ответ.

local ffi = require 'ffi'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local M = {}

local PROTO = 2
local SEP = package.config:sub(1, 1)   -- обратный слэш в Windows
local POLL_ACTIVE = 6             -- секунд: игрок в машине или недавно было событие
local POLL_IDLE = 15              -- секунд: игрок пешком и событий нет
local ACTIVE_WINDOW = 90          -- сколько секунд после события держится быстрый режим
local POLL_INTERVAL_MAX = 120
local MAX_PARALLEL = 2
local OUTBOX_MAX = 50
local CALLSIGN_TTL = 3600

M.PROTO = PROTO

-- ===================================================================
-- JSON (минимальная реализация, без зависимостей)
-- ===================================================================
local json = {}

local ESC = { ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
local function escStr(s)
    return (s:gsub('[%c"\\]', function(c) return ESC[c] or string.format('\\u%04x', c:byte()) end))
end

local function utf8char(cp)
    if cp < 0x80 then return string.char(cp) end
    if cp < 0x800 then return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40) end
    if cp < 0x10000 then
        return string.char(0xE0 + math.floor(cp / 0x1000), 0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
    end
    return string.char(0xF0 + math.floor(cp / 0x40000), 0x80 + math.floor(cp / 0x1000) % 0x40,
        0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
end

local function encodeValue(v, depth)
    if depth > 16 then error('json: too deep') end
    local t = type(v)
    if t == 'string' then return '"' .. escStr(v) .. '"' end
    if t == 'number' then
        if v ~= v or v == math.huge or v == -math.huge then return 'null' end
        -- %.0f, а не %d: в 32-битном процессе %d ломается на числах больше 2^31
        if v == math.floor(v) and math.abs(v) < 1e15 then return string.format('%.0f', v) end
        return string.format('%.14g', v)
    end
    if t == 'boolean' then return v and 'true' or 'false' end
    if t == 'table' then
        local out = {}
        if #v > 0 then
            for i = 1, #v do out[#out + 1] = encodeValue(v[i], depth + 1) end
            return '[' .. table.concat(out, ',') .. ']'
        end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local val = v[k]
            if val ~= nil then out[#out + 1] = '"' .. escStr(k) .. '":' .. encodeValue(val, depth + 1) end
        end
        return '{' .. table.concat(out, ',') .. '}'
    end
    if t == 'nil' then return 'null' end
    error('json: cannot encode ' .. t)
end

function json.encode(v) return encodeValue(v, 0) end

local UNESC = { b = '\b', f = '\f', n = '\n', r = '\r', t = '\t', ['"'] = '"', ['\\'] = '\\', ['/'] = '/' }

function json.decode(str)
    local pos = 1
    local parseValue

    local function skip()
        pos = str:find('[^ \t\r\n]', pos) or (#str + 1)
    end

    local function parseString()
        local buf, i = {}, pos + 1
        while true do
            local j = str:find('["\\]', i)
            if not j then error('json: unterminated string') end
            buf[#buf + 1] = str:sub(i, j - 1)
            if str:sub(j, j) == '"' then
                pos = j + 1
                return table.concat(buf)
            end
            local e = str:sub(j + 1, j + 1)
            if e == 'u' then
                local hex = str:sub(j + 2, j + 5)
                if not hex:match('^%x%x%x%x$') then error('json: bad unicode escape') end
                local cp = tonumber(hex, 16)
                i = j + 6
                if cp >= 0xD800 and cp <= 0xDBFF and str:sub(i, i + 1) == '\\u' then
                    local lo = tonumber(str:sub(i + 2, i + 5), 16)
                    if lo and lo >= 0xDC00 and lo <= 0xDFFF then
                        cp = 0x10000 + (cp - 0xD800) * 0x400 + (lo - 0xDC00)
                        i = i + 6
                    end
                end
                buf[#buf + 1] = utf8char(cp)
            else
                local m = UNESC[e]
                if not m then error('json: bad escape') end
                buf[#buf + 1] = m
                i = j + 2
            end
        end
    end

    local function parseNumber()
        local s = str:match('^-?%d+%.?%d*[eE]?[%+%-]?%d*', pos)
        local n = s and tonumber(s)
        if not n then error('json: bad number') end
        pos = pos + #s
        return n
    end

    local function parseContainer(open, close, depth)
        local out = {}
        pos = pos + 1
        skip()
        if str:sub(pos, pos) == close then pos = pos + 1; return out end
        while true do
            skip()
            if open == '{' then
                if str:sub(pos, pos) ~= '"' then error('json: key expected') end
                local k = parseString()
                skip()
                if str:sub(pos, pos) ~= ':' then error('json: colon expected') end
                pos = pos + 1
                out[k] = parseValue(depth + 1)
            else
                out[#out + 1] = parseValue(depth + 1)
            end
            skip()
            local c = str:sub(pos, pos)
            pos = pos + 1
            if c == close then return out end
            if c ~= ',' then error('json: comma expected') end
        end
    end

    parseValue = function(depth)
        if depth > 20 then error('json: too deep') end
        skip()
        local c = str:sub(pos, pos)
        if c == '{' then return parseContainer('{', '}', depth) end
        if c == '[' then return parseContainer('[', ']', depth) end
        if c == '"' then return parseString() end
        if str:sub(pos, pos + 3) == 'true' then pos = pos + 4; return true end
        if str:sub(pos, pos + 4) == 'false' then pos = pos + 5; return false end
        if str:sub(pos, pos + 3) == 'null' then pos = pos + 4; return nil end
        return parseNumber()
    end

    local v = parseValue(0)
    skip()
    if pos <= #str then error('json: trailing data') end
    return v
end

M.json = json

-- ===================================================================
-- Вспомогательное
-- ===================================================================
local clock = os.clock
local function now() return clock() end

local function urlenc(s)
    return (tostring(s):gsub('[^%w%-_%.~]', function(c) return string.format('%%%02X', c:byte()) end))
end

local function hex(bytes)
    return (bytes:gsub('.', function(c) return string.format('%02x', c:byte()) end))
end

-- Каллсигн приходит и уходит в CP1251. Правила те же, что на сервере.
local function sanitizeCallsign(s)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('{%x%x%x%x%x%x}', ''):gsub('\r', ''):gsub('[%z\1-\9\11\12\14-\31\127]', '')
    local lines = {}
    for line in (s .. '\n'):gmatch('([^\n]*)\n') do
        line = line:match('^%s*(.-)%s*$')
        if line ~= '' then lines[#lines + 1] = line end
        if #lines == 3 then break end
    end
    local out = table.concat(lines, '\n'):sub(1, 80)
    if out == '' then return nil end
    return out
end
M._sanitizeCallsign = sanitizeCallsign

-- Подразделение из свободного текста (HOME -> DEPT) в один из четырёх кодов.
-- Кириллица задана escape-последовательностями CP1251: ASCII-файл не зависит от кодировки.
local function lowerCp1251(s)
    return (s:lower():gsub('[\192-\223]', function(c) return string.char(c:byte() + 32) end):gsub('\168', '\184'))
end

local DEPT_PATTERNS = {
    { 'LSPD', { 'lspd', 'los%s*santos', '\235\241\239\228', '\235\238\241[%s%-]*\241\224\237\242\238\241' } },
    { 'SFPD', { 'sfpd', 'san%s*fierro', '\241\244\239\228', '\241\224\237[%s%-]*\244\232\229\240\240\238' } },
    { 'LVPD', { 'lvpd', 'las%s*venturas', '\235\226\239\228', '\235\224\241[%s%-]*\226\229\237\242\243\240\224\241' } },
    { 'FBI',  { 'fbi', '\244\225\240', '\244\229\228\229\240\224\235' } },
}

function M.normalizeDept(s)
    if type(s) ~= 'string' or s == '' then return nil end
    local low = lowerCp1251(s)
    for _, d in ipairs(DEPT_PATTERNS) do
        for _, p in ipairs(d[2]) do
            if low:find(p) then return d[1] end
        end
    end
    return nil
end

M.DEPTS = { 'LSPD', 'SFPD', 'LVPD', 'FBI' }

local REPORT_FIELDS = {
    uof    = { 'location', 'datetime', 'weapon', 'equipment', 'officersCount', 'seniorOfficer', 'details',
               'department', 'unit', 'officerBadge', 'officerRank', 'officerNick' },
    arrest = { 'suspectName', 'datetime', 'charges', 'location', 'forceUsed', 'witnesses', 'details',
               'department', 'unit', 'officerBadge', 'officerRank', 'officerNick' },
    situ   = { 'situationType', 'datetime', 'location', 'unitsInvolved', 'outcome', 'casualties', 'details',
               'department', 'unit', 'officerBadge', 'officerRank', 'officerNick' },
}

-- ===================================================================
-- Случайные числа и идентификатор установки
-- ===================================================================
local rngHook = nil    -- подмена источника случайности в тестах

-- Системный криптостойкий генератор. Возвращает строку из n байт или nil, если ни один не доступен.
-- ВАЖНО: advapi32.dll и bcrypt.dll не входят в «стандартное пространство» ffi.C в LuaJIT на Windows
-- (там только exe, CRT, kernel32, user32 и gdi32), поэтому их надо загружать явно через ffi.load.
-- Вызов ffi.C.SystemFunction036 в версии 2.0 не находил функцию, и клиент выключал синхронизацию (norng).
local function secureBytes(n)
    if rngHook then return rngHook(n) end
    local buf = ffi.new('uint8_t[?]', n)

    -- 1. RtlGenRandom (advapi32.dll), доступен на всех версиях Windows. Возвращает BOOLEAN.
    local ok1, r1 = pcall(function()
        pcall(ffi.cdef, 'unsigned char __stdcall SystemFunction036(void* buf, unsigned long len);')
        local lib = ffi.load('advapi32')
        if lib.SystemFunction036(buf, n) == 0 then error('RtlGenRandom failed') end
        return ffi.string(buf, n)
    end)
    if ok1 then return r1 end

    -- 2. BCryptGenRandom (bcrypt.dll), Windows Vista и новее. 2 = BCRYPT_USE_SYSTEM_PREFERRED_RNG, 0 = успех.
    local ok2, r2 = pcall(function()
        pcall(ffi.cdef, 'long __stdcall BCryptGenRandom(void* alg, uint8_t* buf, unsigned long len, unsigned long flags);')
        local lib = ffi.load('bcrypt')
        if lib.BCryptGenRandom(nil, buf, n, 2) ~= 0 then error('BCryptGenRandom failed') end
        return ffi.string(buf, n)
    end)
    if ok2 then return r2 end
    return nil
end
M._secureBytes = secureBytes

-- Слабый генератор нужен только для ID отчётов (они не секретны, важна лишь уникальность).
-- Для секретов установки он НЕ используется: нет системного генератора, нет синхронизации.
local function weakBytes(n)
    if not M._seeded then
        M._seeded = true
        math.randomseed(os.time() + math.floor(os.clock() * 1000) + tonumber(tostring({}):match('0x(%x+)') or '0', 16))
    end
    local t = {}
    for i = 1, n do t[i] = string.char(math.random(0, 255)) end
    return table.concat(t)
end

function M.newId() return hex(secureBytes(16) or weakBytes(16)) end

-- ===================================================================
-- Транспорт: curl.exe через CreateProcess (Windows)
-- ===================================================================
local function makeWinTransport(dir)
    local T = {}
    local C = ffi.C
    local seq = 0

    pcall(ffi.cdef, [[
        typedef struct {
            unsigned long cb; char* lpReserved; char* lpDesktop; char* lpTitle;
            unsigned long dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
            unsigned short wShowWindow, cbReserved2; unsigned char* lpReserved2;
            void* hStdInput; void* hStdOutput; void* hStdError;
        } ESO_STARTUPINFOA;
        typedef struct { void* hProcess; void* hThread; unsigned long dwProcessId, dwThreadId; } ESO_PROCESS_INFORMATION;
    ]])
    pcall(ffi.cdef, 'int CreateProcessA(const char*, char*, void*, void*, int, unsigned long, void*, const char*, void*, void*);')
    pcall(ffi.cdef, 'unsigned long WaitForSingleObject(void*, unsigned long);')
    pcall(ffi.cdef, 'int GetExitCodeProcess(void*, unsigned long*);')
    pcall(ffi.cdef, 'int CloseHandle(void*);')
    pcall(ffi.cdef, 'int TerminateProcess(void*, unsigned int);')

    local sysroot = os.getenv('SystemRoot') or 'C:\\Windows'
    local curl = sysroot .. '\\System32\\curl.exe'
    local f = io.open(curl, 'rb')
    if f then f:close() else
        curl = sysroot .. '\\SysWOW64\\curl.exe'
        f = io.open(curl, 'rb')
        if f then f:close() else return nil, 'curl.exe not found' end
    end

    local tmp = dir .. 'tmp' .. SEP

    local function readAll(path)
        local h = io.open(path, 'rb')
        if not h then return nil end
        local s = h:read('*a')
        h:close()
        return s
    end

    function T.start(req)
        seq = seq + 1
        local base = tmp .. 'r' .. seq .. '_' .. math.random(1000, 9999)
        local files = { out = base .. '.out', hdr = base .. '.hdr', body = nil }
        local args = {
            '"' .. curl .. '"', '-sS', '--connect-timeout', '6', '-m', '12', '--ssl-no-revoke',
            '-X', req.method,
            '-H', '"Authorization: Bearer ' .. req.token .. '"',
            '-H', '"X-ESO-Proto: ' .. PROTO .. '"',
            '-H', '"User-Agent: ESO-Sync/' .. req.ua .. '"',
            '-o', '"' .. files.out .. '"', '-D', '"' .. files.hdr .. '"',
        }
        if req.body then
            files.body = base .. '.in'
            local h = io.open(files.body, 'wb')
            if not h then return nil, 'cannot write temp file' end
            h:write(req.body)
            h:close()
            args[#args + 1] = '-H'
            args[#args + 1] = '"Content-Type: application/json"'
            args[#args + 1] = '--data-binary'
            args[#args + 1] = '"@' .. files.body .. '"'
        end
        args[#args + 1] = '"' .. req.url .. '"'
        local cmd = table.concat(args, ' ')

        local ok, handle = pcall(function()
            local si = ffi.new('ESO_STARTUPINFOA')
            si.cb = ffi.sizeof(si)
            si.dwFlags = 1          -- STARTF_USESHOWWINDOW
            si.wShowWindow = 0      -- SW_HIDE
            local pi = ffi.new('ESO_PROCESS_INFORMATION')
            local buf = ffi.new('char[?]', #cmd + 1, cmd)
            -- 0x08000000 = CREATE_NO_WINDOW
            if C.CreateProcessA(nil, buf, nil, nil, 0, 0x08000000, nil, nil, si, pi) == 0 then
                error('CreateProcess failed')
            end
            C.CloseHandle(pi.hThread)
            return pi.hProcess
        end)
        if not ok then
            if files.body then os.remove(files.body) end
            return nil, tostring(handle)
        end
        return { h = handle, files = files, t0 = now() }
    end

    local function cleanup(job)
        pcall(function() C.CloseHandle(job.h) end)
        os.remove(job.files.out)
        os.remove(job.files.hdr)
        if job.files.body then os.remove(job.files.body) end
    end

    function T.poll(job)
        local state = C.WaitForSingleObject(job.h, 0)
        if state ~= 0 then
            if now() - job.t0 > 20 then            -- страховка поверх -m 12
                pcall(function() C.TerminateProcess(job.h, 1) end)
                cleanup(job)
                return true, { err = 'timeout' }
            end
            return false
        end
        local code = ffi.new('unsigned long[1]')
        C.GetExitCodeProcess(job.h, code)
        local hdr = readAll(job.files.hdr) or ''
        local body = readAll(job.files.out)
        cleanup(job)
        local status
        for s in hdr:gmatch('HTTP/%S+ (%d+)') do status = tonumber(s) end
        if code[0] ~= 0 and not status then return true, { err = 'curl exit ' .. tostring(code[0]) } end
        return true, { status = status, body = body }
    end

    function T.cancel(job)
        pcall(function() C.TerminateProcess(job.h, 1) end)
        cleanup(job)
    end

    function T.sweep()
        local ok, lfs = pcall(require, 'lfs')
        if not ok then return end
        local p = tmp:gsub('[\\/]+$', '')
        local it, st, init = lfs.dir(p)
        if not it then return end
        for name in it, st, init do
            if name ~= '.' and name ~= '..' then os.remove(tmp .. name) end
        end
    end

    return T
end

-- ===================================================================
-- Транспорт: поток effil + requests (основной)
-- ===================================================================
-- Возвращает транспорт или nil + 'nolibs' + подробность.
-- Функция потока не должна иметь upvalue: effil копирует её в другое Lua-состояние.
local function makeEffilTransport()
    local okE, effil = pcall(require, 'effil')
    if not okE then return nil, 'nolibs', 'effil: ' .. tostring(effil) end
    local okR, requests = pcall(require, 'requests')
    if not okR then return nil, 'nolibs', 'requests: ' .. tostring(requests) end

    local runner = effil.thread(function(method, url, headers, body, timeout)
        local okq, rq = pcall(require, 'requests')
        if not okq then return false, 'nolibs: requests: ' .. tostring(rq) end
        local args = { headers = headers, timeout = timeout }
        if body ~= '' then args.data = body end
        local ok, res = pcall(rq.request, method, url, args)
        if not ok then return false, tostring(res) end
        return true, res.status_code, res.text
    end)

    local T = {}
    function T.start(req)
        local headers = {
            ['Authorization'] = 'Bearer ' .. req.token,
            ['X-ESO-Proto'] = tostring(PROTO),
            ['User-Agent'] = 'ESO-Sync/' .. req.ua,
            ['Accept'] = 'application/json',
        }
        if req.body then headers['Content-Type'] = 'application/json' end
        local ok, th = pcall(runner, req.method, req.url, headers, req.body or '', 12)
        if not ok then return nil, 'thread: ' .. tostring(th) end
        return { th = th, t0 = now() }
    end

    function T.poll(job)
        local ok, status, err = pcall(function() return job.th:status() end)
        if not ok then return true, { err = 'thread: ' .. tostring(status) } end
        if err then return true, { err = 'thread: ' .. tostring(err) } end
        if status == 'completed' then
            local r = { pcall(function() return job.th:get() end) }
            if not r[1] then return true, { err = 'thread: ' .. tostring(r[2]) } end
            if r[2] then return true, { status = tonumber(r[3]), body = r[4] } end
            return true, { err = tostring(r[3]) }
        elseif status == 'failed' or status == 'canceled' or status == 'cancelled' then
            return true, { err = 'thread: ' .. tostring(status) }
        end
        if now() - job.t0 > 25 then              -- страховка поверх таймаута сокета (12 с)
            pcall(function() job.th:cancel() end)
            return true, { err = 'timeout' }
        end
        return false
    end

    function T.cancel(job) pcall(function() job.th:cancel() end) end
    T.name = 'effil'
    return T
end

-- ===================================================================
-- Состояние
-- ===================================================================
local SERVER_OFF_RECHECK = 300      -- пока сервер выключен аварийным выключателем, проверяем раз в 5 минут
local PERSIST_RETRY = 60            -- повтор доставки отчёта после первых трёх попыток

local opts, transport, dir
local inited = false
local running, queue = {}, {}
local cs = {}                       -- [veh] = { text = <cp1251>, deadline = <clock> }
local tokens = {}                   -- [ip:port] = секрет установки для этого игрового сервера
local regenerated = {}              -- [ip:port] = true, если секрет уже пересоздавался в этой сессии
local st = {
    cursor = 0, server = nil, nextPoll = 0, backoff = 0, activeUntil = 0, polling = false, lastShorten = 0,
    fails = 0, online = false, disabled = nil, serverOff = false,
    lastOk = nil, lastErr = nil, lastExpire = 0, lastTick = 0, motd = nil, legacyChecked = false,
}
M.reports = {}                      -- [dept .. '/' .. kind] = { items, loading, err, at, more }

local function log(s)
    if opts and opts.log then opts.log(s) else print('[ESO-SYNC] ' .. s) end
end

local function status(code, detail)
    if opts and opts.onStatus then pcall(opts.onStatus, code, detail) end
end

-- Создаёт всю цепочку папок: родительский каталог на момент старта может ещё не существовать.
local function ensureDir(path)
    local ok, lfs = pcall(require, 'lfs')
    if not ok then return end
    local p = path:gsub('[\\/]+$', '')
    local acc = ''
    for part in (p .. SEP):gmatch('([^\\/]*)[\\/]') do
        acc = (acc == '' and part == '') and SEP or (acc == SEP and (SEP .. part) or (acc == '' and part or (acc .. SEP .. part)))
        if part ~= '' and not acc:match('^%a:$') and lfs.attributes(acc, 'mode') ~= 'directory' then
            lfs.mkdir(acc)
        end
    end
end

-- ----- секреты установки: по одному на игровой сервер -----
-- Секрет привязан к серверу на стороне Worker, поэтому для каждого сервера нужен свой файл.
-- Секрет это bearer-токен: его нельзя публиковать и пересылать (в том числе на скриншотах).
local function tokenPath(server)
    return dir .. 'sync_id_' .. tostring(server):gsub('[^%w]', '_') .. '.txt'
end

local function readToken(path)
    local h = io.open(path, 'rb')
    if not h then return nil end
    local raw = h:read('*a') or ''
    h:close()
    local s = raw:gsub('%s+', '')
    if s:match('^%x+$') and #s == 64 then return s:lower() end
    return nil
end

local function writeToken(path, t)
    local h = io.open(path, 'wb')
    if not h then return false end
    h:write(t)
    h:close()
    return true
end

-- Возвращает секрет или nil + причину ('norng', 'nowrite').
local function tokenFor(server)
    if tokens[server] then return tokens[server] end
    local path = tokenPath(server)
    local t = readToken(path)
    if not t and not st.legacyChecked then
        -- версия 1 хранила один общий sync_id.txt: усыновляем его для первого сервера
        st.legacyChecked = true
        local legacy = dir .. 'sync_id.txt'
        local lt = readToken(legacy)
        if lt and writeToken(path, lt) then
            os.rename(legacy, legacy .. '.migrated')
            t = lt
        end
    end
    if not t then
        local rnd = secureBytes(32)               -- 256 бит из системного CSPRNG
        if not rnd then return nil, 'norng' end
        t = hex(rnd)
        if not writeToken(path, t) then return nil, 'nowrite' end   -- без сохранения личность менялась бы при каждом запуске
    end
    tokens[server] = t
    return t
end

-- Сервер сказал server_mismatch: этот секрет принадлежит другому серверу (скопированный файл,
-- ручная правка базы). Один раз за сессию заводим новый секрет для данного сервера.
local function regenerateToken(server)
    if regenerated[server] then return false end
    regenerated[server] = true
    tokens[server] = nil
    os.remove(tokenPath(server))
    return tokenFor(server) ~= nil
end

-- ===================================================================
-- Очередь запросов
-- ===================================================================
-- req: method, path, body, server (ip:port, определяет секрет), key (замена в очереди),
--      lane (строгий порядок внутри одной сущности), retries, persist (хранится в outbox), cb
local function enqueue(req)
    if req.key then
        for i = #queue, 1, -1 do
            if queue[i].key == req.key then table.remove(queue, i) end
        end
    end
    queue[#queue + 1] = req
end

local RETRY_DELAYS = { 5, 15, 45 }

local function finish(req, res)
    local netFail = res.err ~= nil
    local decoded
    if not netFail and res.body and res.body ~= '' then
        local okj, v = pcall(json.decode, res.body)
        if okj and type(v) == 'table' then decoded = v end
    end
    local code = res.status
    local errName = decoded and decoded.error

    -- 1. Аварийный выключатель: ждём и ничего не теряем (отчёты остаются в outbox).
    if decoded and decoded.disabled then
        if not st.serverOff then
            st.serverOff = true
            status('server_off')
        end
        st.lastErr = 'disabled'
        if decoded.motd and decoded.motd ~= '' and decoded.motd ~= st.motd then
            st.motd = decoded.motd
            status('motd', u8:decode(decoded.motd))
        end
        if req.persist then
            req.notBefore = now() + SERVER_OFF_RECHECK
            table.insert(queue, 1, req)
            return
        end
        if req.cb then pcall(req.cb, false, res, decoded) end
        return
    end

    -- 2. Отказы, которые отключают синхронизацию целиком (отчёты остаются в outbox).
    if code == 426 then
        st.disabled = 'update_required'
        status('update_required')
    elseif code == 403 and errName == 'banned' then
        st.disabled = 'banned'
        status('banned')
    elseif code == 403 and errName == 'server_mismatch' and req.server then
        if regenerateToken(req.server) then
            table.insert(queue, 1, req)           -- повторяем с новым секретом
            return
        end
    end

    -- 3. Сеть, 5xx и 429: повторяем. Отказ по лимиту не означает «сервер недоступен».
    local retryable = netFail or (code and (code >= 500 or code == 429))
    if retryable then
        if netFail or code >= 500 then
            st.fails = st.fails + 1
            st.lastErr = res.err or ('http ' .. tostring(code))
            if st.fails >= 3 and st.online then
                st.online = false
                status('offline', st.lastErr)
            end
        end
        local tries = (req.tries or 0) + 1
        req.tries = tries
        if tries <= (req.retries or 0) then
            req.notBefore = now() + (RETRY_DELAYS[tries] or PERSIST_RETRY)
            table.insert(queue, 1, req)
            return
        end
        if req.cb then pcall(req.cb, false, res, decoded) end
        return
    end

    -- 4. Успех.
    if code and code >= 200 and code < 300 and decoded then
        st.fails = 0
        st.lastOk = now()
        st.lastErr = nil
        st.serverOff = false
        if not st.online then
            st.online = true
            status('online')
        end
        if req.cb then pcall(req.cb, true, decoded, res) end
        return
    end

    -- 5. Остальные 4xx: повторять бессмысленно.
    st.lastErr = 'http ' .. tostring(code)
    if req.cb then pcall(req.cb, false, res, decoded) end
end

local function startReq(req)
    local token, why = tokenFor(req.server)
    if not token then
        st.disabled = why or 'notoken'
        status(st.disabled)
        return
    end
    local job, err = transport.start({
        method = req.method, url = opts.baseUrl .. req.path, token = token,
        body = req.body, ua = opts.uaVersion,
    })
    if not job then
        finish(req, { err = err or 'spawn failed' })
        return
    end
    running[#running + 1] = { req = req, job = job }
end

local function laneBusy(lane)
    for _, r in ipairs(running) do
        if r.req.lane == lane then return true end
    end
    return false
end

local function pump()
    for i = #running, 1, -1 do
        local r = running[i]
        local done, res = transport.poll(r.job)
        if done then
            table.remove(running, i)
            finish(r.req, res)
        end
    end
    local t = now()
    local blocked = {}
    local i = 1
    while #running < MAX_PARALLEL and i <= #queue do
        local req = queue[i]
        local lane = req.lane
        local skip = false
        if lane and (blocked[lane] or laneBusy(lane)) then
            skip = true                           -- предыдущая операция с той же сущностью ещё не закончена
        elseif (req.notBefore or 0) > t then
            skip = true
            if lane then blocked[lane] = true end -- ждущую повтора операцию последующие не обгоняют
        end
        if skip then
            i = i + 1
        else
            table.remove(queue, i)
            startReq(req)
        end
    end
end

-- ===================================================================
-- Каллсигны
-- ===================================================================
local function emit(changes)
    if #changes > 0 and opts.onCallsigns then
        local ok, err = pcall(opts.onCallsigns, changes)
        if not ok then log('onCallsigns error: ' .. tostring(err)) end
    end
end

-- Задержка до следующего опроса: быстрая в машине и сразу после событий, медленная в простое.
-- Небольшой джиттер, чтобы клиенты не били по серверу в один момент.
local function pollDelay()
    local fast = now() < st.activeUntil
    if not fast and opts.isActive then
        local okA, a = pcall(opts.isActive)
        fast = okA and a and true or false
    end
    return (fast and POLL_ACTIVE or POLL_IDLE) + math.random() * 1.5
end

local function onPoll(ok, j)
    st.polling = false
    if not ok then
        if st.serverOff then
            st.nextPoll = now() + SERVER_OFF_RECHECK
        else
            st.backoff = math.min(POLL_INTERVAL_MAX, math.max(10, (st.backoff or 0) * 2))
            st.nextPoll = now() + st.backoff
        end
        return
    end
    st.backoff = 0
    if j.motd and j.motd ~= '' and j.motd ~= st.motd then
        st.motd = j.motd
        status('motd', u8:decode(j.motd))
    end
    st.cursor = tonumber(j.cursor) or st.cursor
    local t = now()
    local changes = {}
    for _, it in ipairs(j.items or {}) do
        local veh = tonumber(it.veh)
        if veh then
            if type(it.text) == 'string' then
                local text = u8:decode(it.text)
                local old = cs[veh]
                local ttl = tonumber(it.ttl) or CALLSIGN_TTL
                cs[veh] = { text = text, deadline = t + ttl }
                if not old or old.text ~= text then
                    changes[#changes + 1] = { veh = veh, text = text }
                end
            elseif cs[veh] then
                cs[veh] = nil
                changes[#changes + 1] = { veh = veh, text = nil }
            end
        end
    end
    emit(changes)
    if #changes > 0 then st.activeUntil = t + ACTIVE_WINDOW end
    st.nextPoll = j.more and t or (t + pollDelay())
end

local function startPoll()
    local sk = opts.serverKey and opts.serverKey() or nil
    if not sk then st.nextPoll = now() + 3; return end
    if sk ~= st.server then
        -- переподключились к другому серверу: чужие каллсигны к новому не относятся
        local changes = {}
        for veh in pairs(cs) do changes[#changes + 1] = { veh = veh, text = nil } end
        cs = {}
        st.server, st.cursor = sk, 0
        emit(changes)
    end
    local since = st.cursor > 0 and math.max(0, st.cursor - 2000) or 0
    st.nextPoll = now() + 3600           -- пока запрос в пути, не планируем следующий
    st.polling = true
    enqueue({
        method = 'GET', key = 'poll', isPoll = true, retries = 0, cb = onPoll, server = sk,
        path = '/v1/callsigns?server=' .. urlenc(sk) .. '&since=' .. string.format('%.0f', since),
    })
end

local function expireLocal()
    local t = now()
    if t - st.lastExpire < 5 then return end
    st.lastExpire = t
    local changes
    for veh, e in pairs(cs) do
        if e.deadline < t then
            cs[veh] = nil
            changes = changes or {}
            changes[#changes + 1] = { veh = veh, text = nil, expired = true }
        end
    end
    if changes then emit(changes) end
end

-- ===================================================================
-- Outbox: отчёты переживают перезапуск игры, обрыв связи и выключатель на сервере
-- ===================================================================
local function outboxFile(key) return dir .. 'outbox' .. SEP .. key .. '.json' end

local function outboxWrite(key, path, body, server)
    local h = io.open(outboxFile(key), 'wb')
    if h then
        h:write(json.encode({ path = path, body = body, server = server }))
        h:close()
    end
end

-- Файл из outbox удаляется только если сервер окончательно отказал в ЭТОЙ операции.
-- Выключатель, бан, обновление протокола, лимиты и сбои сети файл не удаляют.
local function isPermanent(res, decoded)
    local code = res and res.status
    local err = decoded and decoded.error
    return code == 400 or code == 404 or code == 410 or code == 413 or (code == 403 and err == 'not_owner')
end

local function outboxSend(key, path, body, server)
    enqueue({
        method = 'POST', path = path, body = body, key = key, server = server,
        lane = 'rep:' .. key:sub(4), retries = math.huge, persist = true,
        cb = function(ok, res, decoded)
            if ok then
                os.remove(outboxFile(key))
                return
            end
            if isPermanent(res, decoded) then
                os.remove(outboxFile(key))
                local code = res and res.status
                -- удалять уже удалённое и дописывать в удалённое это не ошибка пользователя
                local quiet = code == 410 or (code == 404 and key:sub(1, 3) == 'rd_')
                if not quiet then
                    local err = decoded and decoded.error or tostring(code)
                    log('rejected by server (' .. key .. '): ' .. tostring(err))
                    status('rejected', err)
                end
            end
        end,
    })
end

local function outboxLoad()
    local ok, lfs = pcall(require, 'lfs')
    if not ok then return end
    local p = (dir .. 'outbox'):gsub('[\\/]+$', '')
    local it, stt, init = lfs.dir(p)
    if not it then return end
    local n = 0
    for name in it, stt, init do
        local key = name:match('^(r[pd]_%x+)%.json$')
        if key and n < OUTBOX_MAX then
            local h = io.open(outboxFile(key), 'rb')
            if h then
                local s = h:read('*a'); h:close()
                local okj, v = pcall(json.decode, s)
                if okj and type(v) == 'table' and v.path and v.body then
                    local server = v.server
                    if not server then   -- файл версии 1: сервер лежит внутри тела
                        local okb, b = pcall(json.decode, v.body)
                        if okb and type(b) == 'table' then server = b.server end
                    end
                    if server then
                        outboxSend(key, v.path, v.body, server)
                        n = n + 1
                    else
                        os.remove(outboxFile(key))
                    end
                else
                    os.remove(outboxFile(key))
                end
            end
        end
    end
end

-- ===================================================================
-- Публичный API
-- ===================================================================

-- opts: baseUrl (только https), dir, version, serverKey(), nick(), onCallsigns(changes), onStatus(code, detail), log(s)
-- Для тестов: transport, randomBytes, allowInsecure.
function M.init(o)
    opts = o
    opts.baseUrl = (o.baseUrl or ''):gsub('/+$', '')
    opts.uaVersion = tostring(o.version or '0'):gsub('[^%w%.%-_]', '_')
    dir = o.dir
    local lowUrl = opts.baseUrl:lower()
    if lowUrl == '' or lowUrl:find('your-subdomain', 1, true) then
        status('notconfigured')
        return false
    end
    -- Секрет установки уходит в заголовке: по открытому HTTP его увидит любой на пути.
    if not lowUrl:match('^https://') and not o.allowInsecure then
        status('insecure')
        return false
    end
    if o.randomBytes then rngHook = o.randomBytes end
    ensureDir(dir)
    ensureDir(dir .. 'tmp')
    ensureDir(dir .. 'outbox')

    local t
    if o.transport then
        t = o.transport
    else
        local why, detail
        t, why, detail = makeEffilTransport()
        if t then
            log('transport: effil + requests (HTTPS certificate is NOT verified)')
        else
            log('effil transport unavailable (' .. tostring(why) .. ': ' .. tostring(detail) .. '), trying curl.exe')
            local c, cerr = makeWinTransport(dir)
            if c then
                t = c
                log('transport: curl.exe')
            else
                status('nolibs', detail or cerr)
                return false
            end
        end
    end
    transport = t
    if transport.sweep then pcall(transport.sweep) end
    inited = true
    st.nextPoll = now() + 4
    outboxLoad()
    return true
end

function M.isEnabled() return inited and not st.disabled end

function M.status()
    local s
    if not inited then s = 'off'
    elseif st.disabled then s = st.disabled
    elseif st.serverOff then s = 'server_off'
    elseif st.online then s = 'online'
    else s = 'offline' end
    return { state = s, lastOk = st.lastOk, err = st.lastErr }
end

-- Вызывать каждый кадр из основного цикла: внутри только дешёвая проверка по времени.
function M.tick()
    if not inited then return end
    local t = now()
    if t - st.lastTick < 0.1 then return end
    st.lastTick = t
    if st.disabled then return end
    pump()
    expireLocal()
    if not st.polling and not st.serverOff and opts.isActive and t - st.lastShorten >= 1 then
        -- игрок сел в машину: не ждём конца медленного периода
        st.lastShorten = t
        local okA, a = pcall(opts.isActive)
        if okA and a and st.nextPoll - t > POLL_ACTIVE + 1.5 and st.nextPoll < t + 3000 then
            st.nextPoll = t + POLL_ACTIVE
        end
    end
    if t >= st.nextPoll then
        local paused = false
        if opts.isPaused then
            local okP, p = pcall(opts.isPaused)
            paused = okP and p and true or false
        end
        if not paused then startPoll() end     -- на паузе игры запросы не тратим
    end
end

-- Ускоряет опрос на ACTIVE_WINDOW секунд (после своих изменений ждём ответа товарищей).
function M.boost()
    local t = now()
    st.activeUntil = t + ACTIVE_WINDOW
    if not st.polling and st.nextPoll > t + POLL_ACTIVE and st.nextPoll < t + 3000 then st.nextPoll = t + POLL_ACTIVE end
end

function M.pushCallsign(veh, text)
    if not inited or st.disabled then return false end
    if type(veh) ~= 'number' or veh < 0 or veh > 1999 then return false end   -- в SA-MP машин не больше 2000
    local clean = sanitizeCallsign(text)
    local sk = opts.serverKey and opts.serverKey()
    if not clean or not sk then return false end
    cs[veh] = { text = clean, deadline = now() + CALLSIGN_TTL }
    M.boost()
    enqueue({
        method = 'POST', path = '/v1/callsign/set', key = 'cs:' .. veh, lane = 'cs:' .. veh, retries = 3, server = sk,
        body = json.encode({ server = sk, veh = veh, text = u8(clean), nick = opts.nick and opts.nick() or '' }),
    })
    return true
end

-- Сброс действует только на текущем игровом сервере.
function M.deleteCallsign(veh)
    if not inited or st.disabled then return false end
    if type(veh) ~= 'number' or veh < 0 or veh > 1999 then return false end
    local sk = opts.serverKey and opts.serverKey()
    if not sk then return false end
    cs[veh] = nil
    M.boost()
    enqueue({
        method = 'POST', path = '/v1/callsign/del', key = 'cs:' .. veh, lane = 'cs:' .. veh, retries = 3, server = sk,
        body = json.encode({ server = sk, veh = veh, nick = opts.nick and opts.nick() or '' }),
    })
    return true
end

-- Модерация: action = 'ban' | 'unban', nick в CP1251. Пароль проверяет только сервер (секрет в Worker),
-- в клиенте его нет. cb(true, decoded, res) или cb(false, res, decoded).
function M.admin(action, nick, password, cb)
    if not inited or st.disabled then return nil, 'disabled' end
    if action ~= 'ban' and action ~= 'unban' then return nil, 'bad action' end
    if type(nick) ~= 'string' or nick == '' or #nick > 40 then return nil, 'bad nick' end
    if type(password) ~= 'string' or password == '' or #password > 128 then return nil, 'bad password' end
    local sk = opts.serverKey and opts.serverKey()
    if not sk then return nil, 'no server' end
    enqueue({
        method = 'POST', path = '/v1/admin/' .. action, retries = 0, server = sk, cb = cb,
        body = json.encode({ nick = u8(nick), password = u8(password), server = sk }),
    })
    return true
end

-- kind: 'uof' | 'arrest' | 'situ'; rep: таблица отчёта из EMS.lua (строки в CP1251), rep.syncId обязателен.
-- Возвращает true или nil + причину.
function M.pushReport(kind, rep)
    if not inited or st.disabled then return nil, 'disabled' end
    local fields = REPORT_FIELDS[kind]
    if not fields then return nil, 'bad kind' end
    if type(rep.syncId) ~= 'string' or not rep.syncId:match('^%x+$') or #rep.syncId ~= 32 then return nil, 'no id' end
    local dept = M.normalizeDept(rep.department)
    if not dept then return nil, 'dept' end
    local sk = opts.serverKey and opts.serverKey()
    if not sk then return nil, 'no server' end
    local data = {}
    for _, k in ipairs(fields) do data[k] = u8(tostring(rep[k] or '')) end
    local body = json.encode({
        id = rep.syncId, server = sk, kind = kind, dept = dept,
        nick = opts.nick and opts.nick() or '', data = data,
    })
    local key = 'rp_' .. rep.syncId
    outboxWrite(key, '/v1/report/put', body, sk)
    outboxSend(key, '/v1/report/put', body, sk)
    return true
end

function M.deleteReport(syncId)
    if not inited or st.disabled then return nil, 'disabled' end
    if type(syncId) ~= 'string' or #syncId ~= 32 or not syncId:match('^%x+$') then return nil, 'no id' end
    local sk = opts.serverKey and opts.serverKey()
    if not sk then return nil, 'no server' end
    local body = json.encode({ id = syncId, server = sk })
    -- если отправка правки ещё в очереди, она теряет смысл
    os.remove(outboxFile('rp_' .. syncId))
    for i = #queue, 1, -1 do
        if queue[i].key == 'rp_' .. syncId then table.remove(queue, i) end
    end
    outboxWrite('rd_' .. syncId, '/v1/report/del', body, sk)
    outboxSend('rd_' .. syncId, '/v1/report/del', body, sk)
    return true
end

-- ----- чтение общих отчётов (для вкладки MDC) -----
-- dept = nil означает все подразделения: подразделение это фильтр, а не граница доступа.
local function repKey(dept, kind) return (dept or '*') .. '/' .. (kind or '*') end

function M.getReports(dept, kind)
    local k = repKey(dept, kind)
    local r = M.reports[k]
    if not r then
        r = { items = {}, loading = false, err = nil, at = nil, more = false }
        M.reports[k] = r
    end
    return r
end

local function fetchReports(dept, kind, append)
    local r = M.getReports(dept, kind)
    if r.loading then return end
    if not inited or st.disabled then r.err = st.disabled or 'off'; return end
    local sk = opts.serverKey and opts.serverKey()
    if not sk then r.err = 'no server'; return end
    r.loading, r.err = true, nil
    local path = '/v1/reports?server=' .. urlenc(sk) .. '&limit=30'
    if dept then path = path .. '&dept=' .. urlenc(dept) end
    if kind then path = path .. '&kind=' .. urlenc(kind) end
    if append and #r.items > 0 then
        local last = r.items[#r.items]
        path = path .. '&before=' .. string.format('%.0f', last.created_at) .. '&before_id=' .. urlenc(last.id)
    end
    enqueue({
        method = 'GET', path = path, retries = 1, server = sk,
        cb = function(ok, res, decoded)
            r.loading = false
            if not ok then
                local code = decoded and decoded.error or (res and (res.err or res.status))
                if decoded and decoded.disabled then code = 'disabled' end
                r.err = tostring(code or 'error')
                return
            end
            local items = res.items or {}
            if not append then r.items = {} end
            local seen = {}
            for _, it in ipairs(r.items) do seen[it.id] = true end
            for _, it in ipairs(items) do
                if not seen[it.id] then r.items[#r.items + 1] = it end
            end
            r.more = res.more and true or false
            r.at = now()
        end,
    })
end

function M.refreshReports(dept, kind) fetchReports(dept, kind, false) end
function M.moreReports(dept, kind) fetchReports(dept, kind, true) end

-- для тестов
M._queueLength = function() return #queue + #running end
M._state = function() return st, cs end
M._tokenFor = tokenFor

return M
