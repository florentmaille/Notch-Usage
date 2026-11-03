import NotchUsageCore
import SwiftUI

/// Réglages accessibles depuis le panneau déplié (FR-021). 013 : trois lignes pour l'essentiel (démarrage,
/// notifications, langue), le reste replié dans « Avancé » ; la clé de session est passée sur l'écran de connexion.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var intervalMinutes: Double = 3
    @State private var showsAdvanced = false
    @State private var language = AppLanguage.storedChoice

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Titre d'abord, retour dessous (retour utilisateur, 013) : « Back » ne colle plus à l'île.
            VStack(alignment: .leading, spacing: 10) {
                Text("Settings").font(.headline)
                Button { model.showSettings = false } label: { Label("Back", systemImage: "chevron.left").contentShape(Rectangle()) }
                    .buttonStyle(.borderless)
            }

            // Sans défilement : le panneau prend la hauteur mesurée des réglages, « Avancé » déplié compris (013).
            VStack(alignment: .leading, spacing: 8) {
                essentials
                DisclosureGroup(isExpanded: $showsAdvanced) {
                    advanced.padding(.top, 6)
                } label: {
                    Text("Advanced").font(.caption).foregroundStyle(.secondary)
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
        .toggleStyle(.switch)
        .onAppear { intervalMinutes = (model.refreshSettings.interval.timeIntervalValue / 60).rounded() }
    }

    // MARK: Essentiel

    private var essentials: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                row("Open at login", isOn: Binding(
                    get: { model.launchAtLoginStatus == .enabled || model.launchAtLoginStatus == .requiresApproval },
                    set: { model.setLaunchAtLogin($0) }))
                if model.launchAtLoginStatus == .requiresApproval {
                    Text("Waiting for approval in System Settings → General → Login Items.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                row("Show in menu bar", isOn: Binding(
                    get: { model.showsMenuBarIcon },
                    set: { model.setMenuBarIcon($0) }))
                row("Notify me before a block", isOn: Binding(
                    get: { model.alertSettings.notifications },
                    set: { model.setNotificationsEnabled($0) }))
                HStack {
                    Text("Language")
                    Spacer()
                    Picker(selection: $language) {
                        Text("System").tag(LanguageChoice.system)
                        // Noms dans leur propre langue, reconnaissables quelle que soit la langue affichée.
                        Text(verbatim: "English").tag(LanguageChoice.english)
                        Text(verbatim: "Français").tag(LanguageChoice.french)
                    } label: { EmptyView() }
                        .pickerStyle(.menu)
                        .fixedSize()
                        .onChange(of: language) { _, v in AppLanguage.store(v) }
                }
                if language != AppLanguage.launchedChoice {
                    HStack {
                        Text("Applies after a restart.").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Button("Restart") { AppLanguage.relaunch() }
                    }
                }
            }
        }
    }

    /// Libellé à gauche, interrupteur à droite, aligné sur le menu de langue.
    private func row(_ title: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle(title, isOn: isOn).labelsHidden()
        }
    }

    // MARK: Avancé

    private var advanced: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Refresh every")
                Spacer()
                Text(intervalLabel).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: $intervalMinutes, in: 1...15, step: 1) { EmptyView() }
                .onChange(of: intervalMinutes) { _, v in model.setRefreshInterval(seconds: v * 60) }
            Divider().padding(.vertical, 2)
            Toggle("Use thresholds when no forecast exists", isOn: Binding(
                get: { model.alertSettings.enabled },
                set: { model.setAlertsEnabled($0) }))
            Stepper(value: Binding(get: { model.alertSettings.warningThreshold }, set: { model.setWarningThreshold($0) }), in: 1...99) {
                HStack { Circle().fill(.orange).frame(width: 8, height: 8); Text("Warning at \(model.alertSettings.warningThreshold)%") }
            }
            .disabled(!model.alertSettings.enabled)
            Stepper(value: Binding(get: { model.alertSettings.criticalThreshold }, set: { model.setCriticalThreshold($0) }), in: 2...100) {
                HStack { Circle().fill(.red).frame(width: 8, height: 8); Text("Critical at \(model.alertSettings.criticalThreshold)%") }
            }
            .disabled(!model.alertSettings.enabled)
            Text("Thresholds colour the gauge for weekly limits and before a forecast exists. Claude rate-limits usage requests: 3 minutes is a safe refresh.")
                .font(.caption2).foregroundStyle(.secondary)
        }
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
