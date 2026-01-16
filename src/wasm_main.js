const GAME_VERSION = "0.2.7 (18 November 2025)";
const WELCOME_HTML = `
<p>
This is a wasm port of a game prototype I created in summer 2025.
</p>

<p>
While the prototype has interesting ideas, it also has serious design problems that are not ironed
out as of the current version.
</p>

<p>
<a href="https://store.steampowered.com/app/1511780/Last_Call_BBS/">Dungeons and Diagrams</a> by Zachtronics was a big influence at the beginning of the project, and its
spirit still lingers here, albeit becoming fainter.
</p>

<p>
The game is played with keyboard and mouse. It automatically saves progress.
</p>

<p>Feedback is appreciated. My email is yanchith@withoutfearofwindorvertigo.com</p>

<p style="font-size: 12px; margin-top: 100px; text-align: end">Game version: ${GAME_VERSION}</p>
`;

// TODO(jt): Link to people who have websites. This will require us to remove the replaceAll @Hack.
const CREDITS_HTML = `
<div>
<h3>Design</h3>
Game Design                                                          Jan Toth<br/>
Puzzle Design                                                        Jan Toth<br/>
Original Ruleset                                                     Zach Barth<br/>

<h3>Programming</h3>
Gameplay                                                             Jan Toth<br/>
Engine                                                               Jan Toth<br/>

<h3>Art</h3>
Tiny Dungeon                                                         Oryx Design Lab<br/>

<h3>Music</h3>
RPG Music Pack                                                       Leohpaz<br/>
Ambiences Pack                                                       JDSherbert<br/>

<h3>Sound effects</h3>
Minifantasy Forgotten Plains                                         Leohpaz<br/>
Book Parchment UI                                                    Leohpaz<br/>
RPG Essentials                                                       Leohpaz<br/>
Ultimate UI SFX                                                      JDSherbert<br/>

<h3>Used Software</h3>
JAI Compiler and Modules                                             Jonathan Blow<br/>
                                                                     Raphael Luba<br/>
stb_vorbis                                                           Sean Barett<br/>
<h3>Playtesters</h3>
Lucia Tusimova                      Ondrej Slintak                   Stefan Mijucic<br/>
Dusan Hetlerovic                    Areta Tothova                    Stefan Urbanek<br/>
@Auex                               @Rupi                            @TechnicBeam<br/>
Matthew VanDevander<br/>

<h3>Special thanks</h3>
Zach Barth                          Matthew VanDevander              Lucia Tusimova<br/>
</div>
`.replaceAll(/ /g, "\u00a0");

// Numeric types in JAI, WASM and JavaScript (work in progress as I discover them)
//
// JAI      WASM    JS
//
// pointer  i64     BigInt
// s64      i64     BigInt
// s32      i32     number
// s16      i32     number
// bool     i32     number
//
// f64      f64     number
// f32      f32     number

