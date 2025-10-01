#!/usr/bin/env bash
set -e

# 檢查版本
check_OS_version() {
    if [ -f /etc/fedora-release ]; then
        FEDORA_VER=$(rpm -E %fedora)
        echo "Fedora version: $FEDORA_VER"

        if [ "$FEDORA_VER" -ge 40 ]; then
            echo "୨୧ Fedora $FEDORA_VER is >= 40  ୨୧"
        else
            echo "Error Fedora version is lower than 40, exiting..."
            exit 1
        fi
    else
        echo "Error This system is not Fedora."
        exit 1
    fi
}

# 更新系統
system_update() {
    echo "Updating system..."
    sudo dnf upgrade -y
}

install_fonts(){
    local copr_fonts=("elxreno/jetbrains-mono-fonts")
    local install_fonts=("jetbrains-mono-fonts")  # 統一拼寫為 fonts

    echo " 檢查套件是否已安裝..."

    for cf in "${copr_fonts[@]}"; do
        if dnf repolist enabled | grep -q "$cf"; then  # 修正邏輯：找到才已安裝；用 enabled 更精準
            echo "OK!  $cf 已安裝"
        else
            echo "$cf 未安裝，快去安裝!!!"
            echo "開啟copr $cf  !!"
            sudo dnf copr enable "$cf" -y
            for ins_font in "${install_fonts[@]}"; do
                sudo dnf install "$ins_font" -y
            done
        fi
    done
}

