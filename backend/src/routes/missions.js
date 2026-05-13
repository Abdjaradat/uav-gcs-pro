const { Router } = require('express');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../firebase');

const router = Router();

router.get('/', async (req, res) => {
  try {
    const { uid } = req.query;
    let query = getDb().collection('missions').orderBy('createdAt', 'desc');
    if (uid) query = query.where('uid', '==', uid);
    const snap = await query.get();
    const missions = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    res.json(missions);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const mission = {
      id: uuidv4(),
      uid: req.body.uid,
      name: req.body.name || 'Untitled',
      waypoints: req.body.waypoints || [],
      status: 'draft',
      createdAt: Date.now(),
      updatedAt: Date.now(),
    };
    await getDb().collection('missions').doc(mission.id).set(mission);
    res.json(mission);
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const ref = getDb().collection('missions').doc(req.params.id);
    await ref.update({ ...req.body, updatedAt: Date.now() });
    const doc = await ref.get();
    res.json({ id: doc.id, ...doc.data() });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    await getDb().collection('missions').doc(req.params.id).delete();
    res.json({ deleted: req.params.id });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
