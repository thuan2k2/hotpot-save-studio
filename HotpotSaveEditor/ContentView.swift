import SwiftUI
import UniformTypeIdentifiers
import UIKit

private enum StudioTab: Hashable { case home, quick, editor, settings }

struct ContentView: View {
    @EnvironmentObject private var editor: SaveEditorModel
    @State private var importing = false
    @State private var exporting = false
    @State private var exportDocument: BinaryPlistDocument?
    @State private var askToClearNow = false
    @State private var selectedTab: StudioTab = .home
    @State private var navigationPath = NavigationPath()
    @State private var catalogExport: LuckyCatalogDocument?
    @State private var importingCatalog = false

    private var importTypes: [UTType] {
        [.data, UTType(filenameExtension: "plist") ?? .data, UTType(filenameExtension: "bplist") ?? .data]
    }

    var body: some View {
        // Keep the tab bar out of the scroll-view layout.  safeAreaInset made
        // its position depend on the currently visible navigation container on
        // iOS 26, which left unused black space beneath it on some devices.
        ZStack(alignment: .bottom) {
            NavigationStack(path: $navigationPath) {
                Group {
                    switch selectedTab {
                    case .home: fileView
                    case .quick: QuickEditView(onExport: exportNow)
                    case .editor: editMenu
                    case .settings: SettingsHomeView(askToClear: $askToClearNow, catalogExport: $catalogExport, importingCatalog: $importingCatalog)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // NavigationLink(destination:) keeps its own presentation state.
            // Recreate the stack when selecting a root tab so a destination
            // such as "VIP & thẻ tháng" cannot remain above the new tab.
            .id(selectedTab)

            StudioTabBar(selection: tabBinding)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        }
        // A ZStack otherwise takes the intrinsic height of its children here.
        // Expanding the root is what makes the scroll viewport and tab bar use
        // the complete iPhone window rather than a vertically centred section.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .modifier(KeyboardDoneModifier())
        .preferredColorScheme(preferredScheme)
        .tint(.orange)
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .data, defaultFilename: "hotpot_repacked.bplist") { result in switch result { case .success: editor.finishExport(); case .failure(let error): editor.errorMessage = "Không thể xuất file: \(error.localizedDescription)" } }
        .fileExporter(isPresented: Binding(get: { catalogExport != nil }, set: { if !$0 { catalogExport = nil } }), document: catalogExport, contentType: .json, defaultFilename: "du-lieu-meo-than-tai.json") { _ in catalogExport = nil }
        .fileImporter(isPresented: $importingCatalog, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): importLuckyCatalog(from: url)
            case .failure(let error): editor.errorMessage = "Không thể chọn dữ liệu Mèo Thần Tài: \(error.localizedDescription)"
            }
        }
        .alert("Xóa dữ liệu giải mã?", isPresented: $askToClearNow) {
            Button("Hủy", role: .cancel) {}
            Button("Xóa", role: .destructive) { editor.clearWorkspace() }
        } message: { Text("Chỉ xóa dữ liệu nội bộ của app, không ảnh hưởng file gốc trong Files.") }
        .alert("Lỗi", isPresented: errorPresented) { Button("Đóng", role: .cancel) {} } message: { Text(editor.errorMessage ?? "") }
        .alert("Hoàn tất", isPresented: infoPresented) { Button("OK", role: .cancel) {} } message: { Text(editor.infoMessage ?? "") }
    }

    private var tabBinding: Binding<StudioTab> { Binding(get: { selectedTab }, set: { newTab in guard newTab != selectedTab else { return }; navigationPath = NavigationPath(); withAnimation(.snappy(duration: 0.28, extraBounce: 0.08)) { selectedTab = newTab } }) }
    private var errorPresented: Binding<Bool> { Binding(get: { editor.errorMessage != nil }, set: { if !$0 { editor.errorMessage = nil } }) }
    private var infoPresented: Binding<Bool> { Binding(get: { editor.infoMessage != nil }, set: { if !$0 { editor.infoMessage = nil } }) }
    private func exportNow() {
        guard let document = editor.prepareExport() else { return }
        // The document must be installed in state before presenting the system
        // Files sheet. Deferring the presentation by one run-loop prevents
        // iOS from discarding the exporter when a button also ends editing.
        exportDocument = document
        DispatchQueue.main.async { exporting = true }
    }
    private func importLuckyCatalog(from url: URL) {
        do {
            let acquired = url.startAccessingSecurityScopedResource()
            defer { if acquired { url.stopAccessingSecurityScopedResource() } }
            let catalog = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
            editor.importItemCatalog(catalog)
        } catch { editor.errorMessage = "Không thể nhập dữ liệu Mèo Thần Tài: \(error.localizedDescription)" }
    }
    private var preferredScheme: ColorScheme? {
        switch editor.appearance { case "Sáng": return .light; case "Tối": return .dark; default: return nil }
    }

