package handlers

import (
	"encoding/json"
	"io"
	"log"
	"net/http"
	"regexp"
	"strings"
	"unicode/utf8"

	"linkgame/server/email"
	"linkgame/server/middleware"
	"linkgame/server/models"
)

type RegisterRequest struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

type AuthResponse struct {
	Token string       `json:"token"`
	User  *models.User `json:"user"`
	Error string       `json:"error,omitempty"`
}

var emailRegex = regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)

func Register(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	var req RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Error: "invalid request body"})
		return
	}

	req.Username = strings.TrimSpace(req.Username)
	req.Email = strings.TrimSpace(req.Email)

	if len(req.Username) < 2 || len(req.Username) > 20 {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Error: "用户名需 2-20 个字符"})
		return
	}
	if !emailRegex.MatchString(req.Email) {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Error: "请输入有效的邮箱地址"})
		return
	}
	if len(req.Password) < 6 {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Error: "密码需要至少 6 位"})
		return
	}

	existing, err := models.GetUserByUsername(req.Username)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(AuthResponse{Error: "服务器错误"})
		return
	}
	if existing != nil {
		w.WriteHeader(http.StatusConflict)
		json.NewEncoder(w).Encode(AuthResponse{Error: "用户名已被注册"})
		return
	}

	existing, err = models.GetUserByEmail(req.Email)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(AuthResponse{Error: "服务器错误"})
		return
	}
	if existing != nil {
		w.WriteHeader(http.StatusConflict)
		json.NewEncoder(w).Encode(AuthResponse{Error: "邮箱已被注册"})
		return
	}

	user, err := models.CreateUser(req.Username, req.Email, req.Password)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(AuthResponse{Error: "注册失败，请重试"})
		return
	}

	token, err := middleware.GenerateToken(user.ID)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(AuthResponse{Error: "生成 token 失败"})
		return
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(AuthResponse{Token: token, User: user})
}

func Login(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	var req RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Error: "invalid request body"})
		return
	}

	user, err := models.GetUserByUsername(req.Username)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(AuthResponse{Error: "服务器错误"})
		return
	}
	if user == nil || !user.CheckPassword(req.Password) {
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(AuthResponse{Error: "用户名或密码错误"})
		return
	}

	token, err := middleware.GenerateToken(user.ID)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(AuthResponse{Error: "生成 token 失败"})
		return
	}

	json.NewEncoder(w).Encode(AuthResponse{Token: token, User: user})
}

type ForgotRequest struct {
	Email string `json:"email"`
}

func ForgotPassword(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	var req ForgotRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "invalid request body"})
		return
	}

	req.Email = strings.TrimSpace(req.Email)
	if !emailRegex.MatchString(req.Email) {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "请输入有效的邮箱地址"})
		return
	}

	user, err := models.GetUserByEmail(req.Email)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "服务器错误"})
		return
	}
	if user == nil {
		json.NewEncoder(w).Encode(map[string]string{"message": "如果该邮箱已注册，验证码已发送"})
		return
	}

	code, err := models.CreateResetToken(user.ID)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "生成验证码失败"})
		return
	}

	if err := email.SendResetCode(user.Email, code); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "发送邮件失败，请稍后重试"})
		return
	}

	json.NewEncoder(w).Encode(map[string]string{"message": "验证码已发送到您的邮箱"})
}

type ResetRequest struct {
	Email       string `json:"email"`
	Code        string `json:"code"`
	NewPassword string `json:"new_password"`
}

func ResetPassword(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	var req ResetRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "invalid request body"})
		return
	}

	if len(req.NewPassword) < 6 {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "新密码需要至少 6 位"})
		return
	}

	user, err := models.GetUserByEmail(req.Email)
	if err != nil || user == nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "邮箱未注册"})
		return
	}

	if !models.VerifyResetToken(user.ID, req.Code) {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "验证码错误或已过期"})
		return
	}

	if err := models.UpdatePassword(user.ID, req.NewPassword); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "重置密码失败"})
		return
	}

	json.NewEncoder(w).Encode(map[string]string{"message": "密码重置成功"})
}

type BindEmailRequest struct {
	Email string `json:"email"`
}

func BindEmail(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	userID := r.Context().Value(middleware.UserIDKey).(int64)

	var req BindEmailRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "invalid request body"})
		return
	}

	req.Email = strings.TrimSpace(req.Email)
	if !emailRegex.MatchString(req.Email) {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "请输入有效的邮箱地址"})
		return
	}

	existing, err := models.GetUserByEmail(req.Email)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "服务器错误"})
		return
	}
	if existing != nil && existing.ID != userID {
		w.WriteHeader(http.StatusConflict)
		json.NewEncoder(w).Encode(map[string]string{"error": "该邮箱已被其他账号绑定"})
		return
	}

	if err := models.UpdateEmail(userID, req.Email); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "绑定失败"})
		return
	}

	json.NewEncoder(w).Encode(map[string]string{"message": "邮箱绑定成功"})
}

func UnlockDaily(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	userID := r.Context().Value(middleware.UserIDKey).(int64)

	currency, err := models.UnlockDaily(userID)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":       "解锁成功",
		"currency":      currency,
		"dailyUnlocked": true,
	})
}

func GetCurrencyLogs(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	userID := r.Context().Value(middleware.UserIDKey).(int64)

	logs, err := models.GetCurrencyLogs(userID, 50)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "获取流水失败"})
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"logs": logs,
	})
}

type NicknameRequest struct {
	Nickname string `json:"nickname"`
}

func UpdateNickname(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	userID := r.Context().Value(middleware.UserIDKey).(int64)

	body, _ := io.ReadAll(r.Body)
	log.Printf("UpdateNickname body: %s", string(body))
	r.Body = io.NopCloser(strings.NewReader(string(body)))

	var req NicknameRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "invalid request body"})
		return
	}

	log.Printf("UpdateNickname decoded: '%s'", req.Nickname)

	req.Nickname = strings.TrimSpace(req.Nickname)
	if utf8.RuneCountInString(req.Nickname) < 2 || utf8.RuneCountInString(req.Nickname) > 12 {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "昵称需 2-12 个字符"})
		return
	}

	if err := models.UpdateNickname(userID, req.Nickname); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "更新昵称失败"})
		return
	}

	json.NewEncoder(w).Encode(map[string]string{"message": "ok"})
}
