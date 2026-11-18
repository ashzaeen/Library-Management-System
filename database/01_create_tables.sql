-- =============================================
-- Library Management System - Database Schema
-- =============================================

-- Drop existing database if it exists
DROP DATABASE IF EXISTS LibraryManagementSystem;

-- Create database
CREATE DATABASE LibraryManagementSystem;
USE LibraryManagementSystem;

-- =============================================
-- Table: Genres
-- Stores different book genres
-- =============================================
CREATE TABLE Genres (
    genre_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- =============================================
-- Table: Authors
-- Stores author information
-- =============================================
CREATE TABLE Authors (
    author_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(200) NOT NULL,
    biography TEXT,
    birth_date DATE,
    nationality VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_author_name (name)
) ENGINE=InnoDB;

-- =============================================
-- Table: Books
-- Stores book information
-- =============================================
CREATE TABLE Books (
    book_id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(300) NOT NULL,
    isbn VARCHAR(20) UNIQUE,
    author_id INT NOT NULL,
    genre_id INT,
    publication_year SMALLINT,  -- FIXED: Changed from YEAR to SMALLINT to support historical dates
    publisher VARCHAR(200),
    total_copies INT NOT NULL DEFAULT 1,
    available_copies INT NOT NULL DEFAULT 1,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (author_id) REFERENCES Authors(author_id) ON DELETE RESTRICT,
    FOREIGN KEY (genre_id) REFERENCES Genres(genre_id) ON DELETE SET NULL,
    
    INDEX idx_title (title),
    INDEX idx_isbn (isbn),
    INDEX idx_author (author_id),
    INDEX idx_genre (genre_id),
    
    CHECK (total_copies >= 0),
    CHECK (available_copies >= 0),
    CHECK (available_copies <= total_copies)
) ENGINE=InnoDB;

-- =============================================
-- Table: Users
-- Stores library user/member information
-- =============================================
CREATE TABLE Users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(200) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20),
    address TEXT,
    registration_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    membership_status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    last_activity_date TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_email (email),
    INDEX idx_membership_status (membership_status),
    INDEX idx_registration_date (registration_date)
) ENGINE=InnoDB;

-- =============================================
-- Table: Transactions
-- Records book checkouts and returns
-- =============================================
CREATE TABLE Transactions (
    transaction_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    book_id INT NOT NULL,
    checkout_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    due_date DATE NOT NULL,
    return_date DATE NULL,
    status ENUM('checked_out', 'returned', 'overdue') DEFAULT 'checked_out',
    fine_amount DECIMAL(10, 2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES Books(book_id) ON DELETE CASCADE,
    
    INDEX idx_user (user_id),
    INDEX idx_book (book_id),
    INDEX idx_checkout_date (checkout_date),
    INDEX idx_due_date (due_date),
    INDEX idx_status (status),
    
    CHECK (due_date >= checkout_date),
    CHECK (return_date IS NULL OR return_date >= checkout_date)
) ENGINE=InnoDB;

-- =============================================
-- Table: Reservations
-- Tracks book reservations
-- =============================================
CREATE TABLE Reservations (
    reservation_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    book_id INT NOT NULL,
    reservation_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    status ENUM('active', 'fulfilled', 'cancelled', 'expired') DEFAULT 'active',
    expiry_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES Books(book_id) ON DELETE CASCADE,
    
    INDEX idx_user (user_id),
    INDEX idx_book (book_id),
    INDEX idx_status (status),
    INDEX idx_reservation_date (reservation_date)
) ENGINE=InnoDB;

-- =============================================
-- Table: Notifications
-- Tracks notifications sent to users
-- =============================================
CREATE TABLE Notifications (
    notification_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    notification_type ENUM('overdue', 'reservation_ready', 'due_soon', 'general') DEFAULT 'general',
    message TEXT NOT NULL,
    notification_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_read BOOLEAN DEFAULT FALSE,
    related_transaction_id INT NULL,
    
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (related_transaction_id) REFERENCES Transactions(transaction_id) ON DELETE SET NULL,
    
    INDEX idx_user (user_id),
    INDEX idx_type (notification_type),
    INDEX idx_date (notification_date),
    INDEX idx_is_read (is_read)
) ENGINE=InnoDB;

-- =============================================
-- Table: ActivityLog
-- Tracks user activity for analytics
-- =============================================
CREATE TABLE ActivityLog (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    activity_type ENUM('checkout', 'return', 'reservation', 'search', 'login') NOT NULL,
    activity_description TEXT,
    activity_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    
    INDEX idx_user (user_id),
    INDEX idx_activity_type (activity_type),
    INDEX idx_timestamp (activity_timestamp)
) ENGINE=InnoDB;

-- =============================================
-- Display table creation summary
-- =============================================
SELECT 'Database schema created successfully!' AS Status;
SHOW TABLES;
