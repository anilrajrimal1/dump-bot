#!/bin/bash

echo "Do you want to take a PostgreSQL dump? (yes/no)"
read postgres_choice

if [[ "$postgres_choice" == "yes" ]]; then
  read -p "Container name/ID: " pg_container
  read -p "Postgres user [default: postgres]: " pg_user
  pg_user=${pg_user:-postgres}
  read -p "Postgres DB name: " pg_db
  read -p "Dump file name [default: postgres-${pg_db}.sql]: " pg_file
  pg_file=${pg_file:-postgres-${pg_db}.sql}
  read -p "Dump path (save location): " pg_path

  mkdir -p "$pg_path"
  docker exec -i "$pg_container" pg_dump -U "$pg_user" -d "$pg_db" > "${pg_path}/${pg_file}"
  echo "Postgres dump saved to: ${pg_path}/${pg_file}"
fi

echo "Do you want to take a MongoDB dump? (yes/no)"
read mongo_choice

if [[ "$mongo_choice" == "yes" ]]; then
  read -p "Container name/ID: " mongo_container
  read -p "Mongo user: " mongo_user
  read -p "Mongo password: " mongo_pass
  read -p "Mongo DB name: " mongo_db
  read -p "Dump file name [default: mongo-${mongo_db}.gz]: " mongo_file
  mongo_file=${mongo_file:-mongo-${mongo_db}.gz}
  read -p "Dump path (save location): " mongo_path

  mkdir -p "$mongo_path"
  docker exec "$mongo_container" mongodump \
    --host mongo --port 27017 \
    --db "$mongo_db" -u "$mongo_user" -p "$mongo_pass" \
    --authenticationDatabase admin \
    --gzip --archive > "${mongo_path}/${mongo_file}"
  echo "Mongo dump saved to: ${mongo_path}/${mongo_file}"
fi
