package handlers

import (
	"encoding/json"
	"log"
	"math/rand"
	"net/http"
	"strconv"
	"sync"
	"time"

	"linkgame/server/middleware"
	"linkgame/server/models"
)

const (
	battleRows     = 12
	battleCols     = 12
	battleTypes    = 20
	maxHP          = 100
	damagePerMatch = 2
	idleTimeout    = 60 * time.Second
	sessionTimeout = 30 * time.Second
)

// ============================================================
// 数据结构
// ============================================================

type BattleSession struct {
	UserID   int64
	Username string
	Avatar   string
	Trophies int
	LastSeen time.Time
	// 当前游戏
	GameID  string
	IsReady bool
	// 待处理事件
	Events []BattleEvent
	mu     sync.Mutex
}

type BattleEvent struct {
	Type string      `json:"type"`
	Data interface{} `json:"data,omitempty"`
}

type BattleGame struct {
	RoomID    string
	PlayerA   int64
	PlayerB   int64
	BoardA    [][]int
	BoardB    [][]int
	HPA       int
	HPB       int
	Finished  bool
	StartTime time.Time
	LastMoveA time.Time
	LastMoveB time.Time
	mu        sync.Mutex
}

// ============================================================
// 全局状态
// ============================================================

var (
	sessions  = map[int64]*BattleSession{}
	games     = map[string]*BattleGame{}
	globalMu  sync.Mutex
)

func getSession(r *http.Request) (*BattleSession, int64, bool) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	globalMu.Lock()
	s, ok := sessions[userID]
	globalMu.Unlock()
	return s, userID, ok
}

func getUserInfo(userID int64) (string, string, int) {
	u, err := models.GetUserByID(userID)
	if err != nil || u == nil {
		return "unknown", "", 0
	}
	n := u.Username
	if u.Nickname != "" {
		n = u.Nickname
	}
	return n, u.Avatar, u.Trophies
}

// ============================================================
// GET /api/battle/online — 在线玩家列表
// ============================================================

func BattleOnline(w http.ResponseWriter, r *http.Request) {
	globalMu.Lock()
	players := []map[string]interface{}{}
	for id, s := range sessions {
		players = append(players, map[string]interface{}{
			"user_id": id, "username": s.Username, "trophies": s.Trophies,
		})
	}
	globalMu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"count": len(players), "players": players,
	})
}

// ============================================================
// POST /api/battle/join — 进入大厅
// ============================================================

func BattleJoin(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(middleware.UserIDKey).(int64)
	name, avatar, trophies := getUserInfo(userID)

	globalMu.Lock()
	if old, exists := sessions[userID]; exists {
		// 清理旧会话中的游戏
		if old.GameID != "" {
			if g, ok := games[old.GameID]; ok {
				g.mu.Lock()
				g.Finished = true
				g.mu.Unlock()
				delete(games, old.GameID)
			}
		}
	}
	sessions[userID] = &BattleSession{
		UserID: userID, Username: name, Avatar: avatar, Trophies: trophies,
		LastSeen: time.Now(), Events: []BattleEvent{},
	}
	globalMu.Unlock()

	log.Printf("Battle: %s joined lobby", name)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status": "ok", "my_name": name,
	})
}

// ============================================================
// GET /api/battle/status — 轮询状态
// ============================================================

