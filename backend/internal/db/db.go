package db

import (
	"database/sql"

	_ "modernc.org/sqlite"
)

func Open(path string) (*sql.DB, error) {
	database, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	if err := database.Ping(); err != nil {
		database.Close()
		return nil, err
	}
	if _, err := database.Exec("PRAGMA foreign_keys = ON"); err != nil {
		database.Close()
		return nil, err
	}
	if _, err := database.Exec("PRAGMA journal_mode = WAL"); err != nil {
		database.Close()
		return nil, err
	}
	if err := migrate(database); err != nil {
		database.Close()
		return nil, err
	}
	return database, nil
}

func migrate(database *sql.DB) error {
	stmts := []string{
		`CREATE TABLE IF NOT EXISTS users (
			id TEXT PRIMARY KEY,
			email TEXT UNIQUE NOT NULL,
			password_hash TEXT NOT NULL,
			kdf_salt TEXT NOT NULL,
			created_at INTEGER NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS sync_records (
			id TEXT PRIMARY KEY,
			user_id TEXT NOT NULL REFERENCES users(id),
			entity_type TEXT NOT NULL,
			entity_id TEXT NOT NULL,
			payload TEXT NOT NULL,
			updated_at INTEGER NOT NULL,
			is_deleted INTEGER NOT NULL DEFAULT 0,
			UNIQUE(user_id, entity_type, entity_id)
		)`,
		`CREATE INDEX IF NOT EXISTS idx_sync_records_user_updated
			ON sync_records(user_id, updated_at)`,
		`CREATE TABLE IF NOT EXISTS refresh_tokens (
			token TEXT PRIMARY KEY,
			user_id TEXT NOT NULL REFERENCES users(id),
			expires_at INTEGER NOT NULL,
			created_at INTEGER NOT NULL
		)`,
	}
	for _, stmt := range stmts {
		if _, err := database.Exec(stmt); err != nil {
			return err
		}
	}
	return nil
}
