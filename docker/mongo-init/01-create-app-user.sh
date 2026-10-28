#!/bin/bash
set -euo pipefail

# This runs only when the MongoDB data volume is initialized for the first time.
# Compose passwords are URL-safe alphanumeric characters to keep the local URI safe.
if [[ ! "${MONGO_APP_USERNAME:-}" =~ ^[A-Za-z0-9_]{3,40}$ ]]; then
  echo "MONGO_APP_USERNAME must contain 3-40 alphanumeric/underscore characters." >&2
  exit 1
fi
if [[ ! "${MONGO_APP_PASSWORD:-}" =~ ^[A-Za-z0-9]{32,}$ ]]; then
  echo "MONGO_APP_PASSWORD must be at least 32 alphanumeric characters." >&2
  exit 1
fi

mongosh --quiet \
  --username "$MONGO_INITDB_ROOT_USERNAME" \
  --password "$MONGO_INITDB_ROOT_PASSWORD" \
  --authenticationDatabase admin \
  --eval "db.getSiblingDB('peso_jobkonek').createUser({user:'${MONGO_APP_USERNAME}',pwd:'${MONGO_APP_PASSWORD}',roles:[{role:'readWrite',db:'peso_jobkonek'}]})"