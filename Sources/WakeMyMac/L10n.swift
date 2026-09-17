// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Murat Çeliker

import Foundation
import WakeCore

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Küçük yerelleştirme yardımcısı: varsayılan İngilizce, sistem dili Türkçe ise Türkçe.
/// (Elle oluşturulan .app paketinde .lproj kaynakları taşımamak için bilinçli olarak koddan.)
enum L10n {
    nonisolated(unsafe) static var isTurkish: Bool =
        Locale.preferredLanguages.first?.hasPrefix("tr") ?? false

    static func t(_ english: String, _ turkish: String) -> String {
        isTurkish ? turkish : english
    }

    // Menu
    static var nothingScheduled: String { t("Nothing scheduled", "Zamanlanmış olay yok") }
    static var noRules: String { t("No rules yet. Add one below.", "Henüz kural yok. Aşağıdan ekleyin.") }
    static var addRule: String { t("Add Rule", "Kural Ekle") }
    static var edit: String { t("Edit…", "Düzenle…") }
    static var delete: String { t("Delete", "Sil") }
    static var refresh: String { t("Refresh", "Yenile") }
    static var launchAtLogin: String { t("Launch at Login", "Girişte Başlat") }
    static var uninstallHelper: String { t("Uninstall Helper…", "Yardımcıyı Kaldır…") }
    static var uninstallConfirmTitle: String {
        t("Uninstall the WakeMyMac helper?", "WakeMyMac yardımcısı kaldırılsın mı?")
    }
    static var uninstallConfirmBody: String {
        t("All scheduled power events will be cancelled and your saved rules will be deleted. Your Mac will no longer wake, sleep or shut down on schedule.",
          "Zamanlanmış tüm güç olayları iptal edilecek ve kayıtlı kurallarınız silinecek. Mac'iniz artık programa göre uyanmayacak, uyumayacak veya kapanmayacak.")
    }
    static var uninstallConfirmAction: String { t("Uninstall", "Kaldır") }
    static var quit: String { t("Quit WakeMyMac", "WakeMyMac'ten Çık") }
    static var about: String { t("About WakeMyMac", "WakeMyMac Hakkında") }
    static var aboutCredits: String {
        t("Wakes, sleeps or shuts down your Mac on schedule.",
          "Mac'inizi zamanlanmış kurallarla uyandırır, uyutur veya kapatır.")
    }

    // Helper (daemon) status
    static func helper(_ status: String) -> String { t("Helper: \(status)", "Yardımcı: \(status)") }
    static var install: String { t("Install", "Kur") }
    static var statusRunning: String { t("Running", "Çalışıyor") }
    static var statusNotResponding: String { t("Enabled, not responding", "Etkin ama yanıt vermiyor") }
    static var statusWaitingApproval: String {
        t("Waiting for approval in System Settings", "Sistem Ayarları'nda onay bekliyor")
    }
    static var statusNotInstalled: String { t("Not installed", "Kurulu değil") }
    static var statusNotFound: String {
        t("Not found (run from the built .app bundle)", "Bulunamadı (derlenmiş .app paketinden çalıştırın)")
    }
    static var statusUnknown: String { t("Unknown", "Bilinmiyor") }

    // Rule editor
    static var newRule: String { t("New Rule", "Yeni Kural") }
    static var editRule: String { t("Edit Rule", "Kuralı Düzenle") }
    static var labelPlaceholder: String { t("Label (optional)", "Etiket (isteğe bağlı)") }
    static var action: String { t("Action", "Eylem") }
    static var time: String { t("Time", "Saat") }
    static var repeatTitle: String { t("Repeat", "Tekrar") }
    static var daily: String { t("Daily", "Her gün") }
    static var weekdays: String { t("Weekdays", "Hafta içi") }
    static var weekends: String { t("Weekends", "Hafta sonu") }
    static var cancel: String { t("Cancel", "Vazgeç") }
    static var save: String { t("Save", "Kaydet") }

    static var everyDay: String { t("Every day", "Her gün") }
    static var repeatsMode: String { t("Repeats", "Tekrarlı") }
    static var onceMode: String { t("Once", "Tek seferlik") }
    static var date: String { t("Date", "Tarih") }
    static var expired: String { t("Expired", "Süresi geçti") }

    static func name(of action: PowerAction) -> String {
        switch action {
        case .wake: return t("Wake", "Uyandır")
        case .powerOn: return t("Power On", "Aç")
        case .wakeOrPowerOn: return t("Wake or Power On", "Uyandır veya Aç")
        case .sleep: return t("Sleep", "Uyut")
        case .shutdown: return t("Shut Down", "Kapat")
        case .restart: return t("Restart", "Yeniden Başlat")
        }
    }

    /// Falls back to the bare action name, never "Wake at 08:00": the row's
    /// second line already carries the schedule, so including the time here
    /// prints it twice.
    static func title(of rule: Rule) -> String {
        rule.label.isEmpty ? name(of: rule.action) : rule.label
    }

    /// The "when" line under a rule's title: a weekly pattern, or the date of a
    /// one-time rule (marked once its moment has passed).
    static func scheduleText(of rule: Rule, calendar: Calendar = .current) -> String {
        switch rule.repeats {
        case .once:
            guard let when = rule.scheduledDate(calendar: calendar) else { return expired }
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            let day = formatter.string(from: when)
            return rule.isExpired() ? "\(expired) · \(day)" : day

        case .weekly(let weekdays):
            let days = Set(weekdays)
            if days == Set(1...7) { return everyDay }
            if days == Set(2...6) { return self.weekdays }
            if days == Set([1, 7]) { return weekends }
            // Rule's initializer keeps weekdays within 1...7, but this stays
            // defensive: a bad symbol lookup would crash the whole menu bar app.
            let symbols = calendar.shortWeekdaySymbols
            return weekdays.compactMap { symbols[safe: $0 - 1] }.joined(separator: " ")
        }
    }
}
