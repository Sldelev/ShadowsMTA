--[[

    Skrypt stworzony i udostępniony na licencji Creative Commons (cc)

    (Async w jednym pliku bo mta ma downa, skrypt sie zaczyna na 471 linijce)

]]



debug.sethook(nil)

local function loadClass()
    ---------
    -- Start of slither.lua dependency
    ---------

    local _LICENSE = -- zlib / libpng
    [[
    Copyright (c) 2011-2014 Bart van Strien

    This software is provided 'as-is', without any express or implied
    warranty. In no event will the authors be held liable for any damages
    arising from the use of this software.

    Permission is granted to anyone to use this software for any purpose,
    including commercial applications, and to alter it and redistribute it
    freely, subject to the following restrictions:

      1. The origin of this software must not be misrepresented; you must not
      claim that you wrote the original software. If you use this software
      in a product, an acknowledgment in the product documentation would be
      appreciated but is not required.

      2. Altered source versions must be plainly marked as such, and must not be
      misrepresented as being the original software.

      3. This notice may not be removed or altered from any source
      distribution.
    ]]

    local class =
    {
        _VERSION = "Slither 20140904",
        -- I have no better versioning scheme, deal with it
        _DESCRIPTION = "Slither is a pythonic class library for lua",
        _URL = "http://bitbucket.org/bartbes/slither",
        _LICENSE = _LICENSE,
    }

    local function stringtotable(path)
        local t = _G
        local name

        for part in path:gmatch("[^%.]+") do
            t = name and t[name] or t
            name = part
        end

        return t, name
    end

    local function class_generator(name, b, t)
        local parents = {}
        for _, v in ipairs(b) do
            parents[v] = true
            for _, v in ipairs(v.__parents__) do
                parents[v] = true
            end
        end

        local temp = { __parents__ = {} }
        for i, v in pairs(parents) do
            table.insert(temp.__parents__, i)
        end

        local class = setmetatable(temp, {
            __index = function(self, key)
                if key == "__class__" then return temp end
                if key == "__name__" then return name end
                if t[key] ~= nil then return t[key] end
                for i, v in ipairs(b) do
                    if v[key] ~= nil then return v[key] end
                end
                if tostring(key):match("^__.+__$") then return end
                if self.__getattr__ then
                    return self:__getattr__(key)
                end
            end,

            __newindex = function(self, key, value)
                t[key] = value
            end,

            allocate = function(instance)
                local smt = getmetatable(temp)
                local mt = {__index = smt.__index}

                function mt:__newindex(key, value)
                    if self.__setattr__ then
                        return self:__setattr__(key, value)
                    else
                        return rawset(self, key, value)
                    end
                end

                if temp.__cmp__ then
                    if not smt.eq or not smt.lt then
                        function smt.eq(a, b)
                            return a.__cmp__(a, b) == 0
                        end
                        function smt.lt(a, b)
                            return a.__cmp__(a, b) < 0
                        end
                    end
                    mt.__eq = smt.eq
                    mt.__lt = smt.lt
                end

                for i, v in pairs{
                    __call__ = "__call", __len__ = "__len",
                    __add__ = "__add", __sub__ = "__sub",
                    __mul__ = "__mul", __div__ = "__div",
                    __mod__ = "__mod", __pow__ = "__pow",
                    __neg__ = "__unm", __concat__ = "__concat",
                    __str__ = "__tostring",
                    } do
                    if temp[i] then mt[v] = temp[i] end
                end

                return setmetatable(instance or {}, mt)
            end,

            __call = function(self, ...)
                local instance = getmetatable(self).allocate()
                if instance.__init__ then instance:__init__(...) end
                return instance
            end
            })

        for i, v in ipairs(t.__attributes__ or {}) do
            class = v(class) or class
        end

        return class
    end

    local function inheritance_handler(set, name, ...)
        local args = {...}

        for i = 1, select("#", ...) do
            if args[i] == nil then
                error("nil passed to class, check the parents")
            end
        end

        local t = nil
        if #args == 1 and type(args[1]) == "table" and not args[1].__class__ then
            t = args[1]
            args = {}
        end

        for i, v in ipairs(args) do
            if type(v) == "string" then
                local t, name = stringtotable(v)
                args[i] = t[name]
            end
        end

        local func = function(t)
            local class = class_generator(name, args, t)
            if set then
                local root_table, name = stringtotable(name)
                root_table[name] = class
            end
            return class
        end

        if t then
            return func(t)
        else
            return func
        end
    end

    function class.private(name)
        return function(...)
            return inheritance_handler(false, name, ...)
        end
    end

    class = setmetatable(class, {
        __call = function(self, name)
            return function(...)
                return inheritance_handler(true, name, ...)
            end
        end,
    })


    function class.issubclass(class, parents)
        if parents.__class__ then parents = {parents} end
        for i, v in ipairs(parents) do
            local found = true
            if v ~= class then
                found = false
                for _, p in ipairs(class.__parents__) do
                    if v == p then
                        found = true
                        break
                    end
                end
            end
            if not found then return false end
        end
        return true
    end

    function class.isinstance(obj, parents)
        return type(obj) == "table" and obj.__class__ and class.issubclass(obj.__class__, parents)
    end

    -- Export a Class Commons interface
    -- to allow interoperability between
    -- class libraries.
    -- See https://github.com/bartbes/Class-Commons
    --
    -- NOTE: Implicitly global, as per specification, unfortunately there's no nice
    -- way to both provide this extra interface, and use locals.
    if common_class ~= false then
        common = {}
        function common.class(name, prototype, superclass)
            prototype.__init__ = prototype.init
            return class_generator(name, {superclass}, prototype)
        end

        function common.instance(class, ...)
            return class(...)
        end
    end

    ---------
    -- End of slither.lua dependency
    ---------

    return class;
