package models

import (
	"fmt"

	"linkgame/server/db"
	"linkgame/server/times"
)

type CurrencyLog struct {
	ID        int64  `json:"id"`
	UserID    int64  `json:"user_id"`
	Amount    int64  `json:"amount"`
	Reason    string `json:"reason"`
	CreatedAt string `json:"created_at"`
}

func InsertCurrencyLog(userID, amount int64, reason string) error {
	_, err := db.DB.Exec(
		"INSERT INTO currency_logs (user_id, amount, reason, created_at) VALUES (?, ?, ?, ?)",
		userID, amount, reason, times.NowString(),
	)
	return err
}

func GetCurrencyLogs(userID int64, limit int) ([]CurrencyLog, error) {
	rows, err := db.DB.Query(
		"SELECT id, user_id, amount, reason, created_at FROM currency_logs WHERE user_id = ? ORDER BY id DESC LIMIT ?",
		userID, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("query currency logs: %w", err)
	}
	defer rows.Close()

	var logs []CurrencyLog
	for rows.Next() {
		var l CurrencyLog
		if err := rows.Scan(&l.ID, &l.UserID, &l.Amount, &l.Reason, &l.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan log: %w", err)
		}
		logs = append(logs, l)
	}
	if logs == nil {
		logs = []CurrencyLog{}
	}
	return logs, rows.Err()
}
