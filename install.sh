#!/bin/sh
printf "Вроде написано бодро, но могут быть ошибки в зависимоти от конфигурации. Продолжить ? [y/N]: "
read answer
case "$answer" in
    [Yy]|[Yy][Ee][Ss])
        echo "Проверка требований..."
        ;;
    *)
        exit 0
        ;;
esac

if [ -x /usr/bin/apk ] ; then
echo "Начинаем настройку..."
else
echo "Скрипт только для OpenWrt 25.12 и новее"
echo "Читаем readme в репозитории"
echo "Заканчиваю работу скрипта..."
sleep 5
exit 0
fi

echo "Обновление списка пакетов..."
apk update
echo "Установка основных пакетов..."
apk add \
    curl \
    bash \
    lsd \
    luci-i18n-base-ru \
    luci-i18n-attendedsysupgrade-ru \
    luci-i18n-filemanager-ru \
    luci-i18n-firewall-ru \
    luci-i18n-package-manager-ru \
    nano \
    net-tools-netstat \
    && echo "Установка основных пакетов завершена."

printf "Устройство с USB-портом и планируешь использовать накопитель? [y/N]: "
read usb_answer
case "$usb_answer" in
    [Yy]|[Yy][Ee][Ss])
        apk add blockd kmod-fs-vfat kmod-usb-storage-uas kmod-usb2 kmod-usb3 lsblk
        echo "Пакеты для работы с внешними накопителями установлены."
        ;;
    *)
        echo "Пропускаем..."
        ;;
esac

is_usb_installed() {
    apk info -e block-mount >/dev/null 2>&1
}

if is_usb_installed; then
    printf "Установить Transmission ? [y/N]: "
    read answer
    case "$answer" in
        [Yy]|[Yy][Ee][Ss])
            apk add luci-i18n-transmission-ru transmission-web
            echo "Торрент-клиент установлен"
            ;;
        *)
            echo "Пропускаем..."
            ;;
    esac
fi

echo "Настройка luci..."

uci set luci.main.lang='ru'
printf "Тема LuCI: (1) Светлая / (2) Темная [2]: "
read theme_choice
theme_choice="${theme_choice:-2}"
case "$theme_choice" in
    1) uci set luci.main.mediaurlbase='/luci-static/bootstrap-light' ;;
    *) uci set luci.main.mediaurlbase='/luci-static/bootstrap-dark' ;;
esac
uci set luci.main.tablefilters='1'
uci set attendedsysupgrade.client.login_check_for_upgrades='1'

printf "Введи hostname устройства [OpenWRT]: "
read hostname_input
hostname_input="${hostname_input:-OpenWRT}"
uci set system.@system[0].hostname="$hostname_input"

uci set system.@system[0].timezone='MSK-3'
uci set system.@system[0].zonename='Europe/Moscow'
uci set system.@system[0].clock_hourcycle='h23'
uci set system.@system[0].clock_timestyle='1'

printf "Введи SSID для Wi-Fi [OpenWRT]: "
read ssid_input
ssid_input="${ssid_input:-OpenWRT}"

printf "Устройство поддерживает WPA3? Если не уверен - ставь WPA2/WPA3 mixed, обычно работает. (1) WPA3 / (2) WPA2/WPA3 mixed / (3) только WPA2 [2]: "
read enc_choice
enc_choice="${enc_choice:-2}"
case "$enc_choice" in
    1) encryption="sae" ;;
    3) encryption="psk2" ;;
    *) encryption="sae-mixed" ;;
esac

