import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var editor: SaveEditorModel
    @State private var importing = false
    @State private var exporting = false
    @State private var exportDocument: BinaryPlistDocument?
    @State private var askToClearAfterExport = false
    @State private var askToClearNow = false

    var body: some View {
        TabView {
            NavigationStack { workspaceView }
                .tabItem { Label("Tệp", systemImage: "folder") }
            NavigationStack { quickEditView }
                .tabItem { Label("Chỉnh sửa", systemImage: "slider.horizontal.3") }
            NavigationStack { jsonEditorView }
                .tabItem { Label("JSON", systemImage: "curlybraces") }
            NavigationStack { helpView }
                .tabItem { Label("Hướng dẫn", systemImage: "questionmark.circle") }
        }
        .tint(.orange)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { editor.importPlist(from: url) }
        }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .data, defaultFilename: "hotpot_repacked.bplist") { result in
            switch result {
            case .success: askToClearAfterExport = true
            case .failure(let error): editor.errorMessage = "Không thể xuất file: \(error.localizedDescription)"
            }
        }
        .alert("Xóa dữ liệu giải mã?", isPresented: $askToClearAfterExport) {
            Button("Giữ lại", role: .cancel) { editor.finishExport(deleteWorkspace: false) }
            Button("Xóa", role: .destructive) { editor.finishExport(deleteWorkspace: true) }
        } message: {
            Text("Đã xuất hotpot_repacked.bplist. Bạn có muốn xóa thư mục Decoded_GameData trong vùng làm việc của app không?")
        }
        .alert("Xóa dữ liệu giải mã?", isPresented: $askToClearNow) {
            Button("Hủy", role: .cancel) {}
            Button("Xóa", role: .destructive) { editor.clearWorkspace() }
        } message: {
            Text("Thao tác này chỉ xóa Decoded_GameData của app, không ảnh hưởng tới tệp gốc trong Files.")
        }
        .alert("Lỗi", isPresented: Binding(get: { editor.errorMessage != nil }, set: { if !$0 { editor.errorMessage = nil } })) {
            Button("Đóng", role: .cancel) {}
        } message: { Text(editor.errorMessage ?? "") }
        .alert("Hoàn tất", isPresented: Binding(get: { editor.infoMessage != nil }, set: { if !$0 { editor.infoMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(editor.infoMessage ?? "") }
    }

    private var workspaceView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                GlassCard {
                    Label(editor.isLoaded ? editor.importedFileName : "Chưa chọn save", systemImage: editor.isLoaded ? "checkmark.seal.fill" : "doc.badge.plus")
                        .font(.headline)
                        .foregroundStyle(editor.isLoaded ? .green : .secondary)
                    Text(editor.status).font(.subheadline).foregroundStyle(.secondary)
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Quy trình an toàn", systemImage: "arrow.triangle.2.circlepath")
                            .font(.headline)
                        FlowStep(number: 1, text: "Chọn file plist từ Files")
                        FlowStep(number: 2, text: "App giải mã vào Decoded_GameData nội bộ")
                        FlowStep(number: 3, text: "Chỉnh sửa dữ liệu")
                        FlowStep(number: 4, text: "Xuất hotpot_repacked.bplist về Files")
                    }
                }
                Button { importing = true } label: {
                    Label(editor.isLoaded ? "Chọn file khác" : "Chọn file PLIST", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)

                if editor.isLoaded {
                    Button { exportDocument = editor.prepareExport(); exporting = exportDocument != nil } label: {
                        Label("Đóng gói và xuất", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.orange)
                }
                if editor.hasWorkspace {
                    Button(role: .destructive) { askToClearNow = true } label: {
                        Label("Xóa Decoded_GameData", systemImage: "trash")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle("Save Studio")
        .background(Color(.systemGroupedBackground))
    }

    private var quickEditView: some View {
        Form {
            Section("Chỉnh sửa nhanh") {
                if !editor.isLoaded {
                    ContentUnavailableView("Chưa có dữ liệu", systemImage: "doc", description: Text("Hãy nhập file PLIST ở tab Tệp."))
                } else {
                    ForEach(editor.quickFields, id: \.key) { field in
                        TextField(field.label, text: Binding(
                            get: { editor.value(for: field.key) },
                            set: { editor.updateQuickValue($0, key: field.key) }
                        ))
                        .keyboardType(.numbersAndPunctuation)
                    }
                }
            }
            Section {
                Text("Các giá trị được ghi vào key_player_data và tự lưu vào vùng làm việc. Với dữ liệu khác, dùng tab JSON.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Chỉnh sửa nhanh")
    }

    private var jsonEditorView: some View {
        VStack(spacing: 0) {
            Picker("Khu vực", selection: Binding(get: { editor.selectedSection }, set: { editor.select($0) })) {
                ForEach(SaveEditorModel.Section.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            if editor.isLoaded {
                TextEditor(text: $editor.editorText)
                    .font(.system(.footnote, design: .monospaced))
                    .padding(.horizontal, 8)
                    .scrollContentBackground(.hidden)
                    .background(Color(.secondarySystemGroupedBackground))
                Button { _ = editor.applyEditorText() } label: {
                    Label("Kiểm tra và lưu JSON", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .padding()
            } else {
                ContentUnavailableView("Chưa có dữ liệu", systemImage: "curlybraces", description: Text("Nhập file PLIST để xem và sửa JSON."))
            }
        }
        .navigationTitle("Trình soạn JSON")
    }

    private var helpView: some View {
        List {
            Section("Tương thích") {
                Label("Binary PLIST", systemImage: "doc.zipper")
                Label("key_player_data: JSON", systemImage: "curlybraces")
                Label("Data_BackUp: Base64 → GZIP → JSON", systemImage: "archivebox")
            }
            Section("Lưu ý") {
                Text("App chỉ xử lý tệp bạn tự chọn trong Files. File gốc không bị ghi đè; file repack được xuất thành hotpot_repacked.bplist để bạn tự sử dụng.")
            }
        }
        .navigationTitle("Hướng dẫn")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HOT POT")
                .font(.caption.weight(.bold)).foregroundStyle(.orange)
            Text("Save Studio")
                .font(.largeTitle.bold())
            Text("Giải mã, chỉnh sửa và đóng gói ngay trên iPhone")
                .foregroundStyle(.secondary)
        }
    }
}

private struct FlowStep: View {
    let number: Int
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)").font(.caption.bold()).frame(width: 24, height: 24).background(.orange, in: Circle()).foregroundStyle(.white)
            Text(text)
        }
    }
}

private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glassEffect(.regular.tint(.orange.opacity(0.08)), in: .rect(cornerRadius: 24))
    }
}