end

local class = loadClass();

--- GTA:MTA Lua async thread scheduler.
-- @author Inlife
-- @license MIT
-- @url https://github.com/Inlife/mta-lua-async
-- @dependency slither.lua https://bitbucket.org/bartbes/slither

class "_Async" {
    
    -- Constructor mehtod
    -- Starts timer to manage scheduler
    -- @access public
    -- @usage local asyncmanager = async();
    __init__ = function(self)

        self.threads = {};
        self.resting = 50; -- in ms (resting time)
        self.maxtime = 200; -- in ms (max thread iteration time)
        self.current = 0;  -- starting frame (resting)
        self.state = "suspended"; -- current scheduler executor state
        self.debug = false;
        self.priority = {
            low = {500, 50},     -- better fps
            normal = {200, 200}, -- medium
            high = {50, 500}     -- better perfomance
        };

        self:setPriority("normal");
    end,


    -- Switch scheduler state
    -- @access private
    -- @param boolean [istimer] Identifies whether or not 
        -- switcher was called from main loop
    switch = function(self, istimer)
        self.state = "running";

        if (self.current + 1  <= #self.threads) then
            self.current = self.current + 1;
            self:execute(self.current);
        else
            self.current = 0;

            if (#self.threads <= 0) then
                self.state = "suspended";
                return;
            end

            -- setTimer(function theFunction, int timeInterval, int timesToExecute) 
            -- (GTA:MTA server scripting function)
            -- For other environments use alternatives.
            setTimer(function() 
                self:switch();
            end, self.resting, 1);
        end
    end,


    -- Managing thread (resuming, removing)
    -- In case of "dead" thread, removing, and skipping to the next (recursive)
    -- @access private
    -- @param int id Thread id (in table async.threads)
    execute = function(self, id)
        local thread = self.threads[id];

        if (thread == nil or coroutine.status(thread) == "dead") then
            table.remove(self.threads, id);
            self:switch();
        else
            coroutine.resume(thread);
            self:switch();
        end
    end,


    -- Adding thread
    -- @access private
    -- @param function func Function to operate with
    add = function(self, func)
        local thread = coroutine.create(func);
        table.insert(self.threads, thread);
    end,


    -- Set priority for executor
    -- Use before you call 'iterate' or 'foreach' 
    -- @access public
    -- @param string|int param1 "low"|"normal"|"high" or number to set 'resting' time
    -- @param int|void param2 number to set 'maxtime' of thread
    -- @usage async:setPriority("normal");
    -- @usage async:setPriority(50, 200);
    setPriority = function(self, param1, param2)
        if (type(param1) == "string") then
            if (self.priority[param1] ~= nil) then
                self.resting = self.priority[param1][1];
                self.maxtime = self.priority[param1][2];
            end
        else
            self.resting = param1;
            self.maxtime = param2;
        end
    end,

    -- Set debug mode enabled/disabled
    -- @access public
    -- @param boolean value true - enabled, false - disabled
    -- @usage async:setDebug(true);
    setDebug = function(self, value)
        self.debug = value;
    end,


    -- Iterate on interval (for cycle)
    -- @access public
    -- @param int from Iterate from
    -- @param int to Iterate to
    -- @param function func Iterate using func
        -- Function func params:
        -- @param int [i] Iteration index
    -- @param function [callback] Callback function, called when execution finished
    -- Usage:
        -- @usage async:iterate(1, 10000, function(i)
        --     print(i);
        -- end);
    iterate = function(self, from, to, func, callback)
        self:add(function()
            local a = getTickCount();
            local lastresume = getTickCount();
            for i = from, to do
                func(i); 

                -- int getTickCount() 
                -- (GTA:MTA server scripting function)
                -- For other environments use alternatives.
                if getTickCount() > lastresume + self.maxtime then
                    coroutine.yield()
                    lastresume = getTickCount()
                end
            end
            if (self.debug) then
                print("[DEBUG]Async iterate: " .. (getTickCount() - a) .. "ms");
            end
            if (callback) then
                callback();
            end
        end);

        self:switch();
    end,

    -- Iterate over array (foreach cycle)
    -- @access public
    -- @param table array Input array
    -- @param function func Iterate using func
        -- Function func params:
        -- @param int [v] Iteration value
        -- @param int [k] Iteration key
    -- @param function [callback] Callback function, called when execution finished
    -- Usage:
        -- @usage async:foreach(vehicles, function(vehicle, id)
        --     print(vehicle.title);
        -- end);
    foreach = function(self, array, func, callback)
        self:add(function()
            local a = getTickCount();
            local lastresume = getTickCount();
            for k,v in ipairs(array) do
                func(v,k);

                -- int getTickCount() 
                -- (GTA:MTA server scripting function)
                -- For other environments use alternatives.
                if getTickCount() > lastresume + self.maxtime then
                    coroutine.yield()
                    lastresume = getTickCount()
                end
            end
            if (self.debug) then
                print("[DEBUG]Async foreach: " .. (getTickCount() - a) .. "ms");
            end
            if (callback) then
                callback();
            end
        end);

        self:switch();
    end,
}

-- Async Singleton wrapper
Async = {
    instance = nil,
};

-- After first call, creates an instance and stores it
local function getInstance()
    if Async.instance == nil then
        Async.instance = _Async();
    end

    return Async.instance; 
end

-- proxy methods for public members
function Async:setDebug(...)
    getInstance():setDebug(...);
end

function Async:setPriority(...)
    getInstance():setPriority(...);
end

function Async:iterate(...)
    getInstance():iterate(...);
end

function Async:foreach(...)
    getInstance():foreach(...);
end

------------------

local shader;
local shadowDetails = 0.25 -- 1 пиксель карты = 4 м мира
local renderDistance = 100 -- радиус окна вокруг игрока, м
local cellSize = 1 / shadowDetails
local windowRadius = math.floor(renderDistance / cellSize)
local sx, sy = 6000 * shadowDetails, 6000 * shadowDetails
local shadowMap = dxCreateRenderTarget(sx, sy)
local currentTime = false
local known = {}
local genQueue, genHead = {}, 1
local loadQueue = {}
local needClear = true
local dirty = false
local lastGX, lastGY = nil, nil
local shadowsColor = false
local BUDGET_MS = 2
local SAVE_INTERVAL = 60000

local skipTextures = {
    "coronastar", "coronamoon", "coronaringle", "lunar", "sphere", "particle",
    "shad_ped", "shad_car", "shad_exp", "shad_huge", "shad_bike", "shad_rcar", "shad_heli",
    "cloudmasked", "collisionsmoke", "cloud1", "vehiclegeneric256", "vehicletyres128",
}

function initShadows()
    shader = dxCreateShader("shadow.fx", 0, 0, true, "world,object,ped")
    engineApplyShaderToWorldTexture(shader, "*")
    for _, name in ipairs(skipTextures) do
        engineRemoveShaderFromWorldTexture(shader, name)
    end
    dxSetShaderValue(shader, "shadowMap", shadowMap)
end

initShadows()

function getMapPositionFromWorldPosition(x, y)
    return (x + 3000)*shadowDetails, (y + 3000)*shadowDetails
end

local CELL_LIMIT = math.floor(3000 / cellSize)

local function cellKey(gx, gy)
    return (gx + 1024) * 2048 + gy + 1024
end

local function rebuildWindow(gx, gy)
    genQueue, genHead = {}, 1
    for dx = -windowRadius, windowRadius do
        for dy = -windowRadius, windowRadius do
            local cx, cy = gx + dx, gy + dy
            if cx >= -CELL_LIMIT and cx < CELL_LIMIT and cy >= -CELL_LIMIT and cy < CELL_LIMIT and known[cellKey(cx, cy)] == nil then
                genQueue[#genQueue + 1] = {cx, cy, dx * dx + dy * dy}
            end
        end
    end
    table.sort(genQueue, function (a, b)
        return a[3] < b[3]
    end)
end

local sunPosition = {
    [0] = {-100, -100, 30, tocolor(40, 85, 105), tocolor(25, 65, 110)},
    [1] = {-100, -100, 30, tocolor(40, 85, 135), tocolor(25, 65, 110)},
    [2] = {-100, -100, 30, tocolor(40, 85, 135), tocolor(25, 65, 110)},
    [3] = {-100, -100, 30, tocolor(40, 85, 135), tocolor(25, 65, 110)},
    [4] = {-100, -100, 30, tocolor(40, 85, 135), tocolor(25, 65, 110)},
    [5] = {-100, -100, 30, tocolor(50, 105, 155), tocolor(35, 85, 130)},
    [6] = {-100, -100, 30, tocolor(255, 200, 155), tocolor(105, 105, 105)},
    [7] = {-100, -100, 50, tocolor(255, 200, 155), tocolor(105, 105, 105)},
    [8] = {-60, -60, 60, tocolor(255, 200, 155), tocolor(105, 105, 105)},
    [9] = {-50, -50, 130, tocolor(255, 200, 155), tocolor(105, 105, 105)},
    [10] = {-30, -30, 230, tocolor(255, 230, 200), tocolor(105, 105, 105)},
    [11] = {-15, -15, 200, tocolor(255, 255, 255), tocolor(105, 105, 105)},
    [12] = {-0, -0, 200, tocolor(255, 255, 255), tocolor(105, 105, 105)},
    [13] = {15, 0, 200, tocolor(255, 255, 240), tocolor(105, 105, 105)},
    [14] = {30, 0, 30, tocolor(255, 240, 230), tocolor(105, 105, 105)},
    [15] = {50, 0, 30, tocolor(255, 230, 220), tocolor(105, 105, 105)},
    [16] = {60, 0, 30, tocolor(255, 220, 210), tocolor(105, 105, 105)},
    [17] = {80, 0, 30, tocolor(255, 210, 190), tocolor(105, 105, 105)},
    [18] = {100, 0, 30, tocolor(255, 210, 180), tocolor(105, 105, 105)},
    [19] = {100, 0, 30, tocolor(255, 200, 170), tocolor(105, 105, 105)},
    [20] = {100, 0, 30, tocolor(255, 200, 155), tocolor(105, 105, 105)},
    [21] = {100, 0, 10, tocolor(255, 200, 155), tocolor(105, 105, 105)},
    [22] = {100, 0, 4, tocolor(255, 200, 155), tocolor(105, 105, 105)},
    [23] = {-100, -100, 30, tocolor(130, 135, 140), tocolor(110, 115, 120)},
}

local entries = {}
local loadHead = 1
local GROUND_FILE = "ground_v2.txt"
local groundZ, groundList, groundDirty = {}, {}, false

local function groundHeight(gx, gy)
    local key = cellKey(gx, gy)
    local z = groundZ[key]
    if z then
        return z
    end
    local wx, wy = gx * cellSize, gy * cellSize
    z = getGroundPosition(wx, wy, 800)
    groundZ[key] = z
    groundList[#groundList + 1] = gx .. " " .. gy .. " " .. string.format("%.3f", z)
    groundDirty = true
    return z
end

local function computeShadow(gx, gy)
    local wx, wy = gx * cellSize, gy * cellSize
    local sp = sunPosition[currentTime]
    local z = groundHeight(gx, gy)
    return not isLineOfSightClear(wx, wy, z + 0.01, wx + sp[1], wy + sp[2], z + sp[3], true, false, false, true, true)
end

local function recordCell(gx, gy, shadowed)
    known[cellKey(gx, gy)] = true
    entries[#entries + 1] = gx .. " " .. gy .. " " .. (shadowed and 1 or 0)
end

local function drawCell(gx, gy)
    local x, y = getMapPositionFromWorldPosition(gx * cellSize, gy * cellSize)
    dxDrawRectangle(x, y, 1, 1, shadowsColor)
end

local function cacheName(hour)
    return "cache_v2_h" .. hour .. ".txt"
end

local function saveCache()
    if not dirty or not currentTime then
        return
    end
    local f = fileCreate(cacheName(currentTime))
    if not f then
        return
    end
    fileWrite(f, table.concat(entries, "\n"))
    fileClose(f)
    dirty = false
end

local function loadGround()
    if not fileExists(GROUND_FILE) then
        return
    end
    local f = fileOpen(GROUND_FILE, true)
    if not f then
        return
    end
    local size = fileGetSize(f)
    local data = size > 0 and fileRead(f, size) or ""
    fileClose(f)
    for gx, gy, z in data:gmatch("(%-?%d+) (%-?%d+) (%-?[%d%.]+)") do
        groundZ[cellKey(tonumber(gx), tonumber(gy))] = tonumber(z)
        groundList[#groundList + 1] = gx .. " " .. gy .. " " .. z
    end
end

local function saveGround()
    if not groundDirty then
        return
    end
    local f = fileCreate(GROUND_FILE)
    if not f then
        return
    end
    fileWrite(f, table.concat(groundList, "\n"))
    fileClose(f)
    groundDirty = false
end

local function processQueue()
    if loadHead > #loadQueue and genHead > #genQueue and not needClear then
        return
    end
    local deadline = getTickCount() + BUDGET_MS
    dxSetRenderTarget(shadowMap, false)
    if needClear then
        dxDrawRectangle(0, 0, sx, sy, sunPosition[currentTime][4])
        needClear = false
    end
    while loadHead <= #loadQueue and getTickCount() < deadline do
        local item = loadQueue[loadHead]
        loadHead = loadHead + 1
        recordCell(item[1], item[2], item[3])
        if item[3] then
            drawCell(item[1], item[2])
        end
    end
    while genHead <= #genQueue and getTickCount() < deadline do
        local item = genQueue[genHead]
        genHead = genHead + 1
        local gx, gy = item[1], item[2]
        if known[cellKey(gx, gy)] == nil then
            local shadowed = computeShadow(gx, gy)
            recordCell(gx, gy, shadowed)
            dirty = true
            if shadowed then
                drawCell(gx, gy)
            end
        end
    end
    dxSetRenderTarget()
end

local function onHourChange()
    local hour = getTime()
    if hour == currentTime then
        return
    end
    saveCache()
    currentTime = hour
    shadowsColor = sunPosition[hour][5]
    known, entries = {}, {}
    genQueue, genHead = {}, 1
    loadQueue, loadHead = {}, 1
    needClear = true
    dirty = false
    lastGX, lastGY = nil, nil
    local name = cacheName(hour)
    if fileExists(name) then
        local f = fileOpen(name, true)
        if f then
            local size = fileGetSize(f)
            local data = size > 0 and fileRead(f, size) or ""
            fileClose(f)
            for gx, gy, s in data:gmatch("(%-?%d+) (%-?%d+) ([01])") do
                loadQueue[#loadQueue + 1] = {tonumber(gx), tonumber(gy), s == "1"}
            end
        end
    end
end

local paused = false
local shadowEnabled = true

local function setShadowEnabled(on)
    if on then
        engineApplyShaderToWorldTexture(shader, "*")
        for _, name in ipairs(skipTextures) do
            engineRemoveShaderFromWorldTexture(shader, name)
        end
    else
        engineRemoveShaderFromWorldTexture(shader, "*")
    end
end

local function onRender()
    local px, py = getElementPosition(localPlayer)
    local gx, gy = math.floor(px / cellSize), math.floor(py / cellSize)
    if gx ~= lastGX or gy ~= lastGY then
        lastGX, lastGY = gx, gy
        rebuildWindow(gx, gy)
    end
    if not paused then
        processQueue()
    end
end

loadGround()
onHourChange()
addEventHandler("onClientRender", root, onRender)
setTimer(onHourChange, 1000, 0)
setTimer(function()
    saveCache()
    saveGround()
end, SAVE_INTERVAL, 0)

addEventHandler("onClientResourceStop", resourceRoot, function()
    saveCache()
    saveGround()
    destroyElement(shadowMap)
end)

addCommandHandler("shdtex", function(_, filter)
    local names = engineGetVisibleTextureNames(filter or "*")
    outputConsole("Видимые текстуры (" .. #names .. "):")
    for _, name in ipairs(names) do
        outputConsole(name)
    end
end)

addCommandHandler("shdbench", function()
    local px, py, pz = getElementPosition(localPlayer)
    local sp = sunPosition[currentTime]
    local n = 200
    local t0 = getTickCount()
    for i = 1, n do
        getGroundPosition(px + i, py, 800)
    end
    local tGround = getTickCount() - t0
    t0 = getTickCount()
    for i = 1, n do
        isLineOfSightClear(px + i, py, pz, px + i + sp[1], py + sp[2], pz + sp[3], true, false, false, true, true)
    end
    local tLos = getTickCount() - t0
    outputConsole("getGroundPosition: " .. tGround / n .. " мс на вызов")
    outputConsole("isLineOfSightClear: " .. tLos / n .. " мс на вызов")
end)

addCommandHandler("shdpause", function()
    paused = not paused
    outputConsole("Генерация теней: " .. (paused and "на паузе" or "работает"))
end)

addCommandHandler("shdoff", function()
    shadowEnabled = not shadowEnabled
    setShadowEnabled(shadowEnabled)
    outputConsole("Шейдер теней: " .. (shadowEnabled and "включён" or "выключен"))
end)

addCommandHandler("shdcell", function()
    local px, py, pz = getElementPosition(localPlayer)
    local gx, gy = math.floor(px / cellSize), math.floor(py / cellSize)
    local wx, wy = gx * cellSize, gy * cellSize
    local z = groundHeight(gx, gy)
    local sp = sunPosition[currentTime]
    local sun = isLineOfSightClear(wx, wy, z + 0.01, wx + sp[1], wy + sp[2], z + sp[3], true, false, false, true, true)
    local up = isLineOfSightClear(wx, wy, z + 0.01, wx, wy, z + 200, true, false, false, true, true)
    outputConsole("Час: " .. currentTime .. ", игрок z: " .. pz .. ", земля z: " .. z)
    outputConsole("Зонд клетки из 800: " .. tostring(getGroundPosition(wx, wy, 800)))
    outputConsole("Зонд игрока из 800: " .. tostring(getGroundPosition(px, py, 800)))
    outputConsole("Зонд игрока из pz+5: " .. tostring(getGroundPosition(px, py, pz + 5)))
    outputConsole("Солнце: " .. sp[1] .. ", " .. sp[2] .. ", " .. sp[3] .. ", видно: " .. tostring(sun))
    outputConsole("Вертикально вверх чисто: " .. tostring(up) .. ", клетка в кэше: " .. tostring(known[cellKey(gx, gy)] ~= nil))
end)