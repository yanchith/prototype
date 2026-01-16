// TODO(jt): Consider changing the Audio struct to a module-level singleton, since there's only
// going to be one just one.

// TODO(jt): @Cleanup @Hack The music assets are too loud compared to the sound effect assets. This
// was the quickest way to turn their volume down, but obviously we should have something more
// proper.
Sfx :: struct {
    name: string;
    tweak_volume := 1.0;
}

Music :: struct {
    stream_id: s64; // Preallocated audio stream ID.
    name_for_loop: string;
    name_for_intro := "";
    tweak_volume := 1.0;
}

Audio :: struct ($MAX_MUSIC_STREAMS: s64) {
    // TODO(jt): Put this in an arena and reserve some space at the beginning. Otherwise, this would
    // actually be a good case for arrayvec.
    sound_stream_queue: [..] Sfx;
    sound_stream_next_id: s64 = MAX_MUSIC_STREAMS; // Starts at MAX_MUSIC_STREAMS and grows. On overflow wraps back to MAX_MUSIC_STREAMS.

    music_stream_states: [MAX_MUSIC_STREAMS] Music_Stream_State;

    music_volume := 1.0;
    sfx_volume   := 1.0;
    mute: bool;
}

// You can also directly access audio.mute, if you don't care about toggling.
audio_toggle_mute :: (audio: *Audio) {
    audio.mute = !audio.mute;
}

audio_set_music_volume :: (audio: *Audio, volume: f32) {
    audio.music_volume = volume;
}

audio_set_sfx_volume :: (audio: *Audio, volume: f32) {
    audio.sfx_volume = volume;
}

audio_is_music_playing :: (audio: Audio, music_stream_id: s64) -> bool {
    state := audio.music_stream_states[music_stream_id];
    return cast(bool, state.flags & .PLAYING);
}

audio_play_music :: (audio: *Audio, music: Music, delay := 0.0) {
    // TODO(jt): Explicit bounds check?
    state := *audio.music_stream_states[music.stream_id];

    // TODO(jt): Allow recycling of music streams?
    assert(state.name_for_loop == "" || state.name_for_loop == music.name_for_loop);
    assert(state.name_for_intro == "" || state.name_for_intro == music.name_for_intro);
    state.name_for_loop  = music.name_for_loop;
    state.name_for_intro = music.name_for_intro;
    state.tweak_volume   = music.tweak_volume;

    if state.flags == .UNINITIALIZED || state.flags & .STOPPED {
        state.flags &= ~.STOPPED;
        state.flags &= ~.PLATFORM_NEEDS_STOP;

        state.flags |= .PLAYING;
        state.flags |= .PLATFORM_NEEDS_INIT;

        if music.name_for_intro.count {
            state.flags |= .INTRO;
        }

        state.volume = 0.0;
        state.delay  = delay;
    }
}

audio_stop_all_music :: (audio: *Audio) {
    for * audio.music_stream_states {
        if it.flags == .UNINITIALIZED                                 continue;
        if it.flags & .STOPPED && !(it.flags & .PLATFORM_NEEDS_STOP)  continue;

        if it.flags & .PLAYING {
            it.flags &= ~.PLAYING;
            it.flags &= ~.PLATFORM_NEEDS_INIT;
        }

        it.flags |= .STOPPED;
        it.flags |= .PLATFORM_NEEDS_STOP;

        if it.flags & .INTRO {
            assert(
                it.flags == (.STOPPED | .PLATFORM_NEEDS_STOP | .INTRO),
                "Expected flags to be %, but were %",
                Music_Stream_Flags.STOPPED | .PLATFORM_NEEDS_STOP | .INTRO,
                it.flags,
            );
        } else {
            assert(
                it.flags == (.STOPPED | .PLATFORM_NEEDS_STOP),
                "Expected flags to be %, but were %",
                Music_Stream_Flags.STOPPED | .PLATFORM_NEEDS_STOP,
                it.flags,
            );
        }

        it.delay = 0.0;
    }
}

