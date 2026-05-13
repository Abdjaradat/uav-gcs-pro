const clients = new Set();

function handleTelemetryWS(ws) {
  clients.add(ws);
  console.log(`WS client connected (${clients.size} total)`);

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data);
      broadcast(msg, ws);
    } catch { /* ignore malformed */ }
  });

  ws.on('close', () => {
    clients.delete(ws);
    console.log(`WS client disconnected (${clients.size} total)`);
  });

  ws.send(JSON.stringify({ type: 'connected', timestamp: Date.now() }));
}

function broadcast(msg, sender) {
  clients.forEach((client) => {
    if (client !== sender && client.readyState === 1) {
      client.send(JSON.stringify(msg));
    }
  });
}

module.exports = { handleTelemetryWS, broadcast };
