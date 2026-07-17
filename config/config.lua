shared.Accuracy = {
    ['Settings'] = {
        ['Target Aim'] = true,
        ['Knock Check'] = true,
        ['Visible Check'] = false,
    },
    ['Keybinds'] = {
        ['Target Lock'] = {  -- keybind settings for camera/aim lock
            ['Key'] = 'F',
            ['Mode'] = 'Toggle',
        },
        ['Trigger Bot'] = {  -- keybind settings for auto-fire when aiming at a target
            ['Key'] = 'F',
            ['Mode'] = 'Toggle',
        },
        ['Speed'] = 'Q',  -- keybind to toggle movement speed boost
        ['ESP'] = 'E',  -- keybind to toggle visual awareness/ESP display
        ['Super Jump'] = 'V',  -- keybind to enable super jump behavior
        ['Toggle on-screen Text'] = 'G',  -- keybind to toggle on-screen text display
    },
    ['FOV'] = {
        ['Enabled'] = false,
        ['Visible'] = true,
        ['Size'] = Vector2.new(2000, 2000),
        ['Thickness'] = 2,
        ['Color'] = Color3.fromRGB(255, 255, 255),
    },
    ['Silent Aim'] = { -- doesnt work for der hood for some reason but works for other games
        ['Enabled'] = true,
        ['Hit Part'] = 'Head',
        ['Use Prediction'] = false,
        ['Prediction'] = {
            ['X'] = 0,
            ['Y'] = 0,
            ['Z'] = 0,
        },
    },
    ['Camera Lock'] = {
        ['Enabled'] = false,
        ['Hit Part'] = 'Closest Part',
        ['Smoothing'] = 40,
        ['Use Prediction'] = true,
        ['Prediction'] = 0.133,
    },
    ['Trigger Bot'] = {
        ['Enabled'] = true,
        ['Delay'] = 0.01,
        ['Knife Check'] = true,
        ['Specific Weapons'] = {
            ['Enabled'] = false,
            ['Weapons'] = {
                '[Double-Barrel SG]',
                '[Revolver]',
                '[TacticalShotgun]',
            },
        },
    },
    ['Spread'] = {
        ['Enabled'] = true,
        ['Amount'] = 26,
        ['Specific Weapons'] = {
            ['Enabled'] = true,
            ['Weapons'] = {
                '[Double-Barrel SG]',
                '[TacticalShotgun]',
            },
        },
    },
    ['Speed'] = {
        ['Enabled'] = true,
        ['Multiplier'] = 35,
        ['Anti Fling'] = false,
    },
    ['Hitbox Expander'] = {
        ['Enabled'] = true,
        ['Size'] = 3,
    },
    ['Spiderman'] = {
        ['Enabled'] = false,
    },
    ['Visual Awareness'] = {
        ['Enabled'] = true,
        ['Color'] = Color3.fromRGB(255, 255, 255),
        ['Target Color'] = Color3.fromRGB(50, 205, 50),
    },
    ['Super Jump'] = {
        ['Enabled'] = true,
        ['Power'] = 265,
        ['Cooldown'] = 0.1,
    },
        ['Infinite Range'] = {
        ['Enabled'] = true,
        ['Key'] = 'F',
        ['Max Range'] = 99999,
    },
        ['Rapid Fire'] = {
        ['Enabled'] = true,
        ['Delay'] = 0.02,
        ['Specific Weapons'] = {
            ['Enabled'] = false,
            ['Weapons'] = {
                '[Revolver]',
                '[Double-Barrel SG]',
            },
        },
    },
}

