--!strict
-- CandyDetector.luau: High-Performance MM2 Candy & Coin Detection
-- Finds collectible seasonal candies, sorts by distance, and maintains blacklists

local CandyDetector = {
    Blacklist = {} :: { [Instance]: number }, -- [coinInstance] = expiryTimestamp
    CoinTypeFilter = "Candy",                  -- Target event currency ("Candy", "Coin", or "All")
}

-- Check if an instance is a valid, active collectible candy
function CandyDetector.IsValidCandy(obj: Instance, coinTypeFilter: string?): boolean
    if not obj or not obj.Parent then return false end
    if not (obj:IsA("BasePart") or obj:IsA("Model")) then return false end

    -- Check blacklist expiry
    local expiry = CandyDetector.Blacklist[obj]
    if expiry and os.clock() < expiry then
        return false
    end

    -- 1. Check for TouchInterest / TouchTransmitter
    local touchInterest = obj:FindFirstChildWhichIsA("TouchTransmitter") or obj:FindFirstChild("TouchInterest")
    if not touchInterest then
        -- In some versions TouchInterest is inside a child part
        local innerTouch = obj:FindFirstChild("CoinVisual") and obj.CoinVisual:FindFirstChildWhichIsA("TouchTransmitter")
        if not innerTouch then
            return false
        end
    end

    -- 2. Verify seasonal CoinID attribute if specified
    local filter = coinTypeFilter or CandyDetector.CoinTypeFilter
    if filter and filter ~= "All" then
        local coinId = obj:GetAttribute("CoinID")
        if coinId and tostring(coinId) ~= filter then
            return false
        end
    end

    -- 3. Check if marked collected by client visual attribute
    local coinVisual = obj:FindFirstChild("CoinVisual")
    if coinVisual and coinVisual:GetAttribute("Collected") == true then
        return false
    end

    return true
end

-- Resolve the BasePart position of a candy target
function CandyDetector.GetTargetPart(candy: Instance): BasePart?
    if candy:IsA("BasePart") then
        return candy
    elseif candy:IsA("Model") then
        return (candy.PrimaryPart or candy:FindFirstChildWhichIsA("BasePart"))
    end
    return nil
end

-- Find all currently valid candies in the active container
function CandyDetector.GetCandies(coinContainer: Instance?, coinTypeFilter: string?): { BasePart }
    local result = {}
    if not coinContainer then return result end

    local filter = coinTypeFilter or CandyDetector.CoinTypeFilter
    for _, item in ipairs(coinContainer:GetChildren()) do
        if CandyDetector.IsValidCandy(item, filter) then
            local part = CandyDetector.GetTargetPart(item)
            if part then
                table.insert(result, part)
            end
        end
    end

    return result
end

-- Find the closest valid candy using squared distance (O(1) sqrt-free)
function CandyDetector.GetClosestCandy(coinContainer: Instance?, playerPos: Vector3, coinTypeFilter: string?): (BasePart?, number)
    local candidates = CandyDetector.GetCandies(coinContainer, coinTypeFilter)
    if #candidates == 0 then
        return nil, math.huge
    end

    local bestPart = nil :: BasePart?
    local bestDistSq = math.huge

    for _, part in ipairs(candidates) do
        local delta = part.Position - playerPos
        local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
        if distSq < bestDistSq then
            bestDistSq = distSq
            bestPart = part
        end
    end

    local realDist = (bestPart and math.sqrt(bestDistSq)) or math.huge
    return bestPart, realDist
end

-- Temporarily blacklist a coin that caused a timeout or stall
function CandyDetector.BlacklistCoin(coin: Instance, durationSeconds: number?)
    local duration = durationSeconds or 12
    CandyDetector.Blacklist[coin] = os.clock() + duration
end

-- Clear expired blacklists to free memory
function CandyDetector.PruneBlacklist()
    local now = os.clock()
    for coin, expiry in pairs(CandyDetector.Blacklist) do
        if now >= expiry or not coin.Parent then
            CandyDetector.Blacklist[coin] = nil
        end
    end
end

function CandyDetector.ClearBlacklist()
    table.clear(CandyDetector.Blacklist)
end

return CandyDetector
