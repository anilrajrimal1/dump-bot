#!/bin/bash

set -euo pipefail

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error_exit() {
  echo "❌ Error: $*" >&2
  exit 1
}

echo "======================"
echo "🧠 DUMP-BOT SCRIPT"
echo "======================"
echo ""

# ------------------- POSTGRESQL SECTION -------------------
echo "PostgreSQL: Do you want to (backup/restore/none)?"
read -r pg_action

if [[ "$pg_action" == "backup" ]]; then
  read -rp "Container name/ID: " pg_container
  read -rp "Postgres user [default: postgres]: " pg_user
  pg_user=${pg_user:-postgres}
  read -rp "Postgres DB name: " pg_db
  read -rp "Dump file name [default: postgres-${pg_db}.sql]: " pg_file
  pg_file=${pg_file:-postgres-${pg_db}.sql}
  read -rp "Dump path (save location): " pg_path

  mkdir -p "$pg_path" || error_exit "Failed to create directory $pg_path"
  log "Starting PostgreSQL backup..."
  if docker exec -i "$pg_container" pg_dump -U "$pg_user" -d "$pg_db" > "${pg_path}/${pg_file}"; then
    log "Badhai xa ! Your Postgres dump saved to: ${pg_path}/${pg_file}"
  else
    error_exit "Failed to perform pg_dump"
  fi

elif [[ "$pg_action" == "restore" ]]; then
  read -rp "Container name/ID: " pg_container
  read -rp "Postgres user [default: postgres]: " pg_user
  pg_user=${pg_user:-postgres}
  read -rp "Postgres DB name: " pg_db
  read -rp "Dump file location (full path): " pg_dump_file

  [[ -f "$pg_dump_file" ]] || error_exit "Dump file not found at $pg_dump_file"

  log "Checking for existing PostgreSQL database..."
  db_exists=$(docker exec -i "$pg_container" psql -U "$pg_user" -tAc "SELECT 1 FROM pg_database WHERE datname='${pg_db}';")

  if [[ "$db_exists" == "1" ]]; then
    log "Database ${pg_db} exists. Terminating connections..."
    docker exec -i "$pg_container" psql -U "$pg_user" -c \
      "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${pg_db}';"

    log "Dropping database \"${pg_db}\"..."
    docker exec -i "$pg_container" psql -U "$pg_user" -c "DROP DATABASE IF EXISTS \"${pg_db}\";" || error_exit "Failed to drop database"
  else
    log "Database ${pg_db} does not exist. Skipping drop."
  fi

  log "Creating database \"${pg_db}\"..."
  docker exec -i "$pg_container" psql -U "$pg_user" -c "CREATE DATABASE \"${pg_db}\";" || error_exit "Failed to create database"

  log "Restoring PostgreSQL dump from $pg_dump_file..."
  if cat "$pg_dump_file" | docker exec -i "$pg_container" psql -U "$pg_user" -d "$pg_db"; then
    log "Badhai xa ! Your PostgreSQL database restored successfully."
  else
    error_exit "Failed to restore PostgreSQL dump"
  fi
fi

# ------------------- MONGODB SECTION -------------------
echo ""
echo "MongoDB: Do you want to (backup/restore/none)?"
read -r mongo_action

if [[ "$mongo_action" == "backup" ]]; then
  read -rp "Container name/ID: " mongo_container
  read -rp "Mongo user: " mongo_user
  read -rp "Mongo password: " mongo_pass
  read -rp "Mongo DB name: " mongo_db
  read -rp "Dump file name [default: mongo-${mongo_db}.gz]: " mongo_file
  mongo_file=${mongo_file:-mongo-${mongo_db}.gz}
  read -rp "Dump path (save location): " mongo_path

  mkdir -p "$mongo_path" || error_exit "Failed to create directory $mongo_path"

  log "Starting MongoDB backup..."
  if docker exec "$mongo_container" mongodump \
    --host mongo --port 27017 \
    --db "$mongo_db" -u "$mongo_user" -p "$mongo_pass" \
    --authenticationDatabase admin \
    --gzip --archive > "${mongo_path}/${mongo_file}"; then
    log "Badhai xa! Your MongoDB dump saved to: ${mongo_path}/${mongo_file}"
  else
    error_exit "Failed to perform mongodump"
  fi

elif [[ "$mongo_action" == "restore" ]]; then
  read -rp "Container name/ID: " mongo_container
  read -rp "Mongo user: " mongo_user
  read -rp "Mongo password: " mongo_pass
  read -rp "Mongo DB name: " mongo_db
  read -rp "Dump file location (full path): " mongo_dump_file

  [[ -f "$mongo_dump_file" ]] || error_exit "Dump file xaina at $mongo_dump_file"

  log "Authenticating to MongoDB and checking DB existence..."
  if docker exec -i "$mongo_container" mongo admin --username "$mongo_user" --password "$mongo_pass" --eval "db.getMongo().getDBNames().includes('$mongo_db')" | grep -q true; then
    log "MongoDB database $mongo_db exists. Dropping it..."
    docker exec -i "$mongo_container" mongo "$mongo_db" --username "$mongo_user" --password "$mongo_pass" --authenticationDatabase admin \
      --eval "db.dropDatabase();" || error_exit "Failed to drop MongoDB database"
  else
    log "MongoDB database $mongo_db does not exist. Skipping drop."
  fi

  log "Copying dump file into container..."
  docker cp "$mongo_dump_file" "$mongo_container:/tmp" || error_exit "Failed to copy dump file into container"

  log "Restoring MongoDB dump..."
  if docker exec -i "$mongo_container" mongorestore --gzip --archive="/tmp/$(basename "$mongo_dump_file")" \
    --db "$mongo_db" --username "$mongo_user" --password "$mongo_pass" --authenticationDatabase admin; then
    log "Badhai xa! Your MongoDB database restored successfully."
  else
    error_exit "Failed to restore MongoDB dump"
  fi
fi

echo ""
log "La sakyo ! Sabai task completed."
