gx.libraryVer = 29

-- Bug Fixes
local oldSetStat = PaperDollFrame_SetStat
PaperDollFrame_SetStat = function(statFrame, unit, statIndex)
   if statIndex == LE_UNIT_STAT_STAMINA then return end
   oldSetStat(statFrame, unit, statIndex)
end
-- Bug Fixes

function math.sign(v)
    return (v >= 0 and 1) or -1
end
function math.round(v, bracket)
    bracket = bracket or 1
    return math.floor(v/bracket + math.sign(v) * 0.5) * bracket
end

local gxCOFrame = CreateFrame("Frame")
local gxCO
local coTable = {}
function gx.queueUpCO(func)
    if func then table.insert(coTable, func) return end
    if gxCO and type(gxCO) == "thread" and coroutine.status(gxCO) == "suspended" then local status = {coroutine.resume(gxCO)}; for k,v in pairs(status) do status[k] = tostring(v) end; local message = select(2, status) if message ~= nil and message ~= "continue" --[[and message ~= "true"]] then --[[WriteFile]]error(--[[GetHackDirectory().."\\gxError.txt",]] table.concat(status, ", ")) end return (message ~= "continue") elseif type(coTable[1]) ~= "nil" then gxCO = coroutine.create(coTable[1]); table.remove(coTable, 1) return true end
    return false
end
function gx.emptyCO()
    for i = 1, #coTable do
        table.remove(coTable)
    end
    if type(gxCO) == "thread" and coroutine.status(gxCO) == "suspended" then gxCO = nil end
end

function gx.inQueue(func)
    return tContains(coTable, func)
end

function gx.queueSize()
    return #coTable
end

function gx.printd(...)
    local tableS = {...}
    for k,v in pairs(tableS) do tableS[k] = tostring(v) end
    if string.lower(Engine_GetUsername()) == "g1zstar" or gxrdebug then print("GXR: "..table.concat(tableS, ", ")) end
end

function gx.notEnoughEnergyFor(spell)
    return select(2, IsUsableSpell(spell))
end

function gx.poolEnergyFor(spell, cast, unit)
    gx.queueUpCO(function()
            while (not castable(spell) and gx.notEnoughEnergyFor(spell)) do
                coroutine.yield()
                gx.printd("Pooling for "..GetSpellInfo(spell))
            end
            if cast then
                while (castable(spell, unit)) do
                    cast(spell, unit)
                    coroutine.yield()
                    gx.printd("Casting "..GetSpellInfo(spell).." after Pooling")
                end
            end
        end)
end

function gx.castThrough(spell, unit, tickTime)
    if tickTime == 0 then CastSpellByID(spell, unit) return end
    local name = UnitChannelInfo("player")
    if not name then cast(spell, unit) return end
    gx.queueUpCO(function()
            local _, _, _, _, startTime, endTime = UnitChannelInfo("player")
            local timeNow = debugprofilestop()
            if not startTime then return end

            for i = 1, 999 do if startTime + (tickTime*1000)*i > timeNow then startTime = startTime + (tickTime*1000)*i break end end
            if startTime > endTime then startTime = endTime end
            
            while (timeNow < startTime) do timeNow = debugprofilestop(); coroutine.yield(); gx.printd(timeNow >= startTime, "Casting "..GetSpellInfo(spell).." after next tick of "..name..".") end
            -- CastSpellByID(spell, unit)
            SpellStopCasting()
            cast(spell, unit)
        end)
end

local queueFrame = CreateFrame("Frame", "queueFrame")
queueFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
queueFrame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
local queueDone = true
function gx.queueUpFailedCast(self, event, unitID, spell, rank, lineID, spellID)
    if UnitIsUnit(unitID, "player") and queueDone then
        if config(gx.rotationKey, "queue"..spellID) and player.spell(spellID).cooldown <= 2 then
            queueDone = false
            gx.queueUpCO(function()
                    while (not castable(spellID, target) and player.spell(spellID).cooldown <= 2 and config(gx.rotationKey, "queue"..spellID)) do
                        print("GXR Queue System: Casting "..spell)
                        coroutine.yield()
                    end
                    while(player.spell(spellID).cooldown == 0) do
                        cast(spellID, target)
                        coroutine.yield()
                    end
                    queueDone = true
                    gx.printd("DONE QUEUE")
                end)
            return
        end
    end
end
queueFrame:SetScript("OnEvent", gx.queueUpFailedCast)

local sephuzs_cd = 0
local icdFrame = CreateFrame("Frame")
icdFrame:RegisterEvent("UNIT_AURA")
local function setICDs(self, event, unit)
    if UnitIsUnit("player", unit) then
        local _, _, _, _, _, duration, expires = UnitBuff("player", GetSpellInfo(208052))
        if duration then sephuzs_cd = expires - duration + 30 end
    end
end
icdFrame:SetScript("OnEvent", setICDs)

function gx.sephuzsAvailable()
    return GetTime() > sephuzs_cd
end

