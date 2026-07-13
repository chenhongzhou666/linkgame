package times

import "time"

var Beijing = time.FixedZone("CST", 8*3600)

func Now() time.Time {
	return time.Now().In(Beijing)
}

func NowString() string {
	return Now().Format("2006-01-02 15:04:05")
}
