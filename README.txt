Hello Stranger!

This is all the source code of my summer 2025 game prototype, playable in browser at:

  https://withoutfearofwindorvertigo.com/prototype/

The assets (textures, music, levels) are not present in this repository, because I am not 100% sure
I have the right to put all of them into the public domain. (I think I do, but I want to be sure
before I do something I shouldn't.)

The JAI compiler is also not yet in the public domain as of the time of writing this, so you
probably don't have a way of compiling the code. If you did, you would build the developer build
with:

  jai build.jai - -developer

... and the release build with:

  jai -release build.jai

For reading the source code, I recommend starting with the entrypoints: build.jai, native_main.jai,
and wasm_main.js. These will eventually lead you to game code, which starts in game.jai.

The code is pretty much identical to what was on my private branch when making the mirror, including
all the unfinished stuff, todo comments, etc.

Enjoy!
