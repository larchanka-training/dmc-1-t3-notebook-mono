#!/bin/bash
set -e  # Остановить все в случае ошибки

echo "🚀 Запускаю сервисы Docker Compose..."
docker-compose up -d

echo "⏳ Инициализирую контейнеры..."
sleep 15

# Бэкенд (API)
API_CONTAINER=$(docker ps -q -f name=api-1)
echo "🐍 Устанавливаю зависимости и запускаю Бэкенд..."
if docker exec $API_CONTAINER sh -c "pgrep -f 'fastapi dev app/main.py' >/dev/null"; then
	echo "ℹ️ Бэкенд уже запущен внутри контейнера."
else
	docker exec -d $API_CONTAINER bash -c "pip install --no-cache-dir --upgrade -r requirements.txt && fastapi dev app/main.py --host 0.0.0.0"
fi

# Фронтенд
FRONTEND_CONTAINER=$(docker ps -q -f name=frontend-1)
echo "🧠 Устанавливаю зависимости и запускаю Фронтенд..."
if docker exec $FRONTEND_CONTAINER sh -c "pgrep -f 'vite' >/dev/null"; then
	echo "ℹ️ Фронтенд уже запущен внутри контейнера."
else
	docker exec -d $FRONTEND_CONTAINER bash -c "cd /home/app && npm install --include=optional && npm run dev"
fi

echo "✅ Фронтенд и API-Бэкенд запущены!"
