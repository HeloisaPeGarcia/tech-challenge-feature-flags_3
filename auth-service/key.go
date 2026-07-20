package main

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
)

// Gera uma chave aleatória
func generateAPIKey() (string, error) {
	bytes := make([]byte, 32)

	_, err := rand.Read(bytes)
	if err != nil {
		return "", err
	}

	return "tm_key_" + hex.EncodeToString(bytes), nil
}

// Cria hash SHA256 da chave
func hashAPIKey(apiKey string) string {
	hash := sha256.Sum256([]byte(apiKey))
	return hex.EncodeToString(hash[:])
}