async function main() {
    const [initialWidth, initialHeight] = computeDesiredDimensions();

    const container        = document.createElement("div");
    const canvas           = document.createElement("canvas");
    const overlay          = document.createElement("div");
    const overlayHtml      = document.createElement("div");
    const overlayLink      = document.createElement("a");
    const overlayButton    = document.createElement("button");

    container.style.display            = "flex";
    container.style["justify-content"] = "center";
    container.style["align-items"]     = "center";
    container.style.position           = "relative";
    container.style.margin             = "0px";
    container.style.border             = "0px";
    container.style.padding            = "0px";
    container.style.width              = "100vw";
    container.style.height             = "100vh";

    canvas.width  = initialWidth;
    canvas.height = initialHeight;
    canvas.style.width  = `${initialWidth}px`;
    canvas.style.height = `${initialHeight}px`;
    canvas.addEventListener("contextmenu", (event) => {
        event.preventDefault();
    });

    overlay.style.display             = "flex";
    overlay.style["flex-direction"]   = "column";
    overlay.style["justify-content"]  = "center";
    overlay.style["align-items"]      = "center";
    overlay.style.position            = "absolute";
    overlay.style.margin              = "0px";
    overlay.style.border              = "0px";
    overlay.style.padding             = "0px";
    overlay.style.top                 = "0px";
    overlay.style.left                = "0px";
    overlay.style.width               = "100vw";
    overlay.style.height              = "100vh";
    overlay.style["min-height"]       = "min-content";
    overlay.style.overflow            = "scroll";
    overlay.style["z-index"]          = 1;
    overlay.style["background-color"] = "#151515ff";

    let viewingCredits = false;

    overlayHtml.innerHTML = WELCOME_HTML;
    overlayHtml.style.margin  = "0px";
    overlayHtml.style.border  = "0px";
    overlayHtml.style.padding = "0px";
    overlayHtml.style.width   = "800px";
    overlayHtml.style.color   = "#ffffff";

    overlayLink.innerText = "View credits"
    overlayLink.style.display       = "block";
    overlayLink.style["margin-top"] = "20px";
    overlayLink.style.color         = "#ffffff";
    overlayLink.style["text-align"] = "end";

    overlayLink.addEventListener("click", () => {
        viewingCredits = !viewingCredits;
        if (viewingCredits) {
            overlayHtml.innerHTML = CREDITS_HTML;
            overlayHtml.appendChild(overlayLink);
            overlayLink.innerText = "View info";
        } else {
            overlayHtml.innerHTML = WELCOME_HTML;
            overlayHtml.appendChild(overlayLink);
            overlayLink.innerText = "View credits";
        }
    });

    overlayButton.disabled = true;
    overlayButton.style.display       = "block";
    overlayButton.style["margin-top"]    = "60px";
    overlayButton.style["margin-bottom"] = "5px"; // @Hack to make it visible when overflowing.
    overlayButton.style.width         = "800px";
    overlayButton.style.height        = "25px";
    overlayButton.style.color         = "#ffffff"
    overlayButton.style.background    = "transparent";
    overlayButton.style.border        = "0px";
    overlayButton.style.outline       = "1px solid #ffffff";

    overlayHtml.appendChild(overlayLink);
    overlay.appendChild(overlayHtml);
    overlay.appendChild(overlayButton);
    container.appendChild(canvas);
    container.appendChild(overlay);

    document.body.appendChild(container);

    const progress = {
        majorSteps: ["Compiling Game", "Initializing Renderer", "Processing Assets", "Processing Puzzles"],
        majorDone: 0,
        minorTotal: 0,
        minorDone: 0,
    };

    updateProgress(overlayButton, progress);

    let wasm = await WebAssembly.instantiateStreaming(window.fetch("diagrams.wasm"), imports);
    progress.majorDone += 1;
    updateProgress(overlayButton, progress);

    // TODO(jt): Grow memory here to a reasonable size right here.
    memory = wasm.instance.exports.memory;

    // Yes, there is a lot of fuctions. Essentially, there are just 2 (4, if you count the
    // allocator), and the rest is there just to poke/peek at datastructures, which is trivial to do
    // in C, but gross in javascript.

    const diagramsGetTextureFilenameData  = wasm.instance.exports.diagrams_get_texture_filename_data;
    const diagramsGetTextureFilenameCount = wasm.instance.exports.diagrams_get_texture_filename_count;
    const diagramsGetTextureCount         = wasm.instance.exports.diagrams_get_texture_count;
    const diagramsGetSfxFilenameData      = wasm.instance.exports.diagrams_get_sfx_filename_data;
    const diagramsGetSfxFilenameCount     = wasm.instance.exports.diagrams_get_sfx_filename_count;
    const diagramsGetSfxCount             = wasm.instance.exports.diagrams_get_sfx_count;
    const diagramsGetMusicFilenameData    = wasm.instance.exports.diagrams_get_music_filename_data;
    const diagramsGetMusicFilenameCount   = wasm.instance.exports.diagrams_get_music_filename_count;
    const diagramsGetMusicCount           = wasm.instance.exports.diagrams_get_music_count;

    const diagramsGameAlloc                  = wasm.instance.exports.diagrams_game_alloc;
    const diagramsGameGetPuzzleCount         = wasm.instance.exports.diagrams_game_get_puzzle_count;
    const diagramsGameGetPuzzleFilenameData  = wasm.instance.exports.diagrams_game_get_puzzle_filename_data;
    const diagramsGameGetPuzzleFilenameCount = wasm.instance.exports.diagrams_game_get_puzzle_filename_count;
    const diagramsGameInit                   = wasm.instance.exports.diagrams_game_init;
    const diagramsGameUpdateAndRender        = wasm.instance.exports.diagrams_game_update_and_render;

    const diagramsPlatformAlloc = wasm.instance.exports.diagrams_platform_alloc;

    const diagramsInputAlloc            = wasm.instance.exports.diagrams_input_alloc;
    const diagramsInputSetTime          = wasm.instance.exports.diagrams_input_set_time;
    const diagramsInputSetWindowSize    = wasm.instance.exports.diagrams_input_set_window_size;
    const diagramsInputSetMousePosition = wasm.instance.exports.diagrams_input_set_mouse_position;
    const diagramsInputClearKeyEvents   = wasm.instance.exports.diagrams_input_clear_key_events;
    const diagramsInputPushKeyEvent     = wasm.instance.exports.diagrams_input_push_key_event;

    const diagramsRenderListsAlloc                    = wasm.instance.exports.diagrams_render_lists_alloc;
    const diagramsRenderListsGetRectCount             = wasm.instance.exports.diagrams_render_lists_get_rect_count;
    const diagramsRenderListsRectsGetRectX            = wasm.instance.exports.diagrams_render_lists_rects_get_rect_x;
    const diagramsRenderListsRectsGetRectY            = wasm.instance.exports.diagrams_render_lists_rects_get_rect_y;
    const diagramsRenderListsRectsGetRectW            = wasm.instance.exports.diagrams_render_lists_rects_get_rect_w;
    const diagramsRenderListsRectsGetRectH            = wasm.instance.exports.diagrams_render_lists_rects_get_rect_h;
    const diagramsRenderListsRectsGetTextureRectX     = wasm.instance.exports.diagrams_render_lists_rects_get_texture_rect_x;
    const diagramsRenderListsRectsGetTextureRectY     = wasm.instance.exports.diagrams_render_lists_rects_get_texture_rect_y;
    const diagramsRenderListsRectsGetTextureRectW     = wasm.instance.exports.diagrams_render_lists_rects_get_texture_rect_w;
    const diagramsRenderListsRectsGetTextureRectH     = wasm.instance.exports.diagrams_render_lists_rects_get_texture_rect_h;
    const diagramsRenderListsRectsGetTextureNameCount = wasm.instance.exports.diagrams_render_lists_rects_get_texture_name_count;
    const diagramsRenderListsRectsGetTextureNameData  = wasm.instance.exports.diagrams_render_lists_rects_get_texture_name_data;
    const diagramsRenderListsRectsGetColorR           = wasm.instance.exports.diagrams_render_lists_rects_get_color_r;
    const diagramsRenderListsRectsGetColorG           = wasm.instance.exports.diagrams_render_lists_rects_get_color_g;
    const diagramsRenderListsRectsGetColorB           = wasm.instance.exports.diagrams_render_lists_rects_get_color_b;
    const diagramsRenderListsRectsGetColorA           = wasm.instance.exports.diagrams_render_lists_rects_get_color_a;

    const diagramsAlloc = wasm.instance.exports.diagrams_alloc;
    const diagramsFree  = wasm.instance.exports.diagrams_free;

    const renderer = await rendererInitialize(canvas);
    if (!renderer.initialized) {
        const p = document.createElement("p");
        p.innerText   = "This game requires WebGPU to play, but your browser does not support it.";
        p.style.color = "#ff0000";

        overlay.appendChild(p);

        return;
    }


    // Upload solid texture for color drawing (this is not optional!)
    rendererUploadTextureRgbaUnorm(renderer, "", new Uint8Array([255, 255, 255, 255]), 1, 1);

    progress.majorDone += 1;
    updateProgress(overlayButton, progress);

    const assetManifest = [];

    const textureCount = diagramsGetTextureCount();
    for (let i = 0n; i < textureCount; ++i) {
        const filenameCount = Number(diagramsGetTextureFilenameCount(i));
        const filenameData = Number(diagramsGetTextureFilenameData(i));

        assetManifest.push({ type: "texture", pathPrefix: "./data/textures/", name: stringFromMemory(filenameData, filenameCount) });
    }

    const sfxCount = diagramsGetSfxCount();
    for (let i = 0n; i < sfxCount; ++i) {
        const filenameCount = Number(diagramsGetSfxFilenameCount(i));
        const filenameData = Number(diagramsGetSfxFilenameData(i));

        assetManifest.push({ type: "audio", pathPrefix: "./data/audio/", name: stringFromMemory(filenameData, filenameCount) });
    }

    const musicCount = diagramsGetMusicCount();
    for (let i = 0n; i < musicCount; ++i) {
        const filenameCount = Number(diagramsGetMusicFilenameCount(i));
        const filenameData = Number(diagramsGetMusicFilenameData(i));

        assetManifest.push({ type: "audio", pathPrefix: "./data/audio/", name: stringFromMemory(filenameData, filenameCount) });
    }

    progress.minorTotal = Number(textureCount + sfxCount + musicCount);
    progress.minorDone  = 0;
    updateProgress(overlayButton, progress);

    const assetWork = assetManifest.map(async (asset) => {
        const path = asset.pathPrefix + asset.name;

        log(`Downloading asset: ${path}`);

        const response = await fetch(path);
        if (!response.ok) {
            logError(`Failed to download asset: ${path}`);
            return;
        }

        const blob       = await response.blob();
        const blobBuffer = await blob.arrayBuffer();
        const blobBytes  = new Uint8Array(blobBuffer);

        // TODO(jt): @Cleanup At least for textures, there is no reason to poke them into WASM
        // memory right now, because the game leaves it to the renderer to stream the assets in, and
        // never touches them itself, but this might eventually change, so we poke anyway.
        const length = blobBytes.length;
        const pointer = diagramsAlloc(BigInt(length));

        const byteView = byteViewFromMemory(Number(pointer), length);
        byteView.set(blobBytes, 0);

        // We store both pointer and length as s64, because that's how WASM will want to read it.
        memoryAssetLocations.set(path, { pointer, length: BigInt(length) });
        log(`Poked ${formatSize(length)} of asset: ${path}`);

        switch (asset.type) {
            case "texture":
                // Use the browser to decode into RGBA8Unorm. This is nuts.
                const bitmap = await window.createImageBitmap(blob);
                const width  = bitmap.width;
                const height = bitmap.height;

                const canvas = new OffscreenCanvas(width, height);
                const ctx    = canvas.getContext('2d');

                ctx.drawImage(bitmap, 0, 0);

                const imageData = ctx.getImageData(0, 0, width, height);
                assert(width, imageData.width);
                assert(height, imageData.height);

                rendererUploadTextureRgbaUnorm(renderer, asset.name, imageData.data.buffer, width, height)

                progress.minorDone += 1;
                updateProgress(overlayButton, progress);
                break;
            case "audio":
                const audioBuffer = await audioContext.decodeAudioData(blobBuffer);
                audioBuffers.set(asset.name, audioBuffer);

                progress.minorDone += 1;
                updateProgress(overlayButton, progress);
                break;
            default:
                progress.minorDone += 1;
                updateProgress(overlayButton, progress);
                break;
        }
    });

    await Promise.all(assetWork);
    progress.majorDone += 1;
    progress.minorTotal = 0;
    progress.minorDone  = 0;
    updateProgress(overlayButton, progress);

    const game        = diagramsGameAlloc();
    const platform    = diagramsPlatformAlloc();
    const input       = diagramsInputAlloc();
    const renderLists = diagramsRenderListsAlloc();

    diagramsGameInit(game, platform);
    log(`Memory size after game_init: ${formatSize(memory.buffer.byteLength)}`);

    // TODO(jt): Figure out a way to process all puzzles with the rest of the assets, so we don't
    // have to wait and can instaed work in the shadows.

    const puzzleManifest = [];
    const puzzleCount = diagramsGameGetPuzzleCount(game);
    for (let i = 0n; i < puzzleCount; ++i) {
        const filenameCount = Number(diagramsGameGetPuzzleFilenameCount(game, i));
        const filenameData = Number(diagramsGameGetPuzzleFilenameData(game, i));

        puzzleManifest.push({ pathPrefix: "./data/puzzles/", name: stringFromMemory(filenameData, filenameCount) });
    }

    progress.minorTotal = Number(puzzleCount);
    progress.minorDone  = 0;
    updateProgress(overlayButton, progress);

    const puzzleAssetWork = puzzleManifest.map(async (asset) => {
        // TODO(jt): @Clenaup This is a copypaste (mostly) of the above generic asset processing
        // code. We should merge these back together, but first we either need to declare puzzles at
        // compile-time, or declare all the other assets at runtime and split off a
        // populate-manifest function, so that JavaScript can call it.
        const path = asset.pathPrefix + asset.name + ".txt";

        log(`Downloading asset: ${path}`);

        const response = await fetch(path);
        if (!response.ok) {
            logError(`Failed to download asset: ${path}`);
            return;
        }

        const blob       = await response.blob();
        const blobBuffer = await blob.arrayBuffer();
        const blobBytes  = new Uint8Array(blobBuffer);

        const length = blobBytes.length;
        const pointer = diagramsAlloc(BigInt(length));

        const byteView = byteViewFromMemory(Number(pointer), length);
        byteView.set(blobBytes, 0);

        // We store both pointer and length as s64, because that's how WASM will want to read it.
        memoryAssetLocations.set(path, { pointer, length: BigInt(length) });
        log(`Poked ${formatSize(length)} of asset: ${path}`);

        progress.minorDone += 1;
        updateProgress(overlayButton, progress);
    });

    await Promise.all(puzzleAssetWork);

    progress.majorDone += 1;
    updateProgress(overlayButton, progress);

    const rectInstanceArray = rendererFloat32ArrayCreate(MAX_RECT_INSTANCES * SIZE_OF_RECT_INSTANCE_IN_FIELDS);
    const rectTextureNames  = [];

    function handleOverlayButtonClick() {
        let frameIndex = 0;

        function loop(timeMillis) {
            frameIndex++;
            if (frameIndex > 1000) {
                log(`WASM memory size: ${formatSize(memory.buffer.byteLength)}`);
                frameIndex = 0;
            }

            const timeSeconds = timeMillis * 0.001;

            const canvasClientRect = canvas.getBoundingClientRect();

            diagramsInputSetTime(input, timeSeconds);
            diagramsInputSetWindowSize(input, renderer.surface.canvas.width, renderer.surface.canvas.height);
            diagramsInputSetMousePosition(input, windowMouseX - canvasClientRect.x, windowMouseY - canvasClientRect.y);
            diagramsInputClearKeyEvents(input);
            for (const event of windowKeyEvents) {
                const key = keymap[event.key];
                const pressed = event.pressed;

                if (key) {
                    diagramsInputPushKeyEvent(input, key, pressed);
                }
            }
            windowKeyEvents.length = 0;

            const quit = diagramsGameUpdateAndRender(game, platform, input, renderLists);

            rendererFloat32ArrayClear(rectInstanceArray);
            rectTextureNames.length = 0;

            const rectCount = diagramsRenderListsGetRectCount(renderLists);
            for (let i = 0n; i < rectCount; ++i) {
                // The game's coordinate system is Y-down, but WebGPU's NDC space is Y-up, so we flippity here.
                const canvasHeight = renderer.surface.canvas.height;

                const x = diagramsRenderListsRectsGetRectX(renderLists, i);
                const y = diagramsRenderListsRectsGetRectY(renderLists, i);
                const w = diagramsRenderListsRectsGetRectW(renderLists, i);
                const h = diagramsRenderListsRectsGetRectH(renderLists, i);

                const texX = diagramsRenderListsRectsGetTextureRectX(renderLists, i);
                const texY = diagramsRenderListsRectsGetTextureRectY(renderLists, i);
                const texW = diagramsRenderListsRectsGetTextureRectW(renderLists, i);
                const texH = diagramsRenderListsRectsGetTextureRectH(renderLists, i);

                const r = diagramsRenderListsRectsGetColorR(renderLists, i);
                const g = diagramsRenderListsRectsGetColorG(renderLists, i);
                const b = diagramsRenderListsRectsGetColorB(renderLists, i);
                const a = diagramsRenderListsRectsGetColorA(renderLists, i);

                const textureNameCount = diagramsRenderListsRectsGetTextureNameCount(renderLists, i);
                const textureNameData  = diagramsRenderListsRectsGetTextureNameData(renderLists, i);
                const textureName      = stringFromMemory(Number(textureNameData), Number(textureNameCount));

                if (renderer.textureBindGroups.has(textureName)) {
                    // Rects in the renderer are defined by two points instead of point+dimension,
                    // so we convert here.
                    rendererFloat32ArrayPushRect(rectInstanceArray,
                                                 x, canvasHeight - y, x + w, canvasHeight - (y + h),
                                                 texX, texY, texX + texW, texY + texH,
                                                 r, g, b, a);

                    rectTextureNames.push(textureName);
                } else {
                    logError(`Can not render with unknown texture ${textureName}`);
                }
            }

            rendererDraw(renderer, rectInstanceArray, rectTextureNames);

            if (quit) {
                // Try cleaning up stuff, so that GC can page it out eventually.

                audioStreams.clear();
                audioBuffers.clear();
                audioContext.close();
                audioContext = null;

                memoryAssetLocations.clear();
                memory = null;

                overlay.removeChild(overlayButton);
                overlay.style.display = "flex";

                window.removeEventListener("keydown",   handleWindowKeyDown);
                window.removeEventListener("keyup",     handleWindowKeyUp);
                window.removeEventListener("mousedown", handleWindowMouseDown);
                window.removeEventListener("mouseup",   handleWindowMouseUp);
                window.removeEventListener("mousemove", handleWindowMouseMove);

                window.removeEventListener("resize", handleWindowResize);

                overlayHtml.innerHTML = `<p style="text-align: center;">Thank you for playing</p>`;
            } else {
                window.requestAnimationFrame(loop);
            }
        }

        overlayButton.removeEventListener("click", handleOverlayButtonClick);
        overlay.style.display = "none";

        window.addEventListener("keydown",   handleWindowKeyDown);
        window.addEventListener("keyup",     handleWindowKeyUp);
        window.addEventListener("mousedown", handleWindowMouseDown);
        window.addEventListener("mouseup",   handleWindowMouseUp);
        window.addEventListener("mousemove", handleWindowMouseMove);

        function handleWindowResize() {
            const [width, height] = computeDesiredDimensions();

            canvas.width  = width;
            canvas.height = height;
            canvas.style.width  = `${width}px`;
            canvas.style.height = `${height}px`;
        }

        window.addEventListener("resize", handleWindowResize);

        window.requestAnimationFrame(loop);
    }


    overlayButton.addEventListener("click", handleOverlayButtonClick);
    overlayButton.disabled  = false;
    overlayButton.innerText = "Start";
    overlayButton.style.cursor = "pointer";
}

