gx.libraryVer = 51

-- Bug Fixes
local oldSetStat = PaperDollFrame_SetStat
PaperDollFrame_SetStat = function(statFrame, unit, statIndex)
   if statIndex == LE_UNIT_STAT_STAMINA then return end
   oldSetStat(statFrame, unit, statIndex)
end
-- local oldTargetNearestEnemy = TargetNearestEnemy
-- TargetNearestEnemy = function(backward)
--     local oldTarget = ObjectExists("target") and ObjectIdentifier("target") or nil
--     TargetNearest(backward)
--     if not UnitExists("target") then return end
--     if not UnitCanAttack("player", "target") and ObjectIdentifier("target") ~= oldTarget then TargetNearestEnemy() end
-- end
-- local oldHpPerStamina = UnitHPPerStamina
-- UnitHPPerStamina = function(unit)
--     -- if not unit then
--     --     return 0
--     -- else.
--     --     return oldHpPerStamina(unit)
--     -- end
--     return 0
-- end
-- Bug Fixes

local pgFrame = CreateFrame("Frame")
pgFrame:SetScript("OnUpdate", function(self, elapsed)
        if Engine_GetUsername() ~= "g1zstar" then self:SetScript("OnUpdate", nil) return end
        if GetGossipOptions() == "Enter the Proving Grounds" then SelectGossipOption(1) end
        if LFGDungeonReadyDialogInstanceInfoFrameName:IsVisible() and LFGDungeonReadyDialogInstanceInfoFrameName:GetText() == "Proving Grounds: White Tiger Temple" then LFGDungeonReadyDialogEnterDungeonButton:Click() end
        local obj
        for i = 1, GetObjectCount() do
            obj = GetObjectWithIndex(i)
            if ObjectExists(obj) and ObjectName(obj) == "Trial Master Rotun" then
                MoveTo(ObjectPosition(obj))
                ObjectInteract(obj)
            end
        end
        if GetGossipOptions() == "Start Basic Damage (Bronze)" then SelectGossipOption(1) end
        if GetGossipOptions() == "I yield!" then LeaveParty(); SelectGossipOption(1) end
    end)

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
    if IsControlKeyDown() and IsAltKeyDown() and IsShiftKeyDown() and GetKeyState(0x43) then gx.emptyCO() return end
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

function gx.getCost(spell)
    if not costFrame then 
        local costFrame = CreateFrame("GameTooltip", "costFrame", nil, "GameTooltipTemplate")
        costFrame:SetOwner(UIParent, "ANCHOR_NONE")
    end
    costFrame:ClearLines()
    costFrame:SetSpellByID(spell)
    costFrame:SetAlpha(0)

    local text = _G["costFrameTextLeft2"]:GetText()
    local match = string.match(text, "%d+%p*%s*%d*%p*%s*%d*%p*%s*%d*")
    if not match then match = 0 end
    return tonumber(match)
end

function gx.notEnoughEnergyFor(spell)
    return select(2, IsUsableSpell(spell))
end

function gx.poolEnergyFor(spell, castAfter, unit)
    gx.queueUpCO(function()
            while (not castable(spell) and gx.notEnoughEnergyFor(spell) and player.time > 0) do
                coroutine.yield()
                gx.printd("Pooling for "..GetSpellInfo(spell))
            end
            if castAfter and UnitExists(unit.unitID) and not UnitIsDeadOrGhost(unit.unitID) then
                while (player.spell(spell).cooldown == 0 and player.spell(61304).cooldown == 0 and player.time > 0) do
                    cast(spell, unit)
                    coroutine.yield()
                    gx.printd("Casting "..GetSpellInfo(spell).." after Pooling")
                end
            end
        end)
end

function gx.castThrough(spell, unit, tickTime)
    if not tickTime or tickTime == 0 then CastSpellByID(spell, unit.unitID) return end
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
      
        -- local SPIRIT_REALM = GetSpellInfo(235621)
        -- local playerRealm = UnitDebuff("player", SPIRIT_REALM)
        -- local unitRealm = UnitDebuff(target, SPIRIT_REALM)
        -- gx.printd("Constant Realm is ", SPIRIT_REALM, ". Player Realm is ", playerRealm, " Target Realm is ", unitRealm, "Realms Match: ", playerRealm == unitRealm)
    end
end
icdFrame:SetScript("OnEvent", setICDs)

function gx.sephuzsAvailable()
    return IsEquippedItem(132452) and GetTime() > sephuzs_cd
end

local overrideList = {
}
function gx.setOverride(itemID, bool) overrideList[itemID] = bool end

function gx.itemUsable(itemID, target)
    if not IsEquippedItem(itemID) then return false end
    local slot = -1
    for i = 1, 17 do if GetInventoryItemID("player", i) == itemID then slot = i end end
    local start, duration, enable = GetInventoryItemCooldown("player", slot)
    if start == 0 then return true end
    return false
end

function gx.use_items(target)
    for i = 1, 17 do
        local itemID = GetInventoryItemID("player", i)
        if itemID and not overrideList[itemID] and gx.itemUsable(itemID, target) then
            UseInventoryItem(i)
        end
    end
end

function gx.use_item(itemID, target)
    local slot = -1
    for i = 1, 17 do if GetInventoryItemID("player", i) == itemID then slot = i end end
    UseInventoryItem(i)
end

