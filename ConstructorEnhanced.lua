-- =====================================================================
--
--    C O N S T R U C T O R   E N H A N C E D   -  LGN's Constructor for Cherax  (v7)
--
-- =====================================================================
--  A standalone script - it doesn't need (or talk to) any other script, in Cherax's own look.
--  INSTALL: put ConstructorEnhanced.lua in your Cherax "Lua" folder.
--  FILES:   your constructs are saved in Lua\CE (kits in Lua\CE\kits) - drop Stand Constructor .json,
--           Cherax .json or Menyoo .xml builds in there too. Lua\CE\data holds the rest (autosave,
--           favourites, ObjectList.txt for Search All Objects). Your Cherax saved vehicles are listed too.
--  First run: builds, the autosave and ObjectList.txt from an old LGNFX folder are copied in once.
--  Everything it spawns is cleared away when it's unloaded (except the vehicle you're sat in).
-- =====================================================================

local CE_NAME = "Constructor Enhanced"
local CE_VERSION = "Constructor Enhanced v7"



-- ---------------------------------------------------------------------
-- what this script spawns (cleared away when it stops), shared with everyone, kept hidden
-- ---------------------------------------------------------------------
local LGX = { spawned = {}, cleanup = nil, cleaned = false }
-- ANIMALS must be made as animals (ped type 28). Made as a person (type 4) - how the XML / JSON spawner
-- and the tour driver used to make every ped - an animal carries a person's face data ("head blend"),
-- which other players' menus block ("Invalid Animal Head Blend Data") and which can crash players who
-- have no protection. So every ped LGNFX makes goes through this check.
LGX.ANIMALS = {}
for _, m in ipairs({ "a_c_boar", "a_c_boar_02", "a_c_cat_01", "a_c_chickenhawk", "a_c_chimp", "a_c_chimp_02", "a_c_chop",
    "a_c_chop_02", "a_c_cormorant", "a_c_cow", "a_c_coyote", "a_c_coyote_02", "a_c_crow", "a_c_deer", "a_c_deer_02",
    "a_c_dolphin", "a_c_fish", "a_c_hen", "a_c_humpback", "a_c_husky", "a_c_killerwhale", "a_c_mtlion", "a_c_mtlion_02",
    "a_c_panther", "a_c_pig", "a_c_pigeon", "a_c_poodle", "a_c_pug", "a_c_pug_02", "a_c_rabbit_01", "a_c_rabbit_02",
    "a_c_rat", "a_c_retriever", "a_c_rhesus", "a_c_rottweiler", "a_c_seagull", "a_c_sharkhammer", "a_c_sharktiger",
    "a_c_shepherd", "a_c_stingray", "a_c_westy" }) do
    LGX.ANIMALS[Utils.Joaat(m) % 4294967296] = m
end
LGX.IsAnimal = function(model)
    if type(model) == "string" then
        if model:lower():sub(1, 4) == "a_c_" then return true end
        model = Utils.Joaat(model)
    end
    return type(model) == "number" and LGX.ANIMALS[model % 4294967296] ~= nil
