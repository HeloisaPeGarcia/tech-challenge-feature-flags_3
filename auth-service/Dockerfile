FROM golang:1.24 AS builder

WORKDIR /app

COPY . .

RUN go mod tidy
RUN go build -o auth-service .

FROM debian:stable-slim

WORKDIR /app

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/auth-service .

EXPOSE 8001

CMD ["./auth-service"]
