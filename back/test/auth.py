import sqlite3
from datetime import datetime, timedelta

telegram_id = 5287879603
device_id = "1112EC7E-E1C4-4320-A0B3-C740F0E7427C"
code = "0000"
expires_in_hours = 24


conn = sqlite3.connect('flower_shop.db')
cursor = conn.cursor()

try:
    expires_at = datetime.now() + timedelta(hours=expires_in_hours)
    
    cursor.execute('''
        INSERT INTO oauth_codes (
            telegram_id,
            device_id,
            code,
            expires_at
        ) VALUES (?, ?, ?, ?)
    ''', (telegram_id, device_id, code, expires_at))
    
    conn.commit()
    print("Запись успешно добавлена в базу данных.")

except sqlite3.IntegrityError as e:
    if "UNIQUE constraint failed" in str(e):
        print("Ошибка: код уже существует в базе данных.")
    else:
        print(f"Ошибка целостности данных: {e}")

except sqlite3.Error as e:
    print(f"Ошибка при работе с базой данных: {e}")


finally:
    conn.close()
