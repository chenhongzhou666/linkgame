package main

import (
	"log"
	"net/http"
	"os"
	"path/filepath"

	"linkgame/server/db"
	"linkgame/server/email"
	"linkgame/server/handlers"
	"linkgame/server/middleware"
)

func main() {
	os.Setenv("TZ", "Asia/Shanghai")

	homeDir, _ := os.UserHomeDir()
	dbPath := filepath.Join(homeDir, ".linkgame", "data.db")

	log.Printf("初始化数据库: %s", dbPath)
	if err := db.Init(dbPath); err != nil {
		log.Fatalf("数据库初始化失败: %v", err)
	}
	defer db.Close()

	email.Init()

	mux := http.NewServeMux()

	mux.HandleFunc("GET /api/health", handlers.Health)

	mux.HandleFunc("POST /api/register", handlers.Register)
	mux.HandleFunc("POST /api/login", handlers.Login)
	mux.HandleFunc("POST /api/forgot-password", handlers.ForgotPassword)
	mux.HandleFunc("POST /api/reset-password", handlers.ResetPassword)
	mux.HandleFunc("POST /api/bind-email", middleware.Auth(handlers.BindEmail))
	mux.HandleFunc("POST /api/me/nickname", middleware.Auth(handlers.UpdateNickname))
	mux.HandleFunc("POST /api/me/daily-unlock", middleware.Auth(handlers.UnlockDaily))
	mux.HandleFunc("GET /api/me/currency-logs", middleware.Auth(handlers.GetCurrencyLogs))
	mux.HandleFunc("POST /api/me/avatar/upload", middleware.Auth(handlers.UploadAvatarImage))
	mux.HandleFunc("GET /api/avatars/{filename}", handlers.ServeAvatar)

	mux.HandleFunc("POST /api/score", middleware.Auth(handlers.SubmitScore))
	mux.HandleFunc("GET /api/leaderboard", handlers.GetLeaderboard)
	mux.HandleFunc("GET /api/daily", handlers.GetDailyLevel)
	mux.HandleFunc("GET /api/my/stats", middleware.Auth(handlers.GetMyStats))
	mux.HandleFunc("GET /api/my/history", middleware.Auth(handlers.GetMyHistory))
	mux.HandleFunc("GET /api/me/widget-skins", middleware.Auth(handlers.GetWidgetSkins))
	mux.HandleFunc("POST /api/me/widget-skins/buy", middleware.Auth(handlers.BuyWidgetSkin))
	mux.HandleFunc("POST /api/me/widget-skins/activate", middleware.Auth(handlers.SetActiveSkin))

	mux.HandleFunc("GET /api/battle/online", handlers.BattleOnline)
	mux.HandleFunc("POST /api/battle/join", middleware.Auth(handlers.BattleJoin))
	mux.HandleFunc("GET /api/battle/status", middleware.Auth(handlers.BattleStatus))
	mux.HandleFunc("POST /api/battle/invite", middleware.Auth(handlers.BattleInvite))
	mux.HandleFunc("POST /api/battle/respond", middleware.Auth(handlers.BattleRespond))
	mux.HandleFunc("POST /api/battle/match", middleware.Auth(handlers.BattleMatch))
	mux.HandleFunc("POST /api/battle/leave", middleware.Auth(handlers.BattleLeave))

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotFound)
		w.Write([]byte(`{"error":"not found"}`))
	})

	addr := ":9090"
	log.Printf("泓泓看服务器启动，监听 %s", addr)

	handler := logMiddleware(mux)
	if err := http.ListenAndServe(addr, handler); err != nil {
		log.Fatalf("服务器启动失败: %v", err)
	}
}

func logMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("→ %s %s", r.Method, r.URL.RequestURI())
		lrw := &logResponseWriter{ResponseWriter: w}
		next.ServeHTTP(lrw, r)
		log.Printf("← %s %s → %d", r.Method, r.URL.Path, lrw.status)
	})
}

type logResponseWriter struct {
	http.ResponseWriter
	status int
}

func (l *logResponseWriter) WriteHeader(code int) {
	l.status = code
	l.ResponseWriter.WriteHeader(code)
}
