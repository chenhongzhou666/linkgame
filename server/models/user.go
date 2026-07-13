package models

import (
	"database/sql"
	"fmt"

	"linkgame/server/db"
	"linkgame/server/times"

	"golang.org/x/crypto/bcrypt"
)

type User struct {
	ID        int64  `json:"id"`
	Username  string `json:"username"`
	Nickname  string `json:"nickname"`
	Email     string `json:"email"`
	Avatar    string `json:"avatar"`
	Currency      int64 `json:"currency"`
	DailyUnlocked bool  `json:"daily_unlocked"`
	Password      string `json:"-"`
	CreatedAt string `json:"created_at"`
}

func CreateUser(username, email, password string) (*User, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}

	result, err := db.DB.Exec(
		"INSERT INTO users (username, email, password, created_at) VALUES (?, ?, ?, ?)",
		username, email, string(hash), times.NowString(),
	)
	if err != nil {
		return nil, fmt.Errorf("insert user: %w", err)
	}

	id, _ := result.LastInsertId()
	return &User{ID: id, Username: username, Email: email}, nil
}

func GetUserByUsername(username string) (*User, error) {
	u := &User{}
	err := db.DB.QueryRow(
		"SELECT id, username, COALESCE(email,''), COALESCE(nickname,''), COALESCE(avatar,''), COALESCE(currency,0), COALESCE(daily_unlocked,0), password, created_at FROM users WHERE username = ?",
		username,
	).Scan(&u.ID, &u.Username, &u.Email, &u.Nickname, &u.Avatar, &u.Currency, &u.DailyUnlocked, &u.Password, &u.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("query user: %w", err)
	}
	return u, nil
}

func GetUserByEmail(email string) (*User, error) {
	u := &User{}
	err := db.DB.QueryRow(
		"SELECT id, username, COALESCE(email,''), COALESCE(nickname,''), COALESCE(avatar,''), COALESCE(currency,0), COALESCE(daily_unlocked,0), password, created_at FROM users WHERE email = ?",
		email,
	).Scan(&u.ID, &u.Username, &u.Email, &u.Nickname, &u.Avatar, &u.Currency, &u.DailyUnlocked, &u.Password, &u.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("query user by email: %w", err)
	}
	return u, nil
}

func UpdatePassword(userID int64, newPassword string) error {
	hash, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("hash password: %w", err)
	}
	_, err = db.DB.Exec("UPDATE users SET password = ? WHERE id = ?", string(hash), userID)
	return err
}

func UpdateNickname(userID int64, nickname string) error {
	_, err := db.DB.Exec("UPDATE users SET nickname = ? WHERE id = ?", nickname, userID)
	return err
}

func UpdateAvatar(userID int64, avatar string) error {
	_, err := db.DB.Exec("UPDATE users SET avatar = ? WHERE id = ?", avatar, userID)
	return err
}

func UpdateEmail(userID int64, newEmail string) error {
	_, err := db.DB.Exec("UPDATE users SET email = ? WHERE id = ?", newEmail, userID)
	return err
}

func AddCurrency(userID int64, amount int64, reason string) (int64, error) {
	_, err := db.DB.Exec("UPDATE users SET currency = currency + ? WHERE id = ?", amount, userID)
	if err != nil {
		return 0, err
	}
	InsertCurrencyLog(userID, amount, reason)
	var total int64
	err = db.DB.QueryRow("SELECT COALESCE(currency,0) FROM users WHERE id = ?", userID).Scan(&total)
	return total, err
}

const DailyUnlockCost int64 = 5000

func UnlockDaily(userID int64) (int64, error) {
	var currency int64
	var already bool
	err := db.DB.QueryRow("SELECT COALESCE(currency,0), COALESCE(daily_unlocked,0) FROM users WHERE id = ?", userID).Scan(&currency, &already)
	if err != nil {
		return 0, err
	}
	if already {
		return currency, nil
	}
	if currency < DailyUnlockCost {
		return 0, fmt.Errorf("金币不足，需要 %d，当前 %d", DailyUnlockCost, currency)
	}
	_, err = db.DB.Exec("UPDATE users SET currency = currency - ?, daily_unlocked = 1 WHERE id = ?", DailyUnlockCost, userID)
	if err != nil {
		return 0, err
	}
	InsertCurrencyLog(userID, -DailyUnlockCost, "解锁每日挑战")
	return currency - DailyUnlockCost, nil
}

func (u *User) CheckPassword(password string) bool {
	return bcrypt.CompareHashAndPassword([]byte(u.Password), []byte(password)) == nil
}
