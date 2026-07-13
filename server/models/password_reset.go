package models

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"time"

	"linkgame/server/db"
	"linkgame/server/times"
)

func CreateResetToken(userID int64) (string, error) {
	code := generateCode(6)
	expiresAt := times.Now().Add(10 * time.Minute).Format("2006-01-02 15:04:05")

	_, err := db.DB.Exec(
		"INSERT INTO password_resets (user_id, token, expires_at) VALUES (?, ?, ?)",
		userID, code, expiresAt,
	)
	if err != nil {
		return "", fmt.Errorf("insert reset token: %w", err)
	}
	return code, nil
}

func VerifyResetToken(userID int64, token string) bool {
	var id int64
	var expiresAt string
	var used int64

	err := db.DB.QueryRow(
		"SELECT id, expires_at, used FROM password_resets WHERE user_id = ? AND token = ? ORDER BY id DESC LIMIT 1",
		userID, token,
	).Scan(&id, &expiresAt, &used)

	if err != nil {
		return false
	}
	if used == 1 {
		return false
	}

	exp, err := time.Parse("2006-01-02 15:04:05", expiresAt)
	if err != nil {
		return false
	}
	if times.Now().After(exp) {
		return false
	}

	db.DB.Exec("UPDATE password_resets SET used = 1 WHERE id = ?", id)
	return true
}

func generateCode(length int) string {
	const chars = "0123456789"
	result := make([]byte, length)
	for i := range result {
		n, _ := rand.Int(rand.Reader, big.NewInt(int64(len(chars))))
		result[i] = chars[n.Int64()]
	}
	return string(result)
}
