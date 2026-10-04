import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct EditField: Identifiable, Hashable {
    let key: String; let title: String; let detail: String
    var id: String { key }
}
struct EditableRow: Identifiable, Hashable {
    let id = UUID(); let identifier: String; let subtitle: String; var values: [String]
}
enum ManualArea: String, CaseIterable, Identifiable {
    case facilities = "Cơ sở vật chất", foods = "Món ăn", customers = "Khách hàng", inventory = "Túi & vật phẩm"
    var id: String { rawValue }
}
enum TaskArea: String, CaseIterable, Identifiable {
    case normal = "Nhiệm vụ thường", daily = "Nhiệm vụ ngày", activity = "Hoạt động ngày", chapter = "Nhiệm vụ chương"
    var id: String { rawValue }
    var key: String { switch self { case .normal: "normalTaskDatas"; case .daily: "dailyTaskDatas"; case .activity: "dailyActTaskDatas"; case .chapter: "chapterTasks" } }
}

@MainActor
final class SaveEditorModel: ObservableObject {
    @Published private(set) var importedFileName = "Chưa có file"
    @Published private(set) var status = "Chọn file com.lxqd.hotpotiver.plist từ Files để bắt đầu."
    @Published private(set) var isLoaded = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published private(set) var hasWorkspace = false
    @Published var showAdFreeTool = false
    private var sourcePlist: [String: Any] = [:]
    private var player: JSONValue = .object([:])
    private var backup: JSONValue = .object([:])

    let quickFields: [EditField] = [
        .init(key: "gold", title: "Tiền vàng", detail: "Gold"), .init(key: "diamond", title: "Kim cương", detail: "Diamond"), .init(key: "actionPoint", title: "Thể lực", detail: "Action Point"), .init(key: "integral", title: "Điểm sự kiện", detail: "Integral"), .init(key: "staffTrainPoint", title: "Sổ đào tạo", detail: "Staff Train Point"), .init(key: "foodLimitCutPoint", title: "Bánh quy", detail: "Food Limit Cut Point"), .init(key: "playerLevel", title: "Cấp độ cửa hàng", detail: "Player Level"), .init(key: "playerExp", title: "Kinh nghiệm", detail: "Player EXP"), .init(key: "starLevel", title: "Cấp sao", detail: "Star Level"), .init(key: "facilityScore", title: "Điểm cơ sở", detail: "Facility Score"), .init(key: "serverScore", title: "Điểm phục vụ", detail: "Service Score"), .init(key: "foodScore", title: "Điểm thức ăn", detail: "Food Score"), .init(key: "vipPoint", title: "Điểm VIP", detail: "VIP Point"), .init(key: "capsuleToysCoin", title: "Xu gắp thú", detail: "Capsule Toys Coin"), .init(key: "shopSkinCoin", title: "Xu thời trang", detail: "Shop Skin Coin"), .init(key: "crawFishCoin", title: "Xu tôm hùm", detail: "Crawfish Coin"), .init(key: "fireflyCoin", title: "Xu đom đóm", detail: "Firefly Coin")]
    let minigameFields: [EditField] = [
        .init(key: "crawFishCoin", title: "Xu tôm hùm", detail: "Câu cá"), .init(key: "baitNum", title: "Mồi câu", detail: "Câu tôm hùm"), .init(key: "fireflyCoin", title: "Xu đom đóm", detail: ""), .init(key: "worldCup22Score", title: "Điểm World Cup", detail: ""), .init(key: "stackTower22Score", title: "Điểm Xếp Tháp", detail: ""), .init(key: "scoreXmas23", title: "Điểm Giáng Sinh", detail: ""), .init(key: "thanksGivingIntegral", title: "Điểm Lễ Tạ Ơn", detail: ""), .init(key: "dragonScore", title: "Điểm sự kiện Rồng", detail: ""), .init(key: "dragonEggPoint", title: "Điểm Trứng Rồng", detail: ""), .init(key: "arcadeIntegral", title: "Xu Arcade", detail: "Máy xèng"), .init(key: "capsuleToysCoin", title: "Xu gắp thú", detail: "")]
    let shopFields: [EditField] = [.init(key: "vipPoint", title: "Điểm VIP", detail: ""), .init(key: "shopSkinCoin", title: "Xu thời trang", detail: "Skin"), .init(key: "shopFoodCoin", title: "Xu thức ăn", detail: "Food"), .init(key: "shopFruitSlotsScore", title: "Điểm máy xèng trái cây", detail: "")]

