import Foundation
import CryptoKit

// MARK: - Piece Manager
/// Manages piece download state, SHA1 verification, and disk writes
public actor PieceManager {
    public let metadata: TorrentMetadata
    private let downloadDirectory: URL

    private var pieceStates: [PieceState]
    var downloadedBytes: Int64 = 0

    public init(metadata: TorrentMetadata, downloadDirectory: URL) throws {
        self.metadata = metadata
        self.downloadDirectory = downloadDirectory
        self.pieceStates = Array(
            repeating: PieceState(status: .missing, data: nil),
            count: metadata.pieces.count
        )
        try FileManager.default.createDirectory(
            at: downloadDirectory.appendingPathComponent(metadata.name),
            withIntermediateDirectories: true
        )
    }

    // MARK: - State
    public var progress: Double {
        let done = pieceStates.filter { $0.status == .verified }.count
        return metadata.pieces.isEmpty ? 0 : Double(done) / Double(metadata.pieces.count)
    }

    public var isComplete: Bool {
        pieceStates.allSatisfy { $0.status == .verified }
    }

    public var pieceStatusArray: [PieceStatus] {
        pieceStates.map { $0.status }
    }

    public var nextMissingPieceIndex: Int? {
        pieceStates.firstIndex { $0.status == .missing }
    }

    // MARK: - Receive piece data
    public func receivePiece(index: Int, begin: Int, data: Data) async throws {
        guard index < pieceStates.count else { return }
        guard pieceStates[index].status == .missing || pieceStates[index].status == .downloading else { return }

        // Accumulate piece data
        var pieceData = pieceStates[index].data ?? Data(
            count: pieceLength(for: index)
        )

        let range = begin..<(begin + data.count)
        guard range.upperBound <= pieceData.count else { return }
        pieceData.replaceSubrange(range, with: data)
        pieceStates[index] = PieceState(status: .downloading, data: pieceData)

        // Check if piece is fully downloaded
        if isFullPiece(index: index, data: pieceData) {
            try await verifyAndStore(index: index, data: pieceData)
        }
    }

    // MARK: - Verification
    private func verifyAndStore(index: Int, data: Data) async throws {
        let expected = metadata.pieces[index]
        let actual = Data(Insecure.SHA1.hash(data: data))

        guard actual == expected else {
            // Corrupt piece — re-download
            pieceStates[index] = PieceState(status: .missing, data: nil)
            throw PieceError.hashMismatch(index: index)
        }

        // Write to disk
        try await writePiece(index: index, data: data)
        pieceStates[index] = PieceState(status: .verified, data: nil) // Free memory
        downloadedBytes += Int64(data.count)
    }

    // MARK: - Disk Write
    private func writePiece(index: Int, data: Data) async throws {
        let pieceOffset = Int64(index) * Int64(metadata.pieceLength)
        var remaining = Int64(data.count)
        var dataOffset = Int64(0)

        for file in metadata.files {
            guard let fileRange = fileRange(for: file),
                  fileRange.overlaps(pieceOffset ..< pieceOffset + remaining) else { continue }

            let fileOffset = max(0, pieceOffset - fileRange.lowerBound)
            let writeOffset = max(0, fileRange.lowerBound - pieceOffset)
            let writeLen = min(
                remaining - writeOffset,
                fileRange.upperBound - pieceOffset - writeOffset
            )

            guard writeLen > 0 else { continue }

            let fileURL = downloadDirectory.appendingPathComponent(file.path)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let fh: FileHandle
            if FileManager.default.fileExists(atPath: fileURL.path) {
                fh = try FileHandle(forWritingTo: fileURL)
            } else {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
                fh = try FileHandle(forWritingTo: fileURL)
            }

            try fh.seek(toOffset: UInt64(fileOffset))
            let slice = data[Int(writeOffset) ..< Int(writeOffset + writeLen)]
            fh.write(Data(slice))
            try fh.close()
        }
    }

    // MARK: - Helpers
    private func pieceLength(for index: Int) -> Int {
        if index == metadata.pieces.count - 1 {
            let remainder = Int(metadata.totalSize) % metadata.pieceLength
            return remainder == 0 ? metadata.pieceLength : remainder
        }
        return metadata.pieceLength
    }

    private func isFullPiece(index: Int, data: Data) -> Bool {
        data.count >= pieceLength(for: index)
    }

    private func fileRange(for file: TorrentFileEntry) -> Range<Int64>? {
        var offset: Int64 = 0
        for f in metadata.files {
            if f.id == file.id {
                return offset ..< offset + file.length
            }
            offset += f.length
        }
        return nil
    }

    // MARK: - Mark piece as requested
    public func markPieceRequesting(_ index: Int) {
        guard index < pieceStates.count,
              pieceStates[index].status == .missing else { return }
        pieceStates[index] = PieceState(status: .downloading, data: nil)
    }
}

// MARK: - Piece State
public struct PieceState {
    var status: PieceStatus
    var data: Data?
}

public enum PieceStatus: Equatable {
    case missing
    case downloading
    case verified
}

// MARK: - Piece Error
public enum PieceError: Error, LocalizedError {
    case hashMismatch(index: Int)

    public var errorDescription: String? {
        if case .hashMismatch(let i) = self {
            return "Piece \(i) SHA1 hash mismatch — re-downloading"
        }
        return nil
    }
}
