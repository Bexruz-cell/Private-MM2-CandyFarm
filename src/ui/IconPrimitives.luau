--[[
    MM2 Delta Android Mobile - Native UI Primitive Icon Engine
    Architect: Mobile UX & High-FPS Engine Architect (MM2 Candy Farm Council)
    Platform: Delta Executor on Android (Roblox Mobile CoreGui)
    Description: 100% Pure Roblox Instance.new primitive icon fallbacks.
                 Renders crisp vector-like icons using Frames, UICorners, UIStrokes,
                 and Rotations with zero external web images, decals, or asset IDs.
    Icons supported:
      - Candy
      - Start
      - Stop
      - Settings
      - Performance
      - Minimize
      - Close
      - Status
      - Movement
      - Statistics
      - Refresh
]]

local IconPrimitives = {}

-- Helper: Create primitive element
local function CreatePrimitive(className: string, properties: { [string]: any }, children: { Instance }?): Instance
    local inst = Instance.new(className)
    for k, v in pairs(properties or {}) do
        inst[k] = v
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = inst
        end
    end
    return inst
end

-- Default Icon Size
local DEFAULT_SIZE = UDim2.fromOffset(20, 20)
local DEFAULT_COLOR = Color3.fromRGB(240, 240, 255)

-- 1. CANDY ICON (Wrapped sweet with center body and flared twist ends)
function IconPrimitives.CreateCandy(size: UDim2?, color: Color3?, accentColor: Color3?): Frame
    local c = color or DEFAULT_COLOR
    local acc = accentColor or Color3.fromRGB(168, 85, 247)
    
    local container = CreatePrimitive("Frame", {
        Name = "Icon_Candy",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Center Sweet Body (Tilted rounded pill)
    local center = CreatePrimitive("Frame", {
        Name = "CandyBody",
        Size = UDim2.new(0.52, 0, 0.52, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        Rotation = 45,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.4, 0) }),
        CreatePrimitive("UIStroke", {
            Color = acc,
            Thickness = 1,
            Transparency = 0.2,
        })
    })
    center.Parent = container

    -- Center decorative stripe
    local stripe = CreatePrimitive("Frame", {
        Name = "Stripe",
        Size = UDim2.new(0.24, 0, 0.8, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = acc,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) }),
    })
    stripe.Parent = center

    -- Left Twist Wing
    local leftWing = CreatePrimitive("Frame", {
        Name = "LeftWing",
        Size = UDim2.new(0.24, 0, 0.38, 0),
        Position = UDim2.new(0.18, 0, 0.18, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = acc,
        Rotation = 15,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.3, 0) })
    })
    leftWing.Parent = container

    -- Right Twist Wing
    local rightWing = CreatePrimitive("Frame", {
        Name = "RightWing",
        Size = UDim2.new(0.24, 0, 0.38, 0),
        Position = UDim2.new(0.82, 0, 0.82, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = acc,
        Rotation = 15,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.3, 0) })
    })
    rightWing.Parent = container

    return container
end