    func importPlist(from url: URL) {
        do {
            let acquired = url.startAccessingSecurityScopedResource(); defer { if acquired { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else { throw SaveEditorError.invalidPlist }
            guard let rawPlayer = plist["key_player_data"], let rawBackup = plist["Data_BackUp"] else { throw SaveEditorError.requiredKeysMissing }
            player = try decodePlayer(rawPlayer); backup = try decodeBackup(rawBackup); sourcePlist = plist; importedFileName = url.lastPathComponent; isLoaded = true; try writeWorkspace(); status = "Đã giải mã. Chọn mục ở tab Chỉnh sửa để bắt đầu."
        } catch { errorMessage = error.localizedDescription }
    }
    func value(for key: String) -> String { string(player[key]) }
    func updateValue(_ text: String, key: String) { let value = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !value.isEmpty else { return }; player[key] = Double(value).map(JSONValue.number) ?? .string(value); persist() }
    func boolValue(_ key: String) -> Bool { player[key]?.boolValue ?? false }
    func setBool(_ key: String, _ value: Bool) { player[key] = .bool(value); persist() }

    func runMassAction(_ action: String) {
        guard ensureLoaded() else { return }; var changed = 0
        switch action {
        case "foods": changed = mutateArray("foodDatas") { $0["isUnlock"] = .bool(true); $0["IsUnlcked"] = .bool(true) }
        case "facilities": changed = mutateArray("facilityDatas") { $0["isOwn"] = .bool(true) }
        case "areas": for key in ["regionUnlock", "areaUnlock", "regionInitFlag"] { changed += fillBooleanValues(key) }
        case "favor": changed = mutateValues("FavorabilityData") { $0["CurrentFavorScore"] = .number(99999) }
        case "staff": changed = mutateArray("staffDatas") { $0["isOwn"] = .bool(true) }
        case "tasks": for key in ["normalTaskDatas", "dailyTaskDatas", "dailyActTaskDatas", "chapterTasks"] { changed += completeTasks(key) }
        default: break }
        persist(); infoMessage = "Đã cập nhật \(changed) mục."
    }
    func extendCard(superCard: Bool) { guard ensureLoaded() else { return }; let key = superCard ? "superMonthCardData" : "monthCardData"; let now = Date().timeIntervalSince1970; var wrapper = player[key]?.objectValue ?? [:]; var values = wrapper["values"]?.arrayValue ?? []; if values.isEmpty { values = [.object(["EndTime": .number(now + 2_592_000)])] } else { values = values.map { var item = $0.objectValue ?? [:]; item["EndTime"] = .number(max(item["EndTime"]?.numberValue ?? 0, now) + 2_592_000); return .object(item) } }; wrapper["values"] = .array(values); player[key] = .object(wrapper); persist(); infoMessage = "Đã gia hạn thẻ tháng thêm 30 ngày." }
    func activateAdFree() { for key in ["isBoughtRemoveAd", "hasRemoveAd", "removeAdCard", "isRemoveAd"] { player[key] = .bool(true) }; persist(); infoMessage = "Đã cập nhật trạng thái loại bỏ quảng cáo." }
    func resetGiftCodes() { player["cdkUsedList"] = .array([]); persist(); infoMessage = "Đã xóa lịch sử Giftcode." }
    func unlockPurchases(_ key: String) { guard var value = player[key] else { return }; recursiveUnlock(&value); player[key] = value; persist(); infoMessage = "Đã mở khóa gói \(key)." }
    func purchaseKeys() -> [String] { player.objectValue?.keys.filter { $0.localizedCaseInsensitiveContains("iap") || $0.localizedCaseInsensitiveContains("purchase") || $0.localizedCaseInsensitiveContains("pack") }.sorted() ?? [] }
    func unlockSkins() { guard var item = player["roleSkinIdUnlock"]?.objectValue, let values = item["values"]?.arrayValue else { infoMessage = "Không tìm thấy roleSkinIdUnlock."; return }; item["values"] = .array(values.map { _ in .bool(true) }); player["roleSkinIdUnlock"] = .object(item); persist(); infoMessage = "Đã mở khóa trang phục nhân viên." }
    func setAdvanced(adCount: String, nextReward: Date, eventScore: String, freeUntil: Date, passScore: String) { updateValue(adCount, key: "rewardAdCount"); player["rewardAdNextRewardTs"] = .number(nextReward.timeIntervalSince1970); updateValue(eventScore, key: "doubleElevenScore"); player["doubleElevenFreeRewardTs"] = .number(freeUntil.timeIntervalSince1970); updateValue(passScore, key: "gatePassScore"); persist(); infoMessage = "Đã lưu quảng cáo và sự kiện." }
    func dateValue(_ key: String) -> Date { Date(timeIntervalSince1970: player[key]?.numberValue ?? Date().timeIntervalSince1970) }

    func manualRows(_ area: ManualArea) -> [EditableRow] {
        switch area {
        case .facilities: return (player["facilityDatas"]?.arrayValue ?? []).map { let o = $0.objectValue ?? [:]; return .init(identifier: string(o["id"]), subtitle: "Vùng \(string(o["region"])) · Loại \(string(o["category"]))", values: [string(o["lv"]), boolString(o["isOwn"])]) }
        case .foods: return (player["foodDatas"]?.arrayValue ?? []).map { let o = $0.objectValue ?? [:]; return .init(identifier: string(o["id"]), subtitle: "Món ăn", values: [string(o["proficiency"]), boolString(o["isUnlock"]), boolString(o["isLimitCut"]), string(o["salesVolume"])]) }
        case .customers: return valuesArray("FavorabilityData").map { let o = $0.objectValue ?? [:]; return .init(identifier: string(o["CustomerId"]), subtitle: "Khách hàng", values: [string(o["CurrentLevel"]), string(o["CurrentFavorScore"])]) }
        case .inventory: return ["pointData", "countData", "bagData"].flatMap { key in keyedValues(key).map { .init(identifier: $0.1, subtitle: key, values: [string($0.2)]) } }
        }
    }
    func saveManualRows(_ rows: [EditableRow], area: ManualArea) {
        switch area {
        case .facilities: mutateArrayAt("facilityDatas") { i, item in item["lv"] = number(rows[safe: i]?.values[safe: 0]); item["isOwn"] = .bool(bool(rows[safe: i]?.values[safe: 1])) }
        case .foods: mutateArrayAt("foodDatas") { i, item in item["proficiency"] = number(rows[safe: i]?.values[safe: 0]); let unlocked = bool(rows[safe: i]?.values[safe: 1]); item["isUnlock"] = .bool(unlocked); item["IsUnlcked"] = .bool(unlocked); item["isLimitCut"] = .bool(bool(rows[safe: i]?.values[safe: 2])); item["salesVolume"] = number(rows[safe: i]?.values[safe: 3]) }
        case .customers: mutateValuesAt("FavorabilityData") { i, item in item["CurrentLevel"] = number(rows[safe: i]?.values[safe: 0]); item["CurrentFavorScore"] = number(rows[safe: i]?.values[safe: 1]) }
        case .inventory: for row in rows { setKeyedValue(row.subtitle, id: row.identifier, value: number(row.values.first)) }
        }; persist(); infoMessage = "Đã lưu các thay đổi thủ công."
    }
    func limitRows() -> [EditableRow] { let words = ["Count", "Limit", "Ts", "Flag", "Purchase"]; return (player.objectValue ?? [:]).flatMap { key, value in guard words.contains(where: { key.localizedCaseInsensitiveContains($0) }), let object = value.objectValue, let keys = object["keys"]?.arrayValue, let values = object["values"]?.arrayValue else { return [] }; return zip(keys, values).map { .init(identifier: string($0.0), subtitle: key, values: [string($0.1)]) } }.sorted { $0.subtitle < $1.subtitle } }
    func saveLimitRows(_ rows: [EditableRow]) { for row in rows { setKeyedValue(row.subtitle, id: row.identifier, value: number(row.values.first)) }; persist(); infoMessage = "Đã lưu lượt và giới hạn." }
    func fusionRows(_ key: String) -> [EditableRow] { keyedValues(key).map { .init(identifier: $0.1, subtitle: key, values: [string($0.2)]) } }
    func saveFusionRows(_ rows: [EditableRow]) { for row in rows { setKeyedValue(row.subtitle, id: row.identifier, value: number(row.values.first)) }; persist(); infoMessage = "Đã lưu dữ liệu ghép đồ." }
    func taskRows(_ area: TaskArea) -> [EditableRow] { (player[area.key]?.arrayValue ?? []).map { let o = $0.objectValue ?? [:]; return .init(identifier: string(o["taskId"] ?? o["id"]), subtitle: area.rawValue, values: [string(o["completeNum"]), string(o["task_count"])]) } }
    func saveTaskRows(_ rows: [EditableRow], area: TaskArea) { mutateArrayAt(area.key) { i, item in item["completeNum"] = number(rows[safe: i]?.values[safe: 0]) }; persist(); infoMessage = "Đã lưu nhiệm vụ." }
    func maxTasks(_ area: TaskArea) { let count = completeTasks(area.key); persist(); infoMessage = "Đã hoàn thành \(count) nhiệm vụ." }
    func luckyRewards() -> [EditableRow] { (player["luckyCatRewardItems"]?.arrayValue ?? []).map { let o = $0.objectValue ?? [:]; return .init(identifier: string(o["itemId"]), subtitle: "Type \(string(o["type"]))", values: [string(o["num"])]) } }
    func saveLuckyRewards(_ rows: [EditableRow]) { player["luckyCatRewardItems"] = .array(rows.map { .object(["type": number($0.subtitle.replacingOccurrences(of: "Type ", with: "")), "itemId": number($0.identifier), "num": number($0.values.first)]) }); persist(); infoMessage = "Đã lưu phần thưởng Mèo Thần Tài." }
    func luckyRecords() -> [EditableRow] { (player["luckyCatRecords"]?.arrayValue ?? []).map { let o = $0.objectValue ?? [:]; return .init(identifier: string(o["talkId"]), subtitle: "Item \(string(o["itemId"]))", values: [string(o["reward"])]) } }
    func maxGatePass() { guard var wrapper = player["gatePassData"]?.objectValue else { infoMessage = "Không có Gate Pass trong save này."; return }; var values = wrapper["values"]?.arrayValue ?? []; values = values.map { value in var pass = value.objectValue ?? [:]; pass["score"] = .number(100000); pass["taskDatas"] = .array((pass["taskDatas"]?.arrayValue ?? []).map { var x = $0.objectValue ?? [:]; x["taskProgress"] = .number(999); x["taskState"] = .number(2); return .object(x) }); pass["challengeDatas"] = .array((pass["challengeDatas"]?.arrayValue ?? []).map { var x = $0.objectValue ?? [:]; x["score"] = .number(999); x["grade"] = .number(99); return .object(x) }); return .object(pass) }; wrapper["values"] = .array(values); player["gatePassData"] = .object(wrapper); persist(); infoMessage = "Đã tối đa Gate Pass." }
    func claimEventRewards() { let keys = ["signInmidAutumnReward", "signInMasParkourReward", "CommonSign2Reward", "christmasDayReward", "signInSevenReward", "CommonSign3Reward", "thanksGivingIntegralOnceReward"]; var count = 0; for key in keys { guard var object = player[key]?.objectValue, let values = object["values"]?.arrayValue else { continue }; object["values"] = .array(values.map { if case .bool(false) = $0 { count += 1; return .bool(true) }; return $0 }); player[key] = .object(object) }; persist(); infoMessage = count == 0 ? "Không tìm thấy quà sự kiện chưa nhận." : "Đã đánh dấu nhận \(count) phần thưởng." }

    func prepareExport() -> BinaryPlistDocument? { guard isLoaded else { return nil }; do { var output = sourcePlist; output["key_player_data"] = try encodePlayer(player); output["Data_BackUp"] = try encodeBackup(backup); status = "Đã đóng gói Binary PLIST. Chọn nơi lưu trong Files."; return .init(data: try PropertyListSerialization.data(fromPropertyList: output, format: .binary, options: 0)) } catch { errorMessage = error.localizedDescription; return nil } }
    func finishExport(deleteWorkspace: Bool) { guard deleteWorkspace else { infoMessage = "Đã xuất file. Dữ liệu giải mã vẫn được giữ trong app."; return }; clearWorkspace(); infoMessage = "Đã xuất file và xóa Decoded_GameData khỏi app." }
    func clearWorkspace() { do { if FileManager.default.fileExists(atPath: workspaceURL.path) { try FileManager.default.removeItem(at: workspaceURL) }; hasWorkspace = false; status = "Đã xóa dữ liệu giải mã khỏi app." } catch { errorMessage = error.localizedDescription } }
    private func ensureLoaded() -> Bool { guard isLoaded else { errorMessage = "Hãy chọn file PLIST trước."; return false }; return true }
    private func persist() { do { try writeWorkspace() } catch { errorMessage = error.localizedDescription } }
    private func mutateArray(_ key: String, _ body: (inout JSONValue) -> Void) -> Int { guard var values = player[key]?.arrayValue else { return 0 }; for i in values.indices { body(&values[i]) }; player[key] = .array(values); return values.count }
    private func mutateArrayAt(_ key: String, _ body: (Int, inout JSONValue) -> Void) { guard var values = player[key]?.arrayValue else { return }; for i in values.indices { body(i, &values[i]) }; player[key] = .array(values) }
    private func valuesArray(_ key: String) -> [JSONValue] { player[key]?.objectValue?["values"]?.arrayValue ?? [] }
    private func mutateValues(_ key: String, _ body: (inout JSONValue) -> Void) -> Int { guard var wrapper = player[key]?.objectValue, var values = wrapper["values"]?.arrayValue else { return 0 }; for i in values.indices { body(&values[i]) }; wrapper["values"] = .array(values); player[key] = .object(wrapper); return values.count }
    private func mutateValuesAt(_ key: String, _ body: (Int, inout JSONValue) -> Void) { guard var wrapper = player[key]?.objectValue, var values = wrapper["values"]?.arrayValue else { return }; for i in values.indices { body(i, &values[i]) }; wrapper["values"] = .array(values); player[key] = .object(wrapper) }
    private func fillBooleanValues(_ key: String) -> Int { guard var wrapper = player[key]?.objectValue, let values = wrapper["values"]?.arrayValue else { return 0 }; wrapper["values"] = .array(values.map { _ in .bool(true) }); player[key] = .object(wrapper); return values.count }
    private func completeTasks(_ key: String) -> Int { guard var tasks = player[key]?.arrayValue else { return 0 }; for i in tasks.indices { var task = tasks[i].objectValue ?? [:]; let target = max(task["task_count"]?.numberValue ?? 0, 1); if (task["completeNum"]?.numberValue ?? 0) < target { task["completeNum"] = .number(target) }; tasks[i] = .object(task) }; player[key] = .array(tasks); return tasks.count }
    private func keyedValues(_ key: String) -> [(Int, String, JSONValue)] { guard let object = player[key]?.objectValue, let keys = object["keys"]?.arrayValue, let values = object["values"]?.arrayValue else { return [] }; return zip(keys.indices, zip(keys, values)).map { ($0.0, string($0.1.0), $0.1.1) } }
    private func setKeyedValue(_ key: String, id: String, value: JSONValue) { guard var object = player[key]?.objectValue, let keys = object["keys"]?.arrayValue, var values = object["values"]?.arrayValue, let index = keys.firstIndex(where: { string($0) == id }), values.indices.contains(index) else { return }; values[index] = value; object["values"] = .array(values); player[key] = .object(object) }
    private func recursiveUnlock(_ value: inout JSONValue) { switch value { case .object(var object): for key in object.keys { if ["isBought", "hasPurchased", "isUnlock", "isPremium", "IsUnlcked"].contains(key) { object[key] = .bool(true) } else if var child = object[key] { recursiveUnlock(&child); object[key] = child } }; value = .object(object); case .array(var array): for i in array.indices { recursiveUnlock(&array[i]) }; value = .array(array); default: break } }
    private func string(_ value: JSONValue?) -> String { guard let value else { return "" }; switch value { case .number(let x): return x.rounded() == x ? String(Int64(x)) : String(x); case .string(let x): return x; case .bool(let x): return x ? "true" : "false"; default: return "" } }
    private func boolString(_ value: JSONValue?) -> String { value?.boolValue == true ? "true" : "false" }
    private func bool(_ value: String?) -> Bool { ["true", "1", "yes", "y"].contains((value ?? "").lowercased()) }
    private func number(_ value: String?) -> JSONValue { .number(Double(value ?? "0") ?? 0) }
    private func decodePlayer(_ raw: Any) throws -> JSONValue { let text: String; if let data = raw as? Data { text = String(decoding: data, as: UTF8.self) } else if let string = raw as? String { text = string } else { throw SaveEditorError.invalidPlayerData }; return try JSONValue.parse(text: text.replacingOccurrences(of: "\0", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) }
    private func decodeBackup(_ raw: Any) throws -> JSONValue { let encoded: Data; if let data = raw as? Data { encoded = data } else if let string = raw as? String { encoded = Data(string.utf8) } else { throw SaveEditorError.invalidBackupData }; guard let compressed = Data(base64Encoded: encoded) else { throw SaveEditorError.invalidBackupData }; return try JSONDecoder().decode(JSONValue.self, from: GzipCodec.decompress(compressed)) }
    private func encodePlayer(_ data: JSONValue) throws -> String { guard let text = String(data: try JSONEncoder().encode(data), encoding: .utf8) else { throw SaveEditorError.encodingFailed }; return text }
    private func encodeBackup(_ data: JSONValue) throws -> Data { try GzipCodec.compress(JSONEncoder().encode(data)).base64EncodedData() }
    private var workspaceURL: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Decoded_GameData", isDirectory: true) }
    private func writeWorkspace() throws { try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true); try player.prettyText.write(to: workspaceURL.appendingPathComponent("key_player_data_DECODED.json"), atomically: true, encoding: .utf8); try backup.prettyText.write(to: workspaceURL.appendingPathComponent("Data_BackUp_DECODED.json"), atomically: true, encoding: .utf8); hasWorkspace = true }
}

private extension JSONValue { var objectValue: [String: JSONValue]? { if case .object(let value) = self { value } else { nil } }; var arrayValue: [JSONValue]? { if case .array(let value) = self { value } else { nil } }; var numberValue: Double? { if case .number(let value) = self { value } else { nil } }; var boolValue: Bool? { if case .bool(let value) = self { value } else { nil } } }
private extension Array { subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil } }
enum SaveEditorError: LocalizedError { case invalidPlist, requiredKeysMissing, invalidPlayerData, invalidBackupData, encodingFailed; var errorDescription: String? { switch self { case .invalidPlist: "File không phải Binary PLIST hợp lệ."; case .requiredKeysMissing: "Không tìm thấy key_player_data hoặc Data_BackUp trong file."; case .invalidPlayerData: "key_player_data không phải JSON hợp lệ."; case .invalidBackupData: "Data_BackUp không có Base64/GZIP hợp lệ."; case .encodingFailed: "Không thể mã hóa JSON." } } }
struct BinaryPlistDocument: FileDocument { static var readableContentTypes: [UTType] { [.data] }; var data: Data; init(data: Data) { self.data = data }; init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }; func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) } }
