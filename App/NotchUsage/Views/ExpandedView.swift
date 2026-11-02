import NotchUsageCore
import SwiftUI

/// Panneau déplié : chaque limite, ancienneté, bandeaux d'état, actions (US1).
struct ExpandedView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let d = model.display
        VStack(alignment: .leading, spacing: 10) {
            header(d)
            if let banner = d.banner { bannerView(banner) }
            switch d.content {
            case .limits:
                ForEach(d.limits) { limit in
                    LimitRow(limit: limit, now: model.now, highlighted: d.alertLevel != .none && limit.id == d.headline?.limit.id,
                             settings: model.alertSettings)
                }
            case .reauthRequired:
                statusBlock(icon: "exclamationmark.lock", title: String(localized: "Reconnect required"),
                            message: reauthMessage)
                reconnectButtons
                if let error = model.connectionError {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
            case .unsupported:
                statusBlock(icon: "questionmark.circle", title: String(localized: "Plan not supported"),
                            message: String(localized: "This Claude plan does not expose usage limits. Pro, Max or Team is required."))
            case .unavailable:
                statusBlock(icon: "wifi.exclamationmark", title: String(localized: "Data unavailable"),
                            message: String(localized: "Waiting for the first reading…"))
            case .connect:
                EmptyView()
            }
            Spacer(minLength: 0)
            footer(d)
        }
    }

    private func header(_ d: DisplayState) -> some View {
        HStack {
            Text("Claude usage").font(.headline)
            Spacer()
            if d.isLoading {
                ProgressView().controlSize(.mini).tint(.white)
            } else if let fetchedAt = d.fetchedAt, d.freshness != .fresh {
                Text(RelativeTimeFormatter.age(fetchedAt, now: model.now, language: AppLanguage.current))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func bannerView(_ banner: DisplayState.Banner) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
            switch banner {
            case .unavailable: Text("Data unavailable, showing the last reading.")
            case .stale: Text("Last reading is older than 30 minutes.")
            case .challenge:
                Text("claude.ai asked for a browser check.")
                Button("Open sign-in") { model.connectWithBrowser() }.buttonStyle(.link)
            }
        }
        .font(.caption)
        .foregroundStyle(.orange)
    }

    private func statusBlock(icon: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(.subheadline.weight(.semibold))
            Text(message).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var reauthMessage: String {
        model.account?.connectionMethod == .claudeCode
            ? String(localized: "Your Claude Code session has expired. Run claude in Terminal once to renew it: Notch Usage reconnects automatically within 30 seconds. Or sign in with your browser.")
            : String(localized: "Your claude.ai session has expired. Sign in again.")
    }

    private var reconnectButtons: some View {
        HStack {
            if model.claudeCodeAvailable {
                Button("Use Claude Code session") { model.connectWithClaudeCode() }
            }
            Button("Sign in with browser") { model.connectWithBrowser() }
        }
        .controlSize(.small)
        .disabled(model.isConnecting)
    }

    private func footer(_ d: DisplayState) -> some View {
        HStack {
            Button { model.refreshNow() } label: { Label("Refresh now", systemImage: "arrow.clockwise").contentShape(Rectangle()) }
                .disabled(d.isLoading || d.content == .reauthRequired)
            Spacer()
            Button { model.showSettings = true; model.pinned = true } label: { Label("Settings", systemImage: "gearshape").contentShape(Rectangle()) }
            Button(role: .destructive) { model.signOut() } label: { Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right").contentShape(Rectangle()) }
            QuitButton()
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// Une limite : libellé, pourcentage, barre, réinitialisation (heure locale + relative). VoiceOver (FR-016).
struct LimitRow: View {
    let limit: UsageLimit
    let now: Date
    let highlighted: Bool
    let settings: AlertSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(LimitLabel.text(for: limit)).font(.subheadline)
                Spacer()
                Text("\(Int(limit.isBlocked ? 100 : limit.utilization.rounded()))%")
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(color)
            }
            UsageBar(value: limit.utilization, color: color).frame(height: 5)
            HStack {
                Text(resetText).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let resetsAt = limit.resetsAt {
                    Text(resetsAt, format: .dateTime.weekday(.abbreviated).hour().minute())
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, highlighted ? 6 : 0)
        .background(highlighted ? color.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(LimitLabel.text(for: limit)), \(Int(limit.utilization.rounded())) percent, resets \(untilReset)"))
    }

    private var resetText: String {
        // Phrase autonome une fois l'heure passée : sinon « Resets reset pending ».
        if let resetsAt = limit.resetsAt, resetsAt <= now { return String(localized: "Reset pending") }
        return limit.isBlocked ? String(localized: "Blocked, resets \(untilReset)") : String(localized: "Resets \(untilReset)")
    }

    private var untilReset: String {
        RelativeTimeFormatter.untilReset(limit.resetsAt, now: now, language: AppLanguage.current)
    }

    private var color: Color {
        if limit.isBlocked { return .red }
        guard settings.enabled else { return .white }
        if limit.utilization >= Double(settings.criticalThreshold) { return .red }
        if limit.utilization >= Double(settings.warningThreshold) { return .orange }
        return .white
    }
}

/// Sans icône dans le Dock ni menu, c'est le seul moyen de quitter l'app hors du Moniteur d'activité.
struct QuitButton: View {
    var body: some View {
        Button { NSApp.terminate(nil) } label: { Label("Quit", systemImage: "power").contentShape(Rectangle()) }
            .keyboardShortcut("q")
    }
}
