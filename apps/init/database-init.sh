#! /bin/sh

# Ensure environment variables are loaded before running this script
# (e.g., using `dotenv -e .env -- bash ./your_script.sh`)

# Check if required variables are set
if [ -z "$POSTGRES_PASSWORD" ] || [ -z "$CUSTOM_PASSWORD" ] || [ -z "$POSTGRES_USER" ] || [ -z "$SERVER" ] || [ -z "$CUSTOM_USER" ] || [ -z "$CUSTOM_DATABASE" ]|| [ -z "$CUSTOM_SCHEMA" ]; then
  echo "Error: One or more required environment variables (POSTGRES_PASSWORD, CUSTOM_PASSWORD, POSTGRES_USER, SERVER, CUSTOM_USER, CUSTOM_DATABASE, CUSTOM_SCHEMA) are not set."
  exit 1
fi

echo "Starting database setup for database '$CUSTOM_DATABASE'..."

# --- URL Encode passwords using Node.js for connection strings ---
POSTGRES_PASSWORD_URL=$(node -p "encodeURIComponent(process.env.POSTGRES_PASSWORD)")
if [ -z "$POSTGRES_PASSWORD_URL" ]; then echo "Error encoding POSTGRES_PASSWORD"; exit 1; fi

CUSTOM_PASSWORD_URL=$(node -p "encodeURIComponent(process.env.CUSTOM_PASSWORD)")
if [ -z "$CUSTOM_PASSWORD_URL" ]; then echo "Error encoding CUSTOM_PASSWORD"; exit 1; fi

echo "Passwords URL-encoded."

# --- Escape single quotes in CATAPULT password for SQL command string ---
SQL_ESCAPED_PASSWORD=$(printf %s "$CUSTOM_PASSWORD" | awk "{gsub(/'/,\"''\"); print}")
if [ -z "$SQL_ESCAPED_PASSWORD" ]; then echo "Error SQL-escaping CUSTOM_PASSWORD"; exit 1; fi

echo "Password SQL-escaped."

# --- Commands using admin credentials (connect to 'postgres' db) ---
# Use the URL-encoded password in the connection string URL
echo "Attempting to create user '$CUSTOM_USER'..."
psql "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD_URL@$SERVER/postgres" -c "CREATE USER $CUSTOM_USER WITH PASSWORD '$SQL_ESCAPED_PASSWORD';" || echo "User '$CUSTOM_USER' likely already exists (Ignoring error)."

# --- Create the dedicated database for catapult ---
echo "Attempting to create database '$CUSTOM_DATABASE' owned by '$CUSTOM_USER'..."
# Connect to 'postgres' database to create a new database
# Use OWNER clause to set the owner during creation
psql "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD_URL@$SERVER/postgres" -c "CREATE DATABASE \"$CUSTOM_DATABASE\" OWNER $CUSTOM_USER;" || echo "Database '$CUSTOM_DATABASE' likely already exists (Ignoring error)."

# --- Grant necessary privileges ON the new database ---
echo "Attempting to grant connect permission on database '$CUSTOM_DATABASE'..."
# Connect to 'postgres' again to grant permissions on the database object itself
psql "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD_URL@$SERVER/postgres" -c "GRANT CONNECT ON DATABASE \"$CUSTOM_DATABASE\" TO $CUSTOM_USER;"
if [ $? -ne 0 ]; then echo "Error granting connect permission"; exit 1; fi

# Grant CREATE on the database allows the user to create schemas within it
echo "Attempting to grant create permission on database '$CUSTOM_DATABASE'..."
psql "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD_URL@$SERVER/postgres" -c "GRANT CREATE ON DATABASE \"$CUSTOM_DATABASE\" TO $CUSTOM_USER;"
if [ $? -ne 0 ]; then echo "Error granting create permission"; exit 1; fi


# --- Command using catapult user credentials (connect to the NEW database) ---
# Use the URL-encoded CATAPULT password in the connection string URL
# Connect to the newly created $CATAPULTDATABASENAME database
echo "Attempting to create schema '$CUSTOM_SCHEMA' in database '$CUSTOM_DATABASE'..."
psql "postgresql://$CUSTOM_USER:$CUSTOM_PASSWORD_URL@$SERVER/$CUSTOM_DATABASE" -c "CREATE SCHEMA IF NOT EXISTS \"$CUSTOM_SCHEMA\" AUTHORIZATION $CUSTOM_USER;"
if [ $? -ne 0 ]; then echo "Error creating schema '$CUSTOM_SCHEMA'"; exit 1; fi

echo "Database setup script completed successfully."