    private var fileView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                StudioPageHeader("Trang chủ", askToClear: $askToClearNow, showsSettings: false)
                StudioSectionTitle("Dữ liệu save")
                StudioCard {
                    Button { importing = true } label: { StudioRow(icon: "folder", title: editor.isLoaded ? editor.importedFileName : "Chọn file PLIST", detail: editor.isLoaded ? "Đã sẵn sàng chỉnh sửa" : "Chọn com.lxqd.hotpotiver.plist từ Files", tint: editor.isLoaded ? .green : .orange) }.buttonStyle(.plain)
                }
                StudioSectionTitle("Thao tác")
                StudioCard {
                    if editor.isLoaded {
                        Button(action: exportNow) { StudioRow(icon: "arrow.up.doc", title: "Đóng gói và xuất", detail: "Tạo hotpot_repacked.bplist và tự xóa dữ liệu đã giải mã", tint: .orange) }.buttonStyle(.plain)
                        Divider().overlay(Color.primary.opacity(0.14)).padding(.leading, 60)
                    }
                    StudioRow(icon: editor.hasWorkspace ? "checkmark.circle.fill" : "circle", title: "Dữ liệu giải mã", detail: editor.hasWorkspace ? "Đang được lưu trong ứng dụng" : "Chưa có dữ liệu giải mã", tint: editor.hasWorkspace ? .green : .secondary, showsChevron: false)
                }
                Text("Ứng dụng chỉ xử lý file bạn tự chọn trong Files. File gốc không bị ghi đè.").font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 4)
            }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 96)
        }
        .background(Color(uiColor: .systemBackground))
        .toolbar(.hidden, for: .navigationBar)
        .fileImporter(isPresented: $importing, allowedContentTypes: importTypes, allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { editor.importPlist(from: url) }
        }
    }

    private var editMenu: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                StudioPageHeader("Chỉnh sửa", askToClear: $askToClearNow, showsSettings: false)
                if !editor.isLoaded { StudioNotice("Hãy chọn file PLIST ở tab Tệp trước khi chỉnh sửa.") }
                StudioSectionTitle("Công cụ chính")
                StudioCard { StudioLinks([("crown", "VIP & thẻ tháng", "Gia hạn thẻ tháng thêm 30 ngày", AnyView(AdvancedView())), ("square.and.pencil", "Chỉnh sửa từng mục", "Cơ sở, món ăn, khách hàng và túi đồ", AnyView(ManualEditorView()))]) }
                StudioSectionTitle("Nội dung game")
                StudioCard { StudioLinks([("cat", "Mèo Thần Tài", "Phần thưởng và lịch sử tương tác", AnyView(LuckyCatView())), ("gamecontroller", "Sự kiện & trò chơi nhỏ", "Điểm và tiền tệ sự kiện", AnyView(MinigameView())), ("storefront", "Cửa hàng & VIP", "Điểm VIP, thẻ tháng và tiền tệ cửa hàng", AnyView(ShopVIPView())), ("ticket", "Thẻ mùa giải", "Xu đào lỗ, cấp độ và thử thách", AnyView(GatePassView())), ("gift", "Quà sự kiện", "Đánh dấu nhận các phần thưởng hiện có", AnyView(EventRewardsView()))]) }
            }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 96)
        }.background(Color(uiColor: .systemBackground)).toolbar(.hidden, for: .navigationBar)
    }
}

