import { WebSocketServer } from 'ws';

const PORT = process.env.PORT || 9090;
const wss = new WebSocketServer({ port: PORT });

// Rooms: code -> { clients: Set(ws), ready: Set(ws), ids: Map(ws->id) }
const rooms = new Map();
let nextClientId = 1;
const matchmakingQueue = [];
const id_map = new Map();

function send(ws, obj) {
  try { ws.send(JSON.stringify(obj)); } catch (_) {}
}

function broadcast(room, obj, exceptWs = null) {
  const txt = JSON.stringify(obj);
  for (const c of room.clients) {
    if (c !== exceptWs && c.readyState === c.OPEN) {
      c.send(txt);
    }
  }
}

function genCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let s = '';
  for (let i = 0; i < 4; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s;
}

function roomOf(ws) {
  for (const [code, room] of rooms) {
    if (room.clients.has(ws)) return [code, room];
  }
  return [null, null];
}

wss.on('connection', (ws) => {
  const id = String(nextClientId++);
  id_map.set(ws, id);
  send(ws, { type: 'welcome', id });

  ws.on('message', (data) => {
    let msg = {};
    try { msg = JSON.parse(data.toString()); } catch (_) { return; }
    const t = msg.type;
    if (t === 'find_match') {
        matchmakingQueue.push(ws);
        if (matchmakingQueue.length >= 2) {
            const [player1, player2] = matchmakingQueue.splice(0, 2);
            const code = genCode();
            rooms.set(code, { clients: new Set([player1, player2]), ready: new Set(), ids: new Map() });
            const room = rooms.get(code);
            const id1 = id_map.get(player1);
            const id2 = id_map.get(player2);
            room.ids.set(player1, id1);
            room.ids.set(player2, id2);

            send(player1, { type: 'room_joined', code, id: id1, is_host: true });
            send(player2, { type: 'room_joined', code, id: id2, is_host: false });
            
            const players = Array.from(room.ids.values());
            send(player1, { type: 'room_state', players });
            send(player2, { type: 'room_state', players });
        } else {
            send(ws, { type: 'waiting_for_match' });
        }
    }
    else if (t === 'create_room') {
      let code = (msg.code || '').toString().toUpperCase();
      if (!code) {
        // generate unique 4-char code
        do { code = genCode(); } while (rooms.has(code));
      }
      if (!rooms.has(code)) {
        rooms.set(code, { clients: new Set(), ready: new Set(), ids: new Map() });
      }
      const room = rooms.get(code);
      room.clients.add(ws);
      room.ids.set(ws, id);
      send(ws, { type: 'room_created', code });
      // Send current state (players) to creator
      const players = Array.from(room.ids.values());
      send(ws, { type: 'room_state', players });
      broadcast(room, { type: 'player_joined', id }, ws);
    }
    else if (t === 'join_room') {
      const code = (msg.code || '').toString().toUpperCase();
      const room = rooms.get(code);
      if (!room) return;
      room.clients.add(ws);
      room.ids.set(ws, id);
      send(ws, { type: 'room_joined', code, id });
      // Send current state to joiner
      const players = Array.from(room.ids.values());
      send(ws, { type: 'room_state', players });
      broadcast(room, { type: 'player_joined', id }, ws);
    }
    else if (t === 'leave_room') {
      const [code, room] = roomOf(ws);
      if (!room) return;
      room.clients.delete(ws);
      room.ready?.delete(ws);
      const pid = room.ids.get(ws);
      room.ids.delete(ws);
      broadcast(room, { type: 'player_left', id: pid });
      if (room.clients.size === 0) rooms.delete(code);
    }
    else if (t === 'ready') {
      const [code, room] = roomOf(ws);
      if (!room) return;
      room.ready.add(ws);
      if (room.ready.size === room.clients.size && room.clients.size > 0) {
        broadcast(room, { type: 'start_game', mode: 'coop', seed: Date.now() });
      }
    }
    else if (t === 'start_game') {
      const [, room] = roomOf(ws);
      if (!room) return;
      const payload = { ...msg, type: 'start_game' };
      if (!payload.seed) payload.seed = Date.now();
      if (!payload.mode) payload.mode = 'coop';
      broadcast(room, payload);
    }
    else if (t === 'state') {
      const [, room] = roomOf(ws);
      if (!room) return;
      const pid = room.ids.get(ws) || id;
      broadcast(room, { type: 'state', id: pid, x: msg.x, y: msg.y }, ws);
    }
    else if (t === 'game') {
      const [, room] = roomOf(ws);
      if (!room) return;
      const pid = room.ids.get(ws) || id;
      const payload = { ...msg, id: pid };
      broadcast(room, payload);
    }
  });

  ws.on('close', () => {
    const index = matchmakingQueue.indexOf(ws);
    if (index > -1) {
        matchmakingQueue.splice(index, 1);
    }

    const [code, room] = roomOf(ws);
    if (!room) return;
    room.clients.delete(ws);
    room.ready?.delete(ws);
    const pid = room.ids.get(ws);
    room.ids.delete(ws);
    broadcast(room, { type: 'player_left', id: pid });
    if (room.clients.size === 0) rooms.delete(code);
  });
});

console.log(`Simple WS server on port ${PORT}`);