local externals = {
    102342, -- ironbark
    116849, -- life cocoon
    6940, -- blessing of sacrifice
    -- blessing of protection (phy immunity)
    -- blessing of spellwarding (spell immunity)
    47788, -- guardian spirit
    33206, -- pain suppression
    223658, -- safeguard

    -- raid wide
    209426, -- darkness
    -- tranquility
    204150, -- aegis of light
    -- 210320, -- aura mastery devotion aura
    64844, -- divine hymn
    81782, -- power word: barrier
    -- light's wrath
    -- vampiric embrace
    207498, -- ancestral guidance
    -- healing tide totem
    -- ancestral protection totem
    -- commanding shout
}
function gx.externalOnUs()
    for i = 1, math.huge do
        if not externals[i] then break end
        if player.buff(externals[i]).any then return true end
    end
    if player.buff(210320).any and select(17, UnitBuff("player", GetSpellInfo(210320))) == -20 then return true end
    return false
end

function gx.cdCheck()
    return config("main", "cdmode") == "always" or config("main", "cdmode") == "boss" and target.isboss
end

function gx.aoe()
    return config("main", "aoe")
end

function gx.talent(r, c, b)
    if b then
        return player.talent(r, c)
    else
        return player.talent(r, c) and 1 or 0
    end
end

function gx.execute_time(spell)
    return math.max(player.spell(spell).castingtime, math.max((1.5/(1+GetHaste()*.01)), 0.75))
end

local brokenIslesIDs = {--[[BrokenIsles =]] 1007, --[[Aszuna =]] 1015, --[[BrokenShore =]] 1021, --[[Dalaran =]] 1014, --[[EyeOfAzshara =]] 1098, --[[Highmountain =]] 1024, --[[Stormheim =]] 1017, --[[Suramar =]] 1033, --[[Valsharah =]] 1018,
                        --[[HallOfTheGuardian =]] 1068, --[[MardumTheShatteredAbyss =]] 1052, --[[NetherlightTemple =]] 1040, --[[Skyhold =]] 1035, --[[TheDreamgrove =]] 1077, --[[TheHeartOfAzeroth =]] 1057, --[[TheWanderingIsle =]] 1044, --[[TrueshotLodge =]] 1072}
function gx.inBrokenIsles()
    return tContains(brokenIslesIDs, GetCurrentMapAreaID())
end

local argusIDs = {--[[MacAree =]] 1170, --[[AtnoranWastes =]] 1171, --[[Argus =]] 1184, --[[Krokuun =]] 1135,}
function gx.inArgus()
    return tContains(argusIDs, GetCurrentMapAreaID())
end

local keyCode = {BUTTON3 = 0x04, BUTTON4 = 0x05, BUTTON5 = 0x06, BACKSPACE = 0x08, TAB = 0x09, ENTER = 0x0D, SHIFT = 0x10, CAPSLOCK = 0x14, ESCAPE = 0x1B, SPACE = 0x20, PAGEUP = 0x21, PAGEDOWN = 0x20, END = 0x23, HOME = 0x24, LEFT = 0x25, UP = 0x26, RIGHT = 0x27, DOWN = 0x28, INSERT = 0x2D, DELETE = 0x2E, NUMPADMULTIPLY = 0x6A, NUMPADPLUS = 0x6B, --[[NUMPADSEPARATOR NUMPAD00 = 0x6C,]] NUMPADMINUS = 0x6D, NUMPADDECIMAL = 0x6E, NUMPADDIVIDE = 0x6F, NUMLOCK = 0x90, LSHIFT = 0xA0, RSHIFT = 0xA1, LCTRL = 0xA2, RCTRL = 0xA3, LALT = 0xA4, RALT = 0xA5}
for i = 0, 9 do
    keyCode[tostring(i)] = 0x30+i
end
for i = 0, 25 do
    keyCode[string.char(65+i)] = 0x41+i
end
for i = 0, 9 do
    keyCode["NUMPAD"..tostring(i)] = 0x60+i
end
for i = 1, 24 do
    keyCode["F"..tostring(i)] = 0x6F+i
end

local function checkKeyState(keys)
    local held
    for k,v in pairs(keys) do
        held = false
        if v == "SHIFT" or v == "ALT" or v == "CTRL" then
            held = GetKeyState(keyCode["L"..v]) or GetKeyState(keyCode["R"..v])
        end
        held = held or GetKeyState(keyCode[v])
        if not held then return false end
    end
    return true
end

local autoRunOn
function gx.getMovingTable()
    local movingTable = {}
    for k,v in pairs(MovementFlag) do
        if UnitMovementFlag("player", v) then movingTable[k] = true end
    end
    return movingTable
end

