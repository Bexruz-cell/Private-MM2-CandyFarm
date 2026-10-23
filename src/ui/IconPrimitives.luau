--!strict
-- IconPrimitives.luau: Native Vector-Style UI Primitives for Roblox
-- Renders clean geometric icons using Frames, UICorner, UIStroke and Rotation.
-- Zero external image asset requests. Zero emojis. 100% self-contained.

local IconPrimitives = {}

local function Create(className: string, properties: { [string]: any }, children: { any }?): any
    local instance = Instance.new(className)
    for k, v in pairs(properties) do
        (instance :: any)[k] = v
    end
    if children then
        for _, child in ipairs(children) do
            child.Parent = instance
        end
    end
    return instance
end

-- Renders a scalable vector icon into a container Frame
function IconPrimitives.CreateIcon(iconName: string, size: number, color: Color3?, accentColor: Color3?): Frame
    local c = color or Color3.fromRGB(220, 220, 230)
    local ac = accentColor or Color3.fromRGB(168, 85, 247)
    local s = size or 16

    local container = Create("Frame", {
        Name = "Icon_" .. iconName,
        Size = UDim2.new(0, s, 0, s),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = false,
    })

    if iconName == "Candy" then
        -- Central candy diamond body
        Create("Frame", {
            Name = "Body",
            Size = UDim2.new(0.65, 0, 0.65, 0),
            Position = UDim2.new(0.175, 0, 0.175, 0),
            BackgroundColor3 = ac,
            Rotation = 45,
            BorderSizePixel = 0,
            Parent = container,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0.35, 0) }),
            Create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.5, Thickness = 1 }),
        })
        -- Left twist
        Create("Frame", {
            Name = "TwistL",
            Size = UDim2.new(0.22, 0, 0.22, 0),
            Position = UDim2.new(0.02, 0, 0.39, 0),
            BackgroundColor3 = c,
            Rotation = 25,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        -- Right twist
        Create("Frame", {
            Name = "TwistR",
            Size = UDim2.new(0.22, 0, 0.22, 0),
            Position = UDim2.new(0.76, 0, 0.39, 0),
            BackgroundColor3 = c,
            Rotation = -25,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })

    elseif iconName == "Start" then
        -- Clean play triangle made of angled bars
        local bar1 = Create("Frame", {
            Size = UDim2.new(0.55, 0, 0.18, 0),
            Position = UDim2.new(0.25, 0, 0.32, 0),
            BackgroundColor3 = c,
            Rotation = 30,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        local bar2 = Create("Frame", {
            Size = UDim2.new(0.55, 0, 0.18, 0),
            Position = UDim2.new(0.25, 0, 0.52, 0),
            BackgroundColor3 = c,
            Rotation = -30,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        local spine = Create("Frame", {
            Size = UDim2.new(0.18, 0, 0.65, 0),
            Position = UDim2.new(0.2, 0, 0.18, 0),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })

    elseif iconName == "Stop" then
        -- Rounded stop square
        Create("Frame", {
            Size = UDim2.new(0.68, 0, 0.68, 0),
            Position = UDim2.new(0.16, 0, 0.16, 0),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
            Parent = container,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0.22, 0) }),
        })

    elseif iconName == "Settings" then
        -- Gear icon
        for i = 0, 3 do
            Create("Frame", {
                Size = UDim2.new(0.85, 0, 0.22, 0),
                Position = UDim2.new(0.075, 0, 0.39, 0),
                BackgroundColor3 = c,
                Rotation = i * 45,
                BorderSizePixel = 0,
                Parent = container,
            }, { Create("UICorner", { CornerRadius = UDim.new(0.3, 0) }) })
        end
        Create("Frame", {
            Size = UDim2.new(0.52, 0, 0.52, 0),
            Position = UDim2.new(0.24, 0, 0.24, 0),
            BackgroundColor3 = ac,
            BorderSizePixel = 0,
            Parent = container,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
        })

    elseif iconName == "Performance" then
        -- Lightning bolt
        Create("Frame", {
            Size = UDim2.new(0.48, 0, 0.18, 0),
            Position = UDim2.new(0.28, 0, 0.18, 0),
            BackgroundColor3 = c,
            Rotation = -35,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.48, 0, 0.18, 0),
            Position = UDim2.new(0.24, 0, 0.62, 0),
            BackgroundColor3 = c,
            Rotation = -35,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.35, 0, 0.18, 0),
            Position = UDim2.new(0.32, 0, 0.41, 0),
            BackgroundColor3 = ac,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })

    elseif iconName == "Zombie" then
        -- Geometric zombie skull
        Create("Frame", {
            Size = UDim2.new(0.72, 0, 0.72, 0),
            Position = UDim2.new(0.14, 0, 0.14, 0),
            BackgroundColor3 = Color3.fromRGB(34, 197, 94),
            BorderSizePixel = 0,
            Parent = container,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0.3, 0) }),
        })
        -- Eyes
        Create("Frame", {
            Size = UDim2.new(0.18, 0, 0.18, 0),
            Position = UDim2.new(0.26, 0, 0.32, 0),
            BackgroundColor3 = Color3.fromRGB(234, 179, 8),
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.18, 0, 0.18, 0),
            Position = UDim2.new(0.56, 0, 0.32, 0),
            BackgroundColor3 = Color3.fromRGB(239, 68, 68),
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
        -- Mouth stitch
        Create("Frame", {
            Size = UDim2.new(0.38, 0, 0.08, 0),
            Position = UDim2.new(0.31, 0, 0.65, 0),
            BackgroundColor3 = Color3.fromRGB(15, 23, 42),
            BorderSizePixel = 0,
            Parent = container,
        })

    elseif iconName == "Minimize" then
        -- Horizontal bar
        Create("Frame", {
            Size = UDim2.new(0.65, 0, 0.14, 0),
            Position = UDim2.new(0.175, 0, 0.43, 0),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })

    elseif iconName == "Close" then
        -- Diagonal X
        Create("Frame", {
            Size = UDim2.new(0.7, 0, 0.14, 0),
            Position = UDim2.new(0.15, 0, 0.43, 0),
            BackgroundColor3 = c,
            Rotation = 45,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.7, 0, 0.14, 0),
            Position = UDim2.new(0.15, 0, 0.43, 0),
            BackgroundColor3 = c,
            Rotation = -45,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })

    elseif iconName == "Status" then
        -- Radar pulse ring + core dot
        Create("Frame", {
            Size = UDim2.new(0.76, 0, 0.76, 0),
            Position = UDim2.new(0.12, 0, 0.12, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = container,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
            Create("UIStroke", { Color = c, Thickness = 1.5 }),
        })
        Create("Frame", {
            Size = UDim2.new(0.28, 0, 0.28, 0),
            Position = UDim2.new(0.36, 0, 0.36, 0),
            BackgroundColor3 = ac,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

    elseif iconName == "Movement" then
        -- Directional chevron
        Create("Frame", {
            Size = UDim2.new(0.48, 0, 0.16, 0),
            Position = UDim2.new(0.12, 0, 0.42, 0),
            BackgroundColor3 = c,
            Rotation = 45,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.48, 0, 0.16, 0),
            Position = UDim2.new(0.40, 0, 0.42, 0),
            BackgroundColor3 = c,
            Rotation = -45,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })

    elseif iconName == "Statistics" then
        -- 3 vertical activity bars
        Create("Frame", {
            Size = UDim2.new(0.16, 0, 0.38, 0),
            Position = UDim2.new(0.18, 0, 0.48, 0),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.4, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.16, 0, 0.68, 0),
            Position = UDim2.new(0.42, 0, 0.18, 0),
            BackgroundColor3 = ac,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.4, 0) }) })
        Create("Frame", {
            Size = UDim2.new(0.16, 0, 0.50, 0),
            Position = UDim2.new(0.66, 0, 0.36, 0),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.4, 0) }) })

    elseif iconName == "Refresh" then
        -- Ring with notch
        Create("Frame", {
            Size = UDim2.new(0.72, 0, 0.72, 0),
            Position = UDim2.new(0.14, 0, 0.14, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = container,
        }, {
            Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
            Create("UIStroke", { Color = c, Thickness = 1.5 }),
        })
        Create("Frame", {
            Size = UDim2.new(0.24, 0, 0.24, 0),
            Position = UDim2.new(0.62, 0, 0.10, 0),
            BackgroundColor3 = ac,
            BorderSizePixel = 0,
            Parent = container,
        }, { Create("UICorner", { CornerRadius = UDim.new(0.3, 0) }) })
    end

    return container
end

return IconPrimitives
