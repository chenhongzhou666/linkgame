package handlers

import (
	"fmt"
	"image"
	_ "image/jpeg"
	"image/png"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"linkgame/server/middleware"
	"linkgame/server/models"

	"golang.org/x/image/draw"
)

func getAvatarDir() string {
	home, _ := os.UserHomeDir()
	dir := filepath.Join(home, ".linkgame", "avatars")
	os.MkdirAll(dir, 0755)
	return dir
}

func UploadAvatarImage(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	userID := r.Context().Value(middleware.UserIDKey).(int64)

	r.Body = http.MaxBytesReader(w, r.Body, 2<<20)
	if err := r.ParseMultipartForm(2 << 20); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprintf(w, `{"error":"图片不能超过2MB"}`)
		return
	}

	file, _, err := r.FormFile("file")
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprintf(w, `{"error":"请选择图片文件"}`)
		return
	}
	defer file.Close()

	buf := make([]byte, 512)
	file.Read(buf)
	contentType := http.DetectContentType(buf)
	file.Seek(0, io.SeekStart)

	if !strings.HasPrefix(contentType, "image/") {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprintf(w, `{"error":"仅支持图片文件"}`)
		return
	}

	src, _, err := image.Decode(file)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprintf(w, `{"error":"无法解析图片"}`)
		return
	}

	bounds := src.Bounds()
	sw, sh := bounds.Dx(), bounds.Dy()
	size := sw
	if sh < sw {
		size = sh
	}
	cropX := (sw - size) / 2
	cropY := (sh - size) / 2
	cropped := src.(interface {
		SubImage(r image.Rectangle) image.Image
	}).SubImage(image.Rect(cropX, cropY, cropX+size, cropY+size))

	dst := image.NewRGBA(image.Rect(0, 0, 128, 128))
	draw.CatmullRom.Scale(dst, dst.Bounds(), cropped, cropped.Bounds(), draw.Over, nil)

	filename := fmt.Sprintf("img_%d.png", userID)
	savePath := filepath.Join(getAvatarDir(), filename)
	out, err := os.Create(savePath)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(w, `{"error":"保存图片失败"}`)
		return
	}
	defer out.Close()
	png.Encode(out, dst)

	avatarValue := "img:" + filename
	models.UpdateAvatar(userID, avatarValue)

	fmt.Fprintf(w, `{"message":"ok","avatar":"%s"}`, avatarValue)
}

func ServeAvatar(w http.ResponseWriter, r *http.Request) {
	filename := r.PathValue("filename")
	if filename == "" || strings.Contains(filename, "..") {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	filePath := filepath.Join(getAvatarDir(), filename)
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		w.WriteHeader(http.StatusNotFound)
		return
	}

	w.Header().Set("Cache-Control", "public, max-age=86400")
	http.ServeFile(w, r, filePath)
}
