// TODO(jt): We are currently (except in solver/solver_tests, because those want to print more
// complicated things) using the log/log_error functions from Basic, but maybe we should be calling
// the platform to log (and ignore the existence of context)?

Platform :: struct {
    //
    // File API
    //

    // TODO(jt): @Cleanup @Memory #malloc Formalize where this is allocated by passing the allocator!
    //
    // Currently:
    //
    // On native, this just calls malloc (and never frees). However, if we pass temp, we have to
    // make sure that other systems make a copy, if they need to hang on to the data longer (or we
    // pass malloc, or a permament arena in this case).
    //
    // On WASM, this is the same as native for non-asset files, but asset files are allocated with
    // malloc by javascript when it pre-populates assets into the JS memory.
    //
    // Either we have to inherit the asset/non-asset distinction from WASM and always use a
    // malloc-style allocator for assets, or we have to make a copy of the data on WASM, so that we
    // respect the allocater given to us by the caller.
    read_file:         (path: string) -> success: bool, result: string;
    write_file:        (path: string, data: string) -> bool;
    delete_file:       (path: string) -> bool;

#if DEVELOPER {
    copy_file: (source_path: string, dest_path: string) -> success: bool;
}

    file_exists:       (path: string) -> bool;

#if DEVELOPER {
    file_is_directory: (path: string) -> bool;
    make_directory_if_it_does_not_exist: (path: string, recursive: bool)          -> success: bool;
    delete_directory:                    (path: string) -> bool;
}

    //
    // Audio API
    //

    // The 'name' in the following procs is the unique identifier of the audio stream. While it in
    // theory could be any string, we are only using it with string literals (stored in the
    // executable).
    //
    // TODO(jt): Enforce that 'audio_name' is a string literal or use a macro/#run to generate IDs for
    // each audio name, e.g.:
    //
    // FOOTSTEP_SOUND :: AudioID("footsteps.wav");

    // NOTE(jt): 'data' is currently copied into the audio system's memory, so it is not neccesary
    // for the original data to remain live.
    load_audio:                 (audio_name: string, data: [] u8) -> success: bool;
    // TODO(jt): @Speed There is a mutex involved in tweaking a sound stream. Maybe provide batch
    // operations, so that we don't have to lock it many times.
    play_audio_stream:          (stream_id: s64, audio_name: string, volume: f32, repeating: bool);
    stop_audio_stream:          (stream_id: s64);
    set_audio_stream_volume:    (stream_id: s64, volume: f32);

    // TODO(jt): @Correctness We use this to chain music tracks together, but this is imprecise, and
    // creates abrupt changes in audio. Probably not true for Sound_Player, but for Web Audio, we
    // can schedule a sound to play ahead of time. Something to think about in the future design of
    // this API.
    is_audio_stream_playing:    (stream_id: s64) -> bool;
}
