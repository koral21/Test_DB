#!/bin/bash

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Функция проверки и установки Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker не установлен. Устанавливаю...${NC}"
        sudo apt update
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt update
        sudo apt install -y docker-ce
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
        echo -e "${GREEN}Docker установлен.${NC}"
    else
        echo -e "${GREEN}Docker уже установлен: $(docker --version)${NC}"
    fi
}

# Функция проверки и установки Docker Compose
install_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Docker Compose не установлен. Устанавливаю...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        echo -e "${GREEN}Docker Compose установлен: $(docker-compose --version)${NC}"
    else
        if [ -f /usr/local/bin/docker-compose ] && [ ! -x /usr/local/bin/docker-compose ]; then
            echo -e "${RED}Docker Compose найден, но не исполняем. Исправляю...${NC}"
            sudo chmod +x /usr/local/bin/docker-compose
        fi
        echo -e "${GREEN}Docker Compose уже установлен: $(docker-compose --version)${NC}"
    fi
}

# Функция ожидания доступности docker-compose
wait_for_docker_compose() {
    local max_attempts=5
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if docker-compose version &> /dev/null; then
            return 0
        else
            echo -e "${RED}Docker Compose занят, жду... (попытка $attempt из $max_attempts)${NC}"
            sleep 2
            ((attempt++))
        fi
    done
    echo -e "${RED}Ошибка: Docker Compose недоступен после $max_attempts попыток.${NC}"
    exit 1
}

# Функция создания структуры Flask-приложения
setup_flask_app() {
    if [ ! -d "flask-app" ]; then
        echo -e "${RED}Директория flask-app не найдена. Создаю...${NC}"
        mkdir -p flask-app
        cd flask-app

        cat <<EOF > Dockerfile
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "app.py"]
EOF

        cat <<EOF > requirements.txt
flask
psycopg2-binary
EOF

        cat <<EOF > app.py
from flask import Flask
import os
import psycopg2

app = Flask(__name__)

DATABASE_URL = os.environ.get('DATABASE_URL')

@app.route('/')
def hello():
    try:
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
EOF
        cd ..
        echo -e "${GREEN}Flask-приложение создано в директории flask-app.${NC}"
    else
        echo -e "${GREEN}Директория flask-app уже существует.${NC}"
    fi
}

# Функция создания docker-compose.yml
setup_docker_compose() {
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}docker-compose.yml не найден. Создаю...${NC}"
        cat <<EOF > docker-compose.yml
services:
  postgres:
    image: postgres:latest
    environment:
      POSTGRES_USER: myuser
      POSTGRES_PASSWORD: mypassword
      POSTGRES_DB: mydatabase
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  flask:
    build: ./flask-app
    ports:
      - "5000:5000"
    environment:
      - DATABASE_URL=postgresql://myuser:mypassword@postgres:5432/mydatabase
    depends_on:
      - postgres
    restart: unless-stopped

volumes:
  postgres_data:
EOF
        echo -e "${GREEN}docker-compose.yml создан.${NC}"
    else
        echo -e "${GREEN}docker-compose.yml уже существует.${NC}"
    fi
}

# Функция удаления контейнеров с конфликтующими именами
remove_conflicting_containers() {
    echo -e "${GREEN}Проверка наличия конфликтующих контейнеров...${NC}"
    for container in "postgres_container" "flask_container"; do
        if docker ps -a --filter "name=$container" --format '{{.ID}}' | grep -q .; then
            echo -e "${RED}Контейнер $container уже существует. Удаляю...${NC}"
            docker rm -f "$container" &> /dev/null
        fi
    done
}

# Основная логика управления
case "$1" in
    start)
        echo -e "${GREEN}Проверка и установка зависимостей...${NC}"
        install_docker
        install_docker_compose
        wait_for_docker_compose
        setup_flask_app
        setup_docker_compose
        remove_conflicting_containers

        echo -e "${GREEN}Запускаю контейнеры...${NC}"
        docker-compose up -d --build
        sleep 2
        echo -e "${GREEN}Контейнеры запущены. Проверка статуса:${NC}"
        docker-compose ps
        ;;
    stop)
        echo -e "${GREEN}Останавливаю контейнеры...${NC}"
        wait_for_docker_compose
        docker-compose down
        echo -e "${GREEN}Контейнеры остановлены.${NC}"
        ;;
    *)
        echo "Использование: $0 {start|stop}"
        echo "  start - Установить всё необходимое и запустить контейнеры"
        echo "  stop  - Остановить и удалить контейнеры"
        exit 1
        ;;
esac

exit 0
