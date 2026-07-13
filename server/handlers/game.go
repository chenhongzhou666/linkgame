package handlers

import (
	"encoding/json"
	"math/rand"
	"net/http"
	"strconv"

	"linkgame/server/middleware"
	"linkgame/server/models"
	"linkgame/server/times"
)

type ScoreRequest struct {
	LevelID     string `json:"level_id"`
	Score       int    `json:"score"`
	TimeSeconds int    `json:"time_seconds"`
}

type ScoreResponse struct {
	Score    *models.Score `json:"score,omitempty"`
	Error    string        `json:"error,omitempty"`
	Currency int64         `json:"currency,omitempty"`
	Rank     int           `json:"rank,omitempty"`
}

func SubmitScore(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	userID := r.Context().Value(middleware.UserIDKey).(int64)

	var req ScoreRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(ScoreResponse{Error: "invalid request body"})
		return
	}

	if req.LevelID == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(ScoreResponse{Error: "level_id is required"})
		return
	}
	if req.TimeSeconds < 1 {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(ScoreResponse{Error: "游玩时间不合理"})
		return
	}

	score, err := models.SubmitScore(userID, req.LevelID, req.Score, req.TimeSeconds)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(ScoreResponse{Error: "提交分数失败"})
		return
	}

	var currency int64
	if req.LevelID == "classic" {
		currency, _ = models.AddCurrency(userID, int64(req.Score), "经典模式得分")
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(ScoreResponse{Score: score, Currency: currency})
}

func GetLeaderboard(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	levelID := r.URL.Query().Get("level_id")
	limitStr := r.URL.Query().Get("limit")
	limit := 100
	if limitStr != "" {
		if n, err := strconv.Atoi(limitStr); err == nil && n > 0 && n <= 500 {
			limit = n
		}
	}

	entries, err := models.GetLeaderboard(levelID, limit)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "获取排行榜失败"})
		return
	}

	if entries == nil {
		entries = []models.LeaderboardEntry{}
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"leaderboard": entries,
		"level_id":    levelID,
	})
}

func GetDailyLevel(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	today := times.Now().Format("2006-01-02")

	level, err := models.GetTodayLevel(today)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "获取关卡失败"})
		return
	}

	if level == nil {
		layout := generateDailyLayout()
		level, err = models.CreateDailyLevel(today, layout)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]string{"error": "生成关卡失败"})
			return
		}
	} else {
		var testLayout [][]int
		if err := json.Unmarshal([]byte(level.LayoutData), &testLayout); err != nil {
			layout := generateDailyLayout()
			if err := models.UpdateDailyLevel(today, layout); err == nil {
				level.LayoutData = layout
			}
		}
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"date":        level.Date,
		"layout_data": level.LayoutData,
	})
}

func generateDailyLayout() string {
	rng := rand.New(rand.NewSource(times.Now().UnixNano()))
	rows, cols := 8, 12
	innerRows, innerCols := rows-2, cols-2
	totalCells := innerRows * innerCols

	pairs := totalCells / 2
	types := []int{}
	for i := 0; i < pairs; i++ {
		t := rng.Intn(20) + 1
		types = append(types, t, t)
	}

	rng.Shuffle(len(types), func(i, j int) {
		types[i], types[j] = types[j], types[i]
	})

	layout := make([][]int, rows)
	for i := range layout {
		layout[i] = make([]int, cols)
	}

	idx := 0
	for r := 1; r <= innerRows; r++ {
		for c := 1; c <= innerCols; c++ {
			layout[r][c] = types[idx]
			idx++
		}
	}

	data, _ := json.Marshal(layout)
	return string(data)
}

func GetMyStats(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	userID := r.Context().Value(middleware.UserIDKey).(int64)
	levelID := r.URL.Query().Get("level_id")

	totalGames, bestScore, avgTime, err := models.GetUserStats(userID, levelID)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "获取统计数据失败"})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"total_games": totalGames,
		"best_score":  bestScore,
		"avg_time":    avgTime,
	})
}

func GetMyHistory(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	userID := r.Context().Value(middleware.UserIDKey).(int64)
	levelID := r.URL.Query().Get("level_id")

	limitStr := r.URL.Query().Get("limit")
	limit := 100
	if limitStr != "" {
		if n, err := strconv.Atoi(limitStr); err == nil && n > 0 && n <= 200 {
			limit = n
		}
	}

	history, err := models.GetUserHistory(userID, levelID, limit)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "获取历史记录失败"})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"history": history,
	})
}
