// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Murat Çeliker

import SwiftUI
import WakeCore

struct MenuView: View {
    @EnvironmentObject private var state: AppState
    @State private var editingRule: Rule?
    @State private var hoveredRuleID: UUID?

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
                    onDelete: {
                        editingRule = nil
                        Task { await state.deleteRule(rule) }
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
            // When the helper is running the header's green dot says so, and
            // this row would be redundant.
            if !state.daemonReachable {
                daemonSection
                Divider()
            }
            // Kept outside daemonSection: failures happen while the helper is
            // running too, and they must stay visible when that row is hidden.
            if let error = state.lastError {
                Text(error)
                    .font(.caption2).foregroundStyle(.red)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                Divider()
            }
            footer
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if state.daemonReachable {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .help(L10n.helper(L10n.statusRunning))
                        .accessibilityLabel(L10n.helper(L10n.statusRunning))
                }
                Text("WakeMyMac").font(.headline)
            }
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
            // Revealed on hover rather than inserted, so the switch below does
            // not shift sideways as the pointer moves down the list.
            Button {
                Task { await state.deleteRule(rule) }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L10n.delete)
            .accessibilityLabel(L10n.delete)
            .opacity(hoveredRuleID == rule.id ? 1 : 0)
            .disabled(hoveredRuleID != rule.id)

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
        .onHover { hoveredRuleID = $0 ? rule.id : nil }
        .onTapGesture { editingRule = rule }
        .contextMenu {
            Button(L10n.edit) { editingRule = rule }
            Button(L10n.delete, role: .destructive) {
                Task { await state.deleteRule(rule) }
            }
        }
    }

    /// Shown only while the helper is unreachable: what is wrong, plus the way
    /// out of it.
    private var daemonSection: some View {
        HStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
            Text(L10n.helper(state.daemonStatusDescription))
                .font(.caption)
            Spacer()
            if state.daemonStatus != .enabled {
                Button(L10n.install) { Task { await state.installDaemon() } }
                    .controlSize(.small)
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
                Button(L10n.uninstallHelper) {
                    if AppInfo.confirmUninstall() {
                        Task { await state.uninstallDaemon() }
                    }
                }
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
