# AyazOS — Ürün ve Mimari Belgesi

Durum: taslak, 2026-11-05. "Doğrulanacak" yazan maddeler henüz test edilmedi.

## Amaç
Normal seviyedeki bilgisayarlar için Windows alternatifi, Ubuntu tabanlı,
GNOME içermeyen, tasarımdan ödün vermeyen kişisel kullanım dağıtımı.
Hedef mimari Intel/AMD 64 bit (x86_64). Çok eski bilgisayarlar hedef dışı.
Hedef kitle terminal kullanmak istemeyen kişiler.

## Uzaktan güncelleme
İmzalı AyazOS APT deposu ve `ayaz-update` servisi. Ayrıntılar `docs/ARCHITECTURE.md`.

## Tasarım dili
Referans: masaüstü tasarım taslağı (Dosyalar penceresi, sağ dock, üst çubuk, müzik bileşeni).

- Üst çubuk: logo, uygulama menüleri, Odak, Wi-Fi, ses, pil, tarih, saat, hızlı ayarlar
- Sağda dikey dock; simgeler opak olabilir, etkin uygulamada nokta göstergesi
- Koyu lacivert cam yüzeyler, ince açık kenarlar, büyük yuvarlak köşeler, açık mavi vurgu
- Masaüstünde selamlama ("Kendine alan aç."), müzik bileşeni, çalışma alanı göstergesi
- Tüm sistemde cam ve su hissi

## Animasyonlar
| Olay | Davranış | Kaynak |
|---|---|---|
| Super tuşu | Dock'taki logodan sağdan sola açılan başlat menüsü | Kabuk (QML) |
| Pencere sürükleme | Dalgalanma (wobbly) | Wayfire `wobbly`, doğrulanacak |
| Küçültme | Sağa, dock'a doğru küçülme | Wayfire eklentisi |
| Kapatma | Kırılıp parçalanma | Yeni C++ eklentisi yazılacak |
| Cam | Arka plan bulanıklığı | Wayfire `blur`, doğrulanacak |
| Açılış | Dönen mor kara delik, "Welcome to AyazOS" | Önceden işlenmiş kareler + Plymouth |


## Mimari
| Katman | Seçim | Gerekçe |
|---|---|---|
| Taban | Ubuntu 26.04 LTS | 5 yıl destek, geniş donanım ve paket uyumu |
| Bileşik yönetici | Wayfire 0.10 (depoda 0.10.0-1) | Hafif, eklentili, efekt odaklı |
| Yedek | KWin | Wayfire donanım uyumunda başarısız olursa |
| Kabuk | Quickshell (Qt6/QML) | Dock, menü, kilit ekranı, bileşenler; paketleme doğrulanacak |
| Giriş | greetd + özel arayüz | GDM ve GNOME bağımlılığı yok |
| Kurulum | Calamares 3.3.14 (depoda var) | Marka uygulanabilir, sade akış |
| İmaj | live-build tabanlı, betikli | Tekrarlanabilir ISO |
| Tarayıcı | Firefox, Mozilla APT deposu | Snap yok, daha hızlı açılış |
| Uygulama merkezi | AppStream + APT + Flatpak üzerine özel arayüz | Snap yok |
| Windows uygulamaları | Wine + binfmt/MIME, `.exe` için tek tık | Yalıtılmış önek, otomatik bağımlılık |

## Hız, pil, ısı
- Snap, apport, GNOME servisleri ve dosya indeksleme varsayılan olarak yok
- zram, systemd-oomd, profil tabanlı önyükleme ve servis temizliği
- power-profiles-daemon ve thermald; dizüstünde pil profili
- Oyunda GameMode, tam ekranda doğrudan tarama ve efektlerin devre dışı kalması
- Uyarlanabilir cam: zayıf GPU'da canlı bulanıklık yerine önceden bulanıklaştırılmış
  duvar kağıdı. Görünüm büyük ölçüde korunur, GPU maliyeti düşer.

### Ölçülecek hedefler
Aynı makinede Ubuntu 26.04 ile karşılaştırılır. Sayılar hedeftir, henüz ölçülmedi.

| Ölçüt | Hedef |
|---|---|
| Boşta RAM | < 800 MB |
| Boşta CPU | < %1 |
| Firefox ilk açılış | Ubuntu'dan belirgin hızlı |
| Efekt akıcılığı | Hedef donanımda 60 FPS |
| Uykudan dönüş | Desteklenen donanımda < 2 sn |

