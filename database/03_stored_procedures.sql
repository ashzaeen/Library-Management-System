-- =============================================
-- Library Management System - Stored Procedures
-- =============================================

USE LibraryManagementSystem;

DELIMITER //

-- =============================================
-- Stored Procedure: ReserveBook
-- Automates the process of reserving a book
-- Checks availability and creates reservation
-- =============================================
DROP PROCEDURE IF EXISTS ReserveBook//

CREATE PROCEDURE ReserveBook(
    IN p_user_id INT,
    IN p_book_id INT,
    OUT p_result VARCHAR(255)
)
BEGIN
    DECLARE v_available_copies INT;
    DECLARE v_existing_reservation INT;
    DECLARE v_expiry_date DATE;
    
    -- Start transaction
    START TRANSACTION;
    
    -- Check if book exists
    IF NOT EXISTS (SELECT 1 FROM Books WHERE book_id = p_book_id) THEN
        SET p_result = 'ERROR: Book not found';
        ROLLBACK;
    
    -- Check if user exists
    ELSEIF NOT EXISTS (SELECT 1 FROM Users WHERE user_id = p_user_id) THEN
        SET p_result = 'ERROR: User not found';
        ROLLBACK;
    
    ELSE
        -- Check if user already has an active reservation for this book
        SELECT COUNT(*) INTO v_existing_reservation
        FROM Reservations
        WHERE user_id = p_user_id 
          AND book_id = p_book_id 
          AND status = 'active';
        
        IF v_existing_reservation > 0 THEN
            SET p_result = 'ERROR: You already have an active reservation for this book';
            ROLLBACK;
        ELSE
            -- Check available copies
            SELECT available_copies INTO v_available_copies
            FROM Books
            WHERE book_id = p_book_id;
            
            -- Set expiry date (7 days from reservation)
            SET v_expiry_date = DATE_ADD(CURDATE(), INTERVAL 7 DAY);
            
            IF v_available_copies > 0 THEN
                -- Book is available, create reservation
                INSERT INTO Reservations (user_id, book_id, reservation_date, status, expiry_date)
                VALUES (p_user_id, p_book_id, CURDATE(), 'active', v_expiry_date);
                
                -- Log the activity
                INSERT INTO ActivityLog (user_id, activity_type, activity_description)
                VALUES (p_user_id, 'reservation', CONCAT('Reserved book ID: ', p_book_id));
                
                -- Send notification
                INSERT INTO Notifications (user_id, notification_type, message)
                VALUES (p_user_id, 'reservation_ready', 
                        CONCAT('Your reservation for book ID ', p_book_id, ' is ready for pickup.'));
                
                SET p_result = CONCAT('SUCCESS: Book reserved. Reservation expires on ', v_expiry_date);
                COMMIT;
            ELSE
                -- Book not available, still create reservation for waiting list
                INSERT INTO Reservations (user_id, book_id, reservation_date, status, expiry_date)
                VALUES (p_user_id, p_book_id, CURDATE(), 'active', v_expiry_date);
                
                -- Log the activity
                INSERT INTO ActivityLog (user_id, activity_type, activity_description)
                VALUES (p_user_id, 'reservation', CONCAT('Reserved book ID: ', p_book_id, ' (waiting list)'));
                
                SET p_result = 'SUCCESS: Book currently unavailable. You are added to the waiting list.';
                COMMIT;
            END IF;
        END IF;
    END IF;
END//

-- =============================================
-- Stored Procedure: CheckoutBook
-- Handles the checkout process
-- Updates available copies and creates transaction
-- =============================================
DROP PROCEDURE IF EXISTS CheckoutBook//

