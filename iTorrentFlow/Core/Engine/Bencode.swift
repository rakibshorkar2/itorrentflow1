import Foundation

// MARK: - Bencode Parser & Serializer
/// Full implementation of the BitTorrent bencode encoding format
public enum BencodeValue {
    case string(Data)
    case integer(Int64)
    case list([BencodeValue])
    case dictionary([String: BencodeValue])

    // MARK: - String convenience
    var stringValue: String? {
        if case .string(let d) = self { return String(data: d, encoding: .utf8) }
        return nil
    }

    var intValue: Int64? {
        if case .integer(let i) = self { return i }
        return nil
    }

    var listValue: [BencodeValue]? {
        if case .list(let l) = self { return l }
        return nil
    }

    var dictValue: [String: BencodeValue]? {
        if case .dictionary(let d) = self { return d }
        return nil
    }

    subscript(key: String) -> BencodeValue? {
        return dictValue?[key]
    }
}

// MARK: - Decoder
public struct BencodeDecoder {
    private var data: [UInt8]
    private var position: Int = 0

    public init(data: Data) {
        self.data = Array(data)
    }

    public mutating func decode() throws -> BencodeValue {
        guard position < data.count else {
            throw BencodeError.unexpectedEnd
        }
        let byte = data[position]
        switch byte {
        case UInt8(ascii: "i"):
            return try decodeInteger()
        case UInt8(ascii: "l"):
            return try decodeList()
        case UInt8(ascii: "d"):
            return try decodeDictionary()
        case UInt8(ascii: "0") ... UInt8(ascii: "9"):
            return try decodeString()
        default:
            throw BencodeError.invalidToken(byte)
        }
    }

    private mutating func decodeInteger() throws -> BencodeValue {
        position += 1 // skip 'i'
        var numStr = ""
        while position < data.count && data[position] != UInt8(ascii: "e") {
            numStr.append(Character(UnicodeScalar(data[position])))
            position += 1
        }
        guard position < data.count else { throw BencodeError.unexpectedEnd }
        position += 1 // skip 'e'
        guard let num = Int64(numStr) else { throw BencodeError.invalidInteger(numStr) }
        return .integer(num)
    }

    private mutating func decodeString() throws -> BencodeValue {
        var lenStr = ""
        while position < data.count && data[position] != UInt8(ascii: ":") {
            lenStr.append(Character(UnicodeScalar(data[position])))
            position += 1
        }
        guard position < data.count else { throw BencodeError.unexpectedEnd }
        position += 1 // skip ':'
        guard let len = Int(lenStr) else { throw BencodeError.invalidLength(lenStr) }
        guard position + len <= data.count else { throw BencodeError.truncatedString }
        let bytes = Data(data[position ..< position + len])
        position += len
        return .string(bytes)
    }

    private mutating func decodeList() throws -> BencodeValue {
        position += 1 // skip 'l'
        var items: [BencodeValue] = []
        while position < data.count && data[position] != UInt8(ascii: "e") {
            items.append(try decode())
        }
        guard position < data.count else { throw BencodeError.unexpectedEnd }
        position += 1 // skip 'e'
        return .list(items)
    }

    private mutating func decodeDictionary() throws -> BencodeValue {
        position += 1 // skip 'd'
        var dict: [String: BencodeValue] = [:]
        while position < data.count && data[position] != UInt8(ascii: "e") {
            let keyValue = try decodeString()
            guard let key = keyValue.stringValue else { throw BencodeError.nonStringKey }
            let value = try decode()
            dict[key] = value
        }
        guard position < data.count else { throw BencodeError.unexpectedEnd }
        position += 1 // skip 'e'
        return .dictionary(dict)
    }
}

// MARK: - Encoder
public struct BencodeEncoder {
    public static func encode(_ value: BencodeValue) -> Data {
        var result = Data()
        encode(value, into: &result)
        return result
    }

    public static func encode(dict: [String: Any]) -> Data {
        var result = Data()
        result.append(UInt8(ascii: "d"))
        for key in dict.keys.sorted() {
            encode(.string(Data(key.utf8)), into: &result)
            if let v = dict[key] as? Int {
                encode(.integer(Int64(v)), into: &result)
            } else if let v = dict[key] as? String {
                encode(.string(Data(v.utf8)), into: &result)
            } else if let v = dict[key] as? Data {
                encode(.string(v), into: &result)
            } else if let v = dict[key] as? [String: Any] {
                result.append(encode(dict: v))
            } else if let v = dict[key] as? [Any] {
                result.append(UInt8(ascii: "l"))
                for item in v {
                    if let i = item as? Int {
                        encode(.integer(Int64(i)), into: &result)
                    } else if let s = item as? String {
                        encode(.string(Data(s.utf8)), into: &result)
                    }
                }
                result.append(UInt8(ascii: "e"))
            }
        }
        result.append(UInt8(ascii: "e"))
        return result
    }

    private static func encode(_ value: BencodeValue, into data: inout Data) {
        switch value {
        case .string(let bytes):
            data.append(contentsOf: "\(bytes.count):".utf8)
            data.append(bytes)
        case .integer(let i):
            data.append(contentsOf: "i\(i)e".utf8)
        case .list(let items):
            data.append(UInt8(ascii: "l"))
            for item in items { encode(item, into: &data) }
            data.append(UInt8(ascii: "e"))
        case .dictionary(let dict):
            data.append(UInt8(ascii: "d"))
            for key in dict.keys.sorted() {
                encode(.string(Data(key.utf8)), into: &data)
                encode(dict[key]!, into: &data)
            }
            data.append(UInt8(ascii: "e"))
        }
    }
}

// MARK: - Errors
public enum BencodeError: Error, LocalizedError {
    case unexpectedEnd
    case invalidToken(UInt8)
    case invalidInteger(String)
    case invalidLength(String)
    case truncatedString
    case nonStringKey

    public var errorDescription: String? {
        switch self {
        case .unexpectedEnd: return "Unexpected end of bencode data"
        case .invalidToken(let b): return "Invalid bencode token: \(b)"
        case .invalidInteger(let s): return "Invalid integer: \(s)"
        case .invalidLength(let s): return "Invalid string length: \(s)"
        case .truncatedString: return "String data truncated"
        case .nonStringKey: return "Dictionary key must be a string"
        }
    }
}