local stopMovingTable = {StrafeLeft = StrafeLeftStop, Backward = MoveBackwardStop, TurnLeft = TurnLeftStop, StrafeRight = StrafeRightStop, Ascending = AscendStop, TurnRight = TurnRightStop, PitchDown = PitchDownStop, Descending = DescendStop, Forward = function() MoveForwardStart(); MoveForwardStop() end, PitchUp = PitchUpStop}
function gx.stopMoving(movingTable)
    for k,v in pairs(movingTable) do
        print(k,v)
        if k == "Forward" then
            local name, _, keyOne, keyTwo = GetBinding(2)
            local comboOne, comboTwo = {}, {}
            
            if keyOne then
                for s in string.gmatch(keyOne, "[^%-]+") do
                    table.insert(comboOne, s)
                end
            end

            if keyTwo then
                for s in string.gmatch(keyTwo, "[^%-]+") do
                    table.insert(comboTwo, s)
                end
            end

            autoRunOn = not (keyOne and checkKeyState(comboOne) or keyTwo and checkKeyState(comboTwo))
        end
        if stopMovingTable[k] then stopMovingTable[k]() end
    end
end

local startMovingTable = {StrafeLeft = StrafeLeftStart, Backward = MoveBackwardStart, TurnLeft = TurnLeftStart, StrafeRight = StrafeRightStart, Ascending = JumpOrAscendStart, TurnRight = TurnRightStart, PitchDown = PitchDownStart, Descending = SitStandOrDescendStart, Forward = MoveForwardStart, PitchUp = PitchUpStart}
local bindingsMovingTable = {MOVEANDSTEER = MoveAndSteerStart, MOVEFORWARD = MoveForwardStart, MOVEBACKWARD = MoveBackwardStart, TURNLEFT = TurnLeftStart, TURNRIGHT = TurnRightStart, STRAFELEFT = StrafeLeftStart, STRAFERIGHT = StrafeRightStart, PITCHUP = PitchUpStart, PITCHDOWN = PitchDownStart}
function gx.startMoving(movingTable)
    -- for k,v in pairs(movingTable) do
    --     if startMovingTable[k] then startMovingTable[k]() end
    -- end

    -- for k,v in pairs(movingTable) do
        for i = 1, 15 do
            local name, _, keyOne, keyTwo = GetBinding(i)
            local comboOne, comboTwo = {}, {}
            
            if keyOne then
                for s in string.gmatch(keyOne, "[^%-]+") do
                    table.insert(comboOne, s)
                end
            end

            if keyTwo then
                for s in string.gmatch(keyTwo, "[^%-]+") do
                    table.insert(comboTwo, s)
                end
            end

            if bindingsMovingTable[name] and (keyOne and checkKeyState(comboOne) or keyTwo and checkKeyState(comboTwo)) then bindingsMovingTable[name]() end
        end
        if autoRunOn then ToggleAutoRun() end
    -- end
end

local insertGeneral = {}

gxDKB = {
    -- Blood
    {},
    -- Frost
    {},
    -- Unholy
    {
        festering_wound = 194310,
        runic_corruption = 51460,
        death_coil = 47541,
        festering_strike = 85948,
        outbreak = 77575,
        virulent_plague = 191587,
        raise_dead = 46584,
        scourge_strike = 55090,
        death_and_decay = 43265,
        death_and_decay = 188290,
        icebound_fortitude = 48792,
        dark_succor = 101568,
        wraith_walk = 212552,
        chains_of_ice = 45524,
        sudden_doom = 81340,
        dark_transformation = 63560,
        summon_gargoyle = 49206,
        army_of_the_dead = 42650,

        -- Honor Talents

        apocalypse = 220143,
        scourge_of_the_worlds = 191748,

        cold_heart = 151796,
        cold_heart_buff = 235599,
        taktheritrixs_shoulderpads = 137075,
        draugr_girdle_of_the_everlasting_king = 132441,
        uvanimor_the_unbeautiful = 137037,
        the_instructors_fourth_lesson = 132448,
        death_march = 144280,
    },
}
insertGeneral = {
    frost_breath = 190780,
    corse_explosion = 127344,
    death_gate = 50977,
    death_grip = 49576,
    death_strike = 49998,
    unholy_strength = 53365,
    razorice = 51715,
    runeforging = 53428,
    anti_magic_shell = 48707,
    dark_command = 56222,
    mind_freeze = 47528,
    path_of_frost = 3714,
    coontrol_undead = 111673,
    raise_ally = 61999,

    acherus_drapes = 132376,
    soul_of_the_deathlord = 151640,
}
for i = 1, 3 do
    for j = 1, #insertGeneral do
        table.insert(gxDKB[i], j, insertGeneral[j])
    end
end

gxDHB = {
    -- Havoc
    {
        demons_bite = 162243,
        darkness = 196718,
        
        felblade = 232893,
        prepared = 203650,
        netherwalk = 196555,
        momentum = 208628,
        fel_eruption = 211881,
        nemesis = 206491,
        chaos_blades = 247938,
        fel_barrage = 211053,

        -- Honor Talents

        fury_of_the_illidari = 201467,
        anguish = 202443,
    },

    -- Vengeance
    {},
}
insertGeneral = {
    blade_dance = 188499,
    blur = 198589,
    blur_buff = 212800,
    chaos_nova = 179057,
    chaos_strike = 162794,
    consume_magic = 183752,
    eye_beam = 198013,
    fel_rush = 195072,
    glide = 131347,
    imprison = 217832,
    metamorphosis = 191427,
    metamorphosis_buff = 162264,
    soul_carver = 214743,
    spectral_sight = 188501,
    throw_glaive = 185123,
    vengeful_retreat = 198793,

    soul_of_the_slayer = 151639,
}
for i = 1, 2 do
    for j = 1, #insertGeneral do
        table.insert(gxDHB[i], j, insertGeneral[j])
    end
