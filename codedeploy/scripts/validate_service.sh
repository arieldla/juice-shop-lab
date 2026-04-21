#!/bin/bash
echo "[validate] Checking Juice Shop health..."
sleep 10

for i in {1..5}; do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80)
  if [ "$HTTP_STATUS" == "200" ]; then
    echo "[validate] Health check passed (HTTP 200)"
    exit 0
  fi
  echo "[validate] Attempt $i: got HTTP $HTTP_STATUS, retrying in 5s..."
  sleep 5
done

echo "[validate] FAILED — Juice Shop did not respond with HTTP 200 after 5 attempts"
exit 1
