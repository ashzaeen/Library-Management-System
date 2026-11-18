-- =============================================
-- Library Management System - Queries and Views
-- =============================================

USE LibraryManagementSystem;

-- =============================================
-- REQUIRED QUERIES
-- =============================================

-- Query 1: Retrieve all books currently checked out
-- with user details and due dates
-- =============================================
SELECT 
    t.transaction_id,
    b.title AS book_title,
    b.isbn,
    a.name AS author_name,
    u.name AS user_name,
    u.email AS user_email,
    u.phone AS user_phone,
    t.checkout_date,
    t.due_date,
    DATEDIFF(t.due_date, CURDATE()) AS days_until_due,
    t.status
FROM Transactions t
JOIN Books b ON t.book_id = b.book_id
JOIN Authors a ON b.author_id = a.author_id
JOIN Users u ON t.user_id = u.user_id
WHERE t.return_date IS NULL
ORDER BY t.due_date;

-- =============================================
-- Query 2: List books available for reservation
-- with genres and authors
-- =============================================
SELECT 
    b.book_id,
    b.title,
    b.isbn,
    a.name AS author_name,
    g.name AS genre,
    b.publication_year,
    b.publisher,
    b.available_copies,
    b.total_copies,
    CASE 
        WHEN b.available_copies > 0 THEN 'Available Now'
        ELSE 'Currently Unavailable'
    END AS availability_status
FROM Books b
JOIN Authors a ON b.author_id = a.author_id
LEFT JOIN Genres g ON b.genre_id = g.genre_id
ORDER BY b.available_copies DESC, b.title;

-- =============================================
-- Query 3: Generate a list of users with overdue books
-- =============================================
SELECT 
    u.user_id,
    u.name AS user_name,
    u.email,
    u.phone,
    b.title AS overdue_book,
    t.checkout_date,
    t.due_date,
    DATEDIFF(CURDATE(), t.due_date) AS days_overdue,
    ROUND(DATEDIFF(CURDATE(), t.due_date) * 0.50, 2) AS estimated_fine
FROM Transactions t
JOIN Users u ON t.user_id = u.user_id
JOIN Books b ON t.book_id = b.book_id
WHERE t.status = 'overdue'
ORDER BY days_overdue DESC;

-- =============================================
-- Query 4: Find most popular books based on checkouts
-- =============================================
SELECT 
    b.book_id,
    b.title,
    a.name AS author_name,
    g.name AS genre,
    COUNT(t.transaction_id) AS total_checkouts,
    b.available_copies,
    b.total_copies
FROM Books b
JOIN Authors a ON b.author_id = a.author_id
LEFT JOIN Genres g ON b.genre_id = g.genre_id
LEFT JOIN Transactions t ON b.book_id = t.book_id
GROUP BY b.book_id, b.title, a.name, g.name, b.available_copies, b.total_copies
ORDER BY total_checkouts DESC
LIMIT 10;

-- =============================================
-- Query 5: Book recommendations based on user history
-- (Books in the same genre as previously borrowed)
-- =============================================
SELECT DISTINCT
    b.book_id,
    b.title,
    a.name AS author_name,
    g.name AS genre,
    b.available_copies,
    'Recommended based on your reading history' AS recommendation_reason
FROM Books b
JOIN Authors a ON b.author_id = a.author_id
JOIN Genres g ON b.genre_id = g.genre_id
WHERE g.genre_id IN (
    -- Get genres user has borrowed before
    SELECT DISTINCT b2.genre_id
    FROM Transactions t
    JOIN Books b2 ON t.book_id = b2.book_id
    WHERE t.user_id = 1  -- Example user_id, can be parameterized
)
AND b.book_id NOT IN (
    -- Exclude books user has already borrowed
    SELECT book_id
    FROM Transactions
    WHERE user_id = 1  -- Example user_id, can be parameterized
)
AND b.available_copies > 0
ORDER BY b.title
LIMIT 5;

-- =============================================
-- VIEWS
-- =============================================

-- View 1: Overdue Books View (for librarians)
-- Shows all currently overdue books with user details
-- =============================================
CREATE OR REPLACE VIEW vw_OverdueBooks AS
SELECT 
    t.transaction_id,
    u.user_id,
    u.name AS user_name,
    u.email AS user_email,
    u.phone AS user_phone,
    b.book_id,
    b.title AS book_title,
    b.isbn,
    a.name AS author_name,
    t.checkout_date,
    t.due_date,
    DATEDIFF(CURDATE(), t.due_date) AS days_overdue,
    ROUND(DATEDIFF(CURDATE(), t.due_date) * 0.50, 2) AS fine_amount
FROM Transactions t
JOIN Users u ON t.user_id = u.user_id
JOIN Books b ON t.book_id = b.book_id
JOIN Authors a ON b.author_id = a.author_id
WHERE t.status = 'overdue'
ORDER BY days_overdue DESC;

