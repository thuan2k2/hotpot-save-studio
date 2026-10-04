import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @EnvironmentObject private var editor: SaveEditorModel
    @State private var importing = false
    @State private var exporting = false
    @State private var exportDocument: BinaryPlistDocument?
    @State private var askToClearAfterExport = false
    @State private var askToClearNow = false

    private var importTypes: [UTType] {
        [.data, UTType(filenameExtension: "plist") ?? .data, UTType(filenameExtension: "bplist") ?? .data]
    }

    var body: some View {
        TabView {
            NavigationStack { fileView }.modifier(KeyboardDoneModifier()).tabItem { Label("Tệp", systemImage: "folder.fill") }
            NavigationStack { editMenu }.modifier(KeyboardDoneModifier()).tabItem { Label("Chỉnh sửa", systemImage: "slider.horizontal.3") }
            NavigationStack { guideView }.modifier(KeyboardDoneModifier()).tabItem { Label("Hướng dẫn", systemImage: "questionmark.circle") }
        }
        .tint(.orange)
        // Keep the layout compact even when the phone has an enlarged accessibility text setting.
        .dynamicTypeSize(.xSmall ... .large)
        .fileImporter(isPresented: $importing, allowedContentTypes: importTypes, allowsMultipleSelection: false) { result in if case .success(let urls) = result, let url = urls.first { editor.importPlist(from: url) } }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .data, defaultFilename: "hotpot_repacked.bplist") { result in switch result { case .success: askToClearAfterExport = true; case .failure(let error): editor.errorMessage = "Không thể xuất file: \(error.localizedDescription)" } }
        .alert("Xóa dữ liệu giải mã?", isPresented: $askToClearAfterExport) { Button("Giữ lại", role: .cancel) { editor.finishExport(deleteWorkspace: false) }; Button("Xóa", role: .destructive) { editor.finishExport(deleteWorkspace: true) } } message: { Text("Đã xuất hotpot_repacked.bplist. Bạn có muốn xóa thư mục Decoded_GameData trong vùng làm việc của app không?") }
        .alert("Xóa dữ liệu giải mã?", isPresented: $askToClearNow) { Button("Hủy", role: .cancel) {}; Button("Xóa", role: .destructive) { editor.clearWorkspace() } } message: { Text("Chỉ xóa dữ liệu nội bộ của app, không ảnh hưởng file gốc trong Files.") }
        .alert("Lỗi", isPresented: Binding(get: { editor.errorMessage != nil }, set: { if !$0 { editor.errorMessage = nil } })) { Button("Đóng", role: .cancel) {} } message: { Text(editor.errorMessage ?? "") }
        .alert("Hoàn tất", isPresented: Binding(get: { editor.infoMessage != nil }, set: { if !$0 { editor.infoMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(editor.infoMessage ?? "") }
    }

    private var fileView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) { Text("HOT POT").font(.caption.weight(.bold)).foregroundStyle(.orange); Text("Save Studio").font(.title2.bold()); Text("Chỉnh sửa save trực tiếp trên iPhone").font(.subheadline).foregroundStyle(.secondary) }
                GlassCard { Label(editor.isLoaded ? editor.importedFileName : "Chưa chọn save", systemImage: editor.isLoaded ? "checkmark.seal.fill" : "doc.badge.plus").font(.subheadline.weight(.semibold)).foregroundStyle(editor.isLoaded ? .green : .secondary); Text(editor.status).font(.caption).foregroundStyle(.secondary) }
                GlassCard { Label("Quy trình", systemImage: "arrow.triangle.2.circlepath").font(.subheadline.weight(.semibold)); Text("1. Chọn PLIST từ Files\n2. Chỉnh sửa tại tab Chỉnh sửa\n3. Xuất hotpot_repacked.bplist\n4. Chọn xóa hoặc giữ dữ liệu giải mã").font(.subheadline).lineSpacing(2).foregroundStyle(.secondary) }
                Button { importing = true } label: { Label(editor.isLoaded ? "Chọn file khác" : "Chọn file PLIST", systemImage: "folder.badge.plus").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.regular)
                if editor.isLoaded { Button { exportDocument = editor.prepareExport(); exporting = exportDocument != nil } label: { Label("Đóng gói và xuất", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.regular).tint(.orange) }
                if editor.hasWorkspace { Button(role: .destructive) { askToClearNow = true } label: { Label("Xóa Decoded_GameData", systemImage: "trash").frame(maxWidth: .infinity) } }
            }.padding()
        }.navigationTitle("Save Studio").background(Color(.systemGroupedBackground))
    }

    private var editMenu: some View {
        List {
            Section { if !editor.isLoaded { ContentUnavailableView("Chưa có dữ liệu", systemImage: "doc", description: Text("Nhập file PLIST tại tab Tệp trước.")) } else { Label("Đã sẵn sàng chỉnh sửa", systemImage: "checkmark.circle.fill").foregroundStyle(.green) } }
            Section("Công cụ chính") {
                NavigationLink { QuickEditView() } label: { MenuRow(icon: "banknote", title: "Chỉnh nhanh & mở khóa", detail: "17 thông số, mở khóa 1 chạm") }
                NavigationLink { AdvancedView() } label: { MenuRow(icon: "crown", title: "VIP, IAP & sự kiện", detail: "Thẻ tháng, quảng cáo, Battle Pass") }
                NavigationLink { ManualEditorView() } label: { MenuRow(icon: "square.and.pencil", title: "Chỉnh từng mục", detail: "Cơ sở, món ăn, khách hàng, túi đồ") }
                NavigationLink { LimitEditorView() } label: { MenuRow(icon: "arrow.counterclockwise", title: "Lượt & giới hạn", detail: "Quét và reset Count, Limit, Ts") }
            }
            Section("Nội dung game") {
                NavigationLink { FusionView() } label: { MenuRow(icon: "puzzlepiece", title: "Bàn cờ ghép đồ", detail: "Cờ trạng thái, bóng nguyên tố, kho") }
                NavigationLink { TasksView() } label: { MenuRow(icon: "checklist", title: "Nhiệm vụ", detail: "4 nhóm nhiệm vụ và hoàn thành nhanh") }
                NavigationLink { LuckyCatView() } label: { MenuRow(icon: "cat", title: "Mèo Thần Tài", detail: "Phần thưởng và lịch sử") }
                NavigationLink { MinigameView() } label: { MenuRow(icon: "gamecontroller", title: "Sự kiện & Minigame", detail: "11 loại điểm và tiền tệ") }
                NavigationLink { ShopVIPView() } label: { MenuRow(icon: "storefront", title: "Cửa hàng & VIP", detail: "VIP, thẻ tháng, tiền shop") }
                NavigationLink { GatePassView() } label: { MenuRow(icon: "ticket", title: "Gate Pass", detail: "Xu đào lỗ, cấp và thử thách") }
                NavigationLink { EventRewardsView() } label: { MenuRow(icon: "gift", title: "Quà sự kiện", detail: "Quét và nhận thưởng hiện có") }
            }
            Section("Ứng dụng") { NavigationLink { SettingsView() } label: { MenuRow(icon: "gearshape", title: "Cài đặt", detail: "Tùy chọn công cụ hiển thị") } }
        }.navigationTitle("Chỉnh sửa").listStyle(.insetGrouped)
    }
    private var guideView: some View { List { Section("12 công cụ chỉnh sửa") { Text("Mỗi công cụ nằm trong tab Chỉnh sửa và chỉ hoạt động sau khi bạn chọn file PLIST.") }; Section("An toàn") { Text("App chỉ thao tác với file bạn chủ động chọn từ Files. Nó không truy cập dữ liệu riêng của game.") }; Section("Xuất file") { Text("Sau khi sửa, quay lại tab Tệp, chọn Đóng gói và xuất. File gốc không bị ghi đè.") } }.navigationTitle("Hướng dẫn") }
}

