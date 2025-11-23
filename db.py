# db.py
import sqlite3
from datetime import datetime

DB_NAME = "bot_records.db"

def init_db():
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            prompt TEXT,
            file_url TEXT
        )
    ''')
    # ✅ 清空資料表（選用）
    c.execute("DELETE FROM records")
    # ✅ 重設自動編號
    c.execute("DELETE FROM sqlite_sequence WHERE name='records'")
    
    conn.commit()
    conn.close()


def insert_record(user_id, prompt, file_url):
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    timestamp = datetime.now().isoformat()
    c.execute('''
        INSERT INTO records (user_id, timestamp, prompt, file_url)
        VALUES (?, ?, ?, ?)
    ''', (user_id, timestamp, prompt, file_url))
    conn.commit()
    conn.close()
