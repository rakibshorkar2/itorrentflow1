iTorrent App - Complete Analysis & Development Guide
1. How iTorrent Works
Architecture Overview
iTorrent is a full-featured iOS BitTorrent client built with:
Layer	Technology
Language	Swift 100%
UI	UIKit (iOS) + SwiftUI (tvOS)
Architecture	MVVM with custom framework (MvvmFoundation)
Torrent Engine	LibTorrent (C++ library, wrapped via LibTorrent-Swift)
Reactive	Combine (@Published, subjects, publishers)
DI	Custom container with @Injected property wrapper
Background	Silent audio loop + Location updates
Sharing	GCDWebServer (HTTP + WebDAV)
Widget	WidgetKit + Live Activity (Dynamic Island)
Analytics	Firebase
End-to-End Download Flow
Magnet/URL/BitTorrent File
        │
        ▼
SceneDelegate (URL routing)
        │
        ▼
TorrentService (LibTorrent Session wrapper)
        │
        ▼
LibTorrent C++ Engine
   ├── DHT peer discovery
   ├── Tracker communication
   ├── Piece downloading
   ├── File assembly
   └── Seeding (upload)
        │
        ▼
BackgroundService (keeps alive via silent audio / location)
        │
        ▼
LiveActivityService (Dynamic Island progress updates)
        │
        ▼
WebDAV/HTTP Server (file access on local network)
Key Features
 1. Magnet link support - opens magnet:// URLs directly
 2. RSS feed reader - browse/search RSS feeds for torrents
 3. File priority selection - choose which files to download
 4. Background downloading - two modes: silent audio + location
 5. Live Activity / Dynamic Island - real-time progress with pause button
 6. WebDAV server - access files over WiFi from any device
 7. In-app video player (AVKit on iOS, VLCKit on tvOS)
 8. Storage scopes - manage storage across external drives
 9. Auto-tracker management - auto-add trackers from lists
10. Proxy support - SOCKS4/5, HTTP proxy for connections
2. Guide: Building a Similar App with AI Agents
Step-by-Step Workflow
Phase 1: Planning (AI-Assisted)
1. Describe the app concept to AI
   "Build me an iOS torrent client with these features: ..."
   
2. AI generates project structure and architecture
   
3. AI selects appropriate libraries (LibTorrent-Swift, etc.)
Phase 2: Code Generation
Use AI agents (Claude, Cursor, Copilot) to:

1. Generate MVVM base classes
2. Write torrent service wrapper
3. Create UI screens (UIKit or SwiftUI)
4. Implement background services
5. Build the networking layer
6. Add settings/preferences storage
Phase 3: Iteration
- Paste errors → AI fixes
- Request features → AI implements
- Refactor code → AI suggests improvements
- Write tests → AI generates
Phase 4: Build & Test
- GitHub Actions CI/CD (see Section 3)
- Xcode for local testing
- TestFlight for beta distribution
Recommended AI Tools
Tool	Purpose
Cursor	Full IDE with AI code generation
Claude Code (opencode)	CLI-based AI coding assistant
GitHub Copilot	Inline code completion
ChatGPT	Architecture planning, debugging
Critical Components AI Must Help With
1. LibTorrent integration - The C++ bridge is the hardest part
2. Background mode configuration - Silent audio + location setup
3. Entitlements - Network, file access, location, background modes
4. Info.plist - URL schemes, document types, background modes
5. Live Activity - ActivityKit + AppIntents for Dynamic Island
6. App Groups - Shared data between app and extensions
3. Building on Windows & Unsigned IPA with GitHub Actions
Can You Build This on Windows?
Directly: NO. iOS builds require macOS + Xcode.
Workarounds:
Method	Feasibility	Notes
GitHub Actions (macOS runner)	YES (Recommended)	Uses macos-15 runner, free for public repos
CrossCode (Windows IDE)	Partial	Can build with SPM, but no UIKit/SwiftUI support yet
xtool (Linux/Windows)	Partial	SwiftPM builds, but missing Apple frameworks
Hackintosh VM	Risky	Legally questionable, unstable for modern Xcode
Cloud Mac (MacStadium, etc.)	YES	$20-50/month, full Xcode access
Cross-platform (Flutter/RN)	Different app	Would be a different codebase entirely
Unsigned IPA via GitHub Actions
Yes, there are templates that do exactly this:
# .github/workflows/build-unsigned.yml
name: Build Unsigned IPA

on: push

jobs:
  build:
    runs-on: macos-15  # GitHub's macOS runner
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app

      - name: Build (unsigned)
        run: |
          xcodebuild build \
            -project iTorrent.xcodeproj \
            -scheme iTorrent \
            -destination 'generic/platform=iOS' \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGN_ENTITLEMENTS=""

      - name: Package IPA (unsigned)
        run: |
          mkdir -p Payload
          cp -r build/Release-iphoneos/iTorrent.app Payload/
          zip -r iTorrent-unsigned.ipa Payload
          rm -rf Payload

      - name: Upload IPA
        uses: actions/upload-artifact@v4
        with:
          name: iTorrent-unsigned
          path: iTorrent-unsigned.ipa
Existing iTorrent CI/CD
The project already has ios-release.yml that:
- Builds with submodules (LibTorrent, MVVMFoundation, GCDWebServer)
- Installs Boost via Homebrew (required by LibTorrent)
- Runs LibTorrent-Swift/make.sh to compile the C++ engine
- Signs with imported certificates
- Exports IPA
- Creates GitHub release + AltStore JSON + TestFlight upload
For Unsigned Builds Specifically
Use the unsign-ipa-make template approach:
1. Fork your repo
2. Add the workflow
3. Push → GitHub Actions builds an unsigned IPA
4. Download from Artifacts tab
Caveat: Unsigned IPAs only work on jailbroken devices or via signing services like AltStore/Sideloadly.
Summary
Question	Answer
How does iTorrent work?	MVVM app wrapping LibTorrent C++ engine with Combine + UIKit
Can you build it with AI?	Yes - AI can generate 80-90% of the code, but you need to understand iOS development fundamentals
Build on Windows?	Not directly - use GitHub Actions macOS runners or cloud Mac services
Unsigned IPA via GitHub Actions?	Yes - set CODE_SIGNING_ALLOWED=NO and package the .app into a zip
App Store submission?	Needs paid Apple Developer account ($99/yr) + code signing