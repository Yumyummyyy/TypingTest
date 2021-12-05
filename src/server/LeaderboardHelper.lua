local leaderboardMod = {}

local dsh = require(script.DatastoreHelper)
local maxAmt = 15

local validationTable = {
    WPM = 0,
    LPM = 0,
    PlayerId = 0
}

--[[
server created -> cache leaderboard data ✔️
every 3 min -> update cached leaderboard ✔️
player joins -> get data, cache friends leaderboard data ✔️
every 3 min -> update cached friends leaderboard ✔️
player finishes test -> update internal data  ✔️
player accesses leaderboard data -> get cached leaderboard ✔️
player accesses friends leaderboard -> get cached friends leaderboard ✔️
player leaves -> remove friends leaderboard from list, save data, remove their stats in game ✔️
]]--

local leaderboard = {}
function leaderboardMod.CacheLeaderboard()
    if #data ~= maxAmt then warn("pls provide valid data"); return end
    for i = 1,maxAmt do
        leaderboard[i] = dsh.RequestDatastore("Leaderboard", i)
    end
end

function leaderboardMod.GetLeaderboard()
    return leaderboard
end

function leaderboardMod.UpdateCache(index, data)
    leaderboard[index] = data
end

function leaderboardMod.IsFirstBigger(leaderboard, cache)
    local leaderboardAmt = {}
    local cacheAmt = {}
    for i,v in pairs(leaderboard) do
        if leaderboardAmt[i] ~= nil then
            leaderboardAmt[i] = leaderboardAmt[i] + v
        else
            leaderboardAmt[i] = v
        end
    end
    for i,v in pairs(cache) do
        if cacheAmt[i] ~= nil then
            cacheAmt[i] = cacheAmt[i] + v
        else
            cacheAmt[i] = v
        end
    end
    if leaderboardAmt >= cacheAmt then
        return true
    end
    return false
end

function leaderboardMod.updateLeaderboardFromCache()
    for i = 1, maxAmt do
        local leaderboardStat = dsh.SafeDatastoreRequest("Leaderboard", i)
        local cacheStat = Leaderboard[i]
        if leaderboardStat == nil then
            break
        end
        if leaderboardMod.IsFirstBigger(cacheStat, leaderboardStat) then
            dsh.UpdateDatastoreEntry("Leaderboard", i, leaderboardStat)
        end
    end
end

function leaderboardMod.Validate(obj)
    local success = false
    for i,v in pairs(validationTable) do
        if type(obj[i]) == type(v) then
            success = true
        else
            success = false
        end
    end
    return success
end

function leaderboardMod.MoveLeaderboardDown(index)
    local prevLeaderboardStat
    for i = index, maxAmt do
        local leaderboardStat = leaderboard[i]
        if leaderboardStat == nil then
            break
        end
        if prevLeaderboardStat ~= nil then
            leaderboardMod.UpdateCache(i, prevLeaderboardStat)
        else
            leaderboardMod.UpdateCache(i, nil)
        end
        prevLeaderboardStat = leaderboardStat
    end
end

function leaderboardMod.AttemptAdd(player, vals)
    if not leaderboardMod.Validate(vals) then return nil end
    local wpm = vals.WPM
    local lpm = vals.LPM
    local success = false
    for i = 1, maxAmt do
        local leaderboardStat = leaderboard[i]
        local willUpdate = false
        if wpm > leaderboardStat.WPM then
            leaderboardStat.WPM = wpm
            willUpdate = true
        end
        if lpm > leaderboardStat.LPM then
            leaderboardStat.LPM = lpm
            willUpdate = true
        end
        if willUpdate then
            leaderboardStat.PlayerId = player
            leaderboardMod.MoveLeaderboardDown(i) -- make room for new entry
            leaderboardMod.UpdateCache(i, leaderboardStat)
            success = true
            break
        end
    end
    return success
end

local friendsLeaderboardList = {}

local function iterPageItems(pages) -- DeFiNiTeLy not copied from roblox docs :)
	return coroutine.wrap(function()
		local pagenum = 1
		while true do
			for _, item in ipairs(pages:GetCurrentPage()) do
				coroutine.yield(item, pagenum)
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
			pagenum = pagenum + 1
		end
	end)
end

function leaderboardMod.CacheAndUpdateFriends(player)
    local friendsPages = game.Players:GetFriendsAsync(player.UserId)
    local friendList = {}
    for item, pageNo in iterPageItems(friendsPages) do
        local friendUserId = item.Id
        local friendName = item.Username
        local friendData = dsh.RequestDatastore("Statistics", friendUserId)
        friendData.Name = friendName
        if friendData then
            friendList[friendUserId] = friendData
        end
    end
    local newList = {}
    for i,v in ipairs(friendList) do
        if #newList ~= 0 then
            for a = 1, #newList do -- compares values
                local b = newList[a]
                local plsAdd = false
                if v.WPM > b.WPM then
                    plsAdd = true
                end
                if v.LPM > b.LPM then
                    plsAdd = true
                end
                if plsAdd then
                    local cached
                    for index = a, #newList do -- shifts everything from a up
                        if cached == nil then
                            cached = newList[index]
                        else
                            local anotherCache = cached
                            cached = newList[index]
                            newList[index] = anotherCache
                        end
                    end
                    newList[a] = v
                end
            end
        else
            newList[i] = v
        end
    end
    friendsLeaderboardList[player.UserId] = newList
end

function leaderboardMod.RemoveFriends(player)
    friendsLeaderboardList[player.UserId] = nil
end

function leaderboardMod.GetFriends(player)
    return friendsLeaderboardList[player.UserId]
end


return leaderboardMod