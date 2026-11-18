# Library Management System

A MySQL-backed library management system: a normalized (3NF) relational schema, business logic in stored procedures and triggers, reporting views, and a Python desktop app on top. Built as my Honors Project for CSE 3330 (Database Systems) at UT Arlington.

## What it does

- **Catalog:** books with one author and one genre each, ISBNs, and total vs. available copies.
- **Members:** registration, membership status (active / inactive / suspended) and last-activity tracking.
- **Circulation:** checkout and return with automatic due dates and fine calculation.
- **Reservations:** reserve a book even while it is checked out, with expiry dates.
- **Automation:** triggers flag a loan as overdue when its row is updated, send overdue and due-soon notifications, reject checkouts with no copies left, expire stale reservations and write an activity log.
- **Analytics:** views and ten ready-made reports for librarians.

## Database at a glance

```mermaid
erDiagram
    GENRES ||--o{ BOOKS : "classifies (optional)"
    AUTHORS ||--|{ BOOKS : "writes"
    USERS ||--o{ TRANSACTIONS : "borrows"
    BOOKS ||--o{ TRANSACTIONS : "is borrowed in"
    USERS ||--o{ RESERVATIONS : "places"
    BOOKS ||--o{ RESERVATIONS : "is reserved in"
    USERS ||--o{ NOTIFICATIONS : "receives"
    TRANSACTIONS |o--o{ NOTIFICATIONS : "triggers (optional)"
    USERS ||--o{ ACTIVITYLOG : "generates"

    GENRES {
        int genre_id PK "AUTO_INCREMENT"
        varchar name UK "100, NOT NULL"
        text description
        timestamp created_at "DEFAULT now"
    }
    AUTHORS {
        int author_id PK "AUTO_INCREMENT"
        varchar name "200, NOT NULL, indexed"
        text biography
        date birth_date
        varchar nationality "100"
        timestamp created_at "DEFAULT now"
    }
    BOOKS {
        int book_id PK "AUTO_INCREMENT"
        varchar title "300, NOT NULL, indexed"
        varchar isbn UK "20, indexed"
        int author_id FK "NOT NULL, ON DELETE RESTRICT"
        int genre_id FK "ON DELETE SET NULL"
        smallint publication_year
        varchar publisher "200"
        int total_copies "NOT NULL, DEFAULT 1"
        int available_copies "NOT NULL, DEFAULT 1"
        text description
        timestamp created_at
        timestamp updated_at "ON UPDATE now"
    }
    USERS {
        int user_id PK "AUTO_INCREMENT"
        varchar name "200, NOT NULL"
        varchar email UK "255, NOT NULL, indexed"
        varchar phone "20"
        text address
        date registration_date "NOT NULL, DEFAULT today, indexed"
        enum membership_status "active|inactive|suspended, indexed"
        timestamp last_activity_date "NULL until first activity"
        timestamp created_at
    }
    TRANSACTIONS {
        int transaction_id PK "AUTO_INCREMENT"
        int user_id FK "NOT NULL, ON DELETE CASCADE"
        int book_id FK "NOT NULL, ON DELETE CASCADE"
        date checkout_date "NOT NULL, DEFAULT today, indexed"
        date due_date "NOT NULL, indexed"
        date return_date "NULL while out"
        enum status "checked_out|returned|overdue, indexed"
        decimal fine_amount "10,2 DEFAULT 0.00"
        timestamp created_at
        timestamp updated_at "ON UPDATE now"
    }
    RESERVATIONS {
        int reservation_id PK "AUTO_INCREMENT"
        int user_id FK "NOT NULL, ON DELETE CASCADE"
        int book_id FK "NOT NULL, ON DELETE CASCADE"
        date reservation_date "NOT NULL, DEFAULT today, indexed"
        enum status "active|fulfilled|cancelled|expired, indexed"
        date expiry_date
        timestamp created_at
        timestamp updated_at "ON UPDATE now"
    }
    NOTIFICATIONS {
        int notification_id PK "AUTO_INCREMENT"
        int user_id FK "NOT NULL, ON DELETE CASCADE"
        enum notification_type "overdue|reservation_ready|due_soon|general, indexed"
        text message "NOT NULL"
        timestamp notification_date "DEFAULT now, indexed"
        boolean is_read "DEFAULT FALSE, indexed"
        int related_transaction_id FK "NULL, ON DELETE SET NULL"
    }
    ACTIVITYLOG {
        int log_id PK "AUTO_INCREMENT"
        int user_id FK "NOT NULL, ON DELETE CASCADE"
        enum activity_type "checkout|return|reservation|search|login, indexed"
        text activity_description
        timestamp activity_timestamp "DEFAULT now, indexed"
    }
```

