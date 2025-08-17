#!/bin/bash

echo "🚀 Сборка приложения Дневник Берика для обеих платформ"
echo "=============================================="

# Очистка проекта
echo "🧹 Очистка проекта..."
flutter clean
flutter pub get

echo ""
echo "📱 Сборка для Android..."
echo "------------------------"
flutter build apk --release
if [ $? -eq 0 ]; then
    echo "✅ Android APK собран успешно!"
    echo "📁 Файл: build/app/outputs/flutter-apk/app-release.apk"
else
    echo "❌ Ошибка сборки Android"
    exit 1
fi

echo ""
echo "🍎 Сборка для iOS..."
echo "--------------------"
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Только на macOS можно собирать iOS
    flutter build ios --release --no-codesign
    if [ $? -eq 0 ]; then
        echo "✅ iOS билд собран успешно!"
        echo "📁 Откройте ios/Runner.xcworkspace в Xcode для финальной сборки"
    else
        echo "❌ Ошибка сборки iOS"
        exit 1
    fi
else
    echo "⚠️  iOS сборка доступна только на macOS"
    echo "💡 Для сборки iOS используйте Mac или Xcode Cloud"
fi

echo ""
echo "🎉 Сборка завершена!"
echo "📋 Инструкции:"
echo "   • Android: Установите app-release.apk на устройство"
echo "   • iOS: Откройте проект в Xcode и соберите для App Store"