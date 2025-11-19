import sqlite3

plant_id = 1
new_stock_quantity = 0

conn = sqlite3.connect('flower_shop.db')
cursor = conn.cursor()

try:
    cursor.execute('''
        UPDATE pot_plants 
        SET stock_quantity = ? 
        WHERE id = ?
    ''', (new_stock_quantity, plant_id))
    
    conn.commit()
    print(f"✅ Количество растения (ID: {plant_id}) успешно изменено на {new_stock_quantity}")

except sqlite3.Error as e:
    print(f"❌ Ошибка при работе с базой данных: {e}")

finally:
    conn.close()