gx.libraryVer = 9

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
    if gxCO and type(gxCO) == "thread" and coroutine.status(gxCO) == "suspended" then return (select(2, coroutine.resume(gxCO)) ~= "continue") elseif type(coTable[1]) ~= "nil" then gxCO = coroutine.create(coTable[1]); table.remove(coTable, 1) return true end
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

function gx.printd(...)
    if string.lower(Engine_GetUsername()) == "g1zstar" or gxrdebug then print("GXR: "..(...)) end
end

function gx.notEnoughEnergyFor(spell)
    return select(2, IsUsableSpell(spell))
end

function gx.poolEnergyFor(spell, cast, unit)
    gx.queueUpCO(function()
            while (not castable(spell)) do
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

gxMKB = {
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

    -- Windwalker
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
}

gxRB = {
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

    -- Assassination
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
    leeching_poison = 108211,
    cheating_death = 45182,
    cheated_death = 45181,
    toxic_blade = 245388,
    alacrity = 193538,
    exsanguinate = 200806,
    marked_for_death = 137619,
    death_from_above = 152150,

    gladiators_medallion = 208683,
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

    -- Outlaw
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

    gladiators_medallion = 208683,
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

    -- Subtlety
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
    cheating_death = 45182,
    cheated_death = 45181,
    alacrity = 193538,
    marked_for_death = 137619,
    death_from_above = 152150,

    gladiators_medallion = 208683,
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
}

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

local idsList = {"gxMKB", "gxRB"}
for _,v in pairs(idsList) do
    for r,c in pairs(gxGB) do
        _G[v][r] = c
    end
end