set -e

clear

echo
echo "========================================================="
echo "              Flux Installer"
echo "========================================================="
echo

echo "[*] Detecting Linux distribution..."

if command -v apt >/dev/null 2>&1; then
    PKG_MANAGER="apt"

elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"

elif command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"

elif command -v zypper >/dev/null 2>&1; then
    PKG_MANAGER="zypper"

elif command -v emerge >/dev/null 2>&1; then
    PKG_MANAGER="portage"

elif command -v apk >/dev/null 2>&1; then
    PKG_MANAGER="apk"

elif command -v xbps-install >/dev/null 2>&1; then
    PKG_MANAGER="xbps"

else
    echo "[!] Unsupported Linux distribution."
    exit 1
fi

echo "[✓] Detected package manager: $PKG_MANAGER"
echo

echo "[*] Installing system dependencies..."
echo

case $PKG_MANAGER in

    apt)
        sudo apt update

        sudo apt install -y \
            python3 \
            python3-pip \
            python3-venv \
            llvm \
            clang \
            git \
            wget \
            curl \
            gpg
        ;;

    dnf)
        sudo dnf install -y \
            python3 \
            python3-pip \
            python3-virtualenv \
            llvm \
            clang \
            git \
            wget \
            curl \
            gnupg2
        ;;

    pacman)
        sudo pacman -Sy --noconfirm \
            python \
            python-pip \
            python-virtualenv \
            llvm \
            clang \
            git \
            wget \
            curl \
            gnupg
        ;;

    zypper)
        sudo zypper install -y \
            python3 \
            python3-pip \
            python3-virtualenv \
            llvm \
            clang \
            git \
            wget \
            curl \
            gpg2
        ;;

    portage)
        sudo emerge \
            dev-lang/python \
            llvm-core/llvm \
            sys-devel/clang \
            dev-vcs/git \
            net-misc/wget \
            net-misc/curl
        ;;

    apk)
        sudo apk add \
            python3 \
            py3-pip \
            py3-virtualenv \
            llvm \
            clang \
            git \
            wget \
            curl \
            gnupg
        ;;

    xbps)
        sudo xbps-install -Sy \
            python3 \
            python3-pip \
            python3-virtualenv \
            llvm \
            clang \
            git \
            wget \
            curl \
            gnupg
        ;;

esac

echo
echo "[✓] System dependencies installed."
echo


echo "[*] Installing Flux..."
echo

if [ -d "$HOME/FluxLang" ]; then
    echo "[*] Existing FluxLang installation detected."
    echo "[*] Pulling latest changes..."

    cd "$HOME/FluxLang"
    git pull

else
    cd "$HOME"

    git clone https://github.com/kvthweatt/FluxLang.git

    cd FluxLang
fi

echo
echo "[✓] Flux installed."
echo


echo "[*] Creating Flux Python virtual environment..."
echo

FLUX_PATH="$HOME/FluxLang"
FLUX_ENV="$FLUX_PATH/.flux_env"

python3 -m venv "$FLUX_ENV"

echo
echo "[✓] Virtual environment created."
echo

echo "[*] Activating Flux environment..."
echo

source "$FLUX_ENV/bin/activate"

echo "[✓] Flux environment activated."
echo

echo "[*] Upgrading pip..."
echo

pip install --upgrade pip setuptools wheel

echo
echo "[*] Installing Python dependencies inside Flux environment..."
echo

pip install \
    llvmlite==0.41.0 \
    dataclasses

echo
echo "[✓] Python dependencies installed."
echo


echo "[*] Configuring environment..."
echo

# Detect shell config
SHELL_CONFIG=""

if [ -n "$BASH_VERSION" ]; then
    SHELL_CONFIG="$HOME/.bashrc"

elif [ -n "$ZSH_VERSION" ]; then
    SHELL_CONFIG="$HOME/.zshrc"

else
    SHELL_CONFIG="$HOME/.profile"
fi

# Add environment variable
if ! grep -q "FLUXC_SRCDIR" "$SHELL_CONFIG"; then

    echo "" >> "$SHELL_CONFIG"
    echo "# FluxLang" >> "$SHELL_CONFIG"
    echo "export FLUXC_SRCDIR=\"$FLUX_PATH\"" >> "$SHELL_CONFIG"

