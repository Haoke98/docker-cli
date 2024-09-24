#!/bin/bash

# 检查是否提供了参数
if [ $# -ne 1 ]; then
    echo "Usage: docker-remote-pull.sh <docker镜像名称>:<tag>"
    exit 1
fi

# 获取镜像名称和标签
image_full=$1

# 设置默认值
registry_mirror="docker.io"  # 默认的镜像仓库，如果没有指定
name_space="library"  # 默认的命名空间，如果没有指定

# 判断输入格式
if [[ $image_full == *"/"* && $image_full == *":"* ]]; then
    # 情况1和情况2，带有<name_space>/<image_name>:<tag>，可能也带有<regsitry-mirror>
    registry_part=$(echo $image_full | awk -F'/' '{print $1}')
    # 如果注册表部分是镜像仓库（有'.'或者':'），就认为是registry-mirror，否则是name_space
    if [[ $registry_part == *"."* || $registry_part == *":"* ]]; then
        registry_mirror=$registry_part
        name_space=$(echo $image_full | awk -F'/' '{print $2}')
        image_name_tag=$(echo $image_full | awk -F'/' '{print $3}')
    else
        name_space=$registry_part
        image_name_tag=$(echo $image_full | awk -F'/' '{print $2}')
    fi
else
    # 情况3，没有命名空间和registry-mirror，只是<image_name>:<tag>
    image_name_tag=$image_full
fi

# 分割出镜像名称和标签
image_name=$(echo $image_name_tag | awk -F':' '{print $1}')
image_tag=$(echo $image_name_tag | awk -F':' '{print $2}')

# 设置输出的tar文件名称
output_file="docker_image_${name_space}_${image_name}_v${image_tag}.tar"

# 拉取Docker镜像
full_image_name="${registry_mirror}/${name_space}/${image_name}:${image_tag}"
echo "Pulling Docker image: $full_image_name..."
docker pull $full_image_name

# 检查镜像拉取是否成功
if [ $? -ne 0 ]; then
    echo "Failed to pull Docker image: $full_image_name"
    exit 1
fi

# 保存Docker镜像为tar文件
echo "Saving Docker image as $output_file..."
docker save -o $output_file $full_image_name

# 检查镜像保存是否成功
if [ $? -ne 0 ]; then
    echo "Failed to save Docker image: $full_image_name to $output_file"
    exit 1
fi

# 定义目标服务器信息
TARGET_SERVER="10.4.2.1"
TARGET_USER="root"
TARGET_PORT="55"
TARGET_DIR="/home/"

# 通过scp传输tar文件到目标服务器
echo "Transferring $output_file to $TARGET_SERVER..."
scp -P $TARGET_PORT $output_file ${TARGET_USER}@${TARGET_SERVER}:${TARGET_DIR}

# 检查传输是否成功
if [ $? -ne 0 ]; then
    echo "Failed to transfer $output_file to ${TARGET_SERVER}:${TARGET_DIR}"
    exit 1
fi

# 通过SSH远程加载Docker镜像
echo "Loading Docker image on remote server..."
ssh -p $TARGET_PORT ${TARGET_USER}@${TARGET_SERVER} "docker load -i ${TARGET_DIR}${output_file}"

# 检查远程加载是否成功
if [ $? -ne 0 ]; then
    echo "Failed to load Docker image on ${TARGET_SERVER}"
    exit 1
fi

echo "Docker image $full_image_name successfully transferred and loaded on $TARGET_SERVER."