audio_play_sound :: (audio: *Audio, sfx: Sfx) {
    // TODO(jt): @Hack We are relying on sounds being short-lived, and thus don't keep references to
    // their audio streams. Do that instead of this early return.
    if !audio.mute {
        array_add(*audio.sound_stream_queue, sfx);
    }
}

audio_update :: (audio: *Audio, platform: Platform, dt: f32) {
    for * audio.music_stream_states {
        if it.flags == .UNINITIALIZED {
            continue;
        }

        it.delay -= dt;
        if it.delay < 0.0 {
            it.delay = 0.0;
        }

        if it.delay != 0.0 {
            continue;
        }

        if it.flags & .PLATFORM_NEEDS_INIT {
            intro := it.flags & .INTRO;
            name  := ifx intro then it.name_for_intro else it.name_for_loop;

            platform.play_audio_stream(it_index, name, it.volume, !intro);
            it.flags &= ~.PLATFORM_NEEDS_INIT;

            // TODO(jt): @Cleanup These asserts are a little laborius after we added INTRO. Consider removing?
            if intro {
                assert(it.flags == (.PLAYING | .INTRO), "Expected flags to be %, but were %", Music_Stream_Flags.PLAYING | .INTRO, it.flags);
            } else {
                assert(it.flags == .PLAYING, "Expected flags to be %, but were %", Music_Stream_Flags.PLAYING, it.flags);
            }
        }

        // First fade-out, only then stop the backend.
        if it.flags & .PLATFORM_NEEDS_STOP && it.volume == 0.0 {
            platform.stop_audio_stream(it_index);
            it.flags &= ~.PLATFORM_NEEDS_STOP;

            // TODO(jt): @Cleanup These asserts are a little laborius after we added INTRO. Consider removing?
            if it.flags & .INTRO {
                assert(it.flags == (.STOPPED | .INTRO), "Expected flags to be %, but were %", Music_Stream_Flags.STOPPED | .INTRO, it.flags);
            } else {
                assert(it.flags == .STOPPED, "Expected flags to be %, but were %", Music_Stream_Flags.STOPPED, it.flags);
            }
        }

        if it.flags == (.PLAYING | .INTRO) {
            if !platform.is_audio_stream_playing(it_index) {
                platform.play_audio_stream(it_index, it.name_for_loop, it.volume, true);
                it.flags &= ~.INTRO;

                assert(it.flags == .PLAYING, "Expected flags to be %, but were %", Music_Stream_Flags.PLAYING, it.flags);
            }
        }

        target_volume: f32;
        if it.flags & .PLAYING  target_volume = audio.music_volume * it.tweak_volume;
        if audio.mute           target_volume = 0.0;

        it.volume = move_toward(it.volume, target_volume, 0.50 * dt, 0.50 * dt);
        platform.set_audio_stream_volume(it_index, it.volume);
    }

    for audio.sound_stream_queue {
        stream_id := audio.sound_stream_next_id;

        // Increment next stream ID. Start on the first ID on overflow.
        audio.sound_stream_next_id += 1;
        if audio.sound_stream_next_id < 0 {
            audio.sound_stream_next_id = audio.MAX_MUSIC_STREAMS;
        }

        // TODO(jt): Tweak volume and pitch.
        platform.play_audio_stream(stream_id, it.name, audio.sfx_volume * it.tweak_volume, false);
    }

    array_reset_keeping_memory(*audio.sound_stream_queue);
}

#scope_file

Music_Stream_Flags :: enum_flags u32 {
    UNINITIALIZED :: 0;

    PLAYING :: 0x01;
    STOPPED :: 0x02;

    PLATFORM_NEEDS_INIT   :: 0x10;
    PLATFORM_NEEDS_STOP   :: 0x20;

    INTRO :: 0x1000;
}

Music_Stream_State :: struct {
    // Configuration
    name_for_loop:  string;
    name_for_intro: string;
    tweak_volume:   f32;

    // Runtime data
    flags:  Music_Stream_Flags;
    volume: f32;
    delay:  f32;
}
