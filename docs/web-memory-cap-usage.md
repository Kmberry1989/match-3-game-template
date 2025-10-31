# iOS WebAssembly Memory Cap Patch

The `docs/index.html` and `docs/index.js` files in this repository include a runtime patch that caps the Godot WebAssembly module's maximum memory to **256 MiB**. This prevents Mobile Safari from rejecting the export after the first launch on iOS devices.

Follow the steps below to apply the patch to your own Godot Web export without needing to open a pull request.

## 1. Export your project for the web

1. In Godot, open **Project → Export…**.
2. Select the **Web** preset and export as usual (either as a folder or a `.zip`).

> **Note:** If you export to a `.zip`, unzip it before continuing so you can replace individual files.

## 2. Copy the patched loader files

1. Locate the patched files in this template repository:
   - [`docs/index.html`](./index.html)
   - [`docs/index.js`](./index.js)
2. Copy both files into your exported web build, replacing the files with the same names that Godot generated.

This injects the JavaScript shim that intercepts WebAssembly compilation and rewrites the memory limits on the fly.

## 3. Upload the patched export to your host

Once the files are replaced, upload or deploy the web export to your hosting provider exactly as you normally would.

The modified loader will now request at most 256 MiB of WebAssembly memory, which allows the game to load on Mobile Safari repeatedly instead of failing after the first run.

## 4. (Optional) Customize the memory cap

If you want to experiment with a different upper limit:

1. Open `index.html` and search for `MAX_MEMORY_PAGES`.
2. Change `4096` to the number of 64 KiB pages you want (e.g. `6144` for 384 MiB).
3. Update the accompanying comment if desired.

Re-exporting from Godot will overwrite the files, so keep a copy of your patched `index.html` and `index.js` handy or reapply the changes after each export.

