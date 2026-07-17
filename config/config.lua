shared.Story = {
    ['Selection'] = {
        ['Selection Mode'] = 'Target', -- target auto
    
        ["Checks"] = {
            ["Target"] = {
                ["Knocked"] = true,
                ["Grabbed"] = true,
                ["Visible"] = true,
                ["On Screen"] = false,
                ["Visible When Locking"] = false
            },
            
            ["Auto"] = {
                ["Knocked"] = true,
                ["Grabbed"] = true,
                ["Visible"] = true,
                ["Forcefield"] = true,
                ["Test"] = true,
            },
        },
    },
 
    ['Binds'] = {
        ['Silent Aim'] = 'C',
        ['Aim Assist'] = 'X',
        ['Triggerbot'] = 'V',
        ['ESP'] = 'Y',
        ['Speed'] = 'Z',
    },
 
    ["SilentAim"] = {
        ['Enabled'] = true,
		['Mode'] = 'Toggle', -- target // hold 
        ['Hitpart'] = {
            'Head',
            'HumanoidRootPart'
        },
        ['Prediction'] = {
            ['Enabled'] = true,
            ['X'] = 0.1335,
            ['Y'] = 0.1335,
            ['Z'] = 0.1335,
            ['Stabilize'] = 5,
        },
    },
    ['Aim Assist'] = {
        ['Enabled'] = true,
        ['Mode'] = 'Toggle',
        ['Hitpart'] = {
            'Head',
            'HumanoidRootPart'
        },
        ["Smoothing"] = 0.5,
        ['Prediction'] = {
            ['Enabled'] = false,
            ['X'] = 0.1335,
            ['Y'] = 0.1335,
            ['Z'] = 0.1335,
        },
    },
    ['Triggerbot'] = {
        ['Enabled'] = true,
        ['Mode'] = 'Toggle',
        ['Delay'] = 0.01,
        ['Weapon Configuration'] = {
            ['Enabled'] = false,
            ['Gun'] = {
                '[Double-Barrel SG]',
                '[Revolver]',
                '[TacticalShotgun]',
            },
        },
    },
 
    ['Double Tap'] = {
        ['Enabled'] = false,
        ['Guns'] = {
            '[Revolver]',
        },
    },
 
	['Fov'] = {
        ['Enabled'] = false,
        ['Visible'] = true,
        ['Size'] = 150,
        ['Color'] = Color3.fromRGB(255, 255, 255),
    },
 
    ['Distance Check'] = {
        ['Enabled'] = false,
        ['Max Distance'] = 300,
    },
 
    ['Spread Modification'] = {
        ['Enabled'] = true,
        ['Guns'] = {
            ['[Double-Barrel SG]'] = 0,
            ['[TacticalShotgun]'] = 0,
        },
    },
 
    ['Hitbox Expander'] = {
        ['Enabled'] = false,
        ['Size'] = {
            ['X'] = 5,
            ['Y'] = 5,
            ['Z'] = 5,
        },
    },
    
    ['Speed Modification'] = {
        ['Enabled'] = true,
        ['Multiplier'] = 11.5,
 
        ['Headless'] = false,
        ['Anti Trip'] = true,
    },
 
    ['ESP'] = {
        ['Enabled'] = true,
        ['Name'] = {
            ['Enabled'] = true,
            ['Color'] = Color3.fromRGB(255, 255, 255),
            ['Position'] = 'Bottom', -- top bottom left right 
        },
    },
 
    ['Skin Changer'] = {
        ['Enabled'] = false,
        ['Skins'] = {
            ['[Double-Barrel SG]'] = 'Galaxy',
            ['[Revolver]'] = 'Galaxy',
            ['[TacticalShotgun]'] = 'Galaxy',
            ['[Knife]'] = 'GPO-Knife',
        },
    },
 
    ['No Jump Cooldown'] = {
        ['Enabled'] = true,
    },
}