printf "Введи пароль Wi-Fi (минимум 8 символов): "
read wifi_key_input
while [ ${#wifi_key_input} -lt 8 ]; do
    printf "Пароль слишком короткий, минимум 8 символов. Повтори: "
    read wifi_key_input
done

is_radio0_installed() {
    uci -q get wireless.radio0 >/dev/null 2>&1
}

if is_radio0_installed; then
    uci set wireless.default_radio0.mode='ap'
    uci set wireless.default_radio0.ssid="$ssid_input"
    uci set wireless.default_radio0.encryption="$encryption"
    uci set wireless.default_radio0.key="$wifi_key_input"
    uci delete wireless.default_radio0.disabled
fi

is_radio1_installed() {
    uci -q get wireless.radio1 >/dev/null 2>&1
}

if is_radio1_installed; then
    uci set wireless.default_radio1.mode='ap'
    uci set wireless.default_radio1.ssid="$ssid_input"
    uci set wireless.default_radio1.encryption="$encryption"
    uci set wireless.default_radio1.key="$wifi_key_input"
    uci delete wireless.default_radio1.disabled
fi

if apk info -e transmission-daemon >/dev/null 2>&1; then
uci set transmission.@transmission[0].enabled='1'
fi

uci commit

echo "Настройка luci завершена."

echo "Поднимаем Wifi..."
wifi up

printf "Установить пароль root ? [y/N]: "
read answer
case "$answer" in
    [Yy]|[Yy][Ee][Ss])
        echo "Установка пароля root..."
        until passwd; do
            echo "Не удалось установить пароль, попробуй ещё раз."
        done
        ;;
    *)
        echo "Пароль root не будет установлен."
        ;;
esac

is_agh_installed() {
    [ -x /opt/AdGuardHome/AdGuardHome ]
}

is_forkop_installed() {
    apk info -e forkop >/dev/null 2>&1
}

printf "Установить AdGuardHome ? [y/N]: "
read answer
case "$answer" in
    [Yy]|[Yy][Ee][Ss])
        curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v
        echo "Установка AdGuardHome завершена."
        ;;
    *)
        echo "AdGuardHome не будет установлен."
        ;;
esac

wait_for_agh_config() {
    echo "========================================="
    echo " Настрой AdGuard Home перед продолжением"
    echo "========================================="
    echo "Открой в браузере: http://192.168.1.1:3000"
    echo "Для корректной работы скрипта необходимо указать порт вэб-интерфейса 8000 и порт DNS 5353."
    echo ""

    while true; do
        printf "AdGuard Home настроен ? (y/n): "
        read answer
        case "$answer" in
            y|Y) break ;;
            n|N) echo "Ок, жду. Настрой и введи y." ;;
            *) echo "Введи y или n" ;;
        esac
    done
}

if is_agh_installed; then
    wait_for_agh_config
fi
echo "-> Продолжаем..."

printf "Установить Forkop ? [y/N]: "
read answer
case "$answer" in
    [Yy]|[Yy][Ee][Ss])
        sh <(wget -O - https://raw.githubusercontent.com/ushan0v/forkop/main/install.sh)
        echo "Установка Forkop завершена."
        ;;
    *)
        echo "Forkop не будет установлен."
        ;;
esac

if is_forkop_installed; then
    printf "Добавить секцию Vless в Forkop ? [y/N]: "
    read answer
    case "$answer" in
        [Yy]|[Yy][Ee][Ss])
            printf "Введи URL подписки: "
            read vless_url

            uci set forkop.Vless='section'
            uci set forkop.Vless.enabled='1'
            uci set forkop.Vless.action='connection'
            uci set forkop.Vless.outbound_detour_enabled='0'
            uci set forkop.Vless.sort_by_latency='0'
            uci set forkop.Vless.mixed_proxy_enabled='0'
            uci set forkop.Vless.resolve_real_ip_for_routing='0'
            uci set forkop.Vless.community_lists='russia_inside'
            uci set forkop.Vless.dashboard_filter_mode='disabled'

            sub_section=$(uci add forkop subscription_url)
            uci set forkop.${sub_section}.section='Vless'
            uci set forkop.${sub_section}.url="$vless_url"
            uci set forkop.${sub_section}.subscription_update_enabled='1'
            uci set forkop.${sub_section}.subscription_update_interval='1h'
            uci set forkop.${sub_section}.download_via_proxy_enabled='0'
            uci set forkop.${sub_section}.auto_user_agent='1'
            uci set forkop.${sub_section}.auto_hwid='1'
            uci set forkop.${sub_section}.show_dashboard_metadata='1'
            uci set forkop.${sub_section}.prefix_nodes='0'
            uci set forkop.${sub_section}.include_urltest_groups='1'
            uci set forkop.${sub_section}.hide_urltest_group_outbounds='1'
            uci set forkop.${sub_section}.hide_detour_outbounds='1'

            uci commit forkop
            echo "Секция Vless добавлена в Forkop."
            ;;
        *)
            echo "Секция Vless не будет добавлена."
            ;;
    esac
