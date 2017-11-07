gx.libraryVer = 6

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
    if gxCO and type(gxCO) == "thread" and coroutine.status(gxCO) == "suspended" then return (select(2, coroutine.resume(gxCO)) == "continue" and false or true) elseif type(coTable[1]) ~= "nil" then gxCO = coroutine.create(coTable[1]); table.remove(coTable, 1) return true end
    return false
end
function gx.emptyCO()
    for i = 1, #coTable do
        table.remove(coTable)
    end
    if type(gxCO) == "thread" and coroutine.status(gxCO) == "suspended" then gxCO = nil end
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