private struct QuickEditView: View {
    @EnvironmentObject var editor: SaveEditorModel
    let onExport: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Chỉnh sửa nhanh").font(.title3.weight(.bold))
                Text("Tiền tệ, điểm và tiến độ tài khoản").font(.subheadline).foregroundStyle(.secondary)
                if !editor.isLoaded { MissingDataView() }
                else {
                    StudioCard {
                        ForEach(editor.quickFields.indices, id: \.self) { index in
                            QuickValueRow(field: editor.quickFields[index])
                            if index < editor.quickFields.count - 1 { Divider().overlay(Color.primary.opacity(0.14)).padding(.leading, 16) }
                        }
                    }
                }
                Text("Mở khóa siêu tốc").font(.title3.weight(.bold)).padding(.top, 6)
                StudioCard { VStack(spacing: 0) { ActionButton("Mở khóa toàn bộ món ăn", icon: "fork.knife") { editor.runMassAction("foods") }; Divider().overlay(Color.primary.opacity(0.14)); ActionButton("Mở khóa cơ sở vật chất", icon: "chair") { editor.runMassAction("facilities") }; Divider().overlay(Color.primary.opacity(0.14)); ActionButton("Mở khóa khu vực & phòng", icon: "door.left.hand.open") { editor.runMassAction("areas") }; Divider().overlay(Color.primary.opacity(0.14)); ActionButton("Tối đa thân thiết khách hàng", icon: "heart") { editor.runMassAction("favor") }; Divider().overlay(Color.primary.opacity(0.14)); ActionButton("Mở khóa nhân viên", icon: "person.3") { editor.runMassAction("staff") }; Divider().overlay(Color.primary.opacity(0.14)); ActionButton("Hoàn thành toàn bộ nhiệm vụ", icon: "checkmark.seal") { editor.runMassAction("tasks") } } }
                HStack(spacing: 10) {
                    Button("Lưu các chỉnh sửa") { editor.infoMessage = "Đã lưu các chỉnh sửa trong vùng làm việc." }.buttonStyle(.bordered).tint(.orange)
                    Button("Đóng gói và xuất", action: onExport).buttonStyle(.borderedProminent).tint(.orange)
                }.frame(maxWidth: .infinity)
                Button("Đưa về gốc", role: .destructive) { editor.resetToOriginal() }.frame(maxWidth: .infinity).buttonStyle(.bordered)
            // The persistent tab pill occupies part of the lower safe area.
            // Leave room after the final row so it can always be scrolled into view.
            }.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 112)
        }.background(Color(uiColor: .systemBackground)).navigationTitle("Chỉnh nhanh").navigationBarTitleDisplayMode(.inline)
    }
}

private struct AdvancedView: View {
    @EnvironmentObject var editor: SaveEditorModel
    @State private var previousExpiry = Date()
    @State private var updatedExpiry = Date()

    var body: some View {
        Form {
            Section("Thẻ tháng") {
                LabeledContent("Thời hạn hiện tại") {
                    Text(previousExpiry.formatted(date: .abbreviated, time: .shortened))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Thời hạn sau chỉnh sửa") {
                    Text(updatedExpiry.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.trailing)
                }
                Button("Gia hạn thẻ tháng (+30 ngày)") {
                    editor.extendCard(superCard: false)
                    updatedExpiry = editor.cardEndDate(superCard: false)
                }
                .tint(.orange)
            }
        }
        .navigationTitle("VIP & thẻ tháng")
        .onAppear {
            let current = editor.cardEndDate(superCard: false)
            previousExpiry = current
            updatedExpiry = current
        }
    }
}