fi

if is_forkop_installed && is_agh_installed; then
    printf "Интегрировать AdGuardHome в Forkop ? [y/N]: "
    read answer
    case "$answer" in
        [Yy]|[Yy][Ee][Ss])        
            uci delete forkop.settings.dns_server
            uci add_list forkop.settings.dns_server='192.168.1.1:5353'
            uci commit forkop
            echo "Готово: Forkop теперь будет использовать AdGuardHome в качестве основного DNS."
            echo "Интеграция AdGuardHome в Forkop завершена."
            ;;
        *)
            echo "Интеграция AdGuardHome в Forkop не будет выполнена."
            ;;
    esac
fi

if is_forkop_installed; then
    printf "Настроить bootstrap DNS для Forkop (8.8.8.8, 8.8.4.4) ? [y/N]: "
    read answer
    case "$answer" in
        [Yy]|[Yy][Ee][Ss])
            uci delete forkop.settings.bootstrap_dns_server 2>/dev/null
            uci add_list forkop.settings.bootstrap_dns_server='8.8.8.8'
            uci add_list forkop.settings.bootstrap_dns_server='8.8.4.4'
            uci commit forkop
            echo "Bootstrap DNS для Forkop настроен: 8.8.8.8, 8.8.4.4"
            ;;
        *)
            echo "Bootstrap DNS не изменён."
            ;;
    esac
fi

if is_forkop_installed; then
    printf "Установить Zapret как компонент Forkop ? [y/N]: "
    read answer
    case "$answer" in
        [Yy]|[Yy][Ee][Ss])
            forkop component_action zapret install
            echo "Zapret установлен."
            ;;
        *)
            echo "Установка Zapret пропущена."
            ;;
    esac
fi

if is_forkop_installed && apk info -e zapret >/dev/null 2>&1; then
    printf "Добавить секцию Zapret в Forkop ? [y/N]: "
    read answer
    case "$answer" in
        [Yy]|[Yy][Ee][Ss])
            uci set forkop.Zapret=section
            uci set forkop.Zapret.enabled='1'
            uci set forkop.Zapret.action='zapret'
            uci set forkop.Zapret.mixed_proxy_enabled='0'
            uci add_list forkop.Zapret.community_lists='youtube'
            echo "Секция Zapret добавлена в Forkop"
            ;;
        *)
            echo "Секция Zapret не будет добавлена."
            ;;
    esac
fi

if is_forkop_installed; then
    printf "Установить Zapret2 как компонент Forkop ? [y/N]: "
    read answer
    case "$answer" in
        [Yy]|[Yy][Ee][Ss])
            forkop component_action zapret2 install
            echo "Zapret установлен."
            ;;
        *)
            echo "Установка Zapret2 пропущена."
            ;;
    esac
fi

if is_forkop_installed; then
    printf "Установить ByeDPI как компонент Forkop ? [y/N]: "
    read answer
    case "$answer" in
        [Yy]|[Yy][Ee][Ss])
            forkop component_action byedpi install
            echo "Zapret установлен."
            ;;
        *)
            echo "Установка ByeDPI пропущена."
            ;;
    esac
fi

echo "Запуск служб..."
if is_agh_installed; then
service AdGuardHome enable
fi

if is_forkop_installed; then
service forkop enable
fi

printf "Готово, рекомендую перезагрузить устройство. Продолжить ? [y/N]: "
read answer
case "$answer" in
    [Yy]|[Yy][Ee][Ss])
        echo "Перезагрузка..."
        reboot
        ;;
    *) 
        echo "Настройка завершена без перезагрузки."
        if is_agh_installed; then
            service AdGuardHome start &
        fi
        if is_forkop_installed; then
            service forkop start &
        fi
        echo "Службы запущены."
        exit 0
        ;;
esac
