#!/bin/sh
echo "Скачивание основного скрипта..."
wget -qO /tmp/install.sh "https://raw.githubusercontent.com/V1meR-Git/OpenWrt-post-install/refs/heads/main/install.sh"

if [ $? -ne 0 ]; then
    echo "Ошибка: не удалось скачать install.sh. Проверьте подключение к интернету."
    exit 1
fi

chmod +x /tmp/install.sh

echo "Запуск установки..."
/tmp/install.sh < /dev/tty

rm -f /tmp/install.sh
