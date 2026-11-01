#!/usr/bin/env bash
# ==============================================================================
# RunPod One-Click Auto-Deploy Script for Flux.1-Dev + PuLID + ControlNet
# Sets up Custom Nodes, Python Dependencies, Model Weights, and Workflow
# ==============================================================================

set -e

COMFYUI_DIR="/workspace/ComfyUI"
if [ ! -d "$COMFYUI_DIR" ]; then
    echo "[!] ComfyUI directory not found at $COMFYUI_DIR. Defaulting to current directory."
    COMFYUI_DIR="$(pwd)"
fi

echo "=========================================================="
echo " Starting Automated ComfyUI Setup on: $COMFYUI_DIR"
echo "=========================================================="

# 1. Install System Utilities (Fast parallel downloader)
echo "[1/5] Installing aria2 for 10Gbps parallel model downloads..."
apt-get update -qq && apt-get install -y -qq aria2 git wget curl

# Function for ultra-fast parallel downloads
download_file() {
    local url="$1"
    local dir="$2"
    local filename="$3"
    mkdir -p "$dir"
    if [ -f "$dir/$filename" ]; then
        echo "  [✓] $filename already exists. Skipping."
    else
        echo "  [↓] Downloading $filename..."
        aria2c -x 16 -s 16 -k 1M --console-log-level=warn --dir="$dir" -o "$filename" "$url"
    fi
}

# 2. Clone Essential Custom Nodes
echo "[2/5] Cloning and updating custom nodes..."
cd "$COMFYUI_DIR/custom_nodes"

clone_or_pull() {
    local repo_url="$1"
    local folder_name="$2"
    if [ -d "$folder_name" ]; then
        echo "  [✓] $folder_name exists. Pulling latest..."
        git -C "$folder_name" pull --quiet
    else
        echo "  [+] Cloning $folder_name..."
        git clone --quiet "$repo_url" "$folder_name"
    fi
}

clone_or_pull "https://github.com/ltdrdata/ComfyUI-Manager.git" "ComfyUI-Manager"
clone_or_pull "https://github.com/sipie800/ComfyUI-PuLID-Flux.git" "ComfyUI-PuLID-Flux"
clone_or_pull "https://github.com/Fannovel16/comfyui_controlnet_aux.git" "comfyui_controlnet_aux"
clone_or_pull "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git" "ComfyUI_UltimateSDUpscale"
clone_or_pull "https://github.com/cubiq/ComfyUI_essentials.git" "ComfyUI_essentials"
clone_or_pull "https://github.com/rgthree/rgthree-comfy.git" "rgthree-comfy"
clone_or_pull "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git" "ComfyUI-Impact-Pack"

# 3. Install Python Dependencies
echo "[3/5] Installing Python wheels (InsightFace, ONNX GPU, etc.)..."
pip install --quiet insightface onnxruntime-gpu facexlib torchvision

# 4. Download Model Weights & Checkpoints Directly to Respective Folders
echo "[4/5] Downloading model weights directly into ComfyUI directory structure..."

# UNET (Flux.1-Dev FP8)
download_file \
    "https://huggingface.co/Kijai/flux-fp8/resolve/main/flux1-dev-fp8.safetensors" \
    "$COMFYUI_DIR/models/unet" \
    "flux1-dev-fp8.safetensors"

# CLIP (T5-XXL FP8 + CLIP-L)
download_file \
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" \
    "$COMFYUI_DIR/models/clip" \
    "t5xxl_fp8_e4m3fn.safetensors"

download_file \
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" \
    "$COMFYUI_DIR/models/clip" \
    "clip_l.safetensors"

# VAE
download_file \
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors" \
    "$COMFYUI_DIR/models/vae" \
    "ae.safetensors"

# PuLID Flux Model
download_file \
    "https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.1.safetensors" \
    "$COMFYUI_DIR/models/pulid" \
    "pulid_flux_v0.9.1.safetensors"

# ControlNet Depth (Flux)
download_file \
    "https://huggingface.co/Shakker-Labs/FLUX.1-dev-ControlNet-Depth/resolve/main/diffusion_pytorch_model.safetensors" \
    "$COMFYUI_DIR/models/controlnet" \
    "flux-depth-controlnet-v3.safetensors"

# DepthAnythingV2 Checkpoint for controlnet_aux
download_file \
    "https://huggingface.co/depth-anything/Depth-Anything-V2-Large/resolve/main/depth_anything_v2_vitl.pth" \
    "$COMFYUI_DIR/custom_nodes/comfyui_controlnet_aux/ckpts" \
    "depth_anything_v2_vitl.pth"

# 4x-UltraSharp Upscaler
download_file \
    "https://huggingface.co/lokcx/4x-Ultrasharp/resolve/main/4x-UltraSharp.pth" \
    "$COMFYUI_DIR/models/upscale_models" \
    "4x-UltraSharp.pth"

# InsightFace AntelopeV2 models (required by PuLID)
INSIGHT_DIR="$COMFYUI_DIR/models/insightface/models/antelopev2"
if [ ! -d "$INSIGHT_DIR" ]; then
    echo "  [↓] Downloading AntelopeV2 face recognition models..."
    mkdir -p "$INSIGHT_DIR"
    wget -q --show-progress -O /tmp/antelopev2.zip "https://github.com/deepinsight/insightface/releases/download/v0.7/antelopev2.zip" || true
    if [ -f /tmp/antelopev2.zip ]; then
        unzip -q -o /tmp/antelopev2.zip -d "$INSIGHT_DIR"
        rm -f /tmp/antelopev2.zip
    fi
fi

# 5. Copy Workflow JSON to User Workflows
echo "[5/5] Deploying workflow JSON into ComfyUI default workflows..."
WORKFLOW_DEST="$COMFYUI_DIR/user/default/workflows"
mkdir -p "$WORKFLOW_DEST"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/workflow.json" ]; then
    cp "$SCRIPT_DIR/workflow.json" "$WORKFLOW_DEST/Riya_Insta_Clone_Workflow.json"
    echo "  [✓] Workflow placed at: $WORKFLOW_DEST/Riya_Insta_Clone_Workflow.json"
fi

echo "=========================================================="
echo " Setup Completed Successfully!"
echo " Open ComfyUI, click 'Load' -> 'Riya_Insta_Clone_Workflow',"
echo " upload your target photo and master face, and hit 'Queue'!"
echo "=========================================================="