fi

# Add Flux environment variable
if ! grep -q "FLUX_ENV" "$SHELL_CONFIG"; then

    echo "export FLUX_ENV=\"$FLUX_ENV\"" >> "$SHELL_CONFIG"

fi

# Add alias
if ! grep -q "alias fluxc=" "$SHELL_CONFIG"; then

    echo "alias fluxc='source $FLUX_ENV/bin/activate && python3 $FLUX_PATH/fxc.py'" >> "$SHELL_CONFIG"

fi

# Add helper alias for entering env
if ! grep -q "alias fluxenv=" "$SHELL_CONFIG"; then

    echo "alias fluxenv='source $FLUX_ENV/bin/activate'" >> "$SHELL_CONFIG"

fi

export FLUXC_SRCDIR="$FLUX_PATH"
export FLUX_ENV="$FLUX_ENV"

echo "[✓] Environment configured."
echo


echo "[*] Running verification checks..."
echo

echo "---------------------------------------------------------"
echo "Python:"
python3 --version

echo
echo "Virtual Environment Python:"
"$FLUX_ENV/bin/python3" --version

echo
echo "Clang:"
clang --version | head -n 1

echo
echo "LLVM:"
llvm-config --version

echo
echo "Git:"
git --version

echo
echo "llvmlite:"
"$FLUX_ENV/bin/python3" -c "import llvmlite; print('llvmlite OK')"

echo "---------------------------------------------------------"
echo


echo "[*] Testing Flux compilation..."
echo

cd "$FLUX_PATH"

"$FLUX_ENV/bin/python3" fxc.py tests/test.fx --log-level 3 || {
    echo
    echo "[!] Flux test compilation failed."
    exit 1
}

echo
echo "[✓] Flux test compilation successful."
echo


read -p "Install Sublime Text? (y/N): " INSTALL_SUBLIME

if [[ "$INSTALL_SUBLIME" =~ ^[Yy]$ ]]; then

    echo
    echo "[*] Installing Sublime Text..."
    echo

    case $PKG_MANAGER in

        apt)
            wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | \
                gpg --dearmor | \
                sudo tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg >/dev/null

            echo "deb https://download.sublimetext.com/ apt/stable/" | \
                sudo tee /etc/apt/sources.list.d/sublime-text.list

            sudo apt update
            sudo apt install -y sublime-text
            ;;

        dnf)
            sudo rpm -v --import \
                https://download.sublimetext.com/sublimehq-rpm-pub.gpg

            sudo dnf config-manager --add-repo \
                https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo

            sudo dnf install -y sublime-text
            ;;

        pacman)
            echo
            echo "[!] Sublime Text installation on Arch requires an AUR helper."
            echo "[!] Install manually with:"
            echo "    yay -S sublime-text-4"
            ;;

        *)
            echo
            echo "[!] Automatic Sublime installation not supported for this distro."
            ;;

    esac

    echo
    echo "[✓] Sublime Text installation completed."
    echo

fi


echo "========================================================="
echo "           Flux Installed Successfully"
echo "========================================================="
echo

echo "Flux Directory:"
echo "  $FLUX_PATH"
echo

echo "Flux Python Environment:"
echo "  $FLUX_ENV"
echo

echo "Flux Python Binary:"
echo "  $FLUX_ENV/bin/python3"
echo

echo "Flux Pip Binary:"
echo "  $FLUX_ENV/bin/pip"
echo

echo "Environment File:"
echo "  $SHELL_CONFIG"
echo

echo "Next Steps:"
echo

echo "  1. Reload your shell:"
echo "     source $SHELL_CONFIG"
echo

echo "  2. Enter Flux environment:"
echo "     fluxenv"
echo

echo "  3. Install extra Python packages:"
echo "     pip install <package>"
echo

echo "  4. Compile a Flux program:"
echo "     fluxc examples/hello.fx"
echo

echo "  5. Run the executable:"
echo "     ./hello"
echo

echo "Happy Flux development!"
echo
