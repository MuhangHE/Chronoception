import ChronoceptionKit
import SwiftData
import SwiftUI

/// Exporting the log, and the MiniMax key, platform and model used to tidy titles.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage(ParserSettings.regionKey) private var region = MiniMaxRegion.china.rawValue
    @AppStorage(ParserSettings.modelKey) private var model = MiniMaxClient.defaultModel

    @State private var hasKey = APIKeyStore.load() != nil
    @State private var newKey = ""
    @State private var testing = false
    @State private var testResult: Result<String, Error>?
    @State private var errorMessage: String?
    @State private var export: Result<ExportFiles, Error>?

    /// The log written out as files, ready to share.
    private struct ExportFiles {
        let json: URL
        let csv: URL
        let count: Int
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    switch export {
                    case .success(let files):
                        ShareLink("导出 JSON（完整数据）", item: files.json)
                        ShareLink("导出 CSV（表格）", item: files.csv)
                    case .failure(let error):
                        Text(error.userMessage)
                            .foregroundStyle(Theme.danger)
                    case nil:
                        ProgressView()
                    }
                } header: {
                    Text("导出")
                } footer: {
                    if case .success(let files) = export {
                        Text("共 \(files.count) 条记录。可以存到「文件」、隔空投送到 Mac，CSV 能用表格软件直接打开。")
                    }
                }
                .paperRows()

                Section {
                    LabeledContent("API key", value: hasKey ? "已保存" : "未填写")
                    SecureField(hasKey ? "输入新的 key 来替换" : "粘贴 MiniMax API key", text: $newKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("保存 key", action: saveKey)
                        .disabled(trimmedKey.isEmpty)
                    if hasKey {
                        Button("删除 key", role: .destructive, action: deleteKey)
                            .foregroundStyle(Theme.danger)
                    }
                } header: {
                    Text("MiniMax")
                } footer: {
                    Text("开始一件事后，MiniMax 会在后台把你写的话整理成简洁的标题；写了「九点就开始了」也会把开始时间改过来。不填 key 也能正常记录，只是不整理。key 只保存在这台 iPhone 的钥匙串里。")
                }
                .paperRows()

                Section {
                    Picker("平台", selection: $region) {
                        Text("国内（minimax.cn）").tag(MiniMaxRegion.china.rawValue)
                        Text("国际（minimax.io）").tag(MiniMaxRegion.international.rawValue)
                    }
                    LabeledContent("模型") {
                        TextField(MiniMaxClient.defaultModel, text: $model)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } footer: {
                    Text("国内和国际平台的 key 不通用，选你申请 key 的那一个。默认的 MiniMax-M3 会关掉思考、直接回答，速度最快。")
                }
                .paperRows()

                Section {
                    Button {
                        Task { await test() }
                    } label: {
                        HStack {
                            Text("测试连接")
                            if testing {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(testing || !hasKey)
                    switch testResult {
                    case .success(let reply):
                        Text("连接正常。MiniMax 回复：\(reply)")
                    case .failure(let error):
                        Text(error.userMessage)
                            .foregroundStyle(Theme.danger)
                    case nil:
                        EmptyView()
                    }
                } footer: {
                    Text("整理时只会把你写的那句话和开始的时间发给 MiniMax。")
                }
                .paperRows()
            }
            .paperBackground()
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .errorAlert($errorMessage)
            .task { export = Result { try makeExport() } }
        }
    }

    private func makeExport() throws -> ExportFiles {
        let entries = try TimeLog(context: modelContext).allEntries()
        let folder = FileManager.default.temporaryDirectory.appending(path: "Export", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = Date.now.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        let json = folder.appending(path: "Chronoception-\(stamp).json")
        let csv = folder.appending(path: "Chronoception-\(stamp).csv")
        try LogExport.json(entries, exportedAt: .now, timeZone: .current).write(to: json, options: .atomic)
        try Data(LogExport.csv(entries, timeZone: .current).utf8).write(to: csv, options: .atomic)
        return ExportFiles(json: json, csv: csv, count: entries.count)
    }

    private var trimmedKey: String {
        newKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveKey() {
        do {
            try APIKeyStore.save(trimmedKey)
            newKey = ""
            hasKey = true
            testResult = nil
        } catch {
            errorMessage = error.userMessage
        }
    }

    private func deleteKey() {
        APIKeyStore.delete()
        hasKey = false
        testResult = nil
    }

    private func test() async {
        testing = true
        defer { testing = false }
        do {
            let reply = try await ParserSettings.client().reply(system: "只回复两个字：正常", user: "测试")
            testResult = .success(String(reply.prefix(20)))
        } catch {
            testResult = .failure(error)
        }
    }
}