const imports = {
    env: {
        // Required by Runtime_Support (#foreign)
        wasm_write_string: (s_count, s_data, to_standard_error) => {
            const s = stringFromMemory(Number(s_data), Number(s_count));

            // TODO(jt): @Hack Because most programming languages can append to a buffer in the
            // output stream, but not javascript, we have to account for that here. JAI logger
            // automatically appends a newline if it is not already present by calling
            // write_strings, and so we get that newline as a new entry. If we do, we just ignore it.
            //
            // This is a hack, because there can, in theory, be a legitimate call to write_string
            // with just a newline (although it won't come from the logging API, because that one
            // composes the message into a string before it calls write_string(s)). If we run into
            // it, we'll have to do something more complicated here, perhaps closer to the hack
            // examples/wasm does.
            if (s == "\n") {
                return;
            }

            const timeMillis = window.performance.now();
            const timeSeconds = 0.001 * timeMillis;

            const secondsString = timeSeconds.toLocaleString("en-US", { fractionalSecondDigits: 6 });


            if (to_standard_error) {
                console.error(`[${secondsString}] JAI: ${s}`);
            } else {
                console.log(`[${secondsString}] JAI: ${s}`);
            }
        },

        // Required by Runtime_Support (#foreign)
        wasm_debug_break: () => {
            debugger;
        },

        // Defined by Preload (#intrinsic), used by Basic.
        //
        // TODO(jt): @Cleanup Think about why we need to provide memcmp and explain. This should
        // probably either link to some high-performance intrinsic the browser provides (but maybe
        // it doesn't exist in the WASM spec), or the compiler should have generated assembly for
        // this?
        memcmp: (p1, p2, count) => {
            p1 = Number(p1);
            p2 = Number(p2);
            count = Number(count);

            // TODO(jt): @Speed Do 64-bit compares and downshift to 8-bit for the tail.
            const byteView1 = byteViewFromMemory(p1, count);
            const byteView2 = byteViewFromMemory(p2, count);

            for (let i = 0; i < count; ++i) {
                let b1 = byteView1[i];
                let b2 = byteView2[i];

                let cmp = b1 - b2;
                if (cmp != 0) {
                    return cmp;
                }
            }

            return 0;
        },

        //
        // Our platform functions, required by wasm_lib.jai (#foreign).
        //

        wasm_platform_get_file_size: (path_count, path_data) => {
            const path = stringFromMemory(Number(path_data), Number(path_count));
            const storagePath = localStoragePath(path);

            const item = window.localStorage.getItem(storagePath);

            if (!item) {
                return -1n;
            }

            // TODO(jt): @Speed @Memory Is there a way we can skip decoding for getting the length?
            const itemData = Uint8Array.fromBase64(item);

            return BigInt(itemData.length);
        },

        wasm_platform_read_file: (path_count, path_data, result_count, result_data) => {
            const path = stringFromMemory(Number(path_data), Number(path_count));
            const storagePath = localStoragePath(path);

            const item = window.localStorage.getItem(storagePath);

            if (!item) {
                return -1n;
            }

            const itemData = Uint8Array.fromBase64(item);
            assert(itemData.length == Number(result_count));

            const byteView = byteViewFromMemory(Number(result_data), itemData.length);
            byteView.set(itemData, 0);

            return BigInt(itemData.length);
        },

        wasm_platform_write_file: (path_count, path_data, data_count, data_data) => {
            const path = stringFromMemory(Number(path_data), Number(path_count));
            const data = byteViewFromMemory(Number(data_data), Number(data_count));

            const storagePath = localStoragePath(path);
            const base64 = data.toBase64();
            try {
                window.localStorage.setItem(storagePath, base64);
                return true;
            } catch (e) {
                return false;
            }
        },

        wasm_platform_delete_file: (path_count, path_data) => {
            const path = stringFromMemory(Number(path_data), Number(path_count));
            const storagePath = localStoragePath(path);

            if (window.localStorage.getItem(storagePath) != null) {
                window.localStorage.removeItem(storagePath);
                return true;
            }

            return false;
        },

        wasm_platform_read_asset: (path_count, path_data, result_data_pointer) => {
            // Assets are pre-downloaded and pre-poked into WASM memory. Fortunately, we can do
            // this, because the game is small. If we had to do asset streaming, this would
            // force us to be asynchronous down to the deepest core, but maybe we'd have to be
            // asynchronous there for asset streaming because of other reasons, too.

            const path = stringFromMemory(Number(path_data), Number(path_count));
            const asset = memoryAssetLocations.get(path);

            if (asset) {
                assert(isAlignedTo(Number(result_data_pointer), 8));

                const i64 = new BigInt64Array(memory.buffer);
                i64[Number(result_data_pointer) >> 3] = asset.pointer;

                return asset.length;
            } else {
                return -1n;
            }
        },

        wasm_platform_load_audio: (audio_name_count, audio_name_data, data_count, data_data) => {
            const audioName = stringFromMemory(Number(audio_name_data), Number(audio_name_count));

            // Fortunately, we pre-decoded the audio buffer at init time, so that we don't have to handle
            // async thoughout the rest of the program.
            //
            // Unfortunately, we only did this for the assets that the game declared.
            //
            // Fortunately, the game currently only asks us to load audio that was previously an asset.
            return audioBuffers.has(audioName);
        },

        wasm_platform_play_audio_stream: (stream_id, audio_name_count, audio_name_data, volume, repeating) => {
            const audioName = stringFromMemory(Number(audio_name_data), Number(audio_name_count));

            const audioBuffer = audioBuffers.get(audioName);
            if (!audioBuffer) {
                logError(`Can't play audio stream (${audioName}). Data not loaded.`);
                return;
            }

            log(`Playing audio stream ${stream_id} (${audioName})`);
            assert(audioBuffer instanceof AudioBuffer);

            const sourceNode = new AudioBufferSourceNode(audioContext, { buffer: audioBuffer });
            sourceNode.loop = repeating;

            const gainNode = audioContext.createGain();
            gainNode.gain.value = volume;

            sourceNode.connect(gainNode).connect(audioContext.destination);
            sourceNode.start();

            const currentTimeSeconds = audioContext.currentTime;

            const stream = {
                sourceNode,
                gainNode,
                timeStartSeconds: currentTimeSeconds,
                timeEndSeconds: currentTimeSeconds + audioBuffer.duration,
            };

            audioStreams.set(stream_id, stream);
        },

        wasm_platform_stop_audio_stream: (stream_id) => {
            log(`Stopping (and releasing) audio stream ${stream_id}`);

            const stream = audioStreams.get(stream_id);
            if (audioStreams.get(stream_id)) {
                // We shouldn't need to lerp volume, the game's audio system does that before calling stop.
                stream.gainNode.disconnect();
                audioStreams.remove(stream_id);
            }
        },

        wasm_platform_set_audio_stream_volume: (stream_id, volume) => {
            const stream = audioStreams.get(stream_id);
            if (stream) {
                stream.gainNode.gain.value = volume;
            }
        },

        wasm_platform_is_audio_stream_playing: (stream_id) => {
            const stream = audioStreams.get(stream_id);
            if (!stream) {
                return false;
            }

            if (stream.sourceNode.loop) {
                return true;
            }

            if (audioContext.currentTime >= stream.timeEndSeconds) {
                return false;
            }

            return true;
        },
    },
};

