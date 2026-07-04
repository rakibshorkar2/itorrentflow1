# iTorrentFlow 🌊

> A powerful, native iOS torrent client with Dynamic Island live activities, background downloading, and a modern SwiftUI interface.

![iOS 16+](https://img.shields.io/badge/iOS-16%2B-blue?style=flat-square&logo=apple)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)
![Build IPA](https://github.com/OWNER/iTorrentFlow/actions/workflows/build-ipa.yml/badge.svg)

---

## Features

| Feature | Details |
|---|---|
| 🧲 Magnet Links | Full magnet URI support with deep-link handler |
| 📁 .torrent Files | Import via Files app or share sheet |
| 🔔 Dynamic Island | Live Activity with real-time speed & progress ring |
| ⬇️ Background Download | Continues downloading when app is minimized |
| 🔍 Torrent Search | Built-in search via public torrent APIs |
| 📊 Speed Graph | Real-time Swift Charts download/upload graph |
| 🗂 File Browser | Browse and share completed files |
| 🌐 DHT / PEX / LSD | Trackerless torrent support |
| ⚡ Bandwidth Control | Upload/download rate limiting |
| 🧩 Piece Visualizer | Custom canvas piece download visualization |
| 🔐 Sequential Download | Watch while downloading |
| 👥 Peer Map | MapKit peer geolocation view |

---

## Building

### Prerequisites
- macOS 13+ with Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- GitHub Actions (automated builds)

### Local Build
```bash
git clone https://github.com/OWNER/iTorrentFlow
cd iTorrentFlow
brew install xcodegen
xcodegen generate
open iTorrentFlow.xcodeproj
```

### CI — Unsigned IPA
Every push to `main` triggers the GitHub Actions workflow which produces an **unsigned IPA** as a downloadable artifact.

---

## Sideloading

Download the `iTorrentFlow.ipa` from GitHub Actions artifacts, then install using:

- **[AltStore](https://altstore.io)** — Free, renews every 7 days
- **[Sideloadly](https://sideloadly.io)** — Simple drag & drop
- **[TrollStore](https://github.com/opa334/TrollStore)** — Permanent install (jailbreak-free on supported firmware)

---

## Architecture

```
iTorrentFlow/
├── App/                  # Entry point, AppDelegate
├── Core/
│   ├── Engine/           # BitTorrent protocol (Bencode, DHT, Peers, Pieces)
│   ├── Models/           # Data models
│   ├── Persistence/      # SwiftData store
│   └── Network/          # Torrent search providers
├── Features/             # SwiftUI feature modules
├── LiveActivity/         # ActivityKit Dynamic Island
└── UI/                   # Design system, components
```

---

## License

MIT — see [LICENSE](LICENSE)