private struct ManualEditorView: View {
    @EnvironmentObject var editor: SaveEditorModel; @State private var area: ManualArea = .facilities; @State private var rows: [EditableRow] = []
    var labels: [String] { switch area { case .facilities: ["Cấp độ", "Sở hữu (true/false)"]; case .foods: ["Thông thạo", "Đã mở", "Đột phá", "Doanh số"]; case .customers: ["Cấp hiện tại", "Điểm thân thiết"]; case .inventory: ["Số lượng"] } }
    var body: some View { VStack(spacing: 0) { Picker("Nhóm", selection: $area) { ForEach(ManualArea.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu).padding(.horizontal); EditableRowsView(rows: $rows, labels: labels, empty: "Không có dữ liệu trong nhóm này.") { editor.saveManualRows(rows, area: area) }.onChange(of: area) { _, _ in rows = editor.manualRows(area) }.onAppear { rows = editor.manualRows(area) } }.navigationTitle("Chỉnh từng mục").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Lưu") { editor.saveManualRows(rows, area: area) } } } }
}

private struct LimitEditorView: View { @EnvironmentObject var editor: SaveEditorModel; @State private var rows: [EditableRow] = []; var body: some View { EditableRowsView(rows: $rows, labels: ["Giá trị (đặt 0 để đặt lại)"], empty: "Không tìm thấy dữ liệu lượt mua, giới hạn hoặc thời gian chờ.") { editor.saveLimitRows(rows) }.navigationTitle("Lượt & giới hạn").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Lưu") { editor.saveLimitRows(rows) } } }.onAppear { rows = editor.limitRows() } } }
private struct FusionView: View { @EnvironmentObject var editor: SaveEditorModel; @State private var rows: [EditableRow] = []; @State private var selected = "fusionElementBalls"; var body: some View { VStack { Picker("Dữ liệu", selection: $selected) { Text("Bóng nguyên tố").tag("fusionElementBalls"); Text("Kho ghép đồ").tag("fusionStockItems") }.pickerStyle(.segmented).padding(); Form { Section("Trạng thái") { Toggle("Mở panel ghép đồ", isOn: Binding(get: { editor.boolValue("openFusionPanelFlag") }, set: { editor.setBool("openFusionPanelFlag", $0) })); Toggle("Đồng bộ bàn cờ cũ", isOn: Binding(get: { editor.boolValue("legacyFusionBoardMigrated") }, set: { editor.setBool("legacyFusionBoardMigrated", $0) })); Toggle("Đồng bộ quà Mèo cũ", isOn: Binding(get: { editor.boolValue("legacyFusionLuckyCatRewardsMigrated") }, set: { editor.setBool("legacyFusionLuckyCatRewardsMigrated", $0) })); TextField("Rương vàng", text: Binding(get: { editor.value(for: "fusionGoldChestNum") }, set: { editor.updateValue($0, key: "fusionGoldChestNum") })).keyboardType(.numbersAndPunctuation) } }; EditableRowsView(rows: $rows, labels: ["Số lượng"], empty: "Không có dữ liệu.") { editor.saveFusionRows(rows) }.onAppear { rows = editor.fusionRows(selected) }.onChange(of: selected) { _, value in rows = editor.fusionRows(value) } }.navigationTitle("Ghép đồ") } }
private struct TasksView: View { @EnvironmentObject var editor: SaveEditorModel; @State private var area: TaskArea = .normal; @State private var rows: [EditableRow] = []; var body: some View { VStack { Picker("Nhóm", selection: $area) { ForEach(TaskArea.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).padding(); Form { Section("Tiến độ chính") { TextField("Chỉ mục nhiệm vụ hiện tại", text: Binding(get: { editor.value(for: "taskCurrentIndex") }, set: { editor.updateValue($0, key: "taskCurrentIndex") })).keyboardType(.numbersAndPunctuation); Button("Hoàn thành tất cả") { editor.maxTasks(area); rows = editor.taskRows(area) }.buttonStyle(.borderedProminent).tint(.orange) } }; EditableRowsView(rows: $rows, labels: ["Đã hoàn thành", "Mục tiêu"], empty: "Không có nhiệm vụ.") { editor.saveTaskRows(rows, area: area) }.onAppear { rows = editor.taskRows(area) }.onChange(of: area) { _, value in rows = editor.taskRows(value) } }.navigationTitle("Nhiệm vụ") } }
private struct LuckyCatView: View {
    @EnvironmentObject var editor: SaveEditorModel
    @State private var rows: [EditableRow] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Phần thưởng Mèo Thần Tài").font(.title3.weight(.bold))
                Text("Mỗi phần thưởng gồm Loại, ID vật phẩm, Tên vật phẩm và Số lượng.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !editor.isLoaded {
                    MissingDataView()
                } else if rows.isEmpty {
                    StudioNotice("Chưa có phần thưởng. Nhấn dấu + để thêm một trường mới.")
                } else {
                    ForEach($rows) { $row in
                        LuckyRewardCard(row: $row)
                    }
                }

                NavigationLink { ItemCatalogView() } label: {
                    StudioRow(
                        icon: "list.bullet.rectangle",
                        title: "Danh sách Item",
                        detail: "Tra cứu, thêm và quản lý ID vật phẩm"
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 112)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Mèo Thần Tài")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { editor.addLuckyReward(); rows = editor.luckyRewards() } label: {
                    Image(systemName: "plus")
                }
                .disabled(!editor.isLoaded)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Lưu") { editor.saveLuckyRewards(rows) }
                    .disabled(!editor.isLoaded)
            }
        }
        .onAppear { rows = editor.luckyRewards() }
    }
}
private struct MinigameView: View {
    @EnvironmentObject var editor: SaveEditorModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Điểm & tiền tệ").font(.title3.weight(.bold))
                Text("Chỉnh điểm và tiền tệ của các sự kiện, trò chơi nhỏ.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !editor.isLoaded {
                    MissingDataView()
                } else {
                    StudioCard {
                        ForEach(editor.minigameFields.indices, id: \.self) { index in
                            QuickValueRow(field: editor.minigameFields[index])
                            if index < editor.minigameFields.count - 1 {
                                Divider().overlay(Color.primary.opacity(0.14)).padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 112)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Sự kiện & trò chơi nhỏ")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Lưu") { editor.infoMessage = "Đã lưu dữ liệu sự kiện và trò chơi nhỏ." }
                    .disabled(!editor.isLoaded)
            }
        }
    }
}
private struct ShopVIPView: View { @EnvironmentObject var editor: SaveEditorModel; var body: some View { Form { Section("Đặc quyền VIP & thẻ tháng") { ForEach(editor.shopFields.prefix(1)) { DetailedValueField(field: $0) }; DatePicker("Hạn thẻ tháng thường", selection: Binding(get: { editor.cardEndDate(superCard: false) }, set: { editor.setCardEndDate($0, superCard: false) })); DatePicker("Hạn thẻ tháng cao cấp", selection: Binding(get: { editor.cardEndDate(superCard: true) }, set: { editor.setCardEndDate($0, superCard: true) })) }; Section("Tiền tệ cửa hàng đặc biệt") { ForEach(editor.shopFields.dropFirst()) { DetailedValueField(field: $0) } } }.navigationTitle("Cửa hàng & VIP").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Lưu") { editor.infoMessage = "Đã lưu dữ liệu cửa hàng và VIP." } } } } }
private struct GatePassView: View { @EnvironmentObject var editor: SaveEditorModel; var body: some View { Form { Section("Thẻ mùa giải") { TextField("Xu đào lỗ", text: Binding(get: { editor.value(for: "holeCoins") }, set: { editor.updateValue($0, key: "holeCoins") })).keyboardType(.numbersAndPunctuation); Button("Tối đa cấp độ & qua ải mọi mùa") { editor.maxGatePass() }.buttonStyle(.borderedProminent).tint(.orange); Text("Đặt 100.000 điểm, hoàn thành nhiệm vụ và thử thách của mọi thẻ mùa giải hiện có.").font(.footnote).foregroundStyle(.secondary) } }.navigationTitle("Thẻ mùa giải") } }
private struct EventRewardsView: View { @EnvironmentObject var editor: SaveEditorModel; var body: some View { VStack(spacing: 14) { Image(systemName: "gift.fill").font(.system(size: 36)).foregroundStyle(.orange); Text("Nhận quà sự kiện").font(.title3.bold()); Text("Quét các nhóm quà đăng nhập và sự kiện có trong save; phần thưởng chưa nhận được đánh dấu hoàn tất.").font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal); Button("Quét & nhận toàn bộ quà") { editor.claimEventRewards() }.buttonStyle(.borderedProminent).controlSize(.regular).tint(.orange) }.frame(maxWidth: .infinity, maxHeight: .infinity).padding().navigationTitle("Quà sự kiện") } }
private struct SettingsView: View { @EnvironmentObject var editor: SaveEditorModel; var body: some View { SettingsHomeView(askToClear: .constant(false), catalogExport: .constant(nil), importingCatalog: .constant(false)) } }

private struct SettingsHomeView: View {
    @EnvironmentObject var editor: SaveEditorModel
    @Binding var askToClear: Bool
    @Binding var catalogExport: LuckyCatalogDocument?
    @Binding var importingCatalog: Bool
    var body: some View {
        Form {
            Section("Ứng dụng") { HStack { Image(systemName: "app.fill").font(.title).foregroundStyle(.orange).frame(width: 48, height: 48).background(Color.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 11)); VStack(alignment: .leading) { Text("Hotpot Save Studio").font(.headline); Text("Phiên bản 1.0").foregroundStyle(.secondary) } } }
            Section("Giao diện") { Picker("Chế độ", selection: $editor.appearance) { Text("Hệ thống").tag("Hệ thống"); Text("Sáng").tag("Sáng"); Text("Tối").tag("Tối") } }
            Section("Dữ liệu Mèo Thần Tài") { Button("Xuất dữ liệu Mèo thần tài") { catalogExport = LuckyCatalogDocument(catalog: editor.itemCatalog) }; Button("Nhập dữ liệu Mèo thần tài") { importingCatalog = true } }
            Section("Dữ liệu ứng dụng") { Button("Xóa dữ liệu đã giải mã", role: .destructive) { askToClear = true } }
            Section("Hướng dẫn") { Text("Chọn file tại Trang chủ, chỉnh sửa tại các tab, sau đó đóng gói và xuất file mới. File gốc trong Files không bị ghi đè.").font(.footnote) }
        }
        .navigationTitle("Cài đặt")
    }
}

private struct ValueField: View { @EnvironmentObject var editor: SaveEditorModel; let field: EditField; var body: some View { TextField(field.title, text: Binding(get: { editor.value(for: field.key) }, set: { editor.updateValue($0, key: field.key) })).keyboardType(.numbersAndPunctuation) } }
private struct DetailedValueField: View { @EnvironmentObject var editor: SaveEditorModel; let field: EditField; var body: some View { VStack(alignment: .leading, spacing: 3) { Text(field.title).font(.subheadline.weight(.medium)); Text(field.detail).font(.caption).foregroundStyle(.secondary); TextField("0", text: Binding(get: { editor.value(for: field.key) }, set: { editor.updateValue($0, key: field.key) })).keyboardType(.numbersAndPunctuation) } } }
private struct LuckyRewardCard: View {
    @EnvironmentObject var editor: SaveEditorModel
    @Binding var row: EditableRow

