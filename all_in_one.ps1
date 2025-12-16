Set-PSDebug -Trace 1
# ==========================================================
# Env
# ==========================================================
$DISTRO = "Ubuntu-24.04"
$WSL_TARGET_DIR = "/home/$((wsl -d $DISTRO -- bash -lc 'echo $USER').Trim())/AI"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== Source directory on Windows. Using this ==="
Write-Host $SCRIPT_DIR
$ErrorActionPreference = "Stop"

# ==========================================================
#  SETUP WSL2 + DISTRO + NVIDIA GPU SUPPORT
#  Script must be run as Administrator
# ==========================================================

Write-Host "=== Enabling Windows features: WSL + VirtualMachinePlatform ==="
#dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
#dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

Write-Host "=== Installing WSL if missing ==="
$distroExists = (wsl -l -q 2>$null | ForEach-Object { $_.Trim() }) -contains $DISTRO
if (-not $distroExists) {
    wsl --install -d $DISTRO
}
wsl --update
wsl -d $DISTRO --user root -- bash -lc 'printf "[boot]\nsystemd=true\n" | tr -d "\r" > /etc/wsl.conf'
wsl --shutdown

Write-Host "=== Running WSL initialization for $DISTRO ==="
wsl -d $DISTRO -- echo "Your selected distro is ready-to-go"

# ----------------------------------------------------------
# Copy utilities from repo  on host to wsl mashine
# ----------------------------------------------------------
$WIN_SRC_DIR = [System.IO.Path]::GetFullPath($SCRIPT_DIR)
$WSL_SRC_DIR = (wsl -d $DISTRO -- bash -lc "wslpath -a '$WIN_SRC_DIR'").Trim()
wsl -d $DISTRO -- bash -c "mkdir -p $WSL_TARGET_DIR"
wsl -d $DISTRO -- bash -lc "mkdir -p '$WSL_TARGET_DIR'; tar -C '$WSL_SRC_DIR' --exclude=all_in_one.ps1 --exclude=.git --exclude=.vscode -cf - . | (cd '$WSL_TARGET_DIR'; tar -xf -)"
wsl -d $DISTRO -- bash -c "cd '$WSL_TARGET_DIR' && chmod +x ./*.sh"
# ----------------------------------------------------------
# Ubuntu commands executed via WSL
# ----------------------------------------------------------

Write-Host "=== Updating Ubuntu system packages ==="
wsl -d $DISTRO --user root -- apt update
wsl -d $DISTRO --user root -- apt upgrade -y

Write-Host "=== Installing essential Ubuntu packages ==="
wsl -d $DISTRO --user root -- apt install -y `
  build-essential `
  ca-certificates `
  curl `
  git `
  gnupg `
  lsb-release `
  pkg-config `
  software-properties-common

# is NVIDIA GPU present in WSL?
Write-Host "=== Checking NVIDIA GPU availability inside WSL ==="
$hasNvidiaSmi = (wsl -d $DISTRO -- bash -lc 'command -v nvidia-smi >/dev/null 2>&1; echo $?' 2>$null).Trim() -eq '0'
if ($hasNvidiaSmi) {
    wsl -d $DISTRO -- nvidia-smi
    Write-Host "NVIDIA GPU detected in WSL."
} else {
    Write-Host "ERROR: nvidia-smi not found in WSL. Install/update NVIDIA driver on Windows (WSL support)."
}


# Write-Host "=== Installing CUDA Toolkit (optional) ==="
# wsl -d $DISTRO -- sudo apt install -y nvidia-cuda-toolkit #uncomment line if needed

# ----------------------------------------------------------
# Docker installation in WSL
# ----------------------------------------------------------

Write-Host "=== Adding Docker repository ==="
wsl -d $DISTRO --user root -- install -m 0755 -d /etc/apt/keyrings
wsl -d $DISTRO --user root -- bash -lc 'ARCH=$(dpkg --print-architecture); CODENAME=$(lsb_release -cs); echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $CODENAME stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null'
Write-Host "=== Installing Docker Engine ==="
wsl -d $DISTRO --user root -- apt update
wsl -d $DISTRO --user root -- apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

Write-Host "=== Adding default WSL user to docker group ==="
$WSLUSER = (wsl -d $DISTRO -- bash -lc 'echo $USER').Trim()
wsl -d $DISTRO --user root -- usermod -aG docker $WSLUSER

Write-Host "=== Installing NVIDIA Container Toolkit ==="
#wsl -d $DISTRO --user root -- bash -c "curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit.gpg"
#wsl -d $DISTRO --user root -- bash -lc 'curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/ubuntu24.04/nvidia-container-toolkit.list | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list'



wsl -d $DISTRO --user root -- apt install -y nvidia-container-toolkit
wsl -d $DISTRO --user root -- nvidia-ctk runtime configure --runtime=docker

Write-Host "=== Restarting Docker inside WSL ==="
$hasSystemd = (wsl -d $DISTRO -- bash -lc 'ps -p 1 -o comm=' 2>$null) -eq 'systemd'
if ($hasSystemd) {
    wsl -d $DISTRO --user root -- systemctl restart docker
}

Write-Host "=== Testing GPU in Docker ==="
try {
    wsl -d $DISTRO -- docker run --rm --gpus all nvidia/cuda:12.4.1-runtime-ubuntu22.04 nvidia-smi
    Write-Host "GPU in Docker works correctly!" 
    wsl -d $DISTRO -- docker rmi nvidia/cuda:12.4.1-runtime-ubuntu22.04
}
catch {
    Write-Host "ERROR: Docker cannot access NVIDIA GPU."
}

try {
    wsl -d $DISTRO -- bash -c "cd '$WSL_TARGET_DIR' && ./build_image.sh && ./run_comfy_headless.sh"
    Write-Host "Build completed"
}
catch {
    Write-Error "Build failed"
    exit 1
}


Write-Host "=== Setup completed ==="
