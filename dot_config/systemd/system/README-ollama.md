# Ollama System Service

This directory contains the systemd service file for Ollama, managed by chezmoi.

## Why system service?

Ollama runs as a dedicated `ollama` user for security isolation and GPU access.
This requires a system-level service (not a user service).

## Install / Update

After editing the service file in chezmoi, apply with:

```bash
sudo cp ~/.local/share/chezmoi/dot_config/systemd/system/ollama.service.tmpl /etc/systemd/system/ollama.service
# Note: chezmoi will render the .tmpl file, but for system services we copy the rendered version
# Or use: chezmoi execute-template < dot_config/systemd/system/ollama.service.tmpl | sudo tee /etc/systemd/system/ollama.service
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

## Environment Variables

| Variable | Value | Purpose |
| ----------------------- | --------------- | ------------------------------------ |
| OLLAMA_CONTEXT_LENGTH | 8192 | Max context window |
| OLLAMA_FLASH_ATTENTION | 1 | Enable flash attention (faster inference) |
| OLLAMA_HOST | 127.0.0.1:11434 | Bind to localhost only |
| OLLAMA_NUM_PARALLEL | 2 | Allow 2 concurrent requests |
| CUDA_VISIBLE_DEVICES | 0 | Use first NVIDIA GPU |

## Current GPU

NVIDIA GeForce GTX 1650, 4.0 GiB VRAM, CUDA 12.8, compute 7.5
