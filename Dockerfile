FROM golang:1.21.4 as build
# COPY configs.toml /go/bin/
WORKDIR /telegram-bot
COPY telegram-bot .
RUN go mod download && go build -o /telegram-bot .

FROM golang:1.21.4
WORKDIR /telegram-bot
COPY --from=build telegram-bot .
#COPY .env .

ENTRYPOINT ["./telegram-bot"]
EXPOSE 8080
