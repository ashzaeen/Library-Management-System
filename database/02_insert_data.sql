-- =============================================
-- Library Management System - Sample Data
-- =============================================

USE LibraryManagementSystem;

-- =============================================
-- Insert Genres
-- =============================================
INSERT INTO Genres (name, description) VALUES
('Fiction', 'Literary works of imaginative narration'),
('Science Fiction', 'Speculative fiction based on scientific concepts'),
('Mystery', 'Fiction dealing with solving a crime or puzzle'),
('Romance', 'Fiction focused on romantic relationships'),
('Biography', 'Account of someone\'s life written by another person'),
('Self-Help', 'Books offering advice on personal improvement'),
('History', 'Non-fiction about past events'),
('Technology', 'Books about technological topics'),
('Fantasy', 'Fiction involving magical or supernatural elements'),
('Thriller', 'Fast-paced fiction designed to create suspense');

-- =============================================
-- Insert Authors
-- =============================================
INSERT INTO Authors (name, biography, birth_date, nationality) VALUES
('Jane Austen', 'English novelist known for her six major novels which critique the British landed gentry.', '1775-12-16', 'British'),
('Isaac Asimov', 'American writer and professor of biochemistry, known for his works of science fiction.', '1920-01-02', 'American'),
('Agatha Christie', 'English writer known for her detective novels, especially those featuring Hercule Poirot.', '1890-09-15', 'British'),
('Stephen King', 'American author of horror, supernatural fiction, suspense, and fantasy novels.', '1947-09-21', 'American'),
('J.K. Rowling', 'British author best known for writing the Harry Potter fantasy series.', '1965-07-31', 'British'),
('Malcolm Gladwell', 'Canadian journalist and author known for his unique perspective on social sciences.', '1963-09-03', 'Canadian'),
('Yuval Noah Harari', 'Israeli historian and professor, known for his popular science bestsellers.', '1976-02-24', 'Israeli'),
('Michelle Obama', 'American attorney and author, former First Lady of the United States.', '1964-01-17', 'American');

-- =============================================
-- Insert Books (at least 10 books with various genres)
-- =============================================
INSERT INTO Books (title, isbn, author_id, genre_id, publication_year, publisher, total_copies, available_copies, description) VALUES
-- Jane Austen books
('Pride and Prejudice', '978-0-14-143951-8', 1, 1, 1813, 'Penguin Classics', 5, 3, 'A romantic novel of manners following the character development of Elizabeth Bennet.'),
('Sense and Sensibility', '978-0-14-143949-5', 1, 1, 1811, 'Penguin Classics', 3, 2, 'A novel about the Dashwood sisters, exploring themes of love and heartbreak.'),

-- Isaac Asimov books
('Foundation', '978-0-553-29335-0', 2, 2, 1951, 'Bantam Spectra', 4, 2, 'First book in the Foundation series, a landmark science fiction saga.'),
('I, Robot', '978-0-553-38256-3', 2, 2, 1950, 'Bantam Spectra', 4, 4, 'Collection of nine science fiction short stories exploring robot ethics.'),

-- Agatha Christie books
('Murder on the Orient Express', '978-0-06-207348-8', 3, 3, 1934, 'William Morrow', 3, 1, 'Detective Hercule Poirot investigates a murder on a train.'),

-- Stephen King books
('The Shining', '978-0-307-74365-9', 4, 10, 1977, 'Doubleday', 4, 2, 'A family heads to an isolated hotel for the winter where sinister forces influence the father.'),
('It', '978-0-450-41150-1', 4, 10, 1986, 'Viking Press', 3, 3, 'Seven children face their worst nightmares when they encounter an evil clown.'),

-- J.K. Rowling books
('Harry Potter and the Philosopher\'s Stone', '978-0-7475-3269-9', 5, 9, 1997, 'Bloomsbury', 6, 4, 'A young wizard begins his magical education at Hogwarts School.'),

-- Non-fiction books
('Outliers', '978-0-316-01792-3', 6, 6, 2008, 'Little, Brown and Company', 5, 5, 'Explores the factors that contribute to high levels of success.'),
('Sapiens: A Brief History of Humankind', '978-0-06-231609-7', 7, 7, 2011, 'Harper', 4, 2, 'An exploration of the history and impact of Homo sapiens on the world.'),
('Becoming', '978-1-5247-6313-8', 8, 5, 2018, 'Crown Publishing', 5, 3, 'Memoir by former First Lady Michelle Obama chronicling her life experiences.'),

-- Additional books
('21 Lessons for the 21st Century', '978-1-7847-0804-8', 7, 7, 2018, 'Spiegel & Grau', 3, 3, 'Explores the present challenges facing humanity in the 21st century.');