let   memory;                            // WASM memory gets set here after we successfully load the module.
const memoryAssetLocations = new Map();  // Maps from asset path string into pointer and length in where the asset was poked.

const textDecoder = new TextDecoder();

// TODO(jt): @Correctness Suspend audio context on defocus.
let   audioContext = new AudioContext(); // Firefox issues a warning that we create the AudioContext eagerly, but we don't play anything yet, so it is fine?
const audioBuffers = new Map();
const audioStreams = new Map();

const KEY_BACKSPACE = 1;
const KEY_ESCAPE    = 2;
const KEY_SPACEBAR  = 3;

const KEY_E = 4;
const KEY_M = 5;
const KEY_Q = 6;
const KEY_R = 7;
const KEY_S = 8;
const KEY_X = 9;
const KEY_V = 10;
const KEY_Z = 11;

const KEY_ALT   = 12;
const KEY_CTRL  = 13;
const KEY_SHIFT = 14;
const KEY_CMD   = 15;

const MOUSE_BUTTON_LEFT   = 16;
const MOUSE_BUTTON_RIGHT  = 17;
const MOUSE_BUTTON_MIDDLE = 18;

const keymap = {
    "Backspace": KEY_BACKSPACE,
    "Escape":    KEY_ESCAPE,
    " ":         KEY_SPACEBAR,

    "e": KEY_E,
    "E": KEY_E,
    "m": KEY_M,
    "M": KEY_M,
    "q": KEY_Q,
    "Q": KEY_Q,
    "r": KEY_R,
    "R": KEY_R,
    "s": KEY_S,
    "S": KEY_S,
    "x": KEY_X,
    "X": KEY_X,
    "v": KEY_V,
    "V": KEY_V,
    "z": KEY_Z,
    "Z": KEY_Z,

    "Alt":     KEY_ALT,
    "Control": KEY_CTRL,
    "Shift":   KEY_SHIFT,
    "Meta":    KEY_CMD,
    // TODO(jt): Find out if this is really cmd on mac...
    "Cmd":     KEY_CMD,

    0: MOUSE_BUTTON_LEFT,
    1: MOUSE_BUTTON_MIDDLE,
    2: MOUSE_BUTTON_RIGHT,
}

