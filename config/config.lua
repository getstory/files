shared.Story = {
    ['Settings'] = {
        ['Target Aim'] = true,
        ['Knock Check'] = true,
        ['Visible Check'] = false,
    },

    ['Keybinds'] = {
        ['Target Lock'] = {
            ['Key'] = 'F',
            ['Mode'] = 'Toggle',
        },
        ['Trigger Bot'] = {
            ['Key'] = 'F',
            ['Mode'] = 'Toggle',
        },
        ['Speed'] = 'Q',
        ['ESP'] = 'E',
    },

    ['FOV'] = {
        ['Enabled'] = false,
        ['Visible'] = true,
        ['Size'] = Vector2.new(250, 250),
        ['Thickness'] = 2,
        ['Color'] = Color3.fromRGB(255, 255, 255),
    },

    ['Silent Aim'] = {
        ['Enabled'] = true,
        ['Hit Part'] = 'Closest Part',
        ['Use Prediction'] = true,
        ['Prediction'] = {
            ['X'] = 0.133,
            ['Y'] = 0.133,
            ['Z'] = 0.133,
        },
    },

    ['Camera Lock'] = {
        ['Enabled'] = true,
        ['Hit Part'] = 'Closest Part',
        ['Smoothing'] = 40,
        ['Use Prediction'] = true,
        ['Prediction'] = 0.133,
    },

    ['Trigger Bot'] = {
        ['Enabled'] = true,
        ['Delay'] = 0.01,
        ['Specific Weapons'] = {
            ['Enabled'] = true,
            ['Weapons'] = {
                '[Double-Barrel SG]',
                '[Revolver]',
                '[TacticalShotgun]',
            },
        },
    },

    ['Spread'] = {
        ['Enabled'] = true,
        ['Amount'] = 1,
        ['Specific Weapons'] = {
            ['Enabled'] = false,
            ['Weapons'] = {
                '[Double-Barrel SG]',
                '[TacticalShotgun]',
            },
        },
    },

    ['Speed'] = {
        ['Enabled'] = true,
        ['Multiplier'] = 16,
        ['Anti Fling'] = false,
    },

    ['Hitbox Expander'] = {
        ['Enabled'] = false,
        ['Size'] = 5,
    },

    ['Spiderman'] = {
        ['Enabled'] = false,
    },

    ['Visual Awareness'] = {
        ['Enabled'] = true,
        ['Color'] = Color3.fromRGB(255, 255, 255),
        ['Target Color'] = Color3.fromRGB(255, 0, 0),
    },
}
