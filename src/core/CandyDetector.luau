--!strict
-- CandyDetector.luau: Validated MM2 Candy Detection & Boundary Guard
-- Validates targets against map boundaries, active TouchInterest, and collection state

local CandyDetector = {
    Blacklist = {} :: { [Instance]: number },
    CoinTypeFilter = "Candy",
    FailCounts = {} :: { [Instance]: number },
}

-- Check if an instance is a valid, currently collectible candy
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

-- Resolve the BasePart target of a candy
function CandyDetector.GetTargetPart(candy: Instance): BasePart?
    if candy:IsA("BasePart") then
        return candy
    elseif candy:IsA("Model") then
        return (candy.PrimaryPart or candy:FindFirstChildWhichIsA("BasePart"))
    end
    return nil
end

-- Find all currently valid candies inside map boundaries
function CandyDetector.GetCandies(
    coinContainer: Instance?,
    filterOrBoundaryFn: (string | ((Vector3) -> boolean))?,
    boundaryFn: ((Vector3) -> boolean)?
): { BasePart }
    local result = {}
    if not coinContainer then return result end

    local filter: string? = nil
    local isPositionValidFn: ((Vector3) -> boolean)? = nil

    if typeof(filterOrBoundaryFn) == "string" then
        filter = filterOrBoundaryFn
        isPositionValidFn = boundaryFn
    elseif typeof(filterOrBoundaryFn) == "function" then
        isPositionValidFn = filterOrBoundaryFn
    end

    local activeFilter = filter or CandyDetector.CoinTypeFilter

    for _, item in ipairs(coinContainer:GetChildren()) do
        if CandyDetector.IsValidCandy(item, activeFilter) then
            local part = CandyDetector.GetTargetPart(item)
            if part then
                -- Spatial boundary validation: Reject any coin outside the map
                local isValidPos = (not isPositionValidFn) or isPositionValidFn(part.Position)
                if isValidPos then
                    table.insert(result, part)
                end
            end
        end
    end

    return result
end

-- Find the closest valid candy using squared distance
function CandyDetector.GetClosestCandy(
    coinContainer: Instance?,
    playerPos: Vector3,
    filterOrBoundaryFn: (string | ((Vector3) -> boolean))?,
    boundaryFn: ((Vector3) -> boolean)?
): (BasePart?, number)
    local candidates = CandyDetector.GetCandies(coinContainer, filterOrBoundaryFn, boundaryFn)
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

-- Register a failed pickup attempt; blacklists if failed repeatedly
function CandyDetector.RecordFailedPickup(coin: Instance, maxRetries: number?): boolean
    local limit = maxRetries or 2
    local count = (CandyDetector.FailCounts[coin] or 0) + 1
    CandyDetector.FailCounts[coin] = count

    if count >= limit then
        CandyDetector.Blacklist[coin] = os.clock() + 15 -- Blacklist for 15s
        CandyDetector.FailCounts[coin] = nil
        return true -- Triggered permanent blacklist for this cycle
    end
    return false
end

function CandyDetector.BlacklistCoin(coin: Instance, durationSeconds: number?)
    local duration = durationSeconds or 15
    CandyDetector.Blacklist[coin] = os.clock() + duration
end

function CandyDetector.PruneBlacklist()
    local now = os.clock()
    for coin, expiry in pairs(CandyDetector.Blacklist) do
        if now >= expiry or not coin.Parent then
            CandyDetector.Blacklist[coin] = nil
            CandyDetector.FailCounts[coin] = nil
        end
    end
end

function CandyDetector.ClearBlacklist()
    table.clear(CandyDetector.Blacklist)
    table.clear(CandyDetector.FailCounts)
end

return CandyDetector
