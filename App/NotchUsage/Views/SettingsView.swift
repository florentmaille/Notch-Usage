import NotchUsageCore
import SwiftUI

/// Réglages accessibles depuis le panneau déplié (FR-021) : cadence, alertes, session, login item.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var intervalMinutes: Double = 3
    @State private var pastedKey = ""
    @State private var language = AppLanguage.storedChoice

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { model.showSettings = false } label: { Label("Back", systemImage: "chevron.left").contentShape(Rectangle()) }
                    .buttonStyle(.borderless)
                Text("Settings").font(.headline)
                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    languageSection
                    notchSection
                    refreshSection
                    alertsSection
                    sessionSection
                    startupSection
                }
            }

            HStack {
                if let account = model.account {
                    Text(account.connectionMethod == .claudeCode ? "Connected via Claude Code" : "Connected via browser")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) { model.signOut() } label: { Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right").contentShape(Rectangle()) }
                    .buttonStyle(.borderless).controlSize(.small)
            }
        }
        .controlSize(.small)
        .onAppear { intervalMinutes = (model.refreshSettings.interval.timeIntervalValue / 60).rounded() }
    }

    private var refreshSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
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
    }

    private var alertsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Highlight the notch when a limit gets close", isOn: Binding(
                    get: { model.alertSettings.enabled },
                    set: { model.setAlertsEnabled($0) }))
                HStack {
                    Stepper(value: Binding(get: { model.alertSettings.warningThreshold }, set: { model.setWarningThreshold($0) }), in: 1...99) {
                        HStack { Circle().fill(.orange).frame(width: 8, height: 8); Text("Warning at \(model.alertSettings.warningThreshold)%") }
                    }
                }
                HStack {
                    Stepper(value: Binding(get: { model.alertSettings.criticalThreshold }, set: { model.setCriticalThreshold($0) }), in: 2...100) {
                        HStack { Circle().fill(.red).frame(width: 8, height: 8); Text("Critical at \(model.alertSettings.criticalThreshold)%") }
                    }
                }
                Text("One alert per threshold, per limit and per reset period. Changes apply on the next refresh.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        } label: { Text("Alerts").font(.caption) }
    }

    private var languageSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Picker(selection: $language) {
                    Text("System").tag(LanguageChoice.system)
                    // Noms dans leur propre langue, reconnaissables quelle que soit la langue affichée.
                    Text(verbatim: "English").tag(LanguageChoice.english)
                    Text(verbatim: "Français").tag(LanguageChoice.french)
                } label: { EmptyView() }
                    .pickerStyle(.segmented)
                    .onChange(of: language) { _, v in AppLanguage.store(v) }
                if language != AppLanguage.launchedChoice {
                    HStack {
                        Text("Applies after a restart.").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Button("Restart") { AppLanguage.relaunch() }
                    }
                }
            }
        } label: { Text("Language").font(.caption) }
    }

    private var notchSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                Picker(selection: Binding(get: { model.headlineChoice }, set: { model.setHeadlineChoice($0) })) {
                    Text("Automatic").tag(HeadlineChoice.automatic)
                    ForEach(headlineOptions, id: \.self) { id in
                        Text(LimitLabel.text(forID: id)).tag(HeadlineChoice.limit(id))
                    }
                } label: { Text("Limit shown") }
                Text("Automatic shows the limit most likely to block you first. A reached 5-hour or all-models weekly limit always shows.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        } label: { Text("Notch").font(.caption) }
    }

    /// Limites du dernier relevé, plus le choix enregistré s'il n'y figure pas (relevé pas encore arrivé).
    private var headlineOptions: [String] {
        var ids = model.display.limits.map(\.id)
        if case .limit(let id) = model.headlineChoice, !ids.contains(id) { ids.append(id) }
        return ids
    }

    private var sessionSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    SecureField("sk-ant-sid…", text: $pastedKey)
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
    }

    private var startupSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Open at login", isOn: Binding(
                    get: { model.launchAtLoginStatus == .enabled || model.launchAtLoginStatus == .requiresApproval },
                    set: { model.setLaunchAtLogin($0) }))
                if model.launchAtLoginStatus == .requiresApproval {
                    Text("Waiting for approval in System Settings → General → Login Items.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        } label: { Text("Startup").font(.caption) }
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
