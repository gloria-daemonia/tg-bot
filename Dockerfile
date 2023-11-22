FROM golang:1.21.4 as build
# COPY configs.toml /go/bin/
WORKDIR /telegram-bot
COPY telegram-bot .
RUN go mod download -json && go build -o fastiv-bot

FROM golang:1.21.4
WORKDIR /telegram-bot
COPY --from=build /telegram-bot/fastiv-bot .
#COPY .env .

ENTRYPOINT ["./fastiv-bot"]
#EXPOSE 8080