end
-- SHARED WITH EVERYONE (what Stand's Constructor does with its parts): a spawned thing is registered
-- with the game's network, set to exist on every player's game and kept yours (it can't move to
-- another player's game, where it could be cleaned away). Without this, props stuck on a car were
-- only on your screen - other players saw the car and nothing on it.
LGX.Networked = function(h)
    if not h or h == 0 then return end
    local function nv(...) pcall(Natives.InvokeVoid, ...) end
    local okS, online = pcall(Natives.InvokeBool, 0x9DE624D2FC4B603F) -- NETWORK_IS_SESSION_STARTED
    if not okS or not online then return end
    nv(0xAD738C3085FE7E11, h, true, false) -- SET_ENTITY_AS_MISSION_ENTITY
    local okI, id = pcall(Natives.InvokeInt, 0xA11700682F3AD45C, h) -- NETWORK_GET_NETWORK_ID_FROM_ENTITY
    if not okI or not id or id == 0 then
        nv(0x06FAACD625D80CAA, h) -- NETWORK_REGISTER_ENTITY_AS_NETWORKED
        okI, id = pcall(Natives.InvokeInt, 0xA11700682F3AD45C, h)
    end
    if not okI or not id or id == 0 then return end
    nv(0xE05E81A888FA63C8, id, true) -- SET_NETWORK_ID_EXISTS_ON_ALL_MACHINES
    nv(0x299EEB23175895FC, id, false) -- SET_NETWORK_ID_CAN_MIGRATE
    for pid = 0, 31 do
        local okA, active = pcall(Natives.InvokeBool, 0xB8DFD30D6973E135, pid) -- NETWORK_IS_PLAYER_ACTIVE
        if okA and active then nv(0xA8A024587329F36A, id, pid, true) end -- SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER
    end
end
-- KEPT HIDDEN: LGNFX's hidden helpers (sync markers, hidden party bus / speaker, hidden DJs...) must never be
-- seen. Hiding them once when they're made wasn't enough - Cherax's spawner fades a new car in, and the
-- fade ends with it visible again (that was the panto showing on you / in your car). So they're
-- hidden again every frame for as long as they exist.
LGX.hidden = {}
LGX.Bool = function(...)
    local ok, r = pcall(Natives.InvokeBool, ...)
    if not ok then return false end
    if type(r) == "number" then return r ~= 0 end
    return r == true
end
LGX.Hide = function(h)
    pcall(Natives.InvokeVoid, 0xEA1C610A04DB6BBB, h, false, false) -- SET_ENTITY_VISIBLE
    pcall(Natives.InvokeVoid, 0x44A0870B7E92D7C0, h, 0, false)     -- SET_ENTITY_ALPHA
end
LGX.KeepHidden = function(h)
    if not h or h == 0 then return end
    LGX.hidden[h] = true
    LGX.Hide(h)
end
LGX.HiddenTick = function()
    for h in pairs(LGX.hidden) do
        if not LGX.Bool(0x7239B21A38F536BA, h) then -- DOES_ENTITY_EXIST
            LGX.hidden[h] = nil
        else
            local okA, a = pcall(Natives.InvokeInt, 0x5A47B3B5E63E94C6, h) -- GET_ENTITY_ALPHA
            if LGX.Bool(0x47D6F43D77935C75, h) or (okA and type(a) == "number" and a > 0) then -- IS_ENTITY_VISIBLE
                if not LGX.Bool(0x01BF60A500E28887, h) then pcall(Natives.InvokeVoid, 0xB69317BF5E782347, h) end -- (control)
                LGX.Hide(h)
            end
        end
    end
end
for _, name in ipairs({ "SpawnVehicle", "CreatePed", "CreateObject", "CreateWorldObject", "CreateRandomPed", "SpawnVehicleForPlayer" }) do
    LGX[name] = function(...)
        local args = { ... }
        if name == "CreatePed" and LGX.IsAnimal(args[1]) then args[2] = 28 end
        local h = GTA[name](table.unpack(args, 1, select("#", ...)))
        if type(h) == "number" and h ~= 0 then LGX.spawned[h] = true end
        return h
    end
end

local function IB(...)
    local r = Natives.InvokeBool(...)
    if type(r) == "number" then return r ~= 0 end
    return r == true
end


-- ---------------------------------------------------------------------
-- core helpers (the same ones LGNFX uses)
-- ---------------------------------------------------------------------
local running = true
local function ShouldStop()
    if not running then return true end
    local ok, stop = pcall(ShouldUnload)
    return ok and stop == true
end
local Dump = {}
function Dump.Info(msg) pcall(Logger.LogInfo, tostring(msg)) end
local function LogErr(where, err)
    local msg = "[CE] Error in " .. where .. ": " .. tostring(err)
    if not pcall(Logger.LogError, msg) then pcall(Logger.LogInfo, msg) end
end
local function Try(where, fn, ...)
    local ok, a, b = pcall(fn, ...)
    if not ok then LogErr(where, a) return nil end
    return a, b
end
-- every option of this script gets its own id ("LgnCE_..."), so nothing clashes with other scripts' options
local H = setmetatable({}, { __index = function(t, k)
    local v = Utils.Joaat("LgnCE_" .. tostring(k))
    rawset(t, k, v)
    return v
end })
local F = { unloadHooks = {}, hudDraws = {} }

local function NowMs()
    local ok, t = pcall(Time.GetEpocheMs)
    if ok and t then return t end
    local ok2, s = pcall(Time.Get)
    if ok2 and s then return s * 1000 end
    return 0
end
-- messages: Cherax's own popups
local function Notify(text)
    text = tostring(text)
    pcall(Logger.LogInfo, "[CE] " .. text)
    pcall(GUI.AddToast, CE_NAME, text, 3000, eToastPos.BOTTOM_RIGHT)
end


F.notMyCar = function(v)
    if not v or v == 0 then return false end
    local okM, me = pcall(Natives.InvokeInt, 0xD80958FC74E988A6) -- PLAYER_PED_ID
    local okD, d = pcall(Natives.InvokeInt, 0xBB40DD2270B65366, v, -1, false) -- GET_PED_IN_VEHICLE_SEAT
    if okD and d and d ~= 0 and d ~= (okM and me or -1) and IB(0x12534C348C6CB68B, d) then return true end -- IS_PED_A_PLAYER
    local ok, res = pcall(function()
        if not IB(0x05661B80A8C9165F, v, "Player_Vehicle") then return false end -- DECOR_EXIST_ON
        local owner = Natives.InvokeInt(0xA06C969B02A97298, v, "Player_Vehicle") -- DECOR_GET_INT
        local mine = Natives.InvokeInt(0xBC1D768F2F5D6C05, Natives.InvokeInt(0x4F8644AF03D0E0D6)) -- NETWORK_HASH_FROM_PLAYER_HANDLE(PLAYER_ID)
        return owner ~= nil and owner ~= 0 and owner ~= -1 and owner ~= mine
    end)
    return ok and res == true
end
-- true while you're typing (GTA Online text chat, or the game's on-screen keyboard) -
-- hotkeys do nothing then, so typing a message can't set anything off
-- Also while the LGNFX command bar is open, and while you're typing in a text box in Cherax's menu
-- (plus a moment after, so the Enter / Esc that finished typing doesn't set a hotkey off)
F.uiTypingUntil = 0
F.Typing = function()
    if F.cmdOpen then return true end
    local okT, t = pcall(Time.GetEpocheMs)
    if okT and t and t < (F.uiTypingUntil or 0) then return true end
    local ok, chat = pcall(IB, 0xB118AF58B5F332A1) -- IS_MP_TEXT_CHAT_TYPING
    if ok and chat then return true end
    local ok2, kb = pcall(Natives.InvokeInt, 0x0CF2B696BBF945AE) -- UPDATE_ONSCREEN_KEYBOARD (0 = typing)
    return ok2 and kb == 0
end
-- (called every frame from the drawing event: is a Cherax menu text box / slider being used right now?)
F.NoteUiTyping = function()
    local okO, open = pcall(GUI.IsOpen)
    if not (okO and open) then return end
    local okA, active = pcall(ImGui.IsAnyItemActive)
    if okA and active then
        local okT, t = pcall(Time.GetEpocheMs)
        if okT and t then F.uiTypingUntil = t + 300 end
    end
end

local function Job(where, fn, ...)
    local args = { ... }
    Script.QueueJob(function() Try(where, fn, (table.unpack or unpack)(args)) end)
end

local function ToPos(p)
    if not p then return nil end
    return { x = p.x + 0.0, y = p.y + 0.0, z = p.z + 0.0 }
end

local function EntityPos(h)
    if not h or h == 0 then return nil end
    local ok, p = pcall(function()
        local e = GTA.HandleToPointer(h)
        return e and e.Position
    end)
    if ok and p then return ToPos(p) end
    local ok2, a, b, c = pcall(Natives.InvokeV3, 0x3FEF770D40960D5A, h, true) -- GET_ENTITY_COORDS
    if ok2 and a then
        if type(a) == "number" then
            if b and c then return { x = a + 0.0, y = b + 0.0, z = c + 0.0 } end
        else
            local okT, t = pcall(ToPos, a)
            if okT then return t end
        end
    end
    return nil
end

local FeatureMgr = (function(cherax)
    local info = {}
    return setmetatable({
        info = info, -- hash -> { name, desc }
        AddFeature = function(hash, name, ftype, desc, ...)
            info[hash] = { name = name, desc = desc }
            return cherax.AddFeature(hash, name, ftype, desc, ...)
        end,
    }, { __index = cherax })
end)(FeatureMgr)

local function TrimSlash(p) return (p:gsub("[\\/]+$", "")) end

local function LuaDir() return TrimSlash(FileMgr.GetMenuRootPath()) .. "\\Lua" end

-- WHERE ITS FILES LIVE: Lua\CE = your constructs (kits in Lua\CE\kits),
-- Lua\CE\data = everything else (the autosave, favourites, ObjectList.txt)
local function CfgDir()
    local base = LuaDir() .. "\\CE"
    pcall(FileMgr.CreateDir, base)
    pcall(FileMgr.CreateDir, base .. "\\data")
    return base .. "\\data"
end
pcall(CfgDir)

local function Slider(hash, name, ftype, desc, min, max, step, default)
    local f = FeatureMgr.AddFeature(hash, name, ftype, desc)
    f:SetLimitValues(min, max)
    f:SetStepSize(step)
    f:SetDefaultValue(default)
    if ftype == eFeatureType.SliderInt then f:SetIntValue(default) else f:SetFloatValue(default) end
    return f
end

local function Toggle(hash, name, desc, default)
    local f = FeatureMgr.AddFeature(hash, name, eFeatureType.Toggle, desc)
    f:SetDefaultValue(default)
    f:SetBoolValue(default)
    F._bind = F._bind or {}
    F._bind[hash] = { name = name, kind = "toggle", f = f } -- for the Hotkeys page
    return f
end


-- Buttons ignore a second press within 0.4s (stops double-clicks / double callbacks doing things twice)
local function Button(hash, name, desc, fn)
    local last = -100000
    return FeatureMgr.AddFeature(hash, name, eFeatureType.Button, desc, function(...)
        local now = NowMs()
        if now - last < 400 then return end
        last = now
        return fn(...)
    end)
end

-- on-screen drawing that has to be asked for every frame (markers): kept for ms, drawn by the loop below
local HUD = { keep = {} }
F.hudKeep = function(key, fn, ms) HUD.keep[key] = { fn = fn, untilAt = NowMs() + (ms or 250) } end
function HUD.Frame(now)
    for k, v in pairs(HUD.keep) do
        if now <= v.untilAt then
            local ok, err = pcall(v.fn)
            if not ok and not HUD["err_" .. k] then HUD["err_" .. k] = true LogErr(k, err) end
        else
            HUD.keep[k] = nil
        end
    end
end



-- objects to stick on: { category, name, model } (the same list as LGNFX's Objects tab)
F.SPAWN_OBJECTS = {
    { "Cash", "Cash Pile2", "bkr_prop_bkr_cashpile_02" },
    { "Cash", "Cash Pile3", "bkr_prop_bkr_cashpile_03" },
    { "Cash", "Cash Pile4", "bkr_prop_bkr_cashpile_04" },
    { "Cash", "Cash Pile5", "bkr_prop_bkr_cashpile_05" },
    { "Cash", "Cash Pile", "bkr_prop_bkr_cashpile_01" },
    { "Cash", "Cash Roll", "bkr_prop_bkr_cash_roll_01" },
    { "Cash", "Cash Scatter3", "bkr_prop_bkr_cash_scatter_03" },
    { "Cash", "Cash Scatter", "bkr_prop_bkr_cash_scatter_01" },
    { "Cash", "Cash Trolley1A", "ch_prop_cash_low_trolly_01a" },
    { "Cash", "Cash Trolley1B", "ch_prop_cash_low_trolly_01b" },
    { "Cash", "Cash Trolley1C", "ch_prop_cash_low_trolly_01c" },
    { "Cash", "Cash Trolley", "bkr_prop_cashtrolley_01a" },
    { "Cash", "Exec Cash", "ex_prop_exec_cashpile" },
    { "Cranes", "Bucket", "v_ilev_found_cranebucket" },
    { "Cranes", "Crane2", "prop_dock_crane_02_cab" },
    { "Cranes", "Crane Cab1", "sm_prop_smug_cranecrab_01" },
    { "Cranes", "Crane Lg", "port_xr_cranelg" },
    { "Cranes", "Crane Lift", "prop_dock_crane_lift" },
    { "Cranes", "Crane Truck2", "prop_crane_01_truck2" },
    { "Cranes", "Crane Truck", "prop_crane_01_truck1" },
    { "Cranes", "Dock1", "prop_dock_crane_01" },
    { "Cranes", "Dock2", "prop_dock_crane_02" },
    { "Cranes", "Dock4", "prop_dock_crane_04" },
    { "Cranes", "Dock Cabl", "p_dock_crane_cabl_s" },
    { "Cranes", "Dock Cable", "p_dock_crane_cable_s" },
    { "Cranes", "Dock Crane2", "prop_dock_crane_02_ld" },
    { "Cranes", "Dock Crane", "p_dock_crane_sld_s" },
    { "Cranes", "Gird", "v_ilev_found_gird_crane" },
    { "Cranes", "Hook2", "prop_dock_crane_02_hook" },
    { "Cranes", "Pulley", "v_ilev_found_crane_pulley" },
    { "Cranes", "Rail Crane", "prop_rail_crane_01" },
    { "Cranes", "Smug Cab02", "sm_prop_smug_cranecrab_02" },
    { "Cranes", "Smug Crane01", "sm_prop_smug_crane_01" },
    { "Cranes", "Smug Crane02", "sm_prop_smug_crane_02" },
    { "Cranes", "Sub Crane", "p_sub_crane_s" },
    { "Cranes", "Tower Crane2A", "prop_towercrane_02a" },
    { "Cranes", "Tower Crane2B", "prop_towercrane_02b" },
    { "Cranes", "Tower Crane2C", "prop_towercrane_02c" },
    { "Cranes", "Tower Crane 2D", "prop_towercrane_02d" },
    { "Cranes", "Tower Crane 2E1", "prop_towercrane_02el" },
    { "Cranes", "Tower Crane 2E12", "prop_towercrane_02el2" },
    { "Cranes", "Tower Crane 2E", "prop_towercrane_02e" },
    { "Cranes", "Tower Crane", "prop_towercrane_01a" },
    { "Drugs", "Crack Pipe", "prop_cs_crackpipe" },
    { "Drugs", "Meth Bag", "prop_meth_bag_01" },
    { "Drugs", "Weedbag", "ba_prop_battle_weed_bigbag_01a" },
    { "Drugs", "Weeddry1", "xs_terrain_prop_weeddry_nxg01" },
    { "Drugs", "Weeddry2", "xs_terrain_prop_weeddry_nxg02" },
    { "Drugs", "Weeddry2B", "xs_terrain_prop_weeddry_nxg02b" },
    { "Drugs", "Weeddry3", "xs_terrain_prop_weeddry_nxg03" },
    { "Drugs", "Weeddry4", "xs_terrain_prop_weeddry_nxg04" },
    { "Houses", "House", "ela_wdn_04_" },
    { "Houses", "Stilt House", "des_stilthouse_root" },
    { "Houses", "Wood House", "ela_wdn_02_" },
    { "Houses", "Apartment2", "db_apart_02_" },
    { "Houses", "Apartment10", "db_apart_10_" },
    { "Houses", "Police Station", "hw1_09_policestation" },
    { "Houses", "Fire Station", "cs1_06_firest01" },
    { "Heist", "Carrier Defense1", "hei_prop_carrier_defense_01" },
    { "Heist", "Carrier Jet", "hei_prop_carrier_jet" },
    { "Heist", "Carrier", "prop_temp_carrier" },
    { "Heist", "Carrier Defense2", "hei_prop_carrier_defense_02" },
    { "Heist", "Emp", "hei_prop_heist_emp" },
    { "Heist", "Tug", "hei_prop_heist_tug" },
    { "Lights", "Light Wall", "prop_snow_wall_light_15a" },
    { "Lights", "Work Light", "tr_prop_tr_worklight_03b" },
    { "Lights", "Work Light2", "prop_worklight_02a" },
    { "Lights", "Tripod Lamp", "tr_prop_tr_tripod_lamp_01a" },
    { "LSTuners", "Mule", "tr_prop_tr_mule_mt_01a" },
    { "LSTuners", "Tampa", "tr_prop_tr_tampa2" },
    { "LSTuners", "Tattoo Van", "tr_prop_tr_van_ts_01a" },
    { "LSTuners", "Boxes Mule", "tr_prop_tr_mule_ms_01a" },
    { "LSTuners", "Truck Trailer", "tr_prop_tr_truktrailer_01a" },
    { "LSTuners", "Finish Line", "tr_prop_tr_finish_line_01a" },
    { "LSTuners", "Camhedz", "tr_prop_tr_camhedz_01a" },
    { "LSTuners", "Ramp", "tr_prop_tr_ramp_01a" },
    { "LSTuners", "Skip Ramp", "tr_prop_tr_skip_ramp_01a" },
    { "Traffic", "Cone1", "prop_mp_cone_01" },
    { "Traffic", "Cone2", "prop_mp_cone_02" },
    { "Traffic", "Cone3", "prop_mp_cone_03" },
    { "Traffic", "Cone4", "prop_mp_cone_04" },
    { "Traffic", "Cone Float", "prop_cone_float_1" },
    { "Traffic", "Cone Light", "prop_air_conelight" },
    { "Traffic", "60 Snow", "prop_snow_sign_road_06g" },
    { "Traffic", "Barrel", "prop_barrier_wat_03a" },
    { "Traffic", "Barrier", "prop_barier_conc_02b" },
    { "Traffic", "Works ahead", "prop_barrier_work04a" },
    { "Traffic", "Work Barrier", "prop_barrier_work06a" },
    { "Traffic", "Police Barrier", "prop_barrier_work05" },
    { "Signs", "Ammu Sign", "sr_mp_spec_races_ammu_sign" },
    { "Signs", "Blimp Sign", "sr_mp_spec_races_blimp_sign" },
    { "Signs", "Circuit1", "stt_prop_sign_circuit_01" },
    { "Signs", "Circuit2", "stt_prop_sign_circuit_02" },
    { "Signs", "Circuit3", "stt_prop_sign_circuit_03" },
    { "Signs", "Circuit4", "stt_prop_sign_circuit_04" },
    { "Signs", "Flight Sign", "sr_mp_spec_races_take_flight_sign" },
    { "Signs", "Ron Sign", "sr_mp_spec_races_ron_sign" },
    { "Signs", "Venic Sign2", "prop_venice_sign_02" },
    { "Signs", "Venice Sign1", "prop_venice_sign_01" },
    { "Signs", "Venice Sign3", "prop_venice_sign_03" },
    { "Signs", "Venice Sign4", "prop_venice_sign_04" },
    { "Signs", "Venice Sign5", "prop_venice_sign_05" },
    { "Signs", "Xero Sign", "sr_mp_spec_races_xero_sign" },
    { "Rocks", "Boulder1", "csx_coastboulder_01_" },
    { "Rocks", "Boulder2", "csx_coastboulder_02_" },
    { "Rocks", "Boulder3", "csx_coastboulder_03_" },
    { "Rocks", "Boulder4", "csx_coastboulder_04_" },
    { "Rocks", "Boulder5", "csx_coastboulder_05_" },
    { "Rocks", "Boulder6", "csx_coastboulder_06_" },
    { "Rocks", "Boulder7", "csx_coastboulder_07_" },
    { "Rocks", "Boulder8", "csx_rvrbldr_biga_" },
    { "Rocks", "Boulder9", "csx_rvrbldr_bigb_" },
    { "Rocks", "Boulder10", "csx_rvrbldr_bigc_" },
    { "Rocks", "Boulder11", "csx_rvrbldr_bigd_" },
    { "Rocks", "Boulder", "csx_coastboulder_00_" },
    { "Rocks", "Rock1", "csx_coastrok1_" },
    { "Rocks", "Rock2", "csx_coastrok2_" },
    { "Rocks", "Rock3", "csx_coastrok3_" },
    { "Rocks", "Rock4", "csx_coastrok4_" },
    { "Rocks", "Seabed1", "csx_seabed_bldr1_" },
    { "Rocks", "Seabed2", "csx_seabed_bldr2_" },
    { "Rocks", "Seabed3", "csx_seabed_bldr3_" },
    { "Rocks", "Seabed4", "csx_seabed_bldr4_" },
    { "Rocks", "Seabed5", "csx_seabed_bldr5_" },
    { "Rocks", "Seabed6", "csx_seabed_bldr6_" },
    { "Rocks", "Seabed7", "csx_seabed_bldr7_" },
    { "Rocks", "Seabed8", "csx_seabed_bldr8_" },
    { "Space", "Black Ufo", "sum_prop_dufocore_01a" },
    { "Space", "Fib Uffo", "p_spinning_anus_s" },
    { "Yacht", "Candles", "apa_mp_h_acc_candles_01" },
    { "Yacht", "Jacuzzi Water2", "apa_mp_apa_yacht_jacuzzi_ripple1" },
    { "Yacht", "Jacuzzi Water", "apa_mp_apa_yacht_jacuzzi_ripple003" },
    { "Yacht", "Rail Gold", "apa_mp_apa_yacht_o1_rail_b" },
    { "Yacht", "Rail Silver", "apa_mp_apa_yacht_o1_rail_a" },
    { "Yacht", "Yacht Radar", "apa_mp_apa_yacht_radar_01a" },
    { "Yacht", "Yacht Windows", "apa_mp_apa_yacht_win" },
    { "Yacht", "Yacht", "apa_mp_apa_yacht" },
    { "Misc", "Bomb1", "w_smug_bomb_01" },
    { "Misc", "Bomb1B", "w_smug_airmissile_01b" },
    { "Misc", "Bomb2", "w_smug_bomb_02" },
    { "Misc", "Bomb3", "w_smug_bomb_03" },
    { "Misc", "Bomb4", "w_smug_bomb_04" },
    { "Misc", "Camp Fire", "prop_beach_fire" },
    { "Misc", "Orange Ball", "prop_juicestand" },
    { "Misc", "Teddy", "v_ilev_mr_rasberryclean" },
    { "Misc", "Police Shield", "prop_ballistic_shield" },
    { "Misc", "Riot Shield", "prop_riot_shield" },
    { "Misc", "Military Pickup", "tr_prop_tr_military_pickup_01a" },
}

Try("creating driving helpers", function()
    local N = {
        PLAYER_PED_ID                   = 0xD80958FC74E988A6,
        GET_VEHICLE_PED_IS_IN           = 0x9A9112A0FE9A4713,
        GET_PED_IN_VEHICLE_SEAT         = 0xBB40DD2270B65366,
        IS_PED_IN_ANY_VEHICLE           = 0x997ABD671D25CA0B,
        GET_MODEL_DIMENSIONS            = 0x03E8D3D5F549087A,
        DOES_ENTITY_EXIST               = 0x7239B21A38F536BA,
        SET_ENTITY_AS_MISSION_ENTITY    = 0xAD738C3085FE7E11,
        DELETE_ENTITY                   = 0xAE3CBE5BF394C9C9,
        NETWORK_HAS_CONTROL_OF_ENTITY   = 0x01BF60A500E28887,
        NETWORK_REQUEST_CONTROL_OF_ENTITY = 0xB69317BF5E782347,
    }
    local X = {}
    F.LX = X
    F.hudDraws = F.hudDraws or {}
    F.unloadHooks = F.unloadHooks or {}

    -- a game function that gives back a position / vector, as {x, y, z}
    function X.V3(hash, ...)
        local ok, a, b, c = pcall(Natives.InvokeV3, hash, ...)
        if not ok or a == nil then return nil end
        if type(a) == "number" then
            if b and c then return { x = a + 0.0, y = b + 0.0, z = c + 0.0 } end
            return nil
        end
        local okT, t = pcall(ToPos, a)
        return okT and t or nil
    end
    function X.Me()
        local ok, me = pcall(Natives.InvokeInt, N.PLAYER_PED_ID)
        return (ok and me and me ~= 0) and me or nil
    end
    -- the car you're in: car, you, are you the driver
    function X.Car()
        local me = X.Me()
        if not me or not IB(N.IS_PED_IN_ANY_VEHICLE, me, false) then return nil, me, false end
        local veh = Natives.InvokeInt(N.GET_VEHICLE_PED_IS_IN, me, false)
        if not veh or veh == 0 then return nil, me, false end
        return veh, me, Natives.InvokeInt(N.GET_PED_IN_VEHICLE_SEAT, veh, -1, false) == me
    end
    local dimCache = {}
    -- model size: minX, minY, minZ, maxX, maxY, maxZ
    function X.Dims(model)
        local d = dimCache[model]
        if d then return d[1], d[2], d[3], d[4], d[5], d[6] end
        local out = { -1.0, -2.3, -0.6, 1.0, 2.3, 1.0 }
        pcall(function()
            local a, b = Memory.Alloc(32), Memory.Alloc(32)
            Natives.InvokeVoid(N.GET_MODEL_DIMENSIONS, model, a, b)
            local v = { Memory.ReadFloat(a), Memory.ReadFloat(a + 8), Memory.ReadFloat(a + 16),
                        Memory.ReadFloat(b), Memory.ReadFloat(b + 8), Memory.ReadFloat(b + 16) }
            Memory.Free(a) Memory.Free(b)
            if v[1] and v[5] and v[5] > v[2] and v[5] - v[2] < 40 then out = v end
        end)
        dimCache[model] = out
        return out[1], out[2], out[3], out[4], out[5], out[6]
    end
    -- deleting: online only whoever controls a thing can delete it - if the game's handed it to another player's
    -- game, the delete used to fail quietly and the thing was left behind for good (hidden buses, markers and
    -- DJs piling up in the lobby's limit on shared things). Now it asks for it back and keeps trying for a
    -- while; if it never comes back, it's handed over to the game to clean away like any ambient thing
    local delQ = {}
    local function DeleteNow(h)
        pcall(function()
            Natives.InvokeVoid(N.SET_ENTITY_AS_MISSION_ENTITY, h, true, true)
            local p = Memory.AllocInt() Memory.WriteInt(p, h)
            Natives.InvokeVoid(N.DELETE_ENTITY, p)
            Memory.Free(p)
        end)
    end
    function X.Delete(h)
        if not h or h == 0 or not IB(N.DOES_ENTITY_EXIST, h) then return end
        if not IB(N.NETWORK_HAS_CONTROL_OF_ENTITY, h) then pcall(Natives.InvokeVoid, N.NETWORK_REQUEST_CONTROL_OF_ENTITY, h) end
        DeleteNow(h)
        if IB(N.DOES_ENTITY_EXIST, h) and not delQ[h] then delQ[h] = NowMs() end
        LGX.spawned[h] = nil
    end
    -- (debug log: going into / out of a building, what LGNFX has made that's still about - so if a building
    -- ever acts up, the log shows whether any of it was LGNFX's)
    local inside, nextIn = nil, 0
    local function NoteBuilding(now)
        if now < nextIn then return end
        nextIn = now + 2000
        local okP, me = pcall(Natives.InvokeInt, 0xD80958FC74E988A6) -- PLAYER_PED_ID
        if not okP or not me or me == 0 then return end
        local okI, int = pcall(Natives.InvokeInt, 0x2107BA504071A6BB, me) -- GET_INTERIOR_FROM_ENTITY
        local now_in = okI and int ~= nil and int ~= 0
        if now_in == inside then return end
        inside = now_in
        local peds, vehs, objs, total = 0, 0, 0, 0
        for h in pairs(LGX.spawned) do
            if IB(N.DOES_ENTITY_EXIST, h) then
                total = total + 1
                local okT, t = pcall(Natives.InvokeInt, 0x8ACD366038D14505, h) -- GET_ENTITY_TYPE (1 ped, 2 vehicle, 3 object)
                if okT and t == 1 then peds = peds + 1 elseif okT and t == 2 then vehs = vehs + 1 else objs = objs + 1 end
            else
                LGX.spawned[h] = nil
            end
        end
        local q = 0 for _ in pairs(delQ) do q = q + 1 end
        pcall(Dump.Info, ("[CE] %s a building - things this script made still about: %d (%d people, %d vehicles, %d props), %d waiting to be deleted"):format(
            now_in and "went into" or "came out of", total, peds, vehs, objs, q))
    end
    F.lxDeleteTick = function()
        pcall(NoteBuilding, NowMs())
        if next(delQ) == nil then return end
        local now = NowMs()
        for h, since in pairs(delQ) do
            if not IB(N.DOES_ENTITY_EXIST, h) then delQ[h] = nil
            elseif IB(N.NETWORK_HAS_CONTROL_OF_ENTITY, h) then DeleteNow(h)
                if not IB(N.DOES_ENTITY_EXIST, h) then delQ[h] = nil end
            elseif now - since > 15000 then
                -- (never got it back: let the game clean it up)
                pcall(function()
                    local p = Memory.AllocInt() Memory.WriteInt(p, h)
                    Natives.InvokeVoid(0xB736A491E64A32CF, p) -- SET_ENTITY_AS_NO_LONGER_NEEDED
                    Memory.Free(p)
                end)
                delQ[h] = nil
            else
                pcall(Natives.InvokeVoid, N.NETWORK_REQUEST_CONTROL_OF_ENTITY, h)
            end
        end
    end
    -- keys (never while you're typing in chat)
    function X.Key(vk) return vk and vk > 0 and Utils.IsKeyDown(vk) and not F.Typing() end
    local keyWas = {}
    function X.KeyTap(id, vk) -- true once when the key goes down
        local down = X.Key(vk)
        local was = keyWas[id]
        keyWas[id] = down
        return down and not was
    end
    X.KEYS = {
        { "Left Shift", 0xA0 }, { "Left Ctrl", 0xA2 }, { "Left Alt", 0xA4 }, { "Caps Lock", 0x14 },
        { "Q", 0x51 }, { "E", 0x45 }, { "Z", 0x5A }, { "X", 0x58 }, { "C", 0x43 }, { "B", 0x42 },
        { "Mouse Side 1", 0x05 }, { "Mouse Side 2", 0x06 }, { "Page Up", 0x21 }, { "Page Down", 0x22 },
        { "Up Arrow", 0x26 }, { "Down Arrow", 0x28 }, { "Numpad +", 0x6B }, { "Numpad -", 0x6D },
        { "Numpad 0", 0x60 }, { "Numpad Enter / Enter", 0x0D }, { "Right Shift", 0xA1 }, { "Right Ctrl", 0xA3 },
    }
    X.KEY_NAMES = {}
    for i, k in ipairs(X.KEYS) do X.KEY_NAMES[i] = k[1] end
end)

Try("creating bring them back", function()
    local N = {
        GET_ENTITY_MODEL      = 0x9F47B058362C84B5, GET_ENTITY_COORDS = 0x3FEF770D40960D5A,
        GET_ENTITY_ROTATION   = 0xAFBD61CC738D9EB9, IS_ENTITY_VISIBLE = 0x47D6F43D77935C75,
        GET_ENTITY_ALPHA      = 0x5A47B3B5E63E94C6, IS_ENTITY_A_VEHICLE = 0x6AC7003FA6E5575E,
        IS_ENTITY_A_PED       = 0x524AC5ECEA15343E, DOES_ENTITY_EXIST = 0x7239B21A38F536BA,
        GET_ENTITY_HEADING    = 0xE83D4F9BA2A38914,
        GET_VEHICLE_MOD = 0x772960298DA26FDB, GET_VEHICLE_MOD_VARIATION = 0xB3924ECD70E095DC,
        GET_VEHICLE_WHEEL_TYPE = 0xB3ED1BFB4BE636DC, IS_TOGGLE_MOD_ON = 0x84B233A8C8FC8AE7,
        GET_VEHICLE_COLOURS = 0xA19435F193E081AC, GET_VEHICLE_EXTRA_COLOURS = 0x3BC4245933A166F7,
        GET_IS_VEHICLE_PRIMARY_COLOUR_CUSTOM = 0xF095C0405307B21B, GET_IS_VEHICLE_SECONDARY_COLOUR_CUSTOM = 0x910A32E7AAD2656C,
        GET_VEHICLE_CUSTOM_PRIMARY_COLOUR = 0xB64CF2CCA9D95F52, GET_VEHICLE_CUSTOM_SECONDARY_COLOUR = 0x8389CD56CA8072DC,
        GET_VEHICLE_LIVERY = 0x2BB9230590DA5E8A, GET_VEHICLE_NUMBER_PLATE_TEXT = 0x7CE1CCB9B293020E,
        GET_VEHICLE_NUMBER_PLATE_TEXT_INDEX = 0xF11BC2DD9A3E7195, GET_VEHICLE_WINDOW_TINT = 0x0EE21293DAD47C95,
        GET_VEHICLE_NEON_ENABLED = 0x8C4B92553E4766A5, GET_VEHICLE_NEON_COLOUR = 0x7619EEE8C886757F,
        GET_VEHICLE_TYRE_SMOKE_COLOR = 0xB635392A4938B3C3, GET_VEHICLE_XENON_LIGHT_COLOR_INDEX = 0x3DFF319A831E0CDB,
        GET_VEHICLE_EXTRA_COLOUR_5 = 0x7D1464D472D32136, GET_VEHICLE_EXTRA_COLOUR_6 = 0xB7635E80A5C31BFF,
    }
    local BB = { cur = nil, shownSecs = nil }
    F.BB = BB
    local function V3(hash, ...)
        local ok, a, b, c = pcall(Natives.InvokeV3, hash, ...)
        if not ok or a == nil then return nil end
        if type(a) == "number" then return (b and c) and { x = a + 0.0, y = b + 0.0, z = c + 0.0 } or nil end
        local okT, t = pcall(ToPos, a)
        return okT and t or nil
    end
    BB.V3 = V3
    -- the game's "read into these numbers" natives
    local function Ints(n, hash, ...)
        local ok, r = pcall(function(...)
            local p = {}
            for i = 1, n do p[i] = Memory.AllocInt() Memory.WriteInt(p[i], 0) end
            local args = { ... }
            for i = 1, n do args[#args + 1] = p[i] end
            Natives.InvokeVoid(hash, table.unpack(args))
            local out = {}
            for i = 1, n do out[i] = Memory.ReadInt(p[i]) or 0 Memory.Free(p[i]) end
            return out
        end, ...)
        return ok and r or nil
    end
    -- a vehicle's whole look, in the form the XML / JSON spawner puts back
    function BB.VehLook(h)
        local v = { mods = {}, toggles = {}, extras = {} }
        pcall(function()
            v.wheelType = Natives.InvokeInt(N.GET_VEHICLE_WHEEL_TYPE, h)
            for i = 0, 49 do
                local m = Natives.InvokeInt(N.GET_VEHICLE_MOD, h, i)
                if m and m >= 0 then v.mods[#v.mods + 1] = { i, m, (i == 23 or i == 24) and IB(N.GET_VEHICLE_MOD_VARIATION, h, i) or false } end
            end
            for _, i in ipairs({ 18, 20, 22 }) do v.toggles[#v.toggles + 1] = { i, IB(N.IS_TOGGLE_MOD_ON, h, i) } end
            local c = Ints(2, N.GET_VEHICLE_COLOURS, h)
            if c then v.primary, v.secondary = c[1], c[2] end
            c = Ints(2, N.GET_VEHICLE_EXTRA_COLOURS, h)
            if c then v.pearl, v.rim = c[1], c[2] end
            if IB(N.GET_IS_VEHICLE_PRIMARY_COLOUR_CUSTOM, h) then v.custom1 = Ints(3, N.GET_VEHICLE_CUSTOM_PRIMARY_COLOUR, h) end
            if IB(N.GET_IS_VEHICLE_SECONDARY_COLOUR_CUSTOM, h) then v.custom2 = Ints(3, N.GET_VEHICLE_CUSTOM_SECONDARY_COLOUR, h) end
            c = Ints(1, N.GET_VEHICLE_EXTRA_COLOUR_5, h) if c then v.interior = c[1] end
            c = Ints(1, N.GET_VEHICLE_EXTRA_COLOUR_6, h) if c then v.dash = c[1] end
            v.smoke = Ints(3, N.GET_VEHICLE_TYRE_SMOKE_COLOR, h)
            v.neonColour = Ints(3, N.GET_VEHICLE_NEON_COLOUR, h)
            v.neons = {}
            for i = 0, 3 do v.neons[i + 1] = IB(N.GET_VEHICLE_NEON_ENABLED, h, i) end
            v.livery = Natives.InvokeInt(N.GET_VEHICLE_LIVERY, h)
            v.tint = Natives.InvokeInt(N.GET_VEHICLE_WINDOW_TINT, h)
            v.plateIndex = Natives.InvokeInt(N.GET_VEHICLE_NUMBER_PLATE_TEXT_INDEX, h)
            local okP, plate = pcall(Natives.InvokeString, N.GET_VEHICLE_NUMBER_PLATE_TEXT, h)
            if okP and plate and plate ~= "" then v.plate = plate end
            local x = Natives.InvokeInt(N.GET_VEHICLE_XENON_LIGHT_COLOR_INDEX, h)
            if x and x >= 0 and x < 255 then v.xenon = x end
        end)
        return v
    end
    -- one thing, as it is right now
    function BB.Snap(h)
        if not h or not IB(N.DOES_ENTITY_EXIST, h) then return nil end
        local r = { h = h, model = (Natives.InvokeInt(N.GET_ENTITY_MODEL, h) or 0) % 4294967296 }
        r.kind = IB(N.IS_ENTITY_A_VEHICLE, h) and 2 or (IB(N.IS_ENTITY_A_PED, h) and 1 or 3)
        r.pos = V3(N.GET_ENTITY_COORDS, h, false) or EntityPos(h)
        r.rot = V3(N.GET_ENTITY_ROTATION, h, 2) or { x = 0.0, y = 0.0, z = Natives.InvokeFloat(N.GET_ENTITY_HEADING, h) or 0.0 }
        r.vis = IB(N.IS_ENTITY_VISIBLE, h)
        local okA, a = pcall(Natives.InvokeInt, N.GET_ENTITY_ALPHA, h)
        r.alpha = (okA and a and a > 0 and a < 255) and a or 255
        if r.kind == 2 then r.veh = BB.VehLook(h) end
        return r
    end
    -- after deleting: what was deleted, and how to put it back
    function BB.Offer(label, restore)
        BB.cur = { label = label, restore = restore, untilAt = NowMs() + 15000 }
        BB.shownSecs = nil
        Notify("Deleted " .. label .. " - press Bring Them Back within 15 seconds to undo", true, "spawner", { merge = "bringback" })
    end
    F.bringBack = Button(H.bringBack, "Bring Them Back",
        "For 15 seconds after a Delete All (or deleting a construct) this puts everything back exactly where it was", function()
            local c = BB.cur
            if not c or NowMs() > c.untilAt then Notify("Nothing to bring back - it works for 15 seconds after deleting", true, "spawner") return end
            BB.cur = nil
            Job("bringing them back", function()
                local ok, err = pcall(c.restore)
                if not ok then LogErr("bring them back", err) return end
                Notify("Brought back " .. c.label, true, "spawner", { merge = "bringback" })
            end)
        end)
    F.bbTick = function()
        local c = BB.cur
        local secs = c and math.ceil((c.untilAt - NowMs()) / 1000) or nil
        if secs and secs <= 0 then BB.cur, secs = nil, nil end
        if secs ~= BB.shownSecs then
            BB.shownSecs = secs
            pcall(function() F.bringBack:SetName(secs and ("Bring Them Back (" .. secs .. "s)") or "Bring Them Back") end)
        end
    end
end)

Try("creating xml/json spawner", function()
    local XS = {}  -- the parsers live in here so they can be tested on their own

    -- ----- small helpers -----
    local function num(s)
        if s == nil then return nil end
        if type(s) == "number" then return s end
        s = tostring(s):gsub("^%s+", ""):gsub("%s+$", "")
        return tonumber(s)
    end
    local function bool(s, default)
        if s == nil then return default end
        if type(s) == "boolean" then return s end
        if type(s) == "number" then return s ~= 0 end
        s = tostring(s):lower():gsub("%s", "")
        if s == "true" or s == "1" or s == "yes" then return true end
        if s == "false" or s == "0" or s == "no" then return false end
        return default
    end
    -- any hash written as 0x..., decimal, or negative -> unsigned 32-bit number
    local function hashOf(v)
        if v == nil then return nil end
        local n
        if type(v) == "number" then
            n = v
        else
            local s = tostring(v):gsub("%s", "")
            if s == "" then return nil end
            if s:match("^%-?0[xX]%x+$") or s:match("^%-?%d+$") then
                n = tonumber(s)
            else
                local ok, h = pcall(Utils.Joaat, s:lower()) -- a model name
                n = ok and h or nil
            end
        end
        if not n then return nil end
        n = math.floor(n) % 4294967296
        if n == 0 then return nil end
        return n
    end
    XS.hashOf, XS.num, XS.bool = hashOf, num, bool

    -- ----- XML -----
    local ENT = { amp = "&", lt = "<", gt = ">", quot = "\"", apos = "'" }
    local function unescape(s)
        return (s:gsub("&(#?[%w]+);", function(e)
            if ENT[e] then return ENT[e] end
            local n = e:match("^#x(%x+)$")
            if n then n = tonumber(n, 16) else n = tonumber(e:match("^#(%d+)$") or "") end
            if n and n < 256 then return string.char(n) end
            return "&" .. e .. ";"
        end))
    end
    -- returns the root element: { tag, attr = {}, kids = {}, text = "" }
    function XS.ParseXML(s)
        s = s:gsub("^\239\187\191", "") -- UTF-8 BOM
        local root = { tag = "#doc", attr = {}, kids = {}, text = "" }
        local stack = { root }
        local i, n = 1, #s
        while i <= n do
            local lt = s:find("<", i, true)
            local top = stack[#stack]
            if not lt then
                top.text = top.text .. s:sub(i)
                break
            end
            if lt > i then top.text = top.text .. s:sub(i, lt - 1) end
            if s:sub(lt, lt + 3) == "<!--" then
                local e = s:find("-->", lt + 4, true)
                i = (e or n) + 3
            elseif s:sub(lt, lt + 8) == "<![CDATA[" then
                local e = s:find("]]>", lt + 9, true) or n
                top.text = top.text .. s:sub(lt + 9, e - 1)
                i = e + 3
            elseif s:sub(lt, lt + 1) == "<?" or s:sub(lt, lt + 1) == "<!" then
                local e = s:find(">", lt, true)
                i = (e or n) + 1
            elseif s:sub(lt, lt + 1) == "</" then
                local e = s:find(">", lt, true) or n
                local tag = s:sub(lt + 2, e - 1):gsub("%s", "")
                -- close back to the matching tag (tolerates sloppy files)
                for k = #stack, 2, -1 do
                    if stack[k].tag == tag then
                        for _ = #stack, k, -1 do table.remove(stack) end
                        break
                    end
                end
                i = e + 1
            else
                -- find the end of this tag, skipping '>' inside quotes
                local j, q = lt + 1, nil
                while j <= n do
                    local c = s:sub(j, j)
                    if q then
                        if c == q then q = nil end
                    elseif c == "\"" or c == "'" then
                        q = c
                    elseif c == ">" then
                        break
                    end
                    j = j + 1
                end
                local body = s:sub(lt + 1, j - 1)
                local selfClose = body:sub(-1) == "/"
                if selfClose then body = body:sub(1, -2) end
                local tag = body:match("^([^%s/>]+)") or ""
                local node = { tag = tag, attr = {}, kids = {}, text = "" }
                for k, _, v in body:gmatch("([%w_:%-%.]+)%s*=%s*([\"'])(.-)%2") do
                    node.attr[k] = unescape(v)
                end
                top.kids[#top.kids + 1] = node
                if not selfClose then stack[#stack + 1] = node end
                i = j + 1
            end
        end
        local function fix(node)
            node.text = unescape(node.text):gsub("^%s+", ""):gsub("%s+$", "")
            for _, k in ipairs(node.kids) do fix(k) end
        end
        fix(root)
        for _, k in ipairs(root.kids) do return k end
        return nil
    end
    local function kid(node, tag)
        if not node then return nil end
        for _, k in ipairs(node.kids) do if k.tag == tag then return k end end
        return nil
    end
    local function kids(node, tag)
        local out = {}
        if node then for _, k in ipairs(node.kids) do if k.tag == tag then out[#out + 1] = k end end end
        return out
    end
    local function txt(node, tag)
        local k = kid(node, tag)
        return k and k.text or nil
    end
    local function xyz(node)
        if not node then return nil end
        local x, y, z = num(txt(node, "X")), num(txt(node, "Y")), num(txt(node, "Z"))
        if not (x and y and z) then return nil end
        return { x = x, y = y, z = z }
    end

    -- ----- JSON -----
    function XS.ParseJSON(s)
        s = s:gsub("^\239\187\191", "")
        local i = 1
        local function ws() i = s:find("[^ \t\r\n]", i) or (#s + 1) end
        local function err(m) error("JSON: " .. m .. " at character " .. i, 0) end
        local value
        local function str()
            i = i + 1
            local out = {}
            while true do
                local c = s:sub(i, i)
                if c == "" then err("unfinished text") end
                if c == "\"" then i = i + 1 break end
                if c == "\\" then
                    local e = s:sub(i + 1, i + 1)
                    local map = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
                    if e == "u" then
                        local code = tonumber(s:sub(i + 2, i + 5), 16) or 63
                        out[#out + 1] = code < 128 and string.char(code) or "?"
                        i = i + 6
                    else
                        out[#out + 1] = map[e] or e
                        i = i + 2
                    end
                else
                    local j = s:find("[\"\\]", i) or (#s + 1)
                    out[#out + 1] = s:sub(i, j - 1)
                    i = j
                end
            end
            return table.concat(out)
        end
        value = function()
            ws()
            local c = s:sub(i, i)
            if c == "{" then
                i = i + 1
                local t = {}
                ws()
                if s:sub(i, i) == "}" then i = i + 1 return t end
                while true do
                    ws()
                    if s:sub(i, i) ~= "\"" then err("expected a name") end
                    local k = str()
                    ws()
                    if s:sub(i, i) ~= ":" then err("expected ':'") end
                    i = i + 1
                    t[k] = value()
                    ws()
                    local d = s:sub(i, i)
                    i = i + 1
                    if d == "}" then return t end
                    if d ~= "," then err("expected ',' or '}'") end
                end
            elseif c == "[" then
                i = i + 1
                local t = {}
                ws()
                if s:sub(i, i) == "]" then i = i + 1 return t end
                while true do
                    t[#t + 1] = value()
                    ws()
                    local d = s:sub(i, i)
                    i = i + 1
                    if d == "]" then return t end
                    if d ~= "," then err("expected ',' or ']'") end
                end
            elseif c == "\"" then
                return str()
            elseif s:sub(i, i + 3) == "true" then i = i + 4 return true
            elseif s:sub(i, i + 4) == "false" then i = i + 5 return false
            elseif s:sub(i, i + 3) == "null" then i = i + 4 return nil
            else
                local m = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
                if not m or m == "" then err("unexpected '" .. c .. "'") end
                i = i + #m
                return tonumber(m)
            end
        end
        local v = value()
        return v
    end

    -- ----- turn a file into a spawn plan -----
    -- plan = { kind = "map"|"vehicle", items = {...}, ref = {x,y,z}, ipls = {...} }
    -- item = { id, model, name, type (1 ped, 2 vehicle, 3 object), pos, rot, frozen, dynamic,
    --          visible, alpha, lod, invincible, proofs, gravity, tint, veh (menyoo vehicle props),
    --          attach = { to, bone, off, rot, collision } }

    local function menyooItem(node)
        local it = {
            id = txt(node, "InitialHandle"),
            model = hashOf(txt(node, "ModelHash")) or hashOf(txt(node, "HashName")),
            name = txt(node, "HashName"),
            type = num(txt(node, "Type")),
            dynamic = bool(txt(node, "Dynamic"), nil),
            frozen = bool(txt(node, "FrozenPos"), nil),
            visible = bool(txt(node, "IsVisible"), true),
            alpha = num(txt(node, "OpacityLevel")),
            lod = num(txt(node, "LodDistance")),
            invincible = bool(txt(node, "IsInvincible"), false),
            gravity = bool(txt(node, "HasGravity"), true),
            proofs = {
                bool(txt(node, "IsBulletProof"), false), bool(txt(node, "IsFireProof"), false),
                bool(txt(node, "IsExplosionProof"), false), bool(txt(node, "IsCollisionProof"), false),
                bool(txt(node, "IsMeleeProof"), false),
            },
        }
        local op = kid(node, "ObjectProperties")
        if op then it.tint = num(txt(op, "TextureVariation")) end
        local pr = kid(node, "PositionRotation")
        if pr then
            it.pos = xyz(pr)
            it.rot = { x = num(txt(pr, "Pitch")) or 0, y = num(txt(pr, "Roll")) or 0, z = num(txt(pr, "Yaw")) or 0 }
        end
        local at = kid(node, "Attachment")
        if at and bool(at.attr.isAttached, false) then
            it.attach = {
                to = txt(at, "AttachedTo"),
                bone = num(txt(at, "BoneIndex")) or 0,
                off = { x = num(txt(at, "X")) or 0, y = num(txt(at, "Y")) or 0, z = num(txt(at, "Z")) or 0 },
                rot = { x = num(txt(at, "Pitch")) or 0, y = num(txt(at, "Roll")) or 0, z = num(txt(at, "Yaw")) or 0 },
                collision = false,
            }
        end
        local vp = kid(node, "VehicleProperties")
        if vp then
            local v = { mods = {}, toggles = {}, extras = {}, neons = {} }
            local c = kid(vp, "Colours")
            if c then
                v.primary, v.secondary = num(txt(c, "Primary")), num(txt(c, "Secondary"))
                v.pearl, v.rim = num(txt(c, "Pearl")), num(txt(c, "Rim"))
                if bool(txt(c, "IsPrimaryColourCustom"), false) then
                    v.custom1 = { num(txt(c, "Cust1_R")) or 0, num(txt(c, "Cust1_G")) or 0, num(txt(c, "Cust1_B")) or 0 }
                end
                if bool(txt(c, "IsSecondaryColourCustom"), false) then
                    v.custom2 = { num(txt(c, "Cust2_R")) or 0, num(txt(c, "Cust2_G")) or 0, num(txt(c, "Cust2_B")) or 0 }
                end
                local r = num(txt(c, "tyreSmoke_R"))
                if r then v.smoke = { r, num(txt(c, "tyreSmoke_G")) or 0, num(txt(c, "tyreSmoke_B")) or 0 } end
            end
            v.livery = num(txt(vp, "Livery"))
            v.plate = txt(vp, "NumberPlateText")
            v.plateIndex = num(txt(vp, "NumberPlateIndex"))
            v.wheelType = num(txt(vp, "WheelType"))
            v.tint = num(txt(vp, "WindowTint"))
            v.bpTyres = bool(txt(vp, "BulletProofTyres"), nil)
            v.dirt = num(txt(vp, "DirtLevel"))
            v.engineOn = bool(txt(vp, "EngineOn"), nil)
            local ne = kid(vp, "Neons")
            if ne then
                v.neons = { bool(txt(ne, "Left"), false), bool(txt(ne, "Right"), false),
                            bool(txt(ne, "Front"), false), bool(txt(ne, "Back"), false) }
                v.neonColour = { num(txt(ne, "R")) or 255, num(txt(ne, "G")) or 0, num(txt(ne, "B")) or 255 }
            end
            for _, m in ipairs((kid(vp, "Mods") or { kids = {} }).kids) do
                local slot = tonumber(m.tag:match("^_(%d+)$") or "")
                if slot then
                    local a, b = m.text:match("^(%-?%d+)%s*,%s*(%-?%d+)")
                    if a then
                        v.mods[#v.mods + 1] = { slot, tonumber(a), tonumber(b) ~= 0 }
                    elseif bool(m.text, nil) ~= nil then
                        v.toggles[#v.toggles + 1] = { slot, bool(m.text, false) }
                    end
                end
            end
            for _, e in ipairs((kid(vp, "ModExtras") or { kids = {} }).kids) do
                local id = tonumber(e.tag:match("^_(%d+)$") or "")
                if id then v.extras[#v.extras + 1] = { id, bool(e.text, false) } end
            end
            it.veh = v
        end
        return it
    end

    local function fromMenyooMap(root)
        local plan = { kind = "map", items = {}, ipls = {} }
        plan.ref = xyz(kid(root, "ReferenceCoords"))
        for _, ip in ipairs((kid(root, "IPLsToLoad") or { kids = {} }).kids) do
            if ip.text ~= "" then plan.ipls[#plan.ipls + 1] = ip.text end
        end
        for _, p in ipairs(kids(root, "Placement")) do plan.items[#plan.items + 1] = menyooItem(p) end
        return plan
    end

    local function fromMenyooVehicle(root)
        local plan = { kind = "vehicle", items = {} }
        local base = menyooItem(root)
        base.type = 2
        base.pos, base.attach = nil, nil
        base.id = base.id or "__base"
        plan.items[1] = base
        plan.root = base.id
        for _, a in ipairs(kids(kid(root, "SpoonerAttachments"), "Attachment")) do
            local it = menyooItem(a)
            if it.attach and (not it.attach.to or it.attach.to == "") then it.attach.to = base.id end
            plan.items[#plan.items + 1] = it
        end
        return plan
    end

    local function fromMapEditor(root)
        local plan = { kind = "map", items = {} }
        local TYPES = { prop = 3, object = 3, vehicle = 2, ped = 1 }
        for _, o in ipairs(kids(kid(root, "Objects"), "MapObject")) do
            local t = TYPES[(txt(o, "Type") or "prop"):lower()]
            if t then
                local r = xyz(kid(o, "Rotation")) or { x = 0, y = 0, z = 0 }
                local dyn = bool(txt(o, "Dynamic"), false)
                plan.items[#plan.items + 1] = {
                    model = hashOf(txt(o, "Hash")), type = t, pos = xyz(kid(o, "Position")),
                    rot = r, dynamic = dyn, frozen = not dyn, visible = true,
                }
            end
        end
        return plan
    end

    function XS.PlanFromXML(s)
        local root = XS.ParseXML(s)
        if not root then return nil, "the file is empty" end
        if root.tag == "SpoonerPlacements" then return fromMenyooMap(root) end
        if root.tag == "Vehicle" then return fromMenyooVehicle(root) end
        if root.tag == "Map" then return fromMapEditor(root) end
        return nil, "unknown XML type <" .. root.tag .. ">"
    end

    -- JSON: reads lots of common spellings so most builds just work
    local function pick(t, ...)
        if type(t) ~= "table" then return nil end
        for _, k in ipairs({ ... }) do if t[k] ~= nil then return t[k] end end
        return nil
    end
    local function vec(v, a, b, c)
        if type(v) ~= "table" then return nil end
        local x = num(pick(v, a or "x", "X", "pitch", "Pitch", 1))
        local y = num(pick(v, b or "y", "Y", "roll", "Roll", 2))
        local z = num(pick(v, c or "z", "Z", "yaw", "Yaw", 3))
        if not (x and y and z) then return nil end
        return { x = x, y = y, z = z }
    end
    local JTYPES = { ped = 1, peds = 1, vehicle = 2, vehicles = 2, veh = 2, object = 3, objects = 3, prop = 3, props = 3 }
    local function jtype(v)
        if v == nil then return nil end
        if type(v) == "number" then return (v >= 1 and v <= 3) and v or nil end
        return JTYPES[tostring(v):lower()]
    end
    local function either(a, b) if a ~= nil then return a end return b end
    local function rgb(t)
        if type(t) ~= "table" then return nil end
        local r, g, b = num(pick(t, "r", "R", 1)), num(pick(t, "g", "G", 2)), num(pick(t, "b", "B", 3))
        if r and g and b then return { math.floor(r), math.floor(g), math.floor(b) } end
        return nil
    end
    local function tbl(v) return type(v) == "table" and v or {} end
    -- Stand Constructor's "vehicle_attributes": paint, neon, wheels, mods (-1 = stock), extras, options
    local function standVehicle(va)
        local v = { mods = {}, toggles = {}, extras = {}, neons = {} }
        local p = tbl(va.paint)
        local p1, p2, ec = tbl(p.primary), tbl(p.secondary), tbl(p.extra_colors)
        v.primary, v.secondary = num(p1.vehicle_standard_color), num(p2.vehicle_standard_color)
        if v.primary and not v.secondary then v.secondary = v.primary end
        if bool(p1.is_custom, false) then v.custom1 = rgb(p1.custom_color) end
        if bool(p2.is_custom, false) then v.custom2 = rgb(p2.custom_color) end
        v.pearl, v.rim = num(ec.pearlescent), num(ec.wheel)
        if v.pearl and not v.rim then v.rim = 0 end
        v.interior, v.dash, v.dirt = num(p.interior_color), num(p.dashboard_color), num(p.dirt_level)
        if type(p.livery) == "number" then v.livery = p.livery end
        if type(va.neon) == "table" then
            local l = tbl(va.neon.lights)
            v.neons = { bool(l.left, false), bool(l.right, false), bool(l.front, false), bool(l.back, false) }
            v.neonColour = rgb(va.neon.color)
        end
        local w = tbl(va.wheels)
        v.wheelType, v.smoke = num(w.wheel_type), rgb(w.tire_smoke_color)
        v.bpTyres = bool(either(w.bulletproof_tires, w.bullet_proof_tires), nil)
        v.drift = bool(w.drift_tires, nil)
        for k, val in pairs(tbl(va.mods)) do
            local slot = tonumber(tostring(k):match("^_?(%d+)$") or "")
            if slot then
                if type(val) == "boolean" then v.toggles[#v.toggles + 1] = { slot, val }
                elseif slot >= 17 and slot <= 22 and num(val) then v.toggles[#v.toggles + 1] = { slot, num(val) >= 0 }
                elseif num(val) then v.mods[#v.mods + 1] = { slot, math.floor(num(val)), false } end
            end
        end
        for k, on in pairs(tbl(va.extras)) do
            local id = tonumber(tostring(k):match("^_?(%d+)$") or "")
            if id and id > 0 then v.extras[#v.extras + 1] = { id, bool(on, false) } end
        end
        local o, hl = tbl(va.options), tbl(va.headlights)
        v.plate = o.license_plate_text and tostring(o.license_plate_text) or nil
        v.plateIndex, v.tint = num(o.license_plate_type), num(o.window_tint)
        v.engineOn = bool(o.engine_running, nil)
        local xc = num(hl.headlights_color)
        if xc and xc >= 0 then v.xenon = xc end
        if hl.headlights_type ~= nil then v.toggles[#v.toggles + 1] = { 22, bool(hl.headlights_type, false) } end
        return v
    end
    local function jsonItem(e, parentId, counter, impliedType, out)
        counter.n = counter.n + 1
        local id = "j" .. counter.n
        local o = type(e.options) == "table" and e.options or {}
        local it = {
            id = id,
            model = hashOf(pick(e, "hash", "Hash", "model_hash", "ModelHash")) or hashOf(pick(e, "model", "Model", "HashName")),
            name = pick(e, "name", "model", "Model", "HashName"),
            type = jtype(pick(e, "type", "Type", "entity_type")) or impliedType,
            pos = vec(pick(e, "position", "world_position", "Position", "pos", "coords", "coordinates"))
                or ((e.x and e.y and e.z) and { x = num(e.x), y = num(e.y), z = num(e.z) } or nil),
            rot = vec(pick(e, "rotation", "world_rotation", "Rotation", "rot"))
                or ((e.pitch or e.roll or e.yaw) and { x = num(e.pitch) or 0, y = num(e.roll) or 0, z = num(e.yaw) or 0 } or nil)
                or ((e.rx or e.ry or e.rz) and { x = num(e.rx) or 0, y = num(e.ry) or 0, z = num(e.rz) or 0 } or nil),
            visible = bool(either(pick(e, "visible", "is_visible", "IsVisible"), o.is_visible), true),
            frozen = bool(either(pick(e, "frozen", "is_frozen", "FrozenPos"), o.is_frozen), nil),
            dynamic = bool(pick(e, "dynamic", "Dynamic"), nil),
            invincible = bool(either(pick(e, "invincible", "is_invincible", "IsInvincible"), o.is_invincible), false),
            alpha = num(either(pick(e, "alpha", "opacity", "OpacityLevel"), o.alpha)),
            tint = num(either(pick(e, "tint", "texture_variation", "TextureVariation"), o.tint)),
            lod = num(either(pick(e, "lod_distance", "LodDistance"), o.lod_distance)),
        }
        local attached = either(pick(e, "is_attached", "attached"), o.is_attached)
        local off = vec(pick(e, "offset", "Offset", "attach_offset", "attachment_offset"))
        if parentId and attached ~= false then
            local col = either(pick(e, "has_collision", "collision"), o.has_collision)
            it.attach = {
                to = parentId,
                bone = num(either(pick(e, "bone_index", "bone", "BoneIndex"), o.bone_index)) or 0,
                off = off or { x = 0, y = 0, z = 0 },
                rot = vec(pick(e, "rotation", "Rotation", "rot")) or { x = 0, y = 0, z = 0 },
                collision = bool(col, false),
            }
        end
        if it.type == 2 and type(e.vehicle_attributes) == "table" then it.veh = standVehicle(e.vehicle_attributes) end
        -- (LGNFX's own extras - other menus just skip them: a locked part, and which bone by name)
        if o.lgn_locked == true then it.locked = true end
        if type(e.lgn_bone_name) == "string" and e.lgn_bone_name ~= "" then it.boneName = e.lgn_bone_name end
        if type(e.model) == "string" and e.model ~= "" and not e.model:match("^%s*0[xX]") and not e.model:match("^%s*%-?%d+%s*$") then
            it.modelName = e.model -- (the real model name, so an edited construct saves it back the same)
        end
        if it.model then out[#out + 1] = it end
        for _, c in ipairs(pick(e, "children", "Children", "attachments", "Attachments") or {}) do
            if type(c) == "table" then jsonItem(c, id, counter, nil, out) end
        end
        return it
    end

    -- CHERAX ENTITY files (Cherax's own vehicle saves, Cherax\Vehicles): type 1 = vehicle, 2 = ped,
    -- 3 = object; mods are stored one higher than the game's (0 = stock); attachments turn with a quaternion
    local CX_TYPES = { [1] = 2, [2] = 1, [3] = 3 }
    local CX_COMPS = { Head = 0, Beard = 1, Hair = 2, Torso = 3, Legs = 4, Hands = 5, Feet = 6, Teeth = 7,
                       Special = 8, ["Special 2"] = 9, Decal = 10, ["Tuxedo/Jacket Bib"] = 11 }
    local CX_PROPS = { Head = 0, Eyes = 1, Ears = 2, Mouth = 3, ["Left Hand"] = 4, ["Right Hand"] = 5,
                       ["Left Wrist"] = 6, ["Right Wrist"] = 7, Hip = 8 }
    -- a quaternion as the game's rotation (degrees, rotation order 2 - what attaching uses)
    function XS.QuatToRot(q)
        if type(q) ~= "table" then return nil end
        local x, y, z, w = num(q.x), num(q.y), num(q.z), num(q.w)
        if not (x and y and z and w) then return nil end
        local r01, r11 = 2 * (x * y - w * z), 1 - 2 * (x * x + z * z)
        local r20, r21, r22 = 2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)
        r21 = math.max(-1, math.min(1, r21))
        local deg = 180 / math.pi
        local atan2 = math.atan2 or math.atan
        return { x = math.asin(r21) * deg, y = atan2(-r20, r22) * deg, z = atan2(-r01, r11) * deg }
    end
    local function cheraxVehicle(e)
        local v = { mods = {}, toggles = {}, extras = {}, neons = {} }
        for k, m in pairs(tbl(e.mods)) do
            local slot = tonumber(tostring(k):match("^mod(%d+)$") or "")
            local idx = type(m) == "table" and num(m.index)
            if slot and idx then
                if slot >= 17 and slot <= 22 then
                    v.toggles[#v.toggles + 1] = { slot, idx > 0 }
                    if slot == 22 and idx >= 2 then v.xenon = math.floor(idx) - 2 end -- (xenon colour)
                else
                    v.mods[#v.mods + 1] = { slot, math.floor(idx) - 1, bool(m.variation, false) }
                end
            end
        end
        v.wheelType, v.smoke = num(e.wheelType), rgb(e.tyreSmokeColor)
        local nk = tbl(e.neonKits)
        v.neons = { bool(nk.left, false), bool(nk.right, false), bool(nk.front, false), bool(nk.back, false) }
        v.neonColour = rgb(nk.color)
        v.primary, v.secondary = num(e.primaryColor), num(e.secondaryColor)
        v.pearl, v.rim = num(e.pearlescentColor), num(e.wheelColor)
        if bool(e.isPrimaryColorCustom, false) then v.custom1 = rgb(e.customPrimaryColor) end
        if bool(e.isSecondaryColorCustom, false) then v.custom2 = rgb(e.customSecondaryColor) end
        v.tint, v.interior, v.dash = num(e.windowTint), num(e.interiorColor), num(e.dashBoardColor)
        v.plate = type(e.plateText) == "string" and e.plateText or nil
        v.plateIndex = num(e.plateTextIndex)
        for k, on in pairs(tbl(e.extras)) do
            local id = tonumber(tostring(k):match("^extra(%d+)$") or "")
            if id and id > 0 then v.extras[#v.extras + 1] = { id, bool(on, false) } end
        end
        v.bpTyres, v.drift = bool(e.bulletproofTyres, nil), bool(e.driftTyres, nil)
        return v
    end
    local function cheraxPed(e)
        local p = { comps = {}, props = {} }
        for name, c in pairs(tbl(e.components)) do
            local id = CX_COMPS[name]
            if id and type(c) == "table" then
                p.comps[#p.comps + 1] = { id, num(c.drawable) or 0, num(c.texture) or 0, num(c.palette) or 0 }
            end
        end
        for name, c in pairs(tbl(e.props)) do
            local id = CX_PROPS[name]
            local d = type(c) == "table" and num(c.drawable)
            if id and d and d >= 0 then p.props[#p.props + 1] = { id, d, math.max(0, num(c.texture) or 0) } end
        end
        return p
    end
    local function cheraxItem(e, parentId, att, counter, out)
        counter.n = counter.n + 1
        local id = "c" .. counter.n
        local it = { id = id, model = hashOf(e.model), type = CX_TYPES[num(e.type) or 3] or 3, visible = true }
        if it.type == 2 then it.veh = cheraxVehicle(e) elseif it.type == 1 then it.ped = cheraxPed(e) end
        if parentId and type(att) == "table" then
            it.attach = { to = parentId, bone = math.max(0, num(att.otherBone) or 0),
                off = vec(att.offset) or { x = 0, y = 0, z = 0 },
                rot = XS.QuatToRot(att.quat) or { x = 0, y = 0, z = 0 }, collision = false }
        end
        if it.model then out[#out + 1] = it end
        for _, a in ipairs(tbl(e.attachments)) do
            if type(a) == "table" and type(a.entity) == "table" then cheraxItem(a.entity, id, a.data, counter, out) end
        end
        return it
    end
    function XS.PlanFromCherax(data)
        local items, counter = {}, { n = 0 }
        local root = cheraxItem(data, nil, nil, counter, items)
        if not root.model then return nil, "no model in it" end
        return { kind = "vehicle", items = items, root = root.id }
    end

    function XS.PlanFromJSON(s)
        local ok, data = pcall(XS.ParseJSON, s)
        if not ok then return nil, tostring(data) end
        if type(data) ~= "table" then return nil, "nothing in the file" end
        if data.format == "Cherax Entity" then return XS.PlanFromCherax(data) end
        local items, counter = {}, { n = 0 }
        if data[1] ~= nil then
            for _, e in ipairs(data) do if type(e) == "table" then jsonItem(e, nil, counter, nil, items) end end
            return { kind = "map", items = items }
        end
        -- lists inside a wrapper: { "objects": [...], "vehicles": [...], ... }
        local found = false
        for key, t in pairs({ objects = 3, props = 3, vehicles = 2, peds = 1, placements = false, entities = false,
                              items = false, Objects = 3, Vehicles = 2, Peds = 1, Placements = false }) do
            if type(data[key]) == "table" and data[key][1] ~= nil then
                found = true
                for _, e in ipairs(data[key]) do
                    if type(e) == "table" then jsonItem(e, nil, counter, t or nil, items) end
                end
            end
        end
        if found then
            return { kind = "map", items = items, ref = vec(pick(data, "reference", "reference_coords", "ReferenceCoords")) }
        end
        -- one build (model + children), e.g. Constructor files
        if pick(data, "model", "hash", "Model", "ModelHash") then
            local root = jsonItem(data, nil, counter, nil, items)
            local isVeh = root.type == 2
            local plan = { kind = (isVeh or not root.pos) and "vehicle" or "map", items = items, root = root.id }
            if plan.kind == "vehicle" then root.pos = nil end
            return plan
        end
        return nil, "didn't find anything to spawn in it"
    end

    -- ----- spawning -----
    local N = {
        PLAYER_PED_ID                   = 0xD80958FC74E988A6,
        GET_ENTITY_HEADING              = 0xE83D4F9BA2A38914,
        REQUEST_MODEL                   = 0x963D27A58DF860AC,
        HAS_MODEL_LOADED                = 0x98A4EB5D89A0C952,
        IS_MODEL_VALID                  = 0xC0296A2EDF545E92,
        IS_MODEL_IN_CDIMAGE             = 0x35B9E0803292B641,
        IS_MODEL_A_VEHICLE              = 0x19AAC8F07BFEC53E,
        IS_MODEL_A_PED                  = 0x75816577FEA6DAD5,
        SET_MODEL_AS_NO_LONGER_NEEDED   = 0xE532F5D78798DAAB,
        DOES_ENTITY_EXIST               = 0x7239B21A38F536BA,
        SET_ENTITY_AS_MISSION_ENTITY    = 0xAD738C3085FE7E11,
        DELETE_ENTITY                   = 0xAE3CBE5BF394C9C9,
        SET_ENTITY_COORDS               = 0x06843DA7060A026B,
        SET_ENTITY_COORDS_NO_OFFSET     = 0x239A3351AC1DA385,
        SET_ENTITY_ROTATION             = 0x8524A8B0171D5E07,
        SET_ENTITY_HEADING              = 0x8E2530AA8ADA980E,
        FREEZE_ENTITY_POSITION          = 0x428CA6DBD1094446,
        SET_ENTITY_ALPHA                = 0x44A0870B7E92D7C0,
        SET_ENTITY_LOD_DIST             = 0x5927F96A78577363,
        SET_ENTITY_INVINCIBLE           = 0x3882114BDE571AD4,
        SET_ENTITY_PROOFS               = 0xFAEE099C6F890BB8,
        SET_ENTITY_HAS_GRAVITY          = 0x4A4722448F18EEF5,
        SET_OBJECT_TEXTURE_VARIATION    = 0x971DA0055324D033,
        ATTACH_ENTITY_TO_ENTITY         = 0x6B9BBD38AB0796DF,
        SET_BLOCKING_OF_NON_TEMPORARY_EVENTS = 0x9F8AA94D6D97DBF4,
        SET_PED_INTO_VEHICLE            = 0xF75B0D629E1C063D,
        SET_PED_COORDS_KEEP_VEHICLE     = 0x9AFEFF481A85AB2E,
        SET_VEHICLE_ON_GROUND_PROPERLY  = 0x49733E92263139D1,
        SET_VEHICLE_MOD_KIT             = 0x1F2AA07F00B3217A,
        SET_VEHICLE_MOD                 = 0x6AF0636DDEDCB6DD,
        TOGGLE_VEHICLE_MOD              = 0x2A1F4F37F95BAD08,
        SET_VEHICLE_WHEEL_TYPE          = 0x487EB21CC7295BA1,
        SET_VEHICLE_COLOURS             = 0x4F1D4BE3A7F24601,
        SET_VEHICLE_EXTRA_COLOURS       = 0x2036F561ADD12E33,
        SET_VEHICLE_CUSTOM_PRIMARY_COLOUR   = 0x7141766F91D15BEA,
        SET_VEHICLE_CUSTOM_SECONDARY_COLOUR = 0x36CED73BFED89754,
        SET_VEHICLE_TYRE_SMOKE_COLOR    = 0xB5BA80F839791C0F,
        SET_VEHICLE_NUMBER_PLATE_TEXT   = 0x95A88F0B409CDA47,
        SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX = 0x9088EB5A43FFB0A1,
        SET_VEHICLE_WINDOW_TINT         = 0x57C51E6BAD752696,
        SET_VEHICLE_LIVERY              = 0x60BF608F1B8CD1B6,
        SET_VEHICLE_NEON_LIGHT_ENABLED  = 0x2AA720E4287BF269,
        SET_VEHICLE_NEON_LIGHTS_COLOUR  = 0x8E0A582209A62695,
        SET_VEHICLE_EXTRA               = 0x7EE3A3C5E4A40CC9,
        SET_VEHICLE_TYRES_CAN_BURST     = 0xEB9DC3C7D8596C46,
        SET_VEHICLE_ENGINE_ON           = 0x2497C4717C8B881E,
        SET_VEHICLE_DIRT_LEVEL          = 0x79D3B596FE44EE8B,
        REQUEST_IPL                     = 0x41B4893843BBDB74,
    }
    local function nv(...) pcall(Natives.InvokeVoid, ...) end
    local function Me()
        local ok, h = pcall(Natives.InvokeInt, N.PLAYER_PED_ID)
        if ok and h and h ~= 0 then return h end
        return nil
    end

    -- The LGNFX folder can be next to LGNFX.lua or in <Cherax>\Lua (like the intro
    -- and sounds), so look in both places.
    local function Bases()
        local out, seen = {}, {}
        local function add(b)
            if b and not seen[b:lower()] then seen[b:lower()] = true out[#out + 1] = b end
        end
        pcall(function()
            local info = debug.getinfo(1, "S")
            local src = info and info.source or ""
            if src:sub(1, 1) == "@" then
                local dir = src:sub(2):gsub("/", "\\"):match("^(.*)\\[^\\]+$")
                if dir then add(dir .. "\\CE\\data") end
            end
        end)
        pcall(function() add(LuaDir() .. "\\CE\\data") end)
        return out
    end
    local function Exists(p)
        local ok, r = pcall(FileMgr.DoesFileExist, p)
        return ok and r == true
    end
    -- where new files should go: the LGNFX folder that's really there (next to the script first)
    local function MainBase()
        local b = Bases()
        for _, base in ipairs(b) do if Exists(base) then return base end end
        return b[1] or (LuaDir() .. "\\CE\\data")
    end
    local function Dir(kind)
        local base = MainBase()
        pcall(FileMgr.CreateDir, base)
        local d = base .. "\\" .. kind
        pcall(FileMgr.CreateDir, d)
        return d
    end

    -- what's in the folders: { label, path, kind }
    -- FindFiles gives back a game-side list (not a plain Lua table), so copy it into one
    local function ToList(found)
        local out = {}
        if found == nil then return out end
        if type(found) == "table" then
            for _, p in pairs(found) do out[#out + 1] = tostring(p) end
            return out
        end
        local ok = pcall(function() for _, p in pairs(found) do out[#out + 1] = tostring(p) end end)
        if not ok or #out == 0 then
            out = {}
            pcall(function()
                local n = #found
                for i = 1, n do out[#out + 1] = tostring(found[i]) end
            end)
        end
        return out
    end
    -- FAVOURITES & RECENT (shared with the Constructor tab): "* Favourites" and "* Recent" folders at
    -- the top of the Folder list. Kept in configs\spawn_file_favourites.txt (shared by every config)
    local Favs = { fav = {}, recent = {}, changed = 0 }
    local function FavKey(p) return (tostring(p or ""):lower():gsub("/", "\\")) end
    function Favs.Path() return CfgDir() .. "\\spawn_file_favourites.txt" end
    function Favs.Save()
        local lines = {}
        for _, p in pairs(Favs.fav) do lines[#lines + 1] = "fav|" .. p end
        table.sort(lines)
        for _, p in ipairs(Favs.recent) do lines[#lines + 1] = "recent|" .. p end
        pcall(FileMgr.WriteFileContent, Favs.Path(), table.concat(lines, "\n") .. "\n", false)
    end
    function Favs.IsFav(p) return Favs.fav[FavKey(p)] ~= nil end
    function Favs.Toggle(p)
        local k = FavKey(p)
        if Favs.fav[k] then Favs.fav[k] = nil else Favs.fav[k] = p end
        Favs.changed = Favs.changed + 1
        Favs.Save()
        return Favs.fav[k] ~= nil
    end
    function Favs.RecentIndex(p)
        local k = FavKey(p)
        for i, r in ipairs(Favs.recent) do if FavKey(r) == k then return i end end
        return nil
    end
    -- (the last 10 things you spawned from files, newest first)
    function Favs.Touch(p)
        local i = Favs.RecentIndex(p)
        if i then table.remove(Favs.recent, i) end
        table.insert(Favs.recent, 1, p)
        while #Favs.recent > 10 do table.remove(Favs.recent) end
        Favs.changed = Favs.changed + 1
        Favs.Save()
    end
    -- the files of a list that go in the * Favourites / * Recent folder
    function Favs.Virtual(d, list)
        local out = {}
        if d.fav then
            for _, f in ipairs(list) do if Favs.IsFav(f.path) then out[#out + 1] = f end end
        elseif d.recent then
            for _, f in ipairs(list) do if Favs.RecentIndex(f.path) then out[#out + 1] = f end end
            table.sort(out, function(a, b) return Favs.RecentIndex(a.path) < Favs.RecentIndex(b.path) end)
        end
        return out
    end
    pcall(function()
        local txt = FileMgr.DoesFileExist(Favs.Path()) and FileMgr.ReadFileContent(Favs.Path()) or ""
        for line in txt:gmatch("[^\r\n]+") do
            local kind, v = line:match("^(%a+)|(.+)$")
            if kind == "fav" then Favs.fav[FavKey(v)] = v
            elseif kind == "recent" and #Favs.recent < 10 then Favs.recent[#Favs.recent + 1] = v end
        end
    end)
    -- models: check, load (once per file) and release afterwards
    local function LoadModel(hash, cache)
        if cache[hash] ~= nil then return cache[hash] end
        local good = IB(N.IS_MODEL_IN_CDIMAGE, hash) and IB(N.IS_MODEL_VALID, hash)
        if good then
            Natives.InvokeVoid(N.REQUEST_MODEL, hash)
            local t0 = NowMs()
            while not IB(N.HAS_MODEL_LOADED, hash) and NowMs() - t0 < 4000 do
                Script.Yield(20)
                Natives.InvokeVoid(N.REQUEST_MODEL, hash)
            end
            good = IB(N.HAS_MODEL_LOADED, hash)
        end
        cache[hash] = good
        return good
    end

    local function TypeOf(it)
        if it.type == 1 or it.type == 2 or it.type == 3 then return it.type end
        if IB(N.IS_MODEL_A_VEHICLE, it.model) then return 2 end
        if IB(N.IS_MODEL_A_PED, it.model) then return 1 end
        return 3
    end

    local function ApplyVehicle(h, v)
        nv(N.SET_VEHICLE_MOD_KIT, h, 0)
        if v.wheelType and v.wheelType >= 0 then nv(N.SET_VEHICLE_WHEEL_TYPE, h, v.wheelType) end
        -- (only parts this car really has: a part number past the end is an "impossible" car - other players'
        -- games refuse to make it, so you were invisible to them in it)
        local skipped = {}
        for _, m in ipairs(v.mods) do
            if m[2] >= 0 then
                local okN, n = pcall(Natives.InvokeInt, 0xE38E9162A2500646, h, m[1]) -- GET_NUM_VEHICLE_MODS
                if okN and type(n) == "number" and m[2] < n then nv(N.SET_VEHICLE_MOD, h, m[1], m[2], m[3])
                else skipped[#skipped + 1] = ("%d:%d/%s"):format(m[1], m[2], tostring(okN and n or "?")) end
            end
        end
        if #skipped > 0 then
            pcall(Dump.Info, ("[CE] saved car: left out %d part(s) this car doesn't have (slot:part/how many): %s"):format(#skipped, table.concat(skipped, " ")))
        end
        for _, t in ipairs(v.toggles) do nv(N.TOGGLE_VEHICLE_MOD, h, t[1], t[2]) end
        if v.xenon then nv(0xE41033B25D003A07, h, v.xenon) end -- SET_VEHICLE_XENON_LIGHT_COLOR_INDEX
        if v.primary and v.secondary then nv(N.SET_VEHICLE_COLOURS, h, v.primary, v.secondary) end
        if v.pearl and v.rim then nv(N.SET_VEHICLE_EXTRA_COLOURS, h, v.pearl, v.rim) end
        if v.interior then nv(0xF40DD601A65F7F19, h, v.interior) end -- SET_VEHICLE_EXTRA_COLOUR_5 (interior)
        if v.dash then nv(0x6089CDF6A57F326C, h, v.dash) end -- SET_VEHICLE_EXTRA_COLOUR_6 (dashboard)
        if v.custom1 then nv(N.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR, h, v.custom1[1], v.custom1[2], v.custom1[3]) end
        if v.custom2 then nv(N.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR, h, v.custom2[1], v.custom2[2], v.custom2[3]) end
        if v.smoke then nv(N.SET_VEHICLE_TYRE_SMOKE_COLOR, h, v.smoke[1], v.smoke[2], v.smoke[3]) end
        if v.livery and v.livery >= 0 then nv(N.SET_VEHICLE_LIVERY, h, v.livery) end
        if v.plate and v.plate ~= "" then nv(N.SET_VEHICLE_NUMBER_PLATE_TEXT, h, v.plate) end
        if v.plateIndex and v.plateIndex >= 0 then nv(N.SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX, h, v.plateIndex) end
        if v.tint and v.tint >= 0 then nv(N.SET_VEHICLE_WINDOW_TINT, h, v.tint) end
        for i, on in ipairs(v.neons or {}) do nv(N.SET_VEHICLE_NEON_LIGHT_ENABLED, h, i - 1, on) end
        if v.neonColour then nv(N.SET_VEHICLE_NEON_LIGHTS_COLOUR, h, v.neonColour[1], v.neonColour[2], v.neonColour[3]) end
        for _, e in ipairs(v.extras) do
            if Natives.InvokeBool(0x1262D55792428154, h, e[1]) then nv(N.SET_VEHICLE_EXTRA, h, e[1], not e[2]) end -- DOES_EXTRA_EXIST (the game's flag means "turn off")
        end
        if v.bpTyres ~= nil then nv(N.SET_VEHICLE_TYRES_CAN_BURST, h, not v.bpTyres) end
        if v.drift ~= nil then nv(0x5AC79C98C5C17F05, h, v.drift) end -- SET_DRIFT_TYRES
        if v.dirt then nv(N.SET_VEHICLE_DIRT_LEVEL, h, v.dirt + 0.0) end
        if v.engineOn then nv(N.SET_VEHICLE_ENGINE_ON, h, true, true, false) end
    end

    local function ApplyLook(h, it, kind)
        if it.visible == false then LGX.KeepHidden(h) end -- (kept hidden: Cherax's spawner fade used to show it again)
        if it.alpha and it.alpha < 255 then nv(N.SET_ENTITY_ALPHA, h, math.floor(it.alpha), false) end
        if it.lod and it.lod > 0 then nv(N.SET_ENTITY_LOD_DIST, h, math.floor(math.min(it.lod, 65535))) end
        if it.invincible then nv(N.SET_ENTITY_INVINCIBLE, h, true) end
        local p = it.proofs
        if p and (p[1] or p[2] or p[3] or p[4] or p[5]) then
            nv(N.SET_ENTITY_PROOFS, h, p[1], p[2], p[3], p[4], p[5], false, false, false)
        end
        if it.gravity == false then nv(N.SET_ENTITY_HAS_GRAVITY, h, false) end
        if kind == 3 and it.tint and it.tint > 0 then nv(N.SET_OBJECT_TEXTURE_VARIATION, h, math.floor(it.tint)) end
        if kind == 1 then nv(N.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS, h, true) end
        if kind == 1 and it.ped then
            for _, c in ipairs(it.ped.comps) do nv(0x262B14F48D29DE80, h, c[1], c[2], c[3], c[4]) end -- SET_PED_COMPONENT_VARIATION
            for _, pr in ipairs(it.ped.props) do nv(0x93376B65A266EB5F, h, pr[1], pr[2], pr[3], true) end -- SET_PED_PROP_INDEX
        end
        if kind == 2 and it.veh then ApplyVehicle(h, it.veh) end
    end

    local function Create(it, kind, p, heading)
        local ok, h
        if kind == 2 then
            ok, h = pcall(LGX.SpawnVehicle, it.model, p.x, p.y, p.z, heading + 0.0, true, false)
        elseif kind == 1 then
            ok, h = pcall(LGX.CreatePed, it.model, 4, p.x, p.y, p.z, heading + 0.0, true, false)
        else
            ok, h = pcall(LGX.CreateObject, it.model, p.x, p.y, p.z, it.dynamic == true, true)
            if not ok or not h or h == 0 then -- some props need Cherax's world-object spawner
                ok, h = pcall(LGX.CreateWorldObject, it.model, p.x, p.y, p.z, it.dynamic == true, true)
            end
        end
        if ok and h and h ~= 0 then return h end
        return nil
    end

    local loaded = {} -- { { name, handles } } one per spawned file, newest last

    local function Remove(h)
        if not h or not IB(N.DOES_ENTITY_EXIST, h) then return end
        -- (LGNFX's delete: takes it back from another player's game first and keeps trying, so nothing's left behind)
        if F.LX and F.LX.Delete then pcall(F.LX.Delete, h) return end
        pcall(function()
            Natives.InvokeVoid(N.SET_ENTITY_AS_MISSION_ENTITY, h, true, true)
            local p = Memory.AllocInt()
            Memory.WriteInt(p, h)
            Natives.InvokeVoid(N.DELETE_ENTITY, p)
            Memory.Free(p)
        end)
        if IB(N.DOES_ENTITY_EXIST, h) then -- couldn't delete it: move it far away
            nv(N.SET_ENTITY_COORDS, h, 0.0, 0.0, -200.0, false, false, false, false)
        end
    end

    local function SpawnPlan(plan, name)
        local me = Me()
        if not me then return end
        -- (keepPlace: Bring Them Back - everything goes exactly where it was, you stay where you are)
        local here = plan.at ~= nil or (not plan.keepPlace and (F.xsHere:IsToggled() or plan.kind == "vehicle"))
        local byId, made, skipped, badModels = {}, {}, 0, {}
        local frozenH = {}
        local cache = {}

        -- where things go
        local myPos = EntityPos(me)
        local heading = Natives.InvokeFloat(N.GET_ENTITY_HEADING, me) or 0.0
        local rad = math.rad(heading)
        local front = myPos and { x = myPos.x - math.sin(rad) * 6.0, y = myPos.y + math.cos(rad) * 6.0, z = myPos.z } or nil
        -- (plan.at: exactly where and which way it goes - Garage Showcase lines cars up with it)
        if plan.at then front, heading = { x = plan.at.x, y = plan.at.y, z = plan.at.z }, plan.at.h or heading end
        local anchor = plan.ref
        if not anchor then
            for _, it in ipairs(plan.items) do if it.pos and not it.attach then anchor = it.pos break end end
        end
        local delta = { x = 0, y = 0, z = 0 }
        if here and front and anchor then
            delta = { x = front.x - anchor.x, y = front.y - anchor.y, z = front.z - anchor.z }
        end

        -- maps far away: go there first so the area is loaded when things appear
        -- (you're held in place until it's built, so you don't fall off sky maps)
        local held = false
        if not here and not plan.keepPlace and F.xsTp:IsToggled() and anchor then
            nv(N.SET_PED_COORDS_KEEP_VEHICLE, me, anchor.x + 0.0, anchor.y + 0.0, anchor.z + 1.0)
            nv(N.FREEZE_ENTITY_POSITION, me, true)
            held = true
            Script.Yield(600)
        end
        for _, ipl in ipairs(plan.ipls or {}) do nv(N.REQUEST_IPL, ipl) end

        Notify("Spawning " .. name .. " (" .. #plan.items .. " things)...", true, "mapSpawn")
        -- 1) spawn everything
        for i, it in ipairs(plan.items) do
            if not it.model or not LoadModel(it.model, cache) then
                skipped = skipped + 1
                if it.model then badModels[#badModels + 1] = it.name or string.format("0x%08X", it.model) end
            else
                local kind = TypeOf(it)
                local p
                if it.pos and not it.attach then
                    p = { x = it.pos.x + delta.x, y = it.pos.y + delta.y, z = it.pos.z + delta.z }
                else
                    p = front or myPos -- attached things snap onto their parent in step 2
                end
                local h = p and Create(it, kind, p, it.rot and it.rot.z or heading)
                if h then
                    made[#made + 1] = h
                    LGX.Networked(h) -- (so other players see it too, not just the base car)
                    if it.id then byId[tostring(it.id)] = h end
                    if it.pos and not it.attach then
                        nv(N.SET_ENTITY_COORDS_NO_OFFSET, h, p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false)
                        local r = it.rot or { x = 0, y = 0, z = 0 }
                        nv(N.SET_ENTITY_ROTATION, h, r.x + 0.0, r.y + 0.0, r.z + 0.0, 2, true)
                    elseif not it.attach then
                        -- the base of a build spawned in front of you
                        nv(N.SET_ENTITY_HEADING, h, heading + 0.0)
                        if kind == 2 then nv(N.SET_VEHICLE_ON_GROUND_PROPERLY, h) end
                    end
                    ApplyLook(h, it, kind)
                    if it.frozen and not it.attach then nv(N.FREEZE_ENTITY_POSITION, h, true) frozenH[h] = true end
                    it._h, it._kind = h, kind
                else
                    skipped = skipped + 1
                end
            end
            if i % 8 == 0 then Script.Yield(0) end
        end

        -- 2) attach things to what they belong to
        for _, it in ipairs(plan.items) do
            local a = it.attach
            if a and it._h then
                local parent
                if a.to and tostring(a.to):upper() == "PLAYER" then parent = me else parent = byId[tostring(a.to)] end
                if parent and parent ~= it._h then
                    nv(N.ATTACH_ENTITY_TO_ENTITY, it._h, parent, math.floor(a.bone or 0),
                        a.off.x + 0.0, a.off.y + 0.0, a.off.z + 0.0, a.rot.x + 0.0, a.rot.y + 0.0, a.rot.z + 0.0,
                        false, false, a.collision == true, it._kind == 1, 2, true)
                end
            end
        end

        if held then nv(N.FREEZE_ENTITY_POSITION, me, false) end

        -- 2b) online: make sure every part really is shared. The network takes new things a moment
        -- after they're made - anything it didn't take the first time is asked again. GTA only lets
        -- each player share a limited number of spawned things, so on big maps some may stay on your
        -- screen only - the message says how many.
        local online = IB(0x9DE624D2FC4B603F) -- NETWORK_IS_SESSION_STARTED
        local unshared = 0
        if online and #made > 0 then
            Script.Yield(250)
            for i, h in ipairs(made) do
                if IB(N.DOES_ENTITY_EXIST, h) and (Natives.InvokeInt(0xA11700682F3AD45C, h) or 0) == 0 then -- NETWORK_GET_NETWORK_ID_FROM_ENTITY
                    LGX.Networked(h)
                    if (Natives.InvokeInt(0xA11700682F3AD45C, h) or 0) == 0 then unshared = unshared + 1 end
                end
                if i % 20 == 0 then Script.Yield(0) end
            end
            if unshared > 0 then
                pcall(Dump.Info, ("[CE] spawn: %d of %d thing(s) in %s couldn't be shared (GTA's limit on shared spawned things)")
                    :format(unshared, #made, tostring(name)))
            end
        end

        -- 3) vehicle builds: hop in
        if plan.kind == "vehicle" and F.xsInto:IsToggled() and not plan.keepPlace and not plan.at then
            for _, it in ipairs(plan.items) do
                if it.id and tostring(it.id) == tostring(plan.root) and it._h and it._kind == 2 then
                    nv(N.SET_PED_INTO_VEHICLE, me, it._h, -1)
                end
            end
        end
        for hash, good in pairs(cache) do if good then nv(N.SET_MODEL_AS_NO_LONGER_NEEDED, hash) end end

        -- (remembered with its base and the parts stuck straight onto it, so the Constructor tab can
        -- list it, put you in it and edit where each part sits)
        local entry = nil
        if #made > 0 then
            entry = { name = name, handles = made, kind = plan.kind, parts = {}, frozenH = frozenH }
            for _, it in ipairs(plan.items) do
                if it._h and plan.root and tostring(it.id) == tostring(plan.root) then
                    entry.root = it._h
                    if it._kind ~= 2 and it.frozen then entry.kind, entry.frozen = "map", true end
                end
            end
            -- parts on the base, and parts stuck on those parts (any depth) - all editable in the Constructor
            local partOf, done = {}, {}
            for _ = 1, 8 do
                local added = false
                for _, it in ipairs(plan.items) do
                    local a = it.attach
                    local ph = a and byId[tostring(a.to)]
                    if it._h and a and entry.root and not done[it] and (ph == entry.root or partOf[ph]) then
                        local pt = { h = it._h, model = it.model, name = it.name, modelName = it.modelName, kind = it._kind,
                            vis = it.visible ~= false, alpha = it.alpha or 255, tint = it.tint, parent = partOf[ph], locked = it.locked,
                            boneName = (ph == entry.root) and it.boneName or nil,
                            bone = math.floor(a.bone or 0), col = a.collision == true,
                            off = { x = a.off.x, y = a.off.y, z = a.off.z }, rot = { x = a.rot.x, y = a.rot.y, z = a.rot.z } }
                        entry.parts[#entry.parts + 1] = pt
                        partOf[it._h], done[it], added = pt, true, true
                    end
                end
                if not added then break end
            end
            entry.extra = math.max(0, #made - #entry.parts - (entry.root and 1 or 0)) -- (things standing on their own)
            loaded[#loaded + 1] = entry
        end
        local msg = "Spawned " .. name .. ": " .. #made .. " thing(s)"
        if unshared > 0 then msg = msg .. " - " .. unshared .. " only on your screen (the lobby's limit on shared things)" end
        if skipped > 0 then
            msg = msg .. ", " .. skipped .. " skipped"
            if #badModels > 0 then
                msg = msg .. " (not in your game: " .. table.concat(badModels, ", ", 1, math.min(3, #badModels))
                    .. (#badModels > 3 and ", ..." or "") .. ")"
            end
        end
        Notify(msg, true, "mapSpawn")
        return entry
    end

    -- a spawned construct / file as it is right now, as a plan that puts it back in the same place
    -- (Bring Them Back): parts on the base keep their exact spot and bone, anything else stuck on
    -- something keeps where it sits on it
    local function EntryPlan(e)
        if not (F.BB and e and e.handles) then return nil end
        local idOf, partOf, items = {}, {}, {}
        for i, h in ipairs(e.handles) do if IB(N.DOES_ENTITY_EXIST, h) then idOf[h] = i end end
        for _, pt in ipairs(e.parts or {}) do partOf[pt.h] = pt end
        for i, h in ipairs(e.handles) do
            local r = idOf[h] and F.BB.Snap(h)
            if r then
                local pt = partOf[h]
                local it = { id = tostring(i), model = r.model, type = r.kind, visible = r.vis, alpha = r.alpha, veh = r.veh,
                             name = pt and pt.name, modelName = pt and pt.modelName,
                             frozen = (e.frozenH and e.frozenH[h]) or (h == e.root and e.frozen) or (e.kind == "map" and r.kind == 3) }
                local parent = Natives.InvokeInt(0x48C2BED9180FE123, h) or 0 -- GET_ENTITY_ATTACHED_TO
                local holder = pt and ((pt.parent and idOf[pt.parent.h or 0]) or (not pt.parent and e.root and idOf[e.root]))
                if holder then
                    it.locked, it.boneName = pt.locked, pt.boneName
                    it.attach = { to = tostring(holder), bone = pt.bone or 0, collision = pt.col == true,
                                  off = { x = pt.off.x, y = pt.off.y, z = pt.off.z }, rot = { x = pt.rot.x, y = pt.rot.y, z = pt.rot.z } }
                elseif parent ~= 0 and idOf[parent] then
                    local o = F.BB.V3(0x2274BC1C4885E333, parent, r.pos.x, r.pos.y, r.pos.z) or { x = 0, y = 0, z = 0 }
                    local pr = F.BB.V3(0xAFBD61CC738D9EB9, parent, 2) or { x = 0, y = 0, z = 0 }
                    it.attach = { to = tostring(idOf[parent]), bone = 0, collision = false, off = o,
                                  rot = { x = r.rot.x - pr.x, y = r.rot.y - pr.y, z = r.rot.z - pr.z } }
                else
                    it.pos, it.rot = r.pos, r.rot
                end
                items[#items + 1] = it
            end
            if i % 20 == 0 then Script.Yield(0) end
        end
        if #items == 0 then return nil end
        return { items = items, root = e.root and idOf[e.root] and tostring(idOf[e.root]) or nil, kind = e.kind,
                 keepPlace = true, name = e.name }
    end
    local function OfferBack(plans, label)
        if #plans == 0 or not F.BB then return false end
        F.BB.Offer(label, function() for _, pl in ipairs(plans) do SpawnPlan(pl, pl.name) end end)
        return true
    end

    -- ----- menu -----
    F.xsHere = Toggle(H.xsHere, "Spawn In Front Of Me",
        "Maps are built where they were made. Turn this on to build them in front of you instead. " ..
        "(Vehicles always appear in front of you.)", false)
    F.xsTp = Toggle(H.xsTp, "Teleport To Maps", "Takes you to a map when you spawn it", true)
    F.xsInto = Toggle(H.xsInto, "Get In Vehicles", "Puts you in the driver's seat of spawned vehicle builds", true)
    F.xsDelAll = Button(H.xsDelAll, "Delete All Spawned Constructs", "Removes every construct you've spawned",
        function() Job("deleting files", function()
            local n = 0
            local plans = {}
            for _, l in ipairs(loaded) do plans[#plans + 1] = EntryPlan(l) end
            for _, l in ipairs(loaded) do
                for _, h in ipairs(l.handles) do
                    Remove(h)
                    n = n + 1
                    if n % 10 == 0 then Script.Yield(0) end
                end
            end
            loaded = {}
            if not OfferBack(plans, n .. " thing(s) spawned from files / constructs") then
                Notify("Deleted " .. n .. " thing(s) you spawned", true, "mapSpawn")
            end
        end) end)
    F.xsTest = XS -- lets the parsers be tested on their own
    -- (shared with the Constructor tab: same readers, same spawning, same "spawned from files" list)
    F.xsApi = { XS = XS, SpawnPlan = SpawnPlan, Remove = Remove, ToList = ToList, Exists = Exists,
        MainBase = MainBase, Dir = Dir, Loaded = function() return loaded end, Favs = Favs, EntryPlan = EntryPlan,
        OfferBack = OfferBack }
end)

Try("creating spawn previews", function()
    local function nv(...) pcall(Natives.InvokeVoid, ...) end
    F.previewOn = Toggle(H.previewOn, "3D Spawn Previews",
        "While a spawner is on screen, a see-through copy of what's picked turns slowly in front of you, so you can see it " ..
        "before you spawn it. Only you see it - it's gone when the menu closes", true)
    local G = { want = nil, wantAt = 0, model = nil, h = nil, loading = nil, spin = 0 }
    local function Hash(m)
        if type(m) == "number" then return m % 4294967296 end
        if type(m) ~= "string" or m == "" then return nil end
        return (tonumber(m) or Utils.Joaat(m)) % 4294967296
    end
    F.WantGhost = function(model)
        if not F.previewOn:IsToggled() then return end
        local h = Hash(model)
        if not h then return end
        G.want, G.wantAt = h, NowMs()
    end
    local function Kill()
        if G.h then
            local h = G.h
            G.h = nil
            pcall(function()
                nv(0xAD738C3085FE7E11, h, true, true)
                local p = Memory.AllocInt() Memory.WriteInt(p, h)
                Natives.InvokeVoid(0xAE3CBE5BF394C9C9, p) -- DELETE_ENTITY
                Memory.Free(p)
            end)
            LGX.spawned[h] = nil
        end
        if G.model then nv(0xE532F5D78798DAAB, G.model) end -- SET_MODEL_AS_NO_LONGER_NEEDED
        G.model, G.loading = nil, nil
    end
    F.unloadHooks = F.unloadHooks or {}
    table.insert(F.unloadHooks, function() pcall(Kill) end)
    local function V3(ok, a, b, c)
        if not ok or a == nil then return nil end
        if type(a) == "table" or type(a) == "userdata" then
            local okT, x, y, z = pcall(function() return a.x, a.y, a.z end)
            if okT and x then return { x = x, y = y, z = z } end
            return nil
        end
        return { x = a, y = b, z = c }
    end
    F.ghostTick = function()
        local now = NowMs()
        local open = (function() local ok, o = pcall(GUI.IsOpen) return ok and o == true end)()
        local want = F.previewOn:IsToggled() and open and G.want and now - G.wantAt < 350 and G.want or nil
        if G.h and not IB(0x7239B21A38F536BA, G.h) then G.h = nil end -- (removed by something else: made again)
        if want ~= G.model then Kill() end
        if not want then return end
        if not G.model then
            if not IB(0xC0296A2EDF545E92, want) then return end -- IS_MODEL_VALID
            G.model, G.loading = want, now
        end
        if not G.h then
            nv(0x963D27A58DF860AC, want) -- REQUEST_MODEL
            if not IB(0x98A4EB5D89A0C952, want) then return end -- HAS_MODEL_LOADED (tried again next frame)
            local me = Natives.InvokeInt(0xD80958FC74E988A6)
            local p = EntityPos(me)
            if not p then return end
            local ok, h
            if IB(0x19AAC8F07BFEC53E, want) then ok, h = pcall(LGX.SpawnVehicle, want, p.x, p.y, p.z + 50.0, 0.0, false, false)
            elseif IB(0x75816577FEA6DAD5, want) then ok, h = pcall(LGX.CreatePed, want, 4, p.x, p.y, p.z + 50.0, 0.0, false, false)
            else ok, h = pcall(LGX.CreateObject, want, p.x, p.y, p.z + 50.0, false, false) end
            if not ok or not h or h == 0 then G.want = nil return end
            G.h = h
            nv(0xEA1C610A04DB6BBB, h, true, false)          -- SET_ENTITY_VISIBLE
            nv(0x44A0870B7E92D7C0, h, 170, false)           -- SET_ENTITY_ALPHA (see-through)
            nv(0x1A9205C1B9EE827F, h, false, false)         -- SET_ENTITY_COLLISION
            nv(0x428CA6DBD1094446, h, true)                 -- FREEZE_ENTITY_POSITION
            nv(0x3882114BDE571AD4, h, true)                 -- SET_ENTITY_INVINCIBLE
            local okD, a, b, c, d, e, f = pcall(F.LX.Dims, want)
            G.size = (okD and a) and math.max(d - a, e - b, f - c) or 2.0
        end
        -- in front of the camera, a bit to the side so the menu doesn't cover it, turning slowly
        local cp = V3(pcall(Natives.InvokeV3, 0x14D6F5678D8F1B37)) -- GET_GAMEPLAY_CAM_COORD
        local cr = V3(pcall(Natives.InvokeV3, 0x837765A25378F0BB, 2)) -- GET_GAMEPLAY_CAM_ROT
        if not cp or not cr then return end
        local yaw, pitch = math.rad(cr.z), math.rad(cr.x)
        local dist = math.max(3.0, math.min(40.0, (G.size or 2.0) * 1.8 + 1.5))
        local fx, fy, fz = -math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch)
        local rx, ry = math.cos(yaw), math.sin(yaw)
        local side = dist * 0.35
        G.spin = (G.spin + 0.6) % 360
        nv(0x239A3351AC1DA385, G.h, cp.x + fx * dist + rx * side, cp.y + fy * dist + ry * side, cp.z + fz * dist, false, false, false) -- SET_ENTITY_COORDS_NO_OFFSET
        nv(0x8E2530AA8ADA980E, G.h, G.spin + 0.0) -- SET_ENTITY_HEADING
    end

    -- PHOTOS: a picture next to the file (same name, .png / .jpg), shown under the list
    local tex, found = {}, {}
    local function Pair(a, b)
        if type(a) ~= "number" and a ~= nil then
            local ok, x, y = pcall(function() return a.x, a.y end)
            if ok then return x, y end
        end
        return a, b
    end
    local foundAt = 0
    local function PhotoPath(base)
        if NowMs() - foundAt > 10000 then found, foundAt = {}, NowMs() end -- (new pictures show up by themselves)
        if found[base] ~= nil then return found[base] or nil end
        found[base] = false
        for _, ext in ipairs({ ".png", ".jpg", ".jpeg", ".PNG", ".JPG" }) do
            local ok, e = pcall(FileMgr.DoesFileExist, base .. ext)
            if ok and e then found[base] = base .. ext break end
        end
        return found[base] or nil
    end
    F.DrawPhoto = function(base, noneText)
        if not base then return end
        local path = PhotoPath(base)
        if not path then if noneText then pcall(ImGui.TextDisabled, noneText) end return end
        if not tex[path] then
            local ok, id = pcall(Texture.LoadTextureAsync, path)
            if not ok or not id then ok, id = pcall(Texture.LoadTexture, path) end
            tex[path] = ok and id or -1
        end
        local id = tex[path]
        if id == -1 then return end
        local okV, valid = pcall(Texture.IsTextureValid, id)
        if not (okV and valid) then pcall(ImGui.TextDisabled, "(loading picture...)") return end
        local okS, srv = pcall(function()
            local t = Texture.GetTexture(id)
            local ok1, sv = pcall(function() return t:GetCurrent() end)
            if not ok1 or not sv then ok1, sv = pcall(function() return t:GetFrame(0) end) end
            return sv
        end)
        if not okS or not srv then return end
        local aw = Pair(ImGui.GetContentRegionAvail())
        local w = math.min(math.max(120, (aw or 320) - 8), 380)
        local h = w * 9 / 16
        local x, y = Pair(ImGui.GetCursorScreenPos())
        if not (x and y) then return end
        pcall(ImGui.AddImage, srv, x, y, x + w, y + h)
        if not pcall(ImGui.Dummy, w, h) then pcall(ImGui.Dummy, { x = w, y = h }) end
    end
    local function Base(path) return path and path:gsub("%.[^%.\\]+$", "") or nil end
    F.drawPreviewFile = function(path) F.DrawPhoto(Base(path)) end
end)

Try("creating constructor options", function()
    local api = F.xsApi
    if not api then return end
    local CX = { files = {}, folders = {}, shown = {}, sig = nil, lastDir = nil, lastSearch = nil, nextScan = 0,
                 b = nil, sel = nil, loadedSig = nil }
    local function nv(...) pcall(Natives.InvokeVoid, ...) end
    local function Me() return Natives.InvokeInt(0xD80958FC74E988A6) end -- PLAYER_PED_ID

    -- ----- where constructs live -----
    -- its own folder, LGNFX\lgnconstructs (not the XML / JSON folders - those have their own tab),
    -- plus the vehicles you've saved with Cherax itself
    CX.DIR = "lgnconstructs"
    -- (your constructs are saved straight into Lua\CE - kits in Lua\CE\kits)
    function CX.Root() local d = LuaDir() .. "\\CE" pcall(FileMgr.CreateDir, d) return d end
    function CX.Sources()
        local root = TrimSlash(FileMgr.GetMenuRootPath())
        return {
            { label = "LGN Constructs", dir = CX.Root(), skip = "\\data\\" },
            { label = "Cherax Saved Vehicles", dir = root .. "\\Vehicles" },
        }
    end
    -- (anything in the old LGNFX\constructs folder is copied over once - files already there are left alone)
    function CX.MoveOld()
        local old = api.MainBase() .. "\\constructs"
        local new = CX.Root()
        for _, kind in ipairs({ "json", "xml" }) do
            local ok, found = pcall(FileMgr.FindFiles, old, "." .. kind, true)
            for _, p in ipairs(ok and api.ToList(found) or {}) do
                p = tostring(p):gsub("/", "\\")
                local name = p:match("([^\\]+)$")
                local src = (p:match("^%a:\\") or p:match("^\\\\")) and p or (old .. "\\" .. p)
                if name and not api.Exists(new .. "\\" .. name) then
                    local okR, content = pcall(FileMgr.ReadFileContent, src)
                    if okR and content and content ~= "" then
                        pcall(FileMgr.WriteFileContent, new .. "\\" .. name, content, false)
                        pcall(Dump.Info, "[CE] constructor: moved " .. name .. " into Lua\\CE")
                    end
                end
            end
        end
    end
    function CX.Scan()
        local list, seen = {}, {}
        for _, src in ipairs(CX.Sources()) do
            local dirL = src.dir:lower()
            for _, kind in ipairs({ "xml", "json" }) do
                for _, ext in ipairs({ "." .. kind, kind }) do
                    local ok, found = pcall(FileMgr.FindFiles, src.dir, ext, true)
                    if ok then
                        for _, p in ipairs(api.ToList(found)) do
                            p = tostring(p):gsub("/", "\\")
                            if p:lower():sub(-#kind - 1) == "." .. kind then
                                local full = p
                                if not (p:match("^%a:\\") or p:match("^\\\\")) then full = src.dir .. "\\" .. p:gsub("^\\+", "") end
                                local skip = src.skip and full:lower():sub(1, #dirL + #src.skip) == dirL .. src.skip
                                if not seen[full:lower()] and not skip then
                                    seen[full:lower()] = true
                                    local rel = full
                                    if full:lower():sub(1, #dirL) == dirL then rel = full:sub(#dirL + 2) end
                                    rel = rel:gsub("%.[^%.\\]+$", "")
                                    local sub = rel:match("^(.*)\\[^\\]+$") or ""
                                    local name = rel:match("([^\\]+)$") or rel
                                    local folder = src.label .. (sub ~= "" and (" / " .. sub:gsub("\\", " / ")) or "")
                                    list[#list + 1] = { path = full, kind = kind, name = name, folder = folder,
                                        label = folder .. " / " .. name }
                                end
                            end
                        end
                    end
                end
            end
        end
        table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
        return list
    end
    function CX.PickedFolder() return CX.folders[(F.cxDir:GetListIndex() or 0) + 1] end
    function CX.PickedFile() return CX.shown[(F.cxList:GetListIndex() or 0) + 1] end
    F.cxPickedPath = function() local f = CX.PickedFile() return f and f.path end
    F.cxPickedModel = function() return (CX.PickedModel()) end
    function CX.Show()
        local d = CX.PickedFolder()
        local was = CX.PickedFile()
        local q = tostring(F.cxSearch:GetStringValue() or ""):lower()
        local words = {}
        for w in q:gmatch("%S+") do words[#words + 1] = w end
        CX.lastSearch, CX.lastDir, CX.shown = q, F.cxDir:GetListIndex() or 0, {}
        local virtual = #words == 0 and d and (d.fav or d.recent)
        if virtual then CX.shown = api.Favs.Virtual(d, CX.files) end
        for _, f in ipairs(virtual and {} or CX.files) do
            if #words > 0 then
                local hay, all = f.label:lower(), true
                for _, w in ipairs(words) do if not hay:find(w, 1, true) then all = false break end end
                if all then CX.shown[#CX.shown + 1] = f end
            elseif d and (d.all or f.folder == d.folder) then
                CX.shown[#CX.shown + 1] = f
            end
        end
        local names = {}
        for i, f in ipairs(CX.shown) do names[i] = (#words > 0 or virtual or (d and d.all)) and f.label or f.name end
        if #names == 0 then
            names = { #words > 0 and ("(no constructs match \"" .. q .. "\")")
                or (d and d.fav and "(no favourites yet - pick a construct and press Favourite Construct)")
                or (d and d.recent and "(nothing spawned yet - constructs you spawn show up here)")
                or (#CX.files == 0 and "(no constructs yet - save one, or drop files in Lua\\CE)") or "(this folder is empty)" }
        end
        F.cxList:SetList(names)
        local keep = 0
        if was then for i, f in ipairs(CX.shown) do if f.path == was.path then keep = i - 1 end end end
        F.cxList:SetListIndex(keep)
    end
    function CX.Refresh(announce)
        local list = CX.Scan()
        local sig = {}
        for i, f in ipairs(list) do sig[i] = f.path end
        sig = table.concat(sig, "|") .. "|" .. api.Favs.changed
        if sig ~= CX.sig then
            local wasDir = CX.PickedFolder()
            CX.files, CX.sig = list, sig
            local fav, rec = { fav = true, key = "*fav" }, { recent = true, key = "*recent" }
            fav.label = "* Favourites  (" .. #api.Favs.Virtual(fav, list) .. ")"
            rec.label = "* Recent  (" .. #api.Favs.Virtual(rec, list) .. ")"
            local byFolder, folders = {}, { { all = true, key = "*", label = "All Constructs  (" .. #list .. ")" }, fav, rec }
            for _, f in ipairs(list) do
                if not byFolder[f.folder] then
                    byFolder[f.folder] = { folder = f.folder, key = f.folder, n = 0 }
                    folders[#folders + 1] = byFolder[f.folder]
                end
                byFolder[f.folder].n = byFolder[f.folder].n + 1
            end
            local labels, keep = {}, 0
            for i, d in ipairs(folders) do
                if d.folder then d.label = d.folder .. "  (" .. d.n .. ")" end
                labels[i] = d.label
                if wasDir and d.key == wasDir.key then keep = i - 1 end
            end
            CX.folders = folders
            F.cxDir:SetList(labels)
            F.cxDir:SetListIndex(keep)
            CX.Show()
            if CX.ShowKits then pcall(CX.ShowKits) end
        end
        if announce then Notify(#CX.files .. " construct(s) in " .. (#CX.folders - 3) .. " folder(s)", true, "spawner") end
    end
    function CX.SpawnPicked()
        local f = CX.PickedFile()
        if not f then Notify("Constructor: pick a construct first", true, "spawner") return end
        CX.SpawnFile(f)
    end
    -- (also the command bar's "spawn <saved car / construct>")
    function CX.SpawnFile(f)
        local okR, content = pcall(FileMgr.ReadFileContent, f.path)
        if not okR or not content or content == "" then Notify("Couldn't read " .. f.name, true, "spawner") return end
        local plan, why
        if f.kind == "xml" then plan, why = api.XS.PlanFromXML(content) else plan, why = api.XS.PlanFromJSON(content) end
        if not plan then Notify("Can't spawn " .. f.name .. ": " .. tostring(why), true, "spawner") return end
        if #plan.items == 0 then Notify(f.name .. " has nothing in it to spawn", true, "spawner") return end
        local e = api.SpawnPlan(plan, f.name)
        if type(e) == "table" then e.path = f.path end
        api.Favs.Touch(f.path)
        pcall(CX.Refresh, false)
    end
    function CX.ToggleFav()
        local f = CX.PickedFile()
        if not f then Notify("Constructor: pick a construct first", true, "spawner") return end
        local on = api.Favs.Toggle(f.path)
        pcall(CX.Refresh, false)
        Notify((on and "Added to favourites: " or "Removed from favourites: ") .. f.name, true, "spawner")
    end

    -- ----- spawned constructs -----
    function CX.LoadedPicked() return api.Loaded()[(F.cxLoaded:GetListIndex() or 0) + 1] end
    function CX.LoadedList()
        local l = api.Loaded()
        local sig = #l .. "|" .. (l[#l] and l[#l].name or "")
        for _, e in ipairs(l) do sig = sig .. "|" .. #(e.parts or {}) .. ":" .. tostring(e.name) end
        if sig == CX.loadedSig then return end
        CX.loadedSig = sig
        local names = {}
        for i, e in ipairs(l) do
            names[i] = i .. ". " .. e.name .. "  (" .. #(e.parts or {}) .. " part" .. (#(e.parts or {}) == 1 and "" or "s") .. ")"
        end
        if #names == 0 then names = { "(nothing spawned yet)" } end
        F.cxLoaded:SetList(names)
        -- (something new spawned: it's picked, so Edit It / Get In It act on what you just spawned)
        if #l > (CX.loadedCount or 0) then F.cxLoaded:SetListIndex(math.max(0, #l - 1))
        elseif (F.cxLoaded:GetListIndex() or 0) >= #l then F.cxLoaded:SetListIndex(math.max(0, #l - 1)) end
        CX.loadedCount = #l
    end
    function CX.DeleteEntry(e)
        local l = api.Loaded()
        for i = #l, 1, -1 do if l[i] == e then table.remove(l, i) end end
        for i, h in ipairs(e.handles) do api.Remove(h) if i % 10 == 0 then Script.Yield(0) end end
        if CX.b and CX.b.entry == e then CX.b, CX.sel = nil, nil CX.PartList() end
    end

    -- ----- building -----
    -- what can be added: LGNFX's object categories (same as the Objects tab), a search of every
    -- object in the game (ObjectList.txt), or any model / ID typed in
    CX.CATS = { { name = "Search Results (type in Search All Objects)", search = true },
                { name = "Custom (type in Custom Object Model)", custom = true } }
    do
        local byCat = {}
        for _, e in ipairs(F.SPAWN_OBJECTS or {}) do
            if not byCat[e[1]] then byCat[e[1]] = { name = e[1], items = {} } CX.CATS[#CX.CATS + 1] = byCat[e[1]] end
            table.insert(byCat[e[1]].items, { e[2], e[3] })
        end
    end
    CX.results = {}
    function CX.CatItems()
        local c = CX.CATS[(F.cxCat:GetListIndex() or 0) + 1] or CX.CATS[1]
        if c.search then return CX.results, c end
        return c.items or {}, c
    end
    function CX.ShowItems()
        local items, c = CX.CatItems()
        local names = {}
        for i, it in ipairs(items) do names[i] = it[1] end
        if #names == 0 then
            names = { c.custom and "(uses Custom Object Model below)" or "(type something in Search All Objects above)" }
        end
        F.cxObj:SetList(names)
        F.cxObj:SetListIndex(0)
        CX.lastCat = F.cxCat:GetListIndex() or 0
    end
    -- SEARCH ALL OBJECTS: every object name in the game, from ObjectList.txt (Stand Constructor's list)
    function CX.ObjectNames()
        if CX.allObjects and #CX.allObjects > 0 then return CX.allObjects end
        CX.allObjects = {}
        for _, path in ipairs({ api.MainBase() .. "\\ObjectList.txt", LuaDir() .. "\\Constructor\\Assets\\ObjectList.txt" }) do
            local ok, txt = pcall(FileMgr.ReadFileContent, path)
            if ok and txt and #txt > 100 then
                for line in txt:gmatch("[^\r\n]+") do
                    local n = line:match("^%s*([%w_%-%.]+)%s*$")
                    if n then CX.allObjects[#CX.allObjects + 1] = n end
                end
                break
            end
        end
        return CX.allObjects
    end
    function CX.Search()
        local q = tostring(F.cxFind:GetStringValue() or ""):lower()
        CX.lastFind = q
        CX.results = {}
        local words = {}
        for w in q:gmatch("%S+") do words[#words + 1] = w end
        if #words == 0 then if (F.cxCat:GetListIndex() or 0) == 0 then CX.ShowItems() end return end
        local all = CX.ObjectNames()
        local hits = {}
        for _, n in ipairs(all) do
            local l, ok = n:lower(), true
            for _, w in ipairs(words) do if not l:find(w, 1, true) then ok = false break end end
            if ok then hits[#hits + 1] = n end
        end
        table.sort(hits, function(x, y) if #x ~= #y then return #x < #y end return x < y end)
        for i = 1, math.min(#hits, 150) do CX.results[#CX.results + 1] = { hits[i], hits[i] } end
        if #all == 0 then
            CX.results = { { "(ObjectList.txt not found - put it in Lua\\CE\\data)", "" } }
        elseif #hits == 0 then
            CX.results = { { "(no objects match \"" .. q .. "\")", "" } }
        elseif #hits > 150 then
            CX.results[#CX.results + 1] = { "(" .. (#hits - 150) .. " more - type more of the name)", "" }
        end
        F.cxCat:SetListIndex(0)
        CX.ShowItems()
    end
    function CX.PickedModel()
        local items, c = CX.CatItems()
        if c.custom then
            local m = tostring(F.cxObjCustom:GetStringValue() or ""):gsub("%s", "")
            return m, m
        end
        local it = items[(F.cxObj:GetListIndex() or 0) + 1]
        if not it or it[2] == "" then return "", "" end
        return it[2], it[1]
    end
    -- bones on the base the part can be stuck to (wheels spin, doors swing...)
    CX.BONES = { { "Centre (no bone)", nil }, { "Chassis", "chassis" }, { "Body", "bodyshell" }, { "Bonnet", "bonnet" },
        { "Boot", "boot" }, { "Front Left Wheel", "wheel_lf" }, { "Front Right Wheel", "wheel_rf" },
        { "Rear Left Wheel", "wheel_lr" }, { "Rear Right Wheel", "wheel_rr" }, { "Driver Door", "door_dside_f" },
        { "Passenger Door", "door_pside_f" }, { "Rear Driver Door", "door_dside_r" }, { "Rear Passenger Door", "door_pside_r" },
        { "Windscreen", "windscreen" }, { "Steering Wheel", "steeringwheel" }, { "Exhaust", "exhaust" }, { "Engine", "engine" },
        { "Spoiler", "misc_a" }, { "Left Headlight", "headlight_l" }, { "Right Headlight", "headlight_r" },
        { "Left Taillight", "taillight_l" }, { "Right Taillight", "taillight_r" } }
    -- parts can be stuck on the base, or on another part (pt.parent) - the list shows them indented under it
    function CX.Depth(pt)
        local d, p = 0, pt.parent
        while p and d < 8 do d, p = d + 1, p.parent end
        return d
    end
    function CX.PartLabel(pt)
        return pt.name or string.format("0x%08X", (pt.model or 0) % 4294967296)
    end
    -- row -> part, in tree order (each part with what's stuck on it right under it)
    CX.view = {}
    function CX.Row(pt)
        for i, p in ipairs(CX.view) do if p == pt then return i - 1 end end
        return 0
    end
    function CX.BuildView()
        local b, view, inList = CX.b, {}, {}
        local parts = b and b.parts or {}
        for _, p in ipairs(parts) do inList[p] = true end
        local seen = {}
        local function Walk(p, d)
            if seen[p] or d > 8 then return end
            seen[p] = true
            view[#view + 1] = p
            for _, q in ipairs(parts) do if q.parent == p then Walk(q, d + 1) end end
        end
        for _, p in ipairs(parts) do if not (p.parent and inList[p.parent]) then Walk(p, 0) end end
        for _, p in ipairs(parts) do if not seen[p] then view[#view + 1] = p end end -- (anything left over still shows)
        CX.view = view
    end
    function CX.PartList()
        local names = {}
        local b = CX.b
        CX.BuildView()
        for i, pt in ipairs(CX.view) do
            local d = CX.Depth(pt)
            names[i] = i .. ". " .. string.rep("   ", d) .. (d > 0 and "> " or "") .. (pt.grp and "[x] " or "")
                .. CX.PartLabel(pt) .. (pt.locked and "  (locked)" or "")
        end
        if #names == 0 then names = { b and "(no parts yet - add one above)" or "(start a construct first)" } end
        F.cxPart:SetList(names)
        if b and #b.parts > 0 then F.cxPart:SetListIndex(math.min(F.cxPart:GetListIndex() or 0, #b.parts - 1)) end
        CX.sel = nil -- (the sliders are filled in from the picked part on the next tick)
    end
    -- what a part is stuck to: its parent part, or the base
    function CX.Holder(pt)
        local b = CX.b
        local p = pt.parent
        if p and p.h and IB(0x7239B21A38F536BA, p.h) then return p.h end
        return b and b.car
    end
    function CX.Attach(pt)
        local b = CX.b
        local to = b and CX.Holder(pt)
        if not (b and pt and to and IB(0x7239B21A38F536BA, pt.h) and IB(0x7239B21A38F536BA, to)) then return end
        -- (online, only the game in charge of a part can stick / move it - if yours has lost it, the move
        -- did nothing and the Constructor seemed to stop working. Ask for it back; the self-heal in
        -- the constructor tick puts it right as soon as it's yours again)
        if not IB(0x01BF60A500E28887, pt.h) then nv(0xB69317BF5E782347, pt.h) end -- NETWORK_HAS_CONTROL / REQUEST_CONTROL
        nv(0x6B9BBD38AB0796DF, pt.h, to, pt.bone or 0, pt.off.x + 0.0, pt.off.y + 0.0, pt.off.z + 0.0,
            pt.rot.x + 0.0, pt.rot.y + 0.0, pt.rot.z + 0.0, false, false, pt.col == true, pt.kind == 1, 2, true) -- ATTACH_ENTITY_TO_ENTITY
    end
    -- every part of the build you're editing that isn't stuck to what it should be is stuck back on
    function CX.Heal()
        local b = CX.b
        if not b or not IB(0x7239B21A38F536BA, b.car) then return end
        for _, pt in ipairs(b.parts) do
            local to = CX.Holder(pt)
            if to and IB(0x7239B21A38F536BA, pt.h) then
                local okA, at = pcall(Natives.InvokeInt, 0x48C2BED9180FE123, pt.h) -- GET_ENTITY_ATTACHED_TO
                if okA and at ~= to then CX.Attach(pt) end
            end
        end
    end
    function CX.Look(pt)
        -- (hidden parts stay hidden - kept that way every frame; shown again = let go of)
        if pt.vis == false then LGX.KeepHidden(pt.h) else LGX.hidden[pt.h] = nil end
        nv(0xEA1C610A04DB6BBB, pt.h, pt.vis ~= false, false) -- SET_ENTITY_VISIBLE
        local a = math.floor(pt.alpha or 255)
        if a >= 255 then nv(0x9B1E824FFBB7027A, pt.h) else nv(0x44A0870B7E92D7C0, pt.h, a, false) end -- RESET_ENTITY_ALPHA / SET_ENTITY_ALPHA
        if pt.tint and pt.kind ~= 1 and pt.kind ~= 2 then nv(0x971DA0055324D033, pt.h, math.floor(pt.tint)) end -- SET_OBJECT_TEXTURE_VARIATION
    end
    function CX.Begin(car, entry)
        if not entry then
            for _, e in ipairs(api.Loaded()) do if e.root == car then entry = e end end
        end
        if not entry then
            local okN, dn = pcall(Natives.InvokeString, 0xB215AAC32D25D019, Natives.InvokeInt(0x9F47B058362C84B5, car)) -- GET_DISPLAY_NAME_FROM_VEHICLE_MODEL
            -- (your own car only goes on the Spawned Constructs list once it has a part on it - an empty
            -- "My build" used to sit at the top of the list and got opened instead of what you spawned)
            entry = { name = "My build (" .. ((okN and dn and dn ~= "" and dn ~= "CARNOTFOUND") and dn:lower() or "construct") .. ")",
                      handles = {}, parts = {}, root = car, kind = "vehicle", pending = true }
        end
        entry.parts = entry.parts or {}
        CX.b = { car = car, entry = entry, parts = entry.parts }
        CX.unsaved = false
        pcall(function() F.cxBaseVis:SetBoolValue(IB(0x47D6F43D77935C75, car)) end) -- IS_ENTITY_VISIBLE
        CX.PartList()
        CX.loadedSig = nil
        Notify(("Constructor: building on %s (%d part%s) - add parts on the Build tab, move them on Edit Part"):format(
            entry.name, #entry.parts, #entry.parts == 1 and "" or "s"), true, "spawner")
    end
    -- in front of you (for new bases)
    function CX.Front(dist)
        local me = Me()
        local p = EntityPos(me)
        if not p then return nil end
        local hd = Natives.InvokeFloat(0xE83D4F9BA2A38914, me) or 0.0 -- GET_ENTITY_HEADING
        local r = math.rad(hd)
        return { x = p.x - math.sin(r) * dist, y = p.y + math.cos(r) * dist, z = p.z, h = hd }
    end
    function CX.LoadModel(model)
        local hash = tonumber(model) or Utils.Joaat(model)
        if not IB(0xC0296A2EDF545E92, hash) then return nil end -- IS_MODEL_VALID
        nv(0x963D27A58DF860AC, hash)
        for _ = 1, 100 do if IB(0x98A4EB5D89A0C952, hash) then break end Script.Yield(20) nv(0x963D27A58DF860AC, hash) end
        if not IB(0x98A4EB5D89A0C952, hash) then return nil end
        return hash
    end
    -- NEW BASE: a vehicle by name, or a construction cone (a map / structure, frozen where it is)
    function CX.NewBase(cone)
        local model = cone and "prop_roadcone01b" or tostring(F.cxVehName:GetStringValue() or ""):gsub("%s", "")
        if model == "" then Notify("Constructor: type a vehicle name first (e.g. adder, pbus2, monster)", true, "spawner") return end
        local hash = CX.LoadModel(model)
        if not hash then Notify("Constructor: '" .. model .. "' isn't a model in your game", true, "spawner") return end
        if not cone and not IB(0x19AAC8F07BFEC53E, hash) then Notify("Constructor: '" .. model .. "' isn't a vehicle", true, "spawner") return end
        local f = CX.Front(cone and 4.0 or 6.0)
        if not f then return end
        local ok, h
        if cone then ok, h = pcall(LGX.CreateObject, hash, f.x, f.y, f.z, false, true)
        else ok, h = pcall(LGX.SpawnVehicle, hash, f.x, f.y, f.z, f.h + 0.0, true, false) end
        nv(0xE532F5D78798DAAB, hash)
        if not ok or not h or h == 0 then Notify("Constructor: couldn't spawn " .. model, true, "spawner") return end
        LGX.Networked(h)
        nv(0x8E2530AA8ADA980E, h, f.h + 0.0) -- SET_ENTITY_HEADING
        if cone then
            nv(0x58A850EAEE20FAA3, h) -- PLACE_OBJECT_ON_GROUND_PROPERLY
            nv(0x428CA6DBD1094446, h, true) -- FREEZE_ENTITY_POSITION
        else
            nv(0x49733E92263139D1, h, 5.0) -- SET_VEHICLE_ON_GROUND_PROPERLY
            if F.xsInto:IsToggled() then nv(0xF75B0D629E1C063D, Me(), h, -1) end
        end
        local entry = { name = cone and "My map" or ("My build (" .. model:lower() .. ")"), handles = { h }, parts = {},
                        root = h, kind = cone and "map" or "vehicle", frozen = cone or nil }
        table.insert(api.Loaded(), entry)
        CX.Begin(h, entry)
    end
    function CX.SpawnPart(model, label)
        local b = CX.b
        if not b or not IB(0x7239B21A38F536BA, b.car) then Notify("Constructor: start a construct first", true, "spawner") return end
        if not model or model == "" then Notify("Constructor: pick an object, or type one in Custom Object Model", true, "spawner") return end
        local hash = CX.LoadModel(model)
        if not hash then Notify("Constructor: '" .. tostring(label or model) .. "' isn't a model in your game", true, "spawner") return end
        local p = EntityPos(b.car)
        if not p then return end
        local kind = IB(0x19AAC8F07BFEC53E, hash) and 2 or (IB(0x75816577FEA6DAD5, hash) and 1 or 3) -- vehicle / ped / object
        local ok, h
        if kind == 2 then ok, h = pcall(LGX.SpawnVehicle, hash, p.x, p.y, p.z + 3.0, 0.0, true, false)
        elseif kind == 1 then ok, h = pcall(LGX.CreatePed, hash, 4, p.x, p.y, p.z + 3.0, 0.0, true, false)
        else ok, h = pcall(LGX.CreateObject, hash, p.x, p.y, p.z + 3.0, true, true) end
        nv(0xE532F5D78798DAAB, hash)
        if not ok or not h or h == 0 then Notify("Constructor: couldn't spawn " .. tostring(label or model), true, "spawner") return end
        LGX.Networked(h)
        return h, hash, kind
    end

    -- ----- UNDO / REDO -----
    -- Every change is a step that can be taken back (Undo) and put back again (Redo) - a move / turn /
    -- setting / name / lock, an added or duplicated part, a removed part (with anything stuck on it), a
    -- group move, a kit. A slider drag or held key is one step. 30 steps for each build.
    CX.undo, CX.redo = {}, {}
    function CX.Snapshot(pt)
        return { off = { x = pt.off.x, y = pt.off.y, z = pt.off.z }, rot = { x = pt.rot.x, y = pt.rot.y, z = pt.rot.z },
                 bone = pt.bone, boneName = pt.boneName, col = pt.col, vis = pt.vis, alpha = pt.alpha,
                 name = pt.name, locked = pt.locked, tint = pt.tint }
    end
    function CX.ApplyState(pt, s)
        pt.off = { x = s.off.x, y = s.off.y, z = s.off.z }
        pt.rot = { x = s.rot.x, y = s.rot.y, z = s.rot.z }
        pt.bone, pt.boneName, pt.col, pt.vis, pt.alpha, pt.name, pt.locked = s.bone, s.boneName, s.col, s.vis, s.alpha, s.name, s.locked
        pt.tint = s.tint
        CX.Attach(pt)
        CX.Look(pt)
    end
    function CX.IndexOf(pt)
        for i, p in ipairs(CX.b and CX.b.parts or {}) do if p == pt then return i end end
        return nil
    end
    -- a user change: remembered for Undo (and Redo starts again from here)
    function CX.Push(op)
        local e = CX.b and CX.b.entry
        op.entry = e
        CX.undo[#CX.undo + 1] = op
        while #CX.undo > 60 do table.remove(CX.undo, 1) end
        for i = #CX.redo, 1, -1 do if CX.redo[i].entry == e then table.remove(CX.redo, i) end end
        CX.dirty, CX.unsaved = true, true
    end
    local function CountFor(list)
        local n, e = 0, CX.b and CX.b.entry
        for _, u in ipairs(list) do if u.entry == e then n = n + 1 end end
        return n
    end
    function CX.UndoCount() return CountFor(CX.undo) end
    function CX.RedoCount() return CountFor(CX.redo) end
    function CX.Pick(pt)
        if CX.IndexOf(pt) then F.cxPart:SetListIndex(CX.Row(pt)) end
        CX.sel = nil -- (the sliders show it again on the next tick)
    end
    -- the raw steps (each gives back the step that undoes it)
    function CX.AddRaw(pt, at)
        local b = CX.b
        if b.entry.pending then b.entry.pending = nil table.insert(api.Loaded(), b.entry) end
        at = math.min(at or (#b.parts + 1), #b.parts + 1)
        table.insert(b.parts, at, pt)
        b.entry.handles[#b.entry.handles + 1] = pt.h
        CX.Attach(pt)
        CX.Look(pt)
        CX.loadedSig = nil
        return at
    end
    function CX.TakeOff(pt)
        local b = CX.b
        local at = CX.IndexOf(pt)
        if at then table.remove(b.parts, at) end
        for j = #b.entry.handles, 1, -1 do if b.entry.handles[j] == pt.h then table.remove(b.entry.handles, j) end end
        api.Remove(pt.h)
        CX.loadedSig = nil
        return at
    end
    function CX.Full(pt)
        local w = CX.Snapshot(pt)
        w.model, w.modelName, w.kind = pt.model, pt.modelName, pt.kind
        return w
    end
    function CX.Apply(op)
        if op.op == "group" then
            local inv = {}
            for _, o in ipairs(op.list) do
                local i = CX.Apply(o)
                if i then table.insert(inv, 1, i) end
            end
            return #inv > 0 and { op = "group", list = inv, what = op.what } or nil
        elseif op.op == "state" then
            if not (CX.IndexOf(op.pt) and IB(0x7239B21A38F536BA, op.pt.h)) then return nil end
            local inv = { op = "state", pt = op.pt, s = CX.Snapshot(op.pt), what = op.what }
            CX.ApplyState(op.pt, op.s)
            return inv
        elseif op.op == "take" then
            if not CX.IndexOf(op.pt) then return nil end
            local was = CX.Full(op.pt)
            local at = CX.TakeOff(op.pt)
            return { op = "put", pt = op.pt, was = was, at = at, what = op.what }
        elseif op.op == "put" then
            if CX.IndexOf(op.pt) then return nil end
            local w = op.was
            local b0 = CX.b
            local h, hash, kind = CX.SpawnPart(w.modelName or w.model, w.name)
            if not h then return nil end
            if CX.b ~= b0 then api.Remove(h) return nil end
            local pt = op.pt -- (the same part comes back, so the steps before it still work on it)
            pt.h, pt.model, pt.kind = h, hash, kind
            CX.ApplyState(pt, w)
            CX.AddRaw(pt, op.at)
            return { op = "take", pt = pt, what = op.what }
        end
        return nil
    end
    local function Step(from, to, word)
        local b = CX.b
        if not b then Notify("Constructor: nothing to " .. word .. " - no build open", true, "spawner") return end
        -- (one at a time: putting a part back waits for its model, and a second press meanwhile
        -- would skip the step before it)
        if CX.busy and NowMs() - CX.busy < 5000 then return end
        CX.busy = NowMs()
        local ok, err = pcall(CX.StepNow, from, to, word, b)
        CX.busy = nil
        if not ok then LogErr("constructor " .. word, err) end
    end
    function CX.StepNow(from, to, word, b)
        for i = #from, 1, -1 do
            local op = from[i]
            if op.entry == b.entry then
                table.remove(from, i)
                local inv = CX.Apply(op)
                if inv then
                    inv.entry = b.entry
                    to[#to + 1] = inv
                    CX.snapPt, CX.dirty, CX.unsaved = nil, true, true
                    CX.PartList()
                    local pt = op.pt or (op.list and op.list[1] and op.list[1].pt)
                    if pt then CX.Pick(pt) end
                    Notify(("Constructor: %s %s  (%d more to %s)"):format(word == "undo" and "undid" or "redid", op.what or "the last change",
                        CountFor(from), word), true, "spawner", { merge = "cx undo" })
                    return
                end
                -- (a step whose part has gone some other way is skipped)
            end
        end
        Notify("Constructor: nothing left to " .. word, true, "spawner", { merge = "cx undo" })
    end
    function CX.Undo() Step(CX.undo, CX.redo, "undo") end
    function CX.Redo() Step(CX.redo, CX.undo, "redo") end

    function CX.AddPart(pt, at, noUndo)
        CX.AddRaw(pt, at)
        CX.PartList()
        F.cxPart:SetListIndex(CX.Row(pt))
        if not noUndo then CX.Push({ op = "take", pt = pt, what = "adding " .. CX.PartLabel(pt) }) end
    end

    -- ----- WHERE YOU'RE LOOKING -----
    -- a line from the camera to what's in the middle of the screen (up to 60m)
    function CX.Aim()
        local ok, res = pcall(function()
            local cp = F.LX and F.LX.V3(0x14D6F5678D8F1B37) -- GET_GAMEPLAY_CAM_COORD
            local cr = F.LX and F.LX.V3(0x837765A25378F0BB, 2) -- GET_GAMEPLAY_CAM_ROT
            if not (cp and cr) then return nil end
            local pitch, yaw = math.rad(cr.x), math.rad(cr.z)
            local d = { x = -math.sin(yaw) * math.cos(pitch), y = math.cos(yaw) * math.cos(pitch), z = math.sin(pitch) }
            local to = { x = cp.x + d.x * 60, y = cp.y + d.y * 60, z = cp.z + d.z * 60 }
            local hitP, endP, nP, eP = Memory.Alloc(8), Memory.Alloc(32), Memory.Alloc(32), Memory.Alloc(8)
            Memory.WriteInt(hitP, 0) Memory.WriteInt(eP, 0)
            local h = Natives.InvokeInt(0x377906D8A31E5586, cp.x + 0.0, cp.y + 0.0, cp.z + 0.0, to.x + 0.0, to.y + 0.0, to.z + 0.0,
                -1, Me(), 7) -- START_EXPENSIVE_SYNCHRONOUS_SHAPE_TEST_LOS_PROBE (everything, not you)
            Natives.InvokeInt(0x3D87450E15D98694, h, hitP, endP, nP, eP) -- GET_SHAPE_TEST_RESULT
            local hit = (Memory.ReadInt(hitP) or 0) % 256 ~= 0
            local r = hit and { x = Memory.ReadFloat(endP), y = Memory.ReadFloat(endP + 8), z = Memory.ReadFloat(endP + 16),
                                ent = Memory.ReadInt(eP) or 0 } or nil
            Memory.Free(hitP) Memory.Free(endP) Memory.Free(nP) Memory.Free(eP)
            return r
        end)
        return ok and res or nil
    end
    -- the spot you're looking at, as a place on the base (or on the part it'd be stuck to)
    function CX.AimOffset(parent)
        local b = CX.b
        local a = b and CX.Aim()
        if not a then return nil end
        local cp = EntityPos(b.car)
        if not cp or math.sqrt((a.x - cp.x) ^ 2 + (a.y - cp.y) ^ 2 + (a.z - cp.z) ^ 2) > 25 then return nil end
        local on = (parent and parent.h) or b.car
        local o = F.LX and F.LX.V3(0x2274BC1C4885E333, on, a.x + 0.0, a.y + 0.0, a.z + 0.0) -- GET_OFFSET_FROM_ENTITY_GIVEN_WORLD_COORDS
        return o
    end

    function CX.Add()
        local model, label = CX.PickedModel()
        local b = CX.b
        -- (Add Onto The Picked Part: the new part is stuck on the part picked on Edit Part)
        local parent = F.cxOnPart:IsToggled() and CX.PickedPart() or nil
        local off = F.cxAimAdd:IsToggled() and CX.AimOffset(parent) or nil
        local h, hash, kind = CX.SpawnPart(model, label)
        if not h then return end
        if CX.b ~= b then api.Remove(h) return end -- (the build closed while the model loaded)
        local pt = { h = h, model = hash, name = label, modelName = model, kind = kind, bone = 0, col = false, vis = true, alpha = 255,
                     off = off and { x = off.x, y = off.y, z = off.z } or { x = 0.0, y = 0.0, z = parent and 0.3 or 1.2 },
                     rot = { x = 0.0, y = 0.0, z = 0.0 }, parent = parent }
        CX.AddPart(pt)
        Notify("Constructor: added " .. label .. (off and " where you're looking" or "") .. (parent and (" onto " .. CX.PartLabel(parent)) or "")
            .. " - move it on the Edit Part tab", true, "spawner")
    end
    function CX.PickedPart()
        local b = CX.b
        if not b then return nil end
        if #CX.view ~= #b.parts then CX.BuildView() end -- (the list is rebuilt when parts come and go - this is the safety net)
        return CX.view[(F.cxPart:GetListIndex() or 0) + 1]
    end
    -- DUPLICATE (Stand's "Clone"): the same part again in the same spot - or mirrored to the other side
    -- (mirror = flip: left / right, front / back or up / down, like Stand's Clone Reflection)
    function CX.Duplicate(mirror)
        local src = CX.PickedPart()
        if not src then Notify("Constructor: pick a part to duplicate first", true, "spawner") return end
        local b0 = CX.b
        local h, hash, kind = CX.SpawnPart(src.modelName or src.model, src.name)
        if not h then return end
        if CX.b ~= b0 then api.Remove(h) return end
        local pt = { h = h, model = hash, name = src.name, modelName = src.modelName, kind = kind, bone = src.bone or 0,
                     boneName = src.boneName, col = src.col, vis = src.vis, alpha = src.alpha, tint = src.tint, parent = src.parent,
                     off = { x = src.off.x, y = src.off.y, z = src.off.z }, rot = { x = src.rot.x, y = src.rot.y, z = src.rot.z } }
        if mirror == "x" then
            pt.off.x, pt.rot.y, pt.rot.z = -pt.off.x, -pt.rot.y, -pt.rot.z
            -- (on a left wheel / door / light: the copy goes on the right one, and the other way round)
            if pt.boneName then
                local bn = pt.boneName
                local sw = bn:gsub("_lf$", "_RF"):gsub("_rf$", "_lf"):gsub("_RF$", "_rf")
                sw = sw:gsub("_lr$", "_RR"):gsub("_rr$", "_lr"):gsub("_RR$", "_rr")
                sw = sw:gsub("dside", "PSIDE"):gsub("pside", "dside"):gsub("PSIDE", "pside")
                sw = sw:gsub("_l$", "_R"):gsub("_r$", "_l"):gsub("_R$", "_r")
                pt.boneName = sw
                pt.bone = CX.BoneIndex(pt)
            end
        elseif mirror == "y" then pt.off.y = -pt.off.y
        elseif mirror == "z" then pt.off.z = -pt.off.z
        else pt.off.x = pt.off.x + (CX.STEPS[(F.cxStep:GetListIndex() or 1) + 1] or 0.01) end -- (plain copy: one step over)
        CX.AddPart(pt)
        Notify("Constructor: " .. (mirror and "mirrored" or "duplicated") .. " " .. tostring(src.name), true, "spawner")
    end
    -- everything stuck on a part (and on those...), deepest first
    function CX.Descendants(pt)
        local out = {}
        local function Walk(p, d)
            if d > 8 then return end
            for _, q in ipairs(CX.b.parts) do if q.parent == p then Walk(q, d + 1) out[#out + 1] = q end end
        end
        Walk(pt, 0)
        return out
    end
    function CX.RemovePart()
        local pt = CX.PickedPart()
        if not pt then return end
        if pt.locked then Notify("Constructor: " .. CX.PartLabel(pt) .. " is locked - unlock it first", true, "spawner") return end
        -- (anything stuck on it comes off with it - Undo puts them all back)
        local list = {}
        for _, q in ipairs(CX.Descendants(pt)) do list[#list + 1] = { op = "take", pt = q } end
        list[#list + 1] = { op = "take", pt = pt }
        local inv = CX.Apply({ op = "group", list = list })
        if inv then
            inv.what = "removing " .. CX.PartLabel(pt)
            CX.Push(inv)
        end
        CX.PartList()
        Notify("Constructor: removed " .. CX.PartLabel(pt) .. (#list > 1 and (" and " .. (#list - 1) .. " part(s) on it") or "")
            .. " - Undo puts it back", true, "spawner")
    end
    -- NAME / LOCK / MOVE TOGETHER
    function CX.RenamePart()
        local pt = CX.PickedPart()
        if not pt then Notify("Constructor: pick a part first", true, "spawner") return end
        local name = tostring(F.cxPartName:GetStringValue() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then Notify("Constructor: type a name in 'Part Name' first", true, "spawner") return end
        CX.Push({ op = "state", pt = pt, s = CX.Snapshot(pt), what = "renaming " .. CX.PartLabel(pt) })
        pt.name = name
        CX.PartList() CX.Pick(pt)
        Notify("Constructor: part named " .. name, true, "spawner")
    end
    function CX.ToggleLock()
        local pt = CX.PickedPart()
        if not pt then Notify("Constructor: pick a part first", true, "spawner") return end
        CX.Push({ op = "state", pt = pt, s = CX.Snapshot(pt), what = (pt.locked and "unlocking " or "locking ") .. CX.PartLabel(pt) })
        pt.locked = not pt.locked or nil
        CX.PartList() CX.Pick(pt)
        Notify("Constructor: " .. CX.PartLabel(pt) .. (pt.locked and " locked - it can't be moved or removed" or " unlocked"), true, "spawner")
    end
    function CX.GroupToggle(which)
        local b = CX.b
        if not b then return end
        local pt = CX.PickedPart()
        if which == "all" then for _, q in ipairs(b.parts) do q.grp = true end
        elseif which == "none" then for _, q in ipairs(b.parts) do q.grp = nil end
        elseif pt then pt.grp = not pt.grp or nil end
        local n = 0
        for _, q in ipairs(b.parts) do if q.grp then n = n + 1 end end
        CX.PartList()
        if pt then CX.Pick(pt) end
        Notify(("Constructor: %d part%s picked to move together - move any of them and the rest follow"):format(n, n == 1 and "" or "s"),
            true, "spawner", { merge = "cx group" })
    end

    -- the picked part follows the sliders live, the exact-number boxes, the keys - and they all show
    -- the part when you pick another
    CX.SL = { { "cxX", "off", "x" }, { "cxY", "off", "y" }, { "cxZ", "off", "z" },
              { "cxRX", "rot", "x" }, { "cxRY", "rot", "y" }, { "cxRZ", "rot", "z" } }
    CX.STEPS = { 0.001, 0.01, 0.05, 0.1, 0.25, 0.5, 1.0 }
    CX.RSTEPS = { 0.1, 1.0, 5.0, 15.0, 45.0, 90.0 }
    CX.lastSl = {}
    function CX.Fmt(v) return (string.format("%.3f", v):gsub("0+$", ""):gsub("%.$", ".0")) end
    function CX.WriteBoxes(pt)
        CX.posTxt = CX.Fmt(pt.off.x) .. " " .. CX.Fmt(pt.off.y) .. " " .. CX.Fmt(pt.off.z)
        CX.rotTxt = CX.Fmt(pt.rot.x) .. " " .. CX.Fmt(pt.rot.y) .. " " .. CX.Fmt(pt.rot.z)
        pcall(function() F.cxPosExact:SetStringValue(CX.posTxt) end)
        pcall(function() F.cxRotExact:SetStringValue(CX.rotTxt) end)
    end
    function CX.WriteSliders(pt)
        for i, s in ipairs(CX.SL) do
            local v = pt[s[2]][s[3]] + 0.0
            pcall(function() F[s[1]]:SetFloatValue(v) end)
            local ok, back = pcall(function() return F[s[1]]:GetFloatValue() end)
            CX.lastSl[i] = ok and back or v -- (what the slider really shows - it can't go past its ends)
        end
    end
    function CX.Numbers(txt)
        local t = {}
        for n in tostring(txt or ""):gsub(",", " "):gmatch("%-?%d*%.?%d+") do t[#t + 1] = tonumber(n) end
        return t
    end
    function CX.BoneIndex(pt)
        local b = CX.b
        if pt.parent or not pt.boneName then return pt.bone or 0 end -- (on another part: its centre)
        local i = Natives.InvokeInt(0xFB71170B7E76ACBA, b.car, pt.boneName) -- GET_ENTITY_BONE_INDEX_BY_NAME
        return (i and i >= 0) and i or 0
    end
    local function Snap(v, step) return math.floor(v / step + 0.5) * step end
    function CX.Live()
        local b = CX.b
        if not b then return end
        local pt = CX.PickedPart()
        if not pt then return end
        -- step sizes
        local st, rst = F.cxStep:GetListIndex() or 1, F.cxRStep:GetListIndex() or 1
        if st ~= CX.lastStep then
            CX.lastStep = st
            for _, k in ipairs({ "cxX", "cxY", "cxZ" }) do pcall(function() F[k]:SetStepSize(CX.STEPS[st + 1] or 0.01) end) end
        end
        if rst ~= CX.lastRStep then
            CX.lastRStep = rst
            for _, k in ipairs({ "cxRX", "cxRY", "cxRZ" }) do pcall(function() F[k]:SetStepSize(CX.RSTEPS[rst + 1] or 1.0) end) end
        end
        if pt ~= CX.curPt then CX.prevPt, CX.curPt = CX.curPt, pt end -- (for Snap Onto Part: the one picked before)
        if CX.sel ~= pt then
            CX.sel = pt
            CX.WriteSliders(pt)
            CX.WriteBoxes(pt)
            pcall(function() F.cxCol:SetBoolValue(pt.col == true) end)
            pcall(function() F.cxVis:SetBoolValue(pt.vis ~= false) end)
            pcall(function() F.cxAlpha:SetIntValue(math.floor(pt.alpha or 255)) end)
            pcall(function() F.cxTint:SetIntValue(math.floor(pt.tint or 0)) end)
            pcall(function() F.cxPartName:SetStringValue(CX.PartLabel(pt)) end)
            local bi = 0
            for i, bn in ipairs(CX.BONES) do if bn[2] and bn[2] == pt.boneName then bi = i - 1 end end
            pcall(function() F.cxBone:SetListIndex(bi) end)
            CX.lastBone = bi
            return
        end
        local before = CX.Snapshot(pt) -- (for Undo)
        local moved, look, typed, shifted = false, false, false, false
        -- sliders (only when you've moved one)
        for i, s in ipairs(CX.SL) do
            local ok, v = pcall(function() return F[s[1]]:GetFloatValue() end)
            if ok and v and CX.lastSl[i] and math.abs(v - CX.lastSl[i]) > 0.00001 then
                pt[s[2]][s[3]], CX.lastSl[i], moved, shifted = v, v, true, true
            end
        end
        if moved then CX.WriteBoxes(pt) end
        -- exact numbers typed in the boxes ("x y z" / "pitch roll yaw")
        local pos, rot = tostring(F.cxPosExact:GetStringValue() or ""), tostring(F.cxRotExact:GetStringValue() or "")
        if pos ~= CX.posTxt then
            CX.posTxt = pos
            local n = CX.Numbers(pos)
            if #n >= 3 then pt.off.x, pt.off.y, pt.off.z = n[1], n[2], n[3] CX.WriteSliders(pt) moved, typed = true, true end
        end
        if rot ~= CX.rotTxt then
            CX.rotTxt = rot
            local n = CX.Numbers(rot)
            if #n >= 3 then pt.rot.x, pt.rot.y, pt.rot.z = n[1], n[2], n[3] CX.WriteSliders(pt) moved, typed = true, true end
        end
        -- Ctrl+Z = Undo, Ctrl+Y = Redo (any time you're building, unless you're typing in a box)
        if not F.Typing() then
            local ctrl = Utils.IsKeyDown(0x11)
            local z, y = ctrl and Utils.IsKeyDown(0x5A), ctrl and Utils.IsKeyDown(0x59)
            if z and not CX.zWas then Job("undoing", CX.Undo) end
            if y and not CX.yWas then Job("redoing", CX.Redo) end
            CX.zWas, CX.yWas = z, y
        end
        -- MOVE WITH KEYS (Stand's Free Edit): numpad 4/6 left-right, 8/2 front-back, 9/3 up-down,
        -- 7/1 turn; hold Shift for 8/2 tilt and 4/6 roll. One step per frame at the chosen step size.
        if F.cxKeys:IsToggled() and not F.Typing() then
            local step, rstep = CX.STEPS[st + 1] or 0.01, CX.RSTEPS[rst + 1] or 1.0
            local function K(vk) return Utils.IsKeyDown(vk) end
            -- (Alt or Shift: with Num Lock on, Windows turns Shift + numpad 8/2/4/6 into the arrow keys)
            local shift = K(0x10) or K(0x12)
            local d = { x = 0, y = 0, z = 0 }
            local r = { x = 0, y = 0, z = 0 }
            if shift or K(0x26) or K(0x28) or K(0x25) or K(0x27) then
                if K(0x68) or K(0x26) then r.x = r.x + rstep end
                if K(0x62) or K(0x28) then r.x = r.x - rstep end
                if K(0x66) or K(0x27) then r.y = r.y + rstep end
                if K(0x64) or K(0x25) then r.y = r.y - rstep end
            else
                if K(0x66) then d.x = d.x + step end
                if K(0x64) then d.x = d.x - step end
                if K(0x68) then d.y = d.y + step end
                if K(0x62) then d.y = d.y - step end
            end
            if K(0x69) then d.z = d.z + step end
            if K(0x63) then d.z = d.z - step end
            if K(0x67) then r.z = r.z + rstep end
            if K(0x61) then r.z = r.z - rstep end
            if d.x ~= 0 or d.y ~= 0 or d.z ~= 0 or r.x ~= 0 or r.y ~= 0 or r.z ~= 0 then
                pt.off.x, pt.off.y, pt.off.z = pt.off.x + d.x, pt.off.y + d.y, pt.off.z + d.z
                pt.rot.x, pt.rot.y, pt.rot.z = pt.rot.x + r.x, pt.rot.y + r.y, pt.rot.z + r.z
                CX.WriteSliders(pt)
                CX.keyBoxAt = NowMs()
                moved, shifted = true, true
            end
        end
        if CX.keyBoxAt and NowMs() - CX.keyBoxAt > 150 then CX.keyBoxAt = nil CX.WriteBoxes(pt) end
        -- bone, collision, visible, alpha
        local bi = F.cxBone:GetListIndex() or 0
        if bi ~= CX.lastBone then
            CX.lastBone = bi
            local bn = CX.BONES[bi + 1]
            pt.boneName = bn and bn[2] or nil
            pt.bone = bn and bn[2] and CX.BoneIndex(pt) or 0
            if bn and bn[2] and pt.bone == 0 and not pt.parent then Notify("Constructor: this base has no " .. bn[1] .. " - stuck to the centre", true, "spawner") end
            moved = true
        end
        local col = F.cxCol:IsToggled()
        if col ~= (pt.col == true) then pt.col = col moved = true end
        local vis = F.cxVis:IsToggled()
        if vis ~= (pt.vis ~= false) then pt.vis = vis look = true end
        local al = math.floor(F.cxAlpha:GetIntValue() or 255)
        if al ~= math.floor(pt.alpha or 255) then pt.alpha = al look = true end
        local tn = math.floor(F.cxTint:GetIntValue() or 0)
        if tn ~= math.floor(pt.tint or 0) then pt.tint = tn look = true end
        -- LOCKED: it doesn't move - everything goes back to how it is
        if pt.locked and (moved or look) then
            CX.ApplyState(pt, before)
            CX.sel = nil
            if NowMs() - (CX.lockSaidAt or 0) > 2500 then
                CX.lockSaidAt = NowMs()
                Notify("Constructor: " .. CX.PartLabel(pt) .. " is locked - unlock it to move it", true, "spawner")
            end
            return
        end
        -- SNAP: moves land on the grid of the Move Step, turns on the Turn Step (typed numbers stay as typed)
        if shifted and not typed then
            local snapped = false
            if F.cxSnap:IsToggled() then
                local step = CX.STEPS[st + 1] or 0.01
                for _, a in ipairs({ "x", "y", "z" }) do
                    local v = Snap(pt.off[a], step)
                    if math.abs(v - pt.off[a]) > 0.00001 then pt.off[a] = v snapped = true end
                end
            end
            if F.cxSnapRot:IsToggled() then
                local rstep = CX.RSTEPS[rst + 1] or 1.0
                for _, a in ipairs({ "x", "y", "z" }) do
                    local v = Snap(pt.rot[a], rstep)
                    if math.abs(v - pt.rot[a]) > 0.00001 then pt.rot[a] = v snapped = true end
                end
            end
            if snapped then CX.WriteSliders(pt) CX.WriteBoxes(pt) end
        end
        if moved or look then
            -- MOVE TOGETHER: the other picked parts (on the same thing) move / turn by the same amount
            local others = {}
            if moved and pt.grp then
                for _, q in ipairs(b.parts) do
                    if q ~= pt and q.grp and not q.locked and q.parent == pt.parent then others[#others + 1] = q end
                end
            end
            -- one undo step per drag / key hold: a new step starts after a short pause or on another part
            local now = NowMs()
            if CX.snapPt ~= pt or now - (CX.snapAt or 0) > 700 then
                local list = { { op = "state", pt = pt, s = before } }
                for _, q in ipairs(others) do list[#list + 1] = { op = "state", pt = q, s = CX.Snapshot(q) } end
                local what = (#others > 0 and ("moving " .. (#others + 1) .. " parts") or ("changing " .. CX.PartLabel(pt)))
                CX.Push(#list == 1 and { op = "state", pt = pt, s = before, what = what } or { op = "group", list = list, what = what })
            end
            CX.snapPt, CX.snapAt = pt, now
            CX.dirty, CX.unsaved = true, true -- (autosave picks up the end of a long drag too)
            if #others > 0 then
                local dx, dy, dz = pt.off.x - before.off.x, pt.off.y - before.off.y, pt.off.z - before.off.z
                local rx, ry, rz = pt.rot.x - before.rot.x, pt.rot.y - before.rot.y, pt.rot.z - before.rot.z
                for _, q in ipairs(others) do
                    q.off.x, q.off.y, q.off.z = q.off.x + dx, q.off.y + dy, q.off.z + dz
                    q.rot.x, q.rot.y, q.rot.z = q.rot.x + rx, q.rot.y + ry, q.rot.z + rz
                    CX.Attach(q)
                end
            end
        end
        if moved then CX.Attach(pt) end
        if look then CX.Look(pt) end
        -- base shown / hidden
        local bv = F.cxBaseVis:IsToggled()
        if b.baseVis ~= bv then
            b.baseVis = bv
            if bv then
                LGX.hidden[b.car] = nil
                nv(0xEA1C610A04DB6BBB, b.car, true, false)
                nv(0x9B1E824FFBB7027A, b.car) -- RESET_ENTITY_ALPHA
            else
                LGX.KeepHidden(b.car) -- (kept hidden - Cherax's spawner fade used to show a new base again)
            end
        end
    end
    function CX.PickedRoot()
        local e = CX.LoadedPicked()
        if e and e.root and IB(0x7239B21A38F536BA, e.root) then return e.root, e end
        Notify("Constructor: pick a spawned construct first", true, "spawner")
        return nil
    end

    -- ----- saving (Stand Constructor's format, so Stand users can load it too) -----
    function CX.Json(v, ind)
        ind = ind or ""
        local t = type(v)
        if t == "table" then
            local isList = v.__list == true or v[1] ~= nil
            local nx = ind .. "  "
            local out = {}
            if isList then
                for _, e in ipairs(v) do out[#out + 1] = nx .. CX.Json(e, nx) end
                return #out == 0 and "[]" or ("[\n" .. table.concat(out, ",\n") .. "\n" .. ind .. "]")
            end
            local keys = {}
            for k in pairs(v) do if k ~= "__list" then keys[#keys + 1] = tostring(k) end end
            table.sort(keys)
            for _, k in ipairs(keys) do out[#out + 1] = nx .. CX.Json(k) .. ": " .. CX.Json(v[k], nx) end
            return #out == 0 and "{}" or ("{\n" .. table.concat(out, ",\n") .. "\n" .. ind .. "}")
        elseif t == "string" then
            return '"' .. v:gsub('[%c"\\]', function(c)
                local m = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
                return m[c] or string.format("\\u%04x", c:byte())
            end) .. '"'
        elseif t == "number" then
            if v ~= v or v == math.huge or v == -math.huge then return "0" end
            if math.floor(v) == v and math.abs(v) < 2^53 then return string.format("%d", v) end
            return string.format("%.4f", v)
        elseif t == "boolean" then return v and "true" or "false" end
        return "null"
    end
    local function Ints(n) local t = {} for i = 1, n do t[i] = Memory.AllocInt() end return t end
    local function Read(p) local out = {} for i, a in ipairs(p) do out[i] = Memory.ReadInt(a) or 0 Memory.Free(a) end return out end
    function CX.VehicleAttributes(car)
        local va = { paint = {}, neon = { lights = {} }, wheels = {}, mods = {}, extras = {}, options = {}, headlights = {} }
        pcall(function()
            local c = Ints(2) nv(0xA19435F193E081AC, car, c[1], c[2]) c = Read(c) -- GET_VEHICLE_COLOURS
            local e = Ints(2) nv(0x3BC4245933A166F7, car, e[1], e[2]) e = Read(e) -- GET_VEHICLE_EXTRA_COLOURS
            va.paint.primary = { vehicle_standard_color = c[1], is_custom = IB(0xF095C0405307B21B, car) }
            va.paint.secondary = { vehicle_standard_color = c[2], is_custom = IB(0x910A32E7AAD2656C, car) }
            if va.paint.primary.is_custom then
                local r = Ints(3) nv(0xB64CF2CCA9D95F52, car, r[1], r[2], r[3]) r = Read(r)
                va.paint.primary.custom_color = { r = r[1], g = r[2], b = r[3] }
            end
            if va.paint.secondary.is_custom then
                local r = Ints(3) nv(0x8389CD56CA8072DC, car, r[1], r[2], r[3]) r = Read(r)
                va.paint.secondary.custom_color = { r = r[1], g = r[2], b = r[3] }
            end
            va.paint.extra_colors = { pearlescent = e[1], wheel = e[2] }
            local i5 = Ints(1) nv(0x7D1464D472D32136, car, i5[1]) va.paint.interior_color = Read(i5)[1]
            local i6 = Ints(1) nv(0xB7635E80A5C31BFF, car, i6[1]) va.paint.dashboard_color = Read(i6)[1]
            va.paint.livery = Natives.InvokeInt(0x2BB9230590DA5E8A, car)
            for i, k in ipairs({ "left", "right", "front", "back" }) do va.neon.lights[k] = IB(0x8C4B92553E4766A5, car, i - 1) end
            local n = Ints(3) nv(0x7619EEE8C886757F, car, n[1], n[2], n[3]) n = Read(n)
            va.neon.color = { r = n[1], g = n[2], b = n[3] }
            va.wheels.wheel_type = Natives.InvokeInt(0xB3ED1BFB4BE636DC, car)
            local s = Ints(3) nv(0xB635392A4938B3C3, car, s[1], s[2], s[3]) s = Read(s)
            va.wheels.tire_smoke_color = { r = s[1], g = s[2], b = s[3] }
            for m = 0, 49 do
                if m >= 17 and m <= 22 then va.mods["_" .. m] = IB(0x84B233A8C8FC8AE7, car, m)
                else va.mods["_" .. m] = Natives.InvokeInt(0x772960298DA26FDB, car, m) end
            end
            for x = 1, 14 do
                if IB(0x1262D55792428154, car, x) then va.extras["_" .. x] = IB(0xD2E6822DBFD6C8BD, car, x) end -- DOES_EXTRA_EXIST / IS_VEHICLE_EXTRA_TURNED_ON
            end
            local okP, plate = pcall(Natives.InvokeString, 0x7CE1CCB9B293020E, car)
            va.options.license_plate_text = okP and plate or nil
            va.options.license_plate_type = Natives.InvokeInt(0xF11BC2DD9A3E7195, car)
            va.options.window_tint = Natives.InvokeInt(0x0EE21293DAD47C95, car)
            va.headlights.headlights_color = Natives.InvokeInt(0x3DFF319A831E0CDB, car)
        end)
        return va
    end
    -- a part as a saved "child" (Stand Constructor's format) - with what's stuck on it inside it
    function CX.ChildOut(pt, kids)
        local c = {
            name = CX.PartLabel(pt), hash = pt.model % 4294967296,
            model = pt.modelName or string.format("0x%08X", pt.model % 4294967296),
            type = pt.kind == 2 and "VEHICLE" or (pt.kind == 1 and "PED" or "OBJECT"),
            offset = { x = pt.off.x, y = pt.off.y, z = pt.off.z }, rotation = { x = pt.rot.x, y = pt.rot.y, z = pt.rot.z },
            options = { bone_index = pt.bone or 0, has_collision = pt.col == true, is_visible = pt.vis ~= false,
                        alpha = math.floor(pt.alpha or 255), is_attached = true, lgn_locked = pt.locked or nil,
                        tint = (pt.tint and pt.tint > 0) and math.floor(pt.tint) or nil },
            lgn_bone_name = pt.boneName,
        }
        local list = kids and kids[pt]
        if list and #list > 0 then
            c.children = { __list = true }
            for _, q in ipairs(list) do c.children[#c.children + 1] = CX.ChildOut(q, kids) end
        end
        return c
    end
    -- the whole build (or just some parts of it) in Stand Constructor's format
    function CX.BuildOut(name, only)
        local b = CX.b
        local model = Natives.InvokeInt(0x9F47B058362C84B5, b.car) % 4294967296
        local isVeh = IB(0x19AAC8F07BFEC53E, model)
        local out = { name = name, hash = model, model = string.format("0x%08X", model), type = isVeh and "VEHICLE" or "OBJECT",
                      children = { __list = true } }
        if isVeh then out.vehicle_attributes = CX.VehicleAttributes(b.car) end
        out.options = { is_visible = IB(0x47D6F43D77935C75, b.car), is_frozen = b.entry.frozen == true or nil }
        local kids, n = {}, 0
        for _, pt in ipairs(b.parts) do
            if IB(0x7239B21A38F536BA, pt.h) and (not only or only[pt]) then
                local p = pt.parent
                if p and not (only and not only[p]) and IB(0x7239B21A38F536BA, p.h or 0) then
                    kids[p] = kids[p] or {}
                    table.insert(kids[p], pt)
                else
                    out.children[#out.children + 1] = pt -- (filled in below)
                end
                n = n + 1
            end
        end
        for i, pt in ipairs(out.children) do out.children[i] = CX.ChildOut(pt, kids) end
        return out, n
    end
    function CX.Save()
        local b = CX.b
        if not b or not IB(0x7239B21A38F536BA, b.car) then Notify("Constructor: start a construct first", true, "spawner") return end
        local name = tostring(F.cxName:GetStringValue() or ""):gsub('[\\/:%*%?"<>|]', ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then Notify("Constructor: type a name in 'Construct Name' first", true, "spawner") return end
        local out, n = CX.BuildOut(name)
        if (b.entry.extra or 0) > 0 then
            Notify(("Constructor: %d thing(s) in this construct stand on their own (not stuck to it) - they aren't saved")
                :format(b.entry.extra), true, "spawner")
        end
        local path = CX.Root() .. "\\" .. name .. ".json"
        -- (a construct with this name already there, and it isn't the one you're editing: press Save again to replace it)
        local okE, exists = pcall(FileMgr.DoesFileExist, path)
        if okE and exists and (b.entry.name or ""):lower() ~= name:lower() then
            local c = CX.saveAsk
            if not (c and c.name == name:lower() and NowMs() - c.at < 6000) then
                CX.saveAsk = { name = name:lower(), at = NowMs() }
                Notify("Constructor: there's already a construct called " .. name .. " - press Save Construct again to replace it", true, "spawner")
                return
            end
        end
        CX.saveAsk = nil
        local ok = pcall(FileMgr.WriteFileContent, path, CX.Json(out) .. "\n", false)
        if ok then
            b.entry.name, b.entry.path = name, path
            CX.loadedSig, CX.nextScan, CX.dirty, CX.unsaved = nil, 0, false, false
            Notify("Constructor: saved " .. name .. " (" .. n .. " part(s)) - it's under LGN Constructs", true, "spawner")
        else
            Notify("Constructor: couldn't save to " .. path, true, "spawner")
        end
    end

    -- ----- AUTOSAVE: the build you're editing is saved every minute (and when LGNFX stops), so a crash
    -- or a session change doesn't lose it - Restore Autosave brings it back -----
    function CX.AutoPath() return CfgDir() .. "\\constructor_autosave.json" end
    function CX.AutoSave(force)
        local b = CX.b
        if not b or not IB(0x7239B21A38F536BA, b.car) or #b.parts == 0 then return end
        if not CX.dirty and not force then return end
        local out, n = CX.BuildOut(b.entry.name or "My build")
        out.lgn_autosave_time = os and os.time and os.time() or nil
        if pcall(FileMgr.WriteFileContent, CX.AutoPath(), CX.Json(out) .. "\n", false) then
            CX.dirty = false
            CX.autoInfo = { name = b.entry.name or "My build", parts = n, at = out.lgn_autosave_time }
        end
    end
    function CX.ReadAutoInfo()
        local ok, txt = pcall(function() return FileMgr.DoesFileExist(CX.AutoPath()) and FileMgr.ReadFileContent(CX.AutoPath()) or "" end)
        if not ok or not txt or txt == "" then CX.autoInfo = nil return end
        local okJ, d = pcall(api.XS.ParseJSON, txt)
        local name = okJ and type(d) == "table" and type(d.name) == "string" and d.name or nil
        local at = tonumber(txt:match('"lgn_autosave_time"%s*:%s*(%d+)') or "")
        local _, parts = txt:gsub('"offset"', "")
        CX.autoInfo = { name = name or "My build", parts = parts, at = at }
    end
    function CX.RestoreAuto()
        local okR, content = pcall(FileMgr.ReadFileContent, CX.AutoPath())
        if not okR or not content or content == "" then Notify("Constructor: no autosave yet - it saves every minute while you build", true, "spawner") return end
        local plan, why = api.XS.PlanFromJSON(content)
        if not plan or #plan.items == 0 then Notify("Constructor: the autosave couldn't be read (" .. tostring(why) .. ")", true, "spawner") return end
        local name = (CX.autoInfo and CX.autoInfo.name or "My build") .. " (autosave)"
        local e = api.SpawnPlan(plan, name)
        if e and e.root then CX.Begin(e.root, e) end
    end

    -- ----- KITS: a group of parts saved on its own, to stick on any build (LGN Constructs / kits) -----
    function CX.KitDir() return CX.Root() .. "\\kits" end
    function CX.SaveKit()
        local b = CX.b
        if not b or #b.parts == 0 then Notify("Constructor: build something first - a kit is some of its parts", true, "spawner") return end
        local name = tostring(F.cxKitName:GetStringValue() or ""):gsub('[\\/:%*%?"<>|]', ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then Notify("Constructor: type a name in 'Kit Name' first", true, "spawner") return end
        -- the parts picked for Move Together (and what's on them) - or every part if none are picked
        local only, any = {}, false
        for _, pt in ipairs(b.parts) do if pt.grp then any = true end end
        for _, pt in ipairs(b.parts) do
            local p, inGrp = pt, false
            while p do if p.grp then inGrp = true break end p = p.parent end
            if not any or inGrp then only[pt] = true end
        end
        local out, n = CX.BuildOut(name, only)
        -- (a kit sits on a cone, so it can also be spawned on its own from the Spawn tab)
        local cone = Utils.Joaat("prop_roadcone01b") % 4294967296
        out.hash, out.model, out.type, out.vehicle_attributes = cone, "prop_roadcone01b", "OBJECT", nil
        out.options = { is_visible = true, is_frozen = true }
        out.lgn_kit = true
        pcall(FileMgr.CreateDir, CX.KitDir())
        local ok = pcall(FileMgr.WriteFileContent, CX.KitDir() .. "\\" .. name .. ".json", CX.Json(out) .. "\n", false)
        CX.nextScan = 0
        Notify(ok and ("Constructor: saved kit " .. name .. " (" .. n .. " part(s)) - add it to any build on the Build tab")
            or "Constructor: couldn't save the kit", true, "spawner")
    end
    function CX.PickedKit() return (CX.kits or {})[(F.cxKit:GetListIndex() or 0) + 1] end
    function CX.AddKit()
        local b = CX.b
        if not b or not IB(0x7239B21A38F536BA, b.car) then Notify("Constructor: start a construct first", true, "spawner") return end
        local k = CX.PickedKit()
        if not k then Notify("Constructor: no kits yet - save some parts as a kit first", true, "spawner") return end
        local okR, content = pcall(FileMgr.ReadFileContent, k.path)
        local okJ, data = pcall(api.XS.ParseJSON, okR and content or "")
        if not okJ or type(data) ~= "table" then Notify("Constructor: couldn't read the kit " .. k.name, true, "spawner") return end
        local list = {}
        local function AddFrom(c, parent, depth)
            if type(c) ~= "table" or depth > 8 then return end
            local o = type(c.options) == "table" and c.options or {}
            local model = (type(c.model) == "string" and c.model ~= "" and not c.model:match("^%s*0[xX]")) and c.model or tonumber(c.hash)
            local h, hash, kind = CX.SpawnPart(model, c.name)
            if not h then return end
            if CX.b ~= b then api.Remove(h) return end
            local off, rot = type(c.offset) == "table" and c.offset or {}, type(c.rotation) == "table" and c.rotation or {}
            local pt = { h = h, model = hash, name = c.name, modelName = type(model) == "string" and model or nil, kind = kind,
                         boneName = c.lgn_bone_name, bone = tonumber(o.bone_index) or 0, col = o.has_collision == true,
                         vis = o.is_visible ~= false, alpha = tonumber(o.alpha) or 255, tint = tonumber(o.tint), parent = parent, locked = o.lgn_locked == true or nil,
                         off = { x = tonumber(off.x) or 0, y = tonumber(off.y) or 0, z = tonumber(off.z) or 0 },
                         rot = { x = tonumber(rot.x) or 0, y = tonumber(rot.y) or 0, z = tonumber(rot.z) or 0 } }
            if pt.boneName and not parent then pt.bone = CX.BoneIndex(pt) end -- (the same bone on THIS car)
            CX.AddRaw(pt)
            list[#list + 1] = { op = "take", pt = pt }
            for _, cc in ipairs(type(c.children) == "table" and c.children or {}) do AddFrom(cc, pt, depth + 1) end
        end
        for _, c in ipairs(type(data.children) == "table" and data.children or {}) do AddFrom(c, nil, 0) end
        if #list == 0 then Notify("Constructor: the kit " .. k.name .. " has no parts in it", true, "spawner") return end
        -- (one Undo takes the whole kit off, parts on parts last-first)
        local rev = {}
        for i = #list, 1, -1 do rev[#rev + 1] = list[i] end
        CX.Push({ op = "group", list = rev, what = "adding the kit " .. k.name })
        CX.PartList()
        F.cxPart:SetListIndex(CX.Row(b.parts[#b.parts]))
        Notify("Constructor: added the kit " .. k.name .. " (" .. #list .. " part(s))", true, "spawner")
    end
    function CX.ShowKits()
        local kits = {}
        local dirL = CX.KitDir():lower()
        for _, f in ipairs(CX.files or {}) do
            if f.path:lower():sub(1, #dirL + 1) == dirL .. "\\" and f.kind == "json" then kits[#kits + 1] = f end
        end
        CX.kits = kits
        local names = {}
        for i, f in ipairs(kits) do names[i] = f.name end
        if #names == 0 then names = { "(no kits yet - pick parts and press Save Parts As Kit)" } end
        pcall(function()
            local keep = F.cxKit:GetListIndex() or 0
            F.cxKit:SetList(names)
            F.cxKit:SetListIndex(math.min(keep, #names - 1))
        end)
    end

    -- ----- menu -----
    F.cxSearch = FeatureMgr.AddFeature(H.cxSearch, "Search Constructs", eFeatureType.InputText,
        "Type part of a name to find a construct in any folder (e.g. 'bus' or 'monster')")
    pcall(function() F.cxSearch:SetSaveable(false) end)
    F.cxDir = FeatureMgr.AddFeature(H.cxDir, "Construct Folder", eFeatureType.Combo,
        "LGN Constructs = Lua\\CE - what you save here, and where to drop constructs (Stand Constructor .json, " ..
        "Cherax .json, Menyoo .xml). Cherax Saved Vehicles = the vehicles you've saved with Cherax (Cherax\\Vehicles)")
    F.cxList = FeatureMgr.AddFeature(H.cxList, "Construct", eFeatureType.Combo, "Constructs in the folder picked above")
    F.cxSpawn = Button(H.cxSpawn, "Spawn Construct", "Spawns the picked construct", function() Job("spawning construct", CX.SpawnPicked) end)
    F.cxRefresh = Button(H.cxRefresh, "Refresh Constructs", "Looks in the folders again right now",
        function() Try("refreshing constructs", CX.Refresh, true) end)
    F.cxFolders = Button(H.cxFolders, "Show Construct Folders", "Shows where constructs are read from", function()
        local t = {}
        for _, s in ipairs(CX.Sources()) do t[#t + 1] = s.label .. ": " .. s.dir end
        Notify(table.concat(t, "   |   "), true, "spawner")
    end)
    F.cxLoaded = FeatureMgr.AddFeature(H.cxLoaded, "Spawned Construct", eFeatureType.Combo,
        "Everything you've spawned from constructs and XML / JSON files (and builds you've started)")
    F.cxGetIn = Button(H.cxGetIn, "Get In It", "Puts you in the driver's seat of the picked construct", function()
        local e = CX.LoadedPicked()
        if e and e.root and IB(0x7239B21A38F536BA, e.root) then nv(0xF75B0D629E1C063D, Me(), e.root, -1)
        else Notify("Constructor: that one has no vehicle to get in", true, "spawner") end
    end)
    F.cxEdit = Button(H.cxEdit, "Edit It", "Opens the picked construct for editing - add parts on the Build tab, move them on Edit Part",
        function()
            local e = CX.LoadedPicked()
            if e and e.root and IB(0x7239B21A38F536BA, e.root) then CX.Begin(e.root, e)
            else Notify("Constructor: pick a spawned construct first", true, "spawner") end
        end)
    F.cxDelOne = Button(H.cxDelOne, "Delete It", "Removes the picked construct", function()
        local e = CX.LoadedPicked()
        if not e then return end
        Job("deleting construct", function()
            local plan = api.EntryPlan and api.EntryPlan(e)
            CX.DeleteEntry(e)
            CX.loadedSig = nil
            if not (plan and api.OfferBack({ plan }, e.name)) then Notify("Deleted " .. e.name, true, "spawner") end
        end)
    end)
    F.cxRename = FeatureMgr.AddFeature(H.cxRename, "Name In List", eFeatureType.InputText,
        "The picked construct's name in this list - type a new one and press Rename It (handy when several are out)")
    F.cxRenameIt = Button(H.cxRenameIt, "Rename It", "Gives the picked construct the name typed above - its saved file in Lua\\CE is renamed too (if it has one there)",
        function()
            local e = CX.LoadedPicked()
            if not e then Notify("Constructor: pick a spawned construct first", true, "spawner") return end
            local name = tostring(F.cxRename:GetStringValue() or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if name == "" then Notify("Constructor: type a name in 'Name In List' first", true, "spawner") return end
            local old = e.name
            -- (its file in Lua\CE gets the new name too - never a file outside it, never over another construct)
            local p = e.path
            local root = CX.Root():lower() .. "\\"
            if p and p:lower():sub(1, #root) == root then
                local clean = name:gsub('[\\/:%*%?"<>|]', "")
                local dir, ext = p:match("^(.*\\)[^\\]+(%.%w+)$")
                local np = dir and (dir .. clean .. ext)
                if np and np:lower() ~= p:lower() then
                    local okE, there = pcall(FileMgr.DoesFileExist, np)
                    if okE and there then Notify("Constructor: there's already a construct called " .. clean .. " - pick another name", true, "spawner") return end
                    local okR, content = pcall(FileMgr.ReadFileContent, p)
                    if not okR or not content or content == "" or not pcall(FileMgr.WriteFileContent, np, content, false) then
                        Notify("Constructor: couldn't rename the file " .. tostring(p), true, "spawner") return
                    end
                    pcall(FileMgr.DeleteFile, p)
                    e.path = np
                    CX.nextScan = 0
                end
            end
            e.name = name
            CX.loadedSig, CX.renKey = nil, nil
            -- (the build you're editing: Save Construct uses the new name too, unless you've typed one)
            if CX.b and CX.b.entry == e and tostring(F.cxName:GetStringValue() or "") == "" then
                pcall(function() F.cxName:SetStringValue(name) end)
            end
            Notify("Renamed " .. tostring(old) .. " to " .. name, true, "spawner")
        end)
    F.cxFav = Button(H.cxFav, "Favourite Construct (add/remove)",
        "Adds the picked construct to * Favourites at the top of the Folder list (or takes it off). " ..
        "* Recent there has the last 10 you spawned", function() Try("favourite construct", CX.ToggleFav) end)
    F.cxUndo = Button(H.cxUndo, "Undo",
        "Takes back the last change to the build you're editing - a move, turn or setting, an added / duplicated part, " ..
        "or a removed part (30 steps). Ctrl+Z does it too", function() Job("undoing", CX.Undo) end)
    F.cxStart = Button(H.cxStart, "Start From My Vehicle",
        "The vehicle you're in becomes the base of a new construct (or opens it for editing if you spawned it from a construct)",
        function()
            local me = Me()
            local veh = IB(0x997ABD671D25CA0B, me, false) and Natives.InvokeInt(0x9A9112A0FE9A4713, me, false) or 0 -- IS_PED_IN_ANY_VEHICLE / GET_VEHICLE_PED_IS_IN
            if not veh or veh == 0 then Notify("Constructor: get in a vehicle first", true, "spawner") return end
            if F.notMyCar(veh) then Notify("Constructor: that's another player's car - build on your own", true, "spawner") return end
            CX.Begin(veh)
        end)
    F.cxVehName = FeatureMgr.AddFeature(H.cxVehName, "Vehicle Name", eFeatureType.InputText,
        "The vehicle to build on (e.g. adder, pbus2, monster, bati) - then press Start From Vehicle Name")
    F.cxFromVeh = Button(H.cxFromVeh, "Start From Vehicle Name", "Spawns that vehicle in front of you and makes it the base of a new construct",
        function() Job("new construct", CX.NewBase, false) end)
    F.cxFromCone = Button(H.cxFromCone, "Start A Map (Construction Cone)",
        "A frozen construction cone in front of you becomes the base of a map / structure - stick ramps, walls, anything on it",
        function() Job("new map construct", CX.NewBase, true) end)
    F.cxBaseVis = Toggle(H.cxBaseVis, "Base Visible", "Off = the base vehicle / cone is hidden and only its parts show (for everyone)", true)

    local cnames = {}
    for i, c in ipairs(CX.CATS) do cnames[i] = c.name end
    F.cxCat = FeatureMgr.AddFeature(H.cxCat, "Browse", eFeatureType.Combo,
        "Pick a category of objects (the same ones as the Objects tab), your search results, or Custom")
    F.cxCat:SetList(cnames)
    F.cxCat:SetListIndex(math.min(2, #cnames - 1))
    F.cxFind = FeatureMgr.AddFeature(H.cxFind, "Search All Objects", eFeatureType.InputText,
        "Type part of a name (e.g. 'neon', 'ramp', 'speaker') to search every object in the game - results show in Object To Add below. " ..
        "Prop names and IDs with pictures: forge.plebmasters.de/objects")
    F.cxObj = FeatureMgr.AddFeature(H.cxObj, "Object To Add", eFeatureType.Combo, "What to stick on")
    F.cxObjCustom = FeatureMgr.AddFeature(H.cxObjCustom, "Custom Object Model", eFeatureType.InputText,
        "Any object, vehicle or ped - its name (prop_beach_fire) or ID (0x1A2B3C4D or 123456). " ..
        "Find prop names / IDs here: forge.plebmasters.de/objects   (Browse must be on Custom)")
    F.cxAdd = Button(H.cxAdd, "Add Part", "Sticks the object onto your construct", function() Job("adding part", CX.Add) end)

    F.cxPart = FeatureMgr.AddFeature(H.cxPart, "Part", eFeatureType.Combo, "The part everything below changes")
    F.cxPartFind = FeatureMgr.AddFeature(H.cxPartFind, "Find Part", eFeatureType.InputText,
        "Type part of a part's name (e.g. 'wheel' or 'light') - the first part that matches is picked")
    pcall(function() F.cxPartFind:SetSaveable(false) end)
    function CX.FindPart(from)
        local b = CX.b
        local q = tostring(F.cxPartFind:GetStringValue() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if not b or q == "" or #b.parts == 0 then return false end
        if #CX.view ~= #b.parts then CX.BuildView() end
        for k = 0, #CX.view - 1 do
            local i = (from + k) % #CX.view + 1
            if CX.PartLabel(CX.view[i]):lower():find(q, 1, true) then
                F.cxPart:SetListIndex(i - 1)
                CX.sel = nil
                return true
            end
        end
        Notify('Constructor: no part matches "' .. q .. '"', true, "spawner", { merge = "cx find part" })
        return false
    end
    F.cxCopyPos = Button(H.cxCopyPos, "Copy Position", "Remembers the picked part's position and rotation, to paste onto another part",
        function()
            local pt = CX.PickedPart()
            if not pt then Notify("Constructor: pick a part first", true, "spawner") return end
            CX.clip = { off = { x = pt.off.x, y = pt.off.y, z = pt.off.z }, rot = { x = pt.rot.x, y = pt.rot.y, z = pt.rot.z }, name = CX.PartLabel(pt) }
            Notify("Constructor: copied where " .. CX.clip.name .. " sits - pick another part and press Paste Position", true, "spawner")
        end)
    F.cxPastePos = Button(H.cxPastePos, "Paste Position", "Puts the picked part where the copied one was (same position and rotation) - Undo puts it back",
        function()
            local pt, c = CX.PickedPart(), CX.clip
            if not pt then Notify("Constructor: pick a part first", true, "spawner") return end
            if not c then Notify("Constructor: press Copy Position on a part first", true, "spawner") return end
            if pt.locked then Notify("Constructor: " .. CX.PartLabel(pt) .. " is locked - unlock it first", true, "spawner") return end
            CX.Push({ op = "state", pt = pt, s = CX.Snapshot(pt), what = "pasting a position onto " .. CX.PartLabel(pt) })
            pt.off = { x = c.off.x, y = c.off.y, z = c.off.z }
            pt.rot = { x = c.rot.x, y = c.rot.y, z = c.rot.z }
            CX.Attach(pt)
            CX.sel = nil -- (the sliders and boxes show the new spot on the next tick)
            Notify("Constructor: " .. CX.PartLabel(pt) .. " moved to where " .. c.name .. " was", true, "spawner")
        end)
    function CX.SnapOnto()
        local a, t = CX.PickedPart(), CX.prevPt
        if not a then Notify("Constructor: pick a part first", true, "spawner") return end
        if not t or t == a or not CX.IndexOf(t) then
            Notify("Constructor: pick the part to snap onto first, then the part to move, then press Snap Onto Part", true, "spawner") return
        end
        if a.parent ~= t.parent or (a.boneName or "") ~= (t.boneName or "") then
            Notify("Constructor: both parts need to be stuck to the same thing to snap together", true, "spawner") return
        end
        if a.locked then Notify("Constructor: " .. CX.PartLabel(a) .. " is locked - unlock it first", true, "spawner") return end
        -- each part's box (its model's size, where it sits) - straight parts snap exactly, turned ones near enough
        local function Box(p)
            local x0, y0, z0, x1, y1, z1 = F.LX.Dims(p.model)
            return { x = (x0 + x1) / 2, y = (y0 + y1) / 2, z = (z0 + z1) / 2 },
                   { x = (x1 - x0) / 2, y = (y1 - y0) / 2, z = (z1 - z0) / 2 }
        end
        local la, ha = Box(a)
        local lt, ht = Box(t)
        local best, bestR = "z", -1
        for _, k in ipairs({ "x", "y", "z" }) do
            local d = (a.off[k] + la[k]) - (t.off[k] + lt[k])
            local r = math.abs(d) / math.max(0.01, ha[k] + ht[k])
            if r > bestR then best, bestR = k, r end
        end
        local d = (a.off[best] + la[best]) - (t.off[best] + lt[best])
        local side = d >= 0 and 1 or -1
        CX.Push({ op = "state", pt = a, s = CX.Snapshot(a), what = "snapping " .. CX.PartLabel(a) })
        a.off[best] = (t.off[best] + lt[best]) + side * (ha[best] + ht[best]) - la[best]
        CX.Attach(a)
        CX.sel = nil
        Notify("Constructor: " .. CX.PartLabel(a) .. " snapped onto " .. CX.PartLabel(t), true, "spawner")
    end
    F.cxSnapTo = Button(H.cxSnapTo, "Snap Onto Part",
        "Pick the part to snap onto, then the part to move, then press this - it goes flush against the side it's nearest (Undo puts it back)",
        function() Try("snapping a part", CX.SnapOnto) end)
    local DIRS = { "Up", "Down", "Forward", "Back", "Left", "Right", "Turn Left", "Turn Right" }
    F.cxAllDir = FeatureMgr.AddFeature(H.cxAllDir, "Which Way", eFeatureType.Combo, "Which way Move Whole Build moves it (by the Move Step / Turn Step)")
    F.cxAllDir:SetList(DIRS)
    function CX.MoveAll()
        local b = CX.b
        if not b or #b.parts == 0 then Notify("Constructor: start or open a build with parts first", true, "spawner") return end
        local i = (F.cxAllDir:GetListIndex() or 0) + 1
        local step = CX.STEPS[(F.cxStep:GetListIndex() or 1) + 1] or 0.01
        local turn = math.rad(CX.RSTEPS[(F.cxRStep:GetListIndex() or 1) + 1] or 1.0) * (i == 7 and 1 or -1)
        local d = ({ { 0, 0, 1 }, { 0, 0, -1 }, { 0, 1, 0 }, { 0, -1, 0 }, { -1, 0, 0 }, { 1, 0, 0 } })[i]
        local list, skipped = {}, 0
        for _, p in ipairs(b.parts) do
            -- (parts stuck on other parts go along with them; locked parts stay put)
            if not (p.parent and CX.IndexOf(p.parent)) then
                if p.locked or (i >= 7 and p.boneName) then skipped = skipped + 1
                else
                    list[#list + 1] = { op = "state", pt = p, s = CX.Snapshot(p) }
                    if d then
                        p.off.x, p.off.y, p.off.z = p.off.x + d[1] * step, p.off.y + d[2] * step, p.off.z + d[3] * step
                    else
                        local x, y = p.off.x, p.off.y
                        p.off.x, p.off.y = x * math.cos(turn) - y * math.sin(turn), x * math.sin(turn) + y * math.cos(turn)
                        p.rot.z = p.rot.z + math.deg(turn)
                    end
                    CX.Attach(p)
                end
            end
        end
        if #list == 0 then Notify("Constructor: nothing to move (every part is locked)", true, "spawner") return end
        CX.Push({ op = "group", list = list, what = "moving the whole build" })
        CX.sel = nil
        Notify("Constructor: whole build moved " .. DIRS[i]:lower() .. (skipped > 0 and (" (" .. skipped .. " locked / on a wheel or door left where they are)") or ""),
            true, "spawner", { merge = "cx move all" })
    end
    F.cxAllMove = Button(H.cxAllMove, "Move Whole Build", "Moves every part together the way picked above - one Move Step, or turned one Turn Step (Undo puts it back)",
        function() Try("moving the whole build", CX.MoveAll) end)
    F.cxPartNext = Button(H.cxPartNext, "Next Match", "Picks the next part that matches Find Part",
        function() Try("finding part", CX.FindPart, (F.cxPart:GetListIndex() or 0) + 1) end)
    F.cxDup = Button(H.cxDup, "Duplicate Part", "Makes a copy of the picked part, one Move Step to the side so you can see it - the copy is picked, ready to move",
        function() Job("duplicating part", CX.Duplicate) end)
    F.cxMirX = Button(H.cxMirX, "Mirror Copy: Left / Right", "A copy on the other side (left <-> right), turned to match",
        function() Job("mirroring part", CX.Duplicate, "x") end)
    F.cxMirY = Button(H.cxMirY, "Mirror Copy: Front / Back", "A copy at the other end (front <-> back)",
        function() Job("mirroring part", CX.Duplicate, "y") end)
    F.cxMirZ = Button(H.cxMirZ, "Mirror Copy: Up / Down", "A copy flipped up <-> down",
        function() Job("mirroring part", CX.Duplicate, "z") end)
    F.cxStep = FeatureMgr.AddFeature(H.cxStep, "Move Step", eFeatureType.Combo, "How far one click of the position sliders (and Move With Keys) moves the part")
    F.cxStep:SetList({ "0.001 m (tiny)", "0.01 m", "0.05 m", "0.1 m", "0.25 m", "0.5 m", "1 m (big)" })
    F.cxStep:SetListIndex(1)
    F.cxRStep = FeatureMgr.AddFeature(H.cxRStep, "Turn Step", eFeatureType.Combo, "How far one click of the rotation sliders (and Move With Keys) turns the part")
    F.cxRStep:SetList({ "0.1 deg (tiny)", "1 deg", "5 deg", "15 deg", "45 deg", "90 deg (big)" })
    F.cxRStep:SetListIndex(1)
    F.cxX = Slider(H.cxX, "Position Left / Right", eFeatureType.SliderFloat, "Moves the part sideways (metres)", -15.0, 15.0, 0.01, 0.0)
    F.cxY = Slider(H.cxY, "Position Back / Front", eFeatureType.SliderFloat, "Moves the part forwards / back (metres)", -15.0, 15.0, 0.01, 0.0)
    F.cxZ = Slider(H.cxZ, "Position Down / Up", eFeatureType.SliderFloat, "Moves the part up / down (metres)", -15.0, 15.0, 0.01, 0.0)
    F.cxPosExact = FeatureMgr.AddFeature(H.cxPosExact, "Exact Position (X Y Z)", eFeatureType.InputText,
        "Type the exact position - left/right, back/front, down/up in metres, e.g.  0 1.25 0.8  (no slider limits here)")
    F.cxRX = Slider(H.cxRX, "Rotation Pitch", eFeatureType.SliderFloat, "Tilts the part forwards / back (degrees)", -180.0, 180.0, 1.0, 0.0)
    F.cxRY = Slider(H.cxRY, "Rotation Roll", eFeatureType.SliderFloat, "Tilts the part sideways (degrees)", -180.0, 180.0, 1.0, 0.0)
    F.cxRZ = Slider(H.cxRZ, "Rotation Yaw", eFeatureType.SliderFloat, "Turns the part left / right (degrees)", -180.0, 180.0, 1.0, 0.0)
    F.cxRotExact = FeatureMgr.AddFeature(H.cxRotExact, "Exact Rotation (Pitch Roll Yaw)", eFeatureType.InputText,
        "Type the exact rotation in degrees, e.g.  0 0 90")
    F.cxKeys = Toggle(H.cxKeys, "Move With Keys (Numpad)",
        "Moves the picked part live: numpad 4/6 = left/right, 8/2 = front/back, 9/3 = up/down, 7/1 = turn. " ..
        "Hold Alt (or Shift): 8/2 = tilt, 4/6 = roll. Uses the Move / Turn Step. (Ctrl+Z / Ctrl+Y undo and redo with or without this)", false)
    local bnames = {}
    for i, bn in ipairs(CX.BONES) do bnames[i] = bn[1] end
    F.cxBone = FeatureMgr.AddFeature(H.cxBone, "Attach To", eFeatureType.Combo,
        "Which part of the base it's stuck to - on a wheel it spins with the wheel, on a door it swings with the door")
    F.cxBone:SetList(bnames)
    F.cxCol = Toggle(H.cxCol, "Part Has Collision", "On = the part is solid (things bump into it)", false)
    F.cxVis = Toggle(H.cxVis, "Part Visible", "Off = the part is hidden (for everyone)", true)
    F.cxAlpha = Slider(H.cxAlpha, "Part See-Through", eFeatureType.SliderInt, "255 = solid, lower = see-through", 0, 255, 5, 255)
    F.cxTint = Slider(H.cxTint, "Part Colour", eFeatureType.SliderInt,
        "The prop's colour version - lots of neon, light and sign props come in several colours. 0 = its normal colour (not every prop has others)", 0, 15, 1, 0)
    F.cxRem = Button(H.cxRem, "Remove Part", "Takes the picked part off (and anything stuck on it) - Undo puts it back",
        function() Job("removing part", CX.RemovePart) end)
    F.cxRedo = Button(H.cxRedo, "Redo", "Puts back what Undo took back (Ctrl+Y does it too)", function() Job("redoing", CX.Redo) end)
    F.cxPartName = FeatureMgr.AddFeature(H.cxPartName, "Part Name", eFeatureType.InputText,
        "The picked part's name in the list (and in the saved construct) - type a new one and press Rename Part")
    F.cxPartRename = Button(H.cxPartRename, "Rename Part", "Gives the picked part the name typed above", function() Try("renaming part", CX.RenamePart) end)
    F.cxLock = Button(H.cxLock, "Lock / Unlock Part", "A locked part can't be moved, turned or removed by accident - press again to unlock",
        function() Try("locking part", CX.ToggleLock) end)
    F.cxGrp = Button(H.cxGrp, "Pick / Unpick For Moving Together",
        "Picks the part for moving together - move any picked part and the rest move the same amount ([x] in the list)",
        function() Try("moving together", CX.GroupToggle) end)
    F.cxGrpAll = Button(H.cxGrpAll, "Pick Every Part", "Picks every part, so the whole build moves together", function() Try("moving together", CX.GroupToggle, "all") end)
    F.cxGrpNone = Button(H.cxGrpNone, "Unpick Every Part", "Nothing moves together any more", function() Try("moving together", CX.GroupToggle, "none") end)
    F.cxSnap = Toggle(H.cxSnap, "Snap To Grid", "Moves land on a grid the size of the Move Step (typed numbers stay as typed)", false)
    F.cxSnapRot = Toggle(H.cxSnapRot, "Snap Turns", "Turns land on the Turn Step - 15 deg, 45 deg, 90 deg...", false)
    F.cxAimAdd = Toggle(H.cxAimAdd, "New Parts Go Where I'm Looking",
        "Look at a spot on your build (centre of the screen - a green dot shows it) and Add Part puts it right there. " ..
        "Off (or looking away) = on top of the build", true)
    F.cxOnPart = Toggle(H.cxOnPart, "Add Onto The Picked Part",
        "New parts are stuck on the part picked on Edit Part (they move with it) instead of on the base", false)
    F.cxAutoRestore = Button(H.cxAutoRestore, "Restore Autosave",
        "Spawns the last autosaved build (saved every minute while you build) in front of you and opens it for editing",
        function() Job("restoring autosave", CX.RestoreAuto) end)
    F.cxKit = FeatureMgr.AddFeature(H.cxKit, "Kit", eFeatureType.Combo, "Your kits (Lua\\CE\\kits)")
    F.cxKitAdd = Button(H.cxKitAdd, "Add Kit To Build", "Sticks the picked kit's parts on your build, where they were on the build it came from",
        function() Job("adding kit", CX.AddKit) end)
    F.cxKitName = FeatureMgr.AddFeature(H.cxKitName, "Kit Name", eFeatureType.InputText, "The name to save the kit under")
    F.cxKitSave = Button(H.cxKitSave, "Save Parts As Kit",
        "Saves the parts picked for Moving Together (and what's on them) as a kit - or every part if none are picked",
        function() Try("saving kit", CX.SaveKit) end)
    F.unloadHooks = F.unloadHooks or {}
    table.insert(F.unloadHooks, function() pcall(CX.AutoSave, false) end)

    F.cxRide = Button(H.cxRide, "Ride In It", "Puts you in a passenger seat of the picked construct", function()
        local r = CX.PickedRoot()
        if r then nv(0xF75B0D629E1C063D, Me(), r, -2) end
    end)
    F.cxTpMe = Button(H.cxTpMe, "Teleport Me To It", "Takes you (and your vehicle) to the picked construct", function()
        local r = CX.PickedRoot()
        local p = r and EntityPos(r)
        if p then nv(0x9AFEFF481A85AB2E, Me(), p.x + 0.0, p.y + 0.0, p.z + 2.0) end -- SET_PED_COORDS_KEEP_VEHICLE
    end)
    F.cxTpIt = Button(H.cxTpIt, "Bring It To Me", "Moves the picked construct in front of you", function()
        Job("bringing construct", function()
            local r, e = CX.PickedRoot()
            local f = r and CX.Front(6.0)
            if not f then return end
            for _ = 1, 20 do
                if IB(0x01BF60A500E28887, r) then break end -- NETWORK_HAS_CONTROL_OF_ENTITY
                nv(0xB69317BF5E782347, r) Script.Yield(50) -- NETWORK_REQUEST_CONTROL_OF_ENTITY
            end
            nv(0x06843DA7060A026B, r, f.x + 0.0, f.y + 0.0, f.z + 0.5, false, false, false, false) -- SET_ENTITY_COORDS
            nv(0x8E2530AA8ADA980E, r, f.h + 0.0)
            if e.kind == "map" then nv(0x58A850EAEE20FAA3, r) else nv(0x49733E92263139D1, r, 5.0) end
        end)
    end)
    F.cxName = FeatureMgr.AddFeature(H.cxName, "Construct Name", eFeatureType.InputText, "The name it's saved under")
    F.cxSave = Button(H.cxSave, "Save Construct",
        "Saves your construct (the vehicle, its paint and mods, and every part) to Lua\\CE - in Stand Constructor's format",
        function() Try("saving construct", CX.Save) end)
    for _, k in ipairs({ "cxSearch", "cxDir", "cxList", "cxLoaded", "cxObj", "cxObjCustom", "cxPart", "cxX", "cxY", "cxZ",
                         "cxRX", "cxRY", "cxRZ", "cxCol", "cxName", "cxVehName", "cxBaseVis", "cxCat", "cxFind", "cxPosExact",
                         "cxRotExact", "cxKeys", "cxBone", "cxVis", "cxAlpha", "cxStep", "cxRStep", "cxRename", "cxPartName",
                         "cxKit", "cxKitName", "cxOnPart" }) do
        pcall(function() F[k]:SetSaveable(false) end)
    end
    pcall(CX.PartList)
    pcall(CX.ShowItems)
    pcall(CX.MoveOld)
    pcall(CX.Refresh, false)
    pcall(CX.LoadedList)
    pcall(CX.ShowKits)
    pcall(CX.ReadAutoInfo)

    F.drawConstructorAdd = function()
        CX.aimWantAt = NowMs()
        pcall(ImGui.TextDisabled, "Pick an object (or search / type one) and press Add Part - then move it on the Edit Part tab (Numpad 5 picks the part you look at)")
        pcall(ImGui.TextDisabled, "Prop names / IDs with pictures: forge.plebmasters.de/objects  (type one in Custom Object Model)")
    end
    F.drawCxAuto = function()
        local a = CX.autoInfo
        if not a then pcall(ImGui.TextDisabled, "Autosave: your build is saved every minute while you edit it") return end
        local ago = ""
        if a.at and os and os.time then
            local m = math.floor((os.time() - a.at) / 60)
            ago = m < 1 and "just now" or (m < 60 and (m .. " min ago") or (math.floor(m / 60) .. " h ago"))
        end
        pcall(ImGui.TextDisabled, ("Autosave: %s (%d part%s)%s - Restore Autosave brings it back"):format(tostring(a.name), a.parts or 0,
            (a.parts or 0) == 1 and "" or "s", ago ~= "" and (", " .. ago) or ""))
    end
    F.drawCxTip = function(which)
        if which == "spawn" then
            pcall(ImGui.TextDisabled, "Pick a construct and press Spawn Construct. Your own builds are in LGN Constructs.")
        elseif which == "save" then
            pcall(ImGui.TextDisabled, CX.b and "Type a name and press Save Construct - it shows up on the Spawn tab"
                or "Start one in 1. Start A New One first (or press Edit It on the Spawn tab)")
        end
    end
    F.cxTick = function()
        if CX.lastDir ~= nil and (F.cxDir:GetListIndex() or 0) ~= CX.lastDir then pcall(CX.Show) end
        if CX.lastSearch ~= nil and tostring(F.cxSearch:GetStringValue() or ""):lower() ~= CX.lastSearch then pcall(CX.Show) end
        pcall(CX.LoadedList)
        -- (Find Part: a new search picks the first match)
        local pq = tostring(F.cxPartFind:GetStringValue() or ""):lower()
        if pq ~= (CX.partQ or "") then CX.partQ = pq if pq:match("%S") then pcall(CX.FindPart, 0) end end
        -- (Name In List shows the picked construct's name, ready to change)
        local e = CX.LoadedPicked()
        local rk = e and (tostring(e) .. "|" .. tostring(e.name)) or "-"
        if rk ~= CX.renKey then
            CX.renKey = rk
            pcall(function() F.cxRename:SetStringValue(e and e.name or "") end)
        end
        if CX.lastCat ~= nil and (F.cxCat:GetListIndex() or 0) ~= CX.lastCat then pcall(CX.ShowItems) end
        if tostring(F.cxFind:GetStringValue() or ""):lower() ~= (CX.lastFind or "") then
            local okF, errF = pcall(CX.Search)
            if not okF then LogErr("constructor search", errF) end
        end
        -- (parts deleted some other way - Delete All, the game - drop out of the list)
        local now0 = NowMs()
        if CX.b and now0 >= (CX.pruneAt or 0) then
            CX.pruneAt = now0 + 1000
            local gone = false
            for i = #CX.b.parts, 1, -1 do
                if not IB(0x7239B21A38F536BA, CX.b.parts[i].h) then table.remove(CX.b.parts, i) gone = true end
            end
            if gone then CX.PartList() end
        end
        -- SELF-HEAL (every 2s): a part that came loose (the game took it off, or another player's game had it
        -- for a moment) is stuck back where the build says it goes, so editing keeps working
        if CX.b and now0 >= (CX.healAt or 0) then
            CX.healAt = now0 + 2000
            local okH, errH = pcall(CX.Heal)
            if not okH then LogErr("constructor self-heal", errH) end
        end
        local okL, errL = pcall(CX.Live)
        if not okL then LogErr("constructor", errL) end
        if CX.extraTick then
            local okE, errE = pcall(CX.extraTick)
            if not okE then LogErr("constructor picking", errE) end
        end
        -- autosave every minute while there's something new
        if CX.b and CX.dirty and now0 >= (CX.autoAt or 0) then
            CX.autoAt = now0 + 60000
            local okA, errA = pcall(CX.AutoSave, false)
            if not okA then LogErr("constructor autosave", errA) end
        end
        -- the green dot where a new part would go (while the Add Parts section is on screen)
        if CX.b and CX.aimWantAt and now0 - CX.aimWantAt < 250 and F.cxAimAdd:IsToggled() then
            local a = CX.Aim()
            local cp = a and EntityPos(CX.b.car)
            if cp and math.sqrt((a.x - cp.x) ^ 2 + (a.y - cp.y) ^ 2 + (a.z - cp.z) ^ 2) <= 25 then
                local function Dot()
                    nv(0x28477EC23D892089, 28, a.x + 0.0, a.y + 0.0, a.z + 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.06, 0.06, 0.06,
                        80, 255, 120, 220, false, false, 2, false, 0, 0, false) -- DRAW_MARKER (a small sphere)
                end
                if F.hudKeep then F.hudKeep("constructor dot", Dot, 120) else Dot() end
            end
        end
        local now = NowMs()
        local onScreen = now - (F._menuPageAt or -100000) < 1500
        if onScreen and not CX.wasOnScreen then CX.nextScan = 0 end -- (just opened: anything new shows straight away)
        CX.wasOnScreen = onScreen
        if not onScreen or now < CX.nextScan then return end
        CX.nextScan = now + 5000
        local ok, err = pcall(CX.Refresh, false)
        if not ok then LogErr("scanning constructs", err) end
    end

    -- ===== THE REDESIGNED CONSTRUCTOR: build bar, part stepping, look-to-pick, reset / nudge buttons =====
    F.cxLookPick = Toggle(H.cxLookPick, "Look To Pick (Numpad 5)",
        "While you're building: look at one of its parts (centre of the screen) and press Numpad 5 - it becomes the picked part", true)
    F.cxMark = Toggle(H.cxMark, "Show Which Part Is Picked",
        "A small yellow marker bobs above the picked part while you're on the Constructor page (only you see it)", true)
    local function Btn(label)
        local ok, p = pcall(ImGui.SmallButton, label)
        return ok and p == true
    end
    function CX.StepPart(d)
        local b = CX.b
        if not b or #b.parts == 0 then return end
        local i = ((F.cxPart:GetListIndex() or 0) + d) % #b.parts
        F.cxPart:SetListIndex(i)
        CX.sel = nil
    end
    function CX.LookPick()
        local b = CX.b
        if not b then return end
        local a = CX.Aim()
        local ent = a and a.ent or 0
        if ent == 0 then Notify("Constructor: look at one of the build's parts, then press Numpad 5", true, "spawner", { merge = "cx look" }) return end
        for _, pt in ipairs(b.parts) do
            if pt.h == ent then
                CX.Pick(pt)
                Notify("Constructor: picked " .. CX.PartLabel(pt), true, "spawner", { merge = "cx look" })
                return
            end
        end
        Notify(ent == b.car and "Constructor: that's the base - look at a part on it" or "Constructor: that isn't part of this build",
            true, "spawner", { merge = "cx look" })
    end
    -- the bar at the top of every Constructor tab: what you're building, the picked part, undo / redo / save
    F.drawCxBar = function()
        local b = CX.b
        if not b or not IB(0x7239B21A38F536BA, b.car) then
            pcall(ImGui.TextDisabled, "Not building anything - Build > 1. Start A New One, or Spawn > Edit It")
            if CX.autoInfo then pcall(ImGui.TextDisabled, "(your last unsaved build can be brought back on the Spawn tab)") end
            return
        end
        local n = #b.parts
        pcall(ImGui.Text, ("Building: %s   |   %d part%s   |   %s"):format(tostring(b.entry.name), n, n == 1 and "" or "s",
            CX.unsaved and "NOT SAVED YET" or "saved"))
        local pt = CX.PickedPart()
        if pt then
            pcall(ImGui.Text, ("Picked: %s  (%d of %d)%s"):format(CX.PartLabel(pt), (F.cxPart:GetListIndex() or 0) + 1, n,
                pt.locked and "  - locked" or ""))
        else
            pcall(ImGui.TextDisabled, "No parts yet - add one on the Build tab")
        end
        if Btn("< Prev Part##cxbar") then CX.StepPart(-1) end
        pcall(ImGui.SameLine)
        if Btn("Next Part >##cxbar") then CX.StepPart(1) end
        pcall(ImGui.SameLine)
        local u, r = CX.UndoCount(), CX.RedoCount()
        if Btn(("Undo (%d)##cxbar"):format(u)) and u > 0 then Job("undoing", CX.Undo) end
        pcall(ImGui.SameLine)
        if Btn(("Redo (%d)##cxbar"):format(r)) and r > 0 then Job("redoing", CX.Redo) end
        pcall(ImGui.SameLine)
        if Btn("Save##cxbar") then
            -- (no name typed yet: saved under the build's own name)
            if tostring(F.cxName:GetStringValue() or ""):gsub("%s", "") == "" then
                pcall(function() F.cxName:SetStringValue(tostring(b.entry.name or "My build")) end)
            end
            -- (on the game thread, like the Save Construct button - it reads the car's paint and mods with
            -- game functions, which aren't safe to call from the menu's drawing)
            Job("saving construct", CX.Save)
        end
        pcall(ImGui.Separator)
    end
    -- slider rows with [-] [0] [+] buttons: 0 puts it straight back to the middle, -/+ move one step
    local function SliderRows(keys, stepOf, id)
        local okB, began = pcall(ImGui.BeginTable, "##cxrows" .. id, 2, 0)
        local okT = okB and began == true
        if okT then
            local fixed = (ImGuiTableColumnFlags and ImGuiTableColumnFlags.WidthFixed) or 16
            pcall(ImGui.TableSetupColumn, "##s" .. id, 0)
            pcall(ImGui.TableSetupColumn, "##b" .. id, fixed)
        end
        for _, k in ipairs(keys) do
            if okT then pcall(ImGui.TableNextColumn) end
            F.renderOne(H[k])
            if okT then pcall(ImGui.TableNextColumn) else pcall(ImGui.Text, "   ") pcall(ImGui.SameLine) end
            local f = F[k]
            local v = f:GetFloatValue() or 0
            if Btn("-##" .. k) then f:SetFloatValue(v - stepOf()) end
            pcall(ImGui.SameLine)
            if Btn("0##" .. k) then f:SetFloatValue(0.0) end
            pcall(ImGui.SameLine)
            if Btn("+##" .. k) then f:SetFloatValue(v + stepOf()) end
        end
        if okT then pcall(ImGui.EndTable) end
    end
    F.drawCxPosRows = function()
        if not CX.PickedPart() then pcall(ImGui.TextDisabled, "Pick a part first") return end
        SliderRows({ "cxX", "cxY", "cxZ" }, function() return CX.STEPS[(F.cxStep:GetListIndex() or 1) + 1] or 0.01 end, "pos")
        if Btn("Put Back In The Middle (0 0 0)##cxpos0") then for _, k in ipairs({ "cxX", "cxY", "cxZ" }) do F[k]:SetFloatValue(0.0) end end
    end
    F.drawCxRotRows = function()
        if not CX.PickedPart() then pcall(ImGui.TextDisabled, "Pick a part first") return end
        SliderRows({ "cxRX", "cxRY", "cxRZ" }, function() return CX.RSTEPS[(F.cxRStep:GetListIndex() or 1) + 1] or 1.0 end, "rot")
        if Btn("Straighten It (0 0 0)##cxrot0") then for _, k in ipairs({ "cxRX", "cxRY", "cxRZ" }) do F[k]:SetFloatValue(0.0) end end
    end
    -- look-to-pick key + the marker over the picked part
    CX.extraTick = function()
        local b = CX.b
        if not b then return end
        if F.cxLookPick:IsToggled() and not F.Typing() and F.LX and F.LX.KeyTap("cxLookPick", 0x65) then CX.LookPick() end
        if F.cxMark:IsToggled() then
            local okO, open = pcall(GUI.IsOpen)
            -- (only while the Constructor page is the one on screen)
            local onPage = F._menuPage == "Constructor" and NowMs() - (F._menuPageAt or 0) < 300
            local pt = okO and open == true and onPage and CX.PickedPart()
            local p = pt and EntityPos(pt.h)
            if p then
                F.hudKeep("constructor picked part", function()
                    nv(0x28477EC23D892089, 0, p.x + 0.0, p.y + 0.0, p.z + 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.18, 0.18, 0.18,
                        255, 200, 0, 190, true, true, 2, false, 0, 0, false) -- DRAW_MARKER (a little cone pointing down at it)
                end, 150)
            end
        end
    end
    F.cxTest = CX
    F.cxRescan = function() pcall(CX.Refresh, false) end
end)


-- ---------------------------------------------------------------------
-- THE MENU: one "Constructor Enhanced" tab with three tabs inside in the order you use them - Spawn, Build,
-- Edit Part - nothing folded away, in Cherax's own look (no LGNFX theme)
-- ---------------------------------------------------------------------
-- "why can't I?": an option that can't work right now is greyed out and says what it needs
local REQ = {}
do
    local function Me() local ok, h = pcall(Natives.InvokeInt, 0xD80958FC74E988A6) return (ok and h and h ~= 0) and h or nil end
    local function InCar() local me = Me() return me and IB(0x997ABD671D25CA0B, me, false) end -- IS_PED_IN_ANY_VEHICLE
    local function CX() return F.cxTest end
    local function Build() local c = CX() return c and c.b end
    local function NeedBuild() return not Build() and "start or open a build first" or nil end
    local function NeedPart()
        if not Build() then return "start or open a build first" end
        local c = CX()
        return not (c.PickedPart and c.PickedPart()) and "add a part first" or nil
    end
    local function NeedSpawned()
        local api = F.xsApi
        return (not api or #api.Loaded() == 0) and "spawn a construct first" or nil
    end
    local function R(keys, fn) for _, k in ipairs(keys) do REQ[H[k]] = fn end end
    R({ "cxStart" }, function() return not InCar() and "get in a vehicle" or nil end)
    R({ "cxAdd", "cxSave", "cxKitAdd", "cxKitSave", "cxGrpAll", "cxGrpNone" }, NeedBuild)
    R({ "cxPartNext" }, function() return NeedPart() or (tostring(F.cxPartFind:GetStringValue() or ""):match("%S") == nil and "type in Find Part first") or nil end)
    R({ "cxPastePos" }, function() return NeedPart() or (not (F.cxTest and F.cxTest.clip) and "copy a position first") or nil end)
    R({ "cxAllMove" }, NeedBuild)
    R({ "cxSnapTo", "cxCopyPos", "cxDup", "cxMirX", "cxMirY", "cxMirZ", "cxRem", "cxPartRename", "cxLock", "cxGrp", "cxCol", "cxVis", "cxAlpha", "cxTint", "cxBone" }, NeedPart)
    R({ "cxUndo" }, function() local c = CX() return (NeedBuild() or (c.UndoCount() == 0 and "nothing to undo yet")) or nil end)
    R({ "cxRedo" }, function() local c = CX() return (NeedBuild() or (c.RedoCount() == 0 and "nothing to redo")) or nil end)
    R({ "cxGetIn", "cxRide", "cxEdit", "cxTpMe", "cxTpIt", "cxDelOne", "cxRenameIt" }, NeedSpawned)
end

local function RenderOne(hash)
    local need = nil
    if REQ[hash] then local ok, n = pcall(REQ[hash]) need = ok and n or nil end
    local dis = need and pcall(ImGui.BeginDisabled, true)
    local okR, errR = pcall(ClickGUI.RenderFeature, hash)
    local okH, hov = pcall(ImGui.IsItemHovered, (ImGuiHoveredFlags and ImGuiHoveredFlags.AllowWhenDisabled) or 0)
    if dis then pcall(ImGui.EndDisabled) end
    if not okR then LogErr("drawing an option", errR) end
    if need then pcall(ImGui.SameLine) pcall(ImGui.TextDisabled, "(" .. need .. ")") end
    if okH and hov then
        local info = FeatureMgr.info[hash]
        if info and info.desc and info.desc ~= "" then pcall(ImGui.SetTooltip, info.desc) end
    end
end
F.renderOne = RenderOne


local function RenderPage(secs)
    for _, section in ipairs(secs) do
        if ClickGUI.BeginCustomChildWindow(section[1]) then
            local ok, err = pcall(function()
                if section.draw and section.drawFirst then pcall(section.draw) end
                for _, hash in ipairs(section[2]) do RenderOne(hash) end
                if section.draw and not section.drawFirst then pcall(section.draw) end
            end)
            if not ok then LogErr("drawing " .. tostring(section[1]), err) end
            ClickGUI.EndCustomChildWindow()
        end
    end
end


local PAGES = {
    { "Spawn", hint = "Your saved constructs: spawn one, then use, edit or delete what's out in the world", {
        { "Saved Constructs", { H.cxSearch, H.cxDir, H.cxList, H.cxSpawn, H.cxFav, H.xsHere, H.xsTp, H.xsInto, H.cxRefresh, H.cxFolders },
            noReset = true, draw = function()
                if F.drawCxTip then F.drawCxTip("spawn") end
                if F.drawPreviewFile and F.cxPickedPath then F.drawPreviewFile(F.cxPickedPath()) end
            end },
        { "Out In The World", { H.cxLoaded, H.cxEdit, H.cxGetIn, H.cxRide, H.cxTpMe, H.cxTpIt, H.cxRename, H.cxRenameIt, H.cxDelOne,
            H.xsDelAll, H.bringBack }, noReset = true,
            hint = "Pick one and press Edit It to change it (it opens on the Build and Edit Part tabs)" },
        { "Unsaved Build", { H.cxAutoRestore }, noReset = true,
            draw = function() if F.drawCxAuto then F.drawCxAuto() end end },
    } },
    { "Build", hint = "1. Start a build   2. Add parts   3. Kits (optional)   4. Save it", {
        { "Now Building", {}, noReset = true, drawFirst = true, draw = function() if F.drawCxBar then F.drawCxBar() end end },
        { "1. Start A New One", { H.cxStart, H.cxVehName, H.cxFromVeh, H.cxFromCone, H.cxBaseVis }, noReset = true },
        { "2. Add Parts", { H.cxCat, H.cxFind, H.cxObj, H.cxObjCustom, H.cxAimAdd, H.cxOnPart, H.cxAdd, H.previewOn }, noReset = true,
            draw = function()
                if F.drawConstructorAdd then F.drawConstructorAdd() end
                if F.WantGhost and F.cxPickedModel then F.WantGhost(F.cxPickedModel()) end
            end },
        { "3. Kits (Parts To Stick On Any Build)", { H.cxKit, H.cxKitAdd, H.cxKitName, H.cxKitSave }, noReset = true, drawFirst = true,
            draw = function() pcall(ImGui.TextDisabled, "Save some parts as a kit, then stick them on any other build") end },
        { "4. Save This Build", { H.cxName, H.cxSave }, noReset = true,
            draw = function() if F.drawCxTip then F.drawCxTip("save") end end },
    } },
    { "Edit Part", hint = "Pick a part (from the list, or look at it + Numpad 5), then move, turn and set it up", {
        { "Now Building", {}, noReset = true, drawFirst = true, draw = function() if F.drawCxBar then F.drawCxBar() end end },
        { "Picked Part", { H.cxPart, H.cxPartFind, H.cxPartNext, H.cxLookPick, H.cxMark, H.cxDup, H.cxMirX, H.cxMirY, H.cxMirZ,
            H.cxCopyPos, H.cxPastePos, H.cxSnapTo, H.cxRem }, noReset = true },
        { "Part Settings", { H.cxCol, H.cxVis, H.cxAlpha, H.cxTint, H.cxBone }, noReset = true },
        { "Position", { H.cxStep, H.cxSnap, H.cxPosExact }, noReset = true, drawFirst = true,
            list = { H.cxX, H.cxY, H.cxZ, H.cxStep, H.cxSnap, H.cxPosExact },
            draw = function() if F.drawCxPosRows then F.drawCxPosRows() end end },
        { "Rotation", { H.cxRStep, H.cxSnapRot, H.cxRotExact }, noReset = true, drawFirst = true,
            list = { H.cxRX, H.cxRY, H.cxRZ, H.cxRStep, H.cxSnapRot, H.cxRotExact },
            draw = function() if F.drawCxRotRows then F.drawCxRotRows() end end },
        { "Name & Lock", { H.cxPartName, H.cxPartRename, H.cxLock }, noReset = true },
        { "Move Parts Together", { H.cxGrp, H.cxGrpAll, H.cxGrpNone }, noReset = true },
        { "Move Whole Build", { H.cxAllDir, H.cxAllMove }, noReset = true },
        { "Keys", { H.cxKeys }, noReset = true,
            list = { H.cxKeys, H.cxUndo, H.cxRedo } }, -- (Undo / Redo are on the bar at the top)
    } },
}


local function RenderTab()
    F._menuPage, F._menuPageAt = "Constructor", NowMs() -- (the picked-part marker only shows while this tab is on screen)
    pcall(F.NoteUiTyping)
    if type(ImGui.BeginTabBar) == "function" and ImGui.BeginTabBar("##ce_tabs", 0) then
        for _, sp in ipairs(PAGES) do
            if ImGui.BeginTabItem(sp[1] .. "##ce") then
                if sp.hint then pcall(ImGui.TextDisabled, sp.hint) end
                local ok, err = pcall(RenderPage, sp[2])
                if not ok then LogErr("drawing " .. sp[1], err) end
                ImGui.EndTabItem()
            end
        end
        ImGui.EndTabBar()
    else
        for _, sp in ipairs(PAGES) do RenderPage(sp[2]) end
    end
end
Try("adding the menu tab", function()
    pcall(ClickGUI.RemoveTab, CE_NAME)
    ClickGUI.AddTab(CE_NAME, RenderTab)
end)
local listRoot, listMain = nil, nil
Try("adding the list menu tab", function()
    listRoot = ListGUI.GetRootTab()
    listMain = listRoot:AddSubTab(CE_NAME, "Build your own constructs and spawn saved ones")
    for _, sp in ipairs(PAGES) do
        local sub = listMain:AddSubTab(sp[1], CE_NAME .. " - " .. sp[1])
        for _, section in ipairs(sp[2]) do
            local hashes = section.list or section[2]
            if #hashes > 0 then
                pcall(function() sub:AddSeperator(section[1]) end)
                for _, h in ipairs(hashes) do pcall(function() sub:AddFeature(h) end) end
            end
        end
    end
end)

-- ---------------------------------------------------------------------
-- THE LOOP: every frame, each piece on its own (one with a problem can't stop the others)
-- ---------------------------------------------------------------------
local STEPS = {
    { "hidden parts", function() LGX.HiddenTick() end },
    { "constructor", function() if F.cxTick then F.cxTick() end end },
    { "spawn previews", function() if F.ghostTick then F.ghostTick() end end },
    { "bring them back", function() if F.bbTick then F.bbTick() end end },
    { "leftover clean up", function() if F.lxDeleteTick then F.lxDeleteTick() end end },
    { "markers", function() HUD.Frame(NowMs()) end },
}
local stepErrAt = {}
Script.QueueJob(function()
    while not ShouldStop() do
        local now = NowMs()
        for _, step in ipairs(STEPS) do
            local ok, err = pcall(step[2])
            if not ok and now - (stepErrAt[step[1]] or 0) > 10000 then
                stepErrAt[step[1]] = now
                LogErr(step[1], err)
            end
        end
        Script.Yield(0)
    end
    if LGX.cleanup then pcall(LGX.cleanup) end
end)
-- (typing in any Cherax text box: the numpad doesn't move parts meanwhile)
pcall(EventMgr.RegisterHandler, eLuaEvent.ON_PRESENT, function() pcall(F.NoteUiTyping) end)

-- ---------------------------------------------------------------------
-- CLEAN UP WHEN IT STOPS: your build is autosaved, then everything it spawned is cleared away -
-- except the vehicle you're sat in (and anything built onto it), so you're never dropped on the road
-- ---------------------------------------------------------------------
LGX.cleanup = function()
    if LGX.cleaned then return end
    LGX.cleaned = true
    for _, fn in ipairs(F.unloadHooks or {}) do pcall(fn) end
    -- then whatever it spawned that's still around
    pcall(function()
        local CN = {
            PLAYER_PED_ID = 0xD80958FC74E988A6, IS_PED_IN_ANY_VEHICLE = 0x997ABD671D25CA0B,
            GET_VEHICLE_PED_IS_IN = 0x9A9112A0FE9A4713, DOES_ENTITY_EXIST = 0x7239B21A38F536BA,
            GET_ENTITY_ATTACHED_TO = 0x48C2BED9180FE123, NETWORK_HAS_CONTROL_OF_ENTITY = 0x01BF60A500E28887,
            NETWORK_REQUEST_CONTROL_OF_ENTITY = 0xB69317BF5E782347, SET_ENTITY_AS_MISSION_ENTITY = 0xAD738C3085FE7E11,
            DELETE_ENTITY = 0xAE3CBE5BF394C9C9, SET_ENTITY_AS_NO_LONGER_NEEDED = 0xB736A491E64A32CF,
        }
        local function Exists(h) local ok, e = pcall(IB, CN.DOES_ENTITY_EXIST, h) return ok and e end
        -- keep: the vehicle you're in, and anything attached to it (or to something attached to it)
        local keep = {}
        local me = Natives.InvokeInt(CN.PLAYER_PED_ID)
        if me and me ~= 0 and IB(CN.IS_PED_IN_ANY_VEHICLE, me, false) then
            local v = Natives.InvokeInt(CN.GET_VEHICLE_PED_IS_IN, me, false)
            if v and v ~= 0 then keep[v] = true end
        end
        local grew = next(keep) ~= nil
        while grew do
            grew = false
            for h in pairs(LGX.spawned) do
                if not keep[h] and Exists(h) then
                    local okA, parent = pcall(Natives.InvokeInt, CN.GET_ENTITY_ATTACHED_TO, h)
                    if okA and parent and parent ~= 0 and keep[parent] then keep[h], grew = true, true end
                end
            end
        end
        -- delete the rest (online, something another player's game has taken over is asked for back first)
        local removed = 0
        for pass = 1, 4 do
            local left = 0
            for h in pairs(LGX.spawned) do
                if keep[h] or not Exists(h) then
                    LGX.spawned[h] = nil
                elseif not IB(CN.NETWORK_HAS_CONTROL_OF_ENTITY, h) then
                    Natives.InvokeVoid(CN.NETWORK_REQUEST_CONTROL_OF_ENTITY, h)
                    left = left + 1
                else
                    pcall(function()
                        Natives.InvokeVoid(CN.SET_ENTITY_AS_MISSION_ENTITY, h, true, true)
                        local p = Memory.AllocInt() Memory.WriteInt(p, h)
                        Natives.InvokeVoid(CN.DELETE_ENTITY, p)
                        Memory.Free(p)
                    end)
                    if Exists(h) then left = left + 1 else LGX.spawned[h] = nil removed = removed + 1 end
                end
            end
            if left == 0 then break end
            pcall(Script.Yield, 60)
        end
        -- anything that still couldn't be deleted is handed to the game, which clears it away itself
        local handed = 0
        for h in pairs(LGX.spawned) do
            if not keep[h] and Exists(h) then
                handed = handed + 1
                pcall(function()
                    local p = Memory.AllocInt() Memory.WriteInt(p, h)
                    Natives.InvokeVoid(CN.SET_ENTITY_AS_NO_LONGER_NEEDED, p)
                    Memory.Free(p)
                end)
            end
        end
        pcall(Dump.Info, ("[CE] clean up: removed %d thing(s) it had spawned%s"):format(removed,
            handed > 0 and (", " .. handed .. " left for the game to clear") or ""))
        pcall(Dump.Info, true)
    end)
end
pcall(EventMgr.RegisterHandler, eLuaEvent.ON_UNLOAD, function()
    running = false
    pcall(ClickGUI.RemoveTab, CE_NAME)
    if listRoot and listMain then pcall(function() listRoot:RemoveSubTab(listMain) end) end
    for _, fn in ipairs(F.unloadHooks or {}) do pcall(fn) end
    F.unloadHooks = {}
    Script.QueueJob(function() if LGX.cleanup then pcall(LGX.cleanup) end end)
    for _, hash in pairs(H) do pcall(FeatureMgr.RemoveFeature, hash) end
end)

-- FIRST RUN: your builds (and kits) are copied into Lua\CE, and the autosave and ObjectList.txt into
-- Lua\CE\data, from an old LGNFX folder - once. Files already here are left alone, and after this only
-- Lua\CE is used
Try("copying your builds in", function()
    local api = F.xsApi
    if not api then return end
    local base = api.MainBase()
    local flag = base .. "\\copied_from_lgnfx.txt"
    if FileMgr.DoesFileExist(flag) then return end
    local old = LuaDir() .. "\\LGNFX"
    local n = 0
    local function Copy(from, to)
        local okE, there = pcall(FileMgr.DoesFileExist, to)
        if okE and there then return end
        local okR, c = pcall(FileMgr.ReadFileContent, from)
        if okR and c and c ~= "" and pcall(FileMgr.WriteFileContent, to, c, false) then n = n + 1 end
    end
    local oldC, newC = old .. "\\lgnconstructs", F.cxTest.Root() -- (your builds go straight into Lua\CE)
    for _, kind in ipairs({ "json", "xml" }) do
        local ok, found = pcall(FileMgr.FindFiles, oldC, "." .. kind, true)
        for _, p in ipairs(ok and api.ToList(found) or {}) do
            p = tostring(p):gsub("/", "\\")
            local full = (p:match("^%a:\\") or p:match("^\\\\")) and p or (oldC .. "\\" .. p:gsub("^\\+", ""))
            if full:lower():sub(1, #oldC + 1) == (oldC .. "\\"):lower() and full:lower():sub(-#kind - 1) == "." .. kind then
                local rel = full:sub(#oldC + 2)
                local sub = rel:match("^(.*)\\[^\\]+$")
                if sub then pcall(FileMgr.CreateDir, newC .. "\\" .. sub) end
                Copy(full, newC .. "\\" .. rel)
            end
        end
    end
    Copy(old .. "\\ObjectList.txt", base .. "\\ObjectList.txt")
    Copy(old .. "\\cfg\\constructor_autosave.json", CfgDir() .. "\\constructor_autosave.json")
    pcall(FileMgr.WriteFileContent, flag, CE_VERSION .. "\n", false)
    if n > 0 then
        if F.cxRescan then F.cxRescan() end
        if F.cxTest and F.cxTest.ReadAutoInfo then pcall(F.cxTest.ReadAutoInfo) end
        Notify(("Copied %d of your files in from the LGNFX folder (builds, autosave, object list)"):format(n))
    end
end)
Notify(CE_VERSION .. " loaded")