## Uygulamalar
- Dosyalar, Ayarlar, Yazılım Merkezi, Sistem Doktoru (terminalsiz sorun çözme)
- Müzik, Galeri, Terminal, kilit ekranı, bileşenler
- Veloneon Notes: varsayılan not defteri
- Oyun paketi: Steam, Proton, GameMode, MangoHud
- Sürücü: `ubuntu-drivers` tabanlı arka plan algılama ve arayüz

## Veloneon Linux uyarlaması
Kaynak: `/Volumes/HDD/Projeler/Projeler/VeloNeon_note/flutter_application_1`
(Flutter, ~14.600 satır Dart, `linux/` klasörü mevcut).

| Bağımlılık | Durum | Plan |
|---|---|---|
| Firebase Auth + Firestore (11'er dosya) | Linux'ta resmi destek beklenmiyor, doğrulanacak | Yerel öncelikli depo, bulut eşitleme REST ile |
| Google ML Kit (4 paket) | Yalnızca mobil | Linux'ta kapat ya da yerel alternatif |
| `speech_to_text`, `local_auth` | Linux desteği doğrulanacak | Kapat ya da değiştir |
| Syncfusion PDF | Lisans koşulları dağıtım için kontrol edilecek | Gerekirse açık kaynak PDF paketi |

## Görseller
- Yazify ana sayfası: `artifacts/yazify/src/components/GalaxyCanvas.tsx` (Three.js sarmal galaksi).
  Varsayılan duvar kağıdı bundan yüksek çözünürlükte işlenir.
- Mor kara delik: yerel kodda ana sayfada bulunamadı. Benzer disk efekti
  `components/ui/radial-orbital-timeline.tsx` içinde ama kaynakta hiçbir yerden çağrılmıyor.
- Yeni logo tasarlanacak; Y logosu yerine geçecek.
- Uzay temalı duvar kağıdı koleksiyonu üretilecek.

## Bilinen sınırlar
- Küresel menü: Firefox gibi GTK uygulamaları Wayland'de üst çubuğa menü aktarmaz.
  Menüler kendi uygulamalarımızda çalışır, diğerlerinde yalnızca uygulama adı görünür.
- Wine: çekirdek anti-cheat kullanan oyunlar ve bazı profesyonel yazılımlar çalışmayabilir.
- Eski NVIDIA kartlar: Wayland desteği zayıf, yedek davranış gerekir.
- Uyku: donanıma bağlı. Her cihazda macOS seviyesi garanti edilemez.
- Oyunda en yüksek performans ile ısınmama birbirine ters düşer; profiller dengeyi kurar.

## Yasal
Canonical politikası: değiştirilmiş sürümde Ubuntu markaları kaldırılmalı ve yazılı izin yoksa
ikili paketler kaynaktan yeniden derlenmelidir. Kişisel geliştirme engellenmez.
Herkese açık dağıtımdan önce Canonical'dan yazılı teyit alınmalı ya da taban yeniden
değerlendirilmelidir. https://canonical.com/legal/intellectual-property-policy

## Aşamalar
| # | Aşama | Bitiş ölçütü |
|---|---|---|
| 0 | Donanım testi | Wayfire efektleri eski ve orta makinede ölçüldü |
| 1 | Kimlik | Logo, renkler, duvar kağıdı, kara delik karesi onaylandı |
| 2 | Masaüstü | Dock, üst çubuk, başlat menüsü, kilit ekranı çalışıyor |
| 3 | Animasyon | Parçalanma ve küçültme eklentileri akıcı çalışıyor |
| 4 | İlk ISO | Boş diske kurulum, açılış ve giriş sorunsuz |
| 5 | Uygulamalar | Dosyalar, Ayarlar, Merkez, Doktor, Veloneon |
| 6 | Windows ve oyun | `.exe` çift tık, sürücü algılama, Steam |
| 7 | Sağlamlık | Uyku, pil, ısı ve donanım matrisi |
| 8 | Yayın | Güncelleme deposu, yasal teyit, herkese açık ISO |

## Test ortamı
Geliştirme makinesi Apple Silicon. Derleme bir ARM64 Ubuntu sanal makinesinde amd64 chroot ile yapılır,
ISO x86_64 QEMU ile denenir. Performans ölçümü gerçek Intel/AMD donanımda yapılmalıdır.