CREATE PROCEDURE CheckoutBook(
    IN p_user_id INT,
    IN p_book_id INT,
    IN p_checkout_days INT,
    OUT p_result VARCHAR(255)
)
BEGIN
    DECLARE v_available_copies INT;
    DECLARE v_due_date DATE;
    DECLARE v_book_title VARCHAR(300);
    DECLARE v_user_status VARCHAR(20);
    
    -- Start transaction
    START TRANSACTION;
    
    -- Get user status
    SELECT membership_status INTO v_user_status
    FROM Users
    WHERE user_id = p_user_id;
    
    -- Check if user can checkout (must be active)
    IF v_user_status != 'active' THEN
        SET p_result = 'ERROR: User account is not active';
        ROLLBACK;
    ELSE
        -- Get book details with row lock
        SELECT available_copies, title INTO v_available_copies, v_book_title
        FROM Books
        WHERE book_id = p_book_id
        FOR UPDATE;
        
        IF v_available_copies IS NULL THEN
            SET p_result = 'ERROR: Book not found';
            ROLLBACK;
        ELSEIF v_available_copies <= 0 THEN
            SET p_result = 'ERROR: No copies available for checkout';
            ROLLBACK;
        ELSE
            -- Calculate due date
            SET v_due_date = DATE_ADD(CURDATE(), INTERVAL p_checkout_days DAY);
            
            -- Update available copies
            UPDATE Books
            SET available_copies = available_copies - 1
            WHERE book_id = p_book_id;
            
            -- Create transaction record
            INSERT INTO Transactions (user_id, book_id, checkout_date, due_date, status)
            VALUES (p_user_id, p_book_id, CURDATE(), v_due_date, 'checked_out');
            
            -- Log the activity
            INSERT INTO ActivityLog (user_id, activity_type, activity_description)
            VALUES (p_user_id, 'checkout', CONCAT('Checked out "', v_book_title, '"'));
            
            -- Update user last activity
            UPDATE Users
            SET last_activity_date = CURRENT_TIMESTAMP
            WHERE user_id = p_user_id;
            
            -- If user had a reservation, mark it as fulfilled
            UPDATE Reservations
            SET status = 'fulfilled'
            WHERE user_id = p_user_id 
              AND book_id = p_book_id 
              AND status = 'active';
            
            SET p_result = CONCAT('SUCCESS: Book checked out. Due date: ', v_due_date);
            COMMIT;
        END IF;
    END IF;
END//

-- =============================================
-- Stored Procedure: ReturnBook
-- Handles the return process
-- Updates available copies and transaction status
-- =============================================
DROP PROCEDURE IF EXISTS ReturnBook//

CREATE PROCEDURE ReturnBook(
    IN p_transaction_id INT,
    OUT p_result VARCHAR(255)
)
BEGIN
    DECLARE v_book_id INT;
    DECLARE v_user_id INT;
    DECLARE v_due_date DATE;
    DECLARE v_fine_amount DECIMAL(10, 2);
    DECLARE v_days_overdue INT;
    
    -- Start transaction
    START TRANSACTION;
    
    -- Get transaction details
    SELECT book_id, user_id, due_date INTO v_book_id, v_user_id, v_due_date
    FROM Transactions
    WHERE transaction_id = p_transaction_id AND return_date IS NULL;
    
    IF v_book_id IS NULL THEN
        SET p_result = 'ERROR: Transaction not found or book already returned';
        ROLLBACK;
    ELSE
        -- Calculate fine if overdue (e.g., $0.50 per day)
        SET v_days_overdue = GREATEST(0, DATEDIFF(CURDATE(), v_due_date));
        SET v_fine_amount = v_days_overdue * 0.50;
        
        -- Update transaction
        UPDATE Transactions
        SET return_date = CURDATE(),
            status = 'returned',
            fine_amount = v_fine_amount
        WHERE transaction_id = p_transaction_id;
        
        -- Increase available copies
        UPDATE Books
        SET available_copies = available_copies + 1
        WHERE book_id = v_book_id;
        
        -- Log the activity
        INSERT INTO ActivityLog (user_id, activity_type, activity_description)
        VALUES (v_user_id, 'return', CONCAT('Returned book ID: ', v_book_id));
        
        -- Update user last activity
        UPDATE Users
        SET last_activity_date = CURRENT_TIMESTAMP
        WHERE user_id = v_user_id;
        
        IF v_fine_amount > 0 THEN
            SET p_result = CONCAT('SUCCESS: Book returned. Fine: $', v_fine_amount);
        ELSE
            SET p_result = 'SUCCESS: Book returned on time. No fine.';
        END IF;
        
        COMMIT;
    END IF;
END//

-- =============================================
-- Stored Procedure: GetUserBorrowingHistory
-- Retrieves borrowing recommendations based on history
-- =============================================
DROP PROCEDURE IF EXISTS GetUserBorrowingHistory//

CREATE PROCEDURE GetUserBorrowingHistory(
    IN p_user_id INT
)
BEGIN
    SELECT 
        t.transaction_id,
        b.title AS book_title,
        a.name AS author_name,
        g.name AS genre,
        t.checkout_date,
        t.return_date,
        t.status
    FROM Transactions t
    JOIN Books b ON t.book_id = b.book_id
    JOIN Authors a ON b.author_id = a.author_id
    LEFT JOIN Genres g ON b.genre_id = g.genre_id
    WHERE t.user_id = p_user_id
    ORDER BY t.checkout_date DESC;
END//

DELIMITER ;

-- =============================================
-- Display stored procedures summary
-- =============================================
SELECT 'Stored procedures created successfully!' AS Status;

SHOW PROCEDURE STATUS WHERE Db = 'LibraryManagementSystem';
