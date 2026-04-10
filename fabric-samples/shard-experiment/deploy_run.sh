#!/bin/bash

# network-setup-and-test.sh

echo "=== 启动Hyperledger Fabric网络 ==="
echo "当前目录: $(pwd)"

# 保存原始目录
ORIGINAL_DIR="$(pwd)"

# 切换到 test-network 目录
TARGET_DIR="$HOME/fabric-dev/fabric-new/fabric-samples/test-network"
if [ ! -d "$TARGET_DIR" ]; then
    echo "错误: 找不到目录 $TARGET_DIR"
    echo "请确认 fabric-samples 安装位置是否正确"
    exit 1
fi

echo "切换到目录: $TARGET_DIR"
cd "$TARGET_DIR"
echo "当前目录: $(pwd)"

# 检查 network.sh 是否存在
if [ ! -f "./network.sh" ]; then
    echo "错误: 在当前目录找不到 network.sh 文件"
    exit 1
fi

# 停止现有网络
echo "步骤1: 停止现有网络..."
./network.sh down

# 启动网络并创建通道
echo "步骤2: 启动网络并创建通道..."
./network.sh up createChannel -c mychannel

# 部署链码
echo "步骤3: 部署链码..."
./network.sh deployCC \
  -c mychannel \
  -ccn ev-cc \
  -ccp ../shard-experiment/chaincode \
  -ccl go \
  -ccv 1.0 \
  -ccs 1 \
  -ccep "OR('Org1MSP.peer')"



echo "=== Fabric网络部署完成 ==="

# 切换到 shard-experiment 目录进行性能测试
SHARD_EXP_DIR="$HOME/fabric-dev/fabric-new/fabric-samples/shard-experiment"
echo ""
echo "=== 开始性能测试 ==="
echo "切换到目录: $SHARD_EXP_DIR"

if [ ! -d "$SHARD_EXP_DIR" ]; then
    echo "错误: 找不到目录 $SHARD_EXP_DIR"
    echo "返回原始目录..."
    cd "$ORIGINAL_DIR"
    exit 1
fi

cd "$SHARD_EXP_DIR"
echo "当前目录: $(pwd)"

# 检查必要的文件是否存在
if [ ! -f "benchmark-config.yaml" ]; then
    echo "警告: 找不到 benchmark-config.yaml 文件"
fi

if [ ! -f "network-3peers.yaml" ]; then
    echo "警告: 找不到 network-3peers.yaml 文件"
fi

# 执行 Caliper 性能测试
echo "步骤4: 执行 Caliper 性能测试..."
echo "执行命令: npx caliper launch manager \\"
echo "  --caliper-workspace . \\"
echo "  --caliper-benchconfig benchmark-config.yaml \\"
echo "  --caliper-networkconfig network-3peers.yaml"

npx caliper launch manager \
  --caliper-workspace . \
  --caliper-benchconfig benchmark-config.yaml \
  --caliper-networkconfig network-3peers.yaml

if [ $? -eq 0 ]; then
    echo "✅ 性能测试完成"
else
    echo "❌ 性能测试失败"
fi

# 返回原始目录（可选）
# echo "返回原始目录: $ORIGINAL_DIR"
# cd "$ORIGINAL_DIR"

echo "=== 脚本执行结束 ==="
