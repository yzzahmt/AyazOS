# AyazOS — Teknik Mimari

Hedef: Ubuntu 26.04 LTS (resolute), amd64. Snap yok, GNOME yok.

## Katmanlar
| Bileşen | Seçim | Not |
|---|---|---|
| Bileşik yönetici | Wayfire 0.10 (Ubuntu deposu) | wobbly, blur, animate, session-lock, foreign-toplevel depoda var |
| AyazOS efektleri | `compositor/` C++ Wayfire eklentileri | `ayaz-shatter` (kapatma), `ayaz-dock-minimize` (sağa küçülme) |
| Kabuk | Quickshell (Qt6/QML), kaynaktan derlenir, kendi .deb'imiz | Ubuntu deposunda yok |
| Giriş ekranı | greetd 0.10.3 + Quickshell greeter | |
| Kilit ekranı | Quickshell `WlSessionLock` | |
| Açılış | Plymouth teması `ayazos-blackhole` | Önceden işlenmiş kareler |
| Kurulum | Calamares 3.3.14 + `ayazos` markası | |
| ISO | `distro/` debootstrap + squashfs betikleri | ARM builder VM içinde amd64 chroot (qemu-user) |
| Güncelleme | İmzalı APT deposu `repo.ayazos` + `ayaz-update` servisi ve arayüzü | Ubuntu güncellemeleri + AyazOS paketleri |
| Uygulamalar | Qt6 C++ + QML (`apps/`) | Dosyalar, Ayarlar, Merkez, Doktor, Müzik |
| Not defteri | Veloneon Notes, Flutter Linux | `apps/veloneon/` |
| .exe | Wine + MIME/binfmt işleyici `ayaz-wine` | Uygulama başına yalıtılmış önek |
| Oyun | Steam, GameMode, MangoHud, `ubuntu-drivers` | |

## Paketler (AyazOS APT deposu)
- `ayazos-desktop` — meta paket, her şeyi çeker
- `ayazos-shell` — QML kabuk + Quickshell bağımlılığı
- `quickshell` — kaynaktan derlenmiş
- `ayazos-wayfire-plugins` — C++ efektler
- `ayazos-branding` — logo, duvar kağıtları, Plymouth, os-release, Calamares markası
- `ayazos-session` — wayfire.ini, greetd ayarı, oturum dosyası, sistem ayarları (zram, sysctl)
- `ayazos-update`, `ayazos-apps`, `ayazos-wine`, `veloneon-notes`

## Tasarım belirteçleri (referans ekran görüntüsünden)
| Belirteç | Değer |
|---|---|
| Zemin | `#0A0E15` |
| Cam yüzey | `rgba(20,26,36,0.78)` + blur |
| Cam yüzey açık | `rgba(36,44,58,0.70)` |
| Kenar | `rgba(255,255,255,0.08)` |
| Seçili satır | `rgba(120,150,200,0.14)` |
| Metin | `#E8EDF5` |
| İkincil metin | `#8A94A6` |
| Vurgu | `#A9C1F2` (düğme), metin `#0E1626` |
| Vurgu 2 (marka) | `#8B5CF6` mor |
| Köşe | pencere 22, kart 14, düğme 12, dock 26 |
| Yazı | Inter (fonts-inter) |
| Simgeler | Lucide tarzı ince çizgi, 1.75 px |
| Hareket | 220 ms standart, yay (spring) eğrileri; başlat menüsü 420 ms |

## Dizinler
```
branding/   logo, duvar kağıtları, plymouth, calamares
shell/      Quickshell QML kabuğu
compositor/ Wayfire eklentileri (C++)
apps/       Qt uygulamaları, veloneon
packaging/  debian paket tanımları
distro/     ISO derleme betikleri
repo/       APT deposu araçları
scripts/    ortam ve VM betikleri (yalnızca HDD)
vm/         sanal makine diskleri (git dışı)
```
