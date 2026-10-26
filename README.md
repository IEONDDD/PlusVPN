<p align="center">
  <img src="branding/plusvpn-icon.png" width="140" alt="PlusVPN" />
</p>

<h1 align="center">PlusVPN</h1>

<p align="center">
  Android VPN-клиент на Flutter (Dart) и Kotlin на базе Xray core.
</p>

<p align="center">
  <a href="https://t.me/OnPlusVPN"><img src="https://img.shields.io/badge/Telegram-Канал_с_обновлениями-0088cc?logo=telegram&logoColor=white" alt="Telegram" /></a>
  <a href="https://github.com/IEONDDD/PlusVPN/releases/latest"><img src="https://img.shields.io/badge/Release-v1.1.0-0088cc?logo=github&logoColor=white" alt="Release" /></a>
</p>

---

Версия исходников **1.1.0+2**. VPN-ядро: `flutter_v2ray_client: 3.5.0` / Xray 26.9.9.

## Оформление

В **Настройки → Оформление → Стиль интерфейса** доступны два режима:

- **Liquid Glass**: прозрачные панели с размытием, бликами и тонкой окантовкой. Прозрачность карточек регулируется от 2% до 20%. Фон из галереи, размытие и цвет из обоев доступны в этом режиме.
- **Material You**: непрозрачные поверхности Material 3, Material-навигация, кнопки, переключатели и типографика. При выборе режима включается системная палитра Android 12+; можно выбрать собственный акцент.

Тема, DNS, подписки и стиль выбираются через скруглённые панели снизу. Диалоги импорта, выбора цвета, исключений приложений и удаления подписок используют текущее оформление. В Material You стеклянные фильтры не создаются. Светлая, тёмная и системная темы работают в обоих режимах.

Бренд приложения, заголовок, уведомление и плитка — **PlusVPN**. Иконка: квадратная монограмма `1+` с VPN-замком на красном фоне. Есть adaptive icon и monochrome-вариант Android 13+. Редактируемый оригинал: [branding/plusvpn-logo.svg](branding/plusvpn-logo.svg).

## Подключения и подписки

Нажмите `+` и выберите способ добавления:

- вставить одиночный VLESS, VMess, Shadowsocks/SIP002 или Trojan ключ;
- вставить HTTPS-ссылку на подписку;
- вставить JSON Xray;
- нажать **JSON-файл** и открыть документ через системный выбор файлов Android.

HTTPS-подписки принимают обычные списки URI, Base64-списки, один JSON-профиль, JSON-массив профилей и объект с массивом `profiles`. Base64 JSON тоже распознаётся. Подписка обновляется по исходной ссылке. Название, квота и срок действия читаются из `profile-title` и `subscription-userinfo`.

Пример структуры JSON (поля подключения заполните своими значениями):

```json
[
  {
    "remarks": "Название сервера",
    "outbounds": [
      {
        "tag": "proxy",
        "protocol": "vless",
        "settings": {
          "vnext": [
            {
              "address": "vpn.example",
              "port": 443,
              "users": [
                { "id": "aabbccdd-1234-4567-89ab-aabbccddeeff", "encryption": "none" }
              ]
            }
          ]
        },
        "streamSettings": { "network": "tcp", "security": "none" }
      }
    ]
  }
]
```

При импорте полного JSON сохраняются `outbounds`, Reality, `xhttpSettings` вместе с `extra`, `sockopt`, маршруты, `balancers`, `observatory` и другие поля конфигурации. Профиль «Автовыбор» остаётся самостоятельным профилем с балансировщиком, а не превращается в один сервер. Название берётся из `remarks`, `ps`, `name` или `tag`. DNS из JSON сохраняется по умолчанию; его можно переопределить в настройках сети.

Android-сервис создаёт TUN самостоятельно. Локальные SOCKS/HTTP-входы привязываются к `127.0.0.1` на портах 10808/10809. Настройка обхода LAN добавляет частные подсети к маршрутам, сохраняя существующие правила подписки. Размер файла/HTTP-ответа ограничен 4 МБ. Личные JSON-профили и ключи в репозиторий не включены.

Поддерживаются URI-транспорты TCP, WebSocket, gRPC и XHTTP. Есть реальный TCP-пинг с ограничением параллелизма, сортировка, обновление/удаление подписок, исключения приложений из VPN и DNS 1.1.1.1 / 8.8.8.8. Изменения сети применяются при следующем подключении; смена активного сервера выполняет переподключение.

## Требования и сборка

Использован Flutter **3.47.8**, Dart **3.13.7**. Нужны JDK **21**, Android SDK Platform **36**, NDK **28.2.13676358**, CMake **3.31.6**. Минимальный Android — **7.0 / API 24**.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Для самостоятельной сборки APK:

