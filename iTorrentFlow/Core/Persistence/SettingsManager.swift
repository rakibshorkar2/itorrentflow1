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
        if let cat = defaults.string(forKey: "defaultCategory") {
            defaultCategory = TorrentCategory(rawValue: cat) ?? .general
        }
        colorScheme = defaults.string(forKey: "colorScheme") ?? "dark"
    }
}