end

gxDRB = {
    -- Balance
    {},

    -- Feral
    {
        ferocious_bite = 22568,
        shred = 5221,
        rake = 1822,
        rake_debuff = 155722,
        thrash = 106832,
        thrash_debuff = 106830,
        tigers_fury = 5217,
        prowl = 5215,
        rip = 1079,
        remove_corruption = 2782,
        swipe = 213764,
        survival_instincts = 61336,
        berserk = 106951,
        clearcasting = 135700,
        stampeding_roar = 106898,
        infected_wounds = 58180,
        maim = 22570,
        skull_bash = 106839,
        predatory_swiftness = 69369,
    
        renewal = 108238,
        displacer_beast = 102280,
        wild_charge = 132302, --?
        -- balance_affinity
        -- guardian_affinity
        -- restoration_affinity
        mighty_bash = 5211,
        mass_entanglement = 102359,
        typhoon = 132469,
        incarnation_king_of_the_jungle = 102543,
        brutal_slash = 202028,
        savage_roar = 52610,
        bloodtalons = 145152,
        elunes_guidance = 202060,
    
        -- Honor Talents
    
        ashamanes_frenzy = 210722,
        fury_of_ashamane = 240670,
    
        chatoyant_signet = 137040,
        ailuro_pouncers = 137024,
        the_wildshapers_clutch = 137094,
        fiery_red_maimers = 144354,
        fiery_red_maimers_buff = 236757,
        behemoth_headdress = 151801,
        luffa_wrappings = 137056,
    
        apex_predator = 252752, -- T214PC
    },

    -- Guardian
    {},
    -- Restoration
    {},
}
insertGeneral = {
    moonfire = 8921,
    regrowth = 8936,
    cat_form = 768,
    dash = 1850,
    bear_form = 5487,
    enraged_maul = 236716,
    growl = 6795,
    dreamwalk = 193753,
    revive = 50769,
    teleport_moonglade = 18960,
    sunfire = 164815,
    travel_form = 783,
    entangling_roots = 339,
    charm_woodland_creature = 127757,
    flap = 164862,
    stag_form = 210053,
    rebirth = 20484,
    flight_form = 165962,

    ekowraith_creator_of_worlds = 137015,
    soul_of_the_archdruid = 151636,
}
for i = 1, 4 do
    for j = 1, #insertGeneral do
        table.insert(gxDRB[i], j, insertGeneral[j])
    end
end

gxHB = {
    -- Beast Mastery
    {},
    -- Marksman
    {
        cobra_shot = 193455,
        concussive_shot = 5116,
        arcane_shot = 185358,
        aimed_shot = 19434,
        multi_shot = 2643,
        freezing_trap = 187650,
        marking_targets = 223138,
        hunters_mark = 185365,
        vulnerable = 187131,
        marked_shot = 185901,
        exhilaration = 109304,
        bursting_shot = 186387,
        counter_shot = 147362,
        tar_trap = 187698,
        trueshot = 193526,
        misdirection = 34477,
        bombardment = 82921,
    
        -- Honor Talents
    
        windburst = 204147,
        bullseye = 204090,
    },

    -- Survival
    {},
}
insertGeneral = {
    call_pet_one = 883,
    marked_shot = 212621,
    vulnerable = 187131,
    revive_pet = 982,
    dismiss_pet = 2641,
    beast_lore = 1462,
    call_pet_two = 83242,
    feed_pet = 6991,
    tame_beast = 1515,
    mend_pet = 136,
    eagle_eye = 6197,
    aspect_of_the_cheetah = 186257,
    feign_death = 5384,
    wake_up = 210000,
    call_pet_three = 83243,
    flare = 1543,
    aspect_of_the_chameleon = 61648,
    fetch = 125050,
    fireworks = 127933,
    call_pet_four = 83244,
    aspect_of_the_turtle = 186265,
    call_pet_five = 83245,
}
for i = 1, 3 do
    for j = 1, #insertGeneral do
        table.insert(gxHB[i], j, insertGeneral[j])
    end
end

