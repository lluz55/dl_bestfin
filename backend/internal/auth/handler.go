package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"bestfin-backend/internal/db"
)

const maxAuthBodyBytes = 8 * 1024

type loginRequest struct {
	Email              string `json:"email"`
	Password           string `json:"password"`
	Name               string `json:"name"`
	KdfSalt            string `json:"kdf_salt"`
	EncryptedMasterKey string `json:"encrypted_master_key"`
	RecoveryVerifier   string `json:"recovery_verifier"`
}

type authResponse struct {
	UserID             string `json:"user_id"`
	Email              string `json:"email"`
	Token              string `json:"token"`
	RefreshToken       string `json:"refresh_token"`
	KdfSalt            string `json:"kdf_salt"`
	EncryptedMasterKey string `json:"encrypted_master_key"`
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type refreshResponse struct {
	Token        string `json:"token"`
	RefreshToken string `json:"refresh_token"`
}

type updateMasterKeyRequest struct {
	EncryptedMasterKey string `json:"encrypted_master_key"`
}

type recoverRequest struct {
	Email              string `json:"email"`
	RecoveryVerifier   string `json:"recovery_verifier"`
	NewPassword        string `json:"new_password"`
	EncryptedMasterKey string `json:"encrypted_master_key"`
	KdfSalt            string `json:"kdf_salt"`
}

type pendingResponse struct {
	Status  string `json:"status"`
	Message string `json:"message"`
}

func Register(database *sql.DB, jwtSecret string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req loginRequest
		if err := decodeAuthRequest(w, r, &req); err != nil {
			return
		}
		req.Email = normalizeEmail(req.Email)
		if !validEmail(req.Email) || !validPassword(req.Password) {
			http.Error(w, "email and password required", http.StatusBadRequest)
			return
		}

		existing, err := db.GetUserByEmail(database, req.Email)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		if existing != nil {
			http.Error(w, "email already registered", http.StatusConflict)
			return
		}

		hash, err := HashPassword(req.Password)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		kdfSalt := req.KdfSalt
		if kdfSalt == "" {
			kdfSalt, err = randomHex(16)
			if err != nil {
				http.Error(w, "internal error", http.StatusInternalServerError)
				return
			}
		} else if !validHexSalt(kdfSalt) {
			http.Error(w, "invalid kdf_salt", http.StatusBadRequest)
			return
		}

		userID, err := randomHex(16)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		if err := db.CreateUser(database, userID, req.Email, hash, kdfSalt, req.EncryptedMasterKey, req.RecoveryVerifier); err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusAccepted)
		writeJSON(w, pendingResponse{
			Status:  "pending",
			Message: "Conta criada. Aguardando aprovação do administrador.",
		})
	}
}

func Login(database *sql.DB, jwtSecret string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req loginRequest
		if err := decodeAuthRequest(w, r, &req); err != nil {
			return
		}
		req.Email = normalizeEmail(req.Email)

		user, err := db.GetUserByEmail(database, req.Email)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		// Always run the bcrypt comparison, even for an unknown email, so the
		// response time doesn't reveal whether the account exists.
		hash := dummyHash
		if user != nil {
			hash = user.PasswordHash
		}
		passwordErr := CheckPassword(req.Password, hash)
		if user == nil || passwordErr != nil {
			http.Error(w, "invalid credentials", http.StatusUnauthorized)
			return
		}

		if user.Status != "approved" {
			w.WriteHeader(http.StatusForbidden)
			msg := "account_pending_approval"
			if user.Status == "rejected" {
				msg = "account_rejected"
			}
			writeJSON(w, map[string]string{"error": msg})
			return
		}

		issueAuth(w, database, jwtSecret, user.ID, user.Email, user.KdfSalt, user.EncryptedMasterKey)
	}
}

