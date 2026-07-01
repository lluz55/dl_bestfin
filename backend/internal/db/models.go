package db

type User struct {
	ID                 string
	Email              string
	PasswordHash       string
	KdfSalt            string
	CreatedAt          int64
	EncryptedMasterKey string
	RecoveryVerifier   string
}

type RefreshToken struct {
	Token     string
	UserID    string
	ExpiresAt int64
}

type SyncRecord struct {
	EntityType string `json:"entity_type"`
	EntityID   string `json:"entity_id"`
	Payload    string `json:"payload"`
	UpdatedAt  int64  `json:"updated_at"`
	IsDeleted  bool   `json:"is_deleted"`
}
