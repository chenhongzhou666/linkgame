package models

import (
	"database/sql"
	"fmt"

	"linkgame/server/db"
	"linkgame/server/times"
)

type DailyLevel struct {
	ID         int64  `json:"id"`
	Date       string `json:"date"`
	LayoutData string `json:"layout_data"`
}

func GetTodayLevel(date string) (*DailyLevel, error) {
	l := &DailyLevel{}
	err := db.DB.QueryRow(
		"SELECT id, date, layout_data FROM daily_levels WHERE date = ?",
		date,
	).Scan(&l.ID, &l.Date, &l.LayoutData)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("query daily level: %w", err)
	}
	return l, nil
}

func CreateDailyLevel(date, layoutData string) (*DailyLevel, error) {
	result, err := db.DB.Exec(
		"INSERT INTO daily_levels (date, layout_data, created_at) VALUES (?, ?, ?)",
		date, layoutData, times.NowString(),
	)
	if err != nil {
		return nil, fmt.Errorf("insert daily level: %w", err)
	}
	id, _ := result.LastInsertId()
	return &DailyLevel{ID: id, Date: date, LayoutData: layoutData}, nil
}

func UpdateDailyLevel(date, layoutData string) error {
	_, err := db.DB.Exec(
		"UPDATE daily_levels SET layout_data = ? WHERE date = ?",
		layoutData, date,
	)
	return err
}
