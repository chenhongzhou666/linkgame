package models

import (
	"database/sql"
	"fmt"

	"linkgame/server/db"
	"linkgame/server/times"
)

type Score struct {
	ID          int64  `json:"id"`
	UserID      int64  `json:"user_id"`
	Username    string `json:"username,omitempty"`
	LevelID     string `json:"level_id"`
	Score       int    `json:"score"`
	TimeSeconds int    `json:"time_seconds"`
	Week        string `json:"week"`
	CreatedAt   string `json:"created_at"`
}

func GetCurrentWeek() string {
	now := times.Now()
	year, week := now.ISOWeek()
	return fmt.Sprintf("%d-W%02d", year, week)
}

func SubmitScore(userID int64, levelID string, score, timeSeconds int) (*Score, error) {
	week := GetCurrentWeek()
	result, err := db.DB.Exec(
		"INSERT INTO scores (user_id, level_id, score, time_seconds, week, created_at) VALUES (?, ?, ?, ?, ?, ?)",
		userID, levelID, score, timeSeconds, week, times.NowString(),
	)
	if err != nil {
		return nil, fmt.Errorf("insert score: %w", err)
	}
	id, _ := result.LastInsertId()
	return &Score{ID: id, UserID: userID, LevelID: levelID, Score: score, TimeSeconds: timeSeconds, Week: week}, nil
}

type LeaderboardEntry struct {
	Rank        int    `json:"rank"`
	Username    string `json:"username"`
	Avatar      string `json:"avatar"`
	Score       int    `json:"score"`
	TimeSeconds int    `json:"time_seconds"`
	CreatedAt   string `json:"created_at"`
}

func GetLeaderboard(levelID string, limit int) ([]LeaderboardEntry, error) {
	week := GetCurrentWeek()
	return getLeaderboardByWeek(levelID, week, limit)
}

func getLeaderboardByWeek(levelID, week string, limit int) ([]LeaderboardEntry, error) {
	var rows *sql.Rows
	var err error

	if levelID != "" {
		rows, err = db.DB.Query(
			`SELECT u.username, COALESCE(u.avatar,''), s.score, s.time_seconds, s.created_at
			 FROM scores s JOIN users u ON s.user_id = u.id
			 WHERE s.level_id = ? AND s.week = ?
			 ORDER BY s.score DESC, s.time_seconds ASC
			 LIMIT ?`, levelID, week, limit,
		)
	} else {
		rows, err = db.DB.Query(
			`SELECT u.username, COALESCE(u.avatar,''), s.score, s.time_seconds, s.created_at
			 FROM scores s JOIN users u ON s.user_id = u.id
			 WHERE s.week = ?
			 ORDER BY s.score DESC, s.time_seconds ASC
			 LIMIT ?`, week, limit,
		)
	}
	if err != nil {
		return nil, fmt.Errorf("query leaderboard: %w", err)
	}
	defer rows.Close()

	var entries []LeaderboardEntry
	for i := 0; rows.Next(); i++ {
		var e LeaderboardEntry
		if err := rows.Scan(&e.Username, &e.Avatar, &e.Score, &e.TimeSeconds, &e.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan row: %w", err)
		}
		e.Rank = i + 1
		entries = append(entries, e)
	}
	if entries == nil {
		entries = []LeaderboardEntry{}
	}
	return entries, rows.Err()
}

func GetUserHistory(userID int64, levelID string, limit int) ([]Score, error) {
	var rows *sql.Rows
	var err error
	if levelID != "" {
		rows, err = db.DB.Query(
			"SELECT id, user_id, level_id, score, time_seconds, COALESCE(week,''), created_at FROM scores WHERE user_id = ? AND level_id = ? ORDER BY created_at DESC LIMIT ?",
			userID, levelID, limit,
		)
	} else {
		rows, err = db.DB.Query(
			"SELECT id, user_id, level_id, score, time_seconds, COALESCE(week,''), created_at FROM scores WHERE user_id = ? ORDER BY created_at DESC LIMIT ?",
			userID, limit,
		)
	}
	if err != nil {
		return nil, fmt.Errorf("query history: %w", err)
	}
	if err != nil {
		return nil, fmt.Errorf("query history: %w", err)
	}
	defer rows.Close()

	var history []Score
	for rows.Next() {
		var s Score
		if err := rows.Scan(&s.ID, &s.UserID, &s.LevelID, &s.Score, &s.TimeSeconds, &s.Week, &s.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan history: %w", err)
		}
		history = append(history, s)
	}
	if history == nil {
		history = []Score{}
	}
	return history, rows.Err()
}

func GetUserStats(userID int64, levelID string) (totalGames int, bestScore int, avgTime float64, err error) {
	if levelID != "" {
		err = db.DB.QueryRow(
			"SELECT COUNT(*), COALESCE(MAX(score), 0), COALESCE(AVG(time_seconds), 0) FROM scores WHERE user_id = ? AND level_id = ?",
			userID, levelID,
		).Scan(&totalGames, &bestScore, &avgTime)
	} else {
		err = db.DB.QueryRow(
			"SELECT COUNT(*), COALESCE(MAX(score), 0), COALESCE(AVG(time_seconds), 0) FROM scores WHERE user_id = ?",
			userID,
		).Scan(&totalGames, &bestScore, &avgTime)
	}
	return
}
