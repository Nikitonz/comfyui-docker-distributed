# ==========================================================
# Env
# ==========================================================
$DISTRO = "Ubuntu-24.04"
$WSL_TARGET_DIR = "~/AI"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== Source directory on Windows. Using this ==="
Write-Host $SCRIPT_DIR

# ==========================================================
#  SETUP WSL2 + UBUNTU 24.04 + NVIDIA GPU SUPPORT
#  Script must be run as Administrator
# ==========================================================

Write-Host "=== Enabling Windows features: WSL + VirtualMachinePlatform ==="
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

Write-Host "=== Installing WSL if missing ==="
wsl --install

Write-Host "=== Installing $DISTRO ==="
wsl --install -d $DISTRO

Write-Host "=== Updating WSL kernel and configuration ==="
wsl --update

Write-Host "=== Shutting down WSL to apply updates ==="
wsl --shutdown

Write-Host "=== Running WSL initialization for $DISTRO ==="
wsl -d $DISTRO -- echo "Your selected distro is ready-to-go"

# ----------------------------------------------------------
# Copy utilities from repo  on host to wsl mashine
# ----------------------------------------------------------

wsl -d $DISTRO -- bash -c "mkdir -p $WSL_TARGET_DIR"
tar -C "$SCRIPT_DIR" -cf - . --exclude=all_in_one.ps1 --exclude=.git --exclude=.vscode | `
wsl -d $DISTRO -- bash -c "cd $WSL_TARGET_DIR && tar -xf -" 
wsl -d $DISTRO -- bash -c "
cd $WSL_TARGET_DIR &&
chmod +x ./*.sh
"
# ----------------------------------------------------------
# Ubuntu commands executed via WSL
# ----------------------------------------------------------

Write-Host "=== Updating Ubuntu system packages ==="
wsl -d $DISTRO -- sudo apt update
wsl -d $DISTRO -- sudo apt upgrade -y

Write-Host "=== Installing essential Ubuntu packages ==="
wsl -d $DISTRO -- sudo apt install -y `
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
try {
    wsl -d $DISTRO -- nvidia-smi
    Write-Host "NVIDIA GPU detected in WSL."
}
catch {
    Write-Host "ERROR: NVIDIA GPU not detected. Install latest Windows NVIDIA driver (560+)."
}


# Write-Host "=== Installing CUDA Toolkit (optional) ==="
# wsl -d $DISTRO -- sudo apt install -y nvidia-cuda-toolkit #uncomment line if needed

# ----------------------------------------------------------
# Docker installation in WSL
# ----------------------------------------------------------

Write-Host "=== Adding Docker repository ==="
wsl -d $DISTRO -- sudo install -m 0755 -d /etc/apt/keyrings
wsl -d $DISTRO -- bash -c "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
wsl -d $DISTRO -- bash -c "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"

Write-Host "=== Installing Docker Engine ==="
wsl -d $DISTRO -- sudo apt update
wsl -d $DISTRO -- sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

Write-Host "=== Adding default WSL user to docker group ==="
$WSLUSER = (wsl -d $DISTRO -- bash -c "echo \$USER").Trim()
wsl -d $DISTRO -- sudo usermod -aG docker $WSLUSER

Write-Host "=== Installing NVIDIA Container Toolkit ==="
wsl -d $DISTRO -- bash -c "curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit.gpg"
wsl -d $DISTRO -- bash -c "curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/$(. /etc/os-release; echo \$ID\$VERSION_ID)/nvidia-container-toolkit.list | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list"

wsl -d $DISTRO -- sudo apt install -y nvidia-container-toolkit
wsl -d $DISTRO -- sudo nvidia-ctk runtime configure --runtime=docker

Write-Host "=== Restarting Docker inside WSL ==="
wsl -d $DISTRO -- sudo systemctl restart docker || Write-Host "Docker service not autostarted in WSL — this is ok."

Write-Host "=== Testing GPU in Docker ==="
try {
    wsl -d $DISTRO -- docker run --rm --gpus all nvidia/cuda:12.4.1-runtime-ubuntu22.04 nvidia-smi
    Write-Host "GPU in Docker works correctly!" 
    wsl -d $DISTRO -- docker rmi nvidia/cuda:12.4.1-runtime-ubuntu22.04
}
catch {
    Write-Host "ERROR: Docker cannot access NVIDIA GPU."
}

wsl -d $DISTRO -- bash -c "
cd $WSL_TARGET_DIR &&
./build_image.sh &&
./run_comfy_headless.sh
"


Write-Host "=== Setup completed ==="
