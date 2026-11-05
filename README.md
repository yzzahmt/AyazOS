# AyazOS

Ubuntu 26.04 LTS tabanlı, GNOME kullanmayan, hızlı ve şık bir masaüstü Linux dağıtımı.
Hedef: Intel/AMD 64 bit, normal seviye bilgisayarlar.

## Yapı
| Katman | Bileşen |
|---|---|
| Bileşik yönetici | Wayfire + AyazOS efekt eklentileri (`compositor/`) |
| Masaüstü kabuğu | Quickshell / QML (`shell/`) |
| Giriş | greetd |
| Kurulum | Calamares |
| Güncellemeler | İmzalı AyazOS APT deposu |

## Dizinler
```
branding/   logo, duvar kağıtları, açılış animasyonu
shell/      üst çubuk, dock, başlat menüsü, kilit ekranı, kontrol merkezi
compositor/ Wayfire eklentileri
apps/       sistem uygulamaları
packaging/  Debian paketleri
distro/     ISO derleme betikleri
docs/       ürün ve mimari belgeleri
```

## Geliştirme
Kabuğu çalışan bir Wayfire oturumunda denemek için:
```sh
mkdir -p ~/.config/quickshell && ln -s "$PWD/shell" ~/.config/quickshell/ayazos
qs -c ayazos
```

Ayrıntılar: [docs/SPEC.md](docs/SPEC.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