gxMGB = {
    -- Arcane
    {},

    -- Fire
    {
        fire_blast = 108853,
        fireball = 133,
        pyroblast = 11366,
        heating_up = 48107,
        hot_streak = 48108,
        scorch = 2948,
        flamestrike = 2120,
        blazing_barrier = 235313,
        dragons_breath = 31661,
        combustion = 190319,
        invisibility = 66,
    
        shimmer = 212653,
        blast_wave = 157981,
        mirror_image = 55342,
        rune_of_power = 116011,
        rune_of_power_buff = 116014,
        incanters_flow = 116267,
        ring_of_frost = 113724,
        living_bomb = 44457,
        cinderstorm = 198929,
        meteor = 153561,
    
        phoenixs_flames = 194466,
    
        koralons_burning_touch = 132454,
        darcklis_dragonfire_diadem = 132863,
        marquee_bindings_of_the_sun_king = 132406,
        kaelthas_ultimate_ability = 209455,
        pyrotex_ignition_cloth = 144355,
        contained_infernal_core = 151809,
        erupting_infernal_core = 248147,
    },

    -- Frost
    {
        frostbolt = 116,
        fire_blast = 108853,
        ice_lance = 30455,
        summon_water_elemental = 31687,
        blizzard = 190356,
        flurry = 44614,
        fingers_of_frost = 44544,
        ice_barrier = 11426,
        brain_freeze = 190446,
        freeze = 231596,
        cone_of_cold = 120,
        icy_veins = 12472,
        invisibility = 66,
        cold_snap = 235219,
        frozen_orb = 84714,
        water_jet = 231598,
        icicles = 205473,
        
        ray_of_frost = 205021,
        bone_chilling = 205766,
        shimmer = 212653,
        ice_floes = 108839,
        mirror_image = 55342,
        rune_of_power = 116011,
        rune_of_power_buff = 116014,
        incanters_flow = 116267,
        ice_nova = 157997,
        ring_of_frost = 113724,
        frost_bomb = 112948,
        glacial_spike = 199786,
        comet_storm = 153595,

        ebonbolt = 214634,
        chain_reaction = 195418,
        chilled_to_the_core = 195446,
        freezing_rain = 240555,

        lady_vashjs_grasp = 132411,
        lady_vashjs_grasp_buff = 208147,
        magtheridons_banished_bracers = 138140,
        magtheridons_might = 214404,
        zannesu_journey = 133970,
        zannesu_journey_buff = 226852,
        ice_time = 144260,
        shattered_fragments_of_sindragosa = 151810,
        shattered_fragments_of_sindragosa_buff = 248176,
        rage_of_the_frost_wyrm = 248177,
    },
}
insertGeneral = {
    frost_nova = 122,
    conjure_refreshment = 190336,
    blink = 1953,
    counterspell = 2139,
    slow_fall = 130,
    ice_block = 45438,
    water_jet = 135029,
    spellsteal = 30449,

    shard_of_the_exodar = 132410,
    belovirs_final_stand = 133977,
    belovirs_final_stand_buff = 207283,
    soul_of_the_archmage = 151642,
}
for i = 1, 3 do
    for j = 1, #insertGeneral do
        table.insert(gxMGB[i], j, insertGeneral[j])
    end
end

gxMKB = {
    -- Brewmaster
    {},

    -- Mistweaver
    {},

    -- Windwalker
    {
        effuse = 116694,
        rising_sun_kick = 107428,
        disable = 116095,
        disable_root = 116706,
        fists_of_fury = 113656,
        detox = 218164,
        touch_of_death = 115080,
        spear_hand_strike = 116705,
        spinning_crane_kick = 101546,
        cyclone_strikes = 228287,
        combo_breaker_blackout_kick = 116768,
        flying_serpent_kick = 101545,
        storm_earth_and_fire = 137639,
        touch_of_karma = 122470,
    
        chi_burst = 123986,
        eye_of_the_tiger = 196608,
        chi_wave = 115098,
        chi_torpedo = 115008,
        tigers_lust = 116841,
        energizing_elixir = 115288,
        power_strikes = 129914,
        ring_of_peace = 116844,
        summon_black_ox_statue = 115315,
        leg_sweep = 119381,
        healing_elixir = 122281,
        diffuse_magic = 122783,
        dampen_harm = 122278,
        rushing_jade_wind = 116847,
        invoke_xuen_the_white_tiger = 123904,
        hit_combo = 196741,
        whirling_dragon_punch = 152175,
        serenity = 152173,
    
        fortifying_brew = 201318,
        zen_moment = 201325,
        grapple_weapon = 233759,
        tigereye_brew = 247483,
    
        strike_of_the_windlord = 205320,
        transfer_the_power = 195321,
        master_of_combinations = 240672,
        thunderfist = 242387,
    
        soul_of_the_grandmaster = 151643,
        cenedril_reflector_of_hatred = 137019,
        drinking_horn_cover = 137097,
        march_of_the_legion = 137220,
        hidden_masters_forbidden_touch = 137057,
        katsuos_eclipse = 137029,
        the_emperors_capacitor = 144239,
        the_emperors_capacitor_buff = 235054,
        the_wind_blows = 151811,
    
        pressure_point = 247255, -- tier 20 4pc
    },
}
insertGeneral = {
    blood_fury = 33697,

    tiger_palm = 100780,
    zen_flight = 125883,
    blackout_kick = 100784,
    roll = 109132,
    provoke = 115546,
    resuscitate = 115178,
    zen_pilgrimage = 126892,
    crackling_jade_lightning = 117952,
    paralysis = 115078,
    transcendence = 101643,
    transcendence_transfer = 119996,
}
for i = 1, 3 do
    for j = 1, #insertGeneral do
        table.insert(gxMKB[i], j, insertGeneral[j])
    end
