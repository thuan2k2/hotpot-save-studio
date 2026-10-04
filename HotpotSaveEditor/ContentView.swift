import SwiftUI
import UniformTypeIdentifiers
import UIKit

private enum StudioTab: Hashable { case files, editor, guide }

struct ContentView: View {
    @EnvironmentObject private var editor: SaveEditorModel
    @State private var importing = false
    @State private var exporting = false
    @State private var exportDocument: BinaryPlistDocument?
    @State private var askToClearAfterExport = false
    @State private var askToClearNow = false
    @State private var selectedTab: StudioTab = .files

    private var importTypes: [UTType] {
        [.data, UTType(filenameExtension: "plist") ?? .data, UTType(filenameExtension: "bplist") ?? .data]
    }

    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case .files: fileView
                case .editor: editMenu
                case .guide: guideView
                }
            }
            .toolbar { ToolbarItemGroup(placement: .topBarTrailing) { NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }; Menu { Button("Xóa dữ liệu giải mã", role: .destructive) { askToClearNow = true } } label: { Image(systemName: "ellipsis.circle") } } }
        }
        .modifier(KeyboardDoneModifier())
        .safeAreaInset(edge: .bottom, spacing: 0) { StudioTabBar(selection: $selectedTab) }
        .preferredColorScheme(.dark)
        .tint(.orange)
        // Keep the layout compact even when the phone has an enlarged accessibility text setting.
        .dynamicTypeSize(.xSmall ... .large)
        .fileImporter(isPresented: $importing, allowedContentTypes: importTypes, allowsMultipleSelection: false) { result in if case .success(let urls) = result, let url = urls.first { editor.importPlist(from: url) } }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .data, defaultFilename: "hotpot_repacked.bplist") { result in switch result { case .success: askToClearAfterExport = true; case .failure(let error): editor.errorMessage = "Không thể xuất file: \(error.localizedDescription)" } }
        .alert("Xóa dữ liệu giải mã?", isPresented: $askToClearAfterExport) { Button("Giữ lại", role: .cancel) { editor.finishExport(deleteWorkspace: false) }; Button("Xóa", role: .destructive) { editor.finishExport(deleteWorkspace: true) } } message: { Text("Đã xuất hotpot_repacked.bplist. Bạn có muốn xóa dữ liệu giải mã trong vùng làm việc của ứng dụng không?") }
        .alert("Xóa dữ liệu giải mã?", isPresented: $askToClearNow) { Button("Hủy", role: .cancel) {}; Button("Xóa", role: .destructive) { editor.clearWorkspace() } } message: { Text("Chỉ xóa dữ liệu nội bộ của app, không ảnh hưởng file gốc trong Files.") }
        .alert("Lỗi", isPresented: Binding(get: { editor.errorMessage != nil }, set: { if !$0 { editor.errorMessage = nil } })) { Button("Đóng", role: .cancel) {} } message: { Text(editor.errorMessage ?? "") }
        .alert("Hoàn tất", isPresented: Binding(get: { editor.infoMessage != nil }, set: { if !$0 { editor.infoMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(editor.infoMessage ?? "") }
    }

    private var fileView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                StudioSectionTitle("Dữ liệu save")
                StudioCard {
                    Button { importing = true } label: { StudioRow(icon: "folder", title: editor.isLoaded ? editor.importedFileName : "Chọn file PLIST", detail: editor.isLoaded ? "Đã sẵn sàng chỉnh sửa" : "Chọn com.lxqd.hotpotiver.plist từ Files", tint: editor.isLoaded ? .green : .orange) }.buttonStyle(.plain)
                }
                StudioSectionTitle("Thao tác")
                StudioCard {
                    if editor.isLoaded {
                        Button { exportDocument = editor.prepareExport(); exporting = exportDocument != nil } label: { StudioRow(icon: "arrow.up.doc", title: "Đóng gói và xuất", detail: "Tạo hotpot_repacked.bplist", tint: .orange) }.buttonStyle(.plain)
                        Divider().overlay(Color.white.opacity(0.14)).padding(.leading, 60)
                    }
                    StudioRow(icon: editor.hasWorkspace ? "checkmark.circle.fill" : "circle", title: "Dữ liệu giải mã", detail: editor.hasWorkspace ? "Đang được lưu trong ứng dụng" : "Chưa có dữ liệu giải mã", tint: editor.hasWorkspace ? .green : .secondary, showsChevron: false)
                }
                Text("Ứng dụng chỉ xử lý file bạn tự chọn trong Files. File gốc không bị ghi đè.").font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 4)
            }.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 28)
        }.background(Color.black).navigationTitle("Tệp").navigationBarTitleDisplayMode(.inline)
    }

    private var editMenu: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if !editor.isLoaded { StudioNotice("Hãy chọn file PLIST ở tab Tệp trước khi chỉnh sửa.") }
                StudioSectionTitle("Công cụ chính")
                StudioCard { StudioLinks([("banknote", "Chỉnh nhanh & mở khóa", "Tiền tệ, cấp độ và mở khóa nhanh", AnyView(QuickEditView())), ("crown", "VIP, gói nạp & sự kiện", "Thẻ tháng, quảng cáo và thẻ mùa giải", AnyView(AdvancedView())), ("square.and.pencil", "Chỉnh sửa từng mục", "Cơ sở, món ăn, khách hàng và túi đồ", AnyView(ManualEditorView())), ("arrow.counterclockwise", "Lượt mua & giới hạn", "Quét và đặt lại lượt, giới hạn, thời gian", AnyView(LimitEditorView()))]) }
                StudioSectionTitle("Nội dung game")
                StudioCard { StudioLinks([("puzzlepiece", "Bàn cờ ghép đồ", "Bóng nguyên tố và kho ghép đồ", AnyView(FusionView())), ("checklist", "Nhiệm vụ", "Nhiệm vụ thường, ngày, hoạt động và chương", AnyView(TasksView())), ("cat", "Mèo Thần Tài", "Phần thưởng và lịch sử tương tác", AnyView(LuckyCatView())), ("gamecontroller", "Sự kiện & trò chơi nhỏ", "Điểm và tiền tệ sự kiện", AnyView(MinigameView())), ("storefront", "Cửa hàng & VIP", "Thẻ tháng và tiền tệ cửa hàng", AnyView(ShopVIPView())), ("ticket", "Thẻ mùa giải", "Xu đào lỗ, cấp độ và thử thách", AnyView(GatePassView())), ("gift", "Quà sự kiện", "Đánh dấu nhận các phần thưởng hiện có", AnyView(EventRewardsView()))]) }
            }.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 28)
        }.background(Color.black).navigationTitle("Chỉnh sửa").navigationBarTitleDisplayMode(.inline)
    }
    private var guideView: some View {
        ScrollView { VStack(alignment: .leading, spacing: 26) { StudioSectionTitle("Hướng dẫn sử dụng"); StudioCard { StudioRow(icon: "1.circle", title: "Chọn file save", detail: "Chọn com.lxqd.hotpotiver.plist trong Files", tint: .orange, showsChevron: false); Divider().overlay(Color.white.opacity(0.14)).padding(.leading, 60); StudioRow(icon: "2.circle", title: "Chỉnh sửa dữ liệu", detail: "Mở các nhóm công cụ tại tab Chỉnh sửa", tint: .orange, showsChevron: false); Divider().overlay(Color.white.opacity(0.14)).padding(.leading, 60); StudioRow(icon: "3.circle", title: "Xuất file mới", detail: "Đóng gói thành hotpot_repacked.bplist", tint: .orange, showsChevron: false) }; StudioSectionTitle("An toàn"); StudioNotice("Ứng dụng chỉ thao tác với file bạn tự chọn và không truy cập dữ liệu riêng của game.") }.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 28) }.background(Color.black).navigationTitle("Hướng dẫn").navigationBarTitleDisplayMode(.inline)
    }
}

