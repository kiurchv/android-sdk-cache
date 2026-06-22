# android-sdk-cache

Мінімальний Android SDK + Gradle + Maven залежності для локальних білдів без dl.google.com / services.gradle.org.

## Що тут є

| Файл | Розмір | Що містить |
|------|--------|-----------|
| `build-tools-37.0.0.tar.gz` | ~62 MB | aapt2, d8, zipalign, apksigner |
| `platform-android-35.tar.gz` | ~57 MB | android.jar (compileSdk 35) |
| `gradle-8.14.5-bin.zip.part{aa,ab}` | ~132 MB | Gradle 8.14.5 binary |
| `deps-cache.tar.gz.part*` | ~500+ MB | Maven залежності (AGP, Kotlin, Hilt, Room, Compose…) |

## Швидкий старт

```bash
# Завантажує і встановлює все (~750MB)
curl -L https://raw.githubusercontent.com/kiurchv/android-sdk-cache/main/setup.sh | bash

# Або якщо вже склонував:
bash setup.sh

# Потім зібрати Cull:
cd /path/to/Cull
export ANDROID_SDK_ROOT=~/android-sdk
./build-local.sh
```

## Оновлення кешу залежностей

Запустити workflow `Package Maven Dependencies` вручну на GitHub після зміни залежностей в Cull.