end

gxPDB = {
    -- Holy
    {},

    -- Protection
    {},

    -- Retribution
    {},
}
insertGeneral = {

}
for i = 1, 3 do
    for j = 1, #insertGeneral do
        table.insert(gxPDB[i], j, insertGeneral[j])
    end
end

gxPRB = {
    -- Discipline
    {},

    -- Holy
    {},

    -- Shadow
    {},
}
insertGeneral = {

}
for i = 1, 3 do
    for j = 1, #insertGeneral do
        table.insert(gxPRB[i], j, insertGeneral[j])
    end
end

gxRB = {
    -- Assassination
    {
        sinister_strike = 1752,
        eviscerate = 196819,
        stealth = 1784,
        cheap_shot = 1833,
        deadly_poison = 2823,
        deadly_poison_debuff = 2818,
        poisoned_knife = 185565,
        garrote = 703,
        pick_pocket = 921,
        sap = 6770,
        rupture = 1943,
        shadowstep = 36554,
        blind = 2094,
        evasion = 5277,
        kidney_shot = 408,
        envenom = 32645,
        crippling_poison = 3408,
        crippling_poison_debuff = 3409,
        distract = 1725,
        mutilate = 1329,
        vanish = 1856,
        wound_poison = 8679,
        vendetta = 79140,
        fan_of_knives = 51723,

        elaborate_planning = 193641,
        hemorrhage = 16511,
        subterfuge = 115192,
        leeching_poison = 108211,
        cheating_death = 45182,
        cheated_death = 45181,
        toxic_blade = 245388,
        alacrity = 193538,
        exsanguinate = 200806,
        marked_for_death = 137619,
        death_from_above = 152150,

        shiv = 248744,
        neurotoxin  = 206328,

        kingsbane = 192759,
        blood_of_the_assassinated = 192925,
        master_assassin_trait = 330,

        duskwalkers_footpads = 137030,
        zoldyck_family_training_shackles = 137098,
        the_empty_crown = 151815,
        the_dreadlords_deceit = 137021,
        the_dreadlords_deceit_buff_assn = 208693,
    },

    -- Outlaw
    {
        stealth = 1784,
        cheap_shot = 1833,
        run_through = 2098,
        saber_slash = 193315,
        pistol_shot = 185763,
        pick_pocket = 921,
        sap = 6770,
        between_the_eyes = 199804,
        ambush = 8676,
        blind = 2094,
        riposte = 199754,
        gouge = 1776,
        distract = 1725,
        roll_the_bones = 193316,
        jolly_roger = 199603,
        grand_melee = 193358,
        shark_infested_waters = 193357,
        true_bearing = 193359,
        buried_treasure = 199600,
        broadsides = 193356,
        vanish = 1856,
        bribe = 199740,
        adrenaline_rush = 13750,
        blade_flurry = 13877,
    
        ghostly_strike = 196937,
        grappling_hook = 195457,
        cheating_death = 45182,
        cheated_death = 45181,
        parley = 199743,
        cannonball_barrage = 185767,
        alacrity = 193538,
        killing_spree = 51690,
        slice_and_dice = 5171,
        marked_for_death = 137619,
        death_from_above = 152150,
    
        shiv = 248744,
        take_your_cut = 198368,
        dismantle = 207777,
        plunder_armor = 198529,
    
        curse_of_the_dreadblades = 202665,
        hidden_blade = 202754,
        loaded_dice = 240837,
    
        thraxis_tricksy_treads = 137031,
        greenskins_waterlogged_wristcuffs = 137099,
        greenskins_waterlogged_wristcuffs_buff = 209423,
        shivarran_symmetry = 141321,
        shivarran_symmetry_buff = 226318,
        the_curse_of_restlessness = 151817,
    },

    -- Subtlety
    {
        eviscerate = 196819,
        stealth = 1784,
        cheap_shot = 1833 ,
        backstab = 53,
        shuriken_toss = 114014,
        shadowstrike = 185438,
        pick_pocket = 921,
        sap = 6770,
        nightblade = 195452,
        shadowstep = 36554,
        blind = 2094,
        evasion = 5277,
        kidney_shot = 408,
        symbols_of_death = 212283,
        distract = 1725,
        shadow_dance = 185313,
        shadow_dance_buff = 185422,
        vanish = 1856,
        shadow_blades = 121471,
        shuriken_storm = 197835,
        shuriken_combo = 245640,
    
        gloomblade = 200758,
        subterfuge = 115192,
        cheating_death = 45182,
        cheated_death = 45181,
        alacrity = 193538,
        marked_for_death = 137619,
        death_from_above = 152150,
    
        shiv = 248744,
        smoke_bomb = 212182,
        cold_blood = 213981,
        shadowy_duel = 207736,
    
        goremaws_bite = 209782,
        finality_eviscerate = 197496,
        finality_nightblade = 197498,
        feeding_frenzy = 242705,
    
        the_dreadlords_deceit = 137021,
        the_dreadlords_deceit_buff_sub = 228224,
        shadow_satyrs_walk = 137032,
        denial_of_the_half_giants = 137100,
        the_first_of_the_dead = 151818,
        the_first_of_the_dead_buff = 248210,
    },
}
insertGeneral = {
    crimson_vial = 185311,
    kick = 1766,
    pick_lock = 1804,
    sprint = 2983,
    feint = 1966,
    shroud_of_concealmeant = 114018,
    tricks_of_the_trade = 57934,
    cloak_of_shadows = 31224,

    insignia_of_ravenholdt = 137049,
    will_of_valeera = 137069,
    will_of_valeera_buff = 208403,
    mantle_of_the_master_assassin = 144236,
    mantle_of_the_master_assassin_buff = 235027,
    soul_of_the_shadowblade = 150936,

    smoke_powder_vault = 139585,
    sticky_bombs_vault = 139584,
    thistle_tea_vault = 139586,
}
for i = 1, 3 do
    for j = 1, #insertGeneral do
        table.insert(gxRB[i], j, insertGeneral[j])
    end
