// product-service/index.js
const express  = require('express');
const cors     = require('cors');
const helmet   = require('helmet');
const morgan   = require('morgan');
const db       = require('./shared/db');

const app  = express();
const PORT = process.env.PORT || 3001;

app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan('combined'));

// ── Health ────────────────────────────────────────────────
app.get('/health', (_, res) => res.json({ status: 'healthy', service: 'product-service', ts: new Date() }));

// ── Get all categories ────────────────────────────────────
app.get('/api/categories', async (_, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT c.*, COUNT(p.id) AS product_count
       FROM categories c
       LEFT JOIN products p ON p.category_id = c.id AND p.is_active = TRUE
       WHERE c.parent_id IS NULL AND c.is_active = TRUE
       GROUP BY c.id
       ORDER BY c.sort_order`
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── List products (with filters) ─────────────────────────
// GET /api/products?category=clothes&brand=Nike&min=500&max=5000&sort=price_asc&page=1&limit=20
app.get('/api/products', async (req, res) => {
  try {
    const {
      category, brand, min, max,
      sort = 'created_at_desc',
      page = 1, limit = 20,
      q, featured
    } = req.query;

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const params = [];
    const where  = ['p.is_active = TRUE'];

    // Category filter — accept slug OR id
    if (category) {
      where.push('(c.slug = ? OR c.parent_id = (SELECT id FROM categories WHERE slug = ?))');
      params.push(category, category);
    }
    if (brand)    { where.push('p.brand = ?');           params.push(brand);         }
    if (min)      { where.push('p.price >= ?');          params.push(parseFloat(min)); }
    if (max)      { where.push('p.price <= ?');          params.push(parseFloat(max)); }
    if (featured) { where.push('p.is_featured = TRUE'); }
    if (q)        { where.push('MATCH(p.name, p.description, p.brand) AGAINST(? IN BOOLEAN MODE)'); params.push(`${q}*`); }

    const orderMap = {
      price_asc:   'p.price ASC',
      price_desc:  'p.price DESC',
      rating_desc: 'p.rating DESC',
      newest:      'p.created_at DESC',
      popular:     'p.sold_count DESC',
    };
    const orderBy = orderMap[sort] || 'p.created_at DESC';

    const whereClause = where.join(' AND ');

    const [products] = await db.execute(
      `SELECT p.id, p.name, p.slug, p.short_desc, p.brand, p.price, p.mrp,
              p.discount_pct, p.stock, p.rating, p.review_count, p.images,
              p.is_featured, p.tags, c.name AS category_name, c.slug AS category_slug
       FROM products p
       JOIN categories c ON c.id = p.category_id
       WHERE ${whereClause}
       ORDER BY ${orderBy}
       LIMIT ${parseInt(limit)} OFFSET ${offset}`,
      params
    );

    const [[{ total }]] = await db.execute(
      `SELECT COUNT(*) AS total
       FROM products p
       JOIN categories c ON c.id = p.category_id
       WHERE ${whereClause}`,
      params
    );

    // Parse JSON fields
    const parsed = products.map(p => ({
      ...p,
      images: safeJson(p.images, []),
      tags:   safeJson(p.tags, []),
    }));

    res.json({
      success: true,
      data: parsed,
      pagination: { page: parseInt(page), limit: parseInt(limit), total, pages: Math.ceil(total / parseInt(limit)) }
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── Get single product by slug ────────────────────────────
app.get('/api/products/:slug', async (req, res) => {
  try {
    const [[product]] = await db.execute(
      `SELECT p.*, c.name AS category_name, c.slug AS category_slug
       FROM products p
       JOIN categories c ON c.id = p.category_id
       WHERE p.slug = ? AND p.is_active = TRUE`,
      [req.params.slug]
    );

    if (!product) return res.status(404).json({ success: false, error: 'Product not found' });

    // Related products
    const [related] = await db.execute(
      `SELECT id, name, slug, brand, price, mrp, discount_pct, images, rating
       FROM products
       WHERE category_id = ? AND id != ? AND is_active = TRUE
       ORDER BY rating DESC LIMIT 6`,
      [product.category_id, product.id]
    );

    // Reviews (last 5)
    const [reviews] = await db.execute(
      `SELECT r.*, u.name AS user_name
       FROM reviews r
       JOIN users u ON u.id = r.user_id
       WHERE r.product_id = ?
       ORDER BY r.created_at DESC LIMIT 5`,
      [product.id]
    );

    res.json({
      success: true,
      data: {
        ...product,
        images:  safeJson(product.images, []),
        tags:    safeJson(product.tags, []),
        specs:   safeJson(product.specs, {}),
        related: related.map(r => ({ ...r, images: safeJson(r.images, []) })),
        reviews,
      }
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── Get featured products ──────────────────────────────────
app.get('/api/products/featured/all', async (_, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT p.id, p.name, p.slug, p.brand, p.price, p.mrp,
              p.discount_pct, p.images, p.rating, p.review_count,
              c.name AS category_name, c.slug AS category_slug
       FROM products p
       JOIN categories c ON c.id = p.category_id
       WHERE p.is_featured = TRUE AND p.is_active = TRUE
       ORDER BY p.rating DESC LIMIT 12`
    );
    res.json({ success: true, data: rows.map(r => ({ ...r, images: safeJson(r.images, []) })) });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── Search products ───────────────────────────────────────
app.get('/api/search', async (req, res) => {
  const { q } = req.query;
  if (!q) return res.json({ success: true, data: [] });
  try {
    const [rows] = await db.execute(
      `SELECT id, name, slug, brand, price, mrp, discount_pct, images, rating, category_id
       FROM products
       WHERE is_active = TRUE AND (name LIKE ? OR brand LIKE ?)
       LIMIT 10`,
      [`%${q}%`, `%${q}%`]
    );
    res.json({ success: true, data: rows.map(r => ({ ...r, images: safeJson(r.images, []) })) });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── Admin: Create product ──────────────────────────────────
app.post('/api/products', async (req, res) => {
  try {
    const { name, slug, description, short_desc, sku, category_id, brand, price, mrp, stock, images, tags, specs, is_featured } = req.body;
    const [result] = await db.execute(
      `INSERT INTO products (name,slug,description,short_desc,sku,category_id,brand,price,mrp,stock,images,tags,specs,is_featured)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [name, slug, description, short_desc, sku, category_id, brand, price, mrp, stock || 0,
       JSON.stringify(images || []), JSON.stringify(tags || []), JSON.stringify(specs || {}), is_featured || false]
    );
    res.status(201).json({ success: true, id: result.insertId });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── Admin: Update stock ────────────────────────────────────
app.patch('/api/products/:id/stock', async (req, res) => {
  try {
    await db.execute('UPDATE products SET stock = stock + ? WHERE id = ?', [req.body.delta, req.params.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── Reduce stock (called by order-service) ────────────────
app.post('/api/products/reduce-stock', async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const { items } = req.body; // [{ product_id, quantity }]
    for (const item of items) {
      const [[p]] = await conn.execute('SELECT stock FROM products WHERE id = ? FOR UPDATE', [item.product_id]);
      if (!p || p.stock < item.quantity) {
        await conn.rollback();
        return res.status(400).json({ success: false, error: `Insufficient stock for product ${item.product_id}` });
      }
      await conn.execute(
        'UPDATE products SET stock = stock - ?, sold_count = sold_count + ? WHERE id = ?',
        [item.quantity, item.quantity, item.product_id]
      );
    }
    await conn.commit();
    res.json({ success: true });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ success: false, error: err.message });
  } finally {
    conn.release();
  }
});

function safeJson(val, fallback) {
  if (!val) return fallback;
  try { return typeof val === 'string' ? JSON.parse(val) : val; }
  catch { return fallback; }
}

app.listen(PORT, () => console.log(`🛍  Product Service running on :${PORT}`));
module.exports = app;