-- View 2: User Dashboard View
-- Shows current reservations and checkouts for users
-- =============================================
CREATE OR REPLACE VIEW vw_UserDashboard AS
SELECT 
    u.user_id,
    u.name AS user_name,
    'Checked Out' AS item_type,
    b.title AS book_title,
    a.name AS author_name,
    t.checkout_date AS action_date,
    t.due_date,
    DATEDIFF(t.due_date, CURDATE()) AS days_remaining,
    t.status,
    NULL AS reservation_status
FROM Users u
JOIN Transactions t ON u.user_id = t.user_id
JOIN Books b ON t.book_id = b.book_id
JOIN Authors a ON b.author_id = a.author_id
WHERE t.return_date IS NULL

UNION ALL

SELECT 
    u.user_id,
    u.name AS user_name,
    'Reserved' AS item_type,
    b.title AS book_title,
    a.name AS author_name,
    r.reservation_date AS action_date,
    r.expiry_date AS due_date,
    DATEDIFF(r.expiry_date, CURDATE()) AS days_remaining,
    NULL AS status,
    r.status AS reservation_status
FROM Users u
JOIN Reservations r ON u.user_id = r.user_id
JOIN Books b ON r.book_id = b.book_id
JOIN Authors a ON b.author_id = a.author_id
WHERE r.status = 'active'

ORDER BY user_id, action_date DESC;

-- View 3: Popular Genres View
-- Displays most popular genres based on borrow history
-- =============================================
CREATE OR REPLACE VIEW vw_PopularGenres AS
SELECT 
    g.genre_id,
    g.name AS genre_name,
    COUNT(DISTINCT t.transaction_id) AS total_checkouts,
    COUNT(DISTINCT b.book_id) AS books_in_genre,
    COUNT(DISTINCT t.user_id) AS unique_borrowers,
    ROUND(COUNT(DISTINCT t.transaction_id) / COUNT(DISTINCT b.book_id), 2) AS avg_checkouts_per_book
FROM Genres g
JOIN Books b ON g.genre_id = b.genre_id
LEFT JOIN Transactions t ON b.book_id = t.book_id
GROUP BY g.genre_id, g.name
ORDER BY total_checkouts DESC;

-- View 4: Book Inventory Status
-- Shows current inventory status of all books
-- =============================================
CREATE OR REPLACE VIEW vw_BookInventory AS
SELECT 
    b.book_id,
    b.title,
    a.name AS author_name,
    g.name AS genre,
    b.isbn,
    b.total_copies,
    b.available_copies,
    (b.total_copies - b.available_copies) AS checked_out_copies,
    ROUND((b.available_copies / b.total_copies) * 100, 1) AS availability_percentage,
    COUNT(DISTINCT r.reservation_id) AS active_reservations,
    CASE 
        WHEN b.available_copies = 0 THEN 'Out of Stock'
        WHEN b.available_copies <= b.total_copies * 0.2 THEN 'Low Stock'
        ELSE 'In Stock'
    END AS stock_status
FROM Books b
JOIN Authors a ON b.author_id = a.author_id
LEFT JOIN Genres g ON b.genre_id = g.genre_id
LEFT JOIN Reservations r ON b.book_id = r.book_id AND r.status = 'active'
GROUP BY b.book_id, b.title, a.name, g.name, b.isbn, 
         b.total_copies, b.available_copies
ORDER BY stock_status, b.title;

-- View 5: User Activity Summary
-- Summarizes user borrowing patterns
-- =============================================
CREATE OR REPLACE VIEW vw_UserActivitySummary AS
SELECT 
    u.user_id,
    u.name AS user_name,
    u.email,
    u.registration_date,
    u.membership_status,
    COUNT(DISTINCT t.transaction_id) AS total_checkouts,
    COUNT(DISTINCT CASE WHEN t.return_date IS NULL THEN t.transaction_id END) AS current_checkouts,
    COUNT(DISTINCT CASE WHEN t.status = 'overdue' THEN t.transaction_id END) AS overdue_books,
    COUNT(DISTINCT r.reservation_id) AS active_reservations,
    SUM(COALESCE(t.fine_amount, 0)) AS total_fines,
    MAX(t.checkout_date) AS last_checkout_date,
    DATEDIFF(CURDATE(), u.registration_date) AS days_as_member
FROM Users u
LEFT JOIN Transactions t ON u.user_id = t.user_id
LEFT JOIN Reservations r ON u.user_id = r.user_id AND r.status = 'active'
GROUP BY u.user_id, u.name, u.email, u.registration_date, u.membership_status
ORDER BY total_checkouts DESC;

-- =============================================
-- Display views summary
-- =============================================
SELECT 'Queries and views created successfully!' AS Status;

SHOW FULL TABLES IN LibraryManagementSystem WHERE Table_type = 'VIEW';
