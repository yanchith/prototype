Overworld :: struct {
    initted:    bool;
    has_errors: bool; // TODO(jt): Reset this at some point?
    needs_save: bool; // Overworld only sets this to true, but other places can set this back to false after handling.

    current_area_name: string;

    effects: Effects;

    newly_solved_levels: [..] string;

    // Points to a Scroll.
    //
    // TODO(jt): Index/handle instead of pointer, if we start removing entities.
    reading_scroll:                    *Scroll;
    reading_scroll_page:               s64;
    reading_scroll_backwards:          bool;
    reading_scroll_time_spent_on_page: f32;

    // TODO(jt): Put areas and entities into a game-specific arena.
    areas:           [..] Area;

    //
    // Entities
    //
    level_entrances: [..] Level_Entrance;
    area_entrances:  [..] Area_Entrance;
    scrolls:         [..] Scroll;
}

Area :: struct {
    name: string;
    size: IVector2;

    music: Music;
    hint_flags: Hint_Flags;
}

// TODO(jt): Make entities serializable!
Entity :: struct {
    area: string;
    rect: Rect;

    hovered: bool;

    // 'unlocked' is the cached value computed out of unlocked_by_levels.
    unlocked:           bool;
    unlocked_by_levels: [] string;

    LOCKED_FX_COLOR       :: Vector4;
    LOCKED_FX_DURATION    :: 0.25;
    LOCKED_FX_ANIM_FRAMES :: Effect_Frame.[
        .{ rect = SPARKLE_ANIM_RECT0, color = .{ 1, 0.5, 0.5, 1 } },
        .{ rect = SPARKLE_ANIM_RECT1, color = .{ 1, 0.5, 0.5, 1 } },
        .{ rect = SPARKLE_ANIM_RECT2, color = .{ 1, 0.5, 0.5, 1 } },
    ];

    SOLVED_FX_DURATION    :: 0.5;
    SOLVED_FX_ANIM_FRAMES :: Effect_Frame.[
        .{ rect = SPARKLE_ANIM_RECT0 },
        .{ rect = SPARKLE_ANIM_RECT1 },
        .{ rect = SPARKLE_ANIM_RECT2 },
        .{ rect = SPARKLE_ANIM_RECT3 },
        .{ rect = SPARKLE_ANIM_RECT4 },
        .{ rect = SPARKLE_ANIM_RECT5 },
        .{ rect = SPARKLE_ANIM_RECT6 },
    ];
}

Level_Entrance :: struct {
    #as using base: Entity;

    level:              string;
    from_original_game: bool;

    solved:      bool;
    board_state: [] Tile; // If not empty, it is allocated in the same arena as the entity.
}

Area_Entrance :: struct {
    #as using base: Entity;

    target_area: string;

    // If 'texture' is empty, a default texture for the entity type is used.
    texture:      string;
    texture_rect: Rect;
}

Scroll :: struct {
    #as using base: Entity;

    pages:              [] string;
    page_frame_ranges:  [] Range;  // Either empty, or is a parallel array to 'pages'. If empty, page has no animation frames.

    frames:         [] Rect;
    frames_texture: string;
    frame_duration: f32 = 0.5;

    Range :: struct {
        start_index: s32; // Inclusive
        end_index:   s32; // Exclusive
    }

    PAGE_FRAME_DURATION :: 0.25;

    UNREAD_FX_DURATION     :: 0.5;
    UNREAD_FX_DELAY        :: 1.0;
    UNREAD_FX_REPEAT_DELAY :: 5.0;
    UNREAD_FX_ANIM_FRAMES  :: Effect_Frame.[
        .{ rect = SPARKLE_ANIM_RECT0, color = .{ 1, 1, 0.75, 1 } },
        .{ rect = SPARKLE_ANIM_RECT1, color = .{ 1, 1, 0.75, 1 } },
        .{ rect = SPARKLE_ANIM_RECT2, color = .{ 1, 1, 0.75, 1 } },
        .{ rect = SPARKLE_ANIM_RECT3, color = .{ 1, 1, 0.75, 1 } },
        .{ rect = SPARKLE_ANIM_RECT4, color = .{ 1, 1, 0.75, 1 } },
        .{ rect = SPARKLE_ANIM_RECT5, color = .{ 1, 1, 0.75, 1 } },
        .{ rect = SPARKLE_ANIM_RECT6, color = .{ 1, 1, 0.75, 1 } },
    ];

    unread := true;
    unread_fx_id: s64 = -1;
}

overworld_init :: (overworld: *Overworld) {
    // TODO(jt): #malloc @Memory Decide what arena these go in. For now this is malloc.
    array_reserve(*overworld.newly_solved_levels,  64);
    array_reserve(*overworld.areas,                64);
    array_reserve(*overworld.level_entrances,     256);
    array_reserve(*overworld.area_entrances,      256);
    array_reserve(*overworld.scrolls,             256);

    overworld.initted = true;
}

// TODO(jt): #array_reset @Cleanup Harmonize reset conventions with JAI once it itself harmonizes.
overworld_reset :: (overworld: *Overworld) {
    overworld.has_errors = false;
    overworld.needs_save = false;

    overworld.current_area_name = "";

    effects_reset(*overworld.effects);

    array_reset_keeping_memory(*overworld.newly_solved_levels);

    overworld.reading_scroll                    = null;
    overworld.reading_scroll_page               = 0;
    overworld.reading_scroll_backwards          = false;
    overworld.reading_scroll_time_spent_on_page = 0.0;

    array_reset_keeping_memory(*overworld.areas);

    array_reset_keeping_memory(*overworld.level_entrances);
    array_reset_keeping_memory(*overworld.area_entrances);
    array_reset_keeping_memory(*overworld.scrolls);
}

