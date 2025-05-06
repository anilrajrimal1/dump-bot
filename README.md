# Dump-Bot

**Dump-Bot** is a simple interactive Bash script that helps you backup and restore **PostgreSQL** and **MongoDB** databases running inside Docker containers. It supports both manual dump input and auto-restore functionality, with proper logging and error handling.

> [!IMPORTANT]  
> Go through README properly
> And yes DO TRY 5 TIMES **BEFORE USING IN PRODUCTION**
> Baaki *BHAGAWAN* ko haat ma :laugh

## Features

- Backup and restore PostgreSQL databases.
- Backup and restore MongoDB databases.
- Supports interactive input.
- Handles existing databases gracefully.
- Safe: confirms and logs each step.
- Drop and recreate databases before restore (if needed).
- Easy to run remotely using `curl`.

## How to use ?

### 1. Run via `curl`

```bash
bash <(curl -s https://dump.anilrajrimal.com.np)
```
> Follow the steps as in examples below

## Requirements

- Docker installed and running.
- Bash shell (Linux/macOS).
- Access to the running PostgreSQL or MongoDB containers.
- Proper credentials to access the databases.

> [!WARNING]
> Make sure you use correct db names, 
> And keep in mind, it performs **CLEAN Installation**

## Example Prompts

### PostgreSQL Backup

```
PostgreSQL: Do you want to (backup/restore/none)?
> backup
Container name/ID: demo-project-db-1
Postgres user [default: postgres]: 
Postgres DB name: demo_db
Dump file name [default: postgres-mydb.sql]: 
Dump path (save location): .
```

### MongoDB Restore

```
MongoDB: Do you want to (backup/restore/none)?
> restore
Container name/ID: demo-project-mongo-1
Mongo user: root
Mongo password: root
Mongo DB name: mongo_db
Dump file location (full path): /home/anil/Downloads/mongo_db.gz
```

> [!NOTE]
> Ensure that the container can access the provided paths.
> PostgreSQL connections to the target DB will be terminated before dropping.
> MongoDB restore assumes the archive was created using `mongodump --gzip --archive`.
