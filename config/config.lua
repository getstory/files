shared.Story = {
    ['settings'] = {
        ['knock check'] = true,
        ['visible check'] = true,
        ['self knock check'] = true,
        ['knife check'] = true,
    },

    ['targeting'] = {
        ['mode'] = 'Select', -- Select/Automatic
    },

    ['binds'] = {
        ['silent aim'] = 'C',
        ['cam lock'] = 'X',
        ['triggerbot'] = 'V',
        ['super jump'] = 'B',
        ['esp'] = 'Y',
        ['speed'] = 'Z',
    },

    ['silent aimbot'] = {
        ['enabled'] = true,
        ['mode'] = 'Toggle',
        ['hitpart'] = 'Closest Part',
        ['use prediction'] = true,
        ['prediction'] = {
            ['x'] = 0.133,
            ['y'] = 0.133,
            ['z'] = 0.133,
        },
        ['fov'] = {
            ['enabled'] = true,
            ['visible'] = true,
            ['mode'] = '3D', -- 3D/2D
            ['active color'] = Color3.fromRGB(0, 17, 255),
            ['size'] = {
                ['x'] = 10,
                ['y'] = 10,
                ['z'] = 10,
            },
        },
        ['distance check'] = {
            ['enabled'] = true,
            ['max distance'] = 300,
        },
    },

    ['camera aimbot'] = {
        ['enabled'] = true,
        ['mode'] = 'Toggle',
        ['hitpart'] = 'Closest Part',
        ['smoothing'] = {
            ['x'] = 40,
            ['y'] = 40,
            ['z'] = 40,
        },
        ['use prediction'] = true,
        ['prediction'] = {
            ['x'] = 0.133,
            ['y'] = 0.133,
            ['z'] = 0.133,
        },
        ['fov'] = {
            ['enabled'] = true,
            ['visible'] = true,
            ['mode'] = '3D', -- 3D/2D
            ['active color'] = Color3.fromRGB(0, 17, 255),
            ['size'] = {
                ['x'] = 10,
                ['y'] = 10,
                ['z'] = 10,
            },
        },
        ['distance check'] = {
            ['enabled'] = true,
            ['max distance'] = 300,
        },
    },

    ['trigger bot'] = {
        ['enabled'] = true,
        ['mode'] = 'Hold',
        ['delay'] = 0.01,
        ['require target'] = true,
        ['specific weapons'] = {
            ['enabled'] = false,
            ['weapons'] = {
                '[Double-Barrel SG]',
                '[Revolver]',
                '[TacticalShotgun]',
            },
        },
        ['fov'] = {
            ['enabled'] = true,
            ['visible'] = true,
            ['mode'] = '3D', -- 3D/2D
            ['active color'] = Color3.fromRGB(0, 17, 255),
            ['size'] = {
                ['x'] = 10,
                ['y'] = 10,
                ['z'] = 10,
            },
        },
        ['distance check'] = {
            ['enabled'] = true,
            ['max distance'] = 300,
        },
    },

    ['target line'] = {
        ['enabled'] = true,
        ['thickness'] = 2.2,
        ['transparency'] = 0.8,
        ['vulnerable'] = Color3.fromRGB(255, 85, 127),
        ['invulnerable'] = Color3.fromRGB(150, 150, 150),
    },

    ['spread modifications'] = {
        ['enabled'] = true,
        ['amount'] = 1, -- 1-100
        ['specific weapons'] = {
            ['enabled'] = false,
            ['weapons'] = {
                '[Double-Barrel SG]',
                '[TacticalShotgun]',
            },
        },
    },

    ['super jump'] = {
        ['enabled'] = false,
        ['jump power'] = 100,
    },

    ['rapid fire'] = {
        ['enabled'] = false,
        ['delay'] = 0.01,
        ['specific weapons'] = {
            ['enabled'] = false,
            ['weapons'] = {
                '[Revolver]',
            },
        },
    },

    ['hitbox expander'] = {
        ['enabled'] = false,
        ['size'] = 5,
    },

    ['spiderman'] = {
        ['enabled'] = false,
        ['jumppower'] = 50,
        ['knifejumppower'] = 60,
    },

    ['speed modifications'] = {
        ['enabled'] = true,
        ['multiplier'] = 35,
    },

    ['esp'] = {
        ['enabled'] = true,
        ['color'] = Color3.fromRGB(255, 255, 255),
        ['target color'] = Color3.fromRGB(255, 0, 0),
        ['use display name'] = false,
        ['name above'] = false,
    },

    ['skins'] = {
        ['enabled'] = false,
        ['weapons'] = {
            ['[Double-Barrel SG]'] = "Golden Age",
            ['[Revolver]'] = "Golden Age",
            ['[TacticalShotgun]'] = "Shadow",
            ['[Knife]'] = "Golden Age Tanto",
        },
    },

    ['headless'] = {
        ['enabled'] = false,
        ['remove face accessories'] = true,
    },
  },
}