const windowKeyEvents = [];
let   windowMouseX;
let   windowMouseY;

function handleWindowKeyDown(event) {
    const key = event.key;
    windowKeyEvents.push({ key, pressed: 1 });
}

function handleWindowKeyUp(event) {
    const key = event.key;
    windowKeyEvents.push({ key, pressed: 0 });
}

function handleWindowMouseDown(event) {
    const button = event.button;
    windowKeyEvents.push({ key: button, pressed: 1 });
}

function handleWindowMouseUp(event) {
    const button = event.button;
    windowKeyEvents.push({ key: button, pressed: 0 });
}

function handleWindowMouseMove(event) {
    windowMouseX = event.clientX;
    windowMouseY = event.clientY;
}

function updateProgress(elem, progress) {
    let text = "";
    let percentDone = 0;

    if (progress.majorSteps.length) {
        text += progress.majorSteps[progress.majorDone];
        percentDone += 100 * progress.majorDone / progress.majorSteps.length;
    }

    if (progress.minorTotal) {
        text += ` (${progress.minorDone} / ${progress.minorTotal})`;
        percentDone += 100 * progress.minorDone / progress.minorTotal / progress.majorSteps.length;
    }

    elem.innerText = text;
    elem.style.backgroundImage = `linear-gradient(to right, #ffffff00, #ffffff00 ${percentDone}%, #ffffff40 ${percentDone}%, #ffffff40)`;
}

