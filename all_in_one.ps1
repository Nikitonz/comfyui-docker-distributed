# ==========================================================
#  SETUP WSL2 + UBUNTU 24.04 + NVIDIA GPU SUPPORT
#  Script must be run as Administrator
# ==========================================================

Write-Host "=== Enabling Windows features: WSL + VirtualMachinePlatform ==="
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

Write-Host "=== Installing WSL if missing ==="
wsl --install

Write-Host "=== Installing Ubuntu 24.04 ==="
wsl --install -d Ubuntu-24.04

Write-Host "=== Updating WSL kernel and configuration ==="
wsl --update

Write-Host "=== Shutting down WSL to apply updates ==="
wsl --shutdown

Write-Host "=== Running WSL initialization for Ubuntu 24.04 ==="
wsl -d Ubuntu-24.04 -- echo "Ubuntu ready-to-go"

# ----------------------------------------------------------
# Ubuntu commands executed via WSL
# ----------------------------------------------------------

Write-Host "=== Updating Ubuntu system packages ==="
wsl -d Ubuntu-24.04 -- sudo apt update
wsl -d Ubuntu-24.04 -- sudo apt upgrade -y

Write-Host "=== Installing essential Ubuntu packages ==="
wsl -d Ubuntu-24.04 -- sudo apt install -y `
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
    wsl -d Ubuntu-24.04 -- nvidia-smi
    Write-Host "NVIDIA GPU detected in WSL."
}
catch {
    Write-Host "ERROR: NVIDIA GPU not detected. Install latest Windows NVIDIA driver (560+)."
}


# Write-Host "=== Installing CUDA Toolkit (optional) ==="
# wsl -d Ubuntu-24.04 -- sudo apt install -y nvidia-cuda-toolkit #uncomment line if needed

# ----------------------------------------------------------
# Docker installation in WSL
# ----------------------------------------------------------

Write-Host "=== Adding Docker repository ==="
wsl -d Ubuntu-24.04 -- sudo install -m 0755 -d /etc/apt/keyrings
wsl -d Ubuntu-24.04 -- bash -c "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
wsl -d Ubuntu-24.04 -- bash -c "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"

Write-Host "=== Installing Docker Engine ==="
wsl -d Ubuntu-24.04 -- sudo apt update
wsl -d Ubuntu-24.04 -- sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

Write-Host "=== Adding default WSL user to docker group ==="
$WSLUSER = (wsl -d Ubuntu-24.04 -- bash -c "echo \$USER").Trim()
wsl -d Ubuntu-24.04 -- sudo usermod -aG docker $WSLUSER

Write-Host "=== Installing NVIDIA Container Toolkit ==="
wsl -d Ubuntu-24.04 -- bash -c "curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit.gpg"
wsl -d Ubuntu-24.04 -- bash -c "curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/$(. /etc/os-release; echo \$ID\$VERSION_ID)/nvidia-container-toolkit.list | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list"

wsl -d Ubuntu-24.04 -- sudo apt install -y nvidia-container-toolkit
wsl -d Ubuntu-24.04 -- sudo nvidia-ctk runtime configure --runtime=docker

Write-Host "=== Restarting Docker inside WSL ==="
wsl -d Ubuntu-24.04 -- sudo systemctl restart docker || Write-Host "Docker service not autostarted in WSL — this is ok."

Write-Host "=== Testing GPU in Docker ==="
try {
    wsl -d Ubuntu-24.04 -- docker run --rm --gpus all nvidia/cuda:12.4.1-runtime-ubuntu22.04 nvidia-smi
    Write-Host "GPU in Docker works correctly!" 
    wsl -d Ubuntu-24.04 -- docker rmi nvidia/cuda:12.4.1-runtime-ubuntu22.04
}
catch {
    Write-Host "ERROR: Docker cannot access NVIDIA GPU."
}

Write-Host "=== Setup completed ==="
