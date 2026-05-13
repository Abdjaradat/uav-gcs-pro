const { Router } = require('express');
const { getAuth } = require('../firebase');

const router = Router();

router.post('/verify', async (req, res) => {
  try {
    const { idToken } = req.body;
    const decoded = await getAuth().verifyIdToken(idToken);
    res.json({ uid: decoded.uid, email: decoded.email, name: decoded.name });
  } catch (e) {
    res.status(401).json({ error: e.message });
  }
});

router.post('/register', async (req, res) => {
  try {
    const { email, password, displayName } = req.body;
    const user = await getAuth().createUser({ email, password, displayName });
    res.json({ uid: user.uid, email: user.email });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

module.exports = router;
