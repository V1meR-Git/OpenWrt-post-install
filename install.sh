#!/bin/sh
printf "Тестовый скрипт для моего удобства. Не рекомендуется использовать на других устройствах. Продолжить ? [y/N]: "
read answer
case "$answer" in
    [Yy]|[Yy][Ee][Ss])
        echo "Продолжаем настройку..."
        ;;
    *)
        exit 0
        ;;
esac

echo "Обновление списка пакетов..."
apk update
echo "Установка основных пакетов..."
apk add \
    curl \
    bash \
    block-mount \
    blockd \
    btop \
    kmod-fs-ext4 \
    kmod-fs-vfat \
    kmod-usb-storage \
    kmod-usb-storage-uas \
    kmod-usb3 \
    lsblk \
    lsd \
    luci-i18n-base-ru \
    luci-i18n-attendedsysupgrade-ru \
    luci-i18n-filemanager-ru \
    luci-i18n-firewall-ru \
    luci-i18n-package-manager-ru \
    luci-i18n-transmission-ru \
    nano \
    net-tools-netstat \
    transmission-daemon \
    transmission-web \
    && echo "Установка основных пакетов завершена."

echo "Настройка luci..."
uci set luci.main.lang='ru'
uci set luci.main.mediaurlbase='/luci-static/bootstrap-dark'
uci set luci.main.tablefilters='1'
uci set attendedsysupgrade.client.login_check_for_upgrades='1'
uci set system.@system[0].hostname='OpenWRT'
uci set system.@system[0].timezone='MSK-3'
uci set system.@system[0].zonename='Europe/Moscow'
uci set system.@system[0].clock_hourcycle='h23'
uci set system.@system[0].clock_timestyle='1'

uci set wireless.default_radio0.mode='ap'
uci set wireless.default_radio0.ssid='OpenWRT'
uci set wireless.default_radio0.encryption='sae-mixed'
uci set wireless.default_radio0.key='00000039A8'
uci set wireless.radio0.channel='11'
uci delete wireless.default_radio0.disabled

uci set wireless.default_radio1.mode='ap'
uci set wireless.default_radio1.ssid='OpenWRT'
uci set wireless.default_radio1.encryption='sae-mixed'
uci set wireless.default_radio1.key='00000039A8'
uci delete wireless.default_radio1.disabled

uci set transmission.@transmission[0].enabled='1'

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

if is_forkop_installed; then
    printf "Добавить профиль Vless в Forkop ? [y/N]: "
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
            echo "Профиль Vless добавлен в Forkop."
            ;;
        *)
            echo "Профиль Vless не будет добавлен."
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
            service AdGuardHome start
        fi
        if is_forkop_installed; then
            service forkop start
        fi
        exit 0
        ;;
esac
