#!/bin/bash
echo "[start_server] Pulling latest Juice Shop image..."
docker pull bkimminich/juice-shop:latest

echo "[start_server] Starting juice-shop container..."
docker run -d \
  --name juice-shop \
  --restart unless-stopped \
  -p 80:3000 \
  -e "NODE_ENV=production" \
  bkimminich/juice-shop:latest

echo "[start_server] Container started"
docker ps | grep juice-shop