    private var itemName: Binding<String> {
        Binding(
            get: { row.values.count > 1 ? row.values[1] : "" },
            set: { value in
                while row.values.count < 2 { row.values.append("") }
                row.values[1] = value
            }
        )
    }

    private var quantity: Binding<String> {
        Binding(
            get: { row.values.first ?? "0" },
            set: { value in
                if row.values.isEmpty { row.values = [value] } else { row.values[0] = value }
            }
        )
    }

    var body: some View {
        StudioCard {
            VStack(spacing: 0) {
                LuckyRewardValueRow(title: "Loại", detail: "Mã loại phần thưởng", value: $row.subtitle, numeric: true)
                Divider().overlay(Color.primary.opacity(0.14)).padding(.leading, 16)
                LuckyRewardValueRow(title: "ID vật phẩm", detail: "Mã định danh vật phẩm", value: $row.identifier, numeric: true)
                    .onChange(of: row.identifier) { _, id in itemName.wrappedValue = editor.itemName(for: id) }
                Divider().overlay(Color.primary.opacity(0.14)).padding(.leading, 16)
                LuckyRewardValueRow(title: "Tên vật phẩm", detail: "Tự điền từ danh mục; có thể sửa khi được phép", value: itemName)
                    .disabled(!editor.canEditItemName(for: row.identifier))
                Divider().overlay(Color.primary.opacity(0.14)).padding(.leading, 16)
                LuckyRewardValueRow(title: "Số lượng", detail: "Số vật phẩm nhận được", value: quantity, numeric: true)
            }
        }
    }
}

private struct ItemCatalogView: View {
    @EnvironmentObject var editor: SaveEditorModel
    @State private var entries: [ItemCatalogEntry] = []
    @State private var searchText = ""

