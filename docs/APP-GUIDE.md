# AyazOS uygulama geliştirme rehberi

Sistem uygulamaları tek bir Qt taşıyıcısıyla çalışır: `ayaz-app <ad>`.

- QML giriş noktası: `apps/<ad>/Main.qml` (kökte bir `Window`, `flags: Qt.Window | Qt.FramelessWindowHint`, `color: "transparent"`).
- Masaüstü dosyası: `apps/<ad>/ayaz-<ad>.desktop`. Wayland app_id `ayaz-<ad>` olur.
- Ortak tasarım: `import AyazOS.UI` → `Theme` (renk, köşe, yazı, süreler), `Glass`, `Icon { name: "<lucide adı>" }`, `IconButton`.
  Simgeler `shell/assets/icons/*.svg` (Lucide). Yeni simge: `https://unpkg.com/lucide-static@0.469.0/icons/<ad>.svg`,
  `currentColor` → `#E8EDF5`, `stroke-width` → `1.75`.
- Yerel yardımcılar: `import AyazOS.Native` → `Fs` (dosya sistemi), `Proc` (komut çalıştırma:
  `Proc { id: p; onFinished: (code, out, err) => ... }` + `p.startWith(["komut", "arg"])`, `Proc.detached([...])`).
- Referans uygulama: `apps/files/Main.qml` (başlık çubuğu, pencere taşıma, kenar çubuğu, liste).
- Tasarım dili: koyu lacivert cam, ince açık kenarlar, büyük köşeler, açık mavi vurgu (`Theme.accent`), Inter yazı tipi.
- Yetki gereken işlemler `pkexec` ile yapılır; masaüstündeki polkit penceresi parolayı sorar.

## Geliştirme ortamında deneme (derleme VM'i)
```
scripts/vsync                                  # projeyi VM'e eşitle
scripts/vssh 'ninja -C /tmp/hostbuild'         # taşıyıcıyı derle (apps/host değiştiyse)
scripts/vssh 'AYAZ_APPS_DIR=~/AyazOS/apps AYAZ_QML_DIR=/tmp/ayazqml /tmp/hostbuild/ayaz-app <ad>'
```
`/tmp/ayazqml` AyazOS.UI modülünün geliştirme kopyasıdır.
