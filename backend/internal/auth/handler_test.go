package auth

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"

	"bestfin-backend/internal/db"
)

const testJWTSecret = "test-secret-with-at-least-32-characters"
const testSalt = "00112233445566778899aabbccddeeff"

func TestRegisterReturnsPending(t *testing.T) {
	database := openTestDB(t)
	defer database.Close()

	body := map[string]string{
		"email":                "pending@example.com",
		"password":             "password123",
		"kdf_salt":             testSalt,
		"encrypted_master_key": "wrapped-key",
		"recovery_verifier":    "verifier",
	}
	resp := performJSON(Register(database, testJWTSecret), body)
	if resp.Code != http.StatusAccepted {
		t.Fatalf("register status = %d, want %d; body = %s", resp.Code, http.StatusAccepted, resp.Body.String())
	}

	var result pendingResponse
	if err := json.Unmarshal(resp.Body.Bytes(), &result); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if result.Status != "pending" {
		t.Fatalf("status = %q, want %q", result.Status, "pending")
	}
}

func TestLoginBlockedForPendingUser(t *testing.T) {
	database := openTestDB(t)
	defer database.Close()

	registerUser(t, database, "pending@example.com")

	body := map[string]string{
		"email":    "pending@example.com",
		"password": "password123",
	}
	resp := performJSON(Login(database, testJWTSecret), body)
	if resp.Code != http.StatusForbidden {
		t.Fatalf("login status = %d, want %d; body = %s", resp.Code, http.StatusForbidden, resp.Body.String())
	}

	var result map[string]string
	if err := json.Unmarshal(resp.Body.Bytes(), &result); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if result["error"] != "account_pending_approval" {
		t.Fatalf("error = %q, want %q", result["error"], "account_pending_approval")
	}
}

func TestLoginBlockedForRejectedUser(t *testing.T) {
	database := openTestDB(t)
	defer database.Close()

	registerUser(t, database, "rejected@example.com")
	user, _ := db.GetUserByEmail(database, "rejected@example.com")
	db.UpdateUserStatus(database, user.ID, "rejected")

	body := map[string]string{
		"email":    "rejected@example.com",
		"password": "password123",
	}
	resp := performJSON(Login(database, testJWTSecret), body)
	if resp.Code != http.StatusForbidden {
		t.Fatalf("login status = %d, want %d; body = %s", resp.Code, http.StatusForbidden, resp.Body.String())
	}

	var result map[string]string
	if err := json.Unmarshal(resp.Body.Bytes(), &result); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if result["error"] != "account_rejected" {
		t.Fatalf("error = %q, want %q", result["error"], "account_rejected")
	}
}

func TestLoginWorksAfterApproval(t *testing.T) {
	database := openTestDB(t)
	defer database.Close()

	registerUser(t, database, "approved@example.com")

	loginBody := map[string]string{
		"email":    "approved@example.com",
		"password": "password123",
	}
	resp := performJSON(Login(database, testJWTSecret), loginBody)
	if resp.Code != http.StatusForbidden {
		t.Fatalf("login before approval: status = %d, want %d", resp.Code, http.StatusForbidden)
	}

	user, _ := db.GetUserByEmail(database, "approved@example.com")
	db.UpdateUserStatus(database, user.ID, "approved")

	resp = performJSON(Login(database, testJWTSecret), loginBody)
	if resp.Code != http.StatusOK {
		t.Fatalf("login after approval: status = %d, want %d; body = %s", resp.Code, http.StatusOK, resp.Body.String())
	}

	var loggedIn authResponse
	if err := json.Unmarshal(resp.Body.Bytes(), &loggedIn); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if loggedIn.KdfSalt != testSalt {
		t.Fatalf("kdf_salt = %q, want %q", loggedIn.KdfSalt, testSalt)
	}
}

func TestRecoveryBlockedForPendingUser(t *testing.T) {
	database := openTestDB(t)
	defer database.Close()

	registerUser(t, database, "recovery@example.com")

	body := map[string]string{
		"email":                "recovery@example.com",
		"recovery_verifier":    "verifier",
		"new_password":         "newpass1234",
		"encrypted_master_key": "new-key",
		"kdf_salt":             testSalt,
	}
	resp := performJSON(RecoverAccount(database), body)
	if resp.Code != http.StatusForbidden {
		t.Fatalf("recovery status = %d, want %d; body = %s", resp.Code, http.StatusForbidden, resp.Body.String())
	}
}

func TestDuplicateEmailRejected(t *testing.T) {
	database := openTestDB(t)
	defer database.Close()

	body := map[string]string{
		"email":    "dup@example.com",
		"password": "password123",
	}
	resp := performJSON(Register(database, testJWTSecret), body)
	if resp.Code != http.StatusAccepted {
		t.Fatalf("first register: status = %d, want %d", resp.Code, http.StatusAccepted)
	}

	resp = performJSON(Register(database, testJWTSecret), body)
	if resp.Code != http.StatusConflict {
		t.Fatalf("duplicate register: status = %d, want %d; body = %s", resp.Code, http.StatusConflict, resp.Body.String())
	}
}

func openTestDB(t *testing.T) *sql.DB {
	t.Helper()
	database, err := db.Open(filepath.Join(t.TempDir(), "bestfin.sqlite"))
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	return database
}

func registerUser(t *testing.T, database *sql.DB, email string) {
	t.Helper()
	body := map[string]string{
		"email":                email,
		"password":             "password123",
		"kdf_salt":             testSalt,
		"encrypted_master_key": "wrapped-key",
		"recovery_verifier":    "verifier",
	}
	resp := performJSON(Register(database, testJWTSecret), body)
	if resp.Code != http.StatusAccepted {
		t.Fatalf("register %s: status = %d, body = %s", email, resp.Code, resp.Body.String())
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
