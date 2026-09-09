<#
.SYNOPSIS
    Automação de Configuração de CI/CD para iOS (Windows -> GitHub Actions -> App Store Connect)

.DESCRIPTION
    Este script auxilia desenvolvedores Windows a:
    1. Gerar Chave Privada RSA e CSR (Certificate Signing Request) usando OpenSSL.
    2. Converter o certificado Apple .cer baixado em um arquivo .p12 protegido.
    3. Converter e registrar automaticamente todos os GitHub Secrets necessários via GitHub CLI (`gh`).

.EXAMPLE
    .\setup-ios-appstore-cicd.ps1
#>

[CmdletBinding()]
param()

Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  🚀 iOS Windows CI/CD Setup: GitHub Actions -> App Store Connect" -ForegroundColor Yellow
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar OpenSSL
$opensslCmd = Get-Command openssl -ErrorAction SilentlyContinue
if (-not $opensslCmd) {
    Write-Host "❌ OpenSSL não foi encontrado no PATH!" -ForegroundColor Red
    Write-Host "💡 Dica: Instale o Git for Windows (que inclui OpenSSL) ou instale via winget: 'winget install ShiningLight.OpenSSL'" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ OpenSSL detectado: $($opensslCmd.Source)" -ForegroundColor Green

# 2. Verificar GitHub CLI
$ghCmd = Get-Command gh -ErrorAction SilentlyContinue
$hasGh = $false
if ($ghCmd) {
    Write-Host "✅ GitHub CLI (gh) detectado: $($ghCmd.Source)" -ForegroundColor Green
    $hasGh = $true
} else {
    Write-Host "⚠️ GitHub CLI (gh) não encontrado. As secrets serão geradas para cópia manual." -ForegroundColor Yellow
}

Write-Host ""
$outputDir = Join-Path $PSScriptRoot "apple_certificates_temp"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# 3. Gerar Chave RSA e CSR
Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host " 1. GERAÇÃO DE CHAVE PRIVADA & CSR (Certificate Signing Request)" -ForegroundColor Yellow
Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan

$email = Read-Host "Digite o seu e-mail Apple Developer"
$name = Read-Host "Digite o seu Nome Completo ou Razão Social"
$country = Read-Host "Digite o código do seu país (padrão: BR)"
if ([string]::IsNullOrWhiteSpace($country)) { $country = "BR" }

$privateKeyPath = Join-Path $outputDir "private_key.key"
$csrPath = Join-Path $outputDir "CertificateSigningRequest.certSigningRequest"

Write-Host "Gerando chave RSA 2048 bits..." -ForegroundColor Gray
openssl genrsa -out "$privateKeyPath" 2048

Write-Host "Gerando CSR..." -ForegroundColor Gray
openssl req -new -key "$privateKeyPath" -out "$csrPath" -subj "/emailAddress=$email, CN=$name, C=$country"

Write-Host ""
Write-Host "✅ Chave privada salva em: $privateKeyPath" -ForegroundColor Green
Write-Host "✅ CSR gerado com sucesso em: $csrPath" -ForegroundColor Green
Write-Host ""
Write-Host "👉 PASSO OBRIGATÓRIO NA APPLE:" -ForegroundColor Yellow
Write-Host "1. Acesse: https://developer.apple.com/account/resources/certificates/add"
Write-Host "2. Selecione 'Apple Distribution' e clique em Continue."
Write-Host "3. Faça upload do arquivo: $csrPath"
Write-Host "4. Baixe o certificado gerado ('distribution.cer') e salve nesta pasta: $outputDir"
Write-Host ""

$cerPath = Join-Path $outputDir "distribution.cer"
while (-not (Test-Path $cerPath)) {
    Read-Host "Pressione [ENTER] após salvar o arquivo 'distribution.cer' em: $outputDir"
}

# 4. Gerar .p12
Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host " 2. CRIAÇÃO DO CERTIFICADO .P12" -ForegroundColor Yellow
Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan

$p12Password = Read-Host "Digite uma senha forte para proteger seu arquivo .p12"
$pemPath = Join-Path $outputDir "distribution.pem"
$p12Path = Join-Path $outputDir "distribution.p12"

openssl x509 -in "$cerPath" -inform DER -out "$pemPath" -outform PEM
openssl pkcs12 -export -inkey "$privateKeyPath" -in "$pemPath" -out "$p12Path" -passout "pass:$p12Password"

Write-Host "✅ Certificado .p12 gerado com sucesso em: $p12Path" -ForegroundColor Green
Write-Host ""

# 5. Obter Provisioning Profile
Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host " 3. PERFIL DE PROVISIONAMENTO (.mobileprovision)" -ForegroundColor Yellow
Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "1. Acesse: https://developer.apple.com/account/resources/profiles/add"
Write-Host "2. Selecione 'App Store Connect' (Distribution)."
Write-Host "3. Selecione seu Bundle ID e o Certificado criado."
Write-Host "4. Baixe o perfil .mobileprovision e cole seu caminho completo abaixo."
Write-Host ""

$mobileProvisionPath = ""
while (-not (Test-Path $mobileProvisionPath -PathType Leaf)) {
    $mobileProvisionPath = Read-Host "Digite o caminho completo do seu arquivo .mobileprovision"
    $mobileProvisionPath = $mobileProvisionPath.Trim('"', "'")
}

# 6. Obter App Store Connect API Key
Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host " 4. CHAVE DE API APP STORE CONNECT" -ForegroundColor Yellow
Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Acesse: https://appstoreconnect.apple.com/access/integrations/api"
$keyId = Read-Host "Digite o Key ID (ex: AB12CD34EF)"
$issuerId = Read-Host "Digite o Issuer ID (ex: 12345678-1234-1234-1234-123456789012)"

$p8Path = ""
while (-not (Test-Path $p8Path -PathType Leaf)) {
    $p8Path = Read-Host "Digite o caminho completo do arquivo AuthKey_${keyId}.p8"
    $p8Path = $p8Path.Trim('"', "'")
}
$p8Content = Get-Content -Raw -Path $p8Path

# 7. Codificação em Base64
$p12Base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($p12Path))
$provisionBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($mobileProvisionPath))

# 8. Upload para GitHub Secrets
Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host " 5. REGISTRO DOS GITHUB SECRETS" -ForegroundColor Yellow
Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan

if ($hasGh) {
    $autoUpload = Read-Host "Deseja registrar todas as 6 Secrets automaticamente no repositório atual via GitHub CLI? (s/n)"
    if ($autoUpload -eq "s" -or $autoUpload -eq "S") {
        Write-Host "Enviando secrets..." -ForegroundColor Gray
        
        $p12Base64 | gh secret set P12_CERTIFICATE_BASE64
        $p12Password | gh secret set P12_PASSWORD
        $provisionBase64 | gh secret set PROVISIONING_PROFILE_BASE64
        $p8Content | gh secret set APP_STORE_CONNECT_PRIVATE_KEY
        $keyId | gh secret set APP_STORE_CONNECT_KEY_ID
        $issuerId | gh secret set APP_STORE_CONNECT_ISSUER_ID
        
        Write-Host "🎉 Todas as 6 Secrets foram registradas no GitHub com sucesso!" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "  ✨ CONFIGURAÇÃO CONCLUÍDA COM SUCESSO!" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "Basta agora fazer um 'git push' para a sua branch no GitHub." -ForegroundColor Cyan
Write-Host "O GitHub Actions cuidará da compilação limpa, assinatura e envio automático para a Apple!" -ForegroundColor Cyan
Write-Host ""
