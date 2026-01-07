# Read Arguments
TEMP=`getopt -o h --long help,new-env,basic,flash-attn,cumesh,o-voxel,flexgemm,nvdiffrast,nvdiffrec -n 'setup.sh' -- "$@"`

eval set -- "$TEMP"

HELP=false
NEW_ENV=false
BASIC=false
FLASHATTN=false
CUMESH=false
OVOXEL=false
FLEXGEMM=false
NVDIFFRAST=false
NVDIFFREC=false
ERROR=false


if [ "$#" -eq 1 ] ; then
    HELP=true
fi

while true ; do
    case "$1" in
        -h|--help) HELP=true ; shift ;;
        --new-env) NEW_ENV=true ; shift ;;
        --basic) BASIC=true ; shift ;;
        --flash-attn) FLASHATTN=true ; shift ;;
        --cumesh) CUMESH=true ; shift ;;
        --o-voxel) OVOXEL=true ; shift ;;
        --flexgemm) FLEXGEMM=true ; shift ;;
        --nvdiffrast) NVDIFFRAST=true ; shift ;;
        --nvdiffrec) NVDIFFREC=true ; shift ;;
        --) shift ; break ;;
        *) ERROR=true ; break ;;
    esac
done

if [ "$ERROR" = true ] ; then
    echo "Error: Invalid argument"
    HELP=true
fi

if [ "$HELP" = true ] ; then
    echo "Usage: setup.sh [OPTIONS]"
    echo "Options:"
    echo "  -h, --help              Display this help message"
    echo "  --new-env               Create a new conda environment"
    echo "  --basic                 Install basic dependencies"
    echo "  --flash-attn            Install flash-attention"
    echo "  --cumesh                Install cumesh"
    echo "  --o-voxel               Install o-voxel"
    echo "  --flexgemm              Install flexgemm"
    echo "  --nvdiffrast            Install nvdiffrast"
    echo "  --nvdiffrec             Install nvdiffrec"
    return
fi

# Get system information
WORKDIR=$(pwd)

# Use workspace for temp files if available (persistent volume), otherwise fallback to /tmp
if [ -d "/workspace" ]; then
    TMP_DIR="/workspace/tmp"
    mkdir -p "$TMP_DIR"
    export TMPDIR="$TMP_DIR"
    export PIP_CACHE_DIR="$TMP_DIR/pip-cache"
    echo "Using persistent volume for temp files: $TMP_DIR"
else
    TMP_DIR="/tmp"
    echo "Using default temp directory: $TMP_DIR"
fi

if command -v nvidia-smi > /dev/null; then
    PLATFORM="cuda"
elif command -v rocminfo > /dev/null; then
    PLATFORM="hip"
else
    echo "Error: No supported GPU found"
    exit 1
fi

if [ "$NEW_ENV" = true ] ; then
    conda create -n trellis2 python=3.10
    conda activate trellis2
    if [ "$PLATFORM" = "cuda" ] ; then
        pip install torch==2.6.0 torchvision==0.21.0 --index-url https://download.pytorch.org/whl/cu124
    elif [ "$PLATFORM" = "hip" ] ; then
        pip install torch==2.6.0 torchvision==0.21.0 --index-url https://download.pytorch.org/whl/rocm6.2.4
    fi
fi

if [ "$BASIC" = true ] ; then
    # Install system dependencies
    apt-get update && apt-get install -y --no-install-recommends \
        git \
        wget \
        ffmpeg \
        libgl1-mesa-glx \
        libjpeg-dev \
        libpng-dev \
        libtiff-dev \
        build-essential \
        zlib1g-dev \
        libeigen3-dev

    pip install imageio imageio-ffmpeg tqdm easydict opencv-python-headless ninja trimesh transformers gradio==6.0.1 tensorboard pandas lpips zstandard
    pip install git+https://github.com/EasternJournalist/utils3d.git@9a4eb15e4021b67b12c460c7057d642626897ec8
    
    # Pillow SIMD needs zlib and jpeg dev first
    pip install pillow-simd
    pip install kornia timm
fi


# Create symlink for Eigen so it can be found
if [ ! -d "/usr/include/Eigen" ] && [ -d "/usr/include/eigen3/Eigen" ]; then
    ln -s /usr/include/eigen3/Eigen /usr/include/Eigen
fi

if [ "$FLASHATTN" = true ] ; then
    if [ "$PLATFORM" = "cuda" ] ; then
        pip install flash-attn==2.7.3
    elif [ "$PLATFORM" = "hip" ] ; then
        echo "[FLASHATTN] Prebuilt binaries not found. Building from source..."
        mkdir -p ${TMP_DIR}/extensions
        rm -rf ${TMP_DIR}/extensions/flash-attention
        git clone --recursive https://github.com/ROCm/flash-attention.git ${TMP_DIR}/extensions/flash-attention
        cd ${TMP_DIR}/extensions/flash-attention
        git checkout tags/v2.7.3-cktile
        GPU_ARCHS=gfx942 python setup.py install #MI300 series
        cd $WORKDIR
    else
        echo "[FLASHATTN] Unsupported platform: $PLATFORM"
    fi
fi

if [ "$NVDIFFRAST" = true ] ; then
    if [ "$PLATFORM" = "cuda" ] ; then
        mkdir -p ${TMP_DIR}/extensions
        rm -rf ${TMP_DIR}/extensions/nvdiffrast
        git clone -b v0.4.0 https://github.com/NVlabs/nvdiffrast.git ${TMP_DIR}/extensions/nvdiffrast
        pip install ${TMP_DIR}/extensions/nvdiffrast --no-build-isolation
    else
        echo "[NVDIFFRAST] Unsupported platform: $PLATFORM"
    fi
fi

if [ "$NVDIFFREC" = true ] ; then
    if [ "$PLATFORM" = "cuda" ] ; then
        mkdir -p ${TMP_DIR}/extensions
        rm -rf ${TMP_DIR}/extensions/nvdiffrec
        git clone -b renderutils https://github.com/JeffreyXiang/nvdiffrec.git ${TMP_DIR}/extensions/nvdiffrec
        pip install ${TMP_DIR}/extensions/nvdiffrec --no-build-isolation
    else
        echo "[NVDIFFREC] Unsupported platform: $PLATFORM"
    fi
fi

if [ "$CUMESH" = true ] ; then
    mkdir -p ${TMP_DIR}/extensions
    rm -rf ${TMP_DIR}/extensions/CuMesh
    git clone https://github.com/JeffreyXiang/CuMesh.git ${TMP_DIR}/extensions/CuMesh --recursive
    pip install ${TMP_DIR}/extensions/CuMesh --no-build-isolation
fi

if [ "$FLEXGEMM" = true ] ; then
    mkdir -p ${TMP_DIR}/extensions
    rm -rf ${TMP_DIR}/extensions/FlexGEMM
    git clone https://github.com/JeffreyXiang/FlexGEMM.git ${TMP_DIR}/extensions/FlexGEMM --recursive
    pip install ${TMP_DIR}/extensions/FlexGEMM --no-build-isolation
fi

if [ "$OVOXEL" = true ] ; then
    mkdir -p ${TMP_DIR}/extensions
    rm -rf ${TMP_DIR}/extensions/o-voxel
    cp -r o-voxel ${TMP_DIR}/extensions/o-voxel
    pip install ${TMP_DIR}/extensions/o-voxel --no-build-isolation
fi