private struct QuickEditView: View {
    @EnvironmentObject var editor: SaveEditorModel
    var body: some View { Form { Section("Chỉnh sửa nhanh") { if !editor.isLoaded { MissingDataView() } else { ForEach(editor.quickFields) { field in ValueField(field: field) } } }; Section("Mở khóa siêu tốc") { ActionButton("Mở khóa toàn bộ món ăn", icon: "fork.knife") { editor.runMassAction("foods") }; ActionButton("Mở khóa cơ sở vật chất", icon: "chair") { editor.runMassAction("facilities") }; ActionButton("Mở khóa khu vực & phòng", icon: "door.left.hand.open") { editor.runMassAction("areas") }; ActionButton("Tối đa thân thiết khách hàng", icon: "heart") { editor.runMassAction("favor") }; ActionButton("Mở khóa nhân viên", icon: "person.3") { editor.runMassAction("staff") }; ActionButton("Hoàn thành toàn bộ nhiệm vụ", icon: "checkmark.seal") { editor.runMassAction("tasks") } } }.navigationTitle("Chỉnh nhanh") }
}

private struct AdvancedView: View {
    @EnvironmentObject var editor: SaveEditorModel
    @State private var adCount = ""; @State private var eventScore = ""; @State private var passScore = ""; @State private var nextReward = Date(); @State private var freeUntil = Date()
    var body: some View { Form { Section("VIP & Giftcode") { ActionButton("Gia hạn thẻ tháng (+30 ngày)", icon: "calendar.badge.plus") { editor.extendCard(superCard: false) }; ActionButton("Gia hạn thẻ tháng cao cấp (+30 ngày)", icon: "crown") { editor.extendCard(superCard: true) }; if editor.showAdFreeTool { ActionButton("Kích hoạt loại bỏ quảng cáo", icon: "nosign", tint: .red) { editor.activateAdFree() } }; ActionButton("Xóa lịch sử Giftcode", icon: "trash") { editor.resetGiftCodes() } }
        Section("Quảng cáo & sự kiện") { TextField("Số lần đã xem quảng cáo", text: $adCount).keyboardType(.numbersAndPunctuation); DatePicker("Thời điểm nhận quảng cáo tiếp theo", selection: $nextReward); TextField("Điểm sự kiện Lễ hội", text: $eventScore).keyboardType(.numbersAndPunctuation); DatePicker("Hạn nhận gói miễn phí sự kiện", selection: $freeUntil); TextField("Tiến độ điểm thẻ mùa giải", text: $passScore).keyboardType(.numbersAndPunctuation); Button("Lưu thiết lập") { editor.setAdvanced(adCount: adCount, nextReward: nextReward, eventScore: eventScore, freeUntil: freeUntil, passScore: passScore) } }
        Section("Gói nạp & trang phục") { ActionButton("Mở khóa toàn bộ trang phục nhân viên", icon: "tshirt") { editor.unlockSkins() }; ForEach(editor.purchaseKeys(), id: \.self) { key in Button("Mở khóa gói nạp") { editor.unlockPurchases(key) } } } }.navigationTitle("VIP & sự kiện").onAppear { adCount = editor.advancedValue("rewardAdCount"); eventScore = editor.advancedValue("DoubleElevenScoreAll"); passScore = editor.gatePassScore(); nextReward = editor.advancedDate("rewardAdNextRewardTs"); freeUntil = editor.advancedDate("DoubleElevenFreeBuyTs") } }
}

