# OpenWrt-post-install

Запуск и настройка
```sh
wget -qO- https://raw.githubusercontent.com/V1meR-Git/OpenWrt-post-install/refs/heads/main/run.sh | sh
```

Скрипт для упрощения настройки роутера
Запуск через ssh или ttyd

### Что делает скрипт:
* Устанавливает основные пакеты
* Настраивает luci
* Настраивает и поднимает Wifi
* Устанавливает пакеты для USB и внешних накопителей
* Устанавливает торрент-клиент
* Устанавливает Forkop и AdGuardHome
* Прописывает использование AGH в качестве upstream DNS
* Добавляет первые секции для Forkop
