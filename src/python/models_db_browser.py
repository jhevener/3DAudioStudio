import sys
import os
import sqlite3
import logging
import csv
from datetime import datetime
import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)  # Suppress SIP deprecation warning
from PyQt5.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QComboBox,
                             QLineEdit, QPushButton, QTableWidget, QTableWidgetItem, QAbstractItemView,
                             QStatusBar, QLabel, QTextEdit, QMenu, QAction, QFileDialog)
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QColor

# Paths for database and INI file
DB_PATH = "C:/temp/s2S/models.db" if sys.platform == "win32" else "/tmp/s2S/models.db"
INI_PATH = "C:/temp/s2S/models.ini" if sys.platform == "win32" else "/tmp/s2S/models.ini"
LOG_DIR = "logs"

# Configure logging
if not os.path.exists(LOG_DIR):
    os.makedirs(LOG_DIR)
LOG_FILE = os.path.join(LOG_DIR, f"ModelBrowser_{datetime.now().strftime('%Y%m%d')}.log")
logging.basicConfig(filename=LOG_FILE, level=logging.INFO, format='[%(asctime)s] %(levelname)s: %(message)s')

class ModelDatabaseBrowser(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Model Database Browser")
        self.setGeometry(100, 100, 1200, 800)
        self.dark_theme = True
        self.current_index = -1
        self.editing = False
        self.list_view_data = []
        self.db_conn = None
        self.db_cursor = None
        self._loading = False  # Recursion guard
        self.init_db()
        self.init_ui()
        self.load_table_data("Models")
        self.update_filter_combos()
        logging.info("Initial data load completed")

    def init_db(self):
        logging.info("Starting Model Database Browser")
        logging.info("Starting database creation")
        if os.path.exists(DB_PATH):
            os.remove(DB_PATH)
        self.db_conn = sqlite3.connect(DB_PATH)
        self.db_cursor = self.db_conn.cursor()
        logging.info(f"Database opened: {DB_PATH}")

        # Create tables
        self.db_cursor.execute("""
            CREATE TABLE Models (
                ModelID INTEGER PRIMARY KEY,
                Name TEXT,
                Path TEXT,
                Description TEXT,
                Comments TEXT,
                CommandLine TEXT
            )
        """)
        logging.info("Models table created")
        self.db_cursor.execute("""
            CREATE TABLE ModelApps (
                ModelID INTEGER,
                App TEXT,
                FOREIGN KEY(ModelID) REFERENCES Models(ModelID)
            )
        """)
        logging.info("ModelApps table created")
        self.db_cursor.execute("""
            CREATE TABLE ModelFocuses (
                ModelID INTEGER,
                Focus TEXT,
                Stems INTEGER,
                FOREIGN KEY(ModelID) REFERENCES Models(ModelID)
            )
        """)
        logging.info("ModelFocuses table created")

        # Populate database from INI file
        if os.path.exists(INI_PATH):
            with open(INI_PATH, 'r') as f:
                lines = f.readlines()
                model_id = 0
                current_section = None
                data = {}
                for line in lines:
                    line = line.strip()
                    if line.startswith('[') and line.endswith(']'):
                        if current_section and data:
                            self.insert_model(model_id, data)
                            model_id += 1
                        current_section = line[1:-1]
                        data = {}
                    elif '=' in line:
                        key, value = line.split('=', 1)
                        data[key.strip()] = value.strip()
                if current_section and data:
                    self.insert_model(model_id, data)
        else:
            logging.error(f"INI file not found: {INI_PATH}")

        self.db_conn.commit()
        logging.info("Database creation completed")

        # Create indices
        logging.info("Initializing database indices")
        self.db_cursor.execute("CREATE INDEX IF NOT EXISTS idx_models_modelid ON Models(ModelID);")
        self.db_cursor.execute("CREATE INDEX IF NOT EXISTS idx_modelapps_modelid ON ModelApps(ModelID);")
        self.db_cursor.execute("CREATE INDEX IF NOT EXISTS idx_modelfocuses_modelid ON ModelFocuses(ModelID);")
        logging.info("Database indices created")

    def insert_model(self, model_id, data):
        self.db_cursor.execute("""
            INSERT INTO Models (ModelID, Name, Path, Description, Comments, CommandLine)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (model_id, data.get("Name", "Unknown"), data.get("Path", ""),
              data.get("Description", ""), data.get("Comments", ""), data.get("CommandLine", "")))
        if "App" in data and data["App"]:
            self.db_cursor.execute("INSERT INTO ModelApps (ModelID, App) VALUES (?, ?)", (model_id, data["App"]))
        if "Focus" in data or ("Stems" in data and int(data.get("Stems", 0)) > 0):
            self.db_cursor.execute("INSERT INTO ModelFocuses (ModelID, Focus, Stems) VALUES (?, ?, ?)",
                                   (model_id, data.get("Focus", ""), int(data.get("Stems", 0))))

    def init_ui(self):
        logging.info("Creating GUI")
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)

        # Toolbar
        toolbar_layout = QHBoxLayout()
        self.table_combo = QComboBox()
        self.table_combo.addItems(["Models", "ModelApps", "ModelFocuses"])
        self.table_combo.currentTextChanged.connect(self.on_table_changed)
        toolbar_layout.addWidget(self.table_combo)

        search_label = QLabel("Search:")
        toolbar_layout.addWidget(search_label)
        self.search_input = QLineEdit()
        self.search_input.textChanged.connect(self.on_search_changed)
        toolbar_layout.addWidget(self.search_input)

        app_filter_label = QLabel("App Filter:")
        toolbar_layout.addWidget(app_filter_label)
        self.filter_app_combo = QComboBox()
        self.filter_app_combo.currentTextChanged.connect(self.on_filter_changed)
        toolbar_layout.addWidget(self.filter_app_combo)

        stems_filter_label = QLabel("Stems Filter:")
        toolbar_layout.addWidget(stems_filter_label)
        self.filter_stems_combo = QComboBox()
        self.filter_stems_combo.currentTextChanged.connect(self.on_filter_changed)
        toolbar_layout.addWidget(self.filter_stems_combo)

        refresh_button = QPushButton("Refresh")
        refresh_button.clicked.connect(self.on_refresh)
        toolbar_layout.addWidget(refresh_button)

        export_button = QPushButton("Export CSV")
        export_button.clicked.connect(self.export_table_to_csv)
        toolbar_layout.addWidget(export_button)

        theme_button = QPushButton("Toggle Theme")
        theme_button.clicked.connect(self.toggle_theme)
        toolbar_layout.addWidget(theme_button)

        main_layout.addLayout(toolbar_layout)

        # ListView (TableWidget)
        self.list_view = QTableWidget()
        self.list_view.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.list_view.setSelectionMode(QAbstractItemView.SingleSelection)
        self.list_view.itemSelectionChanged.connect(self.on_list_view_selection_changed)
        main_layout.addWidget(self.list_view)

        # Navigation buttons
        nav_layout = QHBoxLayout()
        self.first_button = QPushButton("First")
        self.first_button.clicked.connect(self.on_first)
        nav_layout.addWidget(self.first_button)

        self.prev_button = QPushButton("Previous")
        self.prev_button.clicked.connect(self.on_prev)
        nav_layout.addWidget(self.prev_button)

        self.next_button = QPushButton("Next")
        self.next_button.clicked.connect(self.on_next)
        nav_layout.addWidget(self.next_button)

        self.last_button = QPushButton("Last")
        self.last_button.clicked.connect(self.on_last)
        nav_layout.addWidget(self.last_button)

        self.edit_button = QPushButton("Edit")
        self.edit_button.clicked.connect(self.on_edit)
        nav_layout.addWidget(self.edit_button)

        self.save_button = QPushButton("Save")
        self.save_button.clicked.connect(self.on_save)
        self.save_button.setEnabled(False)
        nav_layout.addWidget(self.save_button)

        self.cancel_button = QPushButton("Cancel")
        self.cancel_button.clicked.connect(self.on_cancel)
        self.cancel_button.setEnabled(False)
        nav_layout.addWidget(self.cancel_button)

        main_layout.addLayout(nav_layout)

        # Detail fields
        fields_layout = QVBoxLayout()
        self.model_id_input = QLineEdit()
        self.model_id_input.setReadOnly(True)
        fields_layout.addWidget(QLabel("ModelID:"))
        fields_layout.addWidget(self.model_id_input)

        self.name_input = QTextEdit()
        self.name_input.setReadOnly(True)
        fields_layout.addWidget(QLabel("Name:"))
        fields_layout.addWidget(self.name_input)

        self.app_input = QLineEdit()
        self.app_input.setReadOnly(True)
        fields_layout.addWidget(QLabel("App:"))
        fields_layout.addWidget(self.app_input)

        self.path_input = QTextEdit()
        self.path_input.setReadOnly(True)
        fields_layout.addWidget(QLabel("Path:"))
        fields_layout.addWidget(self.path_input)

        self.desc_input = QTextEdit()
        self.desc_input.setReadOnly(True)
        fields_layout.addWidget(QLabel("Description:"))
        fields_layout.addWidget(self.desc_input)

        self.comments_input = QTextEdit()
        self.comments_input.setReadOnly(True)
        fields_layout.addWidget(QLabel("Comments:"))
        fields_layout.addWidget(self.comments_input)

        self.cmd_input = QTextEdit()
        self.cmd_input.setReadOnly(True)
        fields_layout.addWidget(QLabel("CommandLine:"))
        fields_layout.addWidget(self.cmd_input)

        self.focus_input = QTextEdit()
        self.focus_input.setReadOnly(True)
        fields_layout.addWidget(QLabel("Focus:"))
        fields_layout.addWidget(self.focus_input)

        self.stems_input = QLineEdit()
        self.stems_input.setReadOnly(True)
        fields_layout.addWidget(QLabel("Stems:"))
        fields_layout.addWidget(self.stems_input)

        main_layout.addLayout(fields_layout)

        # Status bar
        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)
        self.status_bar.showMessage("Ready")

        # Context menu
        self.list_view.setContextMenuPolicy(Qt.CustomContextMenu)
        self.list_view.customContextMenuRequested.connect(self.show_context_menu)

        self.apply_theme()
        logging.info("GUI displayed")

    def apply_theme(self):
        bg_color = QColor(45, 45, 45) if self.dark_theme else QColor(255, 255, 255)
        text_color = QColor(255, 255, 255) if self.dark_theme else QColor(0, 0, 0)
        input_bg = QColor(60, 60, 60) if self.dark_theme else QColor(240, 240, 240)
        button_color = QColor(76, 175, 80) if self.dark_theme else QColor(52, 199, 89)

        self.setStyleSheet(f"background-color: {bg_color.name()}; color: {text_color.name()};")
        for widget in [self.search_input, self.model_id_input, self.app_input, self.stems_input,
                       self.name_input, self.path_input, self.desc_input, self.comments_input,
                       self.cmd_input, self.focus_input]:
            widget.setStyleSheet(f"background-color: {input_bg.name()}; color: {text_color.name()};")
        for button in [self.first_button, self.prev_button, self.next_button, self.last_button,
                       self.edit_button, self.save_button, self.cancel_button]:
            button.setStyleSheet(f"background-color: {button_color.name()}; color: white;")
        self.list_view.setStyleSheet(f"background-color: {input_bg.name()}; color: {text_color.name()};")
        logging.info(f"Theme applied: {'Dark' if self.dark_theme else 'Light'}")

    def toggle_theme(self):
        self.dark_theme = not self.dark_theme
        self.apply_theme()

    def load_table_data(self, table, search="", app_filter="", stems_filter=-1):
        logging.info(f"Loading data for table: {table}")
        self.list_view.clear()
        self.current_index = -1
        self.list_view_data = []

        if table == "Models":
            query = """
                SELECT m.ModelID, m.Name, m.Path, m.Description, m.Comments, m.CommandLine, ma.App
                FROM Models m LEFT JOIN ModelApps ma ON m.ModelID = ma.ModelID
            """
            headers = ["ModelID", "Name", "Path", "Description", "Comments", "CommandLine", "App"]
            widths = [80, 150, 250, 300, 300, 400, 100]
        elif table == "ModelApps":
            query = "SELECT ModelID, App FROM ModelApps"
            headers = ["ModelID", "App"]
            widths = [80, 200]
        else:
            query = "SELECT ModelID, Focus, Stems FROM ModelFocuses"
            headers = ["ModelID", "Focus", "Stems"]
            widths = [80, 300, 80]

        where_clauses = []
        if search:
            if table == "Models":
                fields = ["m.ModelID", "m.Name", "m.Path", "m.Description", "m.Comments", "m.CommandLine", "ma.App"]
            elif table == "ModelApps":
                fields = ["ModelID", "App"]
            else:
                fields = ["ModelID", "Focus", "Stems"]
            conditions = [f"{field} LIKE '%{search}%'" for field in fields]
            where_clauses.append(f"({' OR '.join(conditions)})")
        if app_filter and table in ["Models", "ModelApps"]:
            where_clauses.append(f"App = '{app_filter}'")
        if stems_filter >= 0 and table == "ModelFocuses":
            where_clauses.append(f"Stems = {stems_filter}")
        if where_clauses:
            query += " WHERE " + " AND ".join(where_clauses)
        if table == "Models":
            query += " ORDER BY m.ModelID"
        else:
            query += " ORDER BY ModelID"

        self.db_cursor.execute(query)
        rows = self.db_cursor.fetchall()

        self.list_view.setColumnCount(len(headers))
        self.list_view.setHorizontalHeaderLabels(headers)
        self.list_view.setRowCount(len(rows))
        for col, width in enumerate(widths):
            self.list_view.setColumnWidth(col, width)

        for row_idx, row in enumerate(rows):
            for col_idx, value in enumerate(row):
                item = QTableWidgetItem(str(value) if value is not None else "N/A")
                item.setFlags(item.flags() ^ Qt.ItemIsEditable)
                self.list_view.setItem(row_idx, col_idx, item)
            self.list_view_data.append(row)

        self.status_bar.showMessage(f"Loaded {len(rows)} records")
        logging.info(f"Loaded {len(rows)} rows into ListView for table {table}")

    def update_filter_combos(self):
        logging.info("Updating filter combos")
        # Block signals to prevent on_filter_changed from being triggered during updates
        self.filter_app_combo.blockSignals(True)
        self.filter_stems_combo.blockSignals(True)

        self.filter_app_combo.clear()
        self.filter_stems_combo.clear()

        self.db_cursor.execute("SELECT DISTINCT App FROM ModelApps WHERE App IS NOT NULL ORDER BY App")
        apps = [row[0] for row in self.db_cursor.fetchall()]
        self.filter_app_combo.addItem("All")
        self.filter_app_combo.addItems(apps)
        logging.info(f"Updated App filter with {len(apps)} entries")

        self.db_cursor.execute("SELECT DISTINCT Stems FROM ModelFocuses WHERE Stems IS NOT NULL ORDER BY Stems")
        stems = [str(row[0]) for row in self.db_cursor.fetchall()]
        self.filter_stems_combo.addItem("All")
        self.filter_stems_combo.addItems(stems)
        logging.info(f"Updated Stems filter with {len(stems)} entries")

        # Re-enable signals after updates
        self.filter_app_combo.blockSignals(False)
        self.filter_stems_combo.blockSignals(False)

        logging.info("Filter combos update completed")

    def populate_fields(self, index):
        if index < 0 or index >= len(self.list_view_data):
            return
        logging.info(f"Populating fields for index: {index}")
        table = self.table_combo.currentText()
        self.current_index = index
        row = self.list_view_data[index]

        if table == "Models":
            self.model_id_input.setText(str(row[0]))
            self.name_input.setText(row[1])
            self.path_input.setText(row[2])
            self.desc_input.setText(row[3])
            self.comments_input.setText(row[4])
            self.cmd_input.setText(row[5])
            self.app_input.setText(row[6] if row[6] else "")
            self.db_cursor.execute("SELECT Focus, Stems FROM ModelFocuses WHERE ModelID = ?", (row[0],))
            focus_row = self.db_cursor.fetchone()
            if focus_row:
                self.focus_input.setText(focus_row[0])
                self.stems_input.setText(str(focus_row[1]))
            else:
                self.focus_input.setText("")
                self.stems_input.setText("")
        elif table == "ModelApps":
            self.model_id_input.setText(str(row[0]))
            self.app_input.setText(row[1])
            self.name_input.setText("")
            self.path_input.setText("")
            self.desc_input.setText("")
            self.comments_input.setText("")
            self.cmd_input.setText("")
            self.focus_input.setText("")
            self.stems_input.setText("")
        else:
            self.model_id_input.setText(str(row[0]))
            self.focus_input.setText(row[1])
            self.stems_input.setText(str(row[2]))
            self.name_input.setText("")
            self.path_input.setText("")
            self.desc_input.setText("")
            self.comments_input.setText("")
            self.cmd_input.setText("")
            self.app_input.setText("")

        logging.info(f"Populated fields for ModelID: {row[0]} in table: {table}")

    def toggle_edit_mode(self, enable):
        self.editing = enable
        table = self.table_combo.currentText()
        if table == "Models":
            self.name_input.setReadOnly(not enable)
            self.path_input.setReadOnly(not enable)
            self.desc_input.setReadOnly(not enable)
            self.comments_input.setReadOnly(not enable)
            self.cmd_input.setReadOnly(not enable)
            self.app_input.setReadOnly(not enable)
            self.focus_input.setReadOnly(not enable)
            self.stems_input.setReadOnly(not enable)
        elif table == "ModelApps":
            self.app_input.setReadOnly(not enable)
        elif table == "ModelFocuses":
            self.focus_input.setReadOnly(not enable)
            self.stems_input.setReadOnly(not enable)

        self.edit_button.setEnabled(not enable)
        self.save_button.setEnabled(enable)
        self.cancel_button.setEnabled(enable)
        self.first_button.setEnabled(not enable)
        self.prev_button.setEnabled(not enable)
        self.next_button.setEnabled(not enable)
        self.last_button.setEnabled(not enable)
        self.status_bar.showMessage("Editing record..." if enable else "Ready")

    def save_changes(self):
        if self.current_index < 0:
            return
        table = self.table_combo.currentText()
        model_id = self.list_view_data[self.current_index][0]
        if table == "Models":
            name = self.name_input.toPlainText()
            path = self.path_input.toPlainText()
            desc = self.desc_input.toPlainText()
            comments = self.comments_input.toPlainText()
            cmd = self.cmd_input.toPlainText()
            app = self.app_input.text()
            focus = self.focus_input.toPlainText()
            stems = int(self.stems_input.text() or 0)
            self.db_cursor.execute("""
                UPDATE Models SET Name = ?, Path = ?, Description = ?, Comments = ?, CommandLine = ?
                WHERE ModelID = ?
            """, (name, path, desc, comments, cmd, model_id))
            if app:
                self.db_cursor.execute("INSERT OR REPLACE INTO ModelApps (ModelID, App) VALUES (?, ?)", (model_id, app))
            else:
                self.db_cursor.execute("DELETE FROM ModelApps WHERE ModelID = ?", (model_id,))
            if focus or stems > 0:
                self.db_cursor.execute("INSERT OR REPLACE INTO ModelFocuses (ModelID, Focus, Stems) VALUES (?, ?, ?)",
                                       (model_id, focus, stems))
            else:
                self.db_cursor.execute("DELETE FROM ModelFocuses WHERE ModelID = ?", (model_id,))
        elif table == "ModelApps":
            app = self.app_input.text()
            if app:
                self.db_cursor.execute("INSERT OR REPLACE INTO ModelApps (ModelID, App) VALUES (?, ?)", (model_id, app))
            else:
                self.db_cursor.execute("DELETE FROM ModelApps WHERE ModelID = ?", (model_id,))
        else:
            focus = self.focus_input.toPlainText()
            stems = int(self.stems_input.text() or 0)
            if focus or stems > 0:
                self.db_cursor.execute("INSERT OR REPLACE INTO ModelFocuses (ModelID, Focus, Stems) VALUES (?, ?, ?)",
                                       (model_id, focus, stems))
            else:
                self.db_cursor.execute("DELETE FROM ModelFocuses WHERE ModelID = ?", (model_id,))

        self.db_conn.commit()
        self.toggle_edit_mode(False)
        self.load_table_data(table, self.search_input.text(),
                             "" if self.filter_app_combo.currentText() == "All" else self.filter_app_combo.currentText(),
                             -1 if self.filter_stems_combo.currentText() == "All" else int(self.filter_stems_combo.currentText()))
        self.update_filter_combos()
        self.populate_fields(self.current_index)

    def export_table_to_csv(self):
        table = self.table_combo.currentText()
        file_path, _ = QFileDialog.getSaveFileName(self, "Export to CSV", f"{table}_export.csv", "CSV Files (*.csv)")
        if not file_path:
            return

        if table == "Models":
            query = """
                SELECT m.ModelID, m.Name, m.Path, m.Description, m.Comments, m.CommandLine, ma.App
                FROM Models m LEFT JOIN ModelApps ma ON m.ModelID = ma.ModelID ORDER BY m.ModelID
            """
            headers = ["ModelID", "Name", "Path", "Description", "Comments", "CommandLine", "App"]
        elif table == "ModelApps":
            query = "SELECT ModelID, App FROM ModelApps ORDER BY ModelID"
            headers = ["ModelID", "App"]
        else:
            query = "SELECT ModelID, Focus, Stems FROM ModelFocuses ORDER BY ModelID"
            headers = ["ModelID", "Focus", "Stems"]

        self.db_cursor.execute(query)
        rows = self.db_cursor.fetchall()

        with open(file_path, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(headers)
            for row in rows:
                writer.writerow([str(val) if val is not None else "N/A" for val in row])

        self.status_bar.showMessage(f"Exported to {file_path}")

    def show_context_menu(self, pos):
        menu = QMenu()
        copy_action = QAction("Copy Row", self)
        copy_action.triggered.connect(self.copy_row)
        menu.addAction(copy_action)

        export_action = QAction("Export Table to CSV", self)
        export_action.triggered.connect(self.export_table_to_csv)
        menu.addAction(export_action)

        open_path_action = QAction("Open Path in Explorer", self)
        open_path_action.triggered.connect(self.open_path)
        menu.addAction(open_path_action)

        menu.exec_(self.list_view.mapToGlobal(pos))

    def copy_row(self):
        if self.current_index < 0:
            return
        row = self.list_view_data[self.current_index]
        clipboard = QApplication.clipboard()
        clipboard.setText("\t".join([str(val) if val is not None else "N/A" for val in row]))
        self.status_bar.showMessage("Row copied to clipboard")

    def open_path(self):
        if self.current_index < 0 or self.table_combo.currentText() != "Models":
            return
        path = self.list_view_data[self.current_index][2]
        if os.path.exists(path):
            if sys.platform == "win32":
                os.startfile(path)
            else:
                os.system(f"xdg-open {path}")
        else:
            self.status_bar.showMessage(f"Path not found: {path}")

    def on_table_changed(self):
        self.load_table_data(self.table_combo.currentText())
        self.update_filter_combos()

    def on_search_changed(self):
        if self._loading:
            return
        self._loading = True
        try:
            logging.info("Search input changed")
            table = self.table_combo.currentText()
            stems_text = self.filter_stems_combo.currentText()
            if stems_text == "All":
                stems_filter = -1
            else:
                try:
                    stems_filter = int(stems_text) if stems_text else -1
                except ValueError:
                    stems_filter = -1
            self.load_table_data(table, self.search_input.text(),
                                 "" if self.filter_app_combo.currentText() == "All" else self.filter_app_combo.currentText(),
                                 stems_filter)
            self.update_filter_combos()
        finally:
            self._loading = False

    def on_filter_changed(self):
        if self._loading:
            return
        self._loading = True
        try:
            logging.info("Filter changed")
            table = self.table_combo.currentText()
            stems_text = self.filter_stems_combo.currentText()
            if stems_text == "All":
                stems_filter = -1
            else:
                try:
                    stems_filter = int(stems_text) if stems_text else -1
                except ValueError:
                    stems_filter = -1
            self.load_table_data(table, self.search_input.text(),
                                 "" if self.filter_app_combo.currentText() == "All" else self.filter_app_combo.currentText(),
                                 stems_filter)
            self.update_filter_combos()
        finally:
            self._loading = False

    def on_refresh(self):
        if self._loading:
            return
        self._loading = True
        try:
            table = self.table_combo.currentText()
            stems_text = self.filter_stems_combo.currentText()
            if stems_text == "All":
                stems_filter = -1
            else:
                try:
                    stems_filter = int(stems_text) if stems_text else -1
                except ValueError:
                    stems_filter = -1
            self.load_table_data(table, self.search_input.text(),
                                 "" if self.filter_app_combo.currentText() == "All" else self.filter_app_combo.currentText(),
                                 stems_filter)
            self.update_filter_combos()
        finally:
            self._loading = False

    def on_first(self):
        if self.list_view_data:
            self.list_view.selectRow(0)
            self.populate_fields(0)

    def on_prev(self):
        if self.current_index > 0:
            self.list_view.selectRow(self.current_index - 1)
            self.populate_fields(self.current_index - 1)

    def on_next(self):
        if self.current_index < len(self.list_view_data) - 1:
            self.list_view.selectRow(self.current_index + 1)
            self.populate_fields(self.current_index + 1)

    def on_last(self):
        if self.list_view_data:
            self.list_view.selectRow(len(self.list_view_data) - 1)
            self.populate_fields(len(self.list_view_data) - 1)

    def on_edit(self):
        if self.current_index >= 0:
            self.toggle_edit_mode(True)

    def on_save(self):
        self.save_changes()

    def on_cancel(self):
        self.toggle_edit_mode(False)
        self.populate_fields(self.current_index)

    def on_list_view_selection_changed(self):
        selected_rows = self.list_view.selectionModel().selectedRows()
        if selected_rows:
            index = selected_rows[0].row()
            logging.info(f"ListView item selected: {index}")
            self.populate_fields(index)

    def closeEvent(self, event):
        logging.info("Shutting down")
        self.db_conn.close()
        event.accept()

if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = ModelDatabaseBrowser()
    window.show()
    sys.exit(app.exec_())