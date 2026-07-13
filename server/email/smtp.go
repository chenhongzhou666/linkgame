package email

import (
	"fmt"
	"net/smtp"
	"os"
)

type Config struct {
	SMTPHost string
	SMTPPort string
	From     string
	Password string
}

var cfg Config

func Init() {
	cfg = Config{
		SMTPHost: "smtp.qq.com",
		SMTPPort: "587",
		From:     "2199975163@qq.com",
		Password: os.Getenv("QQ_MAIL_AUTH_CODE"),
	}
}

func SendResetCode(to, code string) error {
	subject := "泓泓看 - 密码重置验证码"
	body := fmt.Sprintf(`
<html>
<body style="font-family: sans-serif; max-width: 480px; margin: 0 auto;">
  <h2 style="color: #6c5ce7;">🔐 泓泓看 · 密码重置</h2>
  <p>你的验证码是：</p>
  <div style="background: #f0edff; padding: 16px; border-radius: 8px; text-align: center; margin: 16px 0;">
    <span style="font-size: 28px; font-weight: bold; letter-spacing: 6px; color: #6c5ce7;">%s</span>
  </div>
  <p style="color: #888; font-size: 12px;">验证码 10 分钟内有效，请勿转发给他人。</p>
</body>
</html>`, code)

	msg := fmt.Sprintf("From: 泓泓看 <%s>\r\n"+
		"To: %s\r\n"+
		"Subject: %s\r\n"+
		"MIME-Version: 1.0\r\n"+
		"Content-Type: text/html; charset=UTF-8\r\n"+
		"\r\n%s", cfg.From, to, subject, body)

	auth := smtp.PlainAuth("", cfg.From, cfg.Password, cfg.SMTPHost)
	addr := fmt.Sprintf("%s:%s", cfg.SMTPHost, cfg.SMTPPort)

	return smtp.SendMail(addr, auth, cfg.From, []string{to}, []byte(msg))
}
