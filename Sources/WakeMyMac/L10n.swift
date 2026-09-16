import Foundation
import WakeCore

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
    static var quit: String { t("Quit WakeMyMac", "WakeMyMac'ten Çık") }

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

    static func title(of rule: Rule) -> String {
        rule.label.isEmpty ? t("\(name(of: rule.action)) at \(rule.timeString)",
                               "\(rule.timeString) \(name(of: rule.action))")
                           : rule.label
    }

    static func weekdaysText(of rule: Rule, calendar: Calendar = .current) -> String {
        let days = Set(rule.weekdays)
        if days == Set(1...7) { return everyDay }
        if days == Set(2...6) { return weekdays }
        if days == Set([1, 7]) { return weekends }
        let symbols = calendar.shortWeekdaySymbols
        return rule.weekdays.map { symbols[$0 - 1] }.joined(separator: " ")
    }
}
