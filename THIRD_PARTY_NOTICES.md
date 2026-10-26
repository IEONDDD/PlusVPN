# Сторонние компоненты

VPN-движок поставляется зависимостью `flutter_v2ray_client` версии **3.5.0** из pub.dev, а не скачивается приложением во время запуска.

- [flutter_v2ray_client](https://github.com/amir-zr/flutter_v2ray_client), MIT. В Android-пакет включено ядро Xray 26.9.9.
- [Xray-core](https://github.com/XTLS/Xray-core), MPL-2.0. Исходный код и уведомления о лицензии ядра доступны в исходном проекте и дистрибутиве зависимости.
- [Flutter](https://github.com/flutter/flutter), BSD-3-Clause.

Остальные Dart-зависимости перечислены в `pubspec.yaml`, точные разрешённые версии и контрольные суммы — в `pubspec.lock`. Их уведомления доступны через стандартную страницу лицензий Flutter (`showLicensePage`). Перед распространением собственной сборки сохраните уведомления о лицензиях используемых компонентов.
