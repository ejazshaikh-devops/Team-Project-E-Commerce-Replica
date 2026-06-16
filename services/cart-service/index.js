// cart-service/index.js
const express = require('express');
const cors    = require('cors');
const helmet  = require('helmet');
const morgan  = require('morgan');
const db      = require('./shared/db');

const app  = express();
const PORT = process.env.PORT || 3002;

app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan('combined'));

// ── Health ────────────────────────────────────────────────
app.get('/health', (_, res) => res.json({ status: 'healthy', service: 'cart-service', ts: new Date() }));

// helper: get or create cart
async function getOrCreateCart(userId, sessionId) {
  const conn = await db.getConnection();
  try {
    let cart;
    if (userId) {
      [[cart]] = await conn.execute('SELECT id FROM carts WHERE user_id = ? LIMIT 1', [userId]);
    } else {
      [[cart]] = await conn.execute('SELECT id FROM carts WHERE session_id = ? LIMIT 1', [sessionId]);
    }
    if (!cart) {
      const [r] = await conn.execute(
        'INSERT INTO carts (user_id, session_id) VALUES (?,?)',
        [userId || null, sessionId || null]
      );
      cart = { id: r.insertId };
    }
    return cart.id;
  } finally {
    conn.release();
  }
}

// helper: load cart with items
async function loadCart(cartId) {
  const [items] = await db.execute(
    `SELECT ci.id, ci.product_id, ci.quantity, ci.price,
            p.name, p.slug, p.brand, p.mrp, p.discount_pct, p.stock,
            JSON_UNQUOTE(JSON_EXTRACT(p.images, '$[0]')) AS image
     FROM cart_items ci
     JOIN products p ON p.id = ci.product_id
     WHERE ci.cart_id = ?`,
    [cartId]
  );
  const subtotal = items.reduce((s, i) => s + i.price * i.quantity, 0);
  const itemCount = items.reduce((s, i) => s + i.quantity, 0);
  return { cart_id: cartId, items, subtotal: +subtotal.toFixed(2), item_count: itemCount };
}

// ── GET cart ──────────────────────────────────────────────
app.get('/api/cart', async (req, res) => {
  try {
    const { user_id, session_id } = req.query;
    const cartId = await getOrCreateCart(user_id, session_id);
    res.json({ success: true, data: await loadCart(cartId) });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── ADD item ──────────────────────────────────────────────
app.post('/api/cart/add', async (req, res) => {
  try {
    const { user_id, session_id, product_id, quantity = 1 } = req.body;
    const cartId = await getOrCreateCart(user_id, session_id);

    // Fetch current price from products table
    const [[product]] = await db.execute('SELECT price, stock, name FROM products WHERE id = ? AND is_active = TRUE', [product_id]);
    if (!product) return res.status(404).json({ success: false, error: 'Product not found' });
    if (product.stock < quantity) return res.status(400).json({ success: false, error: 'Insufficient stock' });

    // Upsert cart item
    await db.execute(
      `INSERT INTO cart_items (cart_id, product_id, quantity, price)
       VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)`,
      [cartId, product_id, quantity, product.price]
    );

    res.json({ success: true, data: await loadCart(cartId), message: `${product.name} added to cart` });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── UPDATE quantity ───────────────────────────────────────
app.put('/api/cart/item/:itemId', async (req, res) => {
  try {
    const { quantity } = req.body;
    const { user_id, session_id } = req.query;
    const cartId = await getOrCreateCart(user_id, session_id);

    if (quantity <= 0) {
      await db.execute('DELETE FROM cart_items WHERE id = ? AND cart_id = ?', [req.params.itemId, cartId]);
    } else {
      await db.execute('UPDATE cart_items SET quantity = ? WHERE id = ? AND cart_id = ?', [quantity, req.params.itemId, cartId]);
    }
    res.json({ success: true, data: await loadCart(cartId) });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── REMOVE item ───────────────────────────────────────────
app.delete('/api/cart/item/:itemId', async (req, res) => {
  try {
    const { user_id, session_id } = req.query;
    const cartId = await getOrCreateCart(user_id, session_id);
    await db.execute('DELETE FROM cart_items WHERE id = ? AND cart_id = ?', [req.params.itemId, cartId]);
    res.json({ success: true, data: await loadCart(cartId) });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── CLEAR cart ────────────────────────────────────────────
app.delete('/api/cart', async (req, res) => {
  try {
    const { user_id, session_id } = req.query;
    const cartId = await getOrCreateCart(user_id, session_id);
    await db.execute('DELETE FROM cart_items WHERE cart_id = ?', [cartId]);
    res.json({ success: true, message: 'Cart cleared' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── Merge session cart → user cart (on login) ─────────────
app.post('/api/cart/merge', async (req, res) => {
  try {
    const { user_id, session_id } = req.body;
    const [[sessionCart]] = await db.execute('SELECT id FROM carts WHERE session_id = ?', [session_id]);
    if (!sessionCart) return res.json({ success: true, message: 'Nothing to merge' });

    let [[userCart]] = await db.execute('SELECT id FROM carts WHERE user_id = ?', [user_id]);
    if (!userCart) {
      await db.execute('UPDATE carts SET user_id = ?, session_id = NULL WHERE id = ?', [user_id, sessionCart.id]);
      return res.json({ success: true });
    }

    // Move items from session cart to user cart
    const [sessionItems] = await db.execute('SELECT * FROM cart_items WHERE cart_id = ?', [sessionCart.id]);
    for (const item of sessionItems) {
      await db.execute(
        `INSERT INTO cart_items (cart_id, product_id, quantity, price)
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)`,
        [userCart.id, item.product_id, item.quantity, item.price]
      );
    }
    await db.execute('DELETE FROM carts WHERE id = ?', [sessionCart.id]);
    res.json({ success: true, data: await loadCart(userCart.id) });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.listen(PORT, () => console.log(`🛒 Cart Service running on :${PORT}`));
module.exports = app;