func BattleStatus(w http.ResponseWriter, r *http.Request) {
	s, userID, ok := getSession(r)
	if !ok {
		http.Error(w, `{"status":"not_joined"}`, http.StatusBadRequest)
		return
	}

	s.mu.Lock()
	s.LastSeen = time.Now()
	events := s.Events
	s.Events = nil
	s.mu.Unlock()

	// 检查游戏状态
	result := map[string]interface{}{
		"status": "lobby",
	}
	if s.GameID != "" {
		globalMu.Lock()
		g, gameExists := games[s.GameID]
		globalMu.Unlock()
		if gameExists {
			g.mu.Lock()
			if g.Finished {
				g.mu.Unlock()
				var outcome, myHP, oppHP, trophies interface{}
				if g.HPA <= 0 && g.HPB <= 0 {
					outcome = "draw"
				} else if (userID == g.PlayerA && g.HPB <= 0) || (userID == g.PlayerB && g.HPA <= 0) {
					outcome = "win"
					t, _ := models.AddTrophy(userID)
					trophies = t
				} else {
					outcome = "lose"
				}
				if userID == g.PlayerA {
					myHP = g.HPA; oppHP = g.HPB
				} else {
					myHP = g.HPB; oppHP = g.HPA
				}
				result["status"] = "game_over"
				result["outcome"] = outcome
				result["my_hp"] = myHP
				result["opponent_hp"] = oppHP
				if trophies != nil { result["trophies"] = trophies }

				delete(games, s.GameID)
				s.GameID = ""
			} else {
				// 游戏进行中
				if userID == g.PlayerA {
					result["my_hp"] = g.HPA
					result["opponent_hp"] = g.HPB
				} else {
					result["my_hp"] = g.HPB
					result["opponent_hp"] = g.HPA
				}
				result["status"] = "playing"
				g.mu.Unlock()
			}
		} else {
			s.GameID = ""
		}
	}

	if len(events) > 0 {
		result["events"] = events
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

// ============================================================
// POST /api/battle/invite — 邀请玩家
// ============================================================

func BattleInvite(w http.ResponseWriter, r *http.Request) {
	s, _, ok := getSession(r)
	if !ok {
		http.Error(w, `{"error":"请先进入大厅"}`, http.StatusBadRequest)
		return
	}

	var req struct{ ToUserID int64 `json:"to_user_id"` }
	if json.NewDecoder(r.Body).Decode(&req) != nil || req.ToUserID == 0 {
		http.Error(w, `{"error":"invalid request"}`, http.StatusBadRequest)
		return
	}

	globalMu.Lock()
	target, exists := sessions[req.ToUserID]
	globalMu.Unlock()

	if !exists {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"error": "对方不在线"})
		return
	}

	targetName, _, targetTrophies := getUserInfo(req.ToUserID)

	target.mu.Lock()
	target.Events = append(target.Events, BattleEvent{
		Type: "invite_received",
		Data: map[string]interface{}{
			"from_user_id": s.UserID, "from_username": s.Username, "from_trophies": s.Trophies,
		},
	})
	target.mu.Unlock()

	log.Printf("Battle: %s invited %s", s.Username, targetName)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status": "ok", "invited": targetName,
	})
	_ = targetTrophies
}

// ============================================================
// POST /api/battle/respond — 接受/拒绝邀请
// ============================================================

