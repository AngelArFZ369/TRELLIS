# Base image with CUDA 12.4
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/miniconda3/bin:${PATH}"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    ffmpeg \
    libgl1-mesa-glx \
    libjpeg-dev \
    python3-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && mkdir /root/.conda \
    && bash Miniconda3-latest-Linux-x86_64.sh -b \
    && rm -f Miniconda3-latest-Linux-x86_64.sh

# Create conda environment
RUN conda create -n trellis2 python=3.10 -y

# Make sure we use the conda environment for subsequent commands
SHELL ["conda", "run", "-n", "trellis2", "/bin/bash", "-c"]

# Install PyTorch (CUDA 12.4) as per setup.sh
RUN pip install torch==2.6.0 torchvision==0.21.0 --index-url https://download.pytorch.org/whl/cu124

# Install Basic Dependencies
RUN pip install imageio imageio-ffmpeg tqdm easydict opencv-python-headless ninja trimesh transformers gradio==6.0.1 tensorboard pandas lpips zstandard
RUN pip install git+https://github.com/EasternJournalist/utils3d.git@9a4eb15e4021b67b12c460c7057d642626897ec8
RUN pip install pillow-simd kornia timm

# Install Flash Attention
RUN pip install flash-attn==2.7.3

# Install Extensions (NVDiffrast, NVDiffRec, CuMesh, FlexGEMM)
WORKDIR /tmp/extensions

# NVDiffrast
RUN git clone -b v0.4.0 https://github.com/NVlabs/nvdiffrast.git nvdiffrast \
    && pip install ./nvdiffrast --no-build-isolation

# NVDiffRec
RUN git clone -b renderutils https://github.com/JeffreyXiang/nvdiffrec.git nvdiffrec \
    && pip install ./nvdiffrec --no-build-isolation

# CuMesh
RUN git clone https://github.com/JeffreyXiang/CuMesh.git CuMesh --recursive \
    && pip install ./CuMesh --no-build-isolation

# FlexGEMM
RUN git clone https://github.com/JeffreyXiang/FlexGEMM.git FlexGEMM --recursive \
    && pip install ./FlexGEMM --no-build-isolation

# Clean up extensions source
WORKDIR /app

# Copy project files
COPY . .

# Install o-voxel (local extension)
RUN pip install ./o-voxel --no-build-isolation

# Expose Gradio port
EXPOSE 7860

# Add start script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Default command
CMD ["/start.sh"]
