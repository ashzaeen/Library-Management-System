"""
Name: Ashzaeen Fatmi Khan
Library Management System - Desktop Application
A comprehensive GUI application for managing library operations
"""

import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import mysql.connector
from mysql.connector import Error
from datetime import datetime, timedelta
import hashlib
import os

class LibraryManagementApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Library Management System")
        self.root.geometry("1200x700")
        self.root.resizable(True, True)
        
        # Database connection
        self.connection = None
        self.current_user = None
        self.user_role = None  # 'librarian' or 'user'
        
        # Color scheme
        self.bg_color = "#f0f0f0"
        self.primary_color = "#2c3e50"
        self.secondary_color = "#3498db"
        self.accent_color = "#e74c3c"
        
        # Configure root window
        self.root.configure(bg=self.bg_color)
        
        # Create login screen first
        self.create_login_screen()
    
    def connect_database(self):
        """Establish connection to MySQL database.

        Reuses the open connection if there is one. Opening a fresh one on every
        screen (and dropping the old one) left cursors pointing at a connection
        that no longer existed, which raised ReferenceError on librarian login.
        """
        if self.connection is not None:
            try:
                if self.connection.is_connected():
                    return True
            except Error:
                pass
            self.connection = None  # it dropped; fall through and reconnect
        try:
            self.connection = mysql.connector.connect(
                host='localhost',
                database='LibraryManagementSystem',
                user=os.getenv('LMS_DB_USER', 'root'),
                password=os.getenv('LMS_DB_PASSWORD', '')
            )
            if self.connection.is_connected():
                return True
        except Error as e:
            messagebox.showerror("Database Error", f"Error connecting to database: {e}")
            return False
    
    def create_login_screen(self):
        """Create login interface"""
        # Clear window
        for widget in self.root.winfo_children():
            widget.destroy()
        
        # Main frame
        login_frame = tk.Frame(self.root, bg=self.bg_color)
        login_frame.place(relx=0.5, rely=0.5, anchor="center")
        
        # Title
        title_label = tk.Label(
            login_frame,
            text="Library Management System",
            font=("Arial", 24, "bold"),
            bg=self.bg_color,
            fg=self.primary_color
        )
        title_label.pack(pady=20)
        
        # Role selection
        role_frame = tk.Frame(login_frame, bg=self.bg_color)
        role_frame.pack(pady=10)
        
        tk.Label(
            role_frame,
            text="Login as:",
            font=("Arial", 12),
            bg=self.bg_color
        ).pack(side=tk.LEFT, padx=5)
        
        self.role_var = tk.StringVar(value="user")
        
        tk.Radiobutton(
            role_frame,
            text="User",
            variable=self.role_var,
            value="user",
            font=("Arial", 11),
            bg=self.bg_color
        ).pack(side=tk.LEFT, padx=10)
        
        tk.Radiobutton(
            role_frame,
            text="Librarian",
            variable=self.role_var,
            value="librarian",
            font=("Arial", 11),
            bg=self.bg_color
        ).pack(side=tk.LEFT, padx=10)
        
        # Email entry
        tk.Label(
            login_frame,
            text="Email:",
            font=("Arial", 12),
            bg=self.bg_color
        ).pack(pady=(20, 5))
        
        self.email_entry = tk.Entry(login_frame, font=("Arial", 11), width=30)
        self.email_entry.pack()
        
        # Login button
        login_btn = tk.Button(
            login_frame,
            text="Login",
            font=("Arial", 12, "bold"),
            bg=self.secondary_color,
            fg="white",
            width=20,
            cursor="hand2",
            command=self.login
        )
        login_btn.pack(pady=20)
        
        # Register button
        register_btn = tk.Button(
            login_frame,
            text="New User? Register Here",
            font=("Arial", 10),
            bg=self.bg_color,
            fg=self.secondary_color,
            bd=0,
            cursor="hand2",
            command=self.show_register_screen
        )
        register_btn.pack()
    
    def login(self):
        """Handle login"""
        email = self.email_entry.get().strip()
        role = self.role_var.get()
        
        if not email:
            messagebox.showerror("Error", "Please enter your email")
            return
        
        if not self.connect_database():
            return
        
        try:
            cursor = self.connection.cursor(dictionary=True)
            
            if role == "librarian":
                # For demo purposes, allow specific email as librarian
                if email == "admin@library.com":
                    self.user_role = "librarian"
                    self.current_user = {"name": "Administrator", "email": email}
                    self.create_main_interface()
                else:
                    messagebox.showerror("Error", "Invalid librarian credentials")
            else:
                # Check if user exists
                cursor.execute("SELECT * FROM Users WHERE email = %s", (email,))
                user = cursor.fetchone()
                
                if user:
                    self.user_role = "user"
                    self.current_user = user
                    self.create_main_interface()
                else:
                    messagebox.showerror("Error", "User not found. Please register first.")
            
            cursor.close()
        except Error as e:
            messagebox.showerror("Error", f"Login failed: {e}")
    
    def show_register_screen(self):
        """Show registration form"""
        reg_window = tk.Toplevel(self.root)
        reg_window.title("User Registration")
        reg_window.geometry("400x500")
        reg_window.configure(bg=self.bg_color)
        
        # Title
        tk.Label(
            reg_window,
            text="New User Registration",
            font=("Arial", 16, "bold"),
            bg=self.bg_color,
            fg=self.primary_color
        ).pack(pady=20)
        
        # Form fields
        fields = [
            ("Full Name:", "name"),
            ("Email:", "email"),
            ("Phone:", "phone"),
            ("Address:", "address")
        ]
        
        entries = {}
        
        for label_text, field_name in fields:
            tk.Label(
                reg_window,
                text=label_text,
                font=("Arial", 11),
                bg=self.bg_color
            ).pack(pady=(10, 2))
            
            if field_name == "address":
                entry = tk.Text(reg_window, height=3, width=30, font=("Arial", 10))
            else:
                entry = tk.Entry(reg_window, font=("Arial", 11), width=30)
            entry.pack()
            entries[field_name] = entry
        
        def register_user():
            if not self.connect_database():
                return
            
            try:
                # Get values
                name = entries["name"].get() if hasattr(entries["name"], 'get') else entries["name"].get("1.0", "end-1c")
                email = entries["email"].get()
                phone = entries["phone"].get()
                address = entries["address"].get("1.0", "end-1c")
                
                if not all([name, email]):
                    messagebox.showerror("Error", "Name and Email are required")
                    return
                
                cursor = self.connection.cursor()
                query = """INSERT INTO Users (name, email, phone, address, registration_date, membership_status)
                           VALUES (%s, %s, %s, %s, CURDATE(), 'active')"""
                cursor.execute(query, (name, email, phone, address))
                self.connection.commit()
                cursor.close()
                
                messagebox.showinfo("Success", "Registration successful! You can now login.")
                reg_window.destroy()
            except Error as e:
                messagebox.showerror("Error", f"Registration failed: {e}")
        
        # Register button
        tk.Button(
            reg_window,
            text="Register",
            font=("Arial", 12, "bold"),
            bg=self.secondary_color,
            fg="white",
            width=15,
            cursor="hand2",
            command=register_user
        ).pack(pady=20)
    
    def create_main_interface(self):
        """Create main application interface"""
        # Clear window
        for widget in self.root.winfo_children():
            widget.destroy()
        
        # Top bar
        top_bar = tk.Frame(self.root, bg=self.primary_color, height=60)
        top_bar.pack(fill=tk.X)
        top_bar.pack_propagate(False)
        
        # Title
        tk.Label(
            top_bar,
            text="Library Management System",
            font=("Arial", 18, "bold"),
            bg=self.primary_color,
            fg="white"
        ).pack(side=tk.LEFT, padx=20, pady=15)
        
        # User info
        user_name = self.current_user.get('name', 'Admin')
        role_text = "Librarian" if self.user_role == "librarian" else "Member"
        
        tk.Label(
            top_bar,
            text=f"{user_name} ({role_text})",
            font=("Arial", 11),
            bg=self.primary_color,
            fg="white"
        ).pack(side=tk.RIGHT, padx=20)
        
        # Logout button
        tk.Button(
            top_bar,
            text="Logout",
            font=("Arial", 10),
            bg=self.accent_color,
            fg="white",
            cursor="hand2",
            command=self.logout
        ).pack(side=tk.RIGHT, padx=10)
        
        # Main container
        main_container = tk.Frame(self.root, bg=self.bg_color)
        main_container.pack(fill=tk.BOTH, expand=True)
        
        # Sidebar
        sidebar = tk.Frame(main_container, bg=self.primary_color, width=200)
        sidebar.pack(side=tk.LEFT, fill=tk.Y)
        sidebar.pack_propagate(False)
        
        # Content area
        self.content_area = tk.Frame(main_container, bg="white")
        self.content_area.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        
        # Sidebar buttons
        if self.user_role == "librarian":
            menu_items = [
                ("Dashboard", self.show_dashboard),
                ("Manage Books", self.show_manage_books),
                ("Manage Users", self.show_manage_users),
                ("Transactions", self.show_transactions),
                ("Reservations", self.show_reservations),
                ("Reports", self.show_reports)
            ]
        else:
            menu_items = [
                ("Search Books", self.show_search_books),
                ("My Checkouts", self.show_my_checkouts),
                ("My Reservations", self.show_my_reservations),
                ("Reserve Book", self.show_reserve_book)
            ]
        
        for text, command in menu_items:
            btn = tk.Button(
                sidebar,
                text=text,
                font=("Arial", 11),
                bg=self.primary_color,
                fg="white",
                bd=0,
                cursor="hand2",
                anchor="w",
                padx=20,
                pady=15,
                command=command
            )
            btn.pack(fill=tk.X)
            
            # Hover effect
            btn.bind("<Enter>", lambda e, b=btn: b.configure(bg=self.secondary_color))
            btn.bind("<Leave>", lambda e, b=btn: b.configure(bg=self.primary_color))
        
        # Show default view
        if self.user_role == "librarian":
            self.show_dashboard()
        else:
            self.show_search_books()
    
    def clear_content_area(self):
        """Clear the content area"""
        for widget in self.content_area.winfo_children():
            widget.destroy()
    
    def show_dashboard(self):
        """Show librarian dashboard"""
        self.clear_content_area()
        
        # Title
        tk.Label(
            self.content_area,
            text="Library Dashboard",
            font=("Arial", 20, "bold"),
            bg="white",
            fg=self.primary_color
        ).pack(pady=20)
        
        if not self.connect_database():
            return
        
        try:
            cursor = self.connection.cursor(dictionary=True)
            
            # Stats frame
            stats_frame = tk.Frame(self.content_area, bg="white")
            stats_frame.pack(pady=20, padx=40, fill=tk.X)
            
            # Get statistics
            stats = [
                ("Total Books", "SELECT COUNT(*) as count FROM Books"),
                ("Available Books", "SELECT SUM(available_copies) as count FROM Books"),
                ("Active Users", "SELECT COUNT(*) as count FROM Users WHERE membership_status='active'"),
                ("Books Checked Out", "SELECT COUNT(*) as count FROM Transactions WHERE return_date IS NULL"),
                ("Overdue Books", "SELECT COUNT(*) as count FROM Transactions WHERE status='overdue'"),
                ("Active Reservations", "SELECT COUNT(*) as count FROM Reservations WHERE status='active'")
            ]
            
            for idx, (label, query) in enumerate(stats):
                cursor.execute(query)
                result = cursor.fetchone()
                count = result['count'] if result['count'] is not None else 0
                
                # Stat card
                card = tk.Frame(stats_frame, bg=self.secondary_color, relief=tk.RAISED, bd=2)
                card.grid(row=idx//3, column=idx%3, padx=10, pady=10, sticky="nsew")
                
                tk.Label(
                    card,
                    text=str(count),
                    font=("Arial", 24, "bold"),
                    bg=self.secondary_color,
                    fg="white"
                ).pack(pady=(15, 5))
                
                tk.Label(
                    card,
                    text=label,
                    font=("Arial", 11),
                    bg=self.secondary_color,
                    fg="white"
                ).pack(pady=(0, 15))
                
                # Make grid responsive
                stats_frame.grid_columnconfigure(idx%3, weight=1)
            
            cursor.close()
            
            # Recent activity
            tk.Label(
                self.content_area,
                text="Recent Overdue Books",
                font=("Arial", 14, "bold"),
                bg="white",
                fg=self.primary_color
            ).pack(pady=(20, 10))
            
            # Treeview for overdue books
            tree_frame = tk.Frame(self.content_area, bg="white")
            tree_frame.pack(pady=10, padx=40, fill=tk.BOTH, expand=True)
            
            # Scrollbars
            vsb = ttk.Scrollbar(tree_frame, orient="vertical")
            hsb = ttk.Scrollbar(tree_frame, orient="horizontal")
            
            tree = ttk.Treeview(
                tree_frame,
                columns=("User", "Book", "Due Date", "Days Overdue"),
                show="headings",
                yscrollcommand=vsb.set,
                xscrollcommand=hsb.set,
                height=8
            )
            
            vsb.config(command=tree.yview)
            hsb.config(command=tree.xview)
            
            # Configure columns
            tree.heading("User", text="User Name")
            tree.heading("Book", text="Book Title")
            tree.heading("Due Date", text="Due Date")
            tree.heading("Days Overdue", text="Days Overdue")
            
            tree.column("User", width=150)
            tree.column("Book", width=250)
            tree.column("Due Date", width=100)
            tree.column("Days Overdue", width=100)
            
            # Get overdue books
            cursor = self.connection.cursor(dictionary=True)
            query = """SELECT u.name, b.title, t.due_date, DATEDIFF(CURDATE(), t.due_date) as days_overdue
                       FROM Transactions t
                       JOIN Users u ON t.user_id = u.user_id
                       JOIN Books b ON t.book_id = b.book_id
                       WHERE t.status = 'overdue'
                       ORDER BY days_overdue DESC
                       LIMIT 10"""
            cursor.execute(query)
            
            for row in cursor.fetchall():
                tree.insert("", tk.END, values=(
                    row['name'],
                    row['title'],
                    row['due_date'],
                    row['days_overdue']
                ))
            
            cursor.close()
            
            # Pack tree and scrollbars
            tree.grid(row=0, column=0, sticky="nsew")
            vsb.grid(row=0, column=1, sticky="ns")
            hsb.grid(row=1, column=0, sticky="ew")
            
            tree_frame.grid_rowconfigure(0, weight=1)
            tree_frame.grid_columnconfigure(0, weight=1)
            
        except Error as e:
            messagebox.showerror("Error", f"Failed to load dashboard: {e}")
    
    def logout(self):
        """Logout and return to login screen"""
        if self.connection and self.connection.is_connected():
            self.connection.close()
        self.connection = None
        self.current_user = None
        self.user_role = None
        self.create_login_screen()
    
    # Placeholder methods for other views
    def show_manage_books(self):
        self.clear_content_area()
        tk.Label(self.content_area, text="Manage Books", font=("Arial", 18, "bold")).pack(pady=20)
        tk.Label(self.content_area, text="This section allows adding, editing, and removing books.").pack()
    
    def show_manage_users(self):
        self.clear_content_area()
        tk.Label(self.content_area, text="Manage Users", font=("Arial", 18, "bold")).pack(pady=20)
        tk.Label(self.content_area, text="This section allows managing user accounts.").pack()
    
    def show_transactions(self):
        self.clear_content_area()
        tk.Label(self.content_area, text="Transactions", font=("Arial", 18, "bold")).pack(pady=20)
        tk.Label(self.content_area, text="This section shows all checkout and return transactions.").pack()
    
    def show_reservations(self):
        self.clear_content_area()
        tk.Label(self.content_area, text="Reservations", font=("Arial", 18, "bold")).pack(pady=20)
        tk.Label(self.content_area, text="This section manages book reservations.").pack()
    
    def show_reports(self):
        self.clear_content_area()
        tk.Label(self.content_area, text="Reports", font=("Arial", 18, "bold")).pack(pady=20)
        tk.Label(self.content_area, text="This section generates various library reports.").pack()
    
    def show_search_books(self):
        self.clear_content_area()
        tk.Label(self.content_area, text="Search Books", font=("Arial", 18, "bold")).pack(pady=20)
        tk.Label(self.content_area, text="This section allows searching the library catalog.").pack()
    
    def show_my_checkouts(self):
        self.clear_content_area()
        tk.Label(self.content_area, text="My Checkouts", font=("Arial", 18, "bold")).pack(pady=20)
        tk.Label(self.content_area, text="View your currently checked out books.").pack()
    
    def show_my_reservations(self):
        self.clear_content_area()
        tk.Label(self.content_area, text="My Reservations", font=("Arial", 18, "bold")).pack(pady=20)
        tk.Label(self.content_area, text="View and manage your book reservations.").pack()
    
    def show_reserve_book(self):
        self.clear_content_area()
        tk.Label(self.content_area, text="Reserve a Book", font=("Arial", 18, "bold")).pack(pady=20)
        tk.Label(self.content_area, text="Reserve books that are currently unavailable.").pack()

if __name__ == "__main__":
    root = tk.Tk()
    app = LibraryManagementApp(root)
    root.mainloop()