install_packages() {
    # 要使用的套件
    local packages=("fish" "helix" "kitty" "git" "curl")
    local to_install=()

    echo " 檢查套件是否已安裝..."

    for pkg in "${packages[@]}"; do
        if rpm -q "$pkg" >/dev/null 2>&1; then  # 改用 rpm -q 更精準檢查安裝
            echo "୨୧  OK!  $pkg 已安裝  ୨୧"
        else
            echo " ૮₍ꐦ-᷅ ⤙ -᷄  ₎  $pkg 未安裝，快去安!!!"
            to_install+=("$pkg")
        fi
    done

    # 安裝!!!
    echo "⸜♡⸝ ...安裝中... ⸜♡⸝"

    if [ ${#to_install[@]} -gt 0 ]; then
        sudo dnf install -y "${to_install[@]}"
    else
        echo " ⪩⪨ 都完成安裝了 ⪩⪨"
    fi
}

# 安裝VPN
install_zerotier() {
    echo "◍  安裝 Zerotier... ◍"
    curl -s https://install.zerotier.com -o /tmp/install_zerotier.sh  # 改下載後執行，提升安全
    sudo bash /tmp/install_zerotier.sh
    rm /tmp/install_zerotier.sh  # 清理

    read -p "請輸入 Zerotier 網域 ID: " ZT_NET
    if [ -n "$ZT_NET" ]; then
        sudo zerotier-cli join "$ZT_NET"
        echo "၄၃ 已嘗試加入 Zerotier 網域: $ZT_NET"
    else
        echo "૮₍ꐦ -᷅ ⤙ -᷄ ₎ა   沒有輸入網域 ID，跳過 Zerotier 加入"
    fi
}

install_xrdp() {
    local connection_packages=("xrdp" "tigervnc-server")  # 修正拼寫
    local install_connection=()  # 宣告但未用，可移除；保留以備擴充

    echo " 檢查套件是否已安裝..."

    for cpkg in "${connection_packages[@]}"; do
        if rpm -q "$cpkg" >/dev/null 2>&1; then  # 改用 rpm -q
            echo "୨୧  OK!  $cpkg 已安裝  ୨୧"
            continue  # 已安裝則跳過
        else
            echo " ૮₍ꐦ-᷅ ⤙ -᷄  ₎  $cpkg 未安裝，快去安!!!"

            echo "是否要安裝 $cpkg？ (y/n)"
            read -p "" choice
            # 轉小寫以處理大小寫不敏感
            choice=${choice,,}

            if [[ "$choice" == "y" || "$choice" == "yes" ]]; then
                echo "開始安裝 $cpkg..."

                # 更新套件庫（可選，但推薦）
                sudo dnf update -y

                # 安裝 xrdp 及相關套件
                sudo dnf install -y "$cpkg"

                if [ $? -ne 0 ]; then  # 加錯誤檢查
                    echo "安裝 $cpkg 失敗，請檢查日誌或權限。"
                    continue
                fi

                if [ "$cpkg" == "xrdp" ]; then
                    sudo systemctl enable --now xrdp
                    # 開放防火牆端口（若使用 firewalld）
                    sudo firewall-cmd --permanent --add-port=3389/tcp
                    sudo firewall-cmd --reload
                    echo "xrdp 安裝完成！可使用 RDP 客戶端連接 IP:3389。"
                else
                    echo "請輸入要設定的使用者名稱列表（以逗號分隔，例如: shuhi,fancie）："
                    read -p "" user_input

                    # 分割輸入為陣列（移除空格）
                    IFS=',' read -r -a users <<< "${user_input// /}"

                    # 檢查是否有輸入使用者
                    if [ ${#users[@]} -eq 0 ]; then
                        echo "未輸入任何使用者名稱，取消安裝。"
                        continue
                    fi

                    # 動態分配顯示器，從 1 開始
                    display=1

                    for user in "${users[@]}"; do
                        # 設定 VNC 密碼（若已設會提示覆蓋）
                        su - $user -c "vncpasswd"

                        # 建立服務設定檔
                        sudo cp /usr/lib/systemd/system/vncserver@.service /etc/systemd/system/vncserver@:${display}.service
                        sudo sed -i "s/<USER>/$user/g" /etc/systemd/system/vncserver@:${display}.service

                        # 設定解析度（可自訂）
                        sudo sed -i '/ExecStart=/ s/$/ -geometry 1920x1080 -depth 24/' /etc/systemd/system/vncserver@:${display}.service

                        # 重載並啟用服務
                        sudo systemctl daemon-reload
                        sudo systemctl enable --now vncserver@:${display}.service

                        # 計算端口（5900 + display）
                        port=$((5900 + display))

                        # 開放防火牆但限制來源 IP (使用 rich rule)
                        sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.192.0/24" port port="$port" protocol="tcp" accept'

                        # 顯示資訊
                        echo "- $user: 連接端口 $port，使用密碼登入。"

                        # 遞增顯示器
                        ((display++))
                    done

                    # 重載防火牆
                    sudo firewall-cmd --reload

                    echo "VNC 伺服器安裝完成！僅允許 192.168.192.0/24 子網存取。"
                fi
            else
                echo "取消安裝 $cpkg"
                continue  # 改 exit 為 continue，避免中斷整個腳本
            fi
        fi
    done
}

# 要使用的資料
clone_my_github() {
    echo "Cloning repo..."
    if [ ! -d ~/Fedora_setup ]; then
        git clone https://github.com/Shuhimoon/Fedora_setup ~/Fedora_setup
    else
        echo "Repo already exists, pulling latest changes..."
        cd ~/Fedora_setup && git pull
    fi
}

setup_config_dirs() {
    echo "⚙ Setting up config directories..."

    if [ ! -d ~/.config/helix ]; then
        mkdir -p ~/.config/helix
        echo "♅ Created ~/.config/helix"
    else
        echo "♅  ~/.config/helix   OK! , next...."
    fi

    if [ ! -d ~/.config/fish ]; then
        mkdir -p ~/.config/fish
        echo "♆ Created ~/.config/fish"
    else
        echo "♆ ~/.config/fish OK!!! "
    fi
}

copy_configs() {
    echo "Copying configuration files..."

    if [ -d ~/Fedora_setup/helix ]; then
        cp -r ~/Fedora_setup/helix/* ~/.config/helix/
        echo "Helix config copy end ⸜♡⸝"
    fi

    if [ -d ~/Fedora_setup/fish ]; then
        cp -r ~/Fedora_setup/fish/* ~/.config/fish/
        echo "Fish config copy end ⸜♡⸝"
    fi
}

main() {
    check_OS_version
    system_update
    install_fonts  # 新增呼叫 install_fonts（原腳本缺少）
    install_packages
    install_zerotier
    install_xrdp
    clone_my_github
    setup_config_dirs
    copy_configs

    echo "୨୧ ---- END ---- ୨୧"
}

main
