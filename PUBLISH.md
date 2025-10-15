HTML5 export and GitHub Pages deployment

This project can be published as a browser game using Godot’s Web export and GitHub Pages. Follow these steps for a clean setup that also works with Firebase Google Sign‑In.

1) Create the docs folder
- The repo already contains `docs/` (tracked via `.gitkeep`). GitHub Pages can serve this folder directly from the `main` branch.

2) Add a Web export preset in Godot (Project → Export)
- Add… → Web
- For GitHub Pages, set these options:
  - Threads: Off
  - Compression (Gzip/Brotli): Off
  - Use Relative Paths: On
  - Canvas Resize Policy: Project
  - Heap (WASM memory): 256 MB (increase if needed)
- Export to: `docs/index.html`

3) Export and test locally
- From the repo root, serve `docs/` over HTTP (not file://):
  - Python: `cd docs && python -m http.server 8000`
  - Then open: http://localhost:8000

4) Enable GitHub Pages
- GitHub → Repository → Settings → Pages
- Source: `main` / `/docs`
- Save. Your site will be available at:
  - https://kmberry1989.github.io/match-3-game-template/

5) Configure Google OAuth (Web) and Firebase
- Google Cloud Console → APIs & Services → Credentials → Web OAuth Client
  - Authorized JavaScript origins:
    - `https://kmberry1989.github.io`
  - Authorized redirect URIs (add both forms):
    - `https://kmberry1989.github.io/match-3-game-template/`
    - `https://kmberry1989.github.io/match-3-game-template/index.html`
  - Copy the Web Client ID and set it locally in `addons/godot-firebase/.env`:
    - `webClientId="YOUR_WEB_OAUTH_CLIENT_ID.apps.googleusercontent.com"`
- Firebase Console → Authentication → Settings → Authorized domains
  - Add: `kmberry1989.github.io`

6) Commit and push
- Commit the exported files in `docs/` and push to `main`.
- Pages will publish automatically.

Optional: VS Code tasks
- You can run export and local serve using Tasks (see `.vscode/tasks.json`). Adjust the preset name if you don’t use the default "Web".

Notes
- Keep Compression Off and Threads Off on GitHub Pages (no custom headers available).
- For other hosts that support custom headers (Netlify/Vercel), you can enable Compression and (optionally) Threads with COOP/COEP headers.
