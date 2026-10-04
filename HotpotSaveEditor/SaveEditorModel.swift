import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SaveEditorModel: ObservableObject {
    enum Section: String, CaseIterable, Identifiable {
        case keyPlayer = "Nhân vật"
        case backup = "Sao lưu"
        var id: String { rawValue }
        var fileName: String { self == .keyPlayer ? "key_player_data_DECODED.json" : "Data_BackUp_DECODED.json" }
    }

    @Published private(set) var importedFileName = "Chưa có file"
    @Published private(set) var status = "Chọn file com.lxqd.hotpotiver.plist từ Files để bắt đầu."
    @Published private(set) var isLoaded = false
    @Published var selectedSection: Section = .keyPlayer
    @Published var editorText = ""
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published private(set) var hasWorkspace = false

    private var sourcePlist: [String: Any] = [:]
    private var keyPlayerData: JSONValue = .object([:])
    private var backupData: JSONValue = .object([:])

    var quickFields: [(key: String, label: String)] {
        [
            ("gold", "Tiền vàng"), ("diamond", "Kim cương"),
            ("actionPoint", "Thể lực"), ("integral", "Điểm sự kiện"),
            ("playerLevel", "Cấp độ"), ("playerExp", "Kinh nghiệm"),
            ("vipPoint", "Điểm VIP"), ("capsuleToysCoin", "Xu gắp thú"),
            ("shopSkinCoin", "Xu thời trang")
        ]
    }

    func importPlist(from url: URL) {
        do {
            let acquired = url.startAccessingSecurityScopedResource()
            defer { if acquired { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                throw SaveEditorError.invalidPlist
            }
            guard let rawPlayer = plist["key_player_data"], let rawBackup = plist["Data_BackUp"] else {
                throw SaveEditorError.requiredKeysMissing
            }

            keyPlayerData = try decodePlayer(rawPlayer)
            backupData = try decodeBackup(rawBackup)
            sourcePlist = plist
            importedFileName = url.lastPathComponent
            isLoaded = true
            selectedSection = .keyPlayer
            refreshEditorText()
            try writeWorkspace()
            status = "Đã giải mã an toàn vào vùng làm việc của app."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ section: Section) {
        guard applyEditorText() else { return }
        selectedSection = section
        refreshEditorText()
    }

    func applyEditorText() -> Bool {
        do {
            let value = try JSONValue.parse(text: editorText)
            switch selectedSection {
            case .keyPlayer: keyPlayerData = value
            case .backup: backupData = value
            }
            try writeWorkspace()
            return true
        } catch {
            errorMessage = "JSON chưa hợp lệ: \(error.localizedDescription)"
            return false
        }
    }

    func value(for key: String) -> String {
        guard let value = keyPlayerData[key] else { return "" }
        switch value {
        case .number(let number): return number.rounded() == number ? String(Int64(number)) : String(number)
        case .string(let text): return text
        default: return ""
        }
    }

    func updateQuickValue(_ text: String, key: String) {
        guard let number = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        keyPlayerData[key] = .number(number)
        if selectedSection == .keyPlayer { refreshEditorText() }
        do { try writeWorkspace() } catch { errorMessage = error.localizedDescription }
    }

    func prepareExport() -> BinaryPlistDocument? {
        guard isLoaded, applyEditorText() else { return nil }
        do {
            var output = sourcePlist
            output["key_player_data"] = try encodePlayer(keyPlayerData)
            output["Data_BackUp"] = try encodeBackup(backupData)
            let data = try PropertyListSerialization.data(fromPropertyList: output, format: .binary, options: 0)
            status = "Đã đóng gói Binary PLIST. Chọn nơi lưu trong Files."
            return BinaryPlistDocument(data: data)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func finishExport(deleteWorkspace: Bool) {
        guard deleteWorkspace else {
            infoMessage = "Đã xuất file. Dữ liệu giải mã vẫn được giữ trong app."
            return
        }
        do {
            let url = workspaceURL
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            hasWorkspace = false
            infoMessage = "Đã xuất file và xóa Decoded_GameData khỏi vùng làm việc của app."
        } catch { errorMessage = error.localizedDescription }
    }

    func clearWorkspace() {
        do {
            let url = workspaceURL
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            hasWorkspace = false
            status = "Đã xóa dữ liệu giải mã khỏi app."
        } catch { errorMessage = error.localizedDescription }
    }

    private func refreshEditorText() {
        editorText = selectedSection == .keyPlayer ? keyPlayerData.prettyText : backupData.prettyText
    }

    private func decodePlayer(_ raw: Any) throws -> JSONValue {
        let text: String
        if let data = raw as? Data { text = String(decoding: data, as: UTF8.self) }
        else if let string = raw as? String { text = string }
        else { throw SaveEditorError.invalidPlayerData }
        return try JSONValue.parse(text: text.replacingOccurrences(of: "\0", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func decodeBackup(_ raw: Any) throws -> JSONValue {
        let encoded: Data
        if let data = raw as? Data { encoded = data }
        else if let string = raw as? String { encoded = Data(string.utf8) }
        else { throw SaveEditorError.invalidBackupData }
        guard let compressed = Data(base64Encoded: encoded) else { throw SaveEditorError.invalidBackupData }
        return try JSONDecoder().decode(JSONValue.self, from: GzipCodec.decompress(compressed))
    }

    private func encodePlayer(_ data: JSONValue) throws -> String {
        guard let text = String(data: try JSONEncoder().encode(data), encoding: .utf8) else { throw SaveEditorError.encodingFailed }
        return text
    }

    private func encodeBackup(_ data: JSONValue) throws -> Data {
        let json = try JSONEncoder().encode(data)
        return try GzipCodec.compress(json).base64EncodedData()
    }

    private var workspaceURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Decoded_GameData", isDirectory: true)
    }

    private func writeWorkspace() throws {
        let url = workspaceURL
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try keyPlayerData.prettyText.write(to: url.appendingPathComponent("key_player_data_DECODED.json"), atomically: true, encoding: .utf8)
        try backupData.prettyText.write(to: url.appendingPathComponent("Data_BackUp_DECODED.json"), atomically: true, encoding: .utf8)
        hasWorkspace = true
    }
}

enum SaveEditorError: LocalizedError {
    case invalidPlist, requiredKeysMissing, invalidPlayerData, invalidBackupData, encodingFailed
    var errorDescription: String? {
        switch self {
        case .invalidPlist: return "File không phải Binary PLIST hợp lệ."
        case .requiredKeysMissing: return "Không tìm thấy key_player_data hoặc Data_BackUp trong file."
        case .invalidPlayerData: return "key_player_data không phải JSON hợp lệ."
        case .invalidBackupData: return "Data_BackUp không có Base64/GZIP hợp lệ."
        case .encodingFailed: return "Không thể mã hóa JSON."
        }
    }
}

struct BinaryPlistDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
