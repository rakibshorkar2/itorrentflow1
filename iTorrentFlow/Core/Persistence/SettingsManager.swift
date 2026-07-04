import Foundation
import Combine

// MARK: - Settings Manager
public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()

    private let defaults = UserDefaults(suiteName: "group.com.itorrentflow.app") ?? .standard

    // MARK: - Download Settings
    @Published public var maxDownloadSpeed: Int = 0 {    // KiB/s, 0 = unlimited
        didSet { defaults.set(maxDownloadSpeed, forKey: "maxDownloadSpeed") }
    }
    @Published public var maxUploadSpeed: Int = 50 {     // KiB/s
        didSet { defaults.set(maxUploadSpeed, forKey: "maxUploadSpeed") }
    }
    @Published public var maxConnections: Int = 200 {
        didSet { defaults.set(maxConnections, forKey: "maxConnections") }
    }
    @Published public var maxActiveTorrents: Int = 5 {
        didSet { defaults.set(maxActiveTorrents, forKey: "maxActiveTorrents") }
    }

    // MARK: - Network Settings
    @Published public var enableDHT: Bool = true {
        didSet { defaults.set(enableDHT, forKey: "enableDHT") }
    }
    @Published public var enablePEX: Bool = true {
        didSet { defaults.set(enablePEX, forKey: "enablePEX") }
    }
    @Published public var enableLSD: Bool = true {
        didSet { defaults.set(enableLSD, forKey: "enableLSD") }
    }
    @Published public var enableUTP: Bool = true {
        didSet { defaults.set(enableUTP, forKey: "enableUTP") }
    }
    @Published public var listenPort: Int = 6881 {
        didSet { defaults.set(listenPort, forKey: "listenPort") }
    }

    // MARK: - UI Settings
    @Published public var defaultCategory: TorrentCategory = .general {
        didSet { defaults.set(defaultCategory.rawValue, forKey: "defaultCategory") }
    }
    @Published public var colorScheme: String = "dark" {
        didSet { defaults.set(colorScheme, forKey: "colorScheme") }
    }
    @Published public var sequentialDownload: Bool = false {
        didSet { defaults.set(sequentialDownload, forKey: "sequentialDownload") }
    }
    @Published public var startOnAdd: Bool = true {
        didSet { defaults.set(startOnAdd, forKey: "startOnAdd") }
    }
    @Published public var showDynamicIsland: Bool = true {
        didSet { defaults.set(showDynamicIsland, forKey: "showDynamicIsland") }
    }
    @Published public var autoAddTrackers: Bool = true {
        didSet { defaults.set(autoAddTrackers, forKey: "autoAddTrackers") }
    }

    // MARK: - Default Trackers
    @Published public var defaultTrackerURLs: [String] = DefaultTrackers.list {
        didSet { defaults.set(defaultTrackerURLs, forKey: "defaultTrackerURLs") }
    }

    // MARK: - Background
    @Published public var backgroundMode: BackgroundKeepAliveMode = .audio {
        didSet { defaults.set(backgroundMode.rawValue, forKey: "backgroundMode") }
    }

    // MARK: - Storage
    @Published public var downloadPath: String = "" {
        didSet { defaults.set(downloadPath, forKey: "downloadPath") }
    }

    private init() { load() }

    private func load() {
        maxDownloadSpeed = defaults.integer(forKey: "maxDownloadSpeed")
        maxUploadSpeed = defaults.object(forKey: "maxUploadSpeed") as? Int ?? 50
        maxConnections = defaults.object(forKey: "maxConnections") as? Int ?? 200
        maxActiveTorrents = defaults.object(forKey: "maxActiveTorrents") as? Int ?? 5
        enableDHT = defaults.object(forKey: "enableDHT") as? Bool ?? true
        enablePEX = defaults.object(forKey: "enablePEX") as? Bool ?? true
        enableLSD = defaults.object(forKey: "enableLSD") as? Bool ?? true
        enableUTP = defaults.object(forKey: "enableUTP") as? Bool ?? true
        listenPort = defaults.object(forKey: "listenPort") as? Int ?? 6881
        sequentialDownload = defaults.bool(forKey: "sequentialDownload")
        startOnAdd = defaults.object(forKey: "startOnAdd") as? Bool ?? true
        showDynamicIsland = defaults.object(forKey: "showDynamicIsland") as? Bool ?? true
        autoAddTrackers = defaults.object(forKey: "autoAddTrackers") as? Bool ?? true
        defaultTrackerURLs = defaults.stringArray(forKey: "defaultTrackerURLs") ?? DefaultTrackers.list
        if let raw = defaults.string(forKey: "backgroundMode"),
           let mode = BackgroundKeepAliveMode(rawValue: raw) {
            backgroundMode = mode
        }
        if let cat = defaults.string(forKey: "defaultCategory") {
            defaultCategory = TorrentCategory(rawValue: cat) ?? .general
        }
        colorScheme = defaults.string(forKey: "colorScheme") ?? "dark"
    }
}

// MARK: - Default Trackers
public enum DefaultTrackers {
    public static let list: [String] = [
        "udp://tracker.opentrackr.org:1337/announce",
        "udp://tracker.coppersurfer.tk:6969/announce",
        "udp://tracker.leechers-paradise.org:6969/announce",
        "udp://tracker.internetwarriors.net:1337/announce",
        "udp://tracker.zer0day.to:1337/announce",
        "udp://tracker.tiny-vps.com:6969/announce",
        "udp://tracker.pirateparty.ca:6969/announce",
        "udp://tracker.port443.xyz:6969/announce",
        "http://tracker3.itzmx.com:6961/announce",
        "udp://open.demonii.com:1337/announce",
        "udp://exodus.desync.com:6969/announce",
        "udp://tracker.torrent.eu.org:451/announce",
        "udp://retracker.lanta-net.ru:2710/announce",
        "udp://p4p.arenabg.com:1337/announce",
        "http://tracker1.itzmx.com:8080/announce",
        "udp://tracker.dler.org:6969/announce",
        "http://tracker.foreverpirates.co:80/announce",
        "udp://tracker.opentracker.eu:1337/announce"
    ]
}

// MARK: - Background Keep-Alive Mode
public enum BackgroundKeepAliveMode: String, CaseIterable {
    case audio = "Silent Audio"
    case location = "Location"
}
