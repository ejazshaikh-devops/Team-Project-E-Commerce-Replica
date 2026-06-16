// user-service/index.js
const express  = require('express');
const cors     = require('cors');
const helmet   = require('helmet');
const morgan   = require('morgan');
const bcrypt   = require('bcryptjs');
const jwt      = require('jsonwebtoken');
const db       = require('./shared/db');

const app    = express();
const PORT   = process.env.PORT || 3004;
const SECRET = process.env.JWT_SECRET || 'abhi-ejaz-shop-secret-change-in-prod';

app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan('combined'));

// ── Middleware: verify JWT ────────────────────────────────
function auth(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ success: false, error: 'No token provided' });
  try {
    req.user = jwt.verify(token, SECRET);
    next();
  } catch {
    res.status(401).json({ success: false, error: 'Invalid or expired token' });
  }
}

// ── Health ────────────────────────────────────────────────
app.get('/health', (_, res) => res.json({ status: 'healthy', service: 'user-service', ts: new Date() }));

// ── REGISTER ──────────────────────────────────────────────
app.post('/api/auth/register', async (req, res) => {
  try {
    const { name, email, password, phone } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ success: false, error: 'Name, email and password are required' });
    }
    if (password.length < 6) {
      return res.status(400).json({ success: false, error: 'Password must be at least 6 characters' });
    }

    const [[existing]] = await db.execute('SELECT id FROM users WHERE email = ?', [email]);
    if (existing) return res.status(409).json({ success: false, error: 'Email already registered' });

    const hash = await bcrypt.hash(password, 12);
    const [result] = await db.execute(
      'INSERT INTO users (name, email, password_hash, phone) VALUES (?,?,?,?)',
      [name, email, hash, phone || null]
    );

    const token = jwt.sign({ id: result.insertId, email, role: 'customer' }, SECRET, { expiresIn: '7d' });
    res.status(201).json({
      success: true,
      message: 'Account created successfully! 🎉',
      data: { id: result.insertId, name, email, role: 'customer' },
      token
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── LOGIN ─────────────────────────────────────────────────
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const [[user]] = await db.execute(
      'SELECT id, name, email, password_hash, role, avatar FROM users WHERE email = ?', [email]
    );
    if (!user) return res.status(401).json({ success: false, error: 'Invalid email or password' });

    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) return res.status(401).json({ success: false, error: 'Invalid email or password' });

    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, SECRET, { expiresIn: '7d' });
    res.json({
      success: true,
      message: `Welcome back, ${user.name}! 👋`,
      data: { id: user.id, name: user.name, email: user.email, role: user.role, avatar: user.avatar },
      token
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET profile ───────────────────────────────────────────
app.get('/api/user/profile', auth, async (req, res) => {
  try {
    const [[user]] = await db.execute(
      'SELECT id, name, email, phone, avatar, role, created_at FROM users WHERE id = ?', [req.user.id]
    );
    const [addresses] = await db.execute('SELECT * FROM addresses WHERE user_id = ?', [req.user.id]);
    res.json({ success: true, data: { ...user, addresses } });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── UPDATE profile ────────────────────────────────────────
app.put('/api/user/profile', auth, async (req, res) => {
  try {
    const { name, phone, avatar } = req.body;
    await db.execute('UPDATE users SET name = ?, phone = ?, avatar = ? WHERE id = ?', [name, phone, avatar, req.user.id]);
    res.json({ success: true, message: 'Profile updated' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── CHANGE password ───────────────────────────────────────
app.put('/api/user/password', auth, async (req, res) => {
  try {
    const { current, newPass } = req.body;
    const [[user]] = await db.execute('SELECT password_hash FROM users WHERE id = ?', [req.user.id]);
    const match = await bcrypt.compare(current, user.password_hash);
    if (!match) return res.status(400).json({ success: false, error: 'Current password is wrong' });
    const hash = await bcrypt.hash(newPass, 12);
    await db.execute('UPDATE users SET password_hash = ? WHERE id = ?', [hash, req.user.id]);
    res.json({ success: true, message: 'Password changed successfully' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── ADD address ───────────────────────────────────────────
app.post('/api/user/addresses', auth, async (req, res) => {
  try {
    const { label, street, city, state, pincode, country = 'India', is_default } = req.body;
    if (is_default) await db.execute('UPDATE addresses SET is_default = FALSE WHERE user_id = ?', [req.user.id]);
    const [r] = await db.execute(
      'INSERT INTO addresses (user_id, label, street, city, state, pincode, country, is_default) VALUES (?,?,?,?,?,?,?,?)',
      [req.user.id, label || 'Home', street, city, state, pincode, country, is_default || false]
    );
    res.status(201).json({ success: true, id: r.insertId, message: 'Address saved' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET addresses ─────────────────────────────────────────
app.get('/api/user/addresses', auth, async (req, res) => {
  try {
    const [addresses] = await db.execute('SELECT * FROM addresses WHERE user_id = ?', [req.user.id]);
    res.json({ success: true, data: addresses });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── DELETE address ────────────────────────────────────────
app.delete('/api/user/addresses/:id', auth, async (req, res) => {
  try {
    await db.execute('DELETE FROM addresses WHERE id = ? AND user_id = ?', [req.params.id, req.user.id]);
    res.json({ success: true, message: 'Address deleted' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── WISHLIST ──────────────────────────────────────────────
app.get('/api/user/wishlist', auth, async (req, res) => {
  try {
    const [items] = await db.execute(
      `SELECT p.id, p.name, p.slug, p.brand, p.price, p.mrp, p.discount_pct,
              JSON_UNQUOTE(JSON_EXTRACT(p.images, '$[0]')) AS image, p.rating, w.added_at
       FROM wishlists w
       JOIN products p ON p.id = w.product_id
       WHERE w.user_id = ?
       ORDER BY w.added_at DESC`, [req.user.id]
    );
    res.json({ success: true, data: items });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/user/wishlist', auth, async (req, res) => {
  try {
    const { product_id } = req.body;
    await db.execute(
      'INSERT IGNORE INTO wishlists (user_id, product_id) VALUES (?,?)', [req.user.id, product_id]
    );
    res.json({ success: true, message: 'Added to wishlist' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.delete('/api/user/wishlist/:productId', auth, async (req, res) => {
  try {
    await db.execute('DELETE FROM wishlists WHERE user_id = ? AND product_id = ?', [req.user.id, req.params.productId]);
    res.json({ success: true, message: 'Removed from wishlist' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── Verify token (used by API gateway) ───────────────────
app.post('/api/auth/verify', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '') || req.body.token;
  if (!token) return res.status(401).json({ valid: false });
  try {
    const decoded = jwt.verify(token, SECRET);
    res.json({ valid: true, user: decoded });
  } catch {
    res.status(401).json({ valid: false });
  }
});

app.listen(PORT, () => console.log(`👤 User Service running on :${PORT}`));
module.exports = app;
