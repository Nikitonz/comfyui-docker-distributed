# comfyui-docker-distributed

## Как запустить / How to run
`Win + R → powershell → Ctrl + Shift + Enter`
```powershell
powershell -ExecutionPolicy Bypass -File all-in-one.ps1
```
<details>
<summary>[RU]</summary>
  
## Назначение проекта — автоматизированная подготовка и запуск среды ComfyUI в WSL (Ubuntu по умолчанию) с использованием Docker и NVIDIA GPU.

### Что делает:
  1. копирует файлы репозитория из Windows в среду WSL;
  2. собирает Docker-образ с ComfyUI и зависимостями (PyTorch / CUDA), настраивает для работы в роли worker/master (distributed);
  3. запускает ComfyUI внутри контейнера;

### Проект предназначен для:
  * пользователей Windows 10,11 с NVIDIA GPU;
  * запуска ComfyUI в изолированной Docker-среде;
  * автоматизации установки и запуска без Docker Desktop.
</details>

<details>
<summary>[EN]</summary>

## Project purpose is to automate the setup and execution of ComfyUI inside WSL (Ubuntu by default) using Docker with NVIDIA GPU support.
  
### What does it do?:
  1. copies repository files from Windows into the WSL environment;
  2. builds a Docker image containing ComfyUI and its dependencies (PyTorch / CUDA);
  3. runs ComfyUI inside a container;

### The project is intended for:
  * Windows 10,11 users with NVIDIA GPUs;
  * running ComfyUI in an isolated Docker-based environment;
  * automated deployment without Docker Desktop.
</details>




## Sources used
* ComfyUI — [тык](https://github.com/comfyanonymous/ComfyUI)
* ComfyUI Distributed (by robertvoy) — [тык](https://github.com/robertvoy/comfyui-distributed)