    private var visibleEntryIDs: [UUID] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries
            .filter { keyword.isEmpty || $0.itemID.localizedCaseInsensitiveContains(keyword) || $0.name.localizedCaseInsensitiveContains(keyword) }
            .map(\.id)
    }

    private var nextCustomItemID: String {
        let largest = entries.compactMap { Int($0.itemID) }.filter { $0 >= 3001 }.max() ?? 3000
        return String(largest + 1)
    }

    var body: some View {
        List {
            Section {
                Text("ID từ 0 đến 3000 là dữ liệu có sẵn. Chỉ tên đang trống mới có thể được thêm. ID từ 3001 là mục bạn tự thêm, có thể sửa hoặc xóa.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Tìm ID hoặc tên vật phẩm", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Xóa nội dung tìm kiếm")
                    }
                }
            }

            Section("Item") {
                ForEach(visibleEntryIDs, id: \.self) { entryID in
                    if let index = entries.firstIndex(where: { $0.id == entryID }) {
                        ItemCatalogEditorRow(entry: $entries[index]) {
                            entries.removeAll { $0.id == entryID }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaPadding(.bottom, 86)
        .navigationTitle("Danh sách Item")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    entries.append(.init(itemID: nextCustomItemID, name: "", isBuiltIn: false))
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Lưu") {
                    if editor.saveItemCatalogEntries(entries) {
                        entries = editor.itemCatalogEntries()
                    }
                }
            }
        }
        .onAppear { entries = editor.itemCatalogEntries() }
    }
}

private struct ItemCatalogEditorRow: View {
    @Binding var entry: ItemCatalogEntry
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("ID item", text: $entry.itemID)
                    .keyboardType(.numbersAndPunctuation)
                    .disabled(entry.isBuiltIn)
                if !entry.isBuiltIn {
                    Button(role: .destructive, action: delete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Xóa Item")
                }
            }

