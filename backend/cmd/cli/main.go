package main

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"bestfin-backend/internal/db"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	dataDir := envOr("DATA_DIR", "./data")
	database, err := db.Open(filepath.Join(dataDir, "bestfin.sqlite"))
	if err != nil {
		fmt.Fprintf(os.Stderr, "error opening database: %v\n", err)
		os.Exit(1)
	}
	defer database.Close()

	switch os.Args[1] {
	case "pending":
		cmdListByStatus(database, "pending")
	case "list":
		cmdListAll(database)
	case "approve":
		if len(os.Args) < 3 {
			fmt.Fprintln(os.Stderr, "usage: bestfin-cli approve <email>")
			os.Exit(1)
		}
		cmdSetStatus(database, os.Args[2], "approved")
	case "reject":
		if len(os.Args) < 3 {
			fmt.Fprintln(os.Stderr, "usage: bestfin-cli reject <email>")
			os.Exit(1)
		}
		cmdSetStatus(database, os.Args[2], "rejected")
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n", os.Args[1])
		printUsage()
		os.Exit(1)
	}
}

func cmdListByStatus(database *sql.DB, status string) {
	users, err := db.ListUsersByStatus(database, status)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error listing users: %v\n", err)
		os.Exit(1)
	}
	if len(users) == 0 {
		fmt.Printf("No %s users found.\n", status)
		return
	}
	printUserTable(users)
}

func cmdListAll(database *sql.DB) {
	users, err := db.ListAllUsers(database)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error listing users: %v\n", err)
		os.Exit(1)
	}
	if len(users) == 0 {
		fmt.Println("No users found.")
		return
	}
	printUserTable(users)
}

func cmdSetStatus(database *sql.DB, email, status string) {
	email = strings.ToLower(strings.TrimSpace(email))
	user, err := db.GetUserByEmail(database, email)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error looking up user: %v\n", err)
		os.Exit(1)
	}
	if user == nil {
		fmt.Fprintf(os.Stderr, "user not found: %s\n", email)
		os.Exit(1)
	}

	if err := db.UpdateUserStatus(database, user.ID, status); err != nil {
		fmt.Fprintf(os.Stderr, "error updating status: %v\n", err)
		os.Exit(1)
	}

	action := "approved"
	if status == "rejected" {
		action = "rejected"
	}
	fmt.Printf("User %s has been %s.\n", email, action)
}

func printUserTable(users []db.User) {
	fmt.Printf("%-36s  %-30s  %-12s  %s\n", "ID", "EMAIL", "STATUS", "CREATED")
	fmt.Println(strings.Repeat("-", 100))
	for _, u := range users {
		created := time.Unix(u.CreatedAt, 0).UTC().Format("2006-01-02 15:04")
		fmt.Printf("%-36s  %-30s  %-12s  %s\n", u.ID, u.Email, u.Status, created)
	}
}

func printUsage() {
	fmt.Println("BestFin CLI - User Management")
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Println("  bestfin-cli pending          List users with pending approval")
	fmt.Println("  bestfin-cli list             List all users")
	fmt.Println("  bestfin-cli approve <email>  Approve a user")
	fmt.Println("  bestfin-cli reject <email>   Reject a user")
	fmt.Println()
	fmt.Println("Environment:")
	fmt.Println("  DATA_DIR  Path to data directory (default: ./data)")
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