overworld_populate :: (overworld: *Overworld) {
    if !overworld.initted {
        overworld_init(overworld);
    }

    AREA_DEV_TESTS        :: "Tests";
    AREA_DEV_DRAFTS       :: "Drafts";
    AREA_DEV_MDP          :: "Mountain of Discarded Puzzles";
    AREA_FIRST_STEP       :: "First Step";
    AREA_SEEKING_LIGHT    :: "Seeking Light";
    AREA_GLADE            :: "Glade";
    AREA_PLAINS           :: "Plains";
    AREA_COAST            :: "Coast";
    AREA_PENINSULA        :: "Peninsula";
    AREA_FOREST           :: "Forest";
    AREA_ANCIENT_FOREST   :: "Ancient Forest";
    AREA_VALLEY           :: "Valley";
    AREA_MOUNTAINS        :: "Mountains";
    AREA_BOG              :: "Bog";
    AREA_DEEP_BOG         :: "Deep Bog";
    AREA_ASHLANDS         :: "Ashlands";
    AREA_CREDITS          :: "The End";

    r :: #bake_arguments make_tile_rect(size = TINY_DUNGEON_TILE_SIZE);

    SCREEN_HALF :: #run SCREEN_SIZE_IN_TILES / 2;
    EXIT_NORTH  :: #run r(SCREEN_HALF.x, 0) - Vector2.{ cast(f32, TINY_DUNGEON_TILE_SIZE.x) * 0.5, 0 };
    EXIT_SOUTH  :: #run r(SCREEN_HALF.x, SCREEN_SIZE_IN_TILES.y - 1) - Vector2.{ cast(f32, TINY_DUNGEON_TILE_SIZE.x) * 0.5, 0 };
    EXIT_EAST   :: #run r(SCREEN_SIZE_IN_TILES.x - 1, SCREEN_HALF.y);
    EXIT_WEST   :: #run r(0, SCREEN_HALF.y);

    array_add(*overworld.areas, .{ name = AREA_DEV_DRAFTS, size = .{ 11, 11 }, music = MUSIC_PLAINS, hint_flags = .ALL });
    array_add(*overworld.areas, .{ name = AREA_DEV_TESTS,  size = .{ 13, 11 }, music = MUSIC_PLAINS, hint_flags = .ALL });
    array_add(*overworld.areas, .{ name = AREA_DEV_MDP,    size = .{  9,  7 }, music = MUSIC_PLAINS, hint_flags = .ALL });

    // TODO(jt): @Design Is there a reasonable subset of hints to show during teaching sequences for
    // our new clues? We currently show all, because we want to assure the player the rules they
    // alreayd know have not chganged. If anything, we probably do want to display DEAD_ENDS, and
    // POOLS. If we display DEAD_ENDS, we should probably also display MONSTERS. We display
    // CONNECTIVITY, because what if the new clue messes with that somehow, etc. And if we show all
    // that, why would we leave out TREASURES explicitly... so in the end, we show all.

    array_add(*overworld.areas, .{ name = AREA_FIRST_STEP,     size = .{ 15,  7 }, music = MUSIC_PLAINS,    hint_flags = .ALL });
    array_add(*overworld.areas, .{ name = AREA_SEEKING_LIGHT,  size = .{ 11,  7 }, music = MUSIC_PLAINS,    hint_flags = .ALL });
    array_add(*overworld.areas, .{ name = AREA_GLADE,          size = .{  5,  5 }, music = MUSIC_PLAINS,    hint_flags = .ALL });
    array_add(*overworld.areas, .{ name = AREA_PLAINS,         size = .{  9,  5 }, music = MUSIC_PLAINS,    hint_flags = .NONE });
    array_add(*overworld.areas, .{ name = AREA_COAST,          size = .{ 17,  9 }, music = MUSIC_PLAINS,    hint_flags = .NONE });
    array_add(*overworld.areas, .{ name = AREA_PENINSULA,      size = .{ 17,  9 }, music = MUSIC_PLAINS,    hint_flags = .NONE });
    array_add(*overworld.areas, .{ name = AREA_FOREST,         size = .{ 11,  9 }, music = MUSIC_FOREST,    hint_flags = .NONE });
    array_add(*overworld.areas, .{ name = AREA_ANCIENT_FOREST, size = .{ 13,  7 }, music = MUSIC_FOREST,    hint_flags = .NONE });
    array_add(*overworld.areas, .{ name = AREA_VALLEY,         size = .{ 15, 11 }, music = MUSIC_MOUNTAINS, hint_flags = .ALL });
    array_add(*overworld.areas, .{ name = AREA_MOUNTAINS,      size = .{  9,  7 }, music = MUSIC_MOUNTAINS, hint_flags = .NONE });
    array_add(*overworld.areas, .{ name = AREA_BOG,            size = .{  9,  5 }, music = MUSIC_BOG,       hint_flags = .ALL });
    array_add(*overworld.areas, .{ name = AREA_DEEP_BOG,       size = .{  9,  7 }, music = MUSIC_BOG,       hint_flags = .NONE });
    array_add(*overworld.areas, .{ name = AREA_ASHLANDS,       size = .{ 13,  8 }, music = MUSIC_ASHLANDS,  hint_flags = .NONE });
    array_add(*overworld.areas, .{ name = AREA_CREDITS,        size = .{  6,  3 }, music = MUSIC_DESERT,    hint_flags = .NONE });

    //
    // Tests
    //
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_TESTS, rect = r(6,  3), level = "test005_empty" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_TESTS, rect = r(6,  5), level = "test001_traps" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_TESTS, rect = r(8,  5), level = "test002_traps" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_TESTS, rect = r(10, 5), level = "test003_traps" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_TESTS, rect = r(6,  7), level = "test006_crests" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_TESTS, rect = r(8,  7), level = "test007_crests_alt" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_TESTS, rect = r(10, 7), level = "test008_crests_triple" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_TESTS, rect = r(12, 7), level = "test009_crests_and_minotaurs" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_TESTS, rect = r(6,  9), level = "test013_10x10" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_TESTS, rect = r(8,  9), level = "test014_12x12" });

    array_add(*overworld.area_entrances, .{ area = AREA_DEV_TESTS, rect = EXIT_SOUTH, target_area = AREA_DEV_DRAFTS, texture = TEX_XP_ICONS, texture_rect = ARROW_DOWN_RECT });

    //
    // Drafts
    //
    array_add(*overworld.area_entrances, .{ area = AREA_DEV_DRAFTS, rect = EXIT_EAST,  target_area = AREA_GLADE,     texture = TEX_XP_ICONS, texture_rect = ARROW_RIGHT_RECT });
    array_add(*overworld.area_entrances, .{ area = AREA_DEV_DRAFTS, rect = EXIT_NORTH, target_area = AREA_DEV_TESTS, texture = TEX_XP_ICONS, texture_rect = ARROW_UP_RECT });
    array_add(*overworld.area_entrances, .{ area = AREA_DEV_DRAFTS, rect = EXIT_WEST,  target_area = AREA_DEV_MDP,   texture = TEX_XP_ICONS, texture_rect = ARROW_LEFT_RECT });

    //
    // Mountain of Discarded Puzzles (Mirror levels)
    //
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_MDP, rect = r(8,  5), level = "jt009_the_golden_mirage" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_MDP, rect = r(10, 5), level = "jt010_the_twin_archmages" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_MDP, rect = r(12, 5), level = "jt011_the_twin_archmages_rematch" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_MDP, rect = r(14, 5), level = "jt012_the_cycle_of_calamity" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_MDP, rect = r(8,  7), level = "jt013_the_guardian_of_the_twin_artifacts" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_MDP, rect = r(10, 7), level = "jt014_the_summoning_loop" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_MDP, rect = r(12, 7), level = "jt015_the_summoning_circuit" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_MDP, rect = r(14, 7), level = "jt016_the_dragon_hoards" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_MDP, rect = r(8,  9), level = "jt017_the_halls_of_greed" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEV_MDP, rect = r(10, 9), level = "jt018_bandits_den" });

    array_add(*overworld.area_entrances, .{ area = AREA_DEV_MDP, rect = EXIT_EAST, target_area = AREA_DEV_DRAFTS, texture = TEX_XP_ICONS, texture_rect = ARROW_RIGHT_RECT });

    //
    // First Step (teaching corridors and monsters)
    //
    FIRST_STEP_PREREQUISITES1 :: string.[
        "teaching001a_mysterious_cavelets",
        "teaching001b_mysterious_cavelets",
        "teaching001c_mysterious_cavelets",
    ];

    FIRST_STEP_PREREQUISITES2 :: string.[
        "teaching002_mysterious_cavelets",
        "teaching003_mysterious_cavelets",
    ];

    FIRST_STEP_PREREQUISITES3 :: string.[
        "teaching004_mysterious_cavelets",
        "teaching005_mysterious_cavelets",
    ];

    FIRST_STEP_PREREQUISITES4 :: string.[
        "teaching006_mysterious_cavelets",
        "teaching007a_mysterious_cavelets",
        "teaching007b_mysterious_cavelets",
        "teaching007c_mysterious_cavelets",
        "teaching007d_mysterious_cavelets",
    ];

    FIRST_STEP_PREREQUISITES5 :: string.[
        "teaching010a_mysterious_cavelets",
        "teaching010b_mysterious_cavelets",
        "teaching010c_mysterious_cavelets",
    ];

    FIRST_STEP_PREREQUISITES6 :: string.[
        "teaching008_mysterious_cavelets",
        "teaching009_mysterious_cavelets",
    ];

    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(7,  9), level = "teaching001a_mysterious_cavelets" });
    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(9,  9), level = "teaching001b_mysterious_cavelets" });
    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(11, 9), level = "teaching001c_mysterious_cavelets" });

    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(13, 9), level = "teaching002_mysterious_cavelets", unlocked_by_levels = FIRST_STEP_PREREQUISITES1 });
    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(15, 9), level = "teaching003_mysterious_cavelets", unlocked_by_levels = FIRST_STEP_PREREQUISITES1 });

    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(5,  7), level = "teaching004_mysterious_cavelets",  unlocked_by_levels = FIRST_STEP_PREREQUISITES2 });
    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(7,  7), level = "teaching005_mysterious_cavelets",  unlocked_by_levels = FIRST_STEP_PREREQUISITES2 });
    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(9,  7), level = "teaching006_mysterious_cavelets",  unlocked_by_levels = FIRST_STEP_PREREQUISITES3 });
    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(11, 7), level = "teaching007a_mysterious_cavelets", unlocked_by_levels = FIRST_STEP_PREREQUISITES3 });
    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(13, 7), level = "teaching007b_mysterious_cavelets", unlocked_by_levels = FIRST_STEP_PREREQUISITES3 });
    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(15, 7), level = "teaching007c_mysterious_cavelets", unlocked_by_levels = FIRST_STEP_PREREQUISITES3 });
    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(17, 7), level = "teaching007d_mysterious_cavelets", unlocked_by_levels = FIRST_STEP_PREREQUISITES3 });

    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(5,  5), level = "teaching010a_mysterious_cavelets", unlocked_by_levels = FIRST_STEP_PREREQUISITES4 });
    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(7,  5), level = "teaching010b_mysterious_cavelets", unlocked_by_levels = FIRST_STEP_PREREQUISITES4 });
    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(9,  5), level = "teaching010c_mysterious_cavelets", unlocked_by_levels = FIRST_STEP_PREREQUISITES4 });
    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(11, 5), level = "teaching008_mysterious_cavelets",  unlocked_by_levels = FIRST_STEP_PREREQUISITES5 });
    array_add(*overworld.level_entrances, .{ area = AREA_FIRST_STEP, rect = r(13, 5), level = "teaching009_mysterious_cavelets",  unlocked_by_levels = FIRST_STEP_PREREQUISITES5 });

    array_add(*overworld.scrolls, .{ area = AREA_FIRST_STEP, rect = r(5, 9), pages = .[SCROLL_TUTORIAL_1_NEW_1, SCROLL_TUTORIAL_1_NEW_2] });

    array_add(*overworld.area_entrances, .{ area = AREA_FIRST_STEP, rect = EXIT_NORTH, target_area = AREA_SEEKING_LIGHT, texture = TEX_XP_ICONS, texture_rect = ARROW_UP_RECT, unlocked_by_levels = FIRST_STEP_PREREQUISITES6 });

    //
    // Seeking Light (teaching treasures and numbers)
    //
    SEEKING_LIGHT_PREREQUISITES1 :: string.[
        "teaching011a_mysterious_caves",
        "teaching011b_mysterious_caves",
        "teaching011c_mysterious_caves",
        "teaching011d_mysterious_caves",
    ];

    SEEKING_LIGHT_PREREQUISITES2 :: string.[
        "teaching013_mysterious_caves",
        "teaching014_mysterious_caves",
        "teaching015_mysterious_caves",
    ];

    SEEKING_LIGHT_PREREQUISITES3 :: string.[
        "teaching021_mysterious_caverns",
        "teaching022_mysterious_caverns",
        "teaching023_mysterious_caverns",
        "teaching024_mysterious_caverns",
    ];

    array_add(*overworld.level_entrances, .{ area = AREA_SEEKING_LIGHT, rect = r(7,  9), level = "teaching011a_mysterious_caves" });
    array_add(*overworld.level_entrances, .{ area = AREA_SEEKING_LIGHT, rect = r(9,  9), level = "teaching011b_mysterious_caves" });
    array_add(*overworld.level_entrances, .{ area = AREA_SEEKING_LIGHT, rect = r(11, 9), level = "teaching011c_mysterious_caves" });
    array_add(*overworld.level_entrances, .{ area = AREA_SEEKING_LIGHT, rect = r(13, 9), level = "teaching011d_mysterious_caves" });

    array_add(*overworld.level_entrances, .{ area = AREA_SEEKING_LIGHT, rect = r(7,  7), level = "teaching013_mysterious_caves", unlocked_by_levels = SEEKING_LIGHT_PREREQUISITES1 });
    array_add(*overworld.level_entrances, .{ area = AREA_SEEKING_LIGHT, rect = r(9,  7), level = "teaching014_mysterious_caves", unlocked_by_levels = SEEKING_LIGHT_PREREQUISITES1 });
    array_add(*overworld.level_entrances, .{ area = AREA_SEEKING_LIGHT, rect = r(11, 7), level = "teaching015_mysterious_caves", unlocked_by_levels = SEEKING_LIGHT_PREREQUISITES1 });

    array_add(*overworld.level_entrances, .{ area = AREA_SEEKING_LIGHT, rect = r(7,  5), level = "teaching021_mysterious_caverns", unlocked_by_levels = SEEKING_LIGHT_PREREQUISITES2 });
    array_add(*overworld.level_entrances, .{ area = AREA_SEEKING_LIGHT, rect = r(9,  5), level = "teaching022_mysterious_caverns", unlocked_by_levels = SEEKING_LIGHT_PREREQUISITES2 });
    array_add(*overworld.level_entrances, .{ area = AREA_SEEKING_LIGHT, rect = r(11, 5), level = "teaching023_mysterious_caverns", unlocked_by_levels = SEEKING_LIGHT_PREREQUISITES2 });
    array_add(*overworld.level_entrances, .{ area = AREA_SEEKING_LIGHT, rect = r(13, 5), level = "teaching024_mysterious_caverns", unlocked_by_levels = SEEKING_LIGHT_PREREQUISITES2 });

    array_add(*overworld.area_entrances, .{ area = AREA_SEEKING_LIGHT, rect = EXIT_SOUTH, target_area = AREA_FIRST_STEP, texture = TEX_XP_ICONS, texture_rect = ARROW_DOWN_RECT });
    array_add(*overworld.area_entrances, .{ area = AREA_SEEKING_LIGHT, rect = EXIT_NORTH, target_area = AREA_GLADE,      texture = TEX_XP_ICONS, texture_rect = ARROW_UP_RECT, unlocked_by_levels = SEEKING_LIGHT_PREREQUISITES3 });

    //
    // Glade (area that tests the basics before letting the player move on)
    //
    array_add(*overworld.level_entrances, .{ area = AREA_GLADE, rect = r(10, 6), level = "jt004_city_watch_armory" });
    array_add(*overworld.level_entrances, .{ area = AREA_GLADE, rect = r(12, 6), level = "jt002_forgotten_trail" });
    array_add(*overworld.level_entrances, .{ area = AREA_GLADE, rect = r(10, 8), level = "jt027_the_house_of_lust" });
    array_add(*overworld.level_entrances, .{ area = AREA_GLADE, rect = r(12, 8), level = "jt028_the_sunken_temple" });

    // TODO(jt): @Cleanup What do we do about the original tutorial?
    //
    // array_add(*overworld.scrolls, .{
    //     area = AREA_GLADE,
    //     rect = r(12, 8),
    //     pages = .[
    //         SCROLL_TUTORIAL_1_1,
    //         SCROLL_TUTORIAL_1_2,
    //         SCROLL_TUTORIAL_1_3,
    //         SCROLL_TUTORIAL_1_4,
    //         SCROLL_TUTORIAL_1_5,
    //         SCROLL_TUTORIAL_1_6,
    //         SCROLL_TUTORIAL_1_7,
    //         SCROLL_TUTORIAL_1_8,
    //     ],
    //     page_frame_ranges = .[.{ 0, 1 }, .{ 0, 5 }, .{ 4, 10 }, .{ 9, 17 }, .{ 16, 20 }, .{ 19, 24 }, .{ 23, 26 }, .{ 25, 29 }],
    //     frames = TUTORIAL_ANIM_FRAMES,
    //     frames_texture = TEX_TUTORIAL,
    // });

    array_add(*overworld.area_entrances, .{ area = AREA_GLADE, rect = EXIT_SOUTH, target_area = AREA_SEEKING_LIGHT, texture = TEX_XP_ICONS, texture_rect = ARROW_DOWN_RECT });
    array_add(*overworld.area_entrances, .{ area = AREA_GLADE, rect = EXIT_EAST,  target_area = AREA_PLAINS,        texture = TEX_XP_ICONS, texture_rect = ARROW_RIGHT_RECT, unlocked_by_levels = .[
        "jt004_city_watch_armory",
        "jt002_forgotten_trail",
        "jt027_the_house_of_lust",
        "jt028_the_sunken_temple",
    ] });

    #if DEVELOPER {
        array_add(*overworld.area_entrances, .{ area = AREA_GLADE, rect = EXIT_WEST,  target_area = AREA_DEV_DRAFTS, texture = TEX_XP_ICONS, texture_rect = ARROW_LEFT_RECT });
    }

    //
    // Plains
    //
    array_add(*overworld.level_entrances, .{ area = AREA_PLAINS, rect = r(8,   6), level = "jt055_the_illusionists_cavity" });
    array_add(*overworld.level_entrances, .{ area = AREA_PLAINS, rect = r(10,  6), level = "jt029_the_flooded_tomb" });
    array_add(*overworld.level_entrances, .{ area = AREA_PLAINS, rect = r(12,  6), level = "jt039_the_temple_of_the_frogfolk" });
    array_add(*overworld.level_entrances, .{ area = AREA_PLAINS, rect = r(14,  6), level = "jt049_the_unholy_pilgrimage" });

    array_add(*overworld.level_entrances, .{ area = AREA_PLAINS, rect = r(8,   8), level = "jt037_the_clay_army" });
    array_add(*overworld.level_entrances, .{ area = AREA_PLAINS, rect = r(10,  8), level = "jt030_the_sanctum_guardians" });
    array_add(*overworld.level_entrances, .{ area = AREA_PLAINS, rect = r(12,  8), level = "jt035_the_lost_labyrinth_v3" });
    array_add(*overworld.level_entrances, .{ area = AREA_PLAINS, rect = r(14,  8), level = "jt042_the_hidden_vault" });

    array_add(*overworld.area_entrances, .{ area = AREA_PLAINS, rect = EXIT_WEST,  target_area = AREA_GLADE,  texture = TEX_XP_ICONS, texture_rect = ARROW_LEFT_RECT });
    array_add(*overworld.area_entrances, .{ area = AREA_PLAINS, rect = EXIT_EAST,  target_area = AREA_FOREST, texture = TEX_XP_ICONS, texture_rect = ARROW_RIGHT_RECT, unlocked_by_levels = .[
        "jt055_the_illusionists_cavity",
        "jt029_the_flooded_tomb",
        "jt039_the_temple_of_the_frogfolk",
        "jt049_the_unholy_pilgrimage",
        "jt037_the_clay_army",
        "jt030_the_sanctum_guardians",
        "jt035_the_lost_labyrinth_v3",
        "jt042_the_hidden_vault",
    ]});

    // Levels from Dungeons and Diagrams are disabled, because Zach doesn't think it is okay.
    #if ENABLE_LEVELS_FROM_DUNGEONS_AND_DIAGRAMS {
        array_add(*overworld.area_entrances, .{ area = AREA_PLAINS, rect = EXIT_SOUTH, target_area = AREA_COAST,  texture = TEX_XP_ICONS, texture_rect = ARROW_DOWN_RECT });
    }


    #if ENABLE_LEVELS_FROM_DUNGEONS_AND_DIAGRAMS {
        //
        // Coast
        //
        COAST_PREREQUISITES1 :: string.[
            "001_brightleaf_iron_mine",
            "002_the_secret_tunnels",
            "003_the_graveyard_of_the_vernal_king",
            "004_shifting_walls",
            "005_the_fetid_sewers",
            "006_the_dias_of_the_sun_god",
            "007_the_coronation_of_the_lich",
            "008_the_demon_marquis_of_lust",
        ];

        COAST_PREREQUISITES2 :: string.[
            "009_the_promenade",
            "010_the_bloodsoaked_den",
            "011_the_false_maze_of_the_minotaur",
            "012_the_phylactery_of_the_lich",
            "013_the_trials_of_the_anointed_one",
            "014_the_demon_count_of_gluttony",
            "015_the_winding_warren",
            "016_the_gleaming_sky-vaults",
        ];

        COAST_PREREQUISITES3 :: string.[
            "017_the_corridor_of_vise",
            "018_the_twin_cities_of_the_dead",
            "019_the_tainted_glade",
            "020_the_demon_duke_of_avarice",
            "021_the_altar_of_unkown_sacrifice",
            "022_old_saulksburgh_gold_vaults",
            "023_the_illusory_hoard",
            "024_the_skittering_gallery",
        ];

        COAST_PREREQUISITES4 :: string.[
            "025_the_thiefs_dilemma",
            "026_the_chapel_of_the_undying_martyr",
            "027_the_hungering_caverns",
            "028_the_cosmic_orrery",
            "029_the_house_penumbral",
            "030_the_demon_prince_of_wrath",
            "031_krogmars_last_stand",
            "032_the_catacombs_of_the_lichs_army",
        ];

        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(4,    4), from_original_game = true, level = "001_brightleaf_iron_mine" });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(6,    4), from_original_game = true, level = "002_the_secret_tunnels" });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(8,    4), from_original_game = true, level = "003_the_graveyard_of_the_vernal_king" });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(10,   4), from_original_game = true, level = "004_shifting_walls" });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(12,   4), from_original_game = true, level = "005_the_fetid_sewers" });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(14,   4), from_original_game = true, level = "006_the_dias_of_the_sun_god" });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(16,   4), from_original_game = true, level = "007_the_coronation_of_the_lich" });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(18,   4), from_original_game = true, level = "008_the_demon_marquis_of_lust" });

        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(4,    6), from_original_game = true, level = "009_the_promenade",                  unlocked_by_levels = COAST_PREREQUISITES1 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(6,    6), from_original_game = true, level = "010_the_bloodsoaked_den",            unlocked_by_levels = COAST_PREREQUISITES1 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(8,    6), from_original_game = true, level = "011_the_false_maze_of_the_minotaur", unlocked_by_levels = COAST_PREREQUISITES1 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(10,   6), from_original_game = true, level = "012_the_phylactery_of_the_lich",     unlocked_by_levels = COAST_PREREQUISITES1 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(12,   6), from_original_game = true, level = "013_the_trials_of_the_anointed_one", unlocked_by_levels = COAST_PREREQUISITES1 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(14,   6), from_original_game = true, level = "014_the_demon_count_of_gluttony",    unlocked_by_levels = COAST_PREREQUISITES1 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(16,   6), from_original_game = true, level = "015_the_winding_warren",             unlocked_by_levels = COAST_PREREQUISITES1 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(18,   6), from_original_game = true, level = "016_the_gleaming_sky-vaults",        unlocked_by_levels = COAST_PREREQUISITES1 });

        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(4,    8), from_original_game = true, level = "017_the_corridor_of_vise",          unlocked_by_levels = COAST_PREREQUISITES2 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(6,    8), from_original_game = true, level = "018_the_twin_cities_of_the_dead",   unlocked_by_levels = COAST_PREREQUISITES2 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(8,    8), from_original_game = true, level = "019_the_tainted_glade",             unlocked_by_levels = COAST_PREREQUISITES2 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(10,   8), from_original_game = true, level = "020_the_demon_duke_of_avarice",     unlocked_by_levels = COAST_PREREQUISITES2 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(12,   8), from_original_game = true, level = "021_the_altar_of_unkown_sacrifice", unlocked_by_levels = COAST_PREREQUISITES2 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(14,   8), from_original_game = true, level = "022_old_saulksburgh_gold_vaults",   unlocked_by_levels = COAST_PREREQUISITES2 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(16,   8), from_original_game = true, level = "023_the_illusory_hoard",            unlocked_by_levels = COAST_PREREQUISITES2 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(18,   8), from_original_game = true, level = "024_the_skittering_gallery",        unlocked_by_levels = COAST_PREREQUISITES2 });

        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(4,   10), from_original_game = true, level = "025_the_thiefs_dilemma",               unlocked_by_levels = COAST_PREREQUISITES3 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(6,   10), from_original_game = true, level = "026_the_chapel_of_the_undying_martyr", unlocked_by_levels = COAST_PREREQUISITES3 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(8,   10), from_original_game = true, level = "027_the_hungering_caverns",            unlocked_by_levels = COAST_PREREQUISITES3 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(10,  10), from_original_game = true, level = "028_the_cosmic_orrery",                unlocked_by_levels = COAST_PREREQUISITES3 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(12,  10), from_original_game = true, level = "029_the_house_penumbral",              unlocked_by_levels = COAST_PREREQUISITES3 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(14,  10), from_original_game = true, level = "030_the_demon_prince_of_wrath",        unlocked_by_levels = COAST_PREREQUISITES3 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(16,  10), from_original_game = true, level = "031_krogmars_last_stand",              unlocked_by_levels = COAST_PREREQUISITES3 });
        array_add(*overworld.level_entrances, .{ area = AREA_COAST, rect = r(18,  10), from_original_game = true, level = "032_the_catacombs_of_the_lichs_army",  unlocked_by_levels = COAST_PREREQUISITES3 });

        array_add(*overworld.area_entrances, .{ area = AREA_COAST, rect = EXIT_NORTH, target_area = AREA_PLAINS,    texture = TEX_XP_ICONS, texture_rect = ARROW_UP_RECT });
        array_add(*overworld.area_entrances, .{ area = AREA_COAST, rect = EXIT_SOUTH, target_area = AREA_PENINSULA, texture = TEX_XP_ICONS, texture_rect = ARROW_DOWN_RECT, unlocked_by_levels = COAST_PREREQUISITES4 });

        //
        // Peninsula
        //

        PENINSULA_PREREQUISITES1 :: string.[
            "033_wardens_of_the_uncaged_chaos",
            "034_the_eye_of_the_minotaur",
            "035_the_corroded_corridors",
            "036_the_triumvirate_of_the_planar_keep",
            "037_the_halls_of_the_golemancer",
            "038_the_glacial_nest",
            "039_fort_impenetrable",
            "040_the_artificers_museum",
        ];

        PENINSULA_PREREQUISITES2 :: string.[
            "041_beneath_the_haunted_woods",
            "042_the_scoured_halls",
            "043_the_tomb_of_the_summer_king",
            "044_the_living_reliquary",
            "045_the_twisting_descent",
            "046_the_edge_of_the_endless_swarm",
            "047_the_ascension_of_the_archlich",
            "048_the_tomb_of_the_broken_god",
        ];

        PENINSULA_PREREQUISITES3 :: string.[
            "049_the_ashen_remnant",
            "050_the_tomb_of_the_autumn_king",
            "051_the_oblivion_hoard",
            "052_the_minotaurs_pursuit",
            "053_the_engine_of_the_golemancer",
            "054_the_hive_of_great_sorrow",
            "055_the_masters_of_the_astral_voyager",
            "056_the_barrow_of_the_winter_king",
        ];

        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(4,   4), from_original_game = true, level = "033_wardens_of_the_uncaged_chaos" });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(6,   4), from_original_game = true, level = "034_the_eye_of_the_minotaur" });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(8,   4), from_original_game = true, level = "035_the_corroded_corridors" });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(10,  4), from_original_game = true, level = "036_the_triumvirate_of_the_planar_keep" });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(12,  4), from_original_game = true, level = "037_the_halls_of_the_golemancer" });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(14,  4), from_original_game = true, level = "038_the_glacial_nest" });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(16,  4), from_original_game = true, level = "039_fort_impenetrable" });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(18,  4), from_original_game = true, level = "040_the_artificers_museum" });

        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(4,   6), from_original_game = true, level = "041_beneath_the_haunted_woods",     unlocked_by_levels = PENINSULA_PREREQUISITES1 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(6,   6), from_original_game = true, level = "042_the_scoured_halls",             unlocked_by_levels = PENINSULA_PREREQUISITES1 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(8,   6), from_original_game = true, level = "043_the_tomb_of_the_summer_king",   unlocked_by_levels = PENINSULA_PREREQUISITES1 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(10,  6), from_original_game = true, level = "044_the_living_reliquary",          unlocked_by_levels = PENINSULA_PREREQUISITES1 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(12,  6), from_original_game = true, level = "045_the_twisting_descent",          unlocked_by_levels = PENINSULA_PREREQUISITES1 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(14,  6), from_original_game = true, level = "046_the_edge_of_the_endless_swarm", unlocked_by_levels = PENINSULA_PREREQUISITES1 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(16,  6), from_original_game = true, level = "047_the_ascension_of_the_archlich", unlocked_by_levels = PENINSULA_PREREQUISITES1 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(18,  6), from_original_game = true, level = "048_the_tomb_of_the_broken_god",    unlocked_by_levels = PENINSULA_PREREQUISITES1 });

        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(4,   8), from_original_game = true, level = "049_the_ashen_remnant",                 unlocked_by_levels = PENINSULA_PREREQUISITES2 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(6,   8), from_original_game = true, level = "050_the_tomb_of_the_autumn_king",       unlocked_by_levels = PENINSULA_PREREQUISITES2 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(8,   8), from_original_game = true, level = "051_the_oblivion_hoard",                unlocked_by_levels = PENINSULA_PREREQUISITES2 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(10,  8), from_original_game = true, level = "052_the_minotaurs_pursuit",             unlocked_by_levels = PENINSULA_PREREQUISITES2 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(12,  8), from_original_game = true, level = "053_the_engine_of_the_golemancer",      unlocked_by_levels = PENINSULA_PREREQUISITES2 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(14,  8), from_original_game = true, level = "054_the_hive_of_great_sorrow",          unlocked_by_levels = PENINSULA_PREREQUISITES2 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(16,  8), from_original_game = true, level = "055_the_masters_of_the_astral_voyager", unlocked_by_levels = PENINSULA_PREREQUISITES2 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(18,  8), from_original_game = true, level = "056_the_barrow_of_the_winter_king",     unlocked_by_levels = PENINSULA_PREREQUISITES2 });

        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(6,  10), from_original_game = true, level = "057_the_demon_king_of_vainglory",    unlocked_by_levels = PENINSULA_PREREQUISITES3 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(8,  10), from_original_game = true, level = "058_the_water_temple",               unlocked_by_levels = PENINSULA_PREREQUISITES3 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(10, 10), from_original_game = true, level = "059_the_counil_of_unmaking",         unlocked_by_levels = PENINSULA_PREREQUISITES3 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(12, 10), from_original_game = true, level = "060_ickbogs_grave_mistake",          unlocked_by_levels = PENINSULA_PREREQUISITES3 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(14, 10), from_original_game = true, level = "061_tenaxxuss_gullet",               unlocked_by_levels = PENINSULA_PREREQUISITES3 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(16, 10), from_original_game = true, level = "062_the_undertower_of_the_archlich", unlocked_by_levels = PENINSULA_PREREQUISITES3 });
        array_add(*overworld.level_entrances, .{ area = AREA_PENINSULA, rect = r(18, 10), from_original_game = true, level = "063_the_true_maze_of_the_minotaur",  unlocked_by_levels = PENINSULA_PREREQUISITES3 });

        array_add(*overworld.scrolls, .{ area = AREA_PENINSULA, rect = r(4, 10), pages = .[SCROLL_INFINITE_DUNGEON], unlocked_by_levels = PENINSULA_PREREQUISITES3 });

        array_add(*overworld.area_entrances, .{ area = AREA_PENINSULA, rect = EXIT_NORTH, target_area = AREA_COAST, texture = TEX_XP_ICONS, texture_rect = ARROW_UP_RECT });

    }

    //
    // Forest (Additional vanilla levels)
    //
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(7,   4), level = "jt031_the_west_sewers_complex" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(9,   4), level = "jt032_the_maze_of_many_perils" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(11,  4), level = "jt033_the_lost_labyrinth" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(13,  4), level = "jt034_the_lost_labyrinth_v2" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(15,  4), level = "jt019_the_tomb_without_spikes" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(7,   6), level = "jt036_the_secret_cave" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(9,   6), level = "jt038_the_buried_monarchs" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(11,  6), level = "jt040_the_temple_of_the_snake" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(13,  6), level = "jt041_the_overrun_mines" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(15,  6), level = "jt020_the_crossroads" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(7,   8), level = "jt001_temple_of_decaying_symmetry" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(9,   8), level = "jt005_temple_of_the_sun_god" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(11,  8), level = "jt021_the_vaults_of_order" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(13,  8), level = "jt023_the_branching_dungeon" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(15,  8), level = "jt026_the_walk_of_penance" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(7,  10), level = "jt043_the_lair_of_the_shadow_guardian" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(9,  10), level = "jt045_the_antechamber" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(11, 10), level = "jt052_the_rift" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(13, 10), level = "jt053_the_godstone" });
    array_add(*overworld.level_entrances, .{ area = AREA_FOREST, rect = r(15, 10), level = "jt054_the_stronghold_of_the_false_king" });

    array_add(*overworld.area_entrances, .{ area = AREA_FOREST, rect = EXIT_NORTH, target_area = AREA_BOG,            texture = TEX_XP_ICONS, texture_rect = ARROW_UP_RECT });
    array_add(*overworld.area_entrances, .{ area = AREA_FOREST, rect = EXIT_SOUTH, target_area = AREA_ANCIENT_FOREST, texture = TEX_XP_ICONS, texture_rect = ARROW_DOWN_RECT });
    array_add(*overworld.area_entrances, .{ area = AREA_FOREST, rect = EXIT_EAST,  target_area = AREA_VALLEY,         texture = TEX_XP_ICONS, texture_rect = ARROW_RIGHT_RECT });
    array_add(*overworld.area_entrances, .{ area = AREA_FOREST, rect = EXIT_WEST,  target_area = AREA_PLAINS,         texture = TEX_XP_ICONS, texture_rect = ARROW_LEFT_RECT });

    //
    // Ancient Forest (Knowledge gates to endgame)
    //
    // TODO(jt): Add crest knowledge gates.
    array_add(*overworld.level_entrances, .{ area = AREA_ANCIENT_FOREST, rect = r(10, 5), level = "jt048_the_false_gate" });
    array_add(*overworld.level_entrances, .{ area = AREA_ANCIENT_FOREST, rect = r(12, 5), level = "jt022_the_inner_sanctum" });

    array_add(*overworld.level_entrances, .{ area = AREA_ANCIENT_FOREST, rect = r(9,  7), level = "jt068_the_geometers_castle" });
    array_add(*overworld.level_entrances, .{ area = AREA_ANCIENT_FOREST, rect = r(13, 7), level = "jt069_the_ripples_of_peril" });

    array_add(*overworld.level_entrances, .{ area = AREA_ANCIENT_FOREST, rect = r(10, 9), level = "jt065_the_true_ring_of_the_geometer" });
    array_add(*overworld.level_entrances, .{ area = AREA_ANCIENT_FOREST, rect = r(12, 9), level = "jt067_the_narrow_path" });

    array_add(*overworld.scrolls, .{ area = AREA_ANCIENT_FOREST, rect = r(16, 9), pages = .[SCROLL_FOREST_HINT] });

    array_add(*overworld.area_entrances, .{ area = AREA_ANCIENT_FOREST, rect = EXIT_NORTH, target_area = AREA_FOREST,   texture = TEX_XP_ICONS, texture_rect = ARROW_UP_RECT  });
    array_add(*overworld.area_entrances, .{ area = AREA_ANCIENT_FOREST, rect = r(11, 7),   target_area = AREA_ASHLANDS, unlocked_by_levels = .[
        "jt048_the_false_gate",
        "jt022_the_inner_sanctum",
        "jt068_the_geometers_castle",
        "jt069_the_ripples_of_peril",
        "jt065_the_true_ring_of_the_geometer",
        "jt067_the_narrow_path",
    ] });

    //
    // Valley (Tutorial crests levels)
    //
    VALLEY_PREREQUISITES1 :: string.[
        "teachingcrests002_valley_trail",
        "teachingcrests034_valley_trail",
    ];

    VALLEY_PREREQUISITES2 :: string.[
        "teachingcrests009_valley_trail",
        "teachingcrests035_valley_trail",
    ];

    VALLEY_PREREQUISITES3 :: string.[
        "teachingcrests036_valley_trail",
        "teachingcrests037_valley_trail",
    ];

    VALLEY_PREREQUISITES4 :: string.[
        "teachingcrests004_valley_trail",
        "teachingcrests011_valley_trail",
    ];

    VALLEY_PREREQUISITES5 :: string.[
        "teachingcrests017_valley_trail",
        "teachingcrests027_valley_trail",
        "teachingcrests018_valley_trail",
        "teachingcrests028_valley_trail",
    ];

    VALLEY_PREREQUISITES6 :: string.[
        "teachingcrests020_valley_trail",
        "teachingcrests021_valley_trail",
        "teachingcrests033_valley_trail",
    ];

    VALLEY_PREREQUISITES7 :: string.[
        "teachingcrests030_valley_trail",
        "teachingcrests029_valley_trail",
    ];

    VALLEY_PREREQUISITES8 :: string.[
        "teachingcrests032_valley_trail",
        "teachingcrests031_valley_trail",
    ];

    VALLEY_PREREQUISITES9 :: string.[
        "teachingcrests024_valley_trail",
        "teachingcrests026_valley_trials",
    ];

    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(5,  3), level = "teachingcrests002_valley_trail" });
    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(5,  5), level = "teachingcrests034_valley_trail" });

    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(7,  3), level = "teachingcrests035_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES1 });
    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(7,  5), level = "teachingcrests009_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES1 });

    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(9, 3), level = "teachingcrests036_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES2 });
    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(9, 5), level = "teachingcrests037_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES2 });

    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(11, 3), level = "teachingcrests004_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES3 });
    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(11, 5), level = "teachingcrests011_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES3 });

    // TODO(jt): @Design This is for sure the weakest puzzle of this section.
    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(15, 3), level = "teachingcrests017_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES4 });
    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(17, 3), level = "teachingcrests027_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES4 });
    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(15, 5), level = "teachingcrests018_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES4 });
    // TODO(jt): @Design This puzzle might be too hard to be in the tutorial. Consider moving to mountains
    // and creating an easier testing puzzle for the tutorial.
    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(17, 5), level = "teachingcrests028_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES4 });

    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(5,   9), level = "teachingcrests020_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES5 });
    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(5,  11), level = "teachingcrests021_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES5 });
    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(7,   9), level = "teachingcrests033_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES5 });

    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(9,   9), level = "teachingcrests030_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES6 });
    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(9,  11), level = "teachingcrests029_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES6 });

    // TODO(jt): @Design 32 is is a good level, but mayube a little too hard here? Consider a pair of levels with supressed numbers before 32 and 31?
    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(11,  9), level = "teachingcrests032_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES7 });
    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(11, 11), level = "teachingcrests031_valley_trail", unlocked_by_levels = VALLEY_PREREQUISITES7 });

    // TODO(jt): @Playtest @Design This sub-section is missing single-double, and perhaps also single-single interaction (+2)
    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(15, 10), level = "teachingcrests024_valley_trail",  unlocked_by_levels = VALLEY_PREREQUISITES8 });
    array_add(*overworld.level_entrances, .{ area = AREA_VALLEY, rect = r(17, 10), level = "teachingcrests026_valley_trials", unlocked_by_levels = VALLEY_PREREQUISITES8 });

    array_add(*overworld.area_entrances, .{ area = AREA_VALLEY, rect = EXIT_WEST, target_area = AREA_FOREST,    texture = TEX_XP_ICONS, texture_rect = ARROW_LEFT_RECT });
    array_add(*overworld.area_entrances, .{ area = AREA_VALLEY, rect = EXIT_EAST, target_area = AREA_MOUNTAINS, texture = TEX_XP_ICONS, texture_rect = ARROW_RIGHT_RECT, unlocked_by_levels = VALLEY_PREREQUISITES9 });

    //
    // Mountains (Assuming crest levels)
    //
    array_add(*overworld.level_entrances, .{ area = AREA_MOUNTAINS, rect = r(8,  5), level = "jt056_the_grand_veziers_dilemma" });
    array_add(*overworld.level_entrances, .{ area = AREA_MOUNTAINS, rect = r(10, 5), level = "jt062_leyline_ritual" });
    array_add(*overworld.level_entrances, .{ area = AREA_MOUNTAINS, rect = r(12, 5), level = "jt059_the_winding_catacombs" });
    array_add(*overworld.level_entrances, .{ area = AREA_MOUNTAINS, rect = r(14, 5), level = "jt060" });
    array_add(*overworld.level_entrances, .{ area = AREA_MOUNTAINS, rect = r(8,  7), level = "jt061_the_pale_lines" });
    array_add(*overworld.level_entrances, .{ area = AREA_MOUNTAINS, rect = r(10, 7), level = "jt064_the_geometers_shield" });
    array_add(*overworld.level_entrances, .{ area = AREA_MOUNTAINS, rect = r(12, 7), level = "jt066_the_new_threads_of_the_geometer" });


    array_add(*overworld.scrolls, .{
        area = AREA_MOUNTAINS,
        rect = r(10, 9),
        pages = .[SCROLL_SECRETS_LEARNED],
        unlocked_by_levels = .[
            "jt056_the_grand_veziers_dilemma",
            "jt062_leyline_ritual",
            "jt059_the_winding_catacombs",
            "jt060",
            "jt061_the_pale_lines",
            "jt064_the_geometers_shield",
            "jt066_the_new_threads_of_the_geometer",
        ],
    });

    array_add(*overworld.area_entrances, .{ area = AREA_MOUNTAINS, rect = EXIT_WEST, target_area = AREA_VALLEY, texture = TEX_XP_ICONS, texture_rect = ARROW_LEFT_RECT });

    //
    // Bog (Tutorial trap levels)
    //
    BOG_PREREQUISITES1 :: string.[
        "teachingtraps001_the_tomb_of_many_spikes",
        "teachingtraps002_the_tomb_of_many_spikes",
        "teachingtraps003_the_tomb_of_many_spikes",
        "teachingtraps004_the_tomb_of_many_spikes",
    ];

    BOG_PREREQUISITES2 :: string.[
        "teachingtraps005_the_tomb_of_many_spikes",
        "teachingtraps006_the_tomb_of_many_spikes",
    ];

    array_add(*overworld.level_entrances, .{ area = AREA_BOG, rect = r(8,  8), level = "teachingtraps001_the_tomb_of_many_spikes" });
    array_add(*overworld.level_entrances, .{ area = AREA_BOG, rect = r(10, 8), level = "teachingtraps002_the_tomb_of_many_spikes" });
    array_add(*overworld.level_entrances, .{ area = AREA_BOG, rect = r(12, 8), level = "teachingtraps003_the_tomb_of_many_spikes" });
    array_add(*overworld.level_entrances, .{ area = AREA_BOG, rect = r(14, 8), level = "teachingtraps004_the_tomb_of_many_spikes" });

    array_add(*overworld.level_entrances, .{ area = AREA_BOG, rect = r(8,  6), level = "teachingtraps005_the_tomb_of_many_spikes", unlocked_by_levels = BOG_PREREQUISITES1 });
    array_add(*overworld.level_entrances, .{ area = AREA_BOG, rect = r(10, 6), level = "teachingtraps006_the_tomb_of_many_spikes", unlocked_by_levels = BOG_PREREQUISITES1 });

    array_add(*overworld.area_entrances, .{ area = AREA_BOG, rect = EXIT_NORTH, target_area = AREA_DEEP_BOG, texture = TEX_XP_ICONS, texture_rect = ARROW_UP_RECT, unlocked_by_levels = BOG_PREREQUISITES2 });
    array_add(*overworld.area_entrances, .{ area = AREA_BOG, rect = EXIT_SOUTH, target_area = AREA_FOREST,   texture = TEX_XP_ICONS, texture_rect = ARROW_DOWN_RECT });

    //
    // Deep Bog (Assuming Trap levels)
    //
    array_add(*overworld.level_entrances, .{ area = AREA_DEEP_BOG, rect = r(8,  5), level = "jt050_spontaneous_symmetry_breaking" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEEP_BOG, rect = r(10, 5), level = "jt024_treasury_of_the_underking" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEEP_BOG, rect = r(12, 5), level = "jt025_the_architects_gambit" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEEP_BOG, rect = r(14, 5), level = "jt044_the_lair_of_the_cornered_beast" });

    array_add(*overworld.level_entrances, .{ area = AREA_DEEP_BOG, rect = r(8,  7), level = "jt003_the_archmages_vault" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEEP_BOG, rect = r(10, 7), level = "jt006_twisting_halls" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEEP_BOG, rect = r(12, 7), level = "jt046_the_hollow_tomb" });
    array_add(*overworld.level_entrances, .{ area = AREA_DEEP_BOG, rect = r(14, 7), level = "jt047_the_cursed_garrison" });

    array_add(*overworld.level_entrances, .{ area = AREA_DEEP_BOG, rect = r(8,  9), level = "jt051_the_impostor_beast" });


    array_add(*overworld.scrolls, .{
        area = AREA_DEEP_BOG,
        rect = r(14, 9),
        pages = .[SCROLL_SECRETS_LEARNED],
        unlocked_by_levels = .[
            "jt050_spontaneous_symmetry_breaking",
            "jt024_treasury_of_the_underking",
            "jt025_the_architects_gambit",
            "jt044_the_lair_of_the_cornered_beast",
            "jt003_the_archmages_vault",
            "jt006_twisting_halls",
            "jt046_the_hollow_tomb",
            "jt047_the_cursed_garrison",
            "jt051_the_impostor_beast",
        ],
    });

    array_add(*overworld.area_entrances, .{ area = AREA_DEEP_BOG, rect = EXIT_SOUTH, target_area = AREA_BOG, texture = TEX_XP_ICONS, texture_rect = ARROW_DOWN_RECT });


    //
    // Ashlands (Endgame)
    //
    // TODO(jt): @Design Some of these are 9x9 and some are 10x10. Think about changing all to
    // 10x10, because 9x9s are a little too unrecognizable from 8x8, and it leads to unnecessary
    // confusion.

    array_add(*overworld.level_entrances, .{ area = AREA_ASHLANDS, rect = r(12, 4), level = "endgame001_the_cathedral_of_preserved_heroes" });

    array_add(*overworld.level_entrances, .{ area = AREA_ASHLANDS, rect = r( 6, 7), level = "endgame002_the_consult" });
    array_add(*overworld.level_entrances, .{ area = AREA_ASHLANDS, rect = r( 8, 7), level = "endgame004_fortress_of_the_lost" });
    array_add(*overworld.level_entrances, .{ area = AREA_ASHLANDS, rect = r(10, 7), level = "endgame010_the_lost_vaults" });
    array_add(*overworld.level_entrances, .{ area = AREA_ASHLANDS, rect = r(12, 7), level = "endgame012_the_descent" });
    array_add(*overworld.level_entrances, .{ area = AREA_ASHLANDS, rect = r(14, 7), level = "endgame011_the_sealed_warren" });
    array_add(*overworld.level_entrances, .{ area = AREA_ASHLANDS, rect = r(16, 7), level = "endgame013_the_gnostic_court" });

    array_add(*overworld.level_entrances, .{ area = AREA_ASHLANDS, rect = r( 8, 9), level = "endgame007_the_light_bending_coffers" });
    array_add(*overworld.level_entrances, .{ area = AREA_ASHLANDS, rect = r(11, 9), level = "endgame008_the_world_tree" });
    array_add(*overworld.level_entrances, .{ area = AREA_ASHLANDS, rect = r(14, 9), level = "endgame009_the_decaying_roots" });

    array_add(*overworld.area_entrances, .{ area = AREA_ASHLANDS, rect = r(10, 4),   target_area = AREA_ANCIENT_FOREST, unlocked_by_levels = .["endgame001_the_cathedral_of_preserved_heroes"]});
    array_add(*overworld.area_entrances, .{ area = AREA_ASHLANDS, rect = EXIT_SOUTH, target_area = AREA_CREDITS,        texture = TEX_XP_ICONS, texture_rect = ARROW_DOWN_RECT, unlocked_by_levels = .[
        "endgame001_the_cathedral_of_preserved_heroes",
        "endgame002_the_consult",
        "endgame004_fortress_of_the_lost",
        "endgame010_the_lost_vaults",
        "endgame012_the_descent",
        "endgame011_the_sealed_warren",
        "endgame013_the_gnostic_court",
        "endgame007_the_light_bending_coffers",
        "endgame008_the_world_tree",
        "endgame009_the_decaying_roots",
    ] });

    //
    // Credits
    //
    // TODO(jt): @Design Add treasure into this room! (Prop entity.)
    array_add(*overworld.scrolls, .{ area = AREA_CREDITS, rect = r(11, 7), pages = .[SCROLL_THE_END] });
    array_add(*overworld.scrolls, .{ area = AREA_CREDITS, rect = r(13, 7), pages = .[SCROLL_CREDITS_1, SCROLL_CREDITS_2, SCROLL_CREDITS_3, SCROLL_CREDITS_4, SCROLL_CREDITS_5, SCROLL_CREDITS_6, SCROLL_CREDITS_7, SCROLL_CREDITS_8, SCROLL_CREDITS_9, SCROLL_CREDITS_10] });

    array_add(*overworld.area_entrances, .{ area = AREA_CREDITS, rect = EXIT_NORTH, target_area = AREA_ASHLANDS, texture = TEX_XP_ICONS, texture_rect = ARROW_UP_RECT });

    overworld.current_area_name = AREA_FIRST_STEP;
}

