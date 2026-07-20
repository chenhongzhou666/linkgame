package db

import (
	"database/sql"
	_ "embed"
	"fmt"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite"
)

//go:embed migrations/001_init.sql
var initSQL string

//go:embed migrations/002_email_reset.sql
var migration2SQL string

//go:embed migrations/003_avatar.sql
var migration3SQL string

//go:embed migrations/004_nickname.sql
var migration4SQL string

//go:embed migrations/005_week.sql
var migration5SQL string

//go:embed migrations/006_currency.sql
var migration6SQL string

//go:embed migrations/007_daily_unlock.sql
var migration7SQL string

//go:embed migrations/008_currency_log.sql
var migration8SQL string

//go:embed migrations/010_battle_trophies.sql
var migration10SQL string

var DB *sql.DB

func Init(dbPath string) error {
	dir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("create db dir: %w", err)
	}

	var err error
	DB, err = sql.Open("sqlite", dbPath)
	if err != nil {
		return fmt.Errorf("open db: %w", err)
	}

	DB.SetMaxOpenConns(1)

	if _, err := DB.Exec(initSQL); err != nil {
		return fmt.Errorf("run migration 001: %w", err)
	}

	// migration 002 — 忽略 ALTER TABLE 重复执行错误
	DB.Exec(migration2SQL)
	// migration 003 — avatar field
	DB.Exec(migration3SQL)
	// migration 004 — nickname field
	DB.Exec(migration4SQL)
	// migration 005 — week field for scores
	DB.Exec(migration5SQL)
	// migration 006 — currency for users
	DB.Exec(migration6SQL)
	// migration 007 — daily_unlock for users
	DB.Exec(migration7SQL)
	// migration 008 — currency transaction logs
	DB.Exec(migration8SQL)
	// migration 010 — trophies for battle system
	DB.Exec(migration10SQL)

	return nil
}

func Close() {
	if DB != nil {
		DB.Close()
	}
}
