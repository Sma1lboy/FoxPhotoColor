import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("settings.about") {
                    HStack {
                        Text("settings.version")
                        Spacer()
                        Text(verbatim: version)
                            .foregroundStyle(.secondary)
                    }
                    Text("settings.about.body")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