overworld_save_level_state :: (overworld: *Overworld, level: string, solved: bool, board_state: [] Tile) {
    for * overworld.level_entrances {
        if it.level == level {
            if !it.board_state.count {
                // TODO(jt): #malloc @Memory Put this into overworld arena. Currently allocated by malloc.
                it.board_state = NewArray(board_state.count, Tile, false);
            }

            array_view_copy(it.board_state, board_state, assert_exact_size = true);

            if solved && !it.solved {
                it.solved = true;
                array_add(*overworld.newly_solved_levels, level);
            }

            overworld.needs_save = true;

            // Do not break, because if we placed the same level multiple times (which we
            // shouldn't have?) at least we mark them all?
        }
    }
}

//
// Note on serialization:
//
// If we had an editor and were producing overworld areas there, everything would be an entity, and
// a lot of fields would be serialized. However, at the moment we are building the overworld in
// overworld_populate, and there is only really a few pieces of state we do need to serialize:
//
// - Whether a level is solved (unlocks are automatically recomputed from that).
// - Whether a level is edited, and what is in it
// - Whether a scroll is read.
//
// TODO(jt): The serialization is so trashy that it serializes it_index. Serialize an ID!
//
// TODO(jt): @Cleanup Make this a simple binary format.
OVERWORLD_SERIALIZATION_VERSION :: 3;

