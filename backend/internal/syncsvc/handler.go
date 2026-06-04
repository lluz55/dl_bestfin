package syncsvc

import (
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"bestfin-backend/internal/db"
	"bestfin-backend/internal/middleware"
)

const (
	maxSyncBodyBytes = 2 * 1024 * 1024
	maxSyncRecords   = 250
	maxPayloadBytes  = 64 * 1024
)

var allowedEntityTypes = map[string]bool{
	"account":     true,
	"transaction": true,
	"category":    true,
	"goal":        true,
}

type pushRequest struct {
	Records []db.SyncRecord `json:"records"`
}

type pushResponse struct {
	Synced     int   `json:"synced"`
	ServerTime int64 `json:"server_time"`
}

type pullResponse struct {
	Records    []db.SyncRecord `json:"records"`
	ServerTime int64           `json:"server_time"`
}

func Pull(database *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromContext(r.Context())
		since, _ := strconv.ParseInt(r.URL.Query().Get("since"), 10, 64)

		records, err := db.GetSyncRecordsSince(database, userID, since)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		if records == nil {
			records = []db.SyncRecord{}
		}

		writeJSON(w, pullResponse{Records: records, ServerTime: time.Now().Unix()})
	}
}

func Push(database *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromContext(r.Context())

		var req pushRequest
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxSyncBodyBytes)).Decode(&req); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		if len(req.Records) > maxSyncRecords {
			http.Error(w, "too many records", http.StatusRequestEntityTooLarge)
			return
		}

		for _, record := range req.Records {
			if err := validateRecord(record); err != nil {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}
			if err := db.UpsertSyncRecord(database, userID, record); err != nil {
				http.Error(w, "internal error", http.StatusInternalServerError)
				return
			}
		}

		writeJSON(w, pushResponse{Synced: len(req.Records), ServerTime: time.Now().Unix()})
	}
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v) //nolint:errcheck
}

func validateRecord(record db.SyncRecord) error {
	if !allowedEntityTypes[record.EntityType] {
		return errors.New("invalid entity_type")
	}
	if len(record.EntityID) < 1 || len(record.EntityID) > 128 || strings.ContainsAny(record.EntityID, "\x00\r\n") {
		return errors.New("invalid entity_id")
	}
	if len(record.Payload) == 0 || len(record.Payload) > maxPayloadBytes {
		return errors.New("invalid payload size")
	}
	if !json.Valid([]byte(record.Payload)) {
		return errors.New("invalid payload json")
	}
	now := time.Now().Unix()
	if record.UpdatedAt <= 0 || record.UpdatedAt > now+300 {
		return errors.New("invalid updated_at")
	}
	return nil
}