func BattleRespond(w http.ResponseWriter, r *http.Request) {
	s, _, ok := getSession(r)
	if !ok {
		http.Error(w, `{"error":"请先进入大厅"}`, http.StatusBadRequest)
		return
	}

	var req struct {
		FromUserID int64 `json:"from_user_id"`
		Accept     bool  `json:"accept"`
	}
	if json.NewDecoder(r.Body).Decode(&req) != nil {
		http.Error(w, `{"error":"invalid request"}`, http.StatusBadRequest)
		return
	}

	globalMu.Lock()
	inviter, exists := sessions[req.FromUserID]
	globalMu.Unlock()

	if !exists || !req.Accept {
		if exists {
			inviter.mu.Lock()
			inviter.Events = append(inviter.Events, BattleEvent{
				Type: "invite_declined",
				Data: map[string]interface{}{"from_username": s.Username},
			})
			inviter.mu.Unlock()
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "declined"})
		return
	}

	// 创建游戏
	roomID := "game_" + strconv.FormatInt(time.Now().UnixNano(), 36)
	boardA := genBoard()
	boardB := copy2D(boardA)

	game := &BattleGame{
		RoomID: roomID, PlayerA: req.FromUserID, PlayerB: s.UserID,
		BoardA: boardA, BoardB: boardB, HPA: maxHP, HPB: maxHP,
		StartTime: time.Now(), LastMoveA: time.Now(), LastMoveB: time.Now(),
	}

	globalMu.Lock()
	games[roomID] = game
	inviter.GameID = roomID
	s.GameID = roomID
	globalMu.Unlock()

	// 通知双方
	oppA, _, _ := getUserInfo(s.UserID)
	oppB, _, _ := getUserInfo(req.FromUserID)

	inviter.mu.Lock()
	inviter.Events = append(inviter.Events, BattleEvent{
		Type: "game_start",
		Data: map[string]interface{}{
			"board": boardA, "hp": maxHP, "opponent_name": oppA,
		},
	})
	inviter.mu.Unlock()

	s.mu.Lock()
	s.Events = append(s.Events, BattleEvent{
		Type: "game_start",
		Data: map[string]interface{}{
			"board": boardB, "hp": maxHP, "opponent_name": oppB,
		},
	})
	s.mu.Unlock()

	log.Printf("Battle game %s: %d vs %d", roomID, req.FromUserID, s.UserID)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "accepted"})
}

// ============================================================
// POST /api/battle/match — 提交匹配
// ============================================================

func BattleMatch(w http.ResponseWriter, r *http.Request) {
	s, userID, ok := getSession(r)
	if !ok || s.GameID == "" {
		http.Error(w, `{"error":"不在游戏中"}`, http.StatusBadRequest)
		return
	}

	var req struct {
		Row1, Col1, Row2, Col2 int
	}
	if json.NewDecoder(r.Body).Decode(&req) != nil {
		http.Error(w, `{"error":"invalid"}`, http.StatusBadRequest)
		return
	}

	globalMu.Lock()
	g, exists := games[s.GameID]
	globalMu.Unlock()
	if !exists {
		http.Error(w, `{"error":"游戏不存在"}`, http.StatusBadRequest)
		return
	}

	g.mu.Lock()
	defer g.mu.Unlock()
	if g.Finished {
		http.Error(w, `{"error":"游戏已结束"}`, http.StatusBadRequest)
		return
	}

	var board [][]int
	var isA bool
	var opponentID int64
	if userID == g.PlayerA {
		board = g.BoardA; isA = true; opponentID = g.PlayerB
	} else {
		board = g.BoardB; isA = false; opponentID = g.PlayerA
	}

	if !findBattlePath(board, req.Row1, req.Col1, req.Row2, req.Col2) {
		json.NewEncoder(w).Encode(map[string]interface{}{"valid": false})
		return
	}

	board[req.Row1][req.Col1] = 0
	board[req.Row2][req.Col2] = 0

	var myHP, oppHP int
	if isA {
		g.HPB -= damagePerMatch
		if g.HPB < 0 { g.HPB = 0 }
		myHP = g.HPA; oppHP = g.HPB
		g.LastMoveA = time.Now()
	} else {
		g.HPA -= damagePerMatch
		if g.HPA < 0 { g.HPA = 0 }
		myHP = g.HPB; oppHP = g.HPA
		g.LastMoveB = time.Now()
	}

	// 通知对手
	globalMu.Lock()
	if opp, exists := sessions[opponentID]; exists {
		opp.mu.Lock()
		opp.Events = append(opp.Events, BattleEvent{
			Type: "hit",
			Data: map[string]interface{}{"my_hp": oppHP, "opponent_hp": myHP},
		})
		opp.mu.Unlock()
	}
	globalMu.Unlock()

	// 检查胜负
	gameOver := false
	if oppHP <= 0 {
		gameOver = true
	} else if boardEmpty(board) {
		gameOver = true
	}

	if gameOver {
		g.Finished = true
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"valid": true, "my_hp": myHP, "opponent_hp": oppHP,
		"game_over": gameOver,
	})
}

