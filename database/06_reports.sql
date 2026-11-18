-- =============================================
-- Library Management System - Reports
-- =============================================

USE LibraryManagementSystem;

-- =============================================
-- Report 1: Monthly Borrowing Statistics
-- Shows borrowing trends by month
-- =============================================
SELECT 
    DATE_FORMAT(checkout_date, '%Y-%m') AS month,
    DATE_FORMAT(checkout_date, '%M %Y') AS month_name,
    COUNT(*) AS total_checkouts,
    COUNT(DISTINCT user_id) AS unique_borrowers,
    COUNT(DISTINCT book_id) AS unique_books_borrowed,
    COUNT(CASE WHEN status = 'returned' THEN 1 END) AS books_returned,
    COUNT(CASE WHEN status = 'overdue' THEN 1 END) AS books_overdue,
    COUNT(CASE WHEN return_date IS NOT NULL AND return_date > due_date THEN 1 END) AS late_returns,
    ROUND(AVG(CASE WHEN return_date IS NOT NULL 
              THEN DATEDIFF(return_date, checkout_date) END), 1) AS avg_loan_duration_days
FROM Transactions
GROUP BY DATE_FORMAT(checkout_date, '%Y-%m'), DATE_FORMAT(checkout_date, '%M %Y')
ORDER BY month DESC
LIMIT 12;

-- =============================================
-- Report 2: Most Active Users
-- Identifies users with highest borrowing activity
-- =============================================
SELECT 
    u.user_id,
    u.name,
    u.email,
    u.registration_date,
    COUNT(t.transaction_id) AS total_checkouts,
    COUNT(CASE WHEN t.status = 'returned' THEN 1 END) AS books_returned,
    COUNT(CASE WHEN t.status = 'overdue' THEN 1 END) AS books_overdue,
    COUNT(CASE WHEN t.return_date > t.due_date THEN 1 END) AS late_returns,
    SUM(t.fine_amount) AS total_fines,
    MAX(t.checkout_date) AS last_checkout_date,
    DATEDIFF(CURDATE(), u.registration_date) AS member_for_days,
    ROUND(COUNT(t.transaction_id) / 
          (DATEDIFF(CURDATE(), u.registration_date) / 30), 2) AS avg_checkouts_per_month
FROM Users u
LEFT JOIN Transactions t ON u.user_id = t.user_id
GROUP BY u.user_id, u.name, u.email, u.registration_date
HAVING total_checkouts > 0
ORDER BY total_checkouts DESC
LIMIT 20;

-- =============================================
-- Report 3: Most Borrowed Books
-- Lists books with highest checkout frequency
-- =============================================
SELECT 
    b.book_id,
    b.title,
    a.name AS author_name,
    g.name AS genre,
    b.isbn,
    b.publication_year,
    b.total_copies,
    COUNT(t.transaction_id) AS total_checkouts,
    COUNT(DISTINCT t.user_id) AS unique_borrowers,
    ROUND(COUNT(t.transaction_id) / b.total_copies, 2) AS checkouts_per_copy,
    MAX(t.checkout_date) AS last_checkout_date,
    b.available_copies AS currently_available,
    CASE 
        WHEN b.available_copies = 0 THEN 'High Demand - Out of Stock'
        WHEN b.available_copies <= b.total_copies * 0.3 THEN 'High Demand - Low Stock'
        ELSE 'Available'
    END AS demand_status
FROM Books b
JOIN Authors a ON b.author_id = a.author_id
LEFT JOIN Genres g ON b.genre_id = g.genre_id
LEFT JOIN Transactions t ON b.book_id = t.book_id
GROUP BY b.book_id, b.title, a.name, g.name, b.isbn, 
         b.publication_year, b.total_copies, b.available_copies
ORDER BY total_checkouts DESC
LIMIT 20;

-- =============================================
-- Report 4: Overdue Notifications Sent (Last Month)
-- Lists all overdue notifications from the past month
-- =============================================
SELECT 
    n.notification_id,
    u.user_id,
    u.name AS user_name,
    u.email,
    n.message,
    n.notification_date,
    n.is_read,
    b.title AS book_title,
    t.due_date,
    DATEDIFF(CURDATE(), t.due_date) AS days_overdue
FROM Notifications n
JOIN Users u ON n.user_id = u.user_id
LEFT JOIN Transactions t ON n.related_transaction_id = t.transaction_id
LEFT JOIN Books b ON t.book_id = b.book_id
WHERE n.notification_type = 'overdue'
  AND n.notification_date >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
ORDER BY n.notification_date DESC;

-- =============================================
-- Report 5: Reservation Trends (Last 6 Months)
-- Shows reservation patterns over time
-- =============================================
SELECT 
    DATE_FORMAT(reservation_date, '%Y-%m') AS month,
    DATE_FORMAT(reservation_date, '%M %Y') AS month_name,
    COUNT(*) AS total_reservations,
    COUNT(DISTINCT user_id) AS unique_users,
    COUNT(DISTINCT book_id) AS unique_books,
    COUNT(CASE WHEN status = 'fulfilled' THEN 1 END) AS fulfilled_reservations,
    COUNT(CASE WHEN status = 'cancelled' THEN 1 END) AS cancelled_reservations,
    COUNT(CASE WHEN status = 'expired' THEN 1 END) AS expired_reservations,
    COUNT(CASE WHEN status = 'active' THEN 1 END) AS active_reservations,
    ROUND(COUNT(CASE WHEN status = 'fulfilled' THEN 1 END) * 100.0 / COUNT(*), 1) AS fulfillment_rate
FROM Reservations
WHERE reservation_date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY DATE_FORMAT(reservation_date, '%Y-%m'), DATE_FORMAT(reservation_date, '%M %Y')
ORDER BY month DESC;

