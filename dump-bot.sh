#!/bin/bash

# Set erase character for terminals
if [ -t 0 ]; then
  stty erase ^H
fi

set -euo pipefail

# Trap Ctrl+C
trap 'error_exit "Script interrupted."' INT

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error_exit() {
  echo "❌ Error: $*" >&2
  exit 1
}

start_time=$(date +%s)

echo "======================"
echo "DUMP-BOT SCRIPT"
echo "MAGIC STARTED !!"
echo "======================"
echo ""

# ------------------- POSTGRESQL SECTION -------------------
while true; do
  echo "PostgreSQL: Do you want to (backup/restore/none)?"
  read -er pg_action
  pg_action=$(echo "$pg_action" | tr '[:upper:]' '[:lower:]')

  case "$pg_action" in
    backup|restore|none)
      break
      ;;
    *)
      echo "INVALID INPUT !!: '$pg_action'. Must be 'backup', 'restore', or 'none'. Please try again."
      ;;
  esac
done

if [[ "$pg_action" == "backup" ]]; then
  read -erp "Container name/ID: " pg_container
  read -erp "Postgres user [default: postgres]: " pg_user
  pg_user=${pg_user:-postgres}
  read -erp "Postgres DB name: " pg_db
  read -erp "Dump file name [default: postgres-${pg_db}.sql]: " pg_file
  pg_file=${pg_file:-postgres-${pg_db}.sql}
  read -erp "Dump path (save location): " pg_path

  mkdir -p "$pg_path" || error_exit "Failed to create directory $pg_path"
  log "Starting PostgreSQL backup..."
  if docker exec -i "$pg_container" pg_dump -U "$pg_user" -d "$pg_db" > "${pg_path}/${pg_file}"; then
    log "Completed ! Your Postgres dump saved to: ${pg_path}/${pg_file}"
  else
    error_exit "Failed to perform pg_dump"
  fi

elif [[ "$pg_action" == "restore" ]]; then
  read -erp "Container name/ID: " pg_container
  read -erp "Postgres user [default: postgres]: " pg_user
  pg_user=${pg_user:-postgres}
  read -erp "Postgres DB name: " pg_db
  read -erp "Dump file (full_path/name.sql): " pg_dump_file

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
    log "Completed! Your PostgreSQL database restored successfully."
  else
    error_exit "Failed to restore PostgreSQL dump"
  fi
fi

# ------------------- MONGODB SECTION -------------------
while true; do
  echo "MongoDB: Do you want to (backup/restore/none)?"
  read -er mongo_action
  mongo_action=$(echo "$mongo_action" | tr '[:upper:]' '[:lower:]')

  case "$mongo_action" in
    backup|restore|none)
      break
      ;;
    *)
      echo "INVALID INPUT !!: '$mongo_action'. Must be 'backup', 'restore', or 'none'. Please try again."
      ;;
  esac
done

if [[ "$mongo_action" == "backup" ]]; then
  read -erp "Container name/ID: " mongo_container
  read -erp "Mongo user: " mongo_user
  read -erp "Mongo password: " mongo_pass
  read -erp "Mongo DB name: " mongo_db
  read -erp "Dump file name [default: mongo-${mongo_db}.gz]: " mongo_file
  mongo_file=${mongo_file:-mongo-${mongo_db}.gz}
  read -erp "Dump path (save location): " mongo_path

  mkdir -p "$mongo_path" || error_exit "Failed to create directory $mongo_path"

  log "Starting MongoDB backup..."
  if docker exec "$mongo_container" mongodump \
    --host mongo --port 27017 \
    --db "$mongo_db" -u "$mongo_user" -p "$mongo_pass" \
    --authenticationDatabase admin \
    --gzip --archive > "${mongo_path}/${mongo_file}"; then
    log "Completed! Your MongoDB dump saved to: ${mongo_path}/${mongo_file}"
  else
    error_exit "Failed to perform mongodump"
  fi

elif [[ "$mongo_action" == "restore" ]]; then
  read -erp "Container name/ID: " mongo_container
  read -erp "Mongo user: " mongo_user
  read -erp "Mongo password: " mongo_pass
  read -erp "Mongo DB name: " mongo_db
  read -erp "Dump file Name (full_path/file.gz): " mongo_dump_file

  [[ -f "$mongo_dump_file" ]] || error_exit "Dump file xaina at $mongo_dump_file"

  log "Authenticating to MongoDB and checking DB existence..."
  if docker exec -i "$mongo_container" mongo admin --username "$mongo_user" --password "$mongo_pass" --eval "db.getMongo().getDBNames().indexOf('$mongo_db') >= 0" | grep -q true; then
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
    log "Completed! Your MongoDB database restored successfully."
    docker exec -i "$mongo_container" rm "/tmp/$(basename "$mongo_dump_file")" || log "⚠️ Cleanup failed, temp file left in container"
  else
    error_exit "Failed to restore MongoDB dump"
  fi
fi

echo ""
end_time=$(date +%s)
elapsed=$((end_time - start_time))
log "Done! Sabai task completed in ${elapsed}s."
