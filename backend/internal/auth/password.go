package auth

import "golang.org/x/crypto/bcrypt"

func HashPassword(password string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	return string(b), err
}

func CheckPassword(password, hash string) error {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
}

// dummyHash lets callers run a bcrypt comparison even when no user record
// exists, so the response time for "unknown email" matches "wrong password"
// and doesn't leak account existence.
var dummyHash = mustDummyHash()

func mustDummyHash() string {
	h, err := bcrypt.GenerateFromPassword([]byte("dummy-password-for-timing-safety"), bcrypt.DefaultCost)
	if err != nil {
		panic(err)
	}
	return string(h)
}