end

gxSB = {
    -- Elemental
    {},

    -- Enhancement
    {},

    -- Restoration
    {},
}
insertGeneral = {

}
for i = 1, 3 do
    for j = 1, #insertGeneral do
        table.insert(gxSB[i], j, insertGeneral[j])
    end
end

gxWLB = {
    -- Affliction
    {
        shadow_bolt = 232670,
        corruption = 172,
        corruption_debuff = 146739,
        life_tap = 1454,
        agony = 980,
        drain_soul = 198590,
        unstable_affliction = 30108,
        seed_of_corruption = 27243,
    
        haunt = 48181,
        absolute_corruption = 0,
        empowered_life_tap = 235156,
        demonic_circle = 48018,
        mortal_coil = 6789,
        howl_of_terror = 5484,
        phantom_singularity = 205179,
        soul_harvest = 196098,
        burning_rush = 111400,
        dark_pact = 108416,
        summon_doomguard_supremacy = 157757,
        summon_infernal_supremacy = 157898,
        grimoire_imp = 111859,
        grimoire_voidwalker = 111895,
        grimoire_succubus = 111896,
        grimoire_felhunter = 111897,
        grimoire_of_sacrifice = 108503,
        siphon_life = 63106,
    
        -- Honor Talents
    
        reap_souls = 216698,
        tormented_souls = 216695,
        deadwind_harvester = 216708,
        compounding_horror = 199281,
    
        sacrolashs_dark_strike = 132378,
        power_cord_of_lethtendris = 132457,
        stretens_sleepless_shackles = 132381,
        hood_of_eternal_disdain = 132394,
        reap_and_sow = 144364,
    },

    -- Demonology
    {},

    -- Destruction
    {},
}
insertGeneral = {
    summon_imp = 688,
    fear = 5782,
    create_healthstone = 6201,
    summon_voidwalker = 697,
    health_funnel = 755,
    eye_of_kilrogg = 126,
    unending_breath = 5697,
    summon_succubus = 712,
    banish = 710,
    summon_felhunter = 691,
    command_demon = 119898,
    ritual_of_summoning = 698,
    soulstone = 20707,
    summon_doomguard = 18540,
    unending_resolve = 104773,
    enslave_demon = 1098,
    summon_infernal = 1122,
    create_soulwell = 29893,
    demonic_gateway = 111771,

    pillars_of_the_dark_portal = 132357,
    soul_of_the_netherlord = 151649,
    the_master_harvester = 151821,
}
for i = 1, 3 do
    for j = 1, #insertGeneral do
        table.insert(gxWLB[i], j, insertGeneral[j])
    end
end