function gx.itemCooldown(itemID)
    local slot = -1
    for i = 1, 17 do if GetInventoryItemID("player", i) == itemID then slot = i end end
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
    {
        asphyxiate = 221562,
        heart_strike = 206930,
        marrowrend = 195182,
        bone_shield = 0,
        blood_boil = 50842,
        blood_plague = 0,
        death_and_decay = 43265,
        death_and_decay_buff = 0,
        dancing_rune_weapon = 49028,
        dancing_rune_weapon_buff = 0,
        icebound_fortitude = 48792,
        deaths_caress = 195292,
        vampiric_blood = 55233,
        wraith_walk = 212552,
        crimson_scource = 0,
        gorefiends_grasp = 108199,
        blood_shield = 0,

        bloodworms = 0,
        blooddrinker = 206931,
        blood_tap = 221699,
        mark_of_blood = 206940,
        tombstone = 21980,
        rune_tap = 194679,
        bonestorm = 194844,
        blood_mirror = 206977,
        purgatory = 0,

        consumption = 205223,
        mouth_of_hell = 0,
        umbilicus_eternus = 193249,
        unending_thirst = 0,
        vampiric_aura = 238698,
        souldrinker = 0,
        concordance_of_the_legionfall = 243096,

        shackles_of_bryndaor = 132365,
        rattlegore_bone_legplates = 132453,
        service_of_gorefiend = 132367,
        lanathels_lament = 133974,
        lanathels_lament_buff = 212975,
        skullflowers_haemostasis = 144281,
        haemostasis = 235559,
        soulflayers_corruption = 151795,

        gravewarden = 242010,
    },

    -- Frost
    {
        frost_strike = 49143,
        howling_blast = 49184,
        frost_fever = 55095,
        obliterate = 49020,
        killing_machine = 51124,
        empower_rune_weapon = 47568,
        icebound_fortitude = 48792,
        pillar_of_frost = 51271,
        remorseless_winter = 196770,
        dark_succor = 101568,
        rime = 59052,
        wraith_walk = 212552,
        chains_of_ice = 45524,

        icy_talons = 194879,
        horn_of_winter = 57330,
        glacial_advance = 194913,
        blinding_sleet = 207167,
        winter_is_coming = 211794,
        winter_is_coming_stun = 207171,
        permafrost = 207203,
        inexorable_assault = 253595,
        frostscythe = 207230,
        gathering_storm = 211805,
        obliteration = 207256,
        breath_of_sindragosa = 152279,
        hungering_rune_weapon = 207127,

        sindragosas_fury = 190778,
        concordance_of_the_legionfall = 242583,

        seal_of_necrofantasia = 137223,
        koltiras_newfound_will = 132366,
        toravons_whiteout_bindinds = 132458,
        perseverance_of_the_ebon_martyr = 132459,
        consorts_cold_core = 144293,
        cold_heart = 151796,
        cold_heart_buff = 235599,

        --[[Item - Death Knight T20 Frost 4P Bonus
                        Requires Death Knight
                        Every 3 Runes spent increases the Strength bonus of your next Pillar of Frost by 1%.]]
        --[[Item - Death Knight T21 Blood 4P Bonus
                        Requires Death Knight
                        When Dancing Rune Weapon fades, your Rune regeneration rate is increased by 40% for 10 sec.]]
    },
    
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
        death_and_decay_buff = 188290,
        icebound_fortitude = 48792,
        dark_succor = 101568,
        wraith_walk = 212552,
        chains_of_ice = 45524,
        sudden_doom = 81340,
        dark_transformation = 63560,
        summon_gargoyle = 49206,
        army_of_the_dead = 42650,

        epidemic = 207317,
        blighted_rune_weapon = 194918,
        unholy_frenzy = 207290,
        clawing_shadows = 207311,
        asphyxiate = 108194,
        corpse_shield = 207319,
        necrosis = 216974,
        dark_arbiter = 207349,
        defile = 152280,
        soul_reaper = 130736,
        soul_reaper_buff = 215711,

        -- Honor Talents

        apocalypse = 220143,
        gravitational_pull = 0,
        scourge_of_the_worlds = 191748,
        concordance_of_the_legionfall = 242583,

        cold_heart = 151796,
        cold_heart_buff = 235599,
        taktheritrixs_shoulderpads = 137075,
        taktheritrixs_command = 215069,
        draugr_girdle_of_the_everlasting_king = 132441,
        uvanimor_the_unbeautiful = 137037,
        the_instructors_fourth_lesson = 132448,
        death_march = 144280,

        --[[Item - Death Knight T20 Unholy 2P Bonus
                        Requires Death Knight
                        Each ghoul summoned by Army of the Dead increases your damage dealt by 15% for 3 sec. Duration extends and does not stack.]]
        --[[Item - Death Knight T21 Unholy 2P Bonus
                        Requires Death Knight
                        Death Coil causes the target to take an additional 25% of the direct damage dealt over 4 sec.]]
    },
}
insertGeneral = {
    blood_fury = 20572,

    frost_breath = 190780,
    corse_explosion = 127344,
    death_gate = 50977,
    death_grip = 49576,
    death_strike = 49998,
    runeforging = 53428,
    unholy_strength = 53365,
    razorice = 51715,
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
    for k,v in pairs(insertGeneral) do
        gxDKB[i][k] = v
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
        balanced_blades = 0,
        demon_speed = 0,
        anguish = 202443,
        concordance_of_the_legionfall = 242584,

        moarg_bionic_stabilizers = 137090,
        raddons_cascading_eyes = 137061,
        achor_the_eternal_hunger = 137014,
        loramus_thalipedes_sacrifice = 137022,
        anger_of_the_halfgiants = 137038,
        delusions_of_grandeur = 144279,
        chaos_theory = 151798,

        --[[Item - Demon Hunter T21 Havoc 4P Bonus
                        Requires Demon Hunter
                        When Eye Beam finishes fully channeling, your Haste is increased by 40% for 8 sec.]]
    },

    -- Vengeance
    {
        demon_spikes = 203720,
        demon_spikes_buff = 0,
        fiery_brand = 204021,
        immolation_aura = 178740,
        infernal_strike = 189110,
        metamorphosis = 187827,
        shear = 203782,
        sigil_of_flame = 204596,
        soul_cleave = 228477,
        throw_glaive = 204157,
        torment = 185245,
        sigil_of_silence = 202137,
        empower_wards = 218256,
        sigil_of_misery = 207684,

        felblade = 232893,
        fel_eruption = 211881,
        fracture = 209795,
        sigil_of_chains = 202138,
        fel_devastation = 212084,
        blade_turning = 247253,
        spirit_bomb = 247454,
        spirit_bomb_debuff = 0,
        last_resort = 0,
        demonic_infusion = 236189,
        soul_barrier = 227225,

        soul_carver = 207407,
        defensive_spikes = 0,
        siphon_power = 0,
        fiery_demise = 0,
        painbringer = 207387,
        concordance_of_the_legionfall = 243096,

        cloak_of_fel_flames = 137066,
        kirel_narak = 138949,
        runemasters_pauldron = 137071,
        the_defilers_lost_vambraces = 137091,
        fragment_of_the_betrayers_prison = 138854,
        spirit_of_the_darkness_flame = 144292,
        spirit_of_the_darkness_flame_buff = 235543,
        oblivions_embrace = 151799,

        --[[Item - Demon Hunter T20 Vengeance 2P Bonus
                        Requires Demon Hunter
                        When you consume a Soul Fragment, all enemies within 10 yards deal 5% less damage to you for 6 sec.]]
        --[[Item - Demon Hunter T20 Vengeance 4P Bonus  Level 110
                        Requires Demon Hunter
                        After using Soul Cleave, you gain 2000 Versatility for 8 sec.]]
    },
}
insertGeneral = {
    blood_fury = 20572,

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
    spectral_sight = 188501,
    throw_glaive = 185123,
    vengeful_retreat = 198793,

    soul_of_the_slayer = 151639,
}
for i = 1, 2 do
    for k,v in pairs(insertGeneral) do
        gxDHB[i][k] = v
    end
end