private struct ManualEditorView: View {
    @EnvironmentObject var editor: SaveEditorModel; @State private var area: ManualArea = .facilities; @State private var rows: [EditableRow] = []
    var labels: [String] { switch area { case .facilities: ["Cấp độ", "Sở hữu (true/false)"]; case .foods: ["Thông thạo", "Đã mở", "Đột phá", "Doanh số"]; case .customers: ["Cấp hiện tại", "Điểm thân thiết"]; case .inventory: ["Số lượng"] } }
    var body: some View { VStack(spacing: 0) { Picker("Nhóm", selection: $area) { ForEach(ManualArea.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu).padding(.horizontal); EditableRowsView(rows: $rows, labels: labels, empty: "Không có dữ liệu trong nhóm này.") { editor.saveManualRows(rows, area: area) }.onChange(of: area) { _, _ in rows = editor.manualRows(area) }.onAppear { rows = editor.manualRows(area) } }.navigationTitle("Chỉnh từng mục") }
}

private struct LimitEditorView: View { @EnvironmentObject var editor: SaveEditorModel; @State private var rows: [EditableRow] = []; var body: some View { EditableRowsView(rows: $rows, labels: ["Giá trị (đặt 0 để đặt lại)"], empty: "Không tìm thấy dữ liệu lượt mua, giới hạn hoặc thời gian chờ.") { editor.saveLimitRows(rows) }.navigationTitle("Lượt & giới hạn").onAppear { rows = editor.limitRows() } } }
private struct FusionView: View { @EnvironmentObject var editor: SaveEditorModel; @State private var rows: [EditableRow] = []; @State private var selected = "fusionElementBalls"; var body: some View { VStack { Picker("Dữ liệu", selection: $selected) { Text("Bóng nguyên tố").tag("fusionElementBalls"); Text("Kho ghép đồ").tag("fusionStockItems") }.pickerStyle(.segmented).padding(); Form { Section("Trạng thái") { Toggle("Mở panel ghép đồ", isOn: Binding(get: { editor.boolValue("openFusionPanelFlag") }, set: { editor.setBool("openFusionPanelFlag", $0) })); Toggle("Đồng bộ bàn cờ cũ", isOn: Binding(get: { editor.boolValue("legacyFusionBoardMigrated") }, set: { editor.setBool("legacyFusionBoardMigrated", $0) })); Toggle("Đồng bộ quà Mèo cũ", isOn: Binding(get: { editor.boolValue("legacyFusionLuckyCatRewardsMigrated") }, set: { editor.setBool("legacyFusionLuckyCatRewardsMigrated", $0) })); TextField("Rương vàng", text: Binding(get: { editor.value(for: "fusionGoldChestNum") }, set: { editor.updateValue($0, key: "fusionGoldChestNum") })).keyboardType(.numbersAndPunctuation) } }; EditableRowsView(rows: $rows, labels: ["Số lượng"], empty: "Không có dữ liệu.") { editor.saveFusionRows(rows) }.onAppear { rows = editor.fusionRows(selected) }.onChange(of: selected) { _, value in rows = editor.fusionRows(value) } }.navigationTitle("Ghép đồ") } }
private struct TasksView: View { @EnvironmentObject var editor: SaveEditorModel; @State private var area: TaskArea = .normal; @State private var rows: [EditableRow] = []; var body: some View { VStack { Picker("Nhóm", selection: $area) { ForEach(TaskArea.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).padding(); Form { Section("Tiến độ chính") { TextField("Chỉ mục nhiệm vụ hiện tại", text: Binding(get: { editor.value(for: "taskCurrentIndex") }, set: { editor.updateValue($0, key: "taskCurrentIndex") })).keyboardType(.numbersAndPunctuation); Button("Hoàn thành tất cả") { editor.maxTasks(area); rows = editor.taskRows(area) }.buttonStyle(.borderedProminent).tint(.orange) } }; EditableRowsView(rows: $rows, labels: ["Đã hoàn thành", "Mục tiêu"], empty: "Không có nhiệm vụ.") { editor.saveTaskRows(rows, area: area) }.onAppear { rows = editor.taskRows(area) }.onChange(of: area) { _, value in rows = editor.taskRows(value) } }.navigationTitle("Nhiệm vụ") } }
private struct LuckyCatView: View { @EnvironmentObject var editor: SaveEditorModel; @State private var mode = 0; @State private var rows: [EditableRow] = []; var body: some View { VStack { Picker("Dữ liệu", selection: $mode) { Text("Phần thưởng").tag(0); Text("Lịch sử").tag(1) }.pickerStyle(.segmented).padding(); EditableRowsView(rows: $rows, labels: [mode == 0 ? "Số lượng" : "Phần thưởng"], empty: mode == 0 ? "Không có phần thưởng Mèo Thần Tài." : "Không có lịch sử Mèo Thần Tài.") { if mode == 0 { editor.saveLuckyRewards(rows) } else { editor.saveLuckyRecords(rows) } }.onAppear { rows = editor.luckyRewards() }.onChange(of: mode) { _, value in rows = value == 0 ? editor.luckyRewards() : editor.luckyRecords() } }.navigationTitle("Mèo Thần Tài") } }
private struct MinigameView: View { @EnvironmentObject var editor: SaveEditorModel; var body: some View { Form { Section("Điểm & tiền tệ") { ForEach(editor.minigameFields) { ValueField(field: $0) } } }.navigationTitle("Sự kiện & Minigame") } }
private struct ShopVIPView: View { @EnvironmentObject var editor: SaveEditorModel; var body: some View { Form { Section("VIP & cửa hàng") { ForEach(editor.shopFields) { ValueField(field: $0) } }; Section("Thẻ tháng") { DatePicker("Hạn thẻ tháng thường", selection: Binding(get: { editor.cardEndDate(superCard: false) }, set: { editor.setCardEndDate($0, superCard: false) })); DatePicker("Hạn thẻ tháng cao cấp", selection: Binding(get: { editor.cardEndDate(superCard: true) }, set: { editor.setCardEndDate($0, superCard: true) })) } }.navigationTitle("Cửa hàng & VIP") } }
private struct GatePassView: View { @EnvironmentObject var editor: SaveEditorModel; var body: some View { Form { Section("Thẻ mùa giải") { TextField("Xu đào lỗ", text: Binding(get: { editor.value(for: "holeCoins") }, set: { editor.updateValue($0, key: "holeCoins") })).keyboardType(.numbersAndPunctuation); Button("Tối đa cấp độ & qua ải mọi mùa") { editor.maxGatePass() }.buttonStyle(.borderedProminent).tint(.orange); Text("Đặt 100.000 điểm, hoàn thành nhiệm vụ và thử thách của mọi thẻ mùa giải hiện có.").font(.footnote).foregroundStyle(.secondary) } }.navigationTitle("Thẻ mùa giải") } }
private struct EventRewardsView: View { @EnvironmentObject var editor: SaveEditorModel; var body: some View { VStack(spacing: 14) { Image(systemName: "gift.fill").font(.system(size: 36)).foregroundStyle(.orange); Text("Nhận quà sự kiện").font(.title3.bold()); Text("Quét các nhóm quà đăng nhập và sự kiện có trong save; phần thưởng chưa nhận được đánh dấu hoàn tất.").font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal); Button("Quét & nhận toàn bộ quà") { editor.claimEventRewards() }.buttonStyle(.borderedProminent).controlSize(.regular).tint(.orange) }.frame(maxWidth: .infinity, maxHeight: .infinity).padding().navigationTitle("Quà sự kiện") } }
private struct SettingsView: View { @EnvironmentObject var editor: SaveEditorModel; var body: some View { Form { Section("Giao diện") { Toggle("Hiển thị công cụ loại bỏ quảng cáo", isOn: $editor.showAdFreeTool); Text("Khi bật, nút này xuất hiện trong mục VIP, gói nạp và sự kiện.").font(.footnote).foregroundStyle(.secondary) } }.navigationTitle("Cài đặt") } }

private struct ValueField: View { @EnvironmentObject var editor: SaveEditorModel; let field: EditField; var body: some View { TextField(field.title, text: Binding(get: { editor.value(for: field.key) }, set: { editor.updateValue($0, key: field.key) })).keyboardType(.numbersAndPunctuation) } }
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

private struct StudioSectionTitle: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View { Text(title).font(.title3.weight(.bold)).foregroundStyle(.white).padding(.horizontal, 4) }
}