gxWRB = {
    -- Arms
    {
        slam = 1464,
        victory_rush = 34428,
        execute = 163201,
        mortal_strike = 12294,
        colossus_smash = 167105,
        colossus_smash_debuff = 208086,
        cleave = 845,
        cleave_buff = 188923,
        hamstring = 1715,
        die_by_the_sword = 118038,
        whirlwind = 1680,
        berserker_rage = 18499,
        battle_cry = 1719,
        bladestorm = 227847,
        intimidating_shout = 5246,
        commanding_shout = 97462,

        overpower = 7384,
        shockwave = 46968,
        storm_bolt = 107570,
        rend = 772,
        avatar = 107574,
        bounding_stride = 202164,
        defensive_stance = 197690,
        in_for_the_kill = 248622,
        focused_rage = 207982,
        ravager = 152277,

        warbreaker = 209577,
        shattered_defenses = 248625,
        executioners_precision = 242188,

        weight_of_the_earth = 137077,
        archavons_heavy_hand = 137060,
        the_great_storms_eye = 151823,
        tornados_eye = 248142, -- or 248145
        ayalas_stone_heart = 137052,
        stone_heart = 225947,
        najentuss_vertebrae = 137087,

        weighted_blade = 253383,
    },

    -- Fury
    {
        execute = 5308,
        bloodthirst = 23881,
        furious_slash = 100130,
        taste_for_blood = 206333,
        rampage = 184367,
        enrage = 184362,
        raging_blow = 85288,
        piercing_howl = 12323,
        enraged_regeneration = 184364,
        whirlwind = 190411,
        meat_cleaver = 85739,
        berserker_rage = 18499,
        battle_cry = 1719,
        intimidating_shout = 5246,
        commanding_shout = 97462,
    
        war_machine = 215562,
        shockwave = 46968,
        storm_bolt = 107570,
        wrecking_ball = 215570,
        avatar = 107574,
        furious_charge = 202225,
        bounding_stride = 202164,
        massacre = 206316,
        frothing_berserker = 215572,
        bloodbath = 12292,
        frenzy = 202539,
        bladestorm = 46924,
        dragon_roar = 118000,
    
        odyns_fury = 205545,
        juggernaut = 201009,
        odyns_champion = 200986,
        berserking_fury_artifact = 200953,
        sense_death = 200979,
    
        ceann_ar_charger = 137088,
        kazzalax_fujiedas_fury = 137053,
        fujiedas_fury = 207776,
        valarjar_berserkers = 151824,
    },

    -- Protection
    {
        victory_rush = 34428,
        devastate = 20243,
        shield_slam = 23922,
        thunder_clap = 6343,
        shield_block = 2565,
        shield_block_buff = 132404,
        revenge = 6572,
        revenge_buff = 5302,
        intercept = 198304,
        last_stand = 12975,
        ignore_pain = 190456,
        berserker_rage = 18499,
        demoralizing_shout = 1160,
        battle_cry = 1719,
        shield_wall = 871,
        spell_reflection = 23920,
    
        shockwave = 46968,
        storm_bolt = 107570,
        impending_victory = 202168,
        avatar = 107574,
        vengeance_revenge = 202573,
        vengeance_ignore_pain = 202574,
        ravager = 228920,
    
        -- Honor Talents
    
        neltharions_fury = 203524,
        dragon_scales = 203581,
    },
}
insertGeneral = {
    charge = 100,
    taunt = 355,
    heroic_throw = 57755,
    pummel = 6552,
    heroic_leap = 6544,

    mannoroths_bloodletting_manacles = 137107,
    timeless_stratagem = 143728,
    soul_of_the_battlelord = 151650,
}
for i = 1, 3 do
    for j = 1, #insertGeneral do
        table.insert(gxWRB[i], j, insertGeneral[j])
    end
end

-- apbf = 20572
-- apspbf = 33697
-- spbf = 33072

gxGB = {
    gift_of_the_naaru = 121093,
    stoneform = 20594,
    escape_artist = 20589,
    every_man_for_himself = 59752,
    shadowmeld = 58984,
    quaking_palm = 107079,
    darkflight = 68992,
    running_wild = 87840,
    two_forms = 68996,
    arcane_torrent = 129597,
    rocket_barrage = 69041,
    rocket_jump = 69070,
    war_stomp = 20549,
    berserking = 26297,
    cannibalize = 20577,
    will_of_the_forsaken = 7744,

    gladiators_medallion = 208683,

    sephuzs_secret = 132452,
    sephuzs_secret_buff = 208052,
    prydaz_xavarics_magnum_opus = 132444,
    xavarics_magnum_opus = 207472,
    amanthuls_vision = 154172,
    glimpse_of_enlightenment = 256818,
    amanthuls_grandeur = 256832,
    insignia_of_the_grand_army = 152626,
    norgannons_foresight = 132455,
    -- norgannons_foresight_buff = 208215,
    cinidaria_the_symbiote = 133976,
    roots_of_shaladrassil = 132466,
    aggramars_stride = 132443,
    archimondes_hatred_reborn = 144249,
    archimondes_hatred_reborn_buff = 235169,
    kiljaedens_burning_wish = 144259,
    velens_future_sight = 144258,
    velens_future_sight_buff = 235966,
    celumbra_the_nights_dichotomy = 146666,
    -- celumbra_the_nights_dichotomy_buff1 = 146666,
    -- celumbra_the_nights_dichotomy_buff2 = 146666,
    the_sentinels_eternal_refuge = 146669,
    the_sentinels_eternal_refuge_buff = 241846,
    -- the_sentinels_eternal_refuge_buff_wisp? = 241846,
    vigilance_perch = 146668,
    vigilance_perch_buff = 242066,
    -- vigilance_perch_buff_owl? = 242066,
    rethus_incessant_courage = 146667,
    -- rethus_incessant_courage_buff1 = 146667,
    -- rethus_incessant_courage_buff2 = 146667,

    convergence_of_fates = 140806,
}

local idsList = {"gxDKB", "gxDHB", "gxDRB", "gxHB", "gxMGB", "gxMKB", "gxPDB", "gxPRB", "gxRB", "gxSB", "gxWLB", "gxWRB"}
for _,v in pairs(idsList) do
    for r,c in pairs(gxGB) do
        -- _G[v][r] = c
        for i = 1, #_G[v] do
            _G[v][i][r] = c
        end
    end
end