gxDRB = {
    -- Balance
    {
        solar_wrath = 190984,
        starsurge = 78674,
        lunar_empowerment = 164547,
        solar_empowerment = 164545,
        lunar_strike = 194153,
        prowl = 5215,
        sunfire = 93402,
        moonkin_form = 24858,
        remove_corruption = 2782,
        barkskin = 22812,
        starfall = 191034,
        stellar_empowerment = 0,
        celestial_alignment = 194223,
        innervate = 29166,

        force_of_nature = 205636,
        warrior_of_elune = 202425,
        renewal = 108238,
        displacer_beast = 102280,
        wild_charge = 132302, --?
        -- feral_affinity
        -- guardian_affinity
        -- restoration_affinity
        mighty_bash = 5211,
        mass_entanglement = 102359,
        typhoon = 132469,
        incarnation_chosen_of_elune = 102560,
        stellar_flare = 202347,
        astral_communion = 202359,
        blessing_of_the_ancients = 202360,
        blessing_of_elune = 0,
        blessing_of_anshe = 0,
        fury_of_elune = 202770,

        new_moon = 0,
        half_moon = 0,
        full_moon = 0,
        rapid_innervation = 0,
        moon_and_stars = 202942,
        wax_and_wane = 239952,
        circadian_invocation = 238119,
        concordance_of_the_legionfall = 242586,

        impeccable_fel_essence = 137039,
        promise_of_elune_the_moon_goddess = 137023,
        promise_of_elune_the_moon_goddess_buff = 208284,
        the_emerald_dreamcatcher = 137062,
        the_emerald_dreamcatcher_buff = 224706,
        oneths_intuition = 137092,
        oneths_intuition_buff = 209406,
        oneths_overconfidence = 209407,
        lady_and_the_child = 144295,
        radiant_moonlight = 151800,

        astral_acceleration = 242232,
        solar_solstice = 252767,
    },

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
        protection_of_ashamane = 0,
        ashamanes_energy = 0,
        scent_of_blood = 0,
        feral_instinct = 0,
        open_wounds = 0,
        ashamanes_bite = 0,
        fury_of_ashamane = 240670,
        bloodletters_frailty = 0,
        concordance_of_the_legionfall = 242584,
    
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
    {
        mangle = 33917,
        maul = 6807,
        thrash = 106832,
        thrash_debuff = 0,
        prowl = 5215,
        ironfur = 192081,
        remove_corruption = 2782,
        barkskin = 22812,
        incapacitating_roar = 99,
        swipe = 213764,
        survival_instincts = 61336,
        frenzied_regeneration = 22842,
        gore = 0,
        stampeding_roar = 106898,
        skull_bash = 106839,

        brambles = 0,
        bristling_fur = 155835,
        intimidating_roar = 236748,
        wild_charge = 132302, --?
        -- balance_affinity
        -- feral_affinity
        -- restoration_affinity
        mighty_bash = 5211,
        mass_entanglement = 102359,
        typhoon = 132469,
        incarnation_guardian_of_ursoc = 102558,
        galactic_guardian = 0,
        earthwarden = 0,
        guardian_of_elune = 213680,
        rend_and_tear = 0,
        lunar_beam = 204066,
        pulverize = 80313,

        rage_of_the_sleeper = 200851,
        bloody_paws = 214995,
        gory_fur = 201671,
        adaptive_fur = 0,
        embrace_of_the_nightmare = 0,
        scintillating_moonlight = 0,
        concordance_of_the_legionfall = 243096,

        luffa_wrappings = 137056,
        skysecs_hold = 137025,
        elizes_everlasting_encasement = 137067,
        dual_determination = 137041,
        oakhearts_puny_quods = 144432,
        oakhearts_puny_quods_buff = 236479,
        fury_of_nature = 151802,

        natural_defenses = 211160,
        --[[Item - Druid T21 Guardian 4P Bonus
                        Requires Druid
                        When Barkskin fades, all healing done to you is increased by 10% for 20 sec.]]
    },

    -- Restoration
    {
        solar_wrath = 5176,
        rejuvenation = 774,
        swiftmend = 18562,
        prowl = 5215,
        sunfire = 93402,
        lifebloom = 33763,
        natures_cure = 88423,
        healing_touch = 5185,
        barkskin = 22812,
        wild_growth = 48438,
        clearcasting = 16870,
        innervate = 29166,
        ironbark = 102342,
        living_seed = 0,
        ursols_vortex = 102793,
        revitalize = 212040,
        efflorescence = 145205,
        tranquility = 740,

        cenarion_ward = 102351,
        abundance = 0,
        renewal = 108238,
        displacer_beast = 102280,
        wild_charge = 132302, -- ?
        -- balance_affinity
        -- feral_affinity
        -- guardian_affinity
        mighty_bash = 5211,
        mass_entanglement = 102359,
        typhoon = 132469,
        soul_of_the_forest = 0,
        incarnation_tree_of_life = 33891,
        cultivation = 0,
        spring_blossoms = 0,
        germination = 0,
        flourish = 197721,

        essence_of_ghanir = 208253,
        power_of_the_archdruid = 189877,
        dreamwalker = 0,
        deep_rooted = 0,
        concordance_of_the_legionfall = 242586,

        tearstone_of_elune = 137042,
        essence_of_infusion = 137026,
        edraith_bonds_aglaya = 137095,
        amanthuls_wisdom = 137072,
        the_dark_titans_advice = 137078,
        xionis_caress = 144242,
        chameleon_song = 151783,

        astral_harmony = 232378,
        blossoming_efflorescence = 242315,
        dreamer = 253432,
        awakened = 253434,
    },
}
insertGeneral = {
    blood_fury = 33697,

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
    for k,v in pairs(insertGeneral) do
        gxDRB[i][k] = v
    end
end

gxHB = {
    -- Beast Mastery
    {
        cobra_shot = 193455,
        concussive_shot = 5116,
        kill_command = 34026,
        dire_beast = 120679,
        multi_shot = 2643,
        freezing_trap = 187650,
        exhilaration = 109304,
        aspect_of_the_wild = 193530,
        counter_shot = 147362,
        tar_trap = 187698,
        bestial_wrath = 19574,
        misdirection = 34477,
        beast_cleave = 0,

        dire_frenzy = 217200,
        chimaera_shot = 53209,
        posthaste = 0,
        trailblazer = 0,
        binding_shot = 109248,
        wyvern_sting = 19386,
        intimidation = 19577,
        a_murder_of_crows = 131894,
        barrage = 120360,
        volley = 194386,
        stampede = 201430,

        titans_thunder = 207068,
        hunters_advantage = 0,
        jaws_of_thunder = 0,
        thunderslash = 0,
        cobra_commander = 0,

        roar_of_the_seven_lions = 137080,
        qapla_eredun_war_order = 137227,
        the_apex_predators_claw = 137382,
        the_mantle_of_command = 144326,
        parsels_tongue = 151805,
        parsels_tongue_buff = 248085,
        call_of_the_wild = 137101,

        -- bestial_wrath = 211183, -- t19 4pc
        --[[Item - Hunter T20 Beast Mastery 2P Bonus
                        Requires Hunter
                        Cobra Shot, Multi-shot, and Kill Command increase the damage bonus of Bestial Wrath by 1.5% for its remaining duration.]]
    },
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

        lone_wolf = 0,
        steady_focus = 0,
        lock_and_load = 194594,
        black_arrow = 194599,
        true_aim = 199803,
        posthaste = 0,
        trailblazer = 0,
        explosive_shot = 212431,
        sentinel = 206817,
        binding_shot = 109248,
        wyvern_sting = 19386,
        camouflage = 199483,
        a_murder_of_crows = 131894,
        barrage = 120360,
        volley = 194386,
        sidewinders = 214579,
        piercing_shot = 198670,
    
        -- Honor Talents
    
        windburst = 204147,
        survival_of_the_fittest = 0,
        feet_of_wind = 240777,
        bullseye = 204090,
        rapid_killing = 191342,
        cyclonic_burst = 0,

        magnetized_blasting_cap_launcher = 141353,
        ullrs_feather_snowshoes = 137033,
        zevrims_hunger = 137055,
        war_belt_of_the_sentinel_army = 137081,
        sentinels_sight = 208913,
        mkii_gyroscopic_stabilizer = 144303,
        gyroscopic_stabilization = 235712, --?
        celerity_of_the_windrunners = 151803,
        celerity_of_the_windrunners_buff = 248088,

        --[[Item - Hunter T20 Marksmanship 4P Bonus
                        Requires Hunter
                        Casting two Aimed Shots in a row increases your critical strike damage by 10% for 6 sec.]]
        precision = 246153,
    },

    -- Survival
    {
        harpoon = 190925,
        raptor_strike = 186270,
        wing_clip = 195645,
        flanking_strike = 202800,
        hatchet_toss = 193265,
        survivalist = 164857,
        freezing_trap = 187650,
        mongoose_bite = 190928,
        mongoose_fury = 190931,
        exhilaration = 109304,
        lacerate = 185855,
        muzzle = 187707,
        tar_trap = 187698,
        aspect_of_the_eagle = 186289,
        carve = 187708,
        explosive_trap = 191433,

        throwing_axes = 200163,
        moknathal_tactics = 201081,
        a_murder_of_crows = 206505,
        snake_hunter = 201078,
        posthaste = 0,
        disengage = 781,
        trailblazer = 0,
        caltrops = 194277,
        steel_trap = 162488,
        sticky_bomb = 191241,
        rangers_net = 200108,
        camouflage = 199483,
        butchery = 212436,
        dragonsfire_grenade = 194855,
        serpent_sting = 0,
        spitting_cobra = 194407,

        fury_of_the_eagle = 203415,
        aspect_of_the_skylord = 203927,
        on_the_trail = 204081,
        echo_of_ohnara = 0,

        call_of_the_wild = 137101,
        nesingwarys_trapping_treads = 137034,
        frizzos_fingertrap = 137043,
        helbrine_rope_of_the_mist_marauder = 137082,
        helbrine_rope_of_the_mist_marauder_buff = 0,
        butchers_bone_apron = 144361,
        butchers_bone_apron_buff = 236446,
        unseen_predators_cloak = 151807,

        --[[Item - Hunter T19 Survival 4P Bonus
                        Requires Hunter
                        When Mongoose Fury reaches 6 applications, you gain 15% increased damage to all abilities for 10 sec.]]
        exposed_flank = 252094,
        in_for_the_kill = 252095,
    },
}
insertGeneral = {
    blood_fury = 20572,

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

    concordance_of_the_legionfall = 242584,

    the_shadow_hunters_voodoo_mask = 137064,
    soul_of_the_huntmaster = 151641,
}
for i = 1, 3 do
    for k,v in pairs(insertGeneral) do
        gxHB[i][k] = v
    end
