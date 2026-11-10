import SwiftUI

/// Premier lancement : les deux voies de connexion et la note de risque (US1 sc. 1, FR-001).
struct ConnectView: View {
    @Environment(AppModel.self) private var model
    @State private var showsKey = false
    @State private var pastedKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connect your Claude account").font(.headline)
            Text("Notch Usage shows your Pro or Max limits. Pick how to connect:")
                .font(.caption).foregroundStyle(.secondary)

            if model.claudeCodeAvailable {
                Button { model.connectWithClaudeCode() } label: {
                    Label("Use Claude Code session", systemImage: "terminal")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
                Text("Reads the token Claude Code already stored in your Keychain. macOS will ask you to allow it.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Button { model.connectWithBrowser() } label: {
                Label("Sign in with browser", systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            Text("Opens claude.ai in a small window. The session cookie stays in your Keychain.")
                .font(.caption2).foregroundStyle(.secondary)

            // Repli quand la connexion par navigateur est bloquée (déplacé depuis les réglages, 013).
            DisclosureGroup(isExpanded: $showsKey) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // Libellé pour VoiceOver : sans lui, le champ se lisait « sk-ant-sid… ».
                        SecureField("Session key", text: $pastedKey, prompt: Text(verbatim: "sk-ant-sid…"))
                            .textFieldStyle(.roundedBorder)
                        Button("Use") {
                            model.applySessionKey(pastedKey)
                            pastedKey = ""
                        }
                        .disabled(pastedKey.isEmpty || model.isConnecting)
                    }
                    Text("Paste the sessionKey cookie from claude.ai if the browser sign-in is blocked.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            } label: {
                Text("Other method…").font(.caption).foregroundStyle(.secondary)
            }

            if model.isConnecting {
                HStack(spacing: 6) { ProgressView().controlSize(.small).tint(.white); Text("Checking your usage…").font(.caption) }
            }
            if let error = model.connectionError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }

            Spacer(minLength: 0)

            Text("Uses undocumented Claude endpoints. Nothing leaves your Mac, but Anthropic may change or block them. Use at your own risk.")
                .font(.caption2).foregroundStyle(.secondary)

            HStack {
                Spacer()
                QuitButton().buttonStyle(.borderless).font(.caption).foregroundStyle(.secondary)
            }
        }
        .controlSize(.regular)
        .disabled(model.isConnecting)
    }
}
