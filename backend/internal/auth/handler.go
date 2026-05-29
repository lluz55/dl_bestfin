package auth

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"

	"bestfin-backend/internal/db"
)

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type authResponse struct {
	UserID       string `json:"user_id"`
	Token        string `json:"token"`
	RefreshToken string `json:"refresh_token"`
	KdfSalt      string `json:"kdf_salt"`
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type refreshResponse struct {
	Token string `json:"token"`
}

func Register(database *sql.DB, jwtSecret string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req loginRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Email == "" || req.Password == "" {
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

		userID := uuid.New().String()
		if err := db.CreateUser(database, userID, req.Email, hash, kdfSalt); err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		issueAuth(w, database, jwtSecret, userID, kdfSalt)
	}
}

func Login(database *sql.DB, jwtSecret string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req loginRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		user, err := db.GetUserByEmail(database, req.Email)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		if user == nil || CheckPassword(req.Password, user.PasswordHash) != nil {
			http.Error(w, "invalid credentials", http.StatusUnauthorized)
			return
		}

		issueAuth(w, database, jwtSecret, user.ID, user.KdfSalt)
	}
}

func Refresh(database *sql.DB, jwtSecret string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req refreshRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.RefreshToken == "" {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		rt, err := db.GetRefreshToken(database, req.RefreshToken)
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

		token, err := SignToken(rt.UserID, jwtSecret, time.Hour)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		writeJSON(w, refreshResponse{Token: token})
	}
}

func issueAuth(w http.ResponseWriter, database *sql.DB, jwtSecret, userID, kdfSalt string) {
	token, err := SignToken(userID, jwtSecret, time.Hour)
	if err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	refreshToken := uuid.New().String()
	expiresAt := time.Now().Add(30 * 24 * time.Hour).Unix()
	if err := db.StoreRefreshToken(database, refreshToken, userID, expiresAt); err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	writeJSON(w, authResponse{
		UserID:       userID,
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
