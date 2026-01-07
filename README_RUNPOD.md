# Deploying TRELLIS.2 on RunPod

This guide explains how to deploy the TRELLIS.2 (Text-to-3D) model on RunPod using the Dockerfile adapted for this project.

## Prerequisites

1.  **Docker Desktop** installed on your local machine.
2.  A **Docker Hub** account (to host your image).
3.  A **RunPod** account with credits.

## Step 1: Build the Docker Image

Open a terminal in this directory (`target_repo`) and run:

```bash
# Replace 'your-username' with your actual Docker Hub username.
docker build -t your-username/trellis2-runpod .
```

> **Note**: This build process compiles several custom CUDA extensions (`nvdiffrast`, `flash-attn`, etc.) so it may take **15-30 minutes**.

## Step 2: Push the Image to Docker Hub

```bash
docker login
docker push your-username/trellis2-runpod
```

## Step 3: Deploy on RunPod

1.  Go to [RunPod Console](https://console.runpod.io/deploy).
2.  Click **Deploy Pod**.
3.  Select a GPU. **Recommended**: NVIDIA A40 (48GB) or RTX A6000 (48GB). The 4B model is VRAM intensive.
4.  Click **Select Template** > **Customize Pod**.
    *   **Container Image**: `angelarfz/trellis2-runpod` (the one you just pushed).
    *   **Exposed Ports**: `7860` (this is crucial for the web UI).
    *   **Environment Variables**:
        *   Key: `HF_TOKEN` (Optional, if you need access to gated models, though TRELLIS.2 seems public).
        *   Key: `HF_HOME` (Recommended: `/workspace/hf-cache`). This tells Hugging Face to store models in the persistent volume.
    *   **Container Disk**: Increase to at least **20 GB** (to store model weights if not using persistent volume).
    *   **Volume Disk**: Mounted at `/workspace`. Recommended: **20 GB+**. If you set `HF_HOME` as above, your models will persist here after restarts.
5.  Click **Set Overrides** and then **Deploy**.

## Step 4: Access the Application

1.  Wait for the Pod to start. It may take a few minutes for the container to initialize and for the script to download the model weights (Check **Logs** in RunPod console to see progress).
2.  Once running, click the **Connect** button.
3.  Click **Connect to HTTP Service [Port 7860]**.
4.  You should see the Gradio Web UI for TRELLIS.2.

## Troubleshooting

-   **OOM (Out of Memory)**: If the pod crashes, try a GPU with more VRAM (e.g., A100 80GB).
-   **Slow Startup**: The first time you run it, it downloads ~10GB of model weights.
-   **Logs**: Always check the Pod logs if the UI is not accessible.