private struct StudioCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(spacing: 0) { content }.background(Color.white.opacity(0.12), in: .rect(cornerRadius: 26)).overlay { RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.06), lineWidth: 1) } }
}

private struct StudioRow: View {
    let icon: String; let title: String; let detail: String; var tint: Color = .orange; var showsChevron = true
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 20, weight: .medium)).foregroundStyle(tint).frame(width: 42, height: 42).background(tint.opacity(0.16), in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.body.weight(.semibold)).foregroundStyle(.white).lineLimit(1); Text(detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
            Spacer(minLength: 8)
            if showsChevron { Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary) }
        }.padding(.horizontal, 16).padding(.vertical, 13).contentShape(.rect)
    }
}

private struct StudioLinks: View {
    let entries: [(String, String, String, AnyView)]
    init(_ entries: [(String, String, String, AnyView)]) { self.entries = entries }
    var body: some View {
        VStack(spacing: 0) {
            ForEach(entries.indices, id: \.self) { index in
                NavigationLink { entries[index].3 } label: { StudioRow(icon: entries[index].0, title: entries[index].1, detail: entries[index].2) }.buttonStyle(.plain)
                if index < entries.count - 1 { Divider().overlay(Color.white.opacity(0.14)).padding(.leading, 72) }
            }
        }
    }
}

