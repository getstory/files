shared.Story = {
    ['Settings'] = {
        ['Target Aim']    = true,
        ['Knock Check']   = true,
        ['Visible Check'] = false,
    },

    ['Keybinds'] = {
        ['Target Lock'] = {
            ['Key']  = 'C',
            ['Mode'] = 'Toggle',
        },
        ['Trigger Bot'] = {
            ['Key']  = 'C',
            ['Mode'] = 'Toggle',
        },
        ['Speed']          = 'T',
        ['ESP']            = 'P',
        ['Super Jump']     = 'V',
        ['Toggle GUI']     = 'G',
        ['Spin']           = 'V',
        ['Macro']          = 'V',
        ['Aim Assist']     = 'X',
    },

    ['Silent Aim'] = {
        ['Enabled']              = true,
        ['Hit Scan']             = 'On Shot',
        ['Hit Part']             = 'Head',
        ['Target Line']          = false,
        ['OverrideYAxis']        = 'None',
        ['Prediction']           = 0.12972152,
        ['Prediction Adjustment'] = 1,
        ['3D Adjustment']        = { false, Vector3.new(1, 0, 1) },
        ['Hit Location'] = {
            ['Hit Target']        = 'Nearest Point',
            ['Point Scale']       = 'Dynamic',
            ['Max Nearest Point'] = 0,
            ['Ignore Blank Points'] = true,
            ['R15']               = {'Head'},
        },
        ['Hit Chance'] = {
            ['HitChance']   = 100,
            ['Miss Chance'] = 0,
        },
        ['Prediction Points'] = {
            ['Enabled'] = false,
            ['Hit Points'] = {
                ['Head']             = 0.011,
                ['UpperTorso']       = 0.135,
                ['LowerTorso']       = 0.127,
                ['HumanoidRootPart'] = 0.127,
                ['LeftUpperArm']     = 0.127,
                ['LeftLowerArm']     = 0.127,
                ['LeftHand']         = 0.127,
                ['RightUpperArm']    = 0.127,
                ['RightLowerArm']    = 0.127,
                ['RightHand']        = 0.127,
                ['LeftUpperLeg']     = 0.127,
                ['LeftLowerLeg']     = 0.127,
                ['LeftFoot']         = 0.127,
                ['RightUpperLeg']    = 0.127,
                ['RightLowerLeg']    = 0.127,
                ['RightFoot']        = 0.127,
            },
        },
        ['Ping Prediction'] = {
            ['Enabled']   = false,
            ['20-30']     = 0.105,
            ['30 40']     = 0.110,
            ['40 50']     = 0.115,
            ['50 60']     = 0.120,
            ['60 70']     = 0.123,
            ['70 80']     = 0.129,
            ['80 90']     = 0.130,
            ['90 100']    = 0.134,
            ['100 110']   = 0.139,
            ['110 120']   = 0.144,
            ['120 130']   = 0.149,
            ['130 140']   = 0.1274,
            ['140 150']   = 0.1575,
        },
        ['Anti Curve'] = {
            ['Enabled'] = false,
            ['Mode']    = 'Angles',
            ['Angles']  = {
                ['Max Angle']            = 12,
                ['Distance Threshold']   = 100,
                ['Visualize Anti Curve'] = false,
            },
        },
        ['Client Redirection'] = {
            ['Enabled'] = false,
            ['Weapons'] = { '[Revolver]', '[Silencer]', '[Glock]' },
        },
        ['FOV'] = {
            ['Enabled']  = true,
            ['Visible']  = true,
            ['Sync']     = false,
            ['Type']     = 'Circle', -- Circle / Box, 3D
            ['Box']      = {7, 7},
            ['3D']       = {5, 7, 5},
            ['Circle']   = 200,
            ['Hit Scan'] = math.huge, -- Radius to scan for players within
            ['Weapon Configs'] = {
                ['Enabled']  = false,
                ['Shotguns'] = { ['Circle'] = 150, ['Box'] = {5, 5} },
                ['Pistols']  = { ['Circle'] = 150, ['Box'] = {4, 4} },
                ['Others']   = { ['Circle'] = 15,  ['Box'] = {2, 2} },
            },
        },
    },

    ['Camera Lock'] = {
        ['Enabled']             = true,
        ['Part']                = 'HumanoidRootPart',
        ['MultipleTargetPart']  = {'Head', 'HumanoidRootPart'},
        ['Smoothing']           = 0.045,
        ['Prediction']          = 0.39,
        ['CameraShake']         = 0,
        ['JumpOffset']          = 0,
    },

    ['Trigger Bot'] = {
        ['Enabled']    = true,
        ['Delay']      = 0.01,
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
        ['Amount']  = 0,
        ['Specific Weapons'] = {
            ['Enabled'] = true,
            ['Weapons'] = {
                '[Double-Barrel SG]',
                '[TacticalShotgun]',
            },
        },
    },

    ['Speed'] = {
        ['Enabled']    = true,
        ['Anti Fling'] = false,
        ['Normal'] = {
            ['Multiplier'] = 35,
        },
        ['Low Health'] = {
            ['Enabled']    = false,
            ['Threshold']  = 40,
            ['Multiplier'] = 50,
        },
        ['Reloading'] = {
            ['Enabled']    = false,
            ['Multiplier'] = 28,
        },
        ['Shooting'] = {
            ['Enabled']    = false,
            ['Multiplier'] = 20,
        },
    },

    ['Hitbox Expander'] = {
        ['Enabled'] = false,
        ['Size']    = 3,
    },

    ['Spiderman'] = {
        ['Enabled'] = false,
    },

    ['Visual Awareness'] = {
        ['Enabled']      = true,
        ['Color']        = Color3.fromRGB(255, 255, 255),
        ['Target Color'] = Color3.fromRGB(50, 205, 50),
    },

    ['Super Jump'] = {
        ['Enabled']  = false,
        ['Power']    = 265,
        ['Cooldown'] = 0.1,
    },

    ['Infinite Range'] = {
        ['Enabled']   = true,
        ['Max Range'] = math.huge,
    },

    ['Rapid Fire'] = {
        ['Enabled'] = true,
        ['Delay']   = 0.01,
        ['Specific Weapons'] = {
            ['Enabled'] = false,
            ['Weapons'] = {
                '[Revolver]',
                '[Double-Barrel SG]',
            },
        },
    },

    ['Spin'] = {
        ['Enabled']   = true,
        ['SpinSpeed'] = 9600,
        ['Degrees']   = 360,
    },

    ['Macro'] = {
        ['Enabled'] = true,
        ['Speed']   = 2,
        ['Type']    = 'Third',
    },

    ['Aim Assist'] = {
        ['Enabled']        = true,
        ['Smoothing']      = 0.1,
        ['Prediction']     = 0.127,
        ['OverrideYAxis']  = 'None',
        ['FOV']            = 180,
        ['Wall Check']     = false,
        ['Knocked Check']  = true,
    },

    ['Double Tap'] = {
        ['Enabled'] = true,
        ['Delay']   = 0.05,
    },

    ['Bounding'] = {
        ['Enabled'] = false,
    },

    ['NoClip'] = {
        ['Enabled'] = false,
        ['Delay']   = 0.01,
    },

    ['Chams'] = {
        ['Enabled']         = true,
        ['Fill Color']      = Color3.fromRGB(255, 255, 255),
        ['Fill Transparency'] = 0.5,
        ['Outline Color']   = Color3.fromRGB(255, 255, 255),
        ['Outline Transparency'] = 0,
        ['Depth Mode']      = 'AlwaysOnTop',
    },

    ['Velocity Spoof'] = {
        ['Enabled'] = false,
        ['Type']    = 'Prediction Disabler',
    },

    ['Hit Part Override'] = {
        ['Enabled'] = true,
        ['Parts']   = {'Head', 'HumanoidRootPart', 'UpperTorso'},
    },

    ['Automated Prediction'] = {
        ['Enabled'] = false,
    },

    ['Skin Changer'] = {
        ['Enabled'] = true,
        ['Selected'] = {
            ['[Silencer]']        = 'Default',
            ['[Revolver]']        = 'Default',
            ['[Double-Barrel SG]'] = 'Default',
            ['[TacticalShotgun]'] = 'Default',
            ['[Knife]']           = 'Default',
        },
    },
    ['Name ESP'] = {
        ['Enabled'] = true,
        ['Settings'] = {
            ['Color Settings'] = {
                ['Color']        = Color3.fromRGB(180, 180, 180),
                ['Locked Color'] = Color3.fromRGB(130, 185, 255),
            },
            ['Text Size'] = 13,
            ['Font']      = 'GothamBold',
        },
    },

    ['Target Checks'] = {
        ['Knocked']    = true,
        ['Grabbed']    = false,
        ['Wall']       = true,
        ['Forcefield'] = true,
    },

    ['Self Checks'] = {
        ['Knocked']    = true,
        ['Grabbed']    = true,
        ['Forcefield'] = false,
    },

    ['Unlock Conditions'] = {
        ['Unlock on Target Knock'] = true,
        ['Unlock on Self Knock']   = false,
    },

    ['Raid Awareness'] = {
        ['Enabled']             = true,
        ['Max Render Distance'] = 250,
        ['Binds'] = {
            ['Add Target']    = 'J',
            ['Remove Target'] = 'P',
        },
        ['Box'] = {
            ['Enabled']   = true,
            ['Box Color'] = Color3.fromRGB(255, 255, 255),
        },
        ['Name'] = {
            ['Enabled'] = true,
            ['Type']    = 'Display',
            ['Color']   = Color3.fromRGB(255, 255, 255),
        },
        ['Health'] = {
            ['Enabled']              = true,
            ['Type']                 = 'Bar',
            ['Missing Health Color'] = Color3.fromRGB(255, 0, 0),
            ['High Health Color']    = Color3.fromRGB(0, 255, 0),
        },
        ['Lines'] = {
            ['Enabled'] = false,
            ['Type']    = 'Top',
            ['Color']   = Color3.fromRGB(255, 255, 255),
        },
    },
}