overworld_serialize_state :: (overworld: Overworld) -> string {
    b: String_Builder;
    b.allocator = temp;

    print(*b, "%\n", OVERWORLD_SERIALIZATION_VERSION);

    print(*b, "area %\n", overworld.current_area_name);

    for overworld.level_entrances {
        if it.solved || it.board_state.count {
            print(*b, "level % % ", it_index, it.solved);
            for it.board_state {
                tile_print(*b, it);
            }
            print(*b, "\n");
        }
    }

    for overworld.scrolls {
        if !it.unread {
            print(*b, "scroll %\n", it_index);
        }
    }

    return builder_to_string(*b,, context.allocator);
}

overworld_deserialize_state :: (overworld: *Overworld, _s: string) -> bool {
    if !overworld.initted {
        overworld_init(overworld);
    }

    s := _s;

    version: s64;
    success: bool;

    version, success, s = string_to_int(s);
    if !success {
        return false;
    }

    if version != OVERWORLD_SERIALIZATION_VERSION {
        return false;
    }

    transition_to_area: string;

    while s.count {
        s = eat_spaces_and_newlines(s);

        if String.starts_with(s, "area") {
            s = advance(s, 4);
            s = eat_spaces(s);

            end := 0;
            while end < s.count && s[end] != #char "\n" {
                end += 1;
            }

            if end > 0 {
                area_name := String.slice(s, 0, end);
                // TODO(jt): #malloc @Memory Put this into the overworld arena.
                transition_to_area = copy_string(area_name);
            }

            s = advance(s, end);
        } else if String.starts_with(s, "level") {
            s = advance(s, 5);
            s = eat_spaces(s);

            level_index: s64;
            level_index, success, s = string_to_int(s);
            if !success {
                return false;
            }

            s = eat_spaces(s);

            // TODO(jt): @Cleanup Fortunately this ugly boolean parsing will go away once do a binary format.
            level_solved     := String.starts_with(s, "true");
            level_not_solved := String.starts_with(s, "false");

            if level_solved {
                s = advance(s, 4);
            } else if level_not_solved {
                s = advance(s, 5);
            }

            if !level_solved && !level_not_solved {
                return false;
            }

            s = eat_spaces(s);

            level_board_state: [] Tile;
            {
                end := 0;
                while end < s.count && s[end] != #char "\n" {
                    end += 1;
                }

                if end > 0 {
                    board_state_string := String.slice(s, 0, end);

                    // TODO(jt): #malloc @Memory Put this into the overworld arena.
                    level_board_state = NewArray(board_state_string.count, Tile, false);
                    for board_state_string {
                        tile: Tile;
                        success, tile = tile_parse(it);
                        if !success {
                            return false;
                        }

                        level_board_state[it_index] = tile;
                    }
                }

                s = advance(s, end);
            }

            overworld.level_entrances[level_index].solved = level_solved;
            overworld.level_entrances[level_index].board_state = level_board_state;


        } else if String.starts_with(s, "scroll") {
            s = advance(s, 6);
            s = eat_spaces(s);

            scroll_index: s64;
            scroll_index, success, s = string_to_int(s);
            if !success {
                return false;
            }

            overworld.scrolls[scroll_index].unread = false;
        } else if s.count {
            // If we didn't handle the line, but there is something to handle, just give up!
            return false;
        }
    }

    if transition_to_area {
        handle_area_change(overworld, transition_to_area);
    }

    return true;
}