end

gxMGB = {
    -- Arcane
    {
        displacement = 0,
        arcane_barrage = 44425,
        arcane_blast = 30451,
        arcane_missiles = 5143,
        arcane_explosion = 1449,
        evocation = 12051,
        prismatic_barrier = 235450,
        slow = 31589,
        arcane_power = 12042,
        invisibility = 66,
        presence_of_mind = 205025,
        greater_invisibility = 110959,

        arcane_familiar = 205022,
        arcane_familiar_buff = 210126,
        shimmer = 212653,
        mirror_image = 55342,
        rune_of_power = 116011,
        rune_of_power_buff = 0,
        incanters_flow = 0,
        supernova = 157980,
        charged_up = 205032,
        chrono_shift_buff = 236298,
        chrono_shift_debuff = 236299,
        ring_of_frost = 113724,
        nether_tempest = 114923,
        erosion = 210134,
        arcane_orb = 153626,

        mark_of_aluneth = 224968,
        touch_of_the_magi = 210824,

        rhonins_assaulting_armwraps = 132413,
        rhonins_assaulting_armwraps_buff = 208081,
        cord_of_infinity = 132442,
        cord_of_infinity_buff = 209316,
        mystic_kilt_of_the_rune_master = 132451,
        gravity_spiral = 144274,
        mantle_of_the_first_kirin_tor = 151808,

        crackling_energy = 246224,
        --[[Item - Mage T21 Arcane 2P Bonus
                        Requires Mage
                        Each Arcane Charge you spend increases your damage dealt by 4% for 8 sec.]]
        quick_thinker = 253299,
    },

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
        scorched_earth = 0,
        molten_skin = 0,
        cauterizing_blink = 0,
        blast_furnace = 194522,
        pyretic_incantation = 0,
        phoenix_reborn = 0,
        warmth_of_the_phoenix = 240671,
    
        koralons_burning_touch = 132454,
        darcklis_dragonfire_diadem = 132863,
        marquee_bindings_of_the_sun_king = 132406,
        kaelthas_ultimate_ability = 209455,
        pyrotex_ignition_cloth = 144355,
        contained_infernal_core = 151809,
        erupting_infernal_core = 248147,

        streaking = 211399,
        ignition = 246261,
        critical_massive = 242251,
        inferno = 253220,
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
        jouster = 0,
        black_ice = 0,
        chain_reaction = 195418,
        chilled_to_the_core = 195446,
        freezing_rain = 240555,
        glacial_eruption = 0,

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

        frozen_mass = 242253,
        --[[Item - Mage T21 Frost 4P Bonus
                        Requires Mage
                        When you consume Brain Freeze, the damage of your next Ice Lance is increased by 25%.]]
    },
}
insertGeneral = {
    blood_fury = 33072,

    illusion = 131784,
    polymorph_polar_bear_cub = 161353,
    polymorph_penguin = 161355,
    polymorph_porcupine = 126819,
    polymorph_monkey = 161354,
    polymorph_turkey = 61780,
    shoot = 5019,
    frost_nova = 122,
    polymorph = 118, -- sheep
    conjure_refreshment = 190336,
    blink = 1953,
    counterspell = 2139,
    slow_fall = 130,
    ice_block = 45438,
    polymorph_rabbit = 61721,
    polymorph_turtle = 28271,
    polymorph_black_cat = 61305,
    polymorph_peacock = 161372,
    polymorph_pig = 28272,
    water_jet = 135029,
    spellsteal = 30449,
    timewarp = 80353,

    concordance_of_the_legionfall = 242586,

    shard_of_the_exodar = 132410,
    belovirs_final_stand = 133977,
    belovirs_final_stand_buff = 207283,
    soul_of_the_archmage = 151642,
}
for i = 1, 3 do
    for k,v in pairs(insertGeneral) do
        gxMGB[i][k] = v
    end
end

