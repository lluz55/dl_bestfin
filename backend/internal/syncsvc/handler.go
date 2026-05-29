package syncsvc

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"bestfin-backend/internal/db"
	"bestfin-backend/internal/middleware"
)

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
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		for _, record := range req.Records {
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
