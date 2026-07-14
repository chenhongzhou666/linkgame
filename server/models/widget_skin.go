package models

import (
	"encoding/json"
	"fmt"

	"linkgame/server/db"
)

// AddWidgetSkin adds a skin to user's purchased list (deduplicated)
func AddWidgetSkin(userID int64, skinID string) error {
	// Get current skins
	var currentJSON string
	err := db.DB.QueryRow("SELECT widget_skins FROM users WHERE id = ?", userID).Scan(&currentJSON)
	if err != nil {
		return fmt.Errorf("query widget skins: %w", err)
	}

	var skins []string
	if err := json.Unmarshal([]byte(currentJSON), &skins); err != nil {
		skins = []string{"default"}
	}

	// Check if already owned
	for _, s := range skins {
		if s == skinID {
			return nil // already owned, no-op
		}
	}

	skins = append(skins, skinID)
	newJSON, _ := json.Marshal(skins)
	_, err = db.DB.Exec("UPDATE users SET widget_skins = ? WHERE id = ?", string(newJSON), userID)
	return err
}

// GetWidgetSkins returns user's owned skin IDs
func GetWidgetSkins(userID int64) ([]string, error) {
	var currentJSON string
	err := db.DB.QueryRow("SELECT widget_skins FROM users WHERE id = ?", userID).Scan(&currentJSON)
	if err != nil {
		return []string{"default"}, nil
	}
	var skins []string
	if err := json.Unmarshal([]byte(currentJSON), &skins); err != nil {
		return []string{"default"}, nil
	}
	if skins == nil {
		skins = []string{"default"}
	}
	return skins, nil
}

// SetActiveSkinID sets the currently active skin for a user
func SetActiveSkinID(userID int64, skinID string) error {
	_, err := db.DB.Exec("UPDATE users SET active_skin_id = ? WHERE id = ?", skinID, userID)
	return err
}

// GetActiveSkinID returns the currently active skin ID
func GetActiveSkinID(userID int64) string {
	var skinID string
	err := db.DB.QueryRow("SELECT active_skin_id FROM users WHERE id = ?", userID).Scan(&skinID)
	if err != nil || skinID == "" {
		return "default"
	}
	return skinID
}

// Skin price lookup (mirrors client-side WidgetSkin definitions)
var skinPrices = map[string]int64{
	"default": 0,
	"neon":    3000,
	"pixel":   5000,
	"cat":     5000,
	"golden":  10000,
	"astro":   100,
}

// BuyWidgetSkin deducts currency and adds skin to user's collection
func BuyWidgetSkin(userID int64, skinID string) (int64, error) {
	// Validate skin exists
	price, ok := skinPrices[skinID]
	if !ok {
		return 0, fmt.Errorf("未知的皮肤: %s", skinID)
	}

	// Check if already owned
	owned, _ := GetWidgetSkins(userID)
	for _, s := range owned {
		if s == skinID {
			return 0, fmt.Errorf("你已经拥有该皮肤")
		}
	}

	// Check balance
	var currency int64
	err := db.DB.QueryRow("SELECT COALESCE(currency, 0) FROM users WHERE id = ?", userID).Scan(&currency)
	if err != nil {
		return 0, fmt.Errorf("查询余额失败: %w", err)
	}
	if currency < price {
		return 0, fmt.Errorf("金币不足，需要 %d，当前 %d", price, currency)
	}

	// Deduct and add skin
	_, err = db.DB.Exec("UPDATE users SET currency = currency - ? WHERE id = ?", price, userID)
	if err != nil {
		return 0, fmt.Errorf("扣款失败: %w", err)
	}

	if err := AddWidgetSkin(userID, skinID); err != nil {
		return 0, fmt.Errorf("添加皮肤失败: %w", err)
	}

	// Log the transaction
	InsertCurrencyLog(userID, -price, fmt.Sprintf("购买挂件皮肤: %s", skinID))

	return currency - price, nil
}