-- 2. START ICON (Play chevron / directional triangle)
function IconPrimitives.CreateStart(size: UDim2?, color: Color3?): Frame
    local c = color or Color3.fromRGB(34, 197, 94)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Start",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Simulated triangle using 3 angled line elements
    local topSlant = CreatePrimitive("Frame", {
        Name = "TopSlant",
        Size = UDim2.new(0.55, 0, 0.12, 0),
        Position = UDim2.new(0.32, 0, 0.33, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = c,
        Rotation = 30,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    topSlant.Parent = container

    local botSlant = CreatePrimitive("Frame", {
        Name = "BotSlant",
        Size = UDim2.new(0.55, 0, 0.12, 0),
        Position = UDim2.new(0.32, 0, 0.67, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = c,
        Rotation = -30,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    botSlant.Parent = container

    local backBar = CreatePrimitive("Frame", {
        Name = "BackBar",
        Size = UDim2.new(0.12, 0, 0.58, 0),
        Position = UDim2.new(0.32, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    backBar.Parent = container

    -- Inner Fill Core
    local fillCore = CreatePrimitive("Frame", {
        Name = "FillCore",
        Size = UDim2.new(0.34, 0, 0.34, 0),
        Position = UDim2.new(0.46, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BackgroundTransparency = 0.2,
        Rotation = 45,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.3, 0) })
    })
    fillCore.Parent = container

    return container
end

-- 3. STOP ICON (Square stop block with rounded micro-corners)
function IconPrimitives.CreateStop(size: UDim2?, color: Color3?): Frame
    local c = color or Color3.fromRGB(239, 68, 68)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Stop",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    local square = CreatePrimitive("Frame", {
        Name = "StopSquare",
        Size = UDim2.new(0.68, 0, 0.68, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.22, 0) }),
        CreatePrimitive("UIStroke", {
            Color = Color3.fromRGB(255, 255, 255),
            Thickness = 1,
            Transparency = 0.5,
        })
    })
    square.Parent = container

    return container
end

-- 4. SETTINGS ICON (Mechanical Cog with central aperture and 4 orthogonal & 4 diagonal teeth)
function IconPrimitives.CreateSettings(size: UDim2?, color: Color3?, holeColor: Color3?): Frame
    local c = color or DEFAULT_COLOR
    local bg = holeColor or Color3.fromRGB(18, 18, 24)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Settings",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- 4 Orthogonal & Diagonal Teeth (Cross bars)
    local angles = { 0, 45, 90, 135 }
    for i, ang in ipairs(angles) do
        local bar = CreatePrimitive("Frame", {
            Name = "Tooth_" .. tostring(i),
            Size = UDim2.new(0.78, 0, 0.22, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = c,
            Rotation = ang,
            BorderSizePixel = 0,
        }, {
            CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.3, 0) })
        })
        bar.Parent = container
    end

    -- Center Hub Circle
    local hub = CreatePrimitive("Frame", {
        Name = "Hub",
        Size = UDim2.new(0.6, 0, 0.6, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    hub.Parent = container

    -- Center Hole (Mask matching background)
    local hole = CreatePrimitive("Frame", {
        Name = "Hole",
        Size = UDim2.new(0.28, 0, 0.28, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = bg,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    hole.Parent = container

    return container
end

-- 5. PERFORMANCE ICON (Speed tachometer gauge + lightning bolt)
function IconPrimitives.CreatePerformance(size: UDim2?, color: Color3?): Frame
    local c = color or Color3.fromRGB(56, 189, 248)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Performance",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Gauge Arc (Circular border with open bottom)
    local arcRing = CreatePrimitive("Frame", {
        Name = "GaugeArc",
        Size = UDim2.new(0.74, 0, 0.74, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) }),
        CreatePrimitive("UIStroke", {
            Color = c,
            Thickness = 2,
            Transparency = 0.1,
        })
    })
    arcRing.Parent = container

    -- Lightning Bolt in center
    local boltUpper = CreatePrimitive("Frame", {
        Name = "BoltUpper",
        Size = UDim2.new(0.12, 0, 0.44, 0),
        Position = UDim2.new(0.55, 0, 0.38, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        Rotation = -24,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    boltUpper.Parent = container

    local boltLower = CreatePrimitive("Frame", {
        Name = "BoltLower",
        Size = UDim2.new(0.12, 0, 0.44, 0),
        Position = UDim2.new(0.45, 0, 0.62, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        Rotation = -24,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    boltLower.Parent = container

    return container
end

-- 6. MINIMIZE ICON (Horizontal pill bar)
function IconPrimitives.CreateMinimize(size: UDim2?, color: Color3?): Frame
    local c = color or DEFAULT_COLOR

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Minimize",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    local bar = CreatePrimitive("Frame", {
        Name = "Bar",
        Size = UDim2.new(0.7, 0, 0.14, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    bar.Parent = container

    return container
end

-- 7. CLOSE ICON (Diagonal crossed bars)
function IconPrimitives.CreateClose(size: UDim2?, color: Color3?): Frame
    local c = color or Color3.fromRGB(239, 68, 68)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Close",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    local bar1 = CreatePrimitive("Frame", {
        Name = "Bar1",
        Size = UDim2.new(0.74, 0, 0.14, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        Rotation = 45,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    bar1.Parent = container

    local bar2 = CreatePrimitive("Frame", {
        Name = "Bar2",
        Size = UDim2.new(0.74, 0, 0.14, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        Rotation = -45,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    bar2.Parent = container

    return container
end

-- 8. STATUS ICON (Pulsing radar ring + center core dot)
function IconPrimitives.CreateStatus(size: UDim2?, activeColor: Color3?): Frame
    local c = activeColor or Color3.fromRGB(34, 197, 94)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Status",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Outer Halo Ring
    local ring = CreatePrimitive("Frame", {
        Name = "HaloRing",
        Size = UDim2.new(0.8, 0, 0.8, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) }),
        CreatePrimitive("UIStroke", {
            Color = c,
            Thickness = 1.2,
            Transparency = 0.35,
        })
    })
    ring.Parent = container

    -- Center Solid Signal Dot
    local coreDot = CreatePrimitive("Frame", {
        Name = "CoreDot",
        Size = UDim2.new(0.36, 0, 0.36, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    coreDot.Parent = container

    return container
end

-- 9. MOVEMENT ICON (Navigation waypoint / teleport directional arrow)
function IconPrimitives.CreateMovement(size: UDim2?, color: Color3?): Frame
    local c = color or Color3.fromRGB(168, 85, 247)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Movement",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Left slanted wing
    local leftWing = CreatePrimitive("Frame", {
        Name = "LeftWing",
        Size = UDim2.new(0.6, 0, 0.12, 0),
        Position = UDim2.new(0.36, 0, 0.44, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        Rotation = -64,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    leftWing.Parent = container

    -- Right slanted wing
    local rightWing = CreatePrimitive("Frame", {
        Name = "RightWing",
        Size = UDim2.new(0.6, 0, 0.12, 0),
        Position = UDim2.new(0.64, 0, 0.44, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        Rotation = 64,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    rightWing.Parent = container

    -- Center stem waypoint dot
    local centerDot = CreatePrimitive("Frame", {
        Name = "CenterDot",
        Size = UDim2.new(0.18, 0, 0.18, 0),
        Position = UDim2.new(0.5, 0, 0.72, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    centerDot.Parent = container

    return container
end

-- 10. STATISTICS ICON (Telemetry bar chart with 3 graduated levels)
function IconPrimitives.CreateStatistics(size: UDim2?, color: Color3?): Frame
    local c = color or DEFAULT_COLOR

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Statistics",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Bar 1 (Short, 35%)
    local bar1 = CreatePrimitive("Frame", {
        Name = "Bar1",
        Size = UDim2.new(0.18, 0, 0.35, 0),
        Position = UDim2.new(0.24, 0, 0.82, 0),
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.3, 0) })
    })
    bar1.Parent = container

    -- Bar 2 (Medium, 60%)
    local bar2 = CreatePrimitive("Frame", {
        Name = "Bar2",
        Size = UDim2.new(0.18, 0, 0.60, 0),
        Position = UDim2.new(0.5, 0, 0.82, 0),
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.3, 0) })
    })
    bar2.Parent = container

    -- Bar 3 (Tall, 85%)
    local bar3 = CreatePrimitive("Frame", {
        Name = "Bar3",
        Size = UDim2.new(0.18, 0, 0.85, 0),
        Position = UDim2.new(0.76, 0, 0.82, 0),
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.3, 0) })
    })
    bar3.Parent = container

    -- Bottom Baseline
    local baseline = CreatePrimitive("Frame", {
        Name = "Baseline",
        Size = UDim2.new(0.76, 0, 0.08, 0),
        Position = UDim2.new(0.5, 0, 0.88, 0),
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    baseline.Parent = container

    return container
end

-- 11. REFRESH ICON (Rotational sync arrows)
function IconPrimitives.CreateRefresh(size: UDim2?, color: Color3?): Frame
    local c = color or DEFAULT_COLOR

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Refresh",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Arc Ring Base
    local arc = CreatePrimitive("Frame", {
        Name = "ArcRing",
        Size = UDim2.new(0.68, 0, 0.68, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) }),
        CreatePrimitive("UIStroke", {
            Color = c,
            Thickness = 1.8,
            Transparency = 0.1,
        })
    })
    arc.Parent = container

    -- Mask to simulate open circle
    local mask = CreatePrimitive("Frame", {
        Name = "Mask",
        Size = UDim2.new(0.36, 0, 0.36, 0),
        Position = UDim2.new(0.82, 0, 0.18, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(18, 18, 24),
        BorderSizePixel = 0,
    })
    mask.Parent = container

    -- Arrowhead on top right
    local arrow = CreatePrimitive("Frame", {
        Name = "ArrowHead",
        Size = UDim2.new(0.24, 0, 0.12, 0),
        Position = UDim2.new(0.78, 0, 0.22, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        Rotation = 45,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    arrow.Parent = container

    return container
end

-- 12. ZOMBIE ICON (Cyber Undead Skull / Biohazard primitive)
function IconPrimitives.CreateZombie(size: UDim2?, color: Color3?, eyeColor: Color3?): Frame
    local c = color or Color3.fromRGB(34, 197, 94)
    local bg = eyeColor or Color3.fromRGB(18, 18, 24)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Zombie",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Cranium dome
    local cranium = CreatePrimitive("Frame", {
        Name = "Cranium",
        Size = UDim2.new(0.68, 0, 0.52, 0),
        Position = UDim2.new(0.5, 0, 0.32, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.5, 0) })
    })
    cranium.Parent = container

    -- Left eye socket
    local leftEye = CreatePrimitive("Frame", {
        Name = "LeftEye",
        Size = UDim2.new(0.24, 0, 0.34, 0),
        Position = UDim2.new(0.32, 0, 0.52, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = bg,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    leftEye.Parent = cranium

    -- Right eye socket
    local rightEye = CreatePrimitive("Frame", {
        Name = "RightEye",
        Size = UDim2.new(0.24, 0, 0.34, 0),
        Position = UDim2.new(0.68, 0, 0.52, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = bg,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    rightEye.Parent = cranium

    -- Jaw / Muzzle
    local jaw = CreatePrimitive("Frame", {
        Name = "Jaw",
        Size = UDim2.new(0.44, 0, 0.28, 0),
        Position = UDim2.new(0.5, 0, 0.68, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.25, 0) })
    })
    jaw.Parent = container

    -- Teeth divider slits
    local tooth1 = CreatePrimitive("Frame", {
        Name = "Tooth1",
        Size = UDim2.new(0.12, 0, 0.55, 0),
        Position = UDim2.new(0.36, 0, 0.72, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = bg,
        BorderSizePixel = 0,
    })
    tooth1.Parent = jaw

    local tooth2 = CreatePrimitive("Frame", {
        Name = "Tooth2",
        Size = UDim2.new(0.12, 0, 0.55, 0),
        Position = UDim2.new(0.64, 0, 0.72, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = bg,
        BorderSizePixel = 0,
    })
    tooth2.Parent = jaw

    return container
end

-- 13. PLAYER ICON (Humanoid silhouette: head circle + torso shoulders)
function IconPrimitives.CreatePlayer(size: UDim2?, color: Color3?): Frame
    local c = color or Color3.fromRGB(129, 140, 248)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_Player",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    -- Head Circle
    local head = CreatePrimitive("Frame", {
        Name = "Head",
        Size = UDim2.new(0.38, 0, 0.38, 0),
        Position = UDim2.new(0.5, 0, 0.25, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
    })
    head.Parent = container

    -- Shoulders / Torso
    local torso = CreatePrimitive("Frame", {
        Name = "Torso",
        Size = UDim2.new(0.70, 0, 0.40, 0),
        Position = UDim2.new(0.5, 0, 0.68, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = c,
        BorderSizePixel = 0,
    }, {
        CreatePrimitive("UICorner", { CornerRadius = UDim.new(0.45, 0) })
    })
    torso.Parent = container

    return container
end

-- 14. QUICK TOGGLE ICON (Play triangle or pause bars)
function IconPrimitives.CreateQuickToggle(size: UDim2?, isPlaying: boolean?, color: Color3?): Frame
    local c = color or Color3.fromRGB(240, 240, 255)

    local container = CreatePrimitive("Frame", {
        Name = "Icon_QuickToggle",
        Size = size or DEFAULT_SIZE,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    if isPlaying then
        -- Two vertical pause bars
        local bar1 = CreatePrimitive("Frame", {
            Name = "Bar1",
            Size = UDim2.new(0.24, 0, 0.68, 0),
            Position = UDim2.new(0.32, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
        }, {
            CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
        })
        bar1.Parent = container

        local bar2 = CreatePrimitive("Frame", {
            Name = "Bar2",
            Size = UDim2.new(0.24, 0, 0.68, 0),
            Position = UDim2.new(0.68, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
        }, {
            CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
        })
        bar2.Parent = container
    else
        -- Play chevron / triangle
        local slantTop = CreatePrimitive("Frame", {
            Name = "SlantTop",
            Size = UDim2.new(0.54, 0, 0.18, 0),
            Position = UDim2.new(0.32, 0, 0.35, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = c,
            Rotation = 30,
            BorderSizePixel = 0,
        }, {
            CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
        })
        slantTop.Parent = container

        local slantBot = CreatePrimitive("Frame", {
            Name = "SlantBot",
            Size = UDim2.new(0.54, 0, 0.18, 0),
            Position = UDim2.new(0.32, 0, 0.65, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = c,
            Rotation = -30,
            BorderSizePixel = 0,
        }, {
            CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
        })
        slantBot.Parent = container

        local backBar = CreatePrimitive("Frame", {
            Name = "BackBar",
            Size = UDim2.new(0.18, 0, 0.62, 0),
            Position = UDim2.new(0.32, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
        }, {
            CreatePrimitive("UICorner", { CornerRadius = UDim.new(1, 0) })
        })
        backBar.Parent = container
    end

    return container
end

-- Generic Factory Dispatcher
function IconPrimitives.Render(iconName: string, size: UDim2?, color: Color3?, extraColor: any): Frame
    local name = string.lower(iconName)
    if name == "candy" then
        return IconPrimitives.CreateCandy(size, color, extraColor)
    elseif name == "start" then
        return IconPrimitives.CreateStart(size, color)
    elseif name == "stop" then
        return IconPrimitives.CreateStop(size, color)
    elseif name == "settings" then
        return IconPrimitives.CreateSettings(size, color, extraColor)
    elseif name == "performance" then
        return IconPrimitives.CreatePerformance(size, color)
    elseif name == "minimize" then
        return IconPrimitives.CreateMinimize(size, color)
    elseif name == "close" then
        return IconPrimitives.CreateClose(size, color)
    elseif name == "status" then
        return IconPrimitives.CreateStatus(size, color)
    elseif name == "movement" then
        return IconPrimitives.CreateMovement(size, color)
    elseif name == "statistics" then
        return IconPrimitives.CreateStatistics(size, color)
    elseif name == "refresh" then
        return IconPrimitives.CreateRefresh(size, color)
    elseif name == "zombie" then
        return IconPrimitives.CreateZombie(size, color, extraColor)
    elseif name == "player" or name == "user" then
        return IconPrimitives.CreatePlayer(size, color)
    elseif name == "quicktoggle" then
        local isPlaying = (extraColor == true)
        return IconPrimitives.CreateQuickToggle(size, isPlaying, color)
    else
        -- Fallback: generic status dot
        return IconPrimitives.CreateStatus(size, color)
    end
end

-- Backwards compatibility alias for CreateIcon
function IconPrimitives.CreateIcon(iconName: string, size: any?, color: Color3?, accentColor: Color3?): Frame
    local sz: UDim2? = nil
    if typeof(size) == "number" then
        sz = UDim2.fromOffset(size, size)
    elseif typeof(size) == "UDim2" then
        sz = size
    end
    return IconPrimitives.Render(iconName, sz, color, accentColor)
end

return IconPrimitives
