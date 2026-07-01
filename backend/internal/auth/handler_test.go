package auth

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"

	"bestfin-backend/internal/db"
)

func TestRegisterAndLoginPreserveClientKdfSalt(t *testing.T) {
	database, err := db.Open(filepath.Join(t.TempDir(), "bestfin.sqlite"))
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer database.Close()

	const jwtSecret = "test-secret-with-at-least-32-characters"
	const salt = "00112233445566778899aabbccddeeff"

	registerBody := map[string]string{
		"email":                "user@example.com",
		"password":             "password123",
		"kdf_salt":             salt,
		"encrypted_master_key": "wrapped-key",
		"recovery_verifier":    "verifier",
	}
	registerResp := performJSON(Register(database, jwtSecret), registerBody)
	if registerResp.Code != http.StatusOK {
		t.Fatalf("register status = %d body = %s", registerResp.Code, registerResp.Body.String())
	}

	var registered authResponse
	if err := json.Unmarshal(registerResp.Body.Bytes(), &registered); err != nil {
		t.Fatalf("decode register response: %v", err)
	}
	if registered.KdfSalt != salt {
		t.Fatalf("register kdf_salt = %q, want %q", registered.KdfSalt, salt)
	}

	loginBody := map[string]string{
		"email":    "user@example.com",
		"password": "password123",
	}
	loginResp := performJSON(Login(database, jwtSecret), loginBody)
	if loginResp.Code != http.StatusOK {
		t.Fatalf("login status = %d body = %s", loginResp.Code, loginResp.Body.String())
	}

	var loggedIn authResponse
	if err := json.Unmarshal(loginResp.Body.Bytes(), &loggedIn); err != nil {
		t.Fatalf("decode login response: %v", err)
	}
	if loggedIn.KdfSalt != salt {
		t.Fatalf("login kdf_salt = %q, want %q", loggedIn.KdfSalt, salt)
	}
	if loggedIn.EncryptedMasterKey != "wrapped-key" {
		t.Fatalf("encrypted master key = %q", loggedIn.EncryptedMasterKey)
	}
}

func performJSON(handler http.HandlerFunc, body any) *httptest.ResponseRecorder {
	encoded, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/", bytes.NewReader(encoded))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	return rec
}
