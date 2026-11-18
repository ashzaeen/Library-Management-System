-- =============================================
-- Library Management System - Triggers
-- =============================================

USE LibraryManagementSystem;

DELIMITER //

-- =============================================
-- Trigger: UpdateOverdueStatus
-- Automatically updates transaction status to overdue
-- when due date has passed
-- =============================================
DROP TRIGGER IF EXISTS UpdateOverdueStatus//

CREATE TRIGGER UpdateOverdueStatus
BEFORE UPDATE ON Transactions
FOR EACH ROW
BEGIN
    -- If transaction is still checked out and past due date, mark as overdue
    IF NEW.return_date IS NULL 
       AND NEW.due_date < CURDATE() 
       AND OLD.status != 'overdue' THEN
        SET NEW.status = 'overdue';
    END IF;
END//

-- =============================================
-- Trigger: SendOverdueNotification
-- Automatically sends overdue notification
-- when transaction status changes to overdue
-- =============================================
DROP TRIGGER IF EXISTS SendOverdueNotification//

CREATE TRIGGER SendOverdueNotification
AFTER UPDATE ON Transactions
FOR EACH ROW
BEGIN
    DECLARE v_book_title VARCHAR(300);
    DECLARE v_notification_message TEXT;
    
    -- If status changed to overdue, send notification
    IF NEW.status = 'overdue' AND OLD.status != 'overdue' THEN
        -- Get book title
        SELECT title INTO v_book_title
        FROM Books
        WHERE book_id = NEW.book_id;
        
        -- Create notification message
        SET v_notification_message = CONCAT(
            'Your book "', v_book_title, 
            '" is overdue. It was due on ', NEW.due_date, 
            '. Please return it as soon as possible to avoid additional fines.'
        );
        
        -- Insert notification
        INSERT INTO Notifications (user_id, notification_type, message, related_transaction_id)
        VALUES (NEW.user_id, 'overdue', v_notification_message, NEW.transaction_id);
    END IF;
END//

-- =============================================
-- Trigger: UpdateUserActivityOnCheckout
-- Updates user activity status on checkout
-- =============================================
DROP TRIGGER IF EXISTS UpdateUserActivityOnCheckout//

CREATE TRIGGER UpdateUserActivityOnCheckout
AFTER INSERT ON Transactions
FOR EACH ROW
BEGIN
    -- Update user's last activity date
    UPDATE Users
    SET last_activity_date = CURRENT_TIMESTAMP
    WHERE user_id = NEW.user_id;
    
    -- Log the activity
    INSERT INTO ActivityLog (user_id, activity_type, activity_description)
    VALUES (NEW.user_id, 'checkout', CONCAT('Checked out book ID: ', NEW.book_id));
END//

-- =============================================
-- Trigger: UpdateUserActivityOnReturn
-- Updates user activity status on return
-- =============================================
DROP TRIGGER IF EXISTS UpdateUserActivityOnReturn//

CREATE TRIGGER UpdateUserActivityOnReturn
AFTER UPDATE ON Transactions
FOR EACH ROW
BEGIN
    -- If book was just returned, update user activity
    IF NEW.return_date IS NOT NULL AND OLD.return_date IS NULL THEN
        UPDATE Users
        SET last_activity_date = CURRENT_TIMESTAMP
        WHERE user_id = NEW.user_id;
    END IF;
END//

-- =============================================
-- Trigger: SendDueSoonNotification
-- Sends notification 3 days before due date
-- This would typically be called by a scheduled job
-- but we can simulate it with an insert trigger
-- =============================================
DROP TRIGGER IF EXISTS CheckDueSoonOnInsert//

CREATE TRIGGER CheckDueSoonOnInsert
AFTER INSERT ON Transactions
FOR EACH ROW
BEGIN
    DECLARE v_book_title VARCHAR(300);
    DECLARE v_days_until_due INT;
    
    -- Calculate days until due
    SET v_days_until_due = DATEDIFF(NEW.due_date, CURDATE());
    
    -- If due in 3 days or less, send notification
    IF v_days_until_due <= 3 AND v_days_until_due >= 0 THEN
        SELECT title INTO v_book_title
        FROM Books
        WHERE book_id = NEW.book_id;
        
        INSERT INTO Notifications (user_id, notification_type, message, related_transaction_id)
        VALUES (NEW.user_id, 'due_soon', 
                CONCAT('Reminder: Your book "', v_book_title, '" is due in ', v_days_until_due, ' days.'),
                NEW.transaction_id);
    END IF;
END//

-- =============================================
-- Trigger: ValidateBookAvailability
-- Ensures book availability constraints before checkout
-- =============================================
DROP TRIGGER IF EXISTS ValidateBookAvailability//

CREATE TRIGGER ValidateBookAvailability
BEFORE INSERT ON Transactions
FOR EACH ROW
BEGIN
    DECLARE v_available INT;
    
    -- Check if book has available copies
    SELECT available_copies INTO v_available
    FROM Books
    WHERE book_id = NEW.book_id;
    
    IF v_available <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot checkout: No copies available';
    END IF;
END//

-- =============================================
-- Trigger: ExpireOldReservations
-- Marks reservations as expired if past expiry date
-- =============================================
DROP TRIGGER IF EXISTS ExpireReservationOnUpdate//

CREATE TRIGGER ExpireReservationOnUpdate
BEFORE UPDATE ON Reservations
FOR EACH ROW
BEGIN
    -- If reservation is active and past expiry date, mark as expired
    IF NEW.status = 'active' 
       AND NEW.expiry_date < CURDATE() THEN
        SET NEW.status = 'expired';
    END IF;
END//

-- =============================================
-- Trigger: LogReservationActivity
-- Logs reservation creation to activity log
-- =============================================
DROP TRIGGER IF EXISTS LogReservationActivity//

CREATE TRIGGER LogReservationActivity
AFTER INSERT ON Reservations
FOR EACH ROW
BEGIN
    DECLARE v_book_title VARCHAR(300);
    
    SELECT title INTO v_book_title
    FROM Books
    WHERE book_id = NEW.book_id;
    
    INSERT INTO ActivityLog (user_id, activity_type, activity_description)
    VALUES (NEW.user_id, 'reservation', CONCAT('Reserved "', v_book_title, '"'));
END//

DELIMITER ;

-- =============================================
-- Display triggers summary
-- =============================================
SELECT 'Triggers created successfully!' AS Status;

SHOW TRIGGERS FROM LibraryManagementSystem;
