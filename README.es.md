<div align="center">

# 🍏 iOS Windows to App Store Connect CI/CD

**Compilación, Firma y Publicación 100% Automatizada de Apps iOS directamente desde Windows hacia App Store Connect vía GitHub Actions.**

<p align="center">
  <a href="README.md"><b>English 🇺🇸</b></a> •
  <a href="README.pt-BR.md"><b>Português 🇧🇷</b></a> •
  <a href="README.es.md"><b>Español 🇪🇸</b></a>
</p>

[![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-macOS--15-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/features/actions)
[![Xcode](https://img.shields.io/badge/Xcode-Latest_GA-147EFB?style=for-the-badge&logo=xcode&logoColor=white)](https://developer.apple.com/xcode/)
[![iOS](https://img.shields.io/badge/iOS-16.0+-000000?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

*Sin Mac físico. Sin Hackintosh. Sin costosos servicios de terceros.*

</div>

---

## 📖 Sobre el Proyecto

Desarrollar y publicar una aplicación para la **Apple App Store** desde una computadora **Windows** siempre ha sido un obstáculo importante para desarrolladores y empresas.

Este proyecto ofrece un **kit completo de automatización y plantilla de CI/CD** basado en **GitHub Actions** (utilizando runners oficiales `macos-15`), permitiendo a cualquier desarrollador en Windows:
1. Generar certificados y claves de firma de Apple (CSR, RSA 2048-bit, `.p12`) de forma nativa en Windows con OpenSSL.
2. Compilar binarios nativos Swift/iOS para dispositivos físicos (`arm64`).
3. Generar catálogos de recursos (`Assets.car`) e iconos 100% RGB sin canal alfa que cumplan estrictamente con las reglas de Apple.
4. Firmar digitalmente la aplicación con *Distribution Certificate* y *Provisioning Profile*.
5. Subir automáticamente el paquete `.ipa` a **App Store Connect / TestFlight** utilizando `xcrun altool`.

---

## 🏗️ Flujo y Arquitectura

```mermaid
flowchart TD
    subgraph Local [Entorno Windows Local]
        A[Desarrollador en Windows] -->|1. Ejecuta setup script| B[OpenSSL: Genera Clave RSA y CSR]
        B -->|2. Sube CSR| C[Apple Developer Portal]
        C -->|3. Descarga .cer y .mobileprovision| A
        A -->|4. Convierte a .p12 y Base64| D[GitHub CLI / Secrets]
    end

    subgraph CI_CD [GitHub Actions Cloud: Runner macOS-15]
        D -->|5. Git Push activa el Workflow| E[Runner macOS Inicializado]
        E -->|6. Detecta Dinámicamente Latest GA Xcode| F[Compilación arm64 Swift]
        F -->|7. Genera Iconos RGB y compila Assets.car| G[Inyecta Claves en Keychain]
        G -->|8. Codesign con Entitlements y .p12| H[Empaquetado del IPA]
        H -->|9. Sube vía xcrun altool con API Key| I[App Store Connect / TestFlight]
    end

    subgraph Apple [Ecosistema Apple]
        I -->|10. Procesamiento Automático| J[🟢 Enviado para Revisión / TestFlight]
    end
```

---

## 🚀 Inicio Rápido en 5 Minutos

### 1. Clonar o copiar este repositorio
Copia las carpetas `.github/workflows/build-ios-appstore.yml` y `scripts/` en el repositorio de tu proyecto.

### 2. Ejecutar el Asistente en Windows (PowerShell)
Abre PowerShell en la raíz del proyecto y ejecuta:

```powershell
.\scripts\setup-ios-appstore-cicd.ps1
```

El script interactivo se encargará de:
* Generar tu clave privada RSA y el archivo de solicitud `CertificateSigningRequest.certSigningRequest`.
* Guiar la descarga del certificado `distribution.cer` y perfil `.mobileprovision` en el portal de Apple.
* Exportar el certificado `.p12` protegido con contraseña.
* Codificar todo en Base64 y configurar automáticamente los 6 secretos en tu GitHub mediante `gh secret set`.

---

## 🔐 Secretos de GitHub Necesarios

Si prefieres configurarlos manualmente en **Settings > Secrets and variables > Actions**:

| Nombre del Secreto | Descripción | Cómo Obtenerlo en Windows |
|---|---|---|
| `P12_CERTIFICATE_BASE64` | Certificado de Distribución `.p12` en Base64 | `[Convert]::ToBase64String([IO.File]::ReadAllBytes("distribution.p12"))` |
| `P12_PASSWORD` | Contraseña definida al crear el archivo `.p12` | Texto plano de la contraseña |
| `PROVISIONING_PROFILE_BASE64` | Perfil de Aprovisionamiento `.mobileprovision` en Base64 | `[Convert]::ToBase64String([IO.File]::ReadAllBytes("TuApp.mobileprovision"))` |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Contenido de la clave de API (`AuthKey_XXXX.p8`) | Todo el texto incluyendo `-----BEGIN PRIVATE KEY-----` |
| `APP_STORE_CONNECT_KEY_ID` | Key ID de la API App Store Connect | Ej: `AB12CD34EF` (10 caracteres) |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID de la API App Store Connect | Ej: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` (UUID) |

---

## 📁 Estructura de Archivos Recomendada

```text
├── .github/
│   └── workflows/
│       └── build-ios-appstore.yml       # Workflow completo de CI/CD para macOS
├── ios/
│   └── TuApp/
│       ├── Info.plist                   # Metadatos de la App (CarPlay, Permisos, etc.)
│       ├── Package.swift                # Gestor de Paquetes Swift (o .xcodeproj)
│       ├── Resources/
│       │   └── client_launcher.png      # Imagen base de 1024x1024 para iconos
│       └── Sources/
│           └── App/
│               └── TuAppMain.swift      # Código fuente de la aplicación
└── scripts/
    ├── setup-ios-appstore-cicd.ps1      # Asistente de configuración (Windows PowerShell)
    └── setup-ios-appstore-cicd.sh       # Asistente de configuración (Linux / macOS / WSL)
```

---

## ⚙️ Características Clave del Workflow

- ✅ **Detección Dinámica de Xcode GA**: Localiza y selecciona automáticamente la versión más reciente y estable de Xcode instalada en el runner (`macos-15`), evitando errores de rechazo por versión beta de Apple.
- ✅ **Procesamiento Automático de Iconos**: Genera iconos en todas las resoluciones requeridas (120x120, 180x180, 152x152, 167x167, 1024x1024) con fondo RGB opaco (sin canal alfa) para cumplir las directrices de App Store.
- ✅ **Extracción Dinámica de Entitlements**: Decodifica el archivo `.mobileprovision` y extrae los permisos y entitlements oficiales antes de firmar.
- ✅ **Keychain Efímero y Seguro**: Crea y destruye un keychain temporal en el runner para importar el `.p12` y firmar con `codesign`.
- ✅ **Subida Directa por Terminal**: Emplea la herramienta oficial de línea de comandos `xcrun altool` autenticada mediante clave privada `.p8`.

---

## 📝 Lista de Verificación para App Store Connect

Antes de presionar **Añadir para Revisión (*Add for Review*)**:
- [ ] **Categoría Principal**: Definida en *Información de la App* (ej: Entretenimiento o Utilidades).
- [ ] **Derechos de Contenido**: Marcado como *No*.
- [ ] **Clasificación por Edad (Age Rating)**: Cuestionario completado.
- [ ] **Privacidad de la App**: Prácticas y datos declarados.
- [ ] **Exención de Cifrado**: Asegúrate de que `Info.plist` incluya `<key>ITSAppUsesNonExemptEncryption</key><false/>`.
- [ ] **Capturas de Pantalla**: Sube los tamaños obligatorios (6.5", 5.5" e iPad si corresponde).

---

## 🤝 Contribuciones

¡Las contribuciones son bienvenidas! Siéntete libre de abrir un **Issue** o enviar un **Pull Request**.

---

## 📄 Licencia

Distribuido bajo la licencia **MIT**. Consulta el archivo [LICENSE](LICENSE) para más información.