private struct QuickEditView: View {
    @EnvironmentObject var editor: SaveEditorModel
    var body: some View { Form { Section("Chỉnh sửa nhanh") { if !editor.isLoaded { MissingDataView() } else { ForEach(editor.quickFields) { field in ValueField(field: field) } } }; Section("Mở khóa siêu tốc") { ActionButton("Mở khóa toàn bộ món ăn", icon: "fork.knife") { editor.runMassAction("foods") }; ActionButton("Mở khóa cơ sở vật chất", icon: "chair") { editor.runMassAction("facilities") }; ActionButton("Mở khóa khu vực & phòng", icon: "door.left.hand.open") { editor.runMassAction("areas") }; ActionButton("Tối đa thân thiết khách hàng", icon: "heart") { editor.runMassAction("favor") }; ActionButton("Mở khóa nhân viên", icon: "person.3") { editor.runMassAction("staff") }; ActionButton("Hoàn thành toàn bộ nhiệm vụ", icon: "checkmark.seal") { editor.runMassAction("tasks") } } }.navigationTitle("Chỉnh nhanh") }
}

private struct AdvancedView: View {
    @EnvironmentObject var editor: SaveEditorModel
    @State private var adCount = ""; @State private var eventScore = ""; @State private var passScore = ""; @State private var nextReward = Date(); @State private var freeUntil = Date()
    var body: some View { Form { Section("VIP & Giftcode") { ActionButton("Gia hạn thẻ tháng (+30 ngày)", icon: "calendar.badge.plus") { editor.extendCard(superCard: false) }; ActionButton("Gia hạn thẻ tháng cao cấp (+30 ngày)", icon: "crown") { editor.extendCard(superCard: true) }; if editor.showAdFreeTool { ActionButton("Kích hoạt loại bỏ quảng cáo", icon: "nosign", tint: .red) { editor.activateAdFree() } }; ActionButton("Xóa lịch sử Giftcode", icon: "trash") { editor.resetGiftCodes() } }
        Section("Quảng cáo & sự kiện") { TextField("Số lần đã xem quảng cáo", text: $adCount).keyboardType(.numbersAndPunctuation); DatePicker("Lần nhận quảng cáo kế", selection: $nextReward); TextField("Điểm Double Eleven", text: $eventScore).keyboardType(.numbersAndPunctuation); DatePicker("Hạn quà miễn phí", selection: $freeUntil); TextField("Điểm Battle Pass", text: $passScore).keyboardType(.numbersAndPunctuation); Button("Lưu thiết lập") { editor.setAdvanced(adCount: adCount, nextReward: nextReward, eventScore: eventScore, freeUntil: freeUntil, passScore: passScore) } }
        Section("IAP & trang phục") { ActionButton("Mở khóa toàn bộ trang phục nhân viên", icon: "tshirt") { editor.unlockSkins() }; ForEach(editor.purchaseKeys(), id: \.self) { key in Button(key) { editor.unlockPurchases(key) } } } }.navigationTitle("VIP & sự kiện").onAppear { adCount = editor.advancedValue("rewardAdCount"); eventScore = editor.advancedValue("DoubleElevenScoreAll"); passScore = editor.gatePassScore(); nextReward = editor.advancedDate("rewardAdNextRewardTs"); freeUntil = editor.advancedDate("DoubleElevenFreeBuyTs") } }
}

