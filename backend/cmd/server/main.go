package main

import (
	"log/slog"
	"net/http"
	"os"
	"path/filepath"

	"github.com/go-chi/chi/v5"

	"bestfin-backend/internal/auth"
	"bestfin-backend/internal/db"
	"bestfin-backend/internal/middleware"
	"bestfin-backend/internal/syncsvc"
)

func main() {
	port := envOr("PORT", "8080")
	dataDir := envOr("DATA_DIR", "./data")
	jwtSecret := mustEnv("JWT_SECRET")

	if err := os.MkdirAll(dataDir, 0o755); err != nil {
		slog.Error("create data dir", "err", err)
		os.Exit(1)
	}

	database, err := db.Open(filepath.Join(dataDir, "bestfin.sqlite"))
	if err != nil {
		slog.Error("open db", "err", err)
		os.Exit(1)
	}
	defer database.Close()

	r := chi.NewRouter()
	r.Use(middleware.Logger)

	r.Post("/auth/register", auth.Register(database, jwtSecret))
	r.Post("/auth/login", auth.Login(database, jwtSecret))
	r.Post("/auth/refresh", auth.Refresh(database, jwtSecret))

	r.Group(func(r chi.Router) {
		r.Use(middleware.RequireAuth(jwtSecret))
		r.Get("/sync/pull", syncsvc.Pull(database))
		r.Post("/sync/push", syncsvc.Push(database))
	})

	slog.Info("bestfin-backend starting", "port", port)
	if err := http.ListenAndServe(":"+port, r); err != nil {
		slog.Error("server", "err", err)
		os.Exit(1)
	}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func mustEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		slog.Error("required env var not set", "key", key)
		os.Exit(1)
	}
	return v
}