// Used to qualify the path with game version, so that even if we do not change the website address,
// different versions of the game won't be able to see each other's files.
function localStoragePath(path /*string*/) {
    return `${GAME_VERSION} :: ${path}`;
}

function computeDesiredDimensions() {
    // @Volatile These have to change if we change them in the game.
    const desiredAspectWidth  = 24 * 16;
    const desiredAspectHeight = 15 * 16;

    const windowWidth  = window.innerWidth;
    const windowHeight = window.innerHeight;

    let width  = desiredAspectWidth;
    let height = desiredAspectHeight;
    let nextWidth  = width * 2;
    let nextHeight = height * 2;
    while (nextWidth < windowWidth && nextHeight < windowHeight) {
        width  = nextWidth;
        height = nextHeight;
        nextWidth  *= 2;
        nextHeight *= 2;
    }

    return [width, height];
}

function isAssetPath(path /*string*/) {
    return path.startsWith("./data") || path.startsWith("data")
}

function byteViewFromMemory(pointer /*number*/, length /*number*/) {
    const u8 = new Uint8Array(memory.buffer);
    const view = u8.subarray(pointer, pointer + length);

    return view;
}

// TODO(jt): @Speed @Memory We call stringFromMemory in many places, but maybe not all of those need
// a UTF-16 string? Maybe some are fine with UTF-8 bytes, so that we don't have to allocate, copy
// and decode?
function stringFromMemory(pointer /*number*/, length /*number*/) {
    const u8 = new Uint8Array(memory.buffer);
    const view = u8.subarray(pointer, pointer + length);

    return textDecoder.decode(view);
}

