-- ============================================================
-- Abhi+Ejaz Shop — MariaDB Schema + Seed Data
-- Run once on fresh MariaDB instance
-- ============================================================

CREATE DATABASE IF NOT EXISTS abhi_ejaz_shop CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE abhi_ejaz_shop;

-- ============================================================
-- USERS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(100) NOT NULL,
  email         VARCHAR(150) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  phone         VARCHAR(20),
  avatar        VARCHAR(255) DEFAULT NULL,
  role          ENUM('customer','admin') DEFAULT 'customer',
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_email (email)
) ENGINE=InnoDB;

-- ============================================================
-- ADDRESSES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS addresses (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  user_id     INT NOT NULL,
  label       VARCHAR(50) DEFAULT 'Home',
  street      VARCHAR(255) NOT NULL,
  city        VARCHAR(100) NOT NULL,
  state       VARCHAR(100) NOT NULL,
  pincode     VARCHAR(10) NOT NULL,
  country     VARCHAR(100) DEFAULT 'India',
  is_default  BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_id (user_id)
) ENGINE=InnoDB;

-- ============================================================
-- CATEGORIES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS categories (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL UNIQUE,
  slug        VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  icon        VARCHAR(100),
  banner_url  VARCHAR(255),
  parent_id   INT DEFAULT NULL,
  sort_order  INT DEFAULT 0,
  is_active   BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL,
  INDEX idx_slug (slug),
  INDEX idx_parent (parent_id)
) ENGINE=InnoDB;

-- ============================================================
-- PRODUCTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS products (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  name            VARCHAR(255) NOT NULL,
  slug            VARCHAR(255) NOT NULL UNIQUE,
  description     TEXT,
  short_desc      VARCHAR(500),
  sku             VARCHAR(100) UNIQUE,
  category_id     INT NOT NULL,
  brand           VARCHAR(100),
  price           DECIMAL(10,2) NOT NULL,
  mrp             DECIMAL(10,2) NOT NULL,
  discount_pct    INT GENERATED ALWAYS AS (ROUND((mrp - price) / mrp * 100)) STORED,
  stock           INT DEFAULT 0,
  sold_count      INT DEFAULT 0,
  rating          DECIMAL(3,2) DEFAULT 0.00,
  review_count    INT DEFAULT 0,
  images          JSON,
  tags            JSON,
  specs           JSON,
  is_active       BOOLEAN DEFAULT TRUE,
  is_featured     BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (category_id) REFERENCES categories(id),
  INDEX idx_category (category_id),
  INDEX idx_brand (brand),
  INDEX idx_price (price),
  FULLTEXT idx_search (name, description, brand)
) ENGINE=InnoDB;

