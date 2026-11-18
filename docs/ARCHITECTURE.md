# Architecture and diagrams

Every diagram here is written in [Mermaid](https://mermaid.js.org/), so GitHub renders it natively (light and dark) and the source stays diff-able. They are derived directly from the SQL in [`database/`](../database) and the app in [`app/library_app.py`](../app/library_app.py).

**Contents**

1. [Entity-relationship diagram](#1-entity-relationship-diagram)
2. [Foreign keys and delete behaviour](#2-foreign-keys-and-delete-behaviour)
3. [Status lifecycles](#3-status-lifecycles)
4. [Stored procedure flows](#4-stored-procedure-flows)
5. [Trigger map](#5-trigger-map)
6. [Checkout end to end](#6-checkout-end-to-end)
7. [Views and the tables they read](#7-views-and-the-tables-they-read)
8. [Desktop app](#8-desktop-app)
9. [Build and setup order](#9-build-and-setup-order)

---

## 1. Entity-relationship diagram

Eight tables, all InnoDB. `PK` = primary key, `FK` = foreign key, `UK` = unique. Business rules enforced by `CHECK` constraints are listed under the diagram.

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

**`CHECK` constraints**

| Table | Rule |
| --- | --- |
| `Books` | `total_copies >= 0`, `available_copies >= 0`, `available_copies <= total_copies` |
| `Transactions` | `due_date >= checkout_date`, and `return_date IS NULL OR return_date >= checkout_date` |

These need MySQL 8.0.16 or newer, which is why the README states that minimum.

**Normal form.** Each table is in 3NF: authors and genres are separate entities instead of repeating text on `Books`, and every non-key column depends on the key, the whole key and nothing but the key. The one intentional redundancy is `Books.available_copies`, which is derivable from `total_copies` minus open loans and is kept as a stored counter so availability checks are a single row read.

---

## 2. Foreign keys and delete behaviour

What happens to child rows when a parent row is deleted. Arrows run from parent to child; the label is the `ON DELETE` rule.

```mermaid
flowchart LR
    A[Authors] -- RESTRICT --> B[Books]
    G[Genres] -- "SET NULL" --> B
    U[Users] -- CASCADE --> T[Transactions]
    B -- CASCADE --> T
    U -- CASCADE --> R[Reservations]
    B -- CASCADE --> R
    U -- CASCADE --> N[Notifications]
    T -- "SET NULL" --> N
    U -- CASCADE --> L[ActivityLog]
```

- **RESTRICT** on `Authors → Books`: an author with books cannot be deleted, so no book is ever orphaned.
- **SET NULL** on `Genres → Books` and `Transactions → Notifications`: the child survives without the link (a book can be uncategorised; a notification outlives its loan).
- **CASCADE** everywhere else: deleting a member or a book removes their loans, reservations, notifications and activity.

---

## 3. Status lifecycles

### Transaction (loan)

```mermaid
stateDiagram-v2
    direction LR
    [*] --> checked_out : CheckoutBook inserts the row
    checked_out --> overdue : any UPDATE after due_date (UpdateOverdueStatus)
    checked_out --> returned : ReturnBook sets return_date and fine
    overdue --> returned : ReturnBook, fine = days late x 0.50
    returned --> [*]

    note right of overdue
        There is no scheduled job.
        A loan only flips to overdue
        when its row is updated.
    end note
```

### Reservation

```mermaid
stateDiagram-v2
    direction LR
    [*] --> active : ReserveBook, expires in 7 days
    active --> fulfilled : CheckoutBook by the same user
    active --> expired : any UPDATE after expiry_date (ExpireReservationOnUpdate)
    active --> cancelled : manual
    fulfilled --> [*]
    expired --> [*]
    cancelled --> [*]
```

### Membership

```mermaid
stateDiagram-v2
    direction LR
    [*] --> active : registration default
    active --> inactive : manual
    active --> suspended : manual
    inactive --> active : manual
    suspended --> active : manual

    note right of suspended
        CheckoutBook only allows
        members whose status is active
    end note
```

---

## 4. Stored procedure flows

Each procedure runs in its own `START TRANSACTION` and reports back through an `OUT p_result` parameter. Each also declares an `EXIT HANDLER FOR SQLEXCEPTION` that rolls everything back and returns `ERROR: Database error, nothing was changed`, so a failure never leaves a transaction open. Activity logging is left to the triggers (see [section 5](#5-trigger-map)) so each action is logged exactly once.

### `CheckoutBook(user_id, book_id, checkout_days, OUT result)`

```mermaid
flowchart TD
    S([CALL CheckoutBook]) --> TX[START TRANSACTION]
    TX --> UX{user exists?}
    UX -- no --> E0[/"ERROR: User not found"/] --> RB0[ROLLBACK]
    UX -- yes --> U{membership_status<br/>is active?}
    U -- no --> E1[/"ERROR: User account is not active"/]
    E1 --> RB1[ROLLBACK]
    U -- yes --> LK["SELECT available_copies, title<br/>FROM Books ... FOR UPDATE<br/>(row lock)"]
    LK --> F{book found?}
    F -- no --> E2[/"ERROR: Book not found"/] --> RB2[ROLLBACK]
    F -- yes --> A{available_copies > 0?}
    A -- no --> E3[/"ERROR: No copies available"/] --> RB3[ROLLBACK]
    A -- yes --> D["due_date = today + checkout_days"]
    D --> C2["INSERT Transactions<br/>status = checked_out<br/>(triggers validate, log, stamp user)"]
    C2 --> C1["UPDATE Books<br/>available_copies - 1"]
    C1 --> C5["UPDATE Reservations<br/>active to fulfilled<br/>(same user and book)"]
    C5 --> OK[/"SUCCESS: Book checked out. Due date: ..."/]
    OK --> CM[COMMIT]
```

### `ReturnBook(transaction_id, OUT result)`

```mermaid
flowchart TD
    S([CALL ReturnBook]) --> TX[START TRANSACTION]
    TX --> Q["SELECT book_id, user_id, due_date<br/>FROM Transactions<br/>WHERE id = ? AND return_date IS NULL"]
    Q --> F{row found?}
    F -- no --> E[/"ERROR: not found or already returned"/] --> RB[ROLLBACK]
    F -- yes --> FN["days_overdue = max(0, today - due_date)<br/>fine = days_overdue x 0.50"]
    FN --> U1["UPDATE Transactions<br/>return_date = today<br/>status = returned<br/>fine_amount = fine"]
    U1 --> U2["UPDATE Books<br/>available_copies + 1"]
    U2 --> U3["INSERT ActivityLog (return)"]
    U3 --> U4["UPDATE Users<br/>last_activity_date = now"]
    U4 --> M{fine > 0?}
    M -- yes --> R1[/"SUCCESS: Book returned. Fine: $..."/]
    M -- no --> R2[/"SUCCESS: Returned on time. No fine."/]
    R1 --> CM[COMMIT]
    R2 --> CM
```

### `ReserveBook(user_id, book_id, OUT result)`

```mermaid
flowchart TD
    S([CALL ReserveBook]) --> TX[START TRANSACTION]
    TX --> B{book exists?}
    B -- no --> E1[/"ERROR: Book not found"/] --> RB1[ROLLBACK]
    B -- yes --> U{user exists?}
    U -- no --> E2[/"ERROR: User not found"/] --> RB2[ROLLBACK]
    U -- yes --> D{already an active<br/>reservation for this book?}
    D -- yes --> E3[/"ERROR: already reserved"/] --> RB3[ROLLBACK]
    D -- no --> EX["expiry = today + 7 days"]
    EX --> AV{available_copies > 0?}
    AV -- yes --> I1["INSERT Reservations (active)<br/>(trigger logs the activity)"]
    I1 --> I3["INSERT Notifications<br/>(reservation_ready)"]
    I3 --> R1[/"SUCCESS: Book reserved. Expires on ..."/]
    AV -- no --> W1["INSERT Reservations (active)<br/>= waiting list<br/>(trigger logs the activity)"]
    W1 --> R2[/"SUCCESS: added to the waiting list"/]
    R1 --> CM[COMMIT]
    R2 --> CM
```

### `GetUserBorrowingHistory(user_id)`

A read-only procedure. It joins `Transactions → Books → Authors`, left-joins `Genres`, filters to one user and orders by `checkout_date` descending. It returns the transaction id, title, author, genre, checkout date, return date and status.

---

## 5. Trigger map

Eight triggers, grouped by the table and moment they fire on. `BEFORE` triggers can change or reject the row being written; `AFTER` triggers react to it.

```mermaid
flowchart LR
    subgraph TX["Transactions"]
        direction TB
        T_I[["INSERT"]]
        T_U[["UPDATE"]]
    end
    subgraph RS["Reservations"]
        direction TB
        R_I[["INSERT"]]
        R_U[["UPDATE"]]
    end

    T_I -- BEFORE --> V1["ValidateBookAvailability<br/>reject if no copies"]
    T_I -- AFTER --> V2["UpdateUserActivityOnCheckout"]
    T_I -- AFTER --> V3["CheckDueSoonOnInsert<br/>due in 0-3 days?"]
    T_U -- BEFORE --> V4["UpdateOverdueStatus<br/>set status = overdue"]
    T_U -- AFTER --> V5["SendOverdueNotification"]
    T_U -- AFTER --> V6["UpdateUserActivityOnReturn"]
    R_U -- BEFORE --> V7["ExpireReservationOnUpdate<br/>set status = expired"]
    R_I -- AFTER --> V8["LogReservationActivity"]

    V1 -. "SIGNAL SQLSTATE 45000" .-> X1(["error: no copies available"])
    V2 --> O1[("Users.last_activity_date")]
    V2 --> O2[("ActivityLog")]
    V3 --> O3[("Notifications: due_soon")]
    V4 -. "NEW.status" .-> O4[("Transactions.status")]
    V5 --> O5[("Notifications: overdue")]
    V6 --> O1
    V7 -. "NEW.status" .-> O6[("Reservations.status")]
    V8 --> O2
```

| Trigger | Table | When | What it does |
| --- | --- | --- | --- |
| `ValidateBookAvailability` | `Transactions` | BEFORE INSERT | Raises `SQLSTATE 45000` if the book's `available_copies <= 0`. |
| `UpdateUserActivityOnCheckout` | `Transactions` | AFTER INSERT | Stamps `Users.last_activity_date`; logs a `checkout` row. |
| `CheckDueSoonOnInsert` | `Transactions` | AFTER INSERT | If the due date is 0 to 3 days away, inserts a `due_soon` notification. |
| `UpdateOverdueStatus` | `Transactions` | BEFORE UPDATE | If not returned and past due, sets `status = 'overdue'`. |
| `SendOverdueNotification` | `Transactions` | AFTER UPDATE | When a loan becomes overdue, inserts an `overdue` notification. |
| `UpdateUserActivityOnReturn` | `Transactions` | AFTER UPDATE | When `return_date` is first set, stamps `last_activity_date`. |
| `ExpireReservationOnUpdate` | `Reservations` | BEFORE UPDATE | If active and past `expiry_date`, sets `status = 'expired'`. |
| `LogReservationActivity` | `Reservations` | AFTER INSERT | Logs a `reservation` row with the book title. |

---

## 6. Checkout end to end

What fires, and in what order, when a librarian checks a book out through `CheckoutBook`. The transaction row is inserted *before* the copy counter is decremented so that `ValidateBookAvailability` sees the real count and the last copy of a title can still be checked out.

```mermaid
sequenceDiagram
    autonumber
    actor L as Librarian / app
    participant P as CheckoutBook
    participant Bk as Books
    participant Tx as Transactions
    participant Tg as Triggers
    participant Lg as ActivityLog
    participant Nf as Notifications
    participant Us as Users
    participant Rs as Reservations

    L->>P: CALL CheckoutBook(user, book, days, @result)
    P->>Us: read membership_status
    P->>Bk: SELECT ... FOR UPDATE (lock row)
    P->>Tx: INSERT (checked_out)
    activate Tg
    Tx-->>Tg: BEFORE INSERT: ValidateBookAvailability (copies still > 0)
    Tx-->>Tg: AFTER INSERT: UpdateUserActivityOnCheckout
    Tg->>Us: last_activity_date = now
    Tg->>Lg: INSERT checkout row
    Tx-->>Tg: AFTER INSERT: CheckDueSoonOnInsert
    opt due within 3 days
        Tg->>Nf: INSERT due_soon
    end
    deactivate Tg
    P->>Bk: available_copies - 1
    P->>Rs: active to fulfilled (same user and book)
    P-->>L: SUCCESS: Book checked out. Due date ...
```

---

## 7. Views and the tables they read

Five views in [`05_queries_and_views.sql`](../database/05_queries_and_views.sql). Solid arrows are inner joins, dashed arrows are left joins.

```mermaid
flowchart LR
    Tr[Transactions]
    Us[Users]
    Bk[Books]
    Au[Authors]
    Gn[Genres]
    Rs[Reservations]

    V1(["vw_OverdueBooks<br/>overdue loans + member contact + fine"])
    V2(["vw_UserDashboard<br/>open loans UNION active reservations"])
    V3(["vw_PopularGenres<br/>checkouts, books, borrowers per genre"])
    V4(["vw_BookInventory<br/>stock status + reservation count"])
    V5(["vw_UserActivitySummary<br/>per-member totals, fines, tenure"])

    Tr --> V1
    Us --> V1
    Bk --> V1
    Au --> V1

    Us --> V2
    Tr --> V2
    Rs --> V2
    Bk --> V2
    Au --> V2

    Gn --> V3
    Bk --> V3
    Tr -.-> V3

    Bk --> V4
    Au --> V4
    Gn -.-> V4
    Rs -.-> V4

    Us --> V5
    Tr -.-> V5
    Rs -.-> V5
```

`vw_BookInventory` derives `stock_status` as **Out of Stock** (0 copies), **Low Stock** (at most 20% of total) or **In Stock**.

### Reports

[`06_reports.sql`](../database/06_reports.sql) holds ten analytics reports built on the same tables:

```mermaid
mindmap
  root((Reports))
    Borrowing
      Monthly borrowing statistics
      Most borrowed books
      Genre performance
      Author popularity
    Members
      Most active users
      User retention
    Operations
      Daily operations summary
      Fine collection summary
      Overdue notifications sent
      Reservation trends
```

---

## 8. Desktop app

[`app/library_app.py`](../app/library_app.py) is a single-class Tkinter app (`LibraryManagementApp`) using `mysql-connector-python`. It reads the DB password from the `LMS_DB_PASSWORD` environment variable and connects to `localhost`.

```mermaid
flowchart TD
    classDef todo stroke-dasharray:5 4,color:#888

    Start([python app/library_app.py]) --> Conn["connect_database()<br/>env: LMS_DB_USER, LMS_DB_PASSWORD"]
    Conn --> Login["Login screen<br/>role: user or librarian"]
    Login --> Reg["Register screen<br/>creates a Users row"]
    Reg --> Login
    Login -->|"librarian: admin@library.com"| Lib[Librarian interface]
    Login -->|"user: email lookup"| Mem[Member interface]

    Lib --> Dash["Dashboard<br/>6 live stat tiles + overdue list"]
    Lib --> MB[Manage books]:::todo
    Lib --> MU[Manage users]:::todo
    Lib --> TXN[Transactions]:::todo
    Lib --> RSV[Reservations]:::todo
    Lib --> RPT[Reports]:::todo

    Mem --> SB[Search books]:::todo
    Mem --> MC[My checkouts]:::todo
    Mem --> MR[My reservations]:::todo
    Mem --> RB[Reserve a book]:::todo
```

Solid boxes work today; dashed grey boxes are placeholders. The dashboard tiles run these counts live:

| Tile | Query |
| --- | --- |
| Total Books | `COUNT(*)` on `Books` |
| Available Books | `SUM(available_copies)` on `Books` |
| Active Users | `Users` where `membership_status = 'active'` |
| Books Checked Out | `Transactions` where `return_date IS NULL` |
| Overdue Books | `Transactions` where `status = 'overdue'` |
| Active Reservations | `Reservations` where `status = 'active'` |

Sign-in is a demo: members are matched by email only and the librarian account is hard-coded.

---

## 9. Build and setup order

The scripts depend on each other, so run them in this order. `01` drops and recreates the database.

```mermaid
flowchart LR
    A["01_create_tables.sql<br/>schema, keys, indexes, CHECKs"] --> B["02_insert_data.sql<br/>sample data"]
    B --> C["03_stored_procedures.sql<br/>4 procedures"]
    C --> D["04_triggers.sql<br/>8 triggers"]
    D --> E["05_queries_and_views.sql<br/>5 queries + 5 views"]
    E --> F["06_reports.sql<br/>10 reports (optional)"]
    F --> G["pip install -r app/requirements.txt"]
    G --> H["set LMS_DB_USER / LMS_DB_PASSWORD"]
    H --> I(["python app/library_app.py"])
```