gxMKB = {
    -- Brewmaster
    {
        effuse = 116694,
        blackout_strike = 205523,
        elusive_brawler = 0,
        keg_smash = 121253,
        light_stagger = 0,
        moderate_stagger = 0,
        heavy_stagger = 0,
        ironskin_brew = 115308,
        ironskin_brew_buff = 0,
        detox = 218164,
        purifying_brew = 119582,
        spear_hand_strike = 116705,
        breath_of_fire = 115181,
        breath_of_fire_debuff = 0,
        expel_harm = 115072,
        fortifying_brew = 115203,
        zen_meditation = 115176,

        chi_burst = 123986,
        eye_of_the_tiger = 196608,
        chi_wave = 115098,
        chi_torpedo = 115008,
        tigers_lust = 116841,
        black_ox_brew = 115399,
        ring_of_peace = 116844,
        summon_black_ox_statue = 115315,
        leg_sweep = 119381,
        healing_elixir = 122281,
        dampen_harm = 122278,
        rushing_jade_wind = 116847,
        invoke_niuzao_the_black_ox = 132578,
        elusive_dance = 0,
        blackout_combo = 228563,

        exploding_keg = 214326,
        gifted_student = 227678,
        swift_as_a_coursing_river = 213177,
        dark_side_of_the_moon = 0,
        hot_blooded = 0,
        brew_stache = 214373,
        fortification = 213341,
        concordance_of_the_legionfall = 243096,

        firestone_walkers = 137027,
        salsalabims_lost_tunic = 137016,
        fundamental_observation = 137063,
        gai_plins_soothing_sash = 137079,
        jewel_of_the_lost_abbey = 137044,
        anvilhardened_wristwraps = 144277,
        stormstouts_last_gasp = 151788,
    },

    -- Mistweaver
    {
        effuse = 116694,
        rising_sun_kick = 107428,
        soothing_mist = 0,
        enveloping_mist = 124682,
        teachings_of_the_monastery = 0,
        renewing_mist = 115151,
        renewing_mist_buff = 0,
        renewing_mist_vivify_proc = 0,
        detox = 115450,
        vivify = 116670,
        life_cocoon = 116849,
        essence_font = 191837,
        essence_font_buff = 191840,
        spinning_crane_kick = 101546,
        thunder_focus_tea = 116680,
        fortifying_brew = 243435,
        reawaken = 212051,
        revival = 115310,
        gust_of_mists = 0,

        chi_burst = 123986,
        zen_pulse = 124081,
        chi_wave = 115098,
        chi_torpedo = 115008,
        tigers_lust = 116841,
        lifecycles_vivify = 0,
        lifecycles_enveloping_mist = 0,
        ring_of_peace = 116844,
        song_of_chiji = 198898,
        leg_sweep = 119381,
        healing_elixir = 122281,
        diffuse_magic = 122783,
        dampen_harm = 122278,
        refreshing_jade_wind = 196725,
        invoke_chiji_the_red_crane = 198664,
        summon_jade_serpent_statue = 115313,
        mana_tea = 197908,

        sheiluns_gift = 205406,
        spirit_tether = 199387,
        shroud_of_mist = 0,
        light_on_your_feet = 0,
        the_mists_of_sheilun = 199888,
        blessings_of_yulon = 0,
        concordance_of_the_legionfall = 242586,

        eye_of_collidus_the_warpwatcher = 137045,
        collidus_the_warpwatchers_gaze = 217474,
        petrichor_lagniappe = 137096,
        leggings_of_the_black_flame = 137068,
        the_black_flames_gamble_effuse = 216992,
        the_black_flames_gamble_enveloping_mist = 216995,
        the_black_flames_gamble_essence_font = 217000,
        the_black_flames_gamble_renewing_mist = 216509,
        the_black_flames_gamble_vivify = 217006,
        unison_spaulders = 137073,
        eithas_lunar_glides_of_eramas = 137028,
        ovyds_winter_wrap = 138879,
        shelter_of_rin = 144340,

        surge_of_mists = 246328,
        --[[Item - Monk T20 Mistweaver 4P Bonus
                        Requires Monk
                        When you consume Surge of Mist, your healing done is increased by 12% for 10 sec.]]
        tranquil_mist = 253448,
        --[[Item - Monk T21 Mistweaver 4P Bonus
                        Requires Monk
                        When you cast Renewing Mist, you have a 100% chance to send a bolt of healing Chi at all targets affected by Tranquil Mist, healing them for (300% of Spell power).]]
    },

    -- Windwalker
    {
        effuse = 116694,
        rising_sun_kick = 107428,
        mortal_wounds = 0,
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
        concordance_of_the_legionfall = 242584,
    
        cenedril_reflector_of_hatred = 137019,
        drinking_horn_cover = 137097,
        march_of_the_legion = 137220,
        hidden_masters_forbidden_touch = 137057,
        katsuos_eclipse = 137029,
        the_emperors_capacitor = 144239,
        the_emperors_capacitor_buff = 235054,
        the_wind_blows = 151811,
    
        --[[Item - Monk T19 Windwalker 4P Bonus Level 110
                        Requires Monk
                        Using 3 sequentially different abilities grants 2000 Mastery for 10 sec.]]
        pressure_point = 247255, -- tier 20 4pc
    },
}
insertGeneral = {
    blood_fury = 33697,

    tiger_palm = 100780,
    zen_flight = 125883,
    blackout_kick = 100784,
    roll = 109132,
    soothing_mist = 209525,
    provoke = 115546,
    resuscitate = 115178,
    zen_pilgrimage = 126892,
    crackling_jade_lightning = 117952,
    paralysis = 115078,
    transcendence = 101643,
    transcendence_transfer = 119996,

    soul_of_the_grandmaster = 151643
}
for i = 1, 3 do
    for k,v in pairs(insertGeneral) do
        gxMKB[i][k] = v
    end
end

