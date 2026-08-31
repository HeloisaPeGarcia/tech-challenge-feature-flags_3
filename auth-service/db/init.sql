CREATE TABLE IF NOT EXISTS api_keys (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    
    -- key_hash armazena o hash SHA-256 da chave, que tem 64 caracteres hexadecimais
    key_hash VARCHAR(64) NOT NULL UNIQUE, 
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Seed: chave de serviço interna usada pelo evaluation-service para chamar
-- flag-service e targeting-service. Valor da chave: 'temp-key'
-- SHA256('temp-key') = 1252d67715f013d2890664ec6486c91cc778393521d96071d530f28328c68c34
INSERT INTO api_keys (name, key_hash, is_active)
VALUES ('evaluation-service-internal', '1252d67715f013d2890664ec6486c91cc778393521d96071d530f28328c68c34', true)
ON CONFLICT (key_hash) DO NOTHING;