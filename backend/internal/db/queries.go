package db

import (
	"database/sql"
	"time"

	"github.com/google/uuid"
)

func CreateUser(database *sql.DB, id, email, passwordHash, kdfSalt string) error {
	_, err := database.Exec(
		`INSERT INTO users (id, email, password_hash, kdf_salt, created_at) VALUES (?, ?, ?, ?, ?)`,
		id, email, passwordHash, kdfSalt, time.Now().Unix(),
	)
	return err
}

func GetUserByEmail(database *sql.DB, email string) (*User, error) {
	u := &User{}
	err := database.QueryRow(
		`SELECT id, email, password_hash, kdf_salt, created_at FROM users WHERE email = ?`, email,
	).Scan(&u.ID, &u.Email, &u.PasswordHash, &u.KdfSalt, &u.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return u, err
}

func StoreRefreshToken(database *sql.DB, token, userID string, expiresAt int64) error {
	_, err := database.Exec(
		`INSERT INTO refresh_tokens (token, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)`,
		token, userID, expiresAt, time.Now().Unix(),
	)
	return err
}

func GetRefreshToken(database *sql.DB, token string) (*RefreshToken, error) {
	rt := &RefreshToken{}
	err := database.QueryRow(
		`SELECT token, user_id, expires_at FROM refresh_tokens WHERE token = ?`, token,
	).Scan(&rt.Token, &rt.UserID, &rt.ExpiresAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return rt, err
}

func DeleteRefreshToken(database *sql.DB, token string) error {
	_, err := database.Exec(`DELETE FROM refresh_tokens WHERE token = ?`, token)
	return err
}

func UpsertSyncRecord(database *sql.DB, userID string, r SyncRecord) error {
	isDeleted := 0
	if r.IsDeleted {
		isDeleted = 1
	}
	_, err := database.Exec(`
		INSERT INTO sync_records (id, user_id, entity_type, entity_id, payload, updated_at, is_deleted)
		VALUES (?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(user_id, entity_type, entity_id) DO UPDATE SET
			payload    = excluded.payload,
			updated_at = excluded.updated_at,
			is_deleted = excluded.is_deleted
		WHERE excluded.updated_at > sync_records.updated_at
	`, uuid.New().String(), userID, r.EntityType, r.EntityID, r.Payload, r.UpdatedAt, isDeleted)
	return err
}

func GetSyncRecordsSince(database *sql.DB, userID string, since int64) ([]SyncRecord, error) {
	rows, err := database.Query(`
		SELECT entity_type, entity_id, payload, updated_at, is_deleted
		FROM sync_records
		WHERE user_id = ? AND updated_at > ?
		ORDER BY updated_at ASC
	`, userID, since)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var records []SyncRecord
	for rows.Next() {
		var r SyncRecord
		var isDeleted int
		if err := rows.Scan(&r.EntityType, &r.EntityID, &r.Payload, &r.UpdatedAt, &isDeleted); err != nil {
			return nil, err
		}
		r.IsDeleted = isDeleted == 1
		records = append(records, r)
	}
	return records, rows.Err()
}
