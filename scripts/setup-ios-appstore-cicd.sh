#!/usr/bin/env bash
# ==============================================================================
# iOS CI/CD Setup Script (Bash / WSL / macOS / Linux)
# ==============================================================================

set -e

echo "======================================================================"
echo "  🚀 iOS CI/CD Setup: GitHub Actions -> App Store Connect"
echo "======================================================================"
echo ""

if ! command -v openssl &> /dev/null; then
    echo "❌ OpenSSL não foi encontrado no PATH!"
    exit 1
fi
echo "✅ OpenSSL detectado."

HAS_GH=false
if command -v gh &> /dev/null; then
    echo "✅ GitHub CLI (gh) detectado."
    HAS_GH=true
else
    echo "⚠️ GitHub CLI (gh) não encontrado."
fi

OUTPUT_DIR="scripts/apple_certificates_temp"
mkdir -p "$OUTPUT_DIR"

echo "----------------------------------------------------------------------"
echo " 1. GERAÇÃO DE CHAVE PRIVADA & CSR"
echo "----------------------------------------------------------------------"
read -p "Digite seu e-mail Apple Developer: " EMAIL
read -p "Digite seu Nome Completo ou Razão Social: " NAME
read -p "Digite o código do seu país (ex: BR): " COUNTRY
COUNTRY=${COUNTRY:-BR}

PRIVATE_KEY="$OUTPUT_DIR/private_key.key"
CSR_FILE="$OUTPUT_DIR/CertificateSigningRequest.certSigningRequest"

openssl genrsa -out "$PRIVATE_KEY" 2048
openssl req -new -key "$PRIVATE_KEY" -out "$CSR_FILE" -subj "/emailAddress=$EMAIL, CN=$NAME, C=$COUNTRY"

echo ""
echo "✅ Chave privada e CSR gerados em: $OUTPUT_DIR"
echo "👉 Acesse: https://developer.apple.com/account/resources/certificates/add"
echo "👉 Selecione 'Apple Distribution', suba o arquivo CSR e baixe 'distribution.cer'."
echo ""

CER_FILE="$OUTPUT_DIR/distribution.cer"
while [ ! -f "$CER_FILE" ]; do
    read -p "Pressione [ENTER] após salvar o arquivo 'distribution.cer' em $OUTPUT_DIR..."
done

echo "----------------------------------------------------------------------"
echo " 2. CRIAÇÃO DO CERTIFICADO .P12"
echo "----------------------------------------------------------------------"
read -s -p "Digite uma senha forte para proteger seu arquivo .p12: " P12_PASS
echo ""

PEM_FILE="$OUTPUT_DIR/distribution.pem"
P12_FILE="$OUTPUT_DIR/distribution.p12"

openssl x509 -in "$CER_FILE" -inform DER -out "$PEM_FILE" -outform PEM
openssl pkcs12 -export -inkey "$PRIVATE_KEY" -in "$PEM_FILE" -out "$P12_FILE" -passout "pass:$P12_PASS"

echo "✅ Certificado .p12 gerado com sucesso em: $P12_FILE"
echo ""

echo "----------------------------------------------------------------------"
echo " 3. PERFIL DE PROVISIONAMENTO (.mobileprovision)"
echo "----------------------------------------------------------------------"
read -p "Digite o caminho completo do seu arquivo .mobileprovision: " PROVISION_FILE

echo "----------------------------------------------------------------------"
echo " 4. CHAVE DE API APP STORE CONNECT"
echo "----------------------------------------------------------------------"
read -p "Digite o Key ID (ex: AB12CD34EF): " KEY_ID
read -p "Digite o Issuer ID (ex: 12345678-1234-1234-1234-123456789012): " ISSUER_ID
read -p "Digite o caminho completo do arquivo AuthKey_${KEY_ID}.p8: " P8_FILE

P12_B64=$(base64 < "$P12_FILE" | tr -d '\n')
PROVISION_B64=$(base64 < "$PROVISION_FILE" | tr -d '\n')
P8_CONTENT=$(cat "$P8_FILE")

if [ "$HAS_GH" = true ]; then
    read -p "Deseja registrar todas as 6 Secrets no GitHub agora via GitHub CLI? (s/n): " AUTO_UPLOAD
    if [ "$AUTO_UPLOAD" = "s" ] || [ "$AUTO_UPLOAD" = "S" ]; then
        echo "$P12_B64" | gh secret set P12_CERTIFICATE_BASE64
        echo "$P12_PASS" | gh secret set P12_PASSWORD
        echo "$PROVISION_B64" | gh secret set PROVISIONING_PROFILE_BASE64
        echo "$P8_CONTENT" | gh secret set APP_STORE_CONNECT_PRIVATE_KEY
        echo "$KEY_ID" | gh secret set APP_STORE_CONNECT_KEY_ID
        echo "$ISSUER_ID" | gh secret set APP_STORE_CONNECT_ISSUER_ID
        echo "🎉 Todas as Secrets foram salvas no GitHub com sucesso!"
    fi
fi

echo "======================================================================"
echo "  ✨ CONFIGURAÇÃO CONCLUÍDA COM SUCESSO!"
echo "======================================================================"
