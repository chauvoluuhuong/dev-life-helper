// Initialize sample data for Mongoku test
db = db.getSiblingDB("sampledb");

// Create collections
db.createCollection("products");
db.createCollection("customers");
db.createCollection("orders");

// Insert sample products
db.products.insertMany([
  {
    name: "Laptop",
    brand: "TechBrand",
    price: 999.99,
    stock: 50,
    category: "Electronics",
    specifications: {
      ram: "16GB",
      storage: "512GB SSD",
      processor: "Intel i7",
    },
  },
  {
    name: "Smartphone",
    brand: "PhoneBrand",
    price: 699.99,
    stock: 100,
    category: "Electronics",
    specifications: {
      ram: "8GB",
      storage: "256GB",
      camera: "48MP",
    },
  },
  {
    name: "Headphones",
    brand: "AudioBrand",
    price: 199.99,
    stock: 200,
    category: "Audio",
    specifications: {
      type: "Wireless",
      battery: "30 hours",
      noise_cancelling: true,
    },
  },
]);

// Insert sample customers
db.customers.insertMany([
  {
    name: "Alice Johnson",
    email: "alice@example.com",
    phone: "+1234567890",
    address: {
      street: "123 Main St",
      city: "New York",
      country: "USA",
    },
    created_at: new Date(),
  },
  {
    name: "Bob Smith",
    email: "bob@example.com",
    phone: "+0987654321",
    address: {
      street: "456 Oak Ave",
      city: "Los Angeles",
      country: "USA",
    },
    created_at: new Date(),
  },
]);

// Insert sample orders
db.orders.insertMany([
  {
    order_id: "ORD001",
    customer_email: "alice@example.com",
    products: [{ name: "Laptop", quantity: 1, price: 999.99 }],
    total: 999.99,
    status: "delivered",
    order_date: new Date(),
  },
  {
    order_id: "ORD002",
    customer_email: "bob@example.com",
    products: [
      { name: "Smartphone", quantity: 1, price: 699.99 },
      { name: "Headphones", quantity: 2, price: 399.98 },
    ],
    total: 1099.97,
    status: "processing",
    order_date: new Date(),
  },
]);

print("✅ Sample database initialized with products, customers, and orders");
