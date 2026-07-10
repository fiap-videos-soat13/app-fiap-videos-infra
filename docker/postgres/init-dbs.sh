#!/bin/bash
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  SELECT 'CREATE DATABASE fiap_videos_api' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'fiap_videos_api')\gexec
  SELECT 'CREATE DATABASE fiap_videos_processor' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'fiap_videos_processor')\gexec
  SELECT 'CREATE DATABASE fiap_videos_notifier' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'fiap_videos_notifier')\gexec
EOSQL

for db in fiap_videos_api fiap_videos_processor fiap_videos_notifier; do
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
EOSQL
done