private struct StudioNotice: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.subheadline).foregroundStyle(.secondary).padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.08), in: .rect(cornerRadius: 18)) }
}

private struct StudioTabBar: View {
    @Binding var selection: StudioTab
    var body: some View {
        HStack(spacing: 6) {
            StudioTabButton(tab: .files, title: "Tệp", icon: "folder.fill", selection: $selection)
            StudioTabButton(tab: .editor, title: "Chỉnh sửa", icon: "slider.horizontal.3", selection: $selection)
            StudioTabButton(tab: .guide, title: "Hướng dẫn", icon: "questionmark.circle.fill", selection: $selection)
        }.padding(6).background(.ultraThinMaterial, in: Capsule()).overlay { Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1) }.padding(.horizontal, 20).padding(.bottom, 8).padding(.top, 4)
    }
}

private struct StudioTabButton: View {
    let tab: StudioTab; let title: String; let icon: String; @Binding var selection: StudioTab
    var body: some View { Button { selection = tab } label: { VStack(spacing: 3) { Image(systemName: icon).font(.body.weight(.medium)); Text(title).font(.caption.weight(.medium)) }.foregroundStyle(selection == tab ? Color.orange : Color.white).frame(maxWidth: .infinity).padding(.vertical, 8).background(selection == tab ? Color.white.opacity(0.14) : .clear, in: Capsule()) }.buttonStyle(.plain) }
}
