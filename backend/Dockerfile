# Базовый образ с Python
FROM python:3.9-slim

# Установите рабочую директорию
WORKDIR /app

# Скопируйте файл зависимостей
COPY requirements.txt .

# Установите зависимости
RUN pip install --no-cache-dir -r requirements.txt

# Скопируйте всё приложение
COPY . .

# Укажите команду запуска
CMD ["python", "app.py"]
