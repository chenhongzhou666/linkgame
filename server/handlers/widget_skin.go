package handlers

import (
	"encoding/json"
	"net/http"

	"linkgame/server/middleware"
	"linkgame/server/models"
)

// GetWidgetSkins returns user's owned widget skins and active skin
func GetWidgetSkins(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	userID := r.Context().Value(middleware.UserIDKey).(int64)

	skins, err := models.GetWidgetSkins(userID)
	if err != nil {
		skins = []string{"default"}
	}
	activeID := models.GetActiveSkinID(userID)

	json.NewEncoder(w).Encode(map[string]interface{}{
		"skins":          skins,
		"active_skin_id": activeID,
	})
}

// BuyWidgetSkin deducts currency and adds skin
func BuyWidgetSkin(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	userID := r.Context().Value(middleware.UserIDKey).(int64)

	var req struct {
		SkinID string `json:"skin_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "无效请求"})
		return
	}

	if req.SkinID == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "请指定皮肤ID"})
		return
	}

	currency, err := models.BuyWidgetSkin(userID, req.SkinID)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":  "购买成功",
		"currency": currency,
		"skin_id":  req.SkinID,
	})
}

// SetActiveSkin updates the active skin for widget display
func SetActiveSkin(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	userID := r.Context().Value(middleware.UserIDKey).(int64)

	var req struct {
		SkinID string `json:"skin_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "无效请求"})
		return
	}

	if req.SkinID == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "请指定皮肤ID"})
		return
	}

	// Verify skin is owned
	owned, _ := models.GetWidgetSkins(userID)
	found := false
	for _, s := range owned {
		if s == req.SkinID {
			found = true
			break
		}
	}
	if !found {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "你未拥有该皮肤"})
		return
	}

	if err := models.SetActiveSkinID(userID, req.SkinID); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "设置失败"})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": "已切换皮肤",
		"skin_id": req.SkinID,
	})
}
