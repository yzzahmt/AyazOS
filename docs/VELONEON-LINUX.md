# VeloNeon Notes: Linux sürümü

Branch: `linux-desktop` (repo: `VeloNeon_note`, proje klasörü `flutter_application_1`).

## Linux'ta çalışanlar
- Uygulama doğrudan notlara açılır. Giriş, kayıt ve KVKK ekranı yok.
- Notlar yerelde saklanır: `$XDG_DATA_HOME/veloneon-notes/notes.json` (yoksa `~/.local/share/veloneon-notes/`).
- Not oluşturma, düzenleme, silme, arama, klasörler, favoriler, takvim, çizim ekranı, temalar.
- Gizli Notlar PIN ile korunur. PIN Linux'ta ayarlarda (shared_preferences) tutulur, anahtarlık gerekmez.

## Linux'ta gizlenenler
- Sesli not, Vision AI (ML Kit), PDF AI, sesle yazma, biyometrik kilit.
- Çıkış yap ve hesabı sil (hesap yok).
- Yapay zeka sohbeti internet ister, çevrimdışıyken çalışmaz.

## Nasıl yapıldı
- `lib/data/db.dart` Firestore ile aynı isimlere sahip küçük bir katman. Ekranlar sadece bunu import eder.
  - Android/iOS: `db_firebase.dart` gerçek Firestore'a bağlanır.
  - Linux: `db_local.dart` JSON dosyasına yazar.
- `lib/data/auth.dart` aynı şekilde FirebaseAuth yerine geçer. Linux'ta hep "local-user" açıktır.
- `lib/data/platform_info.dart`: `isLinuxDesktop` ve `hasMobileFeatures` bayrakları.
- `third_party/flutter_secure_storage_linux`: boş bir paket. Orijinali yeni clang ile derlenmiyor (`-Werror`), Linux'ta zaten kullanmıyoruz. Mobil etkilenmez.

## Derleme
VM içinde (Ubuntu, Flutter stable):

```
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev \
  libsecret-1-dev libjsoncpp-dev libasound2-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
cd flutter_application_1
flutter pub get
flutter build linux --release
```

Çıktı: `build/linux/<arch>/release/bundle/`. Çalışma zamanında GTK3, GStreamer (audioplayers) ve ALSA kütüphaneleri gerekir.

Mac'ten VM'e kopyalama: `scripts/vssh-raw` ile `rsync -e`.

## Notlar
- Test: `flutter test test/local_db_test.dart` (yerel depo, sadece Linux'ta çalışır).
- arm64 VM'de derlendi ve başlatıldı. amd64 aynı kaynaktan sonra derlenecek.
- Sürüm numarasını yükselten eski bir yerel değişiklik `git stash` içinde bekliyor.
