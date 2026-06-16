// order-service/index.js
const express = require('express');
const cors    = require('cors');
const helmet  = require('helmet');
const morgan  = require('morgan');
const axios   = require('axios');
const db      = require('./shared/db');

const app  = express();
const PORT = process.env.PORT || 3003;

const PRODUCT_SVC = process.env.PRODUCT_SERVICE_URL || 'http://product-service:3001';
const CART_SVC    = process.env.CART_SERVICE_URL    || 'http://cart-service:3002';

app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan('combined'));

function generateOrderNumber() {
  const ts   = Date.now().toString(36).toUpperCase();
  const rand = Math.random().toString(36).substring(2, 6).toUpperCase();
  return `AEO-${ts}-${rand}`;
}

// ── Health ────────────────────────────────────────────────
app.get('/health', (_, res) => res.json({ status: 'healthy', service: 'order-service', ts: new Date() }));

// ── Place order ───────────────────────────────────────────
app.post('/api/orders', async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const { user_id, session_id, address, payment_method = 'cod', notes } = req.body;

    // 1. Fetch cart
    const cartRes = await axios.get(`${CART_SVC}/api/cart`, { params: { user_id, session_id } });
    const cart = cartRes.data.data;

    if (!cart.items || cart.items.length === 0) {
      await conn.rollback();
      return res.status(400).json({ success: false, error: 'Cart is empty' });
    }

    // 2. Calculate totals
    const subtotal = cart.subtotal;
    const shipping = subtotal >= 499 ? 0 : 49;
    const total    = subtotal + shipping;

    // 3. Reduce stock via product-service
    await axios.post(`${PRODUCT_SVC}/api/products/reduce-stock`, {
      items: cart.items.map(i => ({ product_id: i.product_id, quantity: i.quantity }))
    });

    // 4. Create order
    const [orderResult] = await conn.execute(
      `INSERT INTO orders
         (order_number, user_id, status, payment_status, payment_method,
          subtotal, shipping, total,
          shipping_name, shipping_street, shipping_city, shipping_state, shipping_pincode, notes)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [
        generateOrderNumber(), user_id,
        'confirmed', payment_method === 'cod' ? 'pending' : 'paid',
        payment_method, subtotal, shipping, total,
        address?.name, address?.street, address?.city, address?.state, address?.pincode,
        notes || null
      ]
    );
    const orderId = orderResult.insertId;

    // 5. Create order items
    for (const item of cart.items) {
      await conn.execute(
        `INSERT INTO order_items (order_id, product_id, name, image, quantity, price, total)
         VALUES (?,?,?,?,?,?,?)`,
        [orderId, item.product_id, item.name, item.image || '', item.quantity, item.price, item.price * item.quantity]
      );
    }

    await conn.commit();

    // 6. Clear cart (non-critical, don't fail order if this errors)
    try {
      await axios.delete(`${CART_SVC}/api/cart`, { params: { user_id, session_id } });
    } catch (_) {}

    // 7. Return full order
    const order = await getOrderById(orderId);
    res.status(201).json({ success: true, data: order, message: 'Order placed successfully! 🎉' });

  } catch (err) {
    await conn.rollback();
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  } finally {
    conn.release();
  }
});

// ── Get orders for user ───────────────────────────────────
app.get('/api/orders', async (req, res) => {
  try {
    const { user_id, status, page = 1, limit = 10 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);
    const where  = ['o.user_id = ?'];
    const params = [user_id];

    if (status) { where.push('o.status = ?'); params.push(status); }

    const [orders] = await db.execute(
      `SELECT o.id, o.order_number, o.status, o.payment_status, o.payment_method,
              o.subtotal, o.shipping, o.total, o.created_at,
              o.shipping_name, o.shipping_city, o.shipping_state,
              COUNT(oi.id) AS item_count
       FROM orders o
       LEFT JOIN order_items oi ON oi.order_id = o.id
       WHERE ${where.join(' AND ')}
       GROUP BY o.id
       ORDER BY o.created_at DESC
       LIMIT ${parseInt(limit)} OFFSET ${offset}`,
      params
    );

    const [[{ total }]] = await db.execute(
      `SELECT COUNT(*) AS total FROM orders o WHERE ${where.join(' AND ')}`,
      params
    );

    res.json({ success: true, data: orders, pagination: { page: parseInt(page), limit: parseInt(limit), total } });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── Get single order ──────────────────────────────────────
app.get('/api/orders/:id', async (req, res) => {
  try {
    const order = await getOrderById(req.params.id);
    if (!order) return res.status(404).json({ success: false, error: 'Order not found' });
    res.json({ success: true, data: order });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── Get order by order_number ─────────────────────────────
app.get('/api/orders/track/:orderNumber', async (req, res) => {
  try {
    const [[order]] = await db.execute(
      'SELECT id FROM orders WHERE order_number = ?', [req.params.orderNumber]
    );
    if (!order) return res.status(404).json({ success: false, error: 'Order not found' });
    const full = await getOrderById(order.id);
    res.json({ success: true, data: full });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── Cancel order ──────────────────────────────────────────
app.patch('/api/orders/:id/cancel', async (req, res) => {
  try {
    const [[order]] = await db.execute('SELECT status FROM orders WHERE id = ?', [req.params.id]);
    if (!order) return res.status(404).json({ success: false, error: 'Order not found' });
    if (!['pending', 'confirmed'].includes(order.status)) {
      return res.status(400).json({ success: false, error: `Cannot cancel order in ${order.status} state` });
    }
    await db.execute("UPDATE orders SET status = 'cancelled' WHERE id = ?", [req.params.id]);

    // Restore stock
    const [items] = await db.execute('SELECT product_id, quantity FROM order_items WHERE order_id = ?', [req.params.id]);
    for (const item of items) {
      await axios.patch(`${PRODUCT_SVC}/api/products/${item.product_id}/stock`, { delta: item.quantity })
        .catch(() => {});
    }
    res.json({ success: true, message: 'Order cancelled' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── Admin: Update status ──────────────────────────────────
app.patch('/api/orders/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    const valid = ['pending','confirmed','processing','shipped','delivered','cancelled','refunded'];
    if (!valid.includes(status)) return res.status(400).json({ success: false, error: 'Invalid status' });
    await db.execute('UPDATE orders SET status = ? WHERE id = ?', [status, req.params.id]);
    res.json({ success: true, message: `Order updated to ${status}` });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── Helper: full order with items ────────────────────────
async function getOrderById(id) {
  const [[order]] = await db.execute(
    `SELECT o.*, u.name AS user_name, u.email AS user_email
     FROM orders o
     JOIN users u ON u.id = o.user_id
     WHERE o.id = ?`, [id]
  );
  if (!order) return null;
  const [items] = await db.execute('SELECT * FROM order_items WHERE order_id = ?', [id]);

  // Build timeline
  const statusTimeline = {
    pending:    { label: 'Order Placed',    icon: '📋', done: true },
    confirmed:  { label: 'Order Confirmed', icon: '✅', done: ['confirmed','processing','shipped','delivered'].includes(order.status) },
    processing: { label: 'Processing',      icon: '⚙️', done: ['processing','shipped','delivered'].includes(order.status) },
    shipped:    { label: 'Shipped',         icon: '🚚', done: ['shipped','delivered'].includes(order.status) },
    delivered:  { label: 'Delivered',       icon: '📦', done: order.status === 'delivered' },
  };

  return { ...order, items, timeline: statusTimeline };
}

app.listen(PORT, () => console.log(`📦 Order Service running on :${PORT}`));
module.exports = app;
