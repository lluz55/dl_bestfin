package syncsvc

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"

	"bestfin-backend/internal/auth"
	"bestfin-backend/internal/db"
	"bestfin-backend/internal/middleware"
)

func TestValidateRecordAcceptsOpaqueBase64Payload(t *testing.T) {
	record := db.SyncRecord{
		EntityType: "transaction",
		EntityID:   "tx-1",
		Payload:    "MTIzNDU2Nzg5MDEyY2lwaGVydGV4dG1hYw==",
		UpdatedAt:  time.Now().Unix(),
		IsDeleted:  false,
	}

	if err := validateRecord(record); err != nil {
		t.Fatalf("expected opaque base64 payload to be valid: %v", err)
	}
}

func TestValidateRecordRejectsPlainJsonPayload(t *testing.T) {
	record := db.SyncRecord{
		EntityType: "transaction",
		EntityID:   "tx-1",
		Payload:    `{"description":"plain text"}`,
		UpdatedAt:  time.Now().Unix(),
		IsDeleted:  false,
	}

	if err := validateRecord(record); err == nil {
		t.Fatal("expected plain JSON payload to be rejected")
	}
}

func TestPushThenPullReturnsOpaqueRecord(t *testing.T) {
	database, err := db.Open(filepath.Join(t.TempDir(), "bestfin.sqlite"))
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer database.Close()

	const userID = "user-1"
	const jwtSecret = "test-secret-with-at-least-32-characters"
	if err := db.CreateUser(
		database,
		userID,
		"user@example.com",
		"hash",
		"00112233445566778899aabbccddeeff",
		"wrapped-key",
		"verifier",
	); err != nil {
		t.Fatalf("create user: %v", err)
	}

	token, err := auth.SignToken(userID, jwtSecret, time.Hour)
	if err != nil {
		t.Fatalf("sign token: %v", err)
	}

	pullEmpty := performAuthorized(
		http.MethodGet,
		"/sync/pull?since=0",
		nil,
		token,
		middleware.RequireAuth(jwtSecret)(Pull(database)),
	)
	if pullEmpty.Code != http.StatusOK {
		t.Fatalf("empty pull status = %d body = %s", pullEmpty.Code, pullEmpty.Body.String())
	}
	var empty pullResponse
	if err := json.Unmarshal(pullEmpty.Body.Bytes(), &empty); err != nil {
		t.Fatalf("decode empty pull: %v", err)
	}
	if len(empty.Records) != 0 {
		t.Fatalf("empty pull returned %d records", len(empty.Records))
	}

	payload := "MTIzNDU2Nzg5MDEyY2lwaGVydGV4dG1hYw=="
	updatedAt := time.Now().Unix()
	pushBody := pushRequest{
		Records: []db.SyncRecord{
			{
				EntityType: "transaction",
				EntityID:   "tx-1",
				Payload:    payload,
				UpdatedAt:  updatedAt,
				IsDeleted:  false,
			},
		},
	}
	pushResp := performAuthorized(
		http.MethodPost,
		"/sync/push",
		pushBody,
		token,
		middleware.RequireAuth(jwtSecret)(Push(database)),
	)
	if pushResp.Code != http.StatusOK {
		t.Fatalf("push status = %d body = %s", pushResp.Code, pushResp.Body.String())
	}

	pullAfterPush := performAuthorized(
		http.MethodGet,
		"/sync/pull?since=0",
		nil,
		token,
		middleware.RequireAuth(jwtSecret)(Pull(database)),
	)
	if pullAfterPush.Code != http.StatusOK {
		t.Fatalf("pull status = %d body = %s", pullAfterPush.Code, pullAfterPush.Body.String())
	}
	var pulled pullResponse
	if err := json.Unmarshal(pullAfterPush.Body.Bytes(), &pulled); err != nil {
		t.Fatalf("decode pull: %v", err)
	}
	if len(pulled.Records) != 1 {
		t.Fatalf("pull returned %d records", len(pulled.Records))
	}
	if pulled.Records[0].Payload != payload {
		t.Fatalf("payload = %q, want %q", pulled.Records[0].Payload, payload)
	}
}

func performAuthorized(
	method string,
	path string,
	body any,
	token string,
	handler http.Handler,
) *httptest.ResponseRecorder {
	var reader *bytes.Reader
	if body == nil {
		reader = bytes.NewReader(nil)
	} else {
		encoded, _ := json.Marshal(body)
		reader = bytes.NewReader(encoded)
	}
	req := httptest.NewRequest(method, path, reader)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	return rec
}
