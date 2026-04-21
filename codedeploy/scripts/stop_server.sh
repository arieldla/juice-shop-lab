#!/bin/bash
echo "[stop_server] Stopping juice-shop container if running..."
docker stop juice-shop 2>/dev/null || true
docker rm   juice-shop 2>/dev/null || true
echo "[stop_server] Done"