function isAlignedTo(address /*number*/, align /*number*/) {
    assert(align > 0, `align must be greater than zero, but is ${align}`);
    assert(isPowerOfTwo(align), `align must be a power of two, but is ${align}`);

    const mask = align - 1;
    return address == (address & ~mask); // Comparison has more precedence than bitwise, so parentheses are necessary
}

function isPowerOfTwo(n /*number*/) {
    return n > 0 && !(n & (n - 1));
}

function formatSize(size /*number*/) {
    if (size > (1 << 30)) {
        return `${size >> 30} gigabyte(s)`;
    } else if (size > (1 << 20)) {
        return `${size >> 20} megabyte(s)`;
    } else if (size > (1 << 10)) {
        return `${size >> 10} kilobyte(s)`;
    } else {
        return `${size} byte(s)`;
    }
}

function log(message /*string*/) {
    const timeMillis = window.performance.now();
    const timeSeconds = 0.001 * timeMillis;

    const secondsString = timeSeconds.toLocaleString("en-US", { fractionalSecondDigits: 6 });

    console.log(`[${secondsString}] JS: ${message}`);
}

function logError(message /*string*/) {
    const timeMillis = window.performance.now();
    const timeSeconds = 0.001 * timeMillis;

    const secondsString = timeSeconds.toLocaleString("en-US", { fractionalSecondDigits: 6 });

    console.error(`[${secondsString}] JS: ${message}`);
}

function assert(condition /*bool*/, message /*string?*/) {
    if (!condition) {
        throw new Error(message || "Assertion failed");
    }
}
