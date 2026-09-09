<div align="center">

# 🍏 iOS Windows to App Store Connect CI/CD

**100% Automated iOS App Compilation, Signing, and App Store Connect Deployment directly from Windows via GitHub Actions.**

<p align="center">
  <a href="README.md"><b>English 🇺🇸</b></a> •
  <a href="README.pt-BR.md"><b>Português 🇧🇷</b></a> •
  <a href="README.es.md"><b>Español 🇪🇸</b></a>
</p>

[![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-macOS--15-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/features/actions)
[![Xcode](https://img.shields.io/badge/Xcode-Latest_GA-147EFB?style=for-the-badge&logo=xcode&logoColor=white)](https://developer.apple.com/xcode/)
[![iOS](https://img.shields.io/badge/iOS-16.0+-000000?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

*No physical Mac required. No Hackintosh. No expensive third-party subscription builders.*

</div>

---

## 📖 About The Project

Developing and publishing iOS applications to the **Apple App Store** from a **Windows machine** has historically been a significant bottleneck for independent developers and teams.

This project delivers a **production-ready CI/CD template and automation toolkit** powered by **GitHub Actions** (`macos-15` runners), allowing developers on Windows to:
1. Generate Apple signing keys (CSR, 2048-bit RSA, `.p12`) natively on Windows using OpenSSL.
2. Compile native Swift/iOS binaries for physical devices (`arm64`).
3. Generate App Store compliant RGB icon assets without alpha channels.
4. Codesign apps with official *Distribution Certificates* and *Provisioning Profiles*.
5. Upload `.ipa` packages directly to **App Store Connect / TestFlight** using `xcrun altool`.

---

## 🏗️ Architecture & Workflow

```mermaid
flowchart TD
    subgraph Local [Local Windows Environment]
        A[Windows Developer] -->|1. Run setup script| B[OpenSSL: Generate RSA & CSR]
        B -->|2. Upload CSR| C[Apple Developer Portal]
        C -->|3. Download .cer & .mobileprovision| A
        A -->|4. Export .p12 & Base64 encode| D[GitHub CLI / Secrets]
    end

    subgraph CI_CD [GitHub Actions Cloud: macOS-15 Runner]
        D -->|5. Git Push triggers Workflow| E[Initialize macOS Runner]
        E -->|6. Dynamically select latest GA Xcode| F[Swift / arm64 Compilation]
        F -->|7. Generate RGB icons & actool compile| G[Import .p12 into ephemeral keychain]
        G -->|8. Codesign with Entitlements| H[Package IPA]
        H -->|9. Upload via xcrun altool with API Key| I[App Store Connect / TestFlight]
    end

    subgraph Apple [Apple Ecosystem]
        I -->|10. Automated Ingestion & Processing| J[🟢 Ready for Review / TestFlight]
    end
```

---

## 🚀 Quick Start (5 Minutes)

### 1. Copy Files to Your Repository
Copy the `.github/workflows/build-ios-appstore.yml` and `scripts/` directories into your project repository.

### 2. Run the Interactive Windows PowerShell Wizard
Open PowerShell in your project root and execute:

```powershell
.\scripts\setup-ios-appstore-cicd.ps1
```

The script will:
* Generate your RSA private key and `CertificateSigningRequest.certSigningRequest`.
* Guide you to download the `distribution.cer` and `.mobileprovision` from Apple Developer Portal.
* Package the password-protected `.p12` certificate.
* Base64 encode everything and register all 6 required secrets into your GitHub repository via GitHub CLI (`gh`).

---

## 🔐 Required GitHub Secrets

If you prefer configuring secrets manually under **Settings > Secrets and variables > Actions**:

| Secret Name | Description | How to obtain on Windows |
|---|---|---|
| `P12_CERTIFICATE_BASE64` | Distribution `.p12` certificate encoded in Base64 | `[Convert]::ToBase64String([IO.File]::ReadAllBytes("distribution.p12"))` |
| `P12_PASSWORD` | Password set during `.p12` export | Plain text password |
| `PROVISIONING_PROFILE_BASE64` | `.mobileprovision` profile encoded in Base64 | `[Convert]::ToBase64String([IO.File]::ReadAllBytes("YourApp.mobileprovision"))` |
| `APP_STORE_CONNECT_PRIVATE_KEY` | App Store Connect API Key (`AuthKey_XXXX.p8`) | Full text including `-----BEGIN PRIVATE KEY-----` |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect Key ID | Ex: `AB12CD34EF` (10 characters) |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect Issuer ID | Ex: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` (UUID) |

---

## 📁 Repository Structure

```text
├── .github/
│   └── workflows/
│       └── build-ios-appstore.yml       # Production-ready CI/CD macOS workflow
├── ios/
│   └── YourApp/
│       ├── Info.plist                   # App Metadata (CarPlay, Permissions, etc.)
│       ├── Package.swift                # Swift Package (or .xcodeproj)
│       ├── Resources/
│       │   └── client_launcher.png      # 1024x1024 base icon asset
│       └── Sources/
│           └── App/
│               └── AppMain.swift        # Application source code
└── scripts/
    ├── setup-ios-appstore-cicd.ps1      # Interactive setup wizard (Windows PowerShell)
    └── setup-ios-appstore-cicd.sh       # Interactive setup wizard (Linux / macOS / WSL)
```

---

## ⚙️ Workflow Key Highlights

- ✅ **Dynamic GA Xcode Detection**: Automatically discovers and selects the latest General Availability (GA) Xcode release installed on the runner (`macos-15`), avoiding Apple beta rejection errors.
- ✅ **Automated Icon Processing**: Compiles 100% opaque RGB PNG icons (120x120, 180x180, 152x152, 167x167, 1024x1024) with zero alpha channels using Pillow to satisfy strict App Store validation.
- ✅ **Dynamic Entitlements Extraction**: Extracts clean XML entitlements directly from the `.mobileprovision` file before codesigning.
- ✅ **Ephemeral Secure Keychain**: Provisions and cleans up a temporary macOS keychain for secure codesigning.
- ✅ **Native Command-Line Upload**: Leverages official `xcrun altool` authenticated with `.p8` private keys without requiring GUI Transporter tools.

---

## 📝 App Store Connect Submission Checklist

Before clicking **Add for Review**:
- [ ] **Primary Category**: Configured in *App Information* (e.g., Entertainment / Utilities).
- [ ] **Content Rights**: Set to *No*.
- [ ] **Age Rating**: Completed questionnaire (e.g., 4+).
- [ ] **App Privacy**: Data practices declared.
- [ ] **Encryption Exemption**: Ensure `<key>ITSAppUsesNonExemptEncryption</key><false/>` is in `Info.plist`.
- [ ] **Screenshots**: Upload required 6.5", 5.5", and iPad displays.

---

## 🤝 Contributing

Contributions are warmly welcomed! Feel free to open an **Issue** or submit a **Pull Request**.

---

## 📄 License

Distributed under the **MIT License**. See [LICENSE](LICENSE) for details.
