package middleware

import (
	"net"
	"net/http"
	"sync"
	"time"
)

type rateEntry struct {
	count     int
	resetAt   time.Time
	blockedAt time.Time
}

type RateLimiter struct {
	mu       sync.Mutex
	entries  map[string]rateEntry
	limit    int
	window   time.Duration
	blockFor time.Duration
}

func NewRateLimiter(limit int, window, blockFor time.Duration) *RateLimiter {
	return &RateLimiter{
		entries:  make(map[string]rateEntry),
		limit:    limit,
		window:   window,
		blockFor: blockFor,
	}
}

func SecurityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Referrer-Policy", "no-referrer")
		next.ServeHTTP(w, r)
	})
}

func (l *RateLimiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !l.allow(clientIP(r)) {
			http.Error(w, "too many requests", http.StatusTooManyRequests)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (l *RateLimiter) allow(key string) bool {
	now := time.Now()
	l.mu.Lock()
	defer l.mu.Unlock()

	entry := l.entries[key]
	if !entry.blockedAt.IsZero() && now.Sub(entry.blockedAt) < l.blockFor {
		return false
	}
	if entry.resetAt.IsZero() || now.After(entry.resetAt) {
		l.entries[key] = rateEntry{count: 1, resetAt: now.Add(l.window)}
		return true
	}
	entry.count++
	if entry.count > l.limit {
		entry.blockedAt = now
		l.entries[key] = entry
		return false
	}
	l.entries[key] = entry
	return true
}

func clientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