private struct ManualEditorView: View {
    @EnvironmentObject var editor: SaveEditorModel; @State private var area: ManualArea = .facilities; @State private var rows: [EditableRow] = []
    var labels: [String] { switch area { case .facilities: ["Cấp độ", "Sở hữu (true/false)"]; case .foods: ["Thông thạo", "Đã mở", "Đột phá", "Doanh số"]; case .customers: ["Cấp hiện tại", "Điểm thân thiết"]; case .inventory: ["Số lượng"] } }
    var body: some View { VStack(spacing: 0) { Picker("Nhóm", selection: $area) { ForEach(ManualArea.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu).padding(.horizontal); EditableRowsView(rows: $rows, labels: labels, empty: "Không có dữ liệu trong nhóm này.") { editor.saveManualRows(rows, area: area) }.onChange(of: area) { _, _ in rows = editor.manualRows(area) }.onAppear { rows = editor.manualRows(area) } }.navigationTitle("Chỉnh từng mục") }
}

private struct LimitEditorView: View { @EnvironmentObject var editor: SaveEditorModel; @State private var rows: [EditableRow] = []; var body: some View { EditableRowsView(rows: $rows, labels: ["Giá trị (đặt 0 để reset)"], empty: "Không tìm thấy biến Count, Limit, Ts, Flag hoặc Purchase.") { editor.saveLimitRows(rows) }.navigationTitle("Lượt & giới hạn").onAppear { rows = editor.limitRows() } } }
private struct FusionView: View { @EnvironmentObject var editor: SaveEditorModel; @State private var rows: [EditableRow] = []; @State private var selected = "fusionElementBalls"; var body: some View { VStack { Picker("Dữ liệu", selection: $selected) { Text("Bóng nguyên tố").tag("fusionElementBalls"); Text("Kho ghép đồ").tag("fusionStockItems") }.pickerStyle(.segmented).padding(); Form { Section("Trạng thái") { Toggle("Mở panel ghép đồ", isOn: Binding(get: { editor.boolValue("openFusionPanelFlag") }, set: { editor.setBool("openFusionPanelFlag", $0) })); Toggle("Đồng bộ bàn cờ cũ", isOn: Binding(get: { editor.boolValue("legacyFusionBoardMigrated") }, set: { editor.setBool("legacyFusionBoardMigrated", $0) })); Toggle("Đồng bộ quà Mèo cũ", isOn: Binding(get: { editor.boolValue("legacyFusionLuckyCatRewardsMigrated") }, set: { editor.setBool("legacyFusionLuckyCatRewardsMigrated", $0) })); TextField("Rương vàng", text: Binding(get: { editor.value(for: "fusionGoldChestNum") }, set: { editor.updateValue($0, key: "fusionGoldChestNum") })).keyboardType(.numbersAndPunctuation) } }; EditableRowsView(rows: $rows, labels: ["Số lượng"], empty: "Không có dữ liệu.") { editor.saveFusionRows(rows) }.onAppear { rows = editor.fusionRows(selected) }.onChange(of: selected) { _, value in rows = editor.fusionRows(value) } }.navigationTitle("Ghép đồ") } }
private struct TasksView: View { @EnvironmentObject var editor: SaveEditorModel; @State private var area: TaskArea = .normal; @State private var rows: [EditableRow] = []; var body: some View { VStack { Picker("Nhóm", selection: $area) { ForEach(TaskArea.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).padding(); Form { Section("Tiến độ chính") { TextField("Chỉ mục nhiệm vụ hiện tại", text: Binding(get: { editor.value(for: "taskCurrentIndex") }, set: { editor.updateValue($0, key: "taskCurrentIndex") })).keyboardType(.numbersAndPunctuation); Button("Hoàn thành tất cả") { editor.maxTasks(area); rows = editor.taskRows(area) }.buttonStyle(.borderedProminent).tint(.orange) } }; EditableRowsView(rows: $rows, labels: ["Đã hoàn thành", "Mục tiêu"], empty: "Không có nhiệm vụ.") { editor.saveTaskRows(rows, area: area) }.onAppear { rows = editor.taskRows(area) }.onChange(of: area) { _, value in rows = editor.taskRows(value) } }.navigationTitle("Nhiệm vụ") } }
private struct LuckyCatView: View { @EnvironmentObject var editor: SaveEditorModel; @State private var mode = 0; @State private var rows: [EditableRow] = []; var body: some View { VStack { Picker("Dữ liệu", selection: $mode) { Text("Phần thưởng").tag(0); Text("Lịch sử").tag(1) }.pickerStyle(.segmented).padding(); EditableRowsView(rows: $rows, labels: [mode == 0 ? "Số lượng" : "Phần thưởng"], empty: mode == 0 ? "Không có phần thưởng Mèo Thần Tài." : "Không có lịch sử Mèo Thần Tài.") { if mode == 0 { editor.saveLuckyRewards(rows) } else { editor.saveLuckyRecords(rows) } }.onAppear { rows = editor.luckyRewards() }.onChange(of: mode) { _, value in rows = value == 0 ? editor.luckyRewards() : editor.luckyRecords() } }.navigationTitle("Mèo Thần Tài") } }
private struct MinigameView: View { @EnvironmentObject var editor: SaveEditorModel; var body: some View { Form { Section("Điểm & tiền tệ") { ForEach(editor.minigameFields) { ValueField(field: $0) } } }.navigationTitle("Sự kiện & Minigame") } }
private struct ShopVIPView: View { @EnvironmentObject var editor: SaveEditorModel; var body: some View { Form { Section("VIP & cửa hàng") { ForEach(editor.shopFields) { ValueField(field: $0) } }; Section("Thẻ tháng") { DatePicker("Hạn thẻ tháng thường", selection: Binding(get: { editor.cardEndDate(superCard: false) }, set: { editor.setCardEndDate($0, superCard: false) })); DatePicker("Hạn thẻ tháng cao cấp", selection: Binding(get: { editor.cardEndDate(superCard: true) }, set: { editor.setCardEndDate($0, superCard: true) })) } }.navigationTitle("Cửa hàng & VIP") } }
private struct GatePassView: View { @EnvironmentObject var editor: SaveEditorModel; var body: some View { Form { Section("Gate Pass") { TextField("Xu đào lỗ (holeCoins)", text: Binding(get: { editor.value(for: "holeCoins") }, set: { editor.updateValue($0, key: "holeCoins") })).keyboardType(.numbersAndPunctuation); Button("Tối đa cấp độ & qua ải mọi mùa") { editor.maxGatePass() }.buttonStyle(.borderedProminent).tint(.orange); Text("Đặt 100.000 điểm, hoàn thành nhiệm vụ và thử thách của mọi Gate Pass hiện có.").font(.footnote).foregroundStyle(.secondary) } }.navigationTitle("Gate Pass") } }
private struct EventRewardsView: View { @EnvironmentObject var editor: SaveEditorModel; var body: some View { VStack(spacing: 14) { Image(systemName: "gift.fill").font(.system(size: 36)).foregroundStyle(.orange); Text("Nhận quà sự kiện").font(.title3.bold()); Text("Quét các nhóm quà đăng nhập và sự kiện có trong save; phần thưởng chưa nhận được đánh dấu hoàn tất.").font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal); Button("Quét & nhận toàn bộ quà") { editor.claimEventRewards() }.buttonStyle(.borderedProminent).controlSize(.regular).tint(.orange) }.frame(maxWidth: .infinity, maxHeight: .infinity).padding().navigationTitle("Quà sự kiện") } }
private struct SettingsView: View { @EnvironmentObject var editor: SaveEditorModel; var body: some View { Form { Section("Giao diện") { Toggle("Hiển thị công cụ Loại bỏ quảng cáo", isOn: $editor.showAdFreeTool); Text("Khi bật, nút này xuất hiện trong mục VIP, IAP & sự kiện.").font(.footnote).foregroundStyle(.secondary) } }.navigationTitle("Cài đặt") } }

private struct ValueField: View { @EnvironmentObject var editor: SaveEditorModel; let field: EditField; var body: some View { VStack(alignment: .leading, spacing: 3) { TextField(field.title, text: Binding(get: { editor.value(for: field.key) }, set: { editor.updateValue($0, key: field.key) })).keyboardType(.numbersAndPunctuation); if !field.detail.isEmpty { Text(field.detail).font(.caption).foregroundStyle(.secondary) } } } }
private struct EditableRowsView: View { @Binding var rows: [EditableRow]; let labels: [String]; let empty: String; let save: () -> Void; var body: some View { Group { if rows.isEmpty { ContentUnavailableView(empty, systemImage: "tray") } else { List { ForEach($rows) { $row in EditableRowCard(row: $row, labels: labels) }; Section { Button("Lưu thay đổi", action: save).frame(maxWidth: .infinity).buttonStyle(.borderedProminent).tint(.orange) } } } } } }
private struct EditableRowCard: View { @Binding var row: EditableRow; let labels: [String]; var body: some View { VStack(alignment: .leading, spacing: 8) { Text(row.identifier.isEmpty ? "Không có ID" : row.identifier).font(.headline); Text(row.subtitle).font(.caption).foregroundStyle(.secondary); ForEach(labels.indices, id: \.self) { index in TextField(labels[index], text: Binding(get: { row.values.indices.contains(index) ? row.values[index] : "" }, set: { value in while row.values.count <= index { row.values.append("") }; row.values[index] = value })).textFieldStyle(.roundedBorder).keyboardType(.numbersAndPunctuation) } }.padding(.vertical, 4) } }
private struct MenuRow: View { let icon: String; let title: String; let detail: String; var body: some View { Label { VStack(alignment: .leading, spacing: 2) { Text(title).font(.body); Text(detail).font(.caption).foregroundStyle(.secondary) } } icon: { Image(systemName: icon).font(.body).foregroundStyle(.orange) } } }
private struct ActionButton: View { let title: String; let icon: String; var tint: Color = .orange; let action: () -> Void; init(_ title: String, icon: String, tint: Color = .orange, action: @escaping () -> Void) { self.title = title; self.icon = icon; self.tint = tint; self.action = action }; var body: some View { Button(action: action) { Label(title, systemImage: icon) }.tint(tint) } }
private struct MissingDataView: View { var body: some View { ContentUnavailableView("Chưa có dữ liệu", systemImage: "doc", description: Text("Hãy nhập PLIST ở tab Tệp.")) } }
private struct GlassCard<Content: View>: View { @ViewBuilder var content: Content; var body: some View { VStack(alignment: .leading, spacing: 6) { content }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(.thinMaterial, in: .rect(cornerRadius: 18)) } }

private struct KeyboardDoneModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Xong") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
    }
}