overworld_update_and_render :: (overworld: *Overworld, platform: Platform, input: Input, input_state: Input_State, audio: *Audio, gui: *Gui, render_lists: *Render_Lists) -> Game_Transition {
    if !overworld.initted {
        overworld_init(overworld);
    }

    transition: Game_Transition;

    dtime := cast(f32, to_float64_seconds(input.dtime));

    // TODO(jt): @Cleanup @Speed Get viewport as a parameter.
    viewport := viewport_for_scene(SCREEN_SIZE_IN_TILES, TINY_DUNGEON_TILE_SIZE, input.window_size);
    viewport_transform_position :: (position: Vector2) -> Vector2 #expand {
        return viewport_transform_position(viewport, position);
    }
    viewport_transform_rect :: (r: Rect) -> Rect #expand {
        return viewport_transform_rect(viewport, r);
    }

    area := get_current_area(overworld);

    transition_to_area: string;

    area_level_name_to_level_entrance: Table(string, *Level_Entrance);
    area_level_name_to_level_entrance.allocator = temp;
    for * overworld.level_entrances {
        if it.area == area.name {
            table_add(*area_level_name_to_level_entrance, it.level, it);
        }
    }

    //
    // Update
    //

    {
        level_solved_in_this_area := false;

        while overworld.newly_solved_levels.count {
            solved_level := pop(*overworld.newly_solved_levels);

            // If !found, the level is on another screen, and we don't want to play effects anyway.
            found, found_level_entrance := table_find(*area_level_name_to_level_entrance, solved_level);
            if found {
                effects_add(*overworld.effects, .{
                    rect         = found_level_entrance.rect,
                    texture_name = TEX_ORYX_TINY_DUNGEON_FX,
                    frames       = Entity.SOLVED_FX_ANIM_FRAMES,
                    duration     = Entity.SOLVED_FX_DURATION,
                });

                level_solved_in_this_area = true;
            }
        }

        if level_solved_in_this_area {
            audio_play_sound(audio, SFX_SOLVE_LEVEL_OVERWORLD);
        }
    }

    if !audio_is_music_playing(audio, area.music.stream_id) {
        audio_stop_all_music(audio);
        audio_play_music(audio, area.music, delay = 1.0);
    }

    mb_left_pressed  := input_state.keys[Key_Code.MOUSE_BUTTON_LEFT] & .PRESSED;
    spacebar_pressed := input_state.keys[Key_Code.SPACEBAR] & .PRESSED;

    if overworld.reading_scroll {
        // TODO(jt): Consider do a resetting update for all entities here? Set hovered to false, etc.
        scroll     := overworld.reading_scroll;
        page_index := overworld.reading_scroll_page;
        page_count := scroll.pages.count;

        if page_count {
            // 9x9 tiles (144x144)
            CANVAS_SIZE_TILES  :: IVector2.{ 9, 9 };
            CANVAS_SIZE_PIXELS :: #run CANVAS_SIZE_TILES * TINY_DUNGEON_TILE_SIZE;

            AVAILABLE_SIZE_TILES  :: #run IVector2.{ SCREEN_SIZE_IN_TILES.x, SCREEN_SIZE_IN_TILES.y * 3 / 4 };
            AVAILABLE_SIZE_PIXELS :: #run AVAILABLE_SIZE_TILES * TINY_DUNGEON_TILE_SIZE;

            scroll_has_animation := cast(bool, scroll.page_frame_ranges.count) && cast(bool, scroll.frames.count);
            page_has_animation   := false;
            if scroll_has_animation {
                page_frame_ranges := scroll.page_frame_ranges;
                frames            := scroll.frames;

                assert(page_frame_ranges.count == page_count, "Each scroll page must have a frame range");
                // TODO(jt): Consider adding more validation so that we don't crash just when the player
                // accesses this, but rather crash more consistently.

                // When playing frames backwards, we are actually playing frames associated with the
                // following page, so that we can arrive back to this one!
                page_frame_range := ifx overworld.reading_scroll_backwards then page_frame_ranges[page_index + 1] else page_frame_ranges[page_index];
                page_frame_count := page_frame_range.end_index - page_frame_range.start_index;

                page_has_animation = page_frame_count > 0;
                if page_has_animation {
                    overworld.reading_scroll_time_spent_on_page += dtime;

                    frame_index_base   := page_frame_range.start_index;
                    frame_index_offset := cast(s64, floor(overworld.reading_scroll_time_spent_on_page / scroll.frame_duration));
                    if overworld.reading_scroll_backwards {
                        frame_index_offset = page_frame_count - frame_index_offset - 1;
                    }
                    Clamp(*frame_index_offset, 0, page_frame_count - 1);

                    frame_index := frame_index_base + frame_index_offset;
                    frame       := scroll.frames[frame_index];

                    P0   :: #run (AVAILABLE_SIZE_PIXELS - CANVAS_SIZE_PIXELS) / 2;
                    RECT :: #run Rect.{ cast(f32, P0.x), cast(f32, P0.y), cast(f32, CANVAS_SIZE_PIXELS.x), cast(f32, CANVAS_SIZE_PIXELS.y) };

                    rect := viewport_transform_rect(RECT);

                    draw_rect(*gui.render_lists, rect, frame, scroll.frames_texture);
                }
            }

            STARTING_HEIGHT_WITH_IMAGE: f32 : #run AVAILABLE_SIZE_PIXELS.y;
            STARTING_HEIGHT_TEXT_ONLY:  f32 : 0.0;

            starting_height := ifx page_has_animation then STARTING_HEIGHT_WITH_IMAGE else STARTING_HEIGHT_TEXT_ONLY;
            // Center text across the whole scroll by picking the largest page to compute
            // centering. Only center pages without animation, though. Animated have text under the
            // animation.
            if !page_has_animation {
                max_screen_line_count := viewport.rect.h / viewport.scale / TINY_DUNGEON_FONT_TILE_SIZE.y;
                max_scroll_line_count := 0;
                for page_text: scroll.pages {
                    page_line_count := 1;
                    for page_text {
                        if it == "\n"  {
                            page_line_count += 1;
                        }
                    }

                    if page_line_count > max_scroll_line_count {
                        max_scroll_line_count = page_line_count;
                    }
                }

                starting_line   := (max_screen_line_count - max_scroll_line_count) / 2;
                starting_height += starting_line * TINY_DUNGEON_FONT_TILE_SIZE.y;
            }

            draw_text(
                *gui.render_lists,
                viewport_transform_position(.{ 70, starting_height }),
                scroll.pages[page_index],
                scale = viewport.scale,
                font_kind = .DARK,
            );

            if scroll.pages.count > 1 {
                {
                    activated, events := button(gui, input_state, viewport_transform_position(.{ 70, 220 }), "<", scale = viewport.scale, font_kind = .DARK);
                    if activated {
                        overworld.reading_scroll_page -= 1;
                        if overworld.reading_scroll_page < 0 {
                            overworld.reading_scroll_page = 0;
                        } else {
                            overworld.reading_scroll_time_spent_on_page = 0.0;
                            overworld.reading_scroll_backwards = true;
                            audio_play_sound(audio, SFX_UI_BOOK_TURN_PAGE);
                        }
                    }

                    // TODO(jt): @Cleanup Consider making a button that takes the audio context and just fires the event itself.
                    if events & .HOVERED {
                        audio_play_sound(audio, SFX_UI_BOOK_HOVER);
                    }
                }

                {
                    activated, events := button(gui, input_state, viewport_transform_position(.{ 80, 220 }), ">", scale = viewport.scale, font_kind = .DARK);
                    if activated {
                        overworld.reading_scroll_page += 1;
                        if overworld.reading_scroll_page >= page_count {
                            overworld.reading_scroll_page = page_count - 1;
                        } else {
                            overworld.reading_scroll_time_spent_on_page = 0.0;
                            overworld.reading_scroll_backwards = false;
                            audio_play_sound(audio, SFX_UI_BOOK_TURN_PAGE);
                        }
                    }

                    // TODO(jt): @Cleanup Consider making a button that takes the audio context and just fires the event itself.
                    if events & .HOVERED {
                        audio_play_sound(audio, SFX_UI_BOOK_HOVER);
                    }
                }

                draw_text(
                    *gui.render_lists,
                    viewport_transform_position(.{ 90, 220 }),
                    tprint("(%/%)", page_index + 1, page_count),
                    scale = viewport.scale,
                    font_kind = .DARK,
                );
            }
        }

        {
            activated, events := button(gui, input_state, viewport_transform_position(.{ 260, 220 }), "Close", scale = viewport.scale, font_kind=.DARK);
            if activated {
                overworld.reading_scroll = null;
                overworld.reading_scroll_page = 0;
                overworld.reading_scroll_backwards = false;
                overworld.reading_scroll_time_spent_on_page = 0.0;

                audio_play_sound(audio, SFX_UI_BOOK_CLOSE);
            }

            // TODO(jt): @Cleanup Consider making a button that takes the audio context and just fires the event itself.
            if events & .HOVERED {
                audio_play_sound(audio, SFX_UI_BOOK_HOVER);
            }
        }
    } else {
        //
        // TODO(jt): @Cleanup There is a lot of copy-pasted code in the entity update loops. Try and extract some of it?
        //

        for * entity, entity_index: overworld.level_entrances {
            if entity.area == area.name {
                tile_rect := viewport_transform_rect(entity.rect);

                entity.hovered  = rect_contains(tile_rect, input.mouse_position);
                entity.unlocked = entity.unlocked_by_levels.count == 0;

                if !entity.unlocked {
                    unlocked_count := 0;

                    for entity.unlocked_by_levels {
                        found, found_level_entrance := table_find(*area_level_name_to_level_entrance, it);
                        if found {
                            if found_level_entrance.solved {
                                unlocked_count += 1;
                            }
                        } else {
                            overworld.has_errors = true;
                            // TODO(jt): @Cleanup Don't spam the error. Validate all areas at init time, or when we move from area to area (and reset).
                            log_error("% [%] is unlocked_by %, but the unlocker doesn't exist", type_of(entity), entity_index, it);
                        }
                    }

                    if unlocked_count == entity.unlocked_by_levels.count {
                        entity.unlocked = true;
                    }
                }

                if entity.hovered {
                    #if DEVELOPER {
                        maybe_solve_level(overworld, entity, input_state);
                        maybe_solve_unlocker_levels(overworld, entity, input_state);
                    }

                    if mb_left_pressed || spacebar_pressed {
                        if entity.unlocked {
                            if entity.level.count == 0 {
                                log_error("Level in area % does not have a name set", area.name);
                            }

                            transition.type = .TO_LEVEL;
                            transition.level = entity.level;
                            transition.board_state = entity.board_state;

                            data := Game_Transition.To_Level_Data.{ area.hint_flags, entity.solved };
                            transition.data.to_level = data;

                            audio_play_sound(audio, SFX_ENTER_LEVEL);
                        } else {
                            for level_name: entity.unlocked_by_levels {
                                found, found_level_entrance := table_find(*area_level_name_to_level_entrance, level_name);
                                if found {
                                    effects_add(*overworld.effects, .{
                                        rect         = found_level_entrance.rect,
                                        texture_name = TEX_ORYX_TINY_DUNGEON_FX,
                                        frames       = Entity.LOCKED_FX_ANIM_FRAMES,
                                        duration     = Entity.LOCKED_FX_DURATION,
                                    });
                                }
                            }

                            audio_play_sound(audio, SFX_DENIED);
                        }
                    }
                }
            }
        }

        for * entity, entity_index: overworld.area_entrances {
            if entity.area == area.name {
                tile_rect := viewport_transform_rect(entity.rect);

                entity.hovered  = rect_contains(tile_rect, input.mouse_position);
                entity.unlocked = entity.unlocked_by_levels.count == 0;

                if !entity.unlocked {
                    unlocked_count := 0;

                    for entity.unlocked_by_levels {
                        found, found_level_entrance := table_find(*area_level_name_to_level_entrance, it);
                        if found {
                            if found_level_entrance.solved {
                                unlocked_count += 1;
                            }
                        } else {
                            overworld.has_errors = true;
                            // TODO(jt): @Cleanup Don't spam the error. Validate all areas at init time, or when we move from area to area (and reset).
                            log_error("% [%] is unlocked_by %, but the unlocker doesn't exist", type_of(entity), entity_index, it);
                        }
                    }

                    if unlocked_count == entity.unlocked_by_levels.count {
                        entity.unlocked = true;
                    }
                }

                if entity.hovered {
                    #if DEVELOPER {
                        maybe_solve_unlocker_levels(overworld, entity, input_state);
                    }

                    if mb_left_pressed || spacebar_pressed {
                        if entity.unlocked {
                            transition_to_area = entity.target_area;
                            audio_play_sound(audio, SFX_ENTER_AREA);

                            overworld.needs_save = true;
                        } else {
                            for level_name: entity.unlocked_by_levels {
                                found, found_level_entrance := table_find(*area_level_name_to_level_entrance, level_name);
                                if found {
                                    effects_add(*overworld.effects, .{
                                        rect         = found_level_entrance.rect,
                                        texture_name = TEX_ORYX_TINY_DUNGEON_FX,
                                        frames       = Entity.LOCKED_FX_ANIM_FRAMES,
                                        duration     = Entity.LOCKED_FX_DURATION,
                                    });
                                }
                            }

                            audio_play_sound(audio, SFX_DENIED);
                        }
                    }
                }
            }
        }

        for * entity, entity_index: overworld.scrolls {
            if entity.area == area.name {
                tile_rect := viewport_transform_rect(entity.rect);

                entity.hovered  = rect_contains(tile_rect, input.mouse_position);
                entity.unlocked = entity.unlocked_by_levels.count == 0;

                if !entity.unlocked {
                    unlocked_count := 0;

                    for entity.unlocked_by_levels {
                        found, found_level_entrance := table_find(*area_level_name_to_level_entrance, it);
                        if found {
                            if found_level_entrance.solved {
                                unlocked_count += 1;
                            }
                        } else {
                            overworld.has_errors = true;
                            // TODO(jt): @Cleanup Don't spam the error. Validate all areas at init time, or when we move from area to area (and reset).
                            log_error("% [%] is unlocked_by %, but the unlocker doesn't exist", type_of(entity), entity_index, it);
                        }

                    }

                    if unlocked_count == entity.unlocked_by_levels.count {
                        entity.unlocked = true;
                    }
                }

                if entity.hovered {
                    #if DEVELOPER {
                        maybe_solve_unlocker_levels(overworld, entity, input_state);
                    }

                    if mb_left_pressed || spacebar_pressed {
                        if entity.unlocked {
                            overworld.reading_scroll = entity;
                            overworld.reading_scroll_page = 0;
                            overworld.reading_scroll_backwards = false;
                            overworld.reading_scroll_time_spent_on_page = 0.0;

                            if entity.unread {
                                overworld.needs_save = true;
                                entity.unread = false;

                                // TODO(jt): This could be a stale ID, even though the ID space is quite large.
                                effects_remove(*overworld.effects, entity.unread_fx_id);
                                entity.unread_fx_id = EFFECT_ID_INVALID;
                            }

                            audio_play_sound(audio, SFX_UI_BOOK_OPEN);
                        } else {
                            for level_name: entity.unlocked_by_levels {
                                found, found_level_entrance := table_find(*area_level_name_to_level_entrance, level_name);
                                if found {
                                    effects_add(*overworld.effects, .{
                                        rect         = found_level_entrance.rect,
                                        texture_name = TEX_ORYX_TINY_DUNGEON_FX,
                                        frames       = Entity.LOCKED_FX_ANIM_FRAMES,
                                        duration     = Entity.LOCKED_FX_DURATION,
                                    });
                                }
                            }

                            audio_play_sound(audio, SFX_DENIED);
                        }
                    }
                }

                if entity.unread && entity.unread_fx_id == EFFECT_ID_INVALID {
                    id := effects_add(*overworld.effects, .{
                        rect         = entity.rect,
                        texture_name = TEX_ORYX_TINY_DUNGEON_FX,
                        frames       = Scroll.UNREAD_FX_ANIM_FRAMES,
                        duration     = Scroll.UNREAD_FX_DURATION,

                        delay        = Scroll.UNREAD_FX_DELAY,
                        repeat       = true,
                        repeat_delay = Scroll.UNREAD_FX_REPEAT_DELAY,
                    });

                    entity.unread_fx_id = id;
                }
            }
        }
    }

    if overworld.has_errors {
        draw_error_text(*gui.render_lists, viewport_transform_position(.{ 170, 10 }), "ERRORS", scale = viewport.scale);
    }

    //
    // Render
    //

    // TODO(jt): Remove area_drawing_offset and draw shapeful areas in assets (or code).
    area_drawing_offset := (SCREEN_SIZE_IN_TILES - area.size) / 2;
    assert(area_drawing_offset.x >= 0 && area_drawing_offset.y >= 0); // TODO(jt): Turn this into a log if it proves annoying.

    GROUND_TILE_RECTS :: Rect.[
        // GROUND_BASE_RECT,

        // GROUND_RECT0,
        GROUND_RECT1,
        GROUND_RECT2,
        GROUND_RECT3,

        // GROUND_COBBLE_RECT0,
        // GROUND_COBBLE_RECT1,

        // GROUND_OVERGROWN_BASE_RECT,

        // GROUND_OVERGROWN_RECT0,
        GROUND_OVERGROWN_RECT1,
        GROUND_OVERGROWN_RECT2,
        GROUND_OVERGROWN_RECT3,

        // GROUND_OVERGROWN_COBBLE_RECT0,
        // GROUND_OVERGROWN_COBBLE_RECT1,
    ];

    area_drawing_rng: Random_State;
    random_seed(*area_drawing_rng, 0xcafebabe);
    for y: 0..area.size.y - 1 {
        for x: 0..area.size.x - 1 {
            texture_rect_index := random_get(*area_drawing_rng) % GROUND_TILE_RECTS.count;

            tile_rect := viewport_transform_rect(make_tile_rect(
                area_drawing_offset.x + x,
                area_drawing_offset.y + y,
                TINY_DUNGEON_TILE_SIZE,
            ));
            draw_rect(render_lists, tile_rect, GROUND_TILE_RECTS[texture_rect_index], TEX_ORYX_TINY_DUNGEON_WORLD);
        }
    }

    for overworld.level_entrances {
        if it.area == area.name {
            tile_rect := viewport_transform_rect(it.rect);

            color := Vector4.{ 1, 1, 1, 1 };
            if it.hovered && it.unlocked {
                color = .{ 1.2, 1.2, 1.2, 1 };
            } else if !it.unlocked {
                color = .{ 0.7, 0.7, 0.7, 1 };
            }

            // TODO(jt): Instead of marking with shapes, think about marking levels not made by me
            // with color, like in Taiji. My levels will have a neutralish color, and so will
            // Zach's, and the saturated ones would be for other contributors.
            if it.solved {
                draw_rect(render_lists, tile_rect, LEVEL_ENTRANCE_SOLVED_RECT, TEX_ORYX_TINY_DUNGEON_WORLD, color);
                if it.from_original_game {
                    draw_rect(render_lists, tile_rect, LEVEL_ENTRANCE_CENTER_RECT, TEX_LEVEL_ENTRANCE_CENTER, .{ 0.7, 0.4, 0.7, 1.0 });
                }
            } else {
                draw_rect(render_lists, tile_rect, LEVEL_ENTRANCE_RECT, TEX_ORYX_TINY_DUNGEON_WORLD, color);
                if it.from_original_game {
                    draw_rect(render_lists, tile_rect, LEVEL_ENTRANCE_CENTER_RECT, TEX_LEVEL_ENTRANCE_CENTER, .{ 0.7, 0.4, 0.7, 1.0 });
                }
            }


            if !it.unlocked && it.hovered {
                draw_rect(render_lists, tile_rect, LOCKED_ENTITY_RECT, TEX_ORYX_TINY_DUNGEON_FX, .{ 1, .5, .5, 1 });
            }
        }
    }

    for overworld.area_entrances {
        if it.area == area.name {
            tile_rect := viewport_transform_rect(it.rect);

            color := Vector4.{ 1, 1, 1, 1 };
            if it.hovered && it.unlocked {
                color = .{ 1.2, 1.2, 1.2, 1 };
            } else if !it.unlocked {
                color = .{ 0.7, 0.7, 0.7, 1 };
            }

            if it.texture {
                draw_rect(render_lists, tile_rect, it.texture_rect, it.texture, color);
            } else {
                draw_rect(render_lists, tile_rect, AREA_ENTRANCE_RECT, TEX_ORYX_TINY_DUNGEON_WORLD, color);
            }

            if !it.unlocked && it.hovered {
                draw_rect(render_lists, tile_rect, LOCKED_ENTITY_RECT, TEX_ORYX_TINY_DUNGEON_FX, .{ 1, .5, .5, 1 });
            }
        }
    }

    for overworld.scrolls {
        if it.area == area.name {
            tile_rect := viewport_transform_rect(it.rect);

            color := Vector4.{ 1, 1, 1, 1 };
            if it.hovered && it.unlocked {
                color = .{ 1.2, 1.2, 1.2, 1 };
            } else if !it.unlocked {
                color = .{ 0.7, 0.7, 0.7, 1 };
            }

            draw_rect(render_lists, tile_rect, SCROLL_RECT, TEX_ORYX_TINY_DUNGEON_ITEMS, color);

            if !it.unlocked && it.hovered {
                draw_rect(render_lists, tile_rect, LOCKED_ENTITY_RECT, TEX_ORYX_TINY_DUNGEON_FX, .{ 1, .5, .5, 1 });
            }
        }
    }

    effects_update_and_render(*overworld.effects, dtime, viewport, render_lists);

    draw_text(
        render_lists,
        viewport_transform_position(.{ 10, 6 }),
        area.name,
        scale = viewport.scale,
        font_kind=.LIGHT,
    );

    if overworld.reading_scroll {
        scroll := overworld.reading_scroll;
        page   := overworld.reading_scroll_page;

        {
            tile_rect := viewport_transform_rect(make_tile_rect(0, 0, TINY_DUNGEON_TILE_SIZE));
            draw_rect(render_lists, tile_rect, SCROLL_BACKGROUND_TOP_LEFT_RECT, TEX_ORYX_TINY_DUNGEON_INTERFACE);
        }

        for x: 1..SCREEN_SIZE_IN_TILES.x - 2 {
            tile_rect := viewport_transform_rect(make_tile_rect(x, 0, TINY_DUNGEON_TILE_SIZE));
            draw_rect(render_lists, tile_rect, SCROLL_BACKGROUND_TOP_RECT, TEX_ORYX_TINY_DUNGEON_INTERFACE);
        }

        {
            tile_rect := viewport_transform_rect(make_tile_rect(SCREEN_SIZE_IN_TILES.x - 1, 0, TINY_DUNGEON_TILE_SIZE));
            draw_rect(render_lists, tile_rect, SCROLL_BACKGROUND_TOP_RIGHT_RECT, TEX_ORYX_TINY_DUNGEON_INTERFACE);
        }

        for y: 1..SCREEN_SIZE_IN_TILES.y - 2 {
            {
                tile_rect := viewport_transform_rect(make_tile_rect(0, y, TINY_DUNGEON_TILE_SIZE));
                draw_rect(render_lists, tile_rect, SCROLL_BACKGROUND_MID_LEFT_RECT, TEX_ORYX_TINY_DUNGEON_INTERFACE);
            }

            for x: 1..SCREEN_SIZE_IN_TILES.x - 2 {
                tile_rect := viewport_transform_rect(make_tile_rect(x, y, TINY_DUNGEON_TILE_SIZE));
                draw_rect(render_lists, tile_rect, SCROLL_BACKGROUND_MID_RECT, TEX_ORYX_TINY_DUNGEON_INTERFACE);
            }

            {
                tile_rect := viewport_transform_rect(make_tile_rect(SCREEN_SIZE_IN_TILES.x - 1, y, TINY_DUNGEON_TILE_SIZE));
                draw_rect(render_lists, tile_rect, SCROLL_BACKGROUND_MID_RIGHT_RECT, TEX_ORYX_TINY_DUNGEON_INTERFACE);
            }
        }

        {
            tile_rect := viewport_transform_rect(make_tile_rect(0, SCREEN_SIZE_IN_TILES.y - 1, TINY_DUNGEON_TILE_SIZE));
            draw_rect(render_lists, tile_rect, SCROLL_BACKGROUND_BOTTOM_LEFT_RECT, TEX_ORYX_TINY_DUNGEON_INTERFACE);
        }

        for x: 1..SCREEN_SIZE_IN_TILES.x - 2 {
            tile_rect := viewport_transform_rect(make_tile_rect(x, SCREEN_SIZE_IN_TILES.y - 1, TINY_DUNGEON_TILE_SIZE));
            draw_rect(render_lists, tile_rect, SCROLL_BACKGROUND_BOTTOM_RECT, TEX_ORYX_TINY_DUNGEON_INTERFACE);
        }

        {
            tile_rect := viewport_transform_rect(make_tile_rect(
                SCREEN_SIZE_IN_TILES.x - 1,
                SCREEN_SIZE_IN_TILES.y - 1,
                TINY_DUNGEON_TILE_SIZE,
            ));
            draw_rect(render_lists, tile_rect, SCROLL_BACKGROUND_BOTTOM_RIGHT_RECT, TEX_ORYX_TINY_DUNGEON_INTERFACE);
        }
    }

    if transition_to_area {
        handle_area_change(overworld, transition_to_area);
    }

    return transition;
}