            TextField("Tên vật phẩm", text: $entry.name)
                .disabled(entry.isBuiltIn && !entry.allowsBuiltInNameEdit)

            Text(entry.isBuiltIn
                 ? (entry.allowsBuiltInNameEdit ? "Dữ liệu có sẵn chưa có tên: có thể thêm tên." : "Dữ liệu có sẵn: tên vật phẩm đã được khóa.")
                 : "Item tự thêm: có thể sửa ID, tên hoặc xóa.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct LuckyRewardValueRow: View {
    let title: String
    let detail: String
    @Binding var value: String
    var numeric = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField("0", text: $value)
                .keyboardType(numeric ? .numbersAndPunctuation : .default)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.monospacedDigit())
                .frame(width: 122)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color.primary.opacity(0.10), in: .rect(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }
}
private struct QuickValueRow: View {
    @EnvironmentObject var editor: SaveEditorModel
    let field: EditField
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(field.title).font(.subheadline.weight(.medium)).foregroundStyle(.primary).lineLimit(2)
                Text("(\(field.detail))").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            TextField("0", text: Binding(get: { editor.value(for: field.key) }, set: { editor.updateValue($0, key: field.key) }))
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.monospacedDigit())
                .frame(width: 122)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color.primary.opacity(0.10), in: .rect(cornerRadius: 10))
        }.padding(.horizontal, 16).padding(.vertical, 9)
    }
}
private struct EditableRowsView: View { @Binding var rows: [EditableRow]; let labels: [String]; let empty: String; let save: () -> Void; var body: some View { Group { if rows.isEmpty { ContentUnavailableView(empty, systemImage: "tray") } else { List { ForEach($rows) { $row in EditableRowCard(row: $row, labels: labels) }; Section { Button("Lưu thay đổi", action: save).frame(maxWidth: .infinity).buttonStyle(.borderedProminent).tint(.orange) } } } } } }
private struct EditableRowCard: View { @Binding var row: EditableRow; let labels: [String]; var body: some View { VStack(alignment: .leading, spacing: 8) { Text(row.identifier.isEmpty ? "Không có ID" : row.identifier).font(.headline); Text(row.subtitle).font(.caption).foregroundStyle(.secondary); ForEach(labels.indices, id: \.self) { index in TextField(labels[index], text: Binding(get: { row.values.indices.contains(index) ? row.values[index] : "" }, set: { value in while row.values.count <= index { row.values.append("") }; row.values[index] = value })).textFieldStyle(.roundedBorder).keyboardType(.numbersAndPunctuation) } }.padding(.vertical, 4) } }
private struct MenuRow: View { let icon: String; let title: String; let detail: String; var body: some View { Label { VStack(alignment: .leading, spacing: 2) { Text(title).font(.body); Text(detail).font(.caption).foregroundStyle(.secondary) } } icon: { Image(systemName: icon).font(.body).foregroundStyle(.orange) } } }
private struct ActionButton: View { let title: String; let icon: String; var tint: Color = .orange; let action: () -> Void; init(_ title: String, icon: String, tint: Color = .orange, action: @escaping () -> Void) { self.title = title; self.icon = icon; self.tint = tint; self.action = action }; var body: some View { Button(action: action) { Label(title, systemImage: icon).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 13) }.tint(tint).buttonStyle(.plain) } }
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
    var body: some View { Text(title).font(.headline.weight(.bold)).foregroundStyle(.primary).padding(.horizontal, 2) }
}