func Refresh(database *sql.DB, jwtSecret string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req refreshRequest
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxAuthBodyBytes)).Decode(&req); err != nil || req.RefreshToken == "" {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		tokenHash := hashToken(req.RefreshToken)
		rt, err := db.GetRefreshToken(database, tokenHash)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		if rt == nil || rt.ExpiresAt < time.Now().Unix() {
			if rt != nil {
				db.DeleteRefreshToken(database, rt.Token) //nolint:errcheck
			}
			http.Error(w, "invalid or expired refresh token", http.StatusUnauthorized)
			return
		}
		if err := db.DeleteRefreshToken(database, rt.Token); err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		token, err := SignToken(rt.UserID, jwtSecret, time.Hour)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		refreshToken, err := randomHex(32)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		expiresAt := time.Now().Add(30 * 24 * time.Hour).Unix()
		if err := db.StoreRefreshToken(database, hashToken(refreshToken), rt.UserID, expiresAt); err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		writeJSON(w, refreshResponse{Token: token, RefreshToken: refreshToken})
	}
}

func UpdateMasterKey(database *sql.DB, jwtSecret string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := userIDFromJWT(w, r, jwtSecret)
		if !ok {
			return
		}
		var req updateMasterKeyRequest
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxAuthBodyBytes)).Decode(&req); err != nil || req.EncryptedMasterKey == "" {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		if err := db.UpdateEncryptedMasterKey(database, userID, req.EncryptedMasterKey); err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}
}

func RecoverAccount(database *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req recoverRequest
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxAuthBodyBytes)).Decode(&req); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		req.Email = normalizeEmail(req.Email)
		if req.Email == "" || req.RecoveryVerifier == "" || req.EncryptedMasterKey == "" {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		if !validPassword(req.NewPassword) {
			http.Error(w, "invalid new password", http.StatusBadRequest)
			return
		}

		user, err := db.GetUserByRecoveryVerifier(database, req.Email, req.RecoveryVerifier)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		if user == nil {
			http.Error(w, "invalid recovery verifier", http.StatusUnauthorized)
			return
		}

		if user.Status != "approved" {
			w.WriteHeader(http.StatusForbidden)
			msg := "account_pending_approval"
			if user.Status == "rejected" {
				msg = "account_rejected"
			}
			writeJSON(w, map[string]string{"error": msg})
			return
		}

		hash, err := HashPassword(req.NewPassword)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		kdfSalt := req.KdfSalt
		if kdfSalt == "" {
			kdfSalt = user.KdfSalt
		}
		if err := db.UpdateMasterKey(database, user.ID, req.EncryptedMasterKey, req.RecoveryVerifier, hash, kdfSalt); err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

func userIDFromJWT(w http.ResponseWriter, r *http.Request, jwtSecret string) (string, bool) {
	header := r.Header.Get("Authorization")
	if len(header) < 8 || header[:7] != "Bearer " {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return "", false
	}
	userID, err := VerifyToken(header[7:], jwtSecret)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return "", false
	}
	return userID, true
}

func issueAuth(w http.ResponseWriter, database *sql.DB, jwtSecret, userID, email, kdfSalt, encryptedMasterKey string) {
	token, err := SignToken(userID, jwtSecret, time.Hour)
	if err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	refreshToken, err := randomHex(32)
	if err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	expiresAt := time.Now().Add(30 * 24 * time.Hour).Unix()
	if err := db.StoreRefreshToken(database, hashToken(refreshToken), userID, expiresAt); err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, authResponse{
		UserID:             userID,
		Email:              email,
		Token:              token,
		RefreshToken:       refreshToken,
		KdfSalt:            kdfSalt,
		EncryptedMasterKey: encryptedMasterKey,
	})
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v) //nolint:errcheck
}

func randomHex(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

func hashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

func decodeAuthRequest(w http.ResponseWriter, r *http.Request, req *loginRequest) error {
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxAuthBodyBytes)).Decode(req); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return err
	}
	return nil
}

func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

func validEmail(email string) bool {
	return len(email) <= 254 && strings.Contains(email, "@")
}

func validPassword(password string) bool {
	return len(password) >= 8 && len(password) <= 256
}

func validHexSalt(value string) bool {
	if len(value) != 32 {
		return false
	}
	_, err := hex.DecodeString(value)
	return err == nil
}
