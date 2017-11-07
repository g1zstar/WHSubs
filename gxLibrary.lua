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
local function queueUpCO(func)
    if func then table.insert(coTable, func) return end
    if gxCO and type(gxCO) == "thread" and coroutine.status(gxCO) == "suspended" then coroutine.resume(gxCO) return true elseif type(coTable[1]) ~= "nil" then gxCO = coroutine.create(coTable[1]); table.remove(coTable, 1) return true end
    return false
end
local function emptyCO()
    for i = 1, #coTable do
        table.remove(coTable)
    end
    if type(gxCO) == "thread" and coroutine.status(gxCO) == "suspended" then gxCO = nil end
end

local function printd(...)
    if string.lower(Engine_GetUsername()) == "g1zstar" or gxrdebug then print(...) end
end

local function notEnoughEnergyFor(spell)
    return select(2, IsUsableSpell(spell))
end

local function poolEnergyFor(spell, cast, unit)
    queueUpCO(function()
            while (not castable(spell)) do
                coroutine.yield()
                printd("Pooling for "..GetSpellInfo(spell))
            end
            if cast then
                while (castable(spell, unit)) do
                    cast(spell, unit)
                    coroutine.yield()
                    printd("Casting "..GetSpellInfo(spell).." after Pooling")
                end
            end
        end)
end

local queueFrame = CreateFrame("Frame")
queueFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
queueFrame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
local queueDone = true
local function queueUpFailedCast(self, event, unitID, spell, rank, lineID, spellID)
    if UnitIsUnit(unitID, "player") and queueDone then
        if config(rotationKey, "queue"..spellID) and player.spell(spellID).cooldown <= 2 then
            queueDone = false
            queueUpCO(function()
                    while (not castable(spellID, target) and player.spell(spellID).cooldown <= 2 and config(rotationKey, "queue"..spellID)) do
                        print("GX Queue System: Casting "..spell)
                        coroutine.yield()
                    end
                    cast(spellID, target)
                    queueDone = true
                    printd("DONE QUEUE")
                end)
            return
        end
    end
end
queueFrame:SetScript("OnEvent", queueUpFailedCast)

local function cdCheck()
    return config("main", "cdmode") == "always" or config("main", "cdmode") == "boss" and target.isboss
end

local function aoe()
    return config("main", "aoe")
end

local function talent(r, c, b)
    if b then
        return player.talent(r, c)
    else
        return player.talent(r, c) and 1 or 0
    end
end

local function checkSub(...)
    print(...)
    if licenseChecked then return end
    licenseChecked = true
    local string = "sub_"..string.lower(Engine_GetUsername())
    local class = select(2, UnitClass("player"))
    _G[string] = nil
    _G["sub_"..class] = nil
    pcall(loadstring(...))
    local weekday, month, day, year = CalendarGetDate()
    local date = year..string.format("%02d%02d", month, day)
    date = tonumber(date)
    local daysRemaining = 0
    -- printd(_G[string])
    if _G[string] then
        if _G[string][class] and _G[string][class] >= date then daysRemaining = math.max(daysRemaining, _G[string][class] - date); licenseValid = true end
        if _G[string]["ALL"] and _G[string]["ALL"] >= date then daysRemaining = math.max(daysRemaining, _G[string]["ALL"] - date); licenseValid = true end
    end
    if not licenseValid and _G["sub_"..class] and _G["sub_"..class] >= date then
        licenseValid = true
        print("GX Development Trial License found. This rotation is not finished yet.")
        if ChatFrame1 then ChatFrame1:AddMessage("GX Development Trial License found. This rotation is not finished yet.") end
    elseif not licenseValid then
        UIErrorsFrame:AddMessage("No GX License found.", .6853, .1084, .2063, 1000000)
        print("No GX License found.")
        if ChatFrame1 then ChatFrame1:AddMessage("No GX License found.") end
    else
        print("GX License found. You have "..daysRemaining.." days left on this license.")
        if ChatFrame1 then ChatFrame1:AddMessage("GX License found. You have "..daysRemaining.." days left on this license.") end
    end
    _G[string] = nil
    _G["sub_"..class] = nil
end

local function failedSubDL()
    print("Failed to check GX license.")
end

SendHTTPRequest("https://raw.githubusercontent.com/g1zstar/WHSubs/master/WHSubs.lua", nil, checkSub, failedSubDL)