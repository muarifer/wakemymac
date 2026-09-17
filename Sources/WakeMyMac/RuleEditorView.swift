// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Murat Çeliker

import SwiftUI
import WakeCore

struct RuleEditorView: View {
    @State private var rule: Rule
    @State private var time: Date
    let isNew: Bool
    let onSave: (Rule) -> Void
    let onCancel: () -> Void

    init(rule: Rule, isNew: Bool = false,
         onSave: @escaping (Rule) -> Void, onCancel: @escaping () -> Void) {
        _rule = State(initialValue: rule)
        self.isNew = isNew
        var components = DateComponents()
        components.hour = rule.hour
        components.minute = rule.minute
        _time = State(initialValue: Calendar.current.date(from: components) ?? .now)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isNew ? L10n.newRule : L10n.editRule)
                .font(.headline)

            TextField(L10n.labelPlaceholder, text: $rule.label)
                .textFieldStyle(.roundedBorder)

            Picker(L10n.action, selection: $rule.action) {
                ForEach(PowerAction.allCases, id: \.self) { action in
                    Label(L10n.name(of: action), systemImage: action.symbolName)
                        .tag(action)
                }
            }

            DatePicker(L10n.time, selection: $time, displayedComponents: .hourAndMinute)

            weekdayPicker

            HStack {
                Button(L10n.cancel, role: .cancel, action: onCancel)
                Spacer()
                Button(L10n.save) {
                    let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                    var saved = rule
                    saved.hour = components.hour ?? 0
                    saved.minute = components.minute ?? 0
                    onSave(saved)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(rule.weekdays.isEmpty)
            }
        }
        .padding(12)
    }

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.repeatTitle).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                // Show Monday-first regardless of Calendar's weekday numbering.
                // Plain buttons with an explicit fill: bordered buttons don't
                // render their tint in a non-key menu bar extra window, which
                // makes the selection look dead.
                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                    // Fixed 1...7 literals, so the lookup is in range by
                    // construction; nil-coalescing keeps it total anyway.
                    let symbol = Calendar.current.shortWeekdaySymbols[safe: day - 1] ?? ""
                    let isOn = rule.weekdays.contains(day)
                    Button {
                        if isOn {
                            rule.weekdays.removeAll { $0 == day }
                        } else {
                            rule.weekdays = (rule.weekdays + [day]).sorted()
                        }
                    } label: {
                        Text(symbol)
                            .font(.caption)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 22)
                            .background(
                                isOn ? Color.accentColor : Color.secondary.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 5))
                            .foregroundStyle(isOn ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                Button(L10n.daily) { rule.weekdays = Array(1...7) }
                Button(L10n.weekdays) { rule.weekdays = Array(2...6) }
                Button(L10n.weekends) { rule.weekdays = [1, 7] }
            }
            .buttonStyle(.link)
            .font(.caption)
        }
    }
}
