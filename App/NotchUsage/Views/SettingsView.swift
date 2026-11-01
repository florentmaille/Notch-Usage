import NotchUsageCore
import SwiftUI

/// Réglages accessibles depuis le panneau déplié (FR-021). Section minimale pour US1.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var intervalMinutes: Double = 3
    @State private var pastedKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { model.showSettings = false } label: { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.borderless)
                Text("Settings").font(.headline)
                Spacer()
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Refresh every")
                        Spacer()
                        Text(intervalLabel).monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: $intervalMinutes, in: 1...15, step: 1) { EmptyView() }
                        .onChange(of: intervalMinutes) { _, v in model.setRefreshInterval(seconds: v * 60) }
                    Text("Claude rate-limits this endpoint. 3 minutes is a safe default.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } label: { Text("Refresh").font(.caption) }

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        SecureField("sk-ant-sid01-…", text: $pastedKey)
                            .textFieldStyle(.roundedBorder)
                        Button("Use") {
                            model.applySessionKey(pastedKey)
                            pastedKey = ""
                        }
                        .disabled(pastedKey.isEmpty || model.isConnecting)
                    }
                    Text("Fallback if the browser sign-in is blocked: paste the sessionKey cookie from claude.ai.")
                        .font(.caption2).foregroundStyle(.secondary)
                    if let error = model.connectionError {
                        Text(error).font(.caption).foregroundStyle(.orange)
                    }
                }
            } label: { Text("Session key").font(.caption) }

            Spacer(minLength: 0)

            HStack {
                if let account = model.account {
                    Text(account.connectionMethod == .claudeCode ? "Connected via Claude Code" : "Connected via browser")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) { model.signOut() } label: { Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right") }
                    .buttonStyle(.borderless).controlSize(.small)
            }
        }
        .onAppear { intervalMinutes = (model.refreshSettings.interval.timeIntervalValue / 60).rounded() }
    }

    private var intervalLabel: String {
        let m = Int(intervalMinutes)
        return m == 1 ? String(localized: "1 min") : String(localized: "\(m) min")
    }
}

extension Duration {
    var timeIntervalValue: TimeInterval {
        let c = components
        return TimeInterval(c.seconds) + TimeInterval(c.attoseconds) / 1e18
    }
}