gxPDB = {
    -- Holy
    {
        flash_of_light = 19750,
        hammer_of_justice = 853,
        holy_shock = 20473,
        consecration = 26573,
        beacon_of_light = 53563,
        cleanse = 4987,
        holy_light = 82326,
        divine_protection = 498,
        infusion_of_light = 54149,
        light_of_dawn = 85222,
        blessing_of_protection = 1022,
        light_of_the_martyr = 183998,
        blessing_of_sacrifice = 6940,
        absolution = 212056,
        aura_mastery = 31821,
        avenging_wrath = 31842,

        bestow_faith = 223306,
        lights_hammer = 114158,
        rule_of_law = 214202,
        repentance = 20066,
        blinding_light = 115750,
        devotion_aura = 183425,
        aura_of_sacrifice = 183416,
        aura_of_mercy = 183415,
        divine_purpose = 0,
        holy_avenger = 105809,
        holy_prism = 114165,
        fervent_martyr = 0,
        judgment_of_light = 196941,
        beacon_of_faith = 156910,
        beacon_of_virtue = 200025,

        tyrs_deliverance = 200652,
        knight_of_the_silver_hand = 0,
        power_of_the_silver_hand_accumulation = 200656,
        power_of_the_silver_hand = 200657,
        protection_of_tyr = 211210,
        the_light_saves = 0,
        sacred_dawn = 0,
        concordance_of_the_legionfall = 242586,

        ilterendi_crown_jewel_of_silvermoon = 137046,
        ilterendi_crown_jewel_of_silvermoon_buff = 207589,
        obsidian_stone_spaulders = 137076,
        tyrs_hand_of_faith = 137059,
        maraads_dying_breath = 144273,
        maraads_dying_breath_buff = 234862,
        the_topless_tower = 151782,
        uthers_guard = 137105,

        lights_embrace = 247237,
        purity_of_light = 254332,
    },

    -- Protection
    {
        -- blessed_hammer = 0,
        flash_of_light = 19750,
        hammer_of_justice = 853,
        avengers_shield = 31935,
        hammer_of_the_righteous = 53595,
        righteous_fury = 0,
        consecration = 26573,
        shield_of_the_righteous = 53600,
        shield_of_the_righteous_buff = 0,
        cleanse_toxins = 213644,
        divine_protection = 498,
        rebuke = 96231,
        light_of_the_protector = 184092,
        blessing_of_protection = 1022,
        ardent_defender = 31850,
        blessing_of_sacrifice = 6940,
        guardian_of_ancient_kings = 86659,
        avenging_wrath = 31884,

        blessed_hammer = 204019,
        bastion_of_light = 204035,
        repentance = 20066,
        blinding_light = 115750,
        blessing_of_spellwarding = 204018,
        retribution_aura = 203797,
        hand_of_the_protector = 213652,
        aegis_of_light = 204150,
        judgment_of_light = 196941,
        seraphim = 152262,
        last_defender = 0,

        eye_of_tyr = 209202,
        faiths_armor = 0,
        forbearant_faithful = 0,
        bulwark_of_order = 0,
        light_of_the_titans = 209539,
        defender_of_truth = 0,
        blessed_stalwart = 242869,
        concordance_of_the_legionfall = 243096,

        uthers_guard = 137105,
        heathcliffs_immortality = 137047,
        tyelca_ferren_marcus_stature = 137070,
        breastplate_of_the_golden_valkyr = 137017,
        saruans_resolve = 144275,
        pillars_of_inmost_light = 151812,

        avengers_protection = 242265,
    },

    -- Retribution
    {
        flash_of_light = 19750,
        hammer_of_justice = 853,
        templars_verdict = 85256,
        blade_of_justice = 184575,
        cleanse_toxins = 213644,
        hand_of_hindrance = 183218,
        shield_of_vengeance = 184662,
        rebuke = 96231,
        divine_storm = 53385,
        blessing_of_protection = 1022,
        greater_blessing_of_kings = 203538,
        greater_blessing_of_wisdom = 203539,
        retribution = 0,
        avenging_wrath = 31884,

        execution_sentence = 213757,
        consecration = 205228,
        the_fires_of_justice = 209785,
        zeal = 217020,
        repentance = 20066,
        blinding_light = 115750,
        divine_hammer = 198034,
        justicars_vengeance = 215661,
        eye_for_an_eye = 205191,
        word_of_glory = 210191,
        judgment_of_light = 196941,
        divine_purpose = 223819,
        crusade = 231895,
        holy_wrath = 210220,

        wake_of_ashes = 205273,
        unbreakable_will = 0,
        ashes_to_ashes = 0,
        righteous_verdict = 0,
        blessing_of_the_ashbringer = 0,
        concordance_of_the_legionfall = 242583,

        liadrins_fury_unleashed = 137048,
        liadrins_fury_unleashed_buff = 208410,
        aegisjalmur_the_armguards_of_awe = 140846,
        aegisjalmur_the_armguards_of_awe_debuff = 225056,
        whisper_of_the_nathrezim = 137020,
        whisper_of_the_nathrezim_buff = 207635,
        justice_gaze = 137065,
        ashes_todust = 144358,
        scarlet_inquisitors_expurgation = 151813,
        scarlet_inquisitors_expurgation_buff = 248289,

        -- sacred_judgment = 246973, -- t20 Judgment also increased damage of blade of justice
        sacred_judgment = 253806, -- t21 judgment causes next hp spender's cost to be -1 (WHY THE HELL DID THEY USE THE SAME NAME)
    },
}
insertGeneral = {
    blood_fury = 33697,

    crusader_strike = 35395,
    judgment = 20271,
    hand_of_reckoning = 62124,
    redemption = 7328,
    divine_shield = 642,
    divine_steed = 190784,
    blessing_of_freedom = 1044,
    contemplation = 121183,
    lay_on_hands = 633,
    forbearance = 0,

    chain_of_thrayn = 137086,
    soul_of_the_highlord = 151644,
}
for i = 1, 3 do
    for k,v in pairs(insertGeneral) do
        gxPDB[i][k] = v
    end
end

