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
	Email    string `json:"email"`
	Password string `json:"password"`
	Name     string `json:"name"`
}

type authResponse struct {
	UserID       string `json:"user_id"`
	Email        string `json:"email"`
	Token        string `json:"token"`
	RefreshToken string `json:"refresh_token"`
	KdfSalt      string `json:"kdf_salt"`
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type refreshResponse struct {
	Token        string `json:"token"`
	RefreshToken string `json:"refresh_token"`
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

		kdfSalt, err := randomHex(16)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		userID, err := randomHex(16)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		if err := db.CreateUser(database, userID, req.Email, hash, kdfSalt); err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		issueAuth(w, database, jwtSecret, userID, req.Email, kdfSalt)
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
		if user == nil || CheckPassword(req.Password, user.PasswordHash) != nil {
			http.Error(w, "invalid credentials", http.StatusUnauthorized)
			return
		}

		issueAuth(w, database, jwtSecret, user.ID, user.Email, user.KdfSalt)
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

func issueAuth(w http.ResponseWriter, database *sql.DB, jwtSecret, userID, email, kdfSalt string) {
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
		UserID:       userID,
		Email:        email,
		Token:        token,
		RefreshToken: refreshToken,
		KdfSalt:      kdfSalt,
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
