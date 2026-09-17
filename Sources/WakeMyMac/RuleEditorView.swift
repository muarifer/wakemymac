// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Murat Çeliker

import SwiftUI
import WakeCore

struct RuleEditorView: View {
    private enum Mode: Hashable { case repeats, once }

    @State private var rule: Rule
    @State private var time: Date
    /// Calendar day for a one-time rule. Held separately from `time` so
    /// switching modes back and forth never loses either choice.
    @State private var day: Date
    @State private var mode: Mode
    let isNew: Bool
    let onSave: (Rule) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    init(rule: Rule, isNew: Bool = false,
         onSave: @escaping (Rule) -> Void,
         onDelete: @escaping () -> Void,
         onCancel: @escaping () -> Void) {
        _rule = State(initialValue: rule)
        self.isNew = isNew
        self.onDelete = onDelete
        var components = DateComponents()
        components.hour = rule.hour
        components.minute = rule.minute
        _time = State(initialValue: Calendar.current.date(from: components) ?? .now)
        _mode = State(initialValue: rule.repeats.isOnce ? .once : .repeats)
        // An expired rule reopens on today rather than its spent date, so
        // saving it again actually schedules something.
        let scheduled = rule.scheduledDate()
        _day = State(initialValue: max(scheduled ?? Date(), Date()))
        self.onSave = onSave
        self.onCancel = onCancel
    }

    /// Weekly rules need at least one day; a one-time rule needs a moment that
    /// has not already gone by.
    private var canSave: Bool {
        switch mode {
        case .repeats: return !rule.repeats.weekdays.isEmpty
        case .once: return composed().nextOccurrence(after: Date()) != nil
        }
    }

    /// The rule as the current form state describes it.
    private func composed() -> Rule {
        let calendar = Calendar.current
        let clock = calendar.dateComponents([.hour, .minute], from: time)
        var saved = rule
        saved.hour = clock.hour ?? 0
        saved.minute = clock.minute ?? 0
        switch mode {
        case .repeats:
            saved.repeats = .weekly(weekdays: rule.repeats.weekdays)
        case .once:
            let ymd = calendar.dateComponents([.year, .month, .day], from: day)
            saved.repeats = .once(year: ymd.year ?? 0, month: ymd.month ?? 0, day: ymd.day ?? 0)
        }
        return saved
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

            Picker("", selection: $mode) {
                Text(L10n.repeatsMode).tag(Mode.repeats)
                Text(L10n.onceMode).tag(Mode.once)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            DatePicker(L10n.time, selection: $time, displayedComponents: .hourAndMinute)

            if mode == .once {
                DatePicker(L10n.date, selection: $day, in: Date()...,
                           displayedComponents: .date)
            } else {
                weekdayPicker
            }

            HStack {
                Button(L10n.cancel, role: .cancel, action: onCancel)
                if !isNew {
                    Button(L10n.delete, role: .destructive, action: onDelete)
                }
                Spacer()
                Button(L10n.save) { onSave(composed()) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(12)
    }

    /// Kept sorted so the row's "Mon Tue Wed" summary reads in day order.
    private func weekdayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { rule.repeats.weekdays.contains(weekday) },
            set: { isOn in
                var days = rule.repeats.weekdays
                if isOn {
                    days = (days + [weekday]).sorted()
                } else {
                    days.removeAll { $0 == weekday }
                }
                rule.repeats = .weekly(weekdays: days)
            }
        )
    }

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.repeatTitle).font(.caption).foregroundStyle(.secondary)
            // Four per row: seven checkboxes with day labels do not fit the
            // panel's width in a single line. Monday-first regardless of the
            // calendar's own weekday numbering.
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 4),
                alignment: .leading, spacing: 2
            ) {
                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { weekday in
                    // Fixed 1...7 literals, so the lookup is in range by
                    // construction; nil-coalescing keeps it total anyway.
                    let symbol = Calendar.current.shortWeekdaySymbols[safe: weekday - 1] ?? ""
                    Toggle(symbol, isOn: weekdayBinding(weekday))
                        .toggleStyle(.checkbox)
                }
            }
            HStack(spacing: 8) {
                Button(L10n.daily) { rule.repeats = .weekly(weekdays: Array(1...7)) }
                Button(L10n.weekdays) { rule.repeats = .weekly(weekdays: Array(2...6)) }
                Button(L10n.weekends) { rule.repeats = .weekly(weekdays: [1, 7]) }
            }
            .buttonStyle(.link)
            .font(.caption)
        }
    }
}
