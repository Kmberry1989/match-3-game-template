# Godot Engine Match3 Game Template
![screenshot](https://user-images.githubusercontent.com/31243845/140289774-6552bb39-0747-4c4a-bd5f-6e92ae855b99.png)
## Simple WebSocket Multiplayer (Addon + Server)

This project includes a lightweight Godot 4 addon and a Node.js example server to enable a basic lobby/room multiplayer flow with WebSockets. Mobile-friendly and minimal.

Features
- Automatic server connection (configurable URL).
- Simple lobby: create/join rooms by code.
- Synchronized match start when all are ready.
- Automatic spawning/management of player nodes in `PlayerContainer`.
- Example Node.js WebSocket server in `Server/`.

Quick Start
1) Enable the plugin
- The addon lives in `addons/SimpleMultiplayer` and is already enabled in `project.godot`.
- Two autoloads are added: `WebSocketClient` and `MultiplayerManager`.

2) Run the server
- In `Server/`:
  - `npm install`
  - `npm start` (default `ws://127.0.0.1:9090`)

3) Configure URL (optional)
- Project Settings -> simple_multiplayer -> `server_url`
- Local: `ws://127.0.0.1:9090`
- Online: `wss://your-hostname`

4) Try the lobby
- Launch `Scenes/Menu.tscn`, press `Multiplayer`, then Create/Join a code.
- Press `Ready` on all clients; game loads once everyone is ready.

How it works
- `WebSocketClient` handles the socket and emits: `connection_succeeded`, `room_created`, `room_joined`, `start_game`, `player_joined`, `player_left`.
- `MultiplayerManager` listens and spawns `Scenes/NetPlayer.tscn` under `PlayerContainer` (added to `Scenes/Game.tscn`). Local players send positional state; remotes mirror it.

## Web build

The `docs` folder contains the exported web build for the game which can be hosted on any static web server or service.

If you need the iOS WebAssembly memory cap workaround mentioned in the issue tracker, follow the step-by-step instructions in [`docs/web-memory-cap-usage.md`](docs/web-memory-cap-usage.md) to copy the patched loader files into your own export.