// ============================================================
// POST /api/battle/leave — 离开大厅
// ============================================================

func BattleLeave(w http.ResponseWriter, r *http.Request) {
	s, userID, ok := getSession(r)
	if !ok {
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
		return
	}

	// 清理游戏
	if s.GameID != "" {
		globalMu.Lock()
		if g, exists := games[s.GameID]; exists {
			g.mu.Lock()
			g.Finished = true
			g.mu.Unlock()
			delete(games, s.GameID)

			// 通知对手
			oppID := g.PlayerA
			if oppID == userID { oppID = g.PlayerB }
			if opp, exists := sessions[oppID]; exists {
				opp.mu.Lock()
				opp.Events = append(opp.Events, BattleEvent{
					Type: "opponent_left",
				})
				opp.mu.Unlock()
			}
		}
		globalMu.Unlock()
	}

	globalMu.Lock()
	delete(sessions, userID)
	globalMu.Unlock()

	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

// ============================================================
// 棋盘生成 + BFS
// ============================================================

func genBoard() [][]int {
	ir, ic := battleRows-2, battleCols-2
	tiles := make([]int, 0, ir*ic)
	for i := 0; i < ir*ic/2; i++ {
		t := (i % battleTypes) + 1
		tiles = append(tiles, t, t)
	}
	rand.Shuffle(len(tiles), func(i, j int) { tiles[i], tiles[j] = tiles[j], tiles[i] })

	b := make([][]int, battleRows)
	for r := 0; r < battleRows; r++ { b[r] = make([]int, battleCols) }
	idx := 0
	for r := 1; r <= ir; r++ {
		for c := 1; c <= ic; c++ {
			b[r][c] = tiles[idx]; idx++
		}
	}
	return b
}

func copy2D(src [][]int) [][]int {
	dst := make([][]int, len(src))
	for i := range src {
		dst[i] = make([]int, len(src[i]))
		copy(dst[i], src[i])
	}
	return dst
}

var dirs = [4][2]int{{-1, 0}, {0, 1}, {1, 0}, {0, -1}}

func findBattlePath(board [][]int, r1, c1, r2, c2 int) bool {
	rows, cols := len(board), len(board[0])
	if r1 == r2 && c1 == c2 { return false }
	if r1 < 0 || r1 >= rows || c1 < 0 || c1 >= cols { return false }
	if r2 < 0 || r2 >= rows || c2 < 0 || c2 >= cols { return false }
	if board[r1][c1] == 0 || board[r2][c2] == 0 || board[r1][c1] != board[r2][c2] { return false }

	type st struct{ r, c, d, t int }
	vis := map[st]bool{}
	var q []st
	for d := 0; d < 4; d++ {
		nr, nc := r1+dirs[d][0], c1+dirs[d][1]
		if nr < 0 || nr >= rows || nc < 0 || nc >= cols { continue }
		if nr == r2 && nc == c2 { return true }
		if board[nr][nc] == 0 {
			s := st{nr, nc, d, 0}
			if !vis[s] { vis[s] = true; q = append(q, s) }
		}
	}
	for len(q) > 0 {
		c := q[0]; q = q[1:]
		for d := 0; d < 4; d++ {
			nr, nc := c.r+dirs[d][0], c.c+dirs[d][1]
			if nr < 0 || nr >= rows || nc < 0 || nc >= cols { continue }
			t := c.t; if d != c.d { t++ }
			if t > 2 { continue }
			if nr == r2 && nc == c2 { return true }
			if board[nr][nc] == 0 {
				s := st{nr, nc, d, t}
				if !vis[s] { vis[s] = true; q = append(q, s) }
			}
		}
	}
	return false
}

func boardEmpty(b [][]int) bool {
	for r := range b {
		for c := range b[r] {
			if b[r][c] != 0 { return false }
		}
	}
	return true
}