#scope_file

handle_area_change :: (overworld: *Overworld, new_area_name: string) {
    // TODO(jt): All entity spawned fx animations should be flushed here, not just scrolls.
    for * overworld.scrolls {
        if it.area == overworld.current_area_name {
            it.unread_fx_id = EFFECT_ID_INVALID;
        }
    }

    effects_reset(*overworld.effects);

    overworld.current_area_name = new_area_name;
}

get_current_area :: (overworld: Overworld) -> *Area {
    for * overworld.areas {
        if it.name == overworld.current_area_name {
            return it;
        }
    }

    // TODO(jt): If this assert turns out to be too annoying, consider changing into fixup code!
    assert(false);
    return null;
}

maybe_solve_level :: (overworld: *Overworld, level_entrance: *Level_Entrance, input_state: Input_State) {
    if !(input_state.keys[Key_Code.CTRL] & .DOWN) && input_state.keys[Key_Code.S] & .PRESSED {
        if level_entrance.solved {
            level_entrance.solved = false;
        } else {
            level_entrance.solved = true;
            array_add(*overworld.newly_solved_levels, level_entrance.level);

        }

        overworld.needs_save = true;
    }
}

maybe_solve_unlocker_levels :: (overworld: *Overworld, entity: *Entity, input_state: Input_State) {
    if input_state.keys[Key_Code.CTRL] & .DOWN && input_state.keys[Key_Code.S] & .PRESSED {
        for level_name: entity.unlocked_by_levels {
            // TODO(jt): @Speed We already have a table of levels present on our screen, pass that
            // it and use it for the lookup?
            for * overworld.level_entrances {
                if it.level == level_name {
                    it.solved = true;
                    array_add(*overworld.newly_solved_levels, level_name);

                    overworld.needs_save = true;
                    break;
                }
            }
        }
    }
}

