# WakeMyMac Mimarisi

## Temel fikir

macOS'ta zamanlanmış güç olaylarının tek gerçek API'si `IOPMSchedulePowerEvent`
(IOKit/pwr_mgt). İstenen sayıda **tek seferlik** wake/poweron/sleep/shutdown/restart
olayı kabul eder; `pmset schedule` de aynı API'yi kullanır. `pmset repeat`'in
"tek tekrarlı olay" sınırı API'nin değil pmset'in sınırıdır.

Tekrarlı kurallar bu yüzden uygulama katmanında çözülür:

```
kurallar (rules.json)
   │  her kural için nextOccurrence(after:) hesapla
   ▼
IOPMSchedulePowerEvent(date, owner, type)   ← kural başına 1 tek seferlik olay
   │  en erken olay + 30 sn sonra timer
   ▼
yeniden hesapla → sıradaki gerçekleşmeleri yaz   (döngü)
```

## Bileşenler

### WakeCore (paylaşılan)
- `Rule`: eylem + saat/dakika + hafta günleri (`Calendar` numaralandırması,
  1=Pazar…7=Cumartesi). `nextOccurrence(after:calendar:)` saf fonksiyon —
  test edilebilirliğin tamamı burada.
- `WakeDaemonProtocol`: XPC arayüzü. Payload'lar JSON `Data` olarak taşınır;
  NSSecureCoding yüzeyi bilinçli olarak minimal tutuldu.
- `RuleStore`: atomik JSON okuma/yazma; testler temp dizine yönlendirir.

### wakemymacd (root daemon)
- `SMAppService.daemon(plistName:)` ile kayıt (macOS 13+). Plist app bundle
  içinde `Contents/Library/LaunchDaemons/`, program `BundleProgram` ile bundle
  içindeki binary'yi gösterir. launchd root olarak çalıştırır — wake/poweron
  olayları root ister, daemon'un varlık sebebi bu.
- `PowerEventScheduler`: IOPM çağrılarının ince sarmalayıcısı. Olaylarımız
  `owner` dizesiyle etiketlenir; yeniden zamanlamada yalnız kendi olaylarımız
  iptal edilir (`IOPMCopyScheduledPowerEvents` → filtrele → cancel).
- `SchedulerEngine`: tek seri kuyruk üstünde durum. Re-arm timer'ı
  **wall-clock deadline** kullanır ki uyku sonrası da doğru tetiklensin.
  Olay için en az 60 sn ileri tarih verilir (powerd çok yakın tarihleri
  düşürebilir); yeniden hesap "şimdi + 60 sn" sonrasına bakar, böylece az
  önce ateşlenen occurrence tekrar seçilmez.
- Sleep/shutdown/restart olaylarını powerd/loginwindow yürütür; daemon'un
  ayrıca `shutdown` çağırması gerekmez.

### WakeMyMac (menü bar uygulaması)
- SwiftUI `MenuBarExtra` (.window stili): kural listesi, sonraki olaya canlı
  geri sayım (`TimelineView`), kural editörü, daemon durumu/kurulumu,
  launch-at-login (`SMAppService.mainApp`).
- `DaemonClient`: `NSXPCConnection(machServiceName:options:.privileged)`.
  Her çağrı 5 sn timeout'lu async sarmalayıcıdan geçer; daemon onaylanmamışsa
  UI "Waiting for approval" gösterir ve Sistem Ayarları'na yönlendirir.
- Gerçeğin kaynağı daemon'daki `rules.json`; uygulama her açılışta XPC ile çeker.

## Bilinçli kararlar / kısıtlar

- **SPM + birleştirme script'i, Xcode projesi yok.** `swift build --arch arm64
  --arch x86_64` universal binary üretir; `build.sh` bundle'ı kurar,
  Info.plist + daemon plist'i üretir, imzalar. Xcode projesi gerekirse sonra
  XcodeGen ile türetilebilir.
- **Ad-hoc imza geliştirme içindir.** `SMAppService` ad-hoc imzayla kendi
  makinede çalışır; dağıtım Developer ID + notarization ister.
- **XPC'nin iki ucu da imzaya sabitlenir** (`CodeSigningRequirement`).
  Sistem alanındaki bir Mach servisine her yerel süreç erişebildiği için,
  gereksinim olmadan makinedeki herhangi bir program kapatma zamanlayabilir
  ya da kullanıcının kurallarını silebilirdi. Gereksinim dizesi *çağıran
  binary'nin kendi imzasından* türetilir: Developer ID derlemesi karşı tarafı
  aynı takıma sabitler, ad-hoc geliştirme derlemesinde sabitlenecek takım
  olmadığından yalnız bundle identifier aranır — aksi halde `./build.sh`
  çıktısı kendi daemon'ıyla konuşamazdı. Dize yalnızca derleme zamanı
  sabitlerinden ve kendi imzamızdan kurulur, karşı taraftan gelen hiçbir
  veriden değil: `setCodeSigningRequirement` bozuk bir gereksinimde
  yakalanamayan exception atar.
- **Zaman dilimi/DST:** occurrence hesabı `Calendar.current` ile yerel saatte
  yapılır ve mutlak `Date` yazılır. TZ/DST değişince mevcut kayıtlı olay eski
  duvarsaat karşılığında kalır; bir sonraki re-arm'da düzelir. (İyileştirme:
  `NSSystemTimeZoneDidChange` dinleyip anında yeniden zamanlama.)
- **Onarım döngüsü:** launchd `KeepAlive` ile daemon hep ayakta; çökerse
  yeniden başlar ve `start()` her açılışta tam yeniden zamanlama yapar —
  durumun tamamı rules.json'dan türetilebilir, diskte başka durum yok.
  Hiçbir kural sisteme yazılamazsa (IOPM hatası) 5 dakikada bir yeniden
  denenir; aksi halde zamanlama bir sonraki yeniden başlatmaya kadar sessizce
  ölürdü.
- **Kaldırma açıkça temizlenir.** launchd yalnız süreci durdurur, sürecin
  powerd'ye yazdıklarını geri almaz. Bu yüzden uygulama `unregister()`
  öncesi daemon'a `prepareForRemoval` der: olaylar iptal edilir, rules.json
  silinir. SIGTERM üstünden otomatik temizlik **bilerek yapılmaz** — kapanma
  sırasında da SIGTERM gelir ve o an "açılış" olayını iptal etmek tam olarak
  makinenin bir daha açılmamasına yol açardı. Kullanıcı uygulamayı Kaldır
  demeden silerse hasar sınırlıdır: olaylar tek seferliktir, kural başına en
  fazla bir olay daha tetiklenir, sonra susar.
- **Girdi sınırları.** `Rule`'un designated init'i hour/minute/weekday/etiket
  invariantlarını zorlar ve `init(from:)` ona devreder — sentezlenmiş decode
  doğrulamayı atladığı için elle düzenlenmiş bir rules.json weekday 0 veya 8
  taşıyıp menü barını çökertebiliyordu. Daemon ayrıca payload boyutunu ve
  kural sayısını sınırlar; her kural gerçek bir sistem güç olayına dönüştüğü
  için sınırsız liste powerd'yi doldururdu.
