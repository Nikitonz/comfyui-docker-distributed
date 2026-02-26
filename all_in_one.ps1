Set-PSDebug -Trace 1
# ==========================================================
# Env
# ==========================================================
$DISTRO = "Ubuntu-24.04"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== Source directory on Windows. Using this ==="
Write-Host $SCRIPT_DIR
$ErrorActionPreference = "Stop"

# ----------------------------------------------------------
# Resolve source dir on Windows and convert to WSL path
# ----------------------------------------------------------
$WIN_SRC_DIR = [System.IO.Path]::GetFullPath($SCRIPT_DIR)

if ($WIN_SRC_DIR -match '^[A-Za-z]:\\') {
    $drive = $WIN_SRC_DIR.Substring(0,1).ToLower()
    $rest  = $WIN_SRC_DIR.Substring(2).TrimStart('\') -replace '\\','/'
    $WSL_SRC_DIR = "/mnt/$drive/$rest"
} else {
    throw "WIN_SRC_DIR path '$WIN_SRC_DIR'"
}

# ==========================================================
#  SETUP WSL2 + DISTRO + NVIDIA GPU SUPPORT
#  Script must be run as Administrator
# ==========================================================

Write-Host "=== Enabling Windows features: WSL + VirtualMachinePlatform ==="
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

Write-Host "=== Installing WSL if missing ==="
$distroExists = (wsl -l -q 2>$null | ForEach-Object { $_.Trim() }) -contains $DISTRO
if (-not $distroExists) {
    wsl --install -d $DISTRO
    Write-Host "WSL distro $DISTRO installed. Reboot may be required. Re-run this script after reboot."
    exit 0
}

wsl --update

Write-Host "=== Running WSL configuration and setup for $DISTRO ==="

# ----------------------------------------------------------
# All Linux-side commands in a single WSL call
# ----------------------------------------------------------
$wslScript = @'
set -euo pipefail
echo "=== Running inside WSL: $DISTRO ==="

WSLUSER=$(awk -F: '$3==1000 {print $1; exit}' /etc/passwd)
WSL_TARGET_DIR="/home/$WSLUSER/AI"

echo "Using WSL source dir: $WSL_SRC_DIR"
echo "Project target dir:   $WSL_TARGET_DIR"

mkdir -p "$WSL_TARGET_DIR"
tar -C "$WSL_SRC_DIR" --exclude=all_in_one.ps1 --exclude=.git --exclude=.vscode -cf - . | (cd "$WSL_TARGET_DIR" && tar -xf -)

apt-get update
apt-get install -y \
  build-essential \
  ca-certificates \
  cifs-utils \
  curl \
  git \
  gnupg \
  lsb-release \
  pkg-config \
  software-properties-common
  
add-apt-repository -y multiverse

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg

ARCH=$(dpkg --print-architecture)
CODENAME=$(lsb_release -cs)
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" > /etc/apt/sources.list.d/docker.list

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  -o /etc/apt/keyrings/nvidia-container-toolkit.asc
echo "deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit.asc] https://nvidia.github.io/libnvidia-container/stable/deb/amd64 /" > /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update

apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

apt-get install nvidia-container-toolkit
echo "1==================================================================================="
nvidia-ctk runtime configure --runtime=docker || true
echo "2==================================================================================="
usermod -aG docker "$WSLUSER" || true
echo "3==================================================================================="
if [ "$(ps -p 1 -o comm=)" = "systemd" ]; then
  systemctl restart docker || true
fi

# test gpu in docker
echo "==================================================================================="
if command -v docker >/dev/null 2>&1; then
  if docker run --rm --gpus all nvidia/cuda:12.4.1-runtime-ubuntu22.04 nvidia-smi; then
    echo "GPU in Docker works correctly!"
    docker rmi nvidia/cuda:12.4.1-runtime-ubuntu22.04 || true
  else
    echo "ERROR: Docker cannot access NVIDIA GPU." >&2
	exit 0;
  fi
fi

if [ -x "$WSL_TARGET_DIR/build_image.sh" ] && [ -x "$WSL_TARGET_DIR/run_comfy_headless.sh" ]; then
  cd "$WSL_TARGET_DIR"
  ./build_image.sh
  ./run_comfy_headless.sh
else
  echo "WARNING: build_image.sh or run_comfy_headless.sh not found or not executable in $WSL_TARGET_DIR" >&2
fi
'@

$wslScript = $wslScript -replace "`r",""

Write-Host "=== DEBUG: \$wslScript that will be sent to WSL ==="
Write-Host $wslScript
Write-Host "=== END DEBUG ==="

$wslScriptBytes  = [System.Text.Encoding]::UTF8.GetBytes($wslScript)
$wslScriptBase64 = [Convert]::ToBase64String($wslScriptBytes)

$wslCommand = "export WSL_SRC_DIR='$WSL_SRC_DIR' DISTRO='$DISTRO'; echo '$wslScriptBase64' | base64 -d | bash"


wsl -d $DISTRO --user root -- bash -lc "$wslCommand"

Write-Host "=== Setup completed ==="
