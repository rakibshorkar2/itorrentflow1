import SwiftUI
import Charts

// MARK: - Speed Graph View
/// Real-time download/upload speed chart using Swift Charts
public struct SpeedGraphView: View {
    @State private var dataPoints: [SpeedDataPoint] = []
    let downloadSpeed: Int64
    let uploadSpeed: Int64
    var maxDataPoints: Int = 60

    public init(downloadSpeed: Int64, uploadSpeed: Int64) {
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            HStack {
                Text("Network Speed")
                    .font(Theme.captionFont())
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                SpeedBadge(speed: downloadSpeed, isUpload: false)
                SpeedBadge(speed: uploadSpeed, isUpload: true)
            }

            Chart {
                ForEach(dataPoints) { point in
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        yStart: .value("Speed", 0),
                        yEnd: .value("DL Speed", point.downloadSpeed / 1024) // KiB/s
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.downloadColor.opacity(0.4), Theme.downloadColor.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("DL Speed", point.downloadSpeed / 1024)
                    )
                    .foregroundStyle(Theme.downloadColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", point.timestamp),
                        yStart: .value("Speed", 0),
                        yEnd: .value("UL Speed", point.uploadSpeed / 1024)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.uploadColor.opacity(0.3), Theme.uploadColor.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("UL Speed", point.uploadSpeed / 1024)
                    )
                    .foregroundStyle(Theme.uploadColor)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisValueLabel {
                        if let kb = value.as(Double.self) {
                            Text(formatKBps(kb))
                                .font(Theme.captionFont(size: 9))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Theme.divider)
                }
            }
            .chartBackground { _ in
                Theme.surface.opacity(0.0)
            }
            .frame(height: 80)
            .animation(.linear(duration: 0.3), value: dataPoints.count)
        }
        .onChange(of: downloadSpeed) { newVal in addDataPoint(dl: newVal, ul: uploadSpeed) }
        .onAppear {
            // Seed with zeros
            let now = Date()
            dataPoints = (0..<20).map { i in
                SpeedDataPoint(
                    timestamp: now.addingTimeInterval(Double(i - 20)),
                    downloadSpeed: 0,
                    uploadSpeed: 0
                )
            }
        }
    }

    private func addDataPoint(dl: Int64, ul: Int64) {
        let point = SpeedDataPoint(
            timestamp: Date(),
            downloadSpeed: Double(dl),
            uploadSpeed: Double(ul)
        )
        dataPoints.append(point)
        if dataPoints.count > maxDataPoints {
            dataPoints.removeFirst()
        }
    }

    private func formatKBps(_ kbps: Double) -> String {
        if kbps >= 1024 { return String(format: "%.0f MB/s", kbps / 1024) }
        return String(format: "%.0f KB/s", kbps)
    }
}
