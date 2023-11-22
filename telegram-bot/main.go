package main

import (
	"os"
	"log"
	"fmt"
	"fastiv-youth-bot/config"
	tgbotapi "github.com/go-telegram-bot-api/telegram-bot-api/v5"
)

func main() {
	token_name := "TELEGRAM_APITOKEN"
	token, err := config.Config(token_name)
	if err != nil {
		log.Printf("%s not found in .config", token_name)
	}
	token = os.Getenv(token_name)
	log.Printf("Token: %s", token)


	bot, err := tgbotapi.NewBotAPI(token)
	if err != nil {
		log.Panicf("Failed to create a session: %s", err)
	}
	bot.Debug = true
	

	log.Printf("Authorized on account %s", bot.Self.UserName)

	u := tgbotapi.NewUpdate(0)
	u.Timeout = 60
	updates := bot.GetUpdatesChan(u)

	for update := range updates {
		if update.Message == nil {
			continue
		}
		log.Printf("[%s] %s", update.Message.From.UserName, update.Message.Text)
		msg := tgbotapi.NewMessage(update.Message.Chat.ID, fmt.Sprintf("response: %s",update.Message.Text))
		_, err := bot.Send(msg)
		if err != nil {
			log.Println(err)
		}
	}
}