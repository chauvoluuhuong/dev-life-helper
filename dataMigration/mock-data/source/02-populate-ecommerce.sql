-- Connect to sample_ecommerce database
\c sample_ecommerce;

-- Create users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    full_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create products table
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    stock INTEGER DEFAULT 0,
    category VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create orders table
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    total_amount DECIMAL(10,2) NOT NULL,
    order_status VARCHAR(20) DEFAULT 'pending',
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO users (username, email, full_name) VALUES
('john_doe', 'john@example.com', 'John Doe'),
('jane_smith', 'jane@example.com', 'Jane Smith'),
('mike_wilson', 'mike@example.com', 'Mike Wilson'),
('sarah_jones', 'sarah@example.com', 'Sarah Jones'),
('david_brown', 'david@example.com', 'David Brown');

INSERT INTO products (name, description, price, stock, category) VALUES
('Laptop', 'High-performance laptop', 999.99, 10, 'Electronics'),
('Mouse', 'Wireless optical mouse', 29.99, 50, 'Electronics'),
('Keyboard', 'Mechanical keyboard', 79.99, 25, 'Electronics'),
('Monitor', '24-inch LED monitor', 199.99, 15, 'Electronics'),
('Headphones', 'Noise-canceling headphones', 149.99, 30, 'Electronics'),
('Desk Chair', 'Ergonomic office chair', 299.99, 8, 'Furniture'),
('Desk Lamp', 'LED desk lamp', 49.99, 20, 'Furniture');

INSERT INTO orders (user_id, total_amount, order_status) VALUES
(1, 1029.98, 'completed'),
(2, 279.98, 'shipped'),
(3, 49.99, 'pending'),
(4, 199.99, 'completed'),
(5, 379.98, 'processing'); 