gxPRB = {
    -- Discipline
    {
        shadow_word_pain = 589,
        flash_heal = 2061,
        power_word_shield = 17,
        penance = 47540,
        mind_vision = 2096,
        psychic_scream = 8122,
        atonement = 0,
        purify = 527,
        plea = 200829,
        shadow_mend = 186263,
        levitate = 1706,
        smite = 0,
        focused_will = 45242,
        shadowfiend = 34433,
        pain_suppression = 33206,
        rapture = 47536,
        power_word_radiance = 194509,
        leap_of_faith = 73325,
        mass_resurrection = 212036,
        power_word_barrier = 62618,

        twist_of_fate = 123254,
        schism = 214621,
        angelic_feather = 121536,
        angelic_feather_buff = 121557,
        body_and_soul = 0,
        shining_force = 204263,
        power_word_solace = 129250,
        mindbender = 123040,
        clarity_of_will = 152118,
        shadow_covenant = 204065,
        purge_the_wicked = 204197,
        purge_the_wicked_debuff = 204213,
        divine_star = 110744,
        halo = 120517,
        power_infusion = 10060,
        evangelism = 246287,

        lights_wrath = 207946,
        vestments_of_discipline = 0,
        speed_of_the_pious = 0,
        borrowed_time = 0,
        share_in_the_light = 0,
        power_of_the_dark_side = 0,
        barrier_for_the_devoted = 0,
        sins_of_the_many = 0,
        aegis_of_wrath = 0,

        cord_of_maiev_priestess_of_the_moon = 133800,
        estel_dejahnas_inspiration = 132861,
        dejahnas_inspiration = 214637,
        nero_band_of_promises = 137276,
        skjoldr_sanctuary_of_ivagont = 132436,
        xalan_the_feareds_clench = 132461,
        kam_xiraff = 144244,
        kam_xiraff_buff = 233997,
        inner_hallation = 151786,

        penitent = 246519,
        radiant_focus = 252848,
    },

    -- Holy
    {
        flash_heal = 2061,
        holy_fire = 14914,
        holy_word_serenity = 2050,
        renew = 139,
        holy_word_chastise = 88625,
        purify = 527,
        heal = 2060,
        holy_nova = 132157,
        prayer_of_healing = 596,
        levitate = 1706,
        spirit_of_redemption = 0,
        focused_will = 45242,
        holy_word_sanctify = 34861,
        guardian_spirit = 47788,
        prayer_of_mending = 33076,
        desperate_prayer = 19236,
        leap_of_faith = 73325,
        mass_resurrection = 212036,
        divine_hymn = 64843,
        echo_of_light = 0,

        angelic_feather = 121536,
        angelic_feather_buff = 121557,
        body_and_mind = 214121,
        perseverance = 0,
        shining_force = 204263,
        censure = 0,
        symbol_of_hope = 64901,
        surge_of_light = 0,
        binding_heal = 32546,
        divinity = 197030,
        divine_star = 110744,
        halo = 120517,
        apotheosis = 200183,
        circle_of_healing = 204883,

        invoke_the_naaru = 0,
        guardians_of_light = 0,
        power_of_the_naaru = 0,
        focus_in_the_light = 0,
        light_of_tuure = 208065,
        blessing_of_tuure = 196644,

        xanshi_shroud_of_archbishop_benedictus = 137109,
        archbishop_benedictus_restitution = 211319,
        muzes_unwavering_will = 132450,
        phyrixs_embrace = 132449,
        entrancing_trousers_of_anjuna = 132447,
        almaiesh_the_cord_of_hope = 132445,
        almaiesh_the_cord_of_hope_serenity = 211440,
        almaiesh_the_cord_of_hope_sanctify = 211442,
        almaiesh_the_cord_of_hope_chastise = 211443,
        rammals_ulterior_motive = 144247,
        rammals_ulterior_motive_buff = 234711,
        the_alabaster_lady = 151787,

        answered_prayers = 253437,
        everlasting_hope = 253443,
    },

    -- Shadow
    {
        shadow_word_pain = 589,
        flash_heal = 2061,
        power_word_shield = 17,
        mind_blast = 8092,
        mind_flay = 15407,
        shadowform = 232698,
        mind_vision = 2096,
        psychic_scream = 8122,
        void_bolt = 205448,
        void_eruption = 228260,
        voidform = 194249,
        purify_disease = 213634,
        vampiric_touch = 34914,
        shadow_mend = 186263,
        shadow_word_death = 32379,
        levitate = 1706,
        shadowy_apparitions = 0,
        shadowfiend = 34433,
        dispersion = 47585,
        silence = 15487,
        vampiric_embrace = 15286,

        twist_of_fate = 123254,
        shadow_word_void = 205351,
        body_and_soul = 0,
        mind_bomb = 205369,
        void_ray = 205372,
        shadowy_insight = 124430,
        power_infusion = 10060,
        mindbender = 200174,
        shadow_crash = 205385,
        surrender_to_madness = 193223,

        void_torrent = 205065,
        mental_fortitude = 0,
        thrive_in_the_shadows = 0,
        call_to_the_void = 0,
        sphere_of_insanity = 0,
        mass_hysteria = 0,
        mind_quickening = 240673,
        lash_of_insanity = 0,

        anunds_seared_shackles = 132409,
        anunds_last_breath = 215210,
        zenkaram_iridis_anadem = 133971,
        the_twins_painful_touch = 133973,
        mangazas_madness = 132864,
        mother_shahrazs_seduction = 132437, -- needs to be tested how it affects drain stacks monitor
        zeks_exterminatus = 144438,
        zeks_exterminatus_buff = 236546,
        heart_of_the_void = 151814,

        empty_mind = 247226,
    },
}
insertGeneral = {
    blood_fury = 33072,

    shoot = 5019,
    smite = 585,
    resurrection = 2006,
    shackle_undead = 9484,
    mind_control = 605,
    fade = 586,
    dispel_magic = 825,
    mass_dispel = 32375,

    concordance_of_the_legionfall = 242586,

    soul_of_the_high_priest = 151646,
}
for i = 1, 3 do
    for k,v in pairs(insertGeneral) do
        gxPRB[i][k] = v
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
        surge_of_toxins = 192425,
        blood_of_the_assassinated = 192925,
        master_assassin_trait = 330,

        duskwalkers_footpads = 137030,
        zoldyck_family_training_shackles = 137098,
        the_empty_crown = 151815,
        the_dreadlords_deceit = 137021,
        the_dreadlords_deceit_buff = 208693,

        --[[Item - Rogue T19 Assassination 2P Bonus
                        Requires Rogue
                        Mutilate also causes the target to Bleed for 20% additional damage over 8 sec.]]
        virulent_poisons = 252277,
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

        swordplay = 211669,
        --[[Item - Rogue T20 Outlaw 2P Bonus
                        Requires Rogue
                        Free Pistol Shots increase your critical strike chance by 5% for 8 sec.]]
        --[[Item - Rogue T20 Outlaw 4P Bonus
                        Requires Rogue
                        Adrenaline Rush persists for 8 sec longer when it ends, at half power.]]
        --[[Item - Rogue T21 Outlaw 2P Bonus
                        Requires Rogue
                        Extra attacks from Saber Slash increase the damage of your next Run Through by 5%, stacking up to 4 times.]]
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
        the_dreadlords_deceit_buff = 228224,
        shadow_satyrs_walk = 137032,
        denial_of_the_half_giants = 137100,
        the_first_of_the_dead = 151818,
        the_first_of_the_dead_buff = 248210,

        shadow_gestures = 257945,
    },
}
insertGeneral = {
    blood_fury = 20572,

    crimson_vial = 185311,
    kick = 1766,
    pick_lock = 1804,
    sprint = 2983,
    feint = 1966,
    shroud_of_concealmeant = 114018,
    tricks_of_the_trade = 57934,
    cloak_of_shadows = 31224,

    concordance_of_the_legionfall = 242584,

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
    for k,v in pairs(insertGeneral) do
        gxRB[i][k] = v
    end
end

gxSB = {
    -- Elemental
    {
        lightning_bolt = 188196,
        flame_shock = 188389,
        healing_surge = 8004,  
        earth_shock = 8042,
        lava_burst = 51505,
        wind_shear = 57994,
        cleanse_spirit = 51886,
        thunderstorm = 51490,
        chain_lightning = 188443,
        earth_elemental = 198103,
        frost_shock = 196840,
        lava_surge = 0,
        earthquake = 61882,
        fire_elemental = 198067,
        elemental_focus = 16246,

        totem_mastery = 210643,
        gust_of_wind = 192063,
        ancestral_guidance = 108281,
        wind_rush_totem = 192077,
        lightning_surge_totem = 192058,
        earthgrab_totem = 51485,
        voodoo_totem = 196932,
        elemental_mastery = 16166,
        elemental_blast = 117014,
        liquid_magma_totem = 192222,
        storm_elemental = 192249,
        ascendance = 114050,
        lightning_rod = 0,
        icefury = 210714,

        stormkeeper = 205495,
        static_overload = 191634,
        power_of_the_maelstrom = 191877,
        volcanic_inferno = 0,
        fury_of_the_storms = 0,
        seismic_storm = 0,
        concordance_of_the_legionfall = 242586,

        eye_of_the_twisting_nether = 137050,
        eye_of_the_twisting_nether_buff = 0,
        smoldering_heart = 151819,
        the_deceivers_blood_pact = 137035,
        echoes_of_the_great_sundering = 137074,
        echoes_of_the_great_sundering_buff = 208723,
        pristine_protoscale_girdle = 137083,
        pristine_protoscale_girdle_debuff = 224852,
        alakirs_acrimony = 137102,

        focused_elements = 246594,
        earthen_strength = 252141,
    },

    -- Enhancement
    {
        lightning_bolt = 187837,
        healing_surge = 188070,
        lava_lash = 60103,
        rockbiter = 193786,
        flametongue = 193796,
        flametongue_buff = 194084,
        wind_shear = 57994,
        stormstrike = 17364,
        cleanse_spirit = 51886,
        crash_lightning = 187874,
        feral_spirit = 51533,
        frostbrand = 196834,
        stormbringer = 201846,
        stormlash = 0,
        spirit_walk = 58875,

        windsong = 201898,
        hot_hand = 215785,
        landslide = 202004,
        rainfall = 215864,
        feral_lunge = 196884,
        wind_rush_totem = 192077,
        lightning_surge_totem = 192058,
        earthgrab_totem = 51485,
        voodoo_totem = 196932,
        lightning_shield = 192106,
        hailstorm = 0,
        fury_of_air = 197211,
        sundering = 197214,
        ascendance = 114051,
        earthen_spike = 188089,

        doom_winds = 204945,
        gathering_storms = 0,
        wind_strikes = 0,
        alpha_wolf = 0,
        elemental_healing = 0,
        raging_storms = 0,
        spirit_of_the_maelstrom = 0,
        doom_wolves = 0,
        unleash_doom = 199055,
        lashing_flames = 240842,
        concordance_of_the_legionfall = 242584,

        eye_of_the_twisting_nether = 137050,
        eye_of_the_twisting_nether_buff = 0,
        smoldering_heart = 151819,
        storm_tempests = 137103,
        storm_tempests_debuff = 214265,
        akainus_absolute_justice = 137084,
        emalons_charged_core = 137616,
        emalons_charged_core_buff = 208742,
        spiritual_journey = 138117,
        spiritual_journey_buff = 214170,

        lightning_crash = 242284,
        crashing_lightning = 242286,
        force_of_the_mountain = 254308,
        exposed_elements = 252151,
    },

    -- Restoration
    {
        lightning_bolt = 403,
        flame_shock = 188838,
        healing_surge = 8004,
        riptide = 61295,
        lava_burst = 51505,
        healing_stream_totem = 5394,
        wind_shear = 57994,
        chain_heal = 1064,
        purify_spirit = 77130,
        healing_wave = 77472,
        chain_lightning = 421,
        tidal_waves = 0,
        spiritwalkers_grace = 79206,
        healing_rain = 73920,
        spirit_link_totem = 98008,
        ancestral_vision = 212048,
        healing_tide_totem = 108280,

        undulation = 0,
        unleash_life = 73685,
        gust_of_wind = 192063,
        wind_rush_totem = 192077,
        lightning_surge_totem = 192058,
        earthgrab_totem = 51485,
        voodoo_totem = 196932,
        ancestral_guidance = 108281,
        ancestral_protection_totem = 207399,
        earthen_shield_totem = 198838,
        ancestral_vigor = 207400,
        cloudburst_totem = 157153,
        echo_of_the_elements = 108283,
        ascendance = 114052,
        wellspring = 197995,

        gift_of_the_queen = 207778,
        ghost_in_the_mist = 0,
        caress_of_the_tidemother = 0,
        queen_ascendant = 0,
        servant_of_the_queen = 207654,
        cumulative_upkeep = 0,
        concordance_of_the_legionfall = 242586,

        focuser_of_jonat_the_elder = 137051,
        jonats_focus = 210607,
        intact_nazjatar_molting = 137085,
        elemental_rebalancers = 137036,
        praetorians_tidecallers = 137058,
        nobundos_redemption = 137104,
        nobundos_redemption_buff = 208764,
        fire_in_the_deep = 151785,

        tidal_force = 246729,
        spirit_rain = 246771,
    },
}
insertGeneral = {
    blood_fury = 33697,

    earthbind_totem = 2484,
    farsight = 6196,
    ancestral_spirit = 2008,
    ghost_wolf = 2645,
    reincarnation = 0,
    waterwalking = 546,
    hex_spider = 211004,
    hex_cockroach = 211015,
    hex_compy = 210873,
    hex_snake = 211010,
    hex = 51514, -- frog
    astral_recall = 556,
    bloodlust = 2825,
    heroism = 32182,
    astral_shift = 108271,
    purge = 370,

    uncertain_reminder = 143732,
    soul_of_the_farseer = 151647,
}
for i = 1, 3 do
    for k,v in pairs(insertGeneral) do
        gxSB[i][k] = v
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

        demonic_speed = 242292,
        tormented_agony = 252938,
    },

    -- Demonology
    {
        shadow_bolt = 686,
        life_tap = 1454,
        hand_of_guldan = 105174,
        demonic_empowerment = 193396,
        drain_life = 234153,
        call_dreadstalkers = 104316,
        doom = 603,
        summon_felguard = 30146,
        demonwrath = 193440,

        shadowflame = 205181,
        demonic_calling = 205146,
        implosion = 196277,
        demonic_circle = 48018,
        mortal_coil = 6789,
        shadowfury = 30283,
        soul_harvest = 196098,
        burning_rush = 111400,
        dark_pact = 108416,
        summon_doomguard_supremacy = 157757,
        summon_infernal_supremacy = 157898,
        grimoire_imp = 111859,
        grimoire_voidwalker = 111895,
        grimoire_succubus = 111896,
        grimoire_felhunter = 111897,
        demonic_synergy = 171982,
        summon_darkglare = 205180,
        demonbolt = 157695,

        thalkiels_consumption = 211714,
        stolen_power = 0,
        the_expendables = 0,
        jaws_of_shadow = 0,

        kazzaks_final_curse = 132374,
        wilfreds_sigil_of_superior_summoning = 132369,
        recurrent_ritual = 132393,
        sindorei_spite = 132379,
        sindorei_spite_buff = 208871,
        wakeners_loyalty = 144385,
        wakeners_loyalty_buff = 236200,

        dreaded_haste = 246962,
    },

    -- Destruction
    {
        shadow_bolt = 686,
        life_tap = 1454,
        conflagrate = 17962,
        immolate = 348,
        immolate_debuff = 0,
        chaos_bolt = 116858,
        drain_life = 234153,
        incinerate = 29722,
        rain_of_fire = 5740,
        havoc = 80240,
        
        backdraft = 0,
        roaring_blaze = 0,
        shadowburn = 17877,
        eradication = 196414,
        empowered_life_tap = 235156,
        demonic_circle = 48018,
        mortal_coil = 6789,
        shadowfury = 30283,
        cataclysm = 152108,
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
        channel_demonfire = 196447,

        dimensional_rift = 196586,
        conflagration_of_chaos = 196546,
        devourer_of_life = 0,
        eternal_struggle = 0,
        lord_of_flames = 0,
        planeswalker = 196674,

        alythess_pyrogenics = 132460,
        alythess_pyrogenics_debuff = 205675,
        odr_shadow_of_the_ymirjar = 132375,
        feretory_of_souls = 132456,
        magistrike_restraints = 132407,
        lessons_of_space_time = 144369,
        lessons_of_space_time_buff = 236176,

        embrace_chaos = 212019,
        chaotic_flames = 253092,
    },
}
insertGeneral = {
    blood_fury = 33072,
    
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

    concordance_of_the_legionfall = 242586,

    pillars_of_the_dark_portal = 132357,
    soul_of_the_netherlord = 151649,
    the_master_harvester = 151821,
}
for i = 1, 3 do
    for k,v in pairs(insertGeneral) do
        gxWLB[i][k] = v
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
        concordance_of_the_legionfall = 242583,

        weight_of_the_earth = 137077,
        archavons_heavy_hand = 137060,
        the_great_storms_eye = 151823,
        tornados_eye = 248142, -- or 248145
        ayalas_stone_heart = 137052,
        stone_heart = 225947,
        najentuss_vertebrae = 137087,

        war_veteran = 253382,
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
        concordance_of_the_legionfall = 242583,
    
        ayalas_stone_heart = 137052,
        stone_heart = 225947,
        najentuss_vertebrae = 137087,
        ceann_ar_charger = 137088,
        kazzalax_fujiedas_fury = 137053,
        fujiedas_fury = 207776,
        valarjar_berserkers = 151824,

        raging_thirst = 242300,
        bloody_rage = 242952, -- 242953?
        outrage = 253385,
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
        concordance_of_the_legionfall = 243096,

        thundergods_vigor = 137089,
        the_walls_fell = 137054,
        kakushans_stormscale_gauntlets = 137108,
        kakushans_stormscale_gauntlets_buff = 207844,
        destiny_driver = 137018,
        destiny_driver_buff = 215157,
        ararats_bloodmirror = 151822,

        wall_of_iron = 253428,
    },
}
insertGeneral = {
    blood_fury = 20572,

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
    for k,v in pairs(insertGeneral) do
        gxWRB[i][k] = v
    end
end

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
    draught_of_souls = 140808,
    specter_of_betrayal = 151190,
    umbral_moonglaives = 147012,
    void_stalkers_contract = 151307,
    vial_of_ceaseless_toxins = 147011,
    tome_of_unraveling_sanity = 147019,
    ring_of_collapsing_futures = 142173,
    temptation = 234143,
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
