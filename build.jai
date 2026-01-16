/*

Making a build:

1) Note the release date in CHANGELOG.txt.
2) Run a developer build and make the asset build (ESCAPE -> DO ASSET BUILD).

(steps for native)

3) Make a release non-developer build.
4) Copy the executable to the target directory.
5) Copy the asset_build directory to the target directory and rename it to data.
6) Copy data/puzzles into the data directory in the target directory. (This is not automated yet)
7) Copy over readme and changelog files to the target directory.

(steps for wasm)

3) Update GAME_VERSION constant in wasm_main.js
4) Update WELCOME_HTML constant in wasm.main.js

5) Delete the public directory
6) Make a wasm release non-developer build. This automatically creates the public directory and copies some files into it.
7) Copy the asset_build directory to the public directory and rename it to data.
8) Copy data/puzzles into the public/data. (This is not automated yet)

*/

#import "Compiler";
#import "Basic";
#import "File";
#import "File_Utilities";

// TODO(jt): @Cleanup This is the second (and creates the third and fourth) compiler workspace (the
// default metaprogram has the first). As far as I am aware, the way to simplify is to replace the
// Default_Metaprogram with our own, either with a commandline switch, or by putting
// Default_Metaprogram.jai in the project-local modules. This would bring us back to three
// workspaces.
//
// If we decided to change the top level metaprogram, this file can be folded into that one and removed.
//
// The reason for not doing that is that we'd have to then maintain it.
build :: () {
    make_directory_if_it_does_not_exist("build");

    // TODO(jt): @Cleanup Default_Metaprogram also has a -release flag. After it runs, we detect, if
    // it was passed and tweak stuff. We wouldn't have to do this, if there was just the one (our)
    // metaprogram.
    //
    // TODO(jt): For some reason Default_Metapgrogram doesn't use 03 for release, only 02. Find out why.
    do_release_build   := false;
    do_developer_build := false;
    do_compile_native  := true;
    do_compile_wasm    := false;

    for get_build_options().compile_time_command_line {
        if      it == "-developer"     do_developer_build = true;
        else if it == "-no-developer"  do_developer_build = false;
        else if it == "-native"        do_compile_native = true;
        else if it == "-no-native"     do_compile_native = false;
        else if it == "-wasm"          do_compile_wasm = true;
        else if it == "-no-wasm"       do_compile_wasm = false;
    }

    for get_toplevel_command_line() {
        if it == "-release"  do_release_build = true;
    }

    if !do_compile_native && !do_compile_wasm {
        log_error("One of -native -wasm must be enabled");
        return;
    }

    if do_compile_native {
        w := compiler_create_workspace("Native");

        options := get_build_options(); // Inherited from what Default_Metaprogram set.

        options.output_executable_name = "diagrams";
        options.output_path            = "build";
        options.intermediate_path      = "build/.build_native";

        set_build_options(options, w);

        add_build_string(tprint("__BUILD_OPTIONS_DEVELOPER_BUILD :: %;", do_developer_build), w);
        add_build_file("src/native_main.jai", w);
    }

    if do_compile_wasm {
        w := compiler_create_workspace("WASM");

        options := get_build_options(); // Inherited from what Default_Metaprogram set.

        options.output_executable_name              = "diagrams";
        options.output_path                         = "build";
        options.intermediate_path                   = "build/.build_wasm";
        options.output_type                         = .DYNAMIC_LIBRARY;
        options.backend                             = .LLVM;
        options.os_target                           = .WASM;
        options.cpu_target                          = .CUSTOM;
        options.emit_debug_info                     = .DWARF;
        options.backtrace_on_crash                  = .OFF;           // Runtime_Support_Crash_Handler doesn’t support WASM (yet?)
        // TODO(jt): @Cleanup bulk-memory seems to be enabled by default now? At least removing this
        // line doesn't seem to break anything.
        options.llvm_options.target_system_features = "+bulk-memory"; // "This options is needed so that "memcpy" and "memset" are mapped to "memory.copy" and "memory.fill" instructions in WASM.
        options.llvm_options.enable_split_modules   = false;
        options.llvm_options.function_sections      = true;           // To get around "LLVM ERROR: section already has a defining function: .text"

        if do_release_build {
            // I couldn't get the DWARF debug symbols to work in Chrome (and Firefox doesn't even
            // pretend), so they are disabled for release builds.
            set_optimization(*options, .OPTIMIZED_SMALL, preserve_debug_info = false);
        }

        // examples/wasm sets this at 24 kilobytes, but that wasn't enough for our big
        // functions. Not sure what the LLVM default is, though.
        STACK_SIZE :: 128 << 10;
        options.additional_linker_arguments = .["--stack-first", "-z", tprint("stack-size=%", STACK_SIZE)];

        set_build_options(options, w);

        // TODO(jt): Unless we ship our own Runtime_Support without an allocator, which I imagine
        // would cascade into shipping our own everything, we have to provide a default allocator
        // that doesn't need the CRT. The current Default_Allocator is a stripped down version of
        // rpmalloc on x64, but calls into the CRT on all other platforms, including WASM.
        remap_import(w, "*", "Default_Allocator", "Walloc");

        compiler_begin_intercept(w);

        add_build_string(tprint("__BUILD_OPTIONS_DEVELOPER_BUILD :: %;", do_developer_build), w);
        add_build_file("src/wasm_lib.jai", w);

        // TODO(jt): This message loop currently just waits for complation to finish so that we can
        // move files around. Factor it out so that it can potentially service all workspaces.
        while true {
            message := compiler_wait_for_message();
            if message.kind == .COMPLETE {
                break;
            }
        }

        compiler_end_intercept(w);

        make_directory_if_it_does_not_exist("public");

        Copy :: struct {
            source: string;
            dest:   string;
        }

        print("\n");
        for Copy.[
            Copy.{ "build/diagrams.wasm",    "public/diagrams.wasm" },
            Copy.{ "src/wasm_renderer.js",   "public/renderer.js" },
            Copy.{ "src/wasm_renderer.wgsl", "public/renderer.wgsl" },
            Copy.{ "src/wasm_main.js",       "public/main.js" },
            Copy.{ "src/wasm_index.html",    "public/index.html" },
            Copy.{ "src/wasm_font_IBMPlexMono-Light.ttf", "public/IBMPlexMono-Light.ttf" },
        ] {
            log("Copying % -> %", it.source, it.dest);
            if !copy_file(it.source, it.dest) {
                log_error("Failed to copy file % -> %", it.source, it.dest);
            }
        }
        print("\n");
    }

    // Do not output anything for this workspace.
    set_build_options_dc(.{ do_output = false });
}

#run build();