-- =============================================
-- Additional Report 6: Genre Performance Analysis
-- Analyzes borrowing patterns by genre
-- =============================================
SELECT 
    g.genre_id,
    g.name AS genre_name,
    COUNT(DISTINCT b.book_id) AS total_books,
    COUNT(t.transaction_id) AS total_checkouts,
    COUNT(DISTINCT t.user_id) AS unique_borrowers,
    ROUND(AVG(CASE WHEN t.return_date IS NOT NULL 
              THEN DATEDIFF(t.return_date, t.checkout_date) END), 1) AS avg_loan_days,
    COUNT(CASE WHEN t.status = 'overdue' THEN 1 END) AS overdue_count,
    ROUND(COUNT(CASE WHEN t.status = 'overdue' THEN 1 END) * 100.0 / 
          COUNT(t.transaction_id), 1) AS overdue_percentage,
    ROUND(COUNT(t.transaction_id) / COUNT(DISTINCT b.book_id), 2) AS avg_checkouts_per_book
FROM Genres g
JOIN Books b ON g.genre_id = b.genre_id
LEFT JOIN Transactions t ON b.book_id = t.book_id
GROUP BY g.genre_id, g.name
ORDER BY total_checkouts DESC;

-- =============================================
-- Additional Report 7: Daily Operations Summary
-- Current day snapshot for librarians
-- =============================================
SELECT 
    'Books Checked Out Today' AS metric,
    COUNT(*) AS value
FROM Transactions
WHERE checkout_date = CURDATE()

UNION ALL

SELECT 
    'Books Returned Today',
    COUNT(*)
FROM Transactions
WHERE return_date = CURDATE()

UNION ALL

SELECT 
    'New Reservations Today',
    COUNT(*)
FROM Reservations
WHERE reservation_date = CURDATE()

UNION ALL

SELECT 
    'Currently Overdue Books',
    COUNT(*)
FROM Transactions
WHERE status = 'overdue'

UNION ALL

SELECT 
    'Active Users Today',
    COUNT(DISTINCT user_id)
FROM ActivityLog
WHERE DATE(activity_timestamp) = CURDATE()

UNION ALL

SELECT 
    'Total Books Available',
    SUM(available_copies)
FROM Books

UNION ALL

SELECT 
    'Total Books Checked Out',
    COUNT(*)
FROM Transactions
WHERE return_date IS NULL;

-- =============================================
-- Additional Report 8: Fine Collection Summary
-- Summary of fines collected
-- =============================================
SELECT 
    DATE_FORMAT(return_date, '%Y-%m') AS month,
    DATE_FORMAT(return_date, '%M %Y') AS month_name,
    COUNT(*) AS total_returns,
    COUNT(CASE WHEN fine_amount > 0 THEN 1 END) AS returns_with_fines,
    SUM(fine_amount) AS total_fines_collected,
    AVG(fine_amount) AS avg_fine_amount,
    MAX(fine_amount) AS max_fine_amount
FROM Transactions
WHERE return_date IS NOT NULL
GROUP BY DATE_FORMAT(return_date, '%Y-%m'), DATE_FORMAT(return_date, '%M %Y')
ORDER BY month DESC
LIMIT 12;

-- =============================================
-- Additional Report 9: Author Popularity Report
-- Shows most popular authors by checkouts
-- =============================================
SELECT 
    a.author_id,
    a.name AS author_name,
    a.nationality,
    COUNT(DISTINCT b.book_id) AS books_in_library,
    COUNT(t.transaction_id) AS total_checkouts,
    COUNT(DISTINCT t.user_id) AS unique_borrowers,
    ROUND(COUNT(t.transaction_id) / COUNT(DISTINCT b.book_id), 2) AS avg_checkouts_per_book,
    MAX(t.checkout_date) AS last_checkout_date
FROM Authors a
JOIN Books b ON a.author_id = b.author_id
LEFT JOIN Transactions t ON b.book_id = t.book_id
GROUP BY a.author_id, a.name, a.nationality
ORDER BY total_checkouts DESC
LIMIT 15;

-- =============================================
-- Additional Report 10: User Retention Analysis
-- Analyzes user engagement over time
-- =============================================
SELECT 
    CASE 
        WHEN DATEDIFF(CURDATE(), registration_date) <= 30 THEN '0-1 month'
        WHEN DATEDIFF(CURDATE(), registration_date) <= 90 THEN '1-3 months'
        WHEN DATEDIFF(CURDATE(), registration_date) <= 180 THEN '3-6 months'
        WHEN DATEDIFF(CURDATE(), registration_date) <= 365 THEN '6-12 months'
        ELSE 'Over 1 year'
    END AS member_duration,
    COUNT(DISTINCT u.user_id) AS user_count,
    COUNT(t.transaction_id) AS total_checkouts,
    ROUND(AVG(transaction_count), 2) AS avg_checkouts_per_user,
    COUNT(DISTINCT CASE WHEN last_activity_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) 
                        THEN u.user_id END) AS active_last_30_days,
    ROUND(COUNT(DISTINCT CASE WHEN last_activity_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) 
                               THEN u.user_id END) * 100.0 / COUNT(DISTINCT u.user_id), 1) AS activity_rate
FROM Users u
LEFT JOIN Transactions t ON u.user_id = t.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) AS transaction_count
    FROM Transactions
    GROUP BY user_id
) tc ON u.user_id = tc.user_id
GROUP BY member_duration
ORDER BY 
    CASE member_duration
        WHEN '0-1 month' THEN 1
        WHEN '1-3 months' THEN 2
        WHEN '3-6 months' THEN 3
        WHEN '6-12 months' THEN 4
        ELSE 5
    END;

-- =============================================
SELECT 'All reports created successfully!' AS Status;
