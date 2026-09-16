-- ============================================================
-- Sales Analytics Database Schema
-- Star-schema-friendly design: dimension tables (customers,
-- products) + transactional tables (orders, order_items)
-- ============================================================

CREATE TABLE customers (
    customer_id     INTEGER PRIMARY KEY,
    customer_name   TEXT NOT NULL,
    region          TEXT NOT NULL,
    join_date       DATE NOT NULL
);

CREATE TABLE products (
    product_id      INTEGER PRIMARY KEY,
    product_name    TEXT NOT NULL,
    category        TEXT NOT NULL,
    unit_cost       REAL NOT NULL,
    unit_price      REAL NOT NULL
);

CREATE TABLE orders (
    order_id        INTEGER PRIMARY KEY,
    customer_id     INTEGER NOT NULL,
    order_date      DATE NOT NULL,
    region          TEXT NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_item_id   INTEGER PRIMARY KEY,
    order_id        INTEGER NOT NULL,
    product_id      INTEGER NOT NULL,
    quantity        INTEGER NOT NULL,
    unit_price      REAL NOT NULL,
    discount_pct    REAL NOT NULL DEFAULT 0,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_items_order ON order_items(order_id);
CREATE INDEX idx_items_product ON order_items(product_id);
