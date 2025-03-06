from flask import Flask
import os
import psycopg2

app = Flask(__name__)

# Получаем строку подключения из переменной окружения
DATABASE_URL = os.environ.get('DATABASE_URL')

@app.route('/')
def hello():
    try:
        # Подключаемся к базе данных
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        cur.execute("SELECT version();")
        db_version = cur.fetchone()
        cur.close()
        conn.close()
        return f"Hello from Flask! PostgreSQL version: {db_version}"
    except Exception as e:
        return f"Error connecting to database: {str(e)}"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
