-- Connect to sample_inventory database
\c sample_inventory;

-- Create suppliers table
CREATE TABLE suppliers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    contact_person VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(100),
    address TEXT
);

-- Create items table
CREATE TABLE items (
    id SERIAL PRIMARY KEY,
    sku VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    unit_price DECIMAL(10,2),
    supplier_id INTEGER REFERENCES suppliers(id),
    category VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create stock table
CREATE TABLE stock (
    id SERIAL PRIMARY KEY,
    item_id INTEGER REFERENCES items(id),
    quantity INTEGER NOT NULL DEFAULT 0,
    location VARCHAR(100),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create stock_movements table
CREATE TABLE stock_movements (
    id SERIAL PRIMARY KEY,
    item_id INTEGER REFERENCES items(id),
    movement_type VARCHAR(20) NOT NULL, -- 'in', 'out', 'adjustment'
    quantity INTEGER NOT NULL,
    reference_number VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO suppliers (name, contact_person, phone, email, address) VALUES
('TechSupply Co', 'John Manager', '555-0101', 'john@techsupply.com', '123 Tech Street, Silicon Valley'),
('Office Depot', 'Sarah Sales', '555-0102', 'sarah@officedepot.com', '456 Office Blvd, Business District'),
('Hardware Plus', 'Mike Vendor', '555-0103', 'mike@hardwareplus.com', '789 Hardware Lane, Industrial Zone');

INSERT INTO items (sku, name, description, unit_price, supplier_id, category) VALUES
('TECH-001', 'Laptop Dell XPS', 'High-performance laptop', 1200.00, 1, 'Electronics'),
('TECH-002', 'USB Mouse', 'Wireless USB mouse', 25.00, 1, 'Electronics'),
('OFF-001', 'Office Chair', 'Ergonomic office chair', 250.00, 2, 'Furniture'),
('OFF-002', 'Desk Organizer', 'Multi-compartment organizer', 15.00, 2, 'Office Supplies'),
('HW-001', 'Screwdriver Set', 'Professional screwdriver set', 35.00, 3, 'Tools'),
('HW-002', 'Cable Ties', 'Pack of 100 cable ties', 8.00, 3, 'Hardware'),
('TECH-003', 'Monitor 24"', '24-inch LED monitor', 180.00, 1, 'Electronics');

INSERT INTO stock (item_id, quantity, location) VALUES
(1, 15, 'Warehouse A'),
(2, 100, 'Warehouse A'),
(3, 8, 'Warehouse B'),
(4, 45, 'Warehouse B'),
(5, 25, 'Warehouse C'),
(6, 200, 'Warehouse C'),
(7, 12, 'Warehouse A');

INSERT INTO stock_movements (item_id, movement_type, quantity, reference_number, notes) VALUES
(1, 'in', 20, 'PO-2024-001', 'Initial stock purchase'),
(1, 'out', 5, 'SO-2024-001', 'Sales order fulfillment'),
(2, 'in', 150, 'PO-2024-002', 'Bulk purchase'),
(2, 'out', 50, 'SO-2024-002', 'Office supplies order'),
(3, 'in', 10, 'PO-2024-003', 'Furniture delivery'),
(3, 'out', 2, 'SO-2024-003', 'Customer order'),
(7, 'in', 15, 'PO-2024-004', 'Monitor restocking'),
(7, 'out', 3, 'SO-2024-004', 'Bulk customer order'); 