More diagrams, all rendered natively by GitHub: foreign-key delete rules, status lifecycles, flowcharts for each stored procedure, a trigger map, a checkout sequence diagram, view dependencies, the app's screen map and the build order. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Repository layout

```
database/
  01_create_tables.sql        schema: 8 tables, keys, indexes, CHECK constraints
  02_insert_data.sql          sample genres, authors, books, users and transactions
  03_stored_procedures.sql    ReserveBook, CheckoutBook, ReturnBook, GetUserBorrowingHistory
  04_triggers.sql             8 triggers (overdue, notifications, availability, activity log)
  05_queries_and_views.sql    example queries + 5 views
  06_reports.sql              10 analytics reports
app/
  library_app.py              Tkinter desktop app
  requirements.txt
docs/
  ARCHITECTURE.md             ER diagram, flows, trigger map, view dependencies, app map
LICENSE                       MIT
```

### Schema

`Genres`, `Authors`, `Books`, `Users`, `Transactions`, `Reservations`, `Notifications`, `ActivityLog`.

### Stored procedures

| Procedure | Purpose |
| --- | --- |
| `ReserveBook` | Place a reservation for a user |
| `CheckoutBook` | Check a book out and update availability |
| `ReturnBook` | Return a book and compute any fine |
| `GetUserBorrowingHistory` | A member's full borrowing history |

### Views

`vw_OverdueBooks`, `vw_UserDashboard`, `vw_PopularGenres`, `vw_BookInventory`, `vw_UserActivitySummary`.

### Reports (`06_reports.sql`)

Monthly borrowing statistics, most active users, most borrowed books, overdue notifications sent, reservation trends, genre performance, daily operations summary, fine collection summary, author popularity and user retention.

## Getting started

**Requirements:** MySQL 8.0.16 or newer (the schema uses `CHECK` constraints), Python 3.9+.

1. Create the database, in order. Note that `01_create_tables.sql` drops and recreates `LibraryManagementSystem`.

   ```bash
   mysql -u root -p < database/01_create_tables.sql
   mysql -u root -p < database/02_insert_data.sql
   mysql -u root -p < database/03_stored_procedures.sql
   mysql -u root -p < database/04_triggers.sql
   mysql -u root -p < database/05_queries_and_views.sql
   mysql -u root -p < database/06_reports.sql   # optional: runs the report queries
   ```

2. Run the app:

   ```bash
   pip install -r app/requirements.txt
   export LMS_DB_USER=root
   export LMS_DB_PASSWORD=your-password   # PowerShell: $env:LMS_DB_PASSWORD="your-password"
   python app/library_app.py
   ```

   It connects to `localhost` and the `LibraryManagementSystem` database.

3. Sign in. Choose **user** and enter the email of a member from the sample data (or register one), or choose **librarian** and use the demo account `admin@library.com`.

## Status

The database layer (schema, procedures, triggers, views, reports) is implemented and tested on MySQL 8.0: checkout (including a title's last copy), return with fines, reservations and waiting lists, and overdue notifications all behave as described. Overdue status is set by a trigger when a loan row changes; there is no scheduled job, so the sample data's old loans only flip to overdue once updated. The desktop app is a work in progress: sign-in, registration, role-based navigation and the librarian dashboard with live statistics work. The remaining screens (manage books and users, transactions, reservations, reports, search and the member views) are placeholders. Sign-in is a demo: members are looked up by email only and the librarian account is hard-coded, so don't use it as-is for anything real.

## License

[MIT](LICENSE).

## Author

Ashzaeen Fatmi Khan, University of Texas at Arlington.
