package config

import (
	"os"
	"fmt"

	"github.com/joho/godotenv"
)

func Config(key string) (string, error) {
	// load .env file
	err := godotenv.Load(".config")
	if err != nil {
		fmt.Print("Error loading .config file")
	}
	return os.Getenv(key), err
}