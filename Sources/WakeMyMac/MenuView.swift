import SwiftUI
import WakeCore

struct MenuView: View {
    @EnvironmentObject private var state: AppState
    @State private var editingRule: Rule?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let rule = editingRule {
                RuleEditorView(
                    rule: rule,
                    isNew: !state.rules.contains { $0.id == rule.id },
                    onSave: { saved in
                        editingRule = nil
                        Task { await state.upsertRule(saved) }
                    },
                    onCancel: { editingRule = nil }
                )
            } else {
                listContent
            }
        }
        .task { await state.refresh() }
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if state.rules.isEmpty {
                Text(L10n.noRules)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(state.rules) { rule in
                            ruleRow(rule)
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 220)
            }

            Divider()
            daemonSection
            Divider()
            footer
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("WakeMyMac").font(.headline)
            if let next = state.nextEvent {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Label {
                        Text("\(L10n.name(of: next.action)) \(next.date, style: .relative)")
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: next.action.symbolName)
                    }
                    .foregroundStyle(.secondary)
                }
            } else if state.daemonReachable {
                Text(L10n.nothingScheduled)
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(10)
    }

    private func ruleRow(_ rule: Rule) -> some View {
        HStack {
            Image(systemName: rule.action.symbolName)
                .frame(width: 18)
                .foregroundStyle(rule.enabled ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.title(of: rule))
                    .strikethrough(!rule.enabled, color: .secondary)
                Text("\(L10n.weekdaysText(of: rule)) · \(rule.timeString)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { _ in Task { await state.toggleRule(rule) } }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture { editingRule = rule }
        .contextMenu {
            Button(L10n.edit) { editingRule = rule }
            Button(L10n.delete, role: .destructive) {
                Task { await state.deleteRule(rule) }
            }
        }
    }

    private var daemonSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(state.daemonReachable ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(L10n.helper(state.daemonStatusDescription))
                    .font(.caption)
                Spacer()
                if state.daemonStatus != .enabled {
                    Button(L10n.install) { Task { await state.installDaemon() } }
                        .controlSize(.small)
                }
            }
            if let error = state.lastError {
                Text(error)
                    .font(.caption2).foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(10)
    }

    private var footer: some View {
        HStack {
            Button {
                editingRule = Rule()
            } label: {
                Label(L10n.addRule, systemImage: "plus")
            }
            Spacer()
            Menu {
                Text("WakeMyMac \(AppInfo.version)")
                Button(L10n.about) { AppInfo.showAbout() }
                Divider()
                Toggle(L10n.launchAtLogin, isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                ))
                Button(L10n.refresh) { Task { await state.refresh() } }
                Button(L10n.uninstallHelper) { Task { await state.uninstallDaemon() } }
                Divider()
                Button(L10n.quit) { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(10)
    }
}
