## config.fish

# 檢查檔案是否存在並匯入必要的環境變數
if status is-interactive
    set -l shell_rc
    if test -f "$HOME/.bashrc"
        set shell_rc "$HOME/.bashrc"
    else if test -f "$HOME/.zshrc"
        set shell_rc "$HOME/.zshrc"
    end

    if set -q shell_rc
        # 只匯入 PATH 和必要的環境變數
        for line in (bash -c "source $shell_rc; env | grep -E '^(PATH|HOME|USER|CARGO_HOME|RUSTUP_HOME|NVM_DIR|GOPATH|GOROOT)='")
            set -l key_value (string split -m 1 '=' $line)
            set -gx $key_value[1] $key_value[2]
        end
    end
end

#設定使用者 root 顯示樣式
function fish_prompt
    # 前置符號 ୨୧ 粉色
    set_color magenta
    echo -n "୨୧ "

    # 使用者@主機 綠色
    set_color yellow
    echo -n (whoami)"@"(hostname)

    # 中間符號 ୨୧ 粉色
    set_color magenta
    echo -n " ୨୧ "

    # 當前工作目錄 綠色
    set_color yellow
    if test (pwd) = $HOME
        # 在 home 目錄只顯示 ~
        echo -n "~  "
    else
        # 其他目錄顯示完整路徑 + ~
        echo -n (prompt_pwd)" ~  "
    end

    # 恢復預設顏色
    set_color normal

    # 換行
    echo ""
end

# Rust/Cargo 路徑
set -gx PATH /home/shuhi/.cargo/bin $PATH

#Ctrl + e  exit
function fish_user_key_bindings
    bind \ce 'commandline -r "exit"; commandline -f execute'
end