-- =============================================
-- Insert Users (at least 5 users)
-- =============================================
INSERT INTO Users (name, email, phone, address, registration_date, membership_status) VALUES
('Alice Johnson', 'alice.johnson@email.com', '555-0101', '123 Maple Street, Springfield, IL', '2023-01-15', 'active'),
('Bob Smith', 'bob.smith@email.com', '555-0102', '456 Oak Avenue, Springfield, IL', '2023-03-22', 'active'),
('Carol Williams', 'carol.williams@email.com', '555-0103', '789 Pine Road, Springfield, IL', '2023-06-10', 'active'),
('David Brown', 'david.brown@email.com', '555-0104', '321 Elm Street, Springfield, IL', '2024-01-05', 'active'),
('Emma Davis', 'emma.davis@email.com', '555-0105', '654 Birch Lane, Springfield, IL', '2024-02-14', 'active');

-- =============================================
-- Insert Transactions (at least 10 transactions)
-- Mix of completed returns and ongoing checkouts
-- =============================================
INSERT INTO Transactions (user_id, book_id, checkout_date, due_date, return_date, status, fine_amount) VALUES
-- Completed transactions (returned)
(1, 1, '2024-01-10', '2024-01-24', '2024-01-22', 'returned', 0.00),
(2, 3, '2024-01-15', '2024-01-29', '2024-02-05', 'returned', 3.50),
(3, 5, '2024-02-01', '2024-02-15', '2024-02-14', 'returned', 0.00),
(4, 8, '2024-02-10', '2024-02-24', '2024-02-23', 'returned', 0.00),

-- Currently checked out (not overdue)
(1, 11, '2024-04-15', '2024-04-29', NULL, 'checked_out', 0.00),
(2, 6, '2024-04-18', '2024-05-02', NULL, 'checked_out', 0.00),
(5, 9, '2024-04-20', '2024-05-04', NULL, 'checked_out', 0.00),

-- Overdue transactions
(3, 1, '2024-03-15', '2024-03-29', NULL, 'overdue', 0.00),
(4, 10, '2024-03-20', '2024-04-03', NULL, 'overdue', 0.00),
(5, 5, '2024-04-01', '2024-04-15', NULL, 'overdue', 0.00);

-- =============================================
-- Insert Reservations (at least 3 reservations)
-- =============================================
INSERT INTO Reservations (user_id, book_id, reservation_date, status, expiry_date) VALUES
(2, 1, '2024-04-20', 'active', '2024-04-27'),
(4, 5, '2024-04-22', 'active', '2024-04-29'),
(5, 3, '2024-04-25', 'active', '2024-05-02');

-- =============================================
-- Insert Notifications (at least 5 overdue notifications)
-- =============================================
INSERT INTO Notifications (user_id, notification_type, message, notification_date, is_read, related_transaction_id) VALUES
(3, 'overdue', 'Your book "Pride and Prejudice" is overdue. Please return it as soon as possible.', '2024-03-30 10:00:00', FALSE, 8),
(4, 'overdue', 'Your book "Sapiens: A Brief History of Humankind" is overdue. Please return it as soon as possible.', '2024-04-04 10:00:00', FALSE, 9),
(5, 'overdue', 'Your book "Murder on the Orient Express" is overdue. Please return it as soon as possible.', '2024-04-16 10:00:00', FALSE, 10),
(1, 'due_soon', 'Your book "21 Lessons for the 21st Century" is due in 3 days.', '2024-04-26 09:00:00', TRUE, 5),
(2, 'due_soon', 'Your book "The Shining" is due in 3 days.', '2024-04-26 09:00:00', FALSE, 6);

-- =============================================
-- Insert Activity Log entries
-- =============================================
INSERT INTO ActivityLog (user_id, activity_type, activity_description, activity_timestamp) VALUES
(1, 'checkout', 'Checked out "Pride and Prejudice"', '2024-01-10 14:30:00'),
(1, 'return', 'Returned "Pride and Prejudice"', '2024-01-22 10:15:00'),
(2, 'checkout', 'Checked out "Foundation"', '2024-01-15 11:20:00'),
(3, 'reservation', 'Reserved "Pride and Prejudice"', '2024-04-20 16:45:00'),
(4, 'checkout', 'Checked out "Harry Potter and the Philosopher\'s Stone"', '2024-02-10 13:00:00'),
(5, 'checkout', 'Checked out "Outliers"', '2024-04-20 15:30:00');

-- =============================================
-- Display data insertion summary
-- =============================================
SELECT 'Sample data inserted successfully!' AS Status;

SELECT 
    'Genres' AS Table_Name, COUNT(*) AS Record_Count FROM Genres
UNION ALL
SELECT 'Authors', COUNT(*) FROM Authors
UNION ALL
SELECT 'Books', COUNT(*) FROM Books
UNION ALL
SELECT 'Users', COUNT(*) FROM Users
UNION ALL
SELECT 'Transactions', COUNT(*) FROM Transactions
UNION ALL
SELECT 'Reservations', COUNT(*) FROM Reservations
UNION ALL
SELECT 'Notifications', COUNT(*) FROM Notifications
UNION ALL
SELECT 'ActivityLog', COUNT(*) FROM ActivityLog;
