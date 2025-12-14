docker run -d \
  --name comfyui \
  --gpus all \
  -p 8188:8188 \
  -v /mnt/z:/mnt/z \
  -e EXTRA_MODEL_PATHS=/mnt/z \
  comfyui:torch2.9 \
  bash -c "python main.py --listen --port 8188 --enable-cors-header"
