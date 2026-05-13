const { Router } = require('express');
const { getDb } = require('../firebase');

const router = Router();

router.post('/', async (req, res) => {
  try {
    const entry = {
      uid: req.body.uid,
      missionId: req.body.missionId || null,
      lat: req.body.lat,
      lng: req.body.lng,
      alt: req.body.alt,
      speed: req.body.speed,
      heading: req.body.heading,
      battery: req.body.battery,
      mode: req.body.mode,
      timestamp: Date.now(),
    };
    await getDb().collection('telemetry').add(entry);
    res.json({ status: 'ok' });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

router.get('/:missionId', async (req, res) => {
  try {
    const snap = await getDb()
      .collection('telemetry')
      .where('missionId', '==', req.params.missionId)
      .orderBy('timestamp', 'asc')
      .limit(5000)
      .get();
    const data = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    res.json(data);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