// TODO(jt): Hide!
SCROLL_TUTORIAL_1_1 :: #string END
Welcome, adventurer!

In this game you must use logic to
complete the dungeon map by placing
walls in the correct spaces.
END;

SCROLL_TUTORIAL_1_2 :: #string END
The number next to each row indicates
how many walls it contains.

Left click to place walls.
END;

SCROLL_TUTORIAL_1_3 :: #string END
Every empty space in a map is part of
either a treasure room or a hallway.

Right click to mark empty spaces.

END;
SCROLL_TUTORIAL_1_4 :: #string END
Treasure rooms are always 3x3 with
a single entrance, a single chest,
and no other objects.

The chest can be in any of the spaces.
END;

SCROLL_TUTORIAL_1_5 :: #string END
Every monster is in a dead end.

Every dead end contains a monster.
END;

SCROLL_TUTORIAL_1_6 :: #string END
All empty spaces connect into a single
contiguous shape. Diagonal spaces
are never considered to be adjacent.
END;

// TODO(jt): @Design @Hack What about 2x2 pools versus traps/crests? The original game says 2x2 of
// empty space, and both monsters and treasure rooms actually enforce no pools via their own rules
// (so that the game doesn't have to say 2x2 of nonwall space?). Traps automatically satisfy
// pools. Crests, however, do not! For example, if we take the ruleset literally, this is a valid
// crest cap:
//
// ####
// #..#
// #a.#
// #.##
//
// For now, we add a sentence about clues counting as empty space, but this is ugly!
SCROLL_TUTORIAL_1_7 :: #string END
Hallways are always one space wide.