```sh
flutter build apk --release
```

Результат: `build/app/outputs/flutter-apk/app-release.apk`. Для отдельных архитектур добавьте `--split-per-abi`.

Выбранную Java показывает `flutter doctor -v`. При необходимости используйте `flutter config --jdk-dir="ПУТЬ_К_JDK_21"` — эта команда изменяет настройку Flutter на вашей машине. Java 25 не подходит Gradle 8.14.3. AGP 8.13.0 и Kotlin 2.2.20 выбраны для совместимости с VPN-плагином; новый Flutter выводит предупреждения об их будущей замене.

Для подписи собственным ключом скопируйте `android/key.properties.example` в `android/key.properties` и заполните поля. Без этого файла локальная release-сборка использует debug-ключ. `key.properties` и хранилища ключей исключены из Git.

### Плитка Android

Добавьте **PlusVPN** в редакторе быстрых настроек. Плитка показывает название и флаг выбранного сервера, включает/выключает тот же VPN-сервис с последним сохранённым конфигом без запуска Flutter UI. Первое подключение требует системного согласия; для плитки используется нативная `VpnPermissionActivity`.

## Структура

```text
lib/
  main.dart                         приложение, общий фон и навигация
  models.dart                       профили, подписки, настройки
  app_state.dart                    сохранение, импорт и управление соединением
  theme/app_theme.dart              Liquid Glass / Material You для всего UI
  widgets/common.dart               поверхности, панели выбора и диалоги
  widgets/plus_logo.dart             векторная монограмма PlusVPN
  services/
    subscription_service.dart       URI, Base64, JSON Xray, HTTPS и заголовки
    config_builder.dart             генератор и адаптация полного Xray JSON
    vpn_engine.dart                 MethodChannel и TCP-пинг
  tabs/                             главная, серверы, настройки
android/app/src/main/
  AndroidManifest.xml               сервисы, плитка, иконка и разрешения
  kotlin/com/plusvpn/plus_vpn/
    MainActivity.kt                 разрешения, выбор JSON, список приложений
    VpnBridge.kt                    PlusVpnApplication и управление ядром
    VpnTileService.kt               Quick Settings
    VpnPermissionActivity.kt        системное согласие для плитки
branding/plusvpn-logo.svg            исходник логотипа
```

## Проверки версии 1.1.0

Выполнены **27 успешных тестов**, включая локальную проверку всех 9 профилей предоставленного JSON. Проверены сохранение Reality/XHTTP, балансировщика, observatory, DNS и маршрутов; импорт по HTTPS и из файла; стабильные идентификаторы; смена стиля, темы и DNS; панели и диалоги в обоих режимах при ширине 320/360 px. Превью интерфейса отрисованы средствами Flutter и просмотрены.

`flutter analyze` проходит без замечаний. Успешны задачи `:app:compileReleaseKotlin` и `:app:processReleaseResources`; APK версии 1.1.0 по просьбе пользователя не создавался. Подключение к реальным серверам из личной подписки не выполнялось.

Для проверки своего JSON без включения его в репозиторий можно задать переменную окружения `PLUSVPN_TEST_CONFIG_PATH` и запустить `flutter test test/json_subscription_test.dart`. Без этой переменной соответствующий приватный тест пропускается; синтетические примеры проверяются всегда.

## Ограничения

- TCP-пинг проверяет соединение до узла с учётом DNS; он не проверяет пароль или прохождение трафика через туннель.
- Clash YAML, SS plugins, URI KCP/QUIC и устаревший VMess `alterId > 0` не поддерживаются. Основной JSON-формат — Xray, не sing-box.
- Опция отключения проверки TLS `allowInsecure` удалена из используемого ядра; соответствующие ключи отклоняются.
- Плагин использует IPv4 и перехватывает IPv6 для предотвращения обхода туннеля. Полноценная передача IPv6 через VPN не заявляется.
- Плагин 3.5.0 добавляет прямые DNS-маршруты для портов 53/853. Выбор резолвера сам по себе не шифрует DNS.
- Always-on / автозапуск после перезагрузки не реализованы. Ключи хранятся в приватном хранилище приложения, Android Backup отключён.

## GitHub

Ветка `main` подготовлена локально. После создания пустого репозитория на GitHub:

```sh
git add .
git commit -m "Add PlusVPN client"
git remote add origin https://github.com/YOUR_ACCOUNT/YOUR_REPOSITORY.git
git push -u origin main
```

SDK, кэши, APK, локальные пути и ключи подписи исключены из Git. `pubspec.lock` включён. Сторонние компоненты: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