-- ============================================================
-- CART TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS carts (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  user_id     INT,
  session_id  VARCHAR(100),
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user (user_id),
  INDEX idx_session (session_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cart_items (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  cart_id     INT NOT NULL,
  product_id  INT NOT NULL,
  quantity    INT NOT NULL DEFAULT 1,
  price       DECIMAL(10,2) NOT NULL,
  added_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (cart_id) REFERENCES carts(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id),
  UNIQUE KEY uq_cart_product (cart_id, product_id),
  INDEX idx_cart (cart_id)
) ENGINE=InnoDB;

-- ============================================================
-- ORDERS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS orders (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  order_number    VARCHAR(50) NOT NULL UNIQUE,
  user_id         INT NOT NULL,
  status          ENUM('pending','confirmed','processing','shipped','delivered','cancelled','refunded') DEFAULT 'pending',
  payment_status  ENUM('pending','paid','failed','refunded') DEFAULT 'pending',
  payment_method  VARCHAR(50) DEFAULT 'cod',
  subtotal        DECIMAL(10,2) NOT NULL,
  discount        DECIMAL(10,2) DEFAULT 0.00,
  shipping        DECIMAL(10,2) DEFAULT 0.00,
  total           DECIMAL(10,2) NOT NULL,
  address_id      INT,
  shipping_name   VARCHAR(100),
  shipping_street VARCHAR(255),
  shipping_city   VARCHAR(100),
  shipping_state  VARCHAR(100),
  shipping_pincode VARCHAR(10),
  notes           TEXT,
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  INDEX idx_user (user_id),
  INDEX idx_status (status),
  INDEX idx_order_number (order_number)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_items (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  order_id    INT NOT NULL,
  product_id  INT NOT NULL,
  name        VARCHAR(255) NOT NULL,
  image       VARCHAR(255),
  quantity    INT NOT NULL,
  price       DECIMAL(10,2) NOT NULL,
  total       DECIMAL(10,2) NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id),
  INDEX idx_order (order_id)
) ENGINE=InnoDB;

-- ============================================================
-- REVIEWS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS reviews (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  product_id  INT NOT NULL,
  user_id     INT NOT NULL,
  rating      TINYINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  title       VARCHAR(200),
  body        TEXT,
  verified    BOOLEAN DEFAULT FALSE,
  helpful     INT DEFAULT 0,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id),
  UNIQUE KEY uq_review (product_id, user_id),
  INDEX idx_product (product_id)
) ENGINE=InnoDB;

-- ============================================================
-- WISHLIST TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS wishlists (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  user_id     INT NOT NULL,
  product_id  INT NOT NULL,
  added_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  UNIQUE KEY uq_wish (user_id, product_id)
) ENGINE=InnoDB;

-- ============================================================
-- SEED: CATEGORIES
-- ============================================================
INSERT INTO categories (name, slug, description, icon, sort_order) VALUES
('Clothing',      'clothes',     'Fashion for men, women & kids',          '👕', 1),
('Electronics',   'electronics', 'Phones, laptops, gadgets & accessories', '📱', 2),
('Footwear',      'footwear',    'Shoes, sandals, sneakers & more',        '👟', 3),
('Home & Living', 'home',        'Furniture, decor & kitchen',             '🏠', 4),
('Beauty',        'beauty',      'Skincare, makeup & grooming',            '💄', 5),
('Books',         'books',       'Fiction, non-fiction, textbooks',        '📚', 6);

-- Sub-categories
INSERT INTO categories (name, slug, parent_id, sort_order) VALUES
('Men',    'men-clothing',   1, 1),
('Women',  'women-clothing', 1, 2),
('Kids',   'kids-clothing',  1, 3),
('Mobiles','mobiles',        2, 1),
('Laptops','laptops',        2, 2),
('Audio',  'audio',          2, 3);

-- ============================================================
-- SEED: PRODUCTS — CLOTHING
-- ============================================================
INSERT INTO products (name, slug, description, short_desc, sku, category_id, brand, price, mrp, stock, rating, review_count, images, tags, specs, is_featured) VALUES

-- Men Clothing
('Levi''s Classic White T-Shirt',
 'levis-classic-white-tshirt',
 'Premium 100% cotton crew neck t-shirt with a relaxed fit. Perfect for casual everyday wear. Pre-shrunk fabric that retains its shape wash after wash.',
 '100% Cotton | Regular Fit | Machine Washable',
 'CLO-M-001', 1, 'Levi''s', 549.00, 999.00, 250, 4.3, 1240,
 '["https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=400","https://images.unsplash.com/photo-1503341733017-1901578f9f1e?w=400"]',
 '["tshirt","men","cotton","casual","white"]',
 '{"material":"100% Cotton","fit":"Regular","neck":"Crew Neck","sleeve":"Half Sleeve","wash":"Machine Wash"}',
 TRUE),

('Allen Solly Slim Fit Chinos',
 'allen-solly-slim-chinos',
 'Smart casual chinos in stretch cotton blend. Slim fit with 4-pocket styling. Ideal for office wear or weekend outings.',
 'Stretch Cotton | Slim Fit | 5-Pocket',
 'CLO-M-002', 1, 'Allen Solly', 1299.00, 2299.00, 150, 4.4, 876,
 '["https://images.unsplash.com/photo-1542272604-787c3835535d?w=400","https://images.unsplash.com/photo-1473966968600-fa801b869a1a?w=400"]',
 '["chinos","men","slim-fit","formal","casual"]',
 '{"material":"97% Cotton 3% Elastane","fit":"Slim","closure":"Zip & Button","pockets":"5-Pocket"}',
 TRUE),

('Peter England Formal Shirt',
 'peter-england-formal-shirt',
 'Classic formal shirt with fine check pattern. Wrinkle-resistant fabric for all-day freshness. Ideal for corporate settings.',
 'Wrinkle Resistant | Slim Fit | Full Sleeve',
 'CLO-M-003', 1, 'Peter England', 899.00, 1799.00, 180, 4.2, 654,
 '["https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=400"]',
 '["shirt","men","formal","office","check"]',
 '{"material":"60% Cotton 40% Polyester","fit":"Slim","collar":"Spread","sleeve":"Full Sleeve"}',
 FALSE),

-- Women Clothing
('Biba Anarkali Kurta',
 'biba-anarkali-kurta',
 'Elegant Anarkali style kurta with beautiful floral print. Made from soft rayon fabric. Perfect for festive occasions and casual outings.',
 'Rayon | A-Line | Knee Length',
 'CLO-W-001', 1, 'BIBA', 1499.00, 2999.00, 200, 4.6, 2100,
 '["https://images.unsplash.com/photo-1583391733956-6c78276477e2?w=400","https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=400"]',
 '["kurta","women","ethnic","anarkali","festive"]',
 '{"material":"Rayon","style":"Anarkali","length":"Knee Length","pattern":"Floral Print"}',
 TRUE),

('W Brand Straight Palazzo Set',
 'w-palazzo-set',
 'Comfortable straight-cut palazzo paired with a matching short kurti. Ideal for both casual and semi-formal wear.',
 'Poly Crepe | Straight Fit | Set of 2',
 'CLO-W-002', 1, 'W', 1799.00, 3499.00, 120, 4.5, 987,
 '["https://images.unsplash.com/photo-1614676471928-2ed0ad1061a4?w=400"]',
 '["palazzo","women","set","casual","ethnic"]',
 '{"material":"Poly Crepe","pieces":"2-piece set","length":"Full Length","fit":"Relaxed"}',
 FALSE),

('Zara Floral Maxi Dress',
 'zara-floral-maxi-dress',
 'Flowy floral maxi dress with V-neck and adjustable straps. Perfect for summers, beach outings, or casual brunches.',
 'Chiffon | Maxi Length | V-Neck',
 'CLO-W-003', 1, 'Zara', 2199.00, 3999.00, 90, 4.7, 1560,
 '["https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=400","https://images.unsplash.com/photo-1572804013309-59a88b7e92f1?w=400"]',
 '["dress","women","maxi","floral","summer"]',
 '{"material":"Chiffon","neckline":"V-Neck","length":"Maxi","pattern":"Floral"}',
 TRUE);

-- ============================================================
-- SEED: PRODUCTS — ELECTRONICS
-- ============================================================
INSERT INTO products (name, slug, description, short_desc, sku, category_id, brand, price, mrp, stock, rating, review_count, images, tags, specs, is_featured) VALUES

('Samsung Galaxy S24',
 'samsung-galaxy-s24',
 'The Samsung Galaxy S24 features a 6.2" Dynamic AMOLED display, Snapdragon 8 Gen 3 processor, 50MP triple camera system, and a long-lasting 4000mAh battery with 25W fast charging.',
 '6.2" AMOLED | Snapdragon 8 Gen 3 | 50MP Camera',
 'ELE-M-001', 2, 'Samsung', 54999.00, 74999.00, 80, 4.6, 3420,
 '["https://images.unsplash.com/photo-1610945415295-d9bbf067e59c?w=400","https://images.unsplash.com/photo-1574755393849-623942496936?w=400"]',
 '["phone","samsung","5g","android","flagship"]',
 '{"display":"6.2 inch Dynamic AMOLED 2X","processor":"Snapdragon 8 Gen 3","ram":"8GB","storage":"256GB","camera":"50MP + 12MP + 10MP","battery":"4000mAh","os":"Android 14","5g":true}',
 TRUE),

('Apple iPhone 15',
 'apple-iphone-15',
 'iPhone 15 with Dynamic Island, 48MP main camera with 2x optical zoom, USB-C charging, and A16 Bionic chip. Experience the next level of mobile photography.',
 '6.1" Super Retina XDR | A16 Bionic | 48MP Camera',
 'ELE-M-002', 2, 'Apple', 69999.00, 79900.00, 60, 4.8, 5670,
 '["https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=400","https://images.unsplash.com/photo-1696446701796-da61339d1a66?w=400"]',
 '["iphone","apple","5g","ios","flagship"]',
 '{"display":"6.1 inch Super Retina XDR","processor":"A16 Bionic","storage":"128GB","camera":"48MP + 12MP","battery":"3877mAh","os":"iOS 17","charging":"USB-C"}',
 TRUE),

('Dell Inspiron 15 Laptop',
 'dell-inspiron-15',
 'Dell Inspiron 15 with Intel Core i5-12th Gen, 16GB RAM, 512GB SSD, and Windows 11. Ideal for students and professionals. Features a full HD anti-glare display.',
 'Intel i5 12th Gen | 16GB RAM | 512GB SSD | Win 11',
 'ELE-L-001', 2, 'Dell', 52999.00, 72990.00, 45, 4.4, 1230,
 '["https://images.unsplash.com/photo-1593642632559-0c6d3fc62b89?w=400","https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=400"]',
 '["laptop","dell","i5","windows","student"]',
 '{"processor":"Intel Core i5-1235U","ram":"16GB DDR4","storage":"512GB SSD","display":"15.6 FHD Anti-glare","os":"Windows 11","battery":"3-cell 41WHr","weight":"1.65kg"}',
 TRUE),

('Apple MacBook Air M2',
 'macbook-air-m2',
 'The MacBook Air with M2 chip delivers incredible performance in an impossibly thin design. 18-hour battery, MagSafe charging, and a stunning Liquid Retina display.',
 'M2 Chip | 8GB RAM | 256GB SSD | 18hr Battery',
 'ELE-L-002', 2, 'Apple', 99900.00, 119900.00, 30, 4.9, 4320,
 '["https://images.unsplash.com/photo-1611186871525-b3aab77c3b83?w=400","https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=400"]',
 '["macbook","apple","m2","laptop","premium"]',
 '{"processor":"Apple M2","ram":"8GB Unified Memory","storage":"256GB SSD","display":"13.6 Liquid Retina","battery":"18 hours","weight":"1.24kg","ports":"2x Thunderbolt MagSafe"}',
 TRUE),

('Sony WH-1000XM5 Headphones',
 'sony-wh1000xm5',
 'Industry-leading noise cancellation with 30-hour battery life. Precise Voice Pickup Technology with 8 microphones for crystal-clear calls. Foldable design for easy travel.',
 'ANC | 30hr Battery | Hi-Res Audio | 8 Mics',
 'ELE-A-001', 2, 'Sony', 24990.00, 34990.00, 120, 4.7, 2890,
 '["https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400","https://images.unsplash.com/photo-1484704849700-f032a568e944?w=400"]',
 '["headphones","sony","noise-cancelling","wireless","premium"]',
 '{"type":"Over-Ear","connectivity":"Bluetooth 5.2","battery":"30 hours","anc":true,"driver":"30mm","frequency":"4Hz-40kHz","weight":"250g"}',
 FALSE),

('boAt Airdopes 141',
 'boat-airdopes-141',
 'True wireless earbuds with powerful 10mm drivers, 42-hour total playback, BEAST Mode for low latency gaming, and ENx noise cancelling technology.',
 'TWS | 42hr Total | ENx Mic | BEAST Mode',
 'ELE-A-002', 2, 'boAt', 1299.00, 2990.00, 400, 4.2, 8900,
 '["https://images.unsplash.com/photo-1608156639585-b3a032ef9689?w=400","https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=400"]',
 '["earbuds","boat","tws","budget","gaming"]',
 '{"type":"In-Ear TWS","battery":"6hr earbuds + 36hr case","drivers":"10mm","connectivity":"Bluetooth 5.1","ipx":"IPX4","latency":"60ms BEAST Mode"}',
 TRUE);

-- ============================================================
-- SEED: PRODUCTS — FOOTWEAR
-- ============================================================
INSERT INTO products (name, slug, description, short_desc, sku, category_id, brand, price, mrp, stock, rating, review_count, images, tags, specs, is_featured) VALUES

('Nike Air Max 270',
 'nike-air-max-270',
 'The Nike Air Max 270 features the first-ever Max Air unit created specifically for Nike Sportswear. The large window and 32mm heel unit delivers a supersoft, cushioned ride.',
 'Air Max | React Foam | Breathable Mesh Upper',
 'FOO-001', 3, 'Nike', 8495.00, 12995.00, 95, 4.6, 3200,
 '["https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400","https://images.unsplash.com/photo-1607522370275-f14206abe5d3?w=400"]',
 '["sneakers","nike","running","airmax","sports"]',
 '{"upper":"Mesh and synthetic","sole":"Rubber","closure":"Lace-Up","type":"Running/Lifestyle","heel_height":"32mm Air"}',
 TRUE),

('Adidas Ultraboost 22',
 'adidas-ultraboost-22',
 'The Ultraboost 22 features a Primeknit+ upper that adapts to the natural expansion of your foot. BOOST midsole returns energy with every step.',
 'BOOST Midsole | Primeknit+ Upper | Energized Run',
 'FOO-002', 3, 'Adidas', 10999.00, 17999.00, 70, 4.7, 2100,
 '["https://images.unsplash.com/photo-1608231387042-66d1773070a5?w=400"]',
 '["sneakers","adidas","running","boost","premium"]',
 '{"upper":"Primeknit+","midsole":"BOOST","outsole":"Continental Rubber","type":"Running","arch":"Neutral"}',
 FALSE);

-- ============================================================
-- SEED: ADMIN USER
-- ============================================================
-- Password: Admin@123 (bcrypt hash)
INSERT INTO users (name, email, password_hash, role) VALUES
('Admin', 'admin@abhiejaz.shop', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TiGc.9pE3a6YpxP7hB4J6Hj5PiTy', 'admin');

-- ============================================================
-- STORED PROCEDURE: Update product rating
-- ============================================================
DELIMITER //
CREATE PROCEDURE update_product_rating(IN p_id INT)
BEGIN
  UPDATE products
  SET rating = (SELECT COALESCE(AVG(rating), 0) FROM reviews WHERE product_id = p_id),
      review_count = (SELECT COUNT(*) FROM reviews WHERE product_id = p_id)
  WHERE id = p_id;
END //
DELIMITER ;

-- Trigger: auto-update rating when review added
CREATE TRIGGER after_review_insert
AFTER INSERT ON reviews
FOR EACH ROW
  CALL update_product_rating(NEW.product_id);

CREATE TRIGGER after_review_delete
AFTER DELETE ON reviews
FOR EACH ROW
  CALL update_product_rating(OLD.product_id);