/// A compact in-content header for the three root tabs.  Keeping this inside
/// the scroll view avoids the oversized iOS 26 glass navigation toolbar while
/// still letting SwiftUI place it below the Dynamic Island safe area.
private struct StudioPageHeader: View {
    let title: String
    @Binding var askToClear: Bool
    let showsSettings: Bool

    init(_ title: String, askToClear: Binding<Bool>, showsSettings: Bool = false) {
        self.title = title
        _askToClear = askToClear
        self.showsSettings = showsSettings
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            if showsSettings {
                NavigationLink { SettingsView() } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Color.primary.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}

private struct StudioCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(spacing: 0) { content }.background(Color.primary.opacity(0.08), in: .rect(cornerRadius: 20)).overlay { RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.10), lineWidth: 1) } }
}

private struct StudioRow: View {
    let icon: String; let title: String; let detail: String; var tint: Color = .orange; var showsChevron = true
    @ScaledMetric(relativeTo: .body) private var verticalPadding: CGFloat = 10
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .medium)).foregroundStyle(tint).frame(width: 36, height: 36).background(tint.opacity(0.16), in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) { Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1); Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            Spacer(minLength: 6)
            if showsChevron { Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
        }.padding(.horizontal, 13).padding(.vertical, verticalPadding).contentShape(.rect)
    }
}

private struct StudioLinks: View {
    let entries: [(String, String, String, AnyView)]
    init(_ entries: [(String, String, String, AnyView)]) { self.entries = entries }
    var body: some View {
        VStack(spacing: 0) {
            ForEach(entries.indices, id: \.self) { index in
                NavigationLink { entries[index].3 } label: { StudioRow(icon: entries[index].0, title: entries[index].1, detail: entries[index].2) }.buttonStyle(.plain)
                if index < entries.count - 1 { Divider().overlay(Color.primary.opacity(0.14)).padding(.leading, 61) }
            }
        }
    }
}

private struct StudioNotice: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.subheadline).foregroundStyle(.secondary).padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(0.07), in: .rect(cornerRadius: 18)) }
}

private struct StudioTabBar: View {
    @Binding var selection: StudioTab
    var body: some View {
        HStack(spacing: 6) {
            StudioTabButton(tab: .home, title: "Home", icon: "house.fill", selection: $selection)
            StudioTabButton(tab: .quick, title: "Sửa nhanh", icon: "bolt.fill", selection: $selection)
            StudioTabButton(tab: .editor, title: "Chỉnh sửa", icon: "slider.horizontal.3", selection: $selection)
            StudioTabButton(tab: .settings, title: "Cài đặt", icon: "gearshape.fill", selection: $selection)
        }.padding(4).glassEffect(.regular, in: Capsule()).overlay { Capsule().stroke(Color.primary.opacity(0.16), lineWidth: 1) }
    }
}

private struct StudioTabButton: View {
    let tab: StudioTab; let title: String; let icon: String; @Binding var selection: StudioTab
    var body: some View { Button { selection = tab } label: { VStack(spacing: 2) { Image(systemName: icon).font(.subheadline.weight(.medium)); Text(title).font(.caption2.weight(.medium)) }.foregroundStyle(selection == tab ? Color.orange : Color.primary).frame(maxWidth: .infinity).padding(.vertical, 6).background(selection == tab ? Color.orange.opacity(0.18) : .clear, in: Capsule()) }.buttonStyle(.plain).contentShape(Capsule()).animation(.snappy(duration: 0.24), value: selection) }
}
