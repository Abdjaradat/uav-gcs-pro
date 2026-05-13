require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { WebSocketServer } = require('ws');
const http = require('http');
const { initFirebase } = require('./firebase');
const missionRoutes = require('./routes/missions');
const telemetryRoutes = require('./routes/telemetry');
const authRoutes = require('./routes/auth');
const { handleTelemetryWS } = require('./ws/telemetry');

const app = express();
const server = http.createServer(app);

app.use(cors());
app.use(express.json());

initFirebase();

app.use('/api/auth', authRoutes);
app.use('/api/missions', missionRoutes);
app.use('/api/telemetry', telemetryRoutes);

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', version: '4.0.0', timestamp: Date.now() });
});

const wss = new WebSocketServer({ server, path: '/ws/telemetry' });
wss.on('connection', handleTelemetryWS);

const PORT = process.env.PORT || 10000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`UAV GCS Backend running on port ${PORT}`);
});