Outside of treasure rooms there will
never be a 2x2 block of empty spaces.
Objects count as empty space.
END;

SCROLL_TUTORIAL_1_8 :: #string END
Place all walls correctly to solve
the puzzle and unlock more!
END;

SCROLL_TUTORIAL_1_NEW_1 :: #string END
Welcome, adventurer!

In this game you must use logic to
complete the dungeon map by placing
walls in the correct spaces.
END;

SCROLL_TUTORIAL_1_NEW_2 :: #string END
Left click to place walls.

Right click to mark empty spaces.
END;

SCROLL_SECRETS_LEARNED :: #string END
You have learned the secrets of this land.
END;

SCROLL_INFINITE_DUNGEON :: #string END
The shadow caverns are under construction.
END;

SCROLL_FOREST_HINT :: #string END
The portal is sealed.

To enter, learn the secrets of
distant lands.
END;

SCROLL_THE_END :: #string END
       Thank you for playing!
END;

SCROLL_CREDITS_1 :: #string END
         A game by Jan Toth



  www.withoutfearofwindorvertigo.com
END;

SCROLL_CREDITS_2 :: #string END
Influences


Dungeons & Diagrams       Zachtronics
The Witness               Thekla, inc
Taiji                     Matthew VanDevander
Dragonsweeper             Daniel Benmergui
END;

SCROLL_CREDITS_3 :: #string END
Design


Game Design               Jan Toth
Puzzle Design             Jan Toth
Original Ruleset          Zach Barth

END;

SCROLL_CREDITS_4 :: #string END
Programming


Gameplay                  Jan Toth
Engine                    Jan Toth
END;

SCROLL_CREDITS_5 :: #string END
Art


Tiny Dungeon              Oryx Design Lab
END;


SCROLL_CREDITS_6 :: #string END
Music


RPG Music                 Leohpaz
Ambiences                 JDSherbert
END;


SCROLL_CREDITS_7 :: #string END
Sound effects


Minifantasy Forgotten Plains  Leohpaz
Book Parchment UI             Leohpaz
RPG Essentials                Leohpaz
Ultimate UI SFX               JDSherbert
END;

SCROLL_CREDITS_8 :: #string END
Used Software


JAI Compiler and Modules  Jonathan Blow
                          Raphael Luba
stb_vorbis                Sean Barett
END;

SCROLL_CREDITS_9 :: #string END
Playtesters


Lucia Tusimova            Ondrej Slintak
Stefan Mijucic            Dusan Hetlerovic
Areta Tothova             Stefan Urbanek
@Auex                     @Rupi
@TechnicBeam              Matthew VanDevander
END;


SCROLL_CREDITS_10 :: #string END
Special thanks

Zach Barth
Matthew VanDevander
Lucia Tusimova
END;
