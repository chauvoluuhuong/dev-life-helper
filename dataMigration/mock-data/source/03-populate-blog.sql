-- Connect to sample_blog database
\c sample_blog;

-- Create authors table
CREATE TABLE authors (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    bio TEXT,
    joined_date DATE DEFAULT CURRENT_DATE
);

-- Create posts table
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    author_id INTEGER REFERENCES authors(id),
    published_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'draft',
    views INTEGER DEFAULT 0
);

-- Create comments table
CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    post_id INTEGER REFERENCES posts(id),
    author_name VARCHAR(100) NOT NULL,
    author_email VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO authors (name, email, bio) VALUES
('Alice Johnson', 'alice@blogsite.com', 'Tech writer with 5+ years experience'),
('Bob Martinez', 'bob@blogsite.com', 'Software developer and blogger'),
('Carol Davis', 'carol@blogsite.com', 'Marketing specialist and content creator'),
('Daniel Lee', 'daniel@blogsite.com', 'UX designer and writer');

INSERT INTO posts (title, content, author_id, status, views) VALUES
('Getting Started with PostgreSQL', 'PostgreSQL is a powerful open-source database...', 1, 'published', 245),
('Docker Best Practices', 'When working with Docker containers...', 2, 'published', 189),
('Modern Web Development', 'Web development has evolved significantly...', 3, 'published', 167),
('Database Migration Tips', 'Migrating databases can be challenging...', 1, 'published', 98),
('Introduction to DevOps', 'DevOps practices help streamline...', 2, 'draft', 0),
('UI/UX Design Principles', 'Good design starts with understanding...', 4, 'published', 156);

INSERT INTO comments (post_id, author_name, author_email, content) VALUES
(1, 'Reader1', 'reader1@email.com', 'Great article! Very helpful for beginners.'),
(1, 'Reader2', 'reader2@email.com', 'Thanks for the detailed explanation.'),
(2, 'Developer123', 'dev@email.com', 'These tips saved me hours of debugging.'),
(3, 'WebDev', 'webdev@email.com', 'Excellent overview of modern practices.'),
(4, 'DBA_Expert', 'dba@email.com', 'Would love to see more migration examples.'),
(6, 'Designer', 'designer@email.com', 'Love the practical approach to design.'); 