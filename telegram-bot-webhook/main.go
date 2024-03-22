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


	bot_address, err := config.Config("BOT_ADDRESS")
	bot_port, err := config.Config("BOT_PORT")
	cert_path, err := config.Config("CERT_PATH")
	telegram_url, err := config.Config("TELEGRAM_URL")

	webhook, _ := tgbotapi.NewWebhookWithCert(fmt.Sprintf("https://%s:%s/%s", bot_address, bot_port, token), cert_path)
	_, err = bot.Request(webhook)
	if err != nil {
		log.Fatal(err)
	}

	info, err := bot.GetWebhookInfo()
	if err != nil {
		log.Fatal(err)
	}

	if info.LastErrorDate != 0 {
		log.Printf("Telegram callback failed: %s", info.LastErrorMessage)
	}

	updates := bot.ListenForWebhook("/" + bot.Token)
	go http.ListenAndServeTLS("0.0.0.0:8443", "cert.pem", "key.pem", nil)

	for update := range updates {
		if update.Message == nil {
			continue
		}
		log.Printf("[%s] %s", update.Message.From.UserName, update.Message.Text)
		msg := tgbotapi.NewMessage(update.Message.Chat.ID, fmt.Sprintf("Response:\n%s",update.Message.Text))
		_, err := bot.Send(msg)
		if err != nil {
			log.Println(err)
		}
	}
}