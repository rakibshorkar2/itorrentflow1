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
