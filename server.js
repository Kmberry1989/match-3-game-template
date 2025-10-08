// Server code for your Godot game (server.js)
const WebSocket = require('ws');

const wss = new WebSocket.Server({ port: 8080 });

let waitingPlayer = null;
const playerPairs = new Map();

console.log('WebSocket server started and listening on port 8080...');

wss.on('connection', ws => {
    console.log('Player connected.');

    if (waitingPlayer) {
        console.log('Matching players...');
        playerPairs.set(ws, waitingPlayer);
        playerPairs.set(waitingPlayer, ws);
        waitingPlayer = null;

        // Tell both players the game has started
        const startMsg = JSON.stringify({ type: 'game_started' });
        ws.send(startMsg);
        playerPairs.get(ws).send(startMsg);
    } else {
        waitingPlayer = ws;
        ws.send(JSON.stringify({ type: 'waiting' }));
    }

    ws.on('message', message => {
        const opponent = playerPairs.get(ws);
        if (opponent && opponent.readyState === WebSocket.OPEN) {
            opponent.send(message);
        }
    });

    ws.on('close', () => {
        console.log('Player disconnected.');
        const opponent = playerPairs.get(ws);
        if (opponent) {
            opponent.send(JSON.stringify({ type: 'opponent_disconnected' }));
            playerPairs.delete(ws);
            playerPairs.delete(opponent);
        }
        if (ws === waitingPlayer) {
            waitingPlayer = null;
        }
    });
});
