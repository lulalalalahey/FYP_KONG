#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 配置 - 使用绝对路径
PROJECT_DIR="$HOME/fabric-dev/fabric-samples/shard-experiment"
NETWORK_DIR="$HOME/fabric-dev/fabric-samples/test-network"
RESULTS_DIR="$PROJECT_DIR/experiments/results"
LOGS_DIR="$PROJECT_DIR/experiments/logs"

# 实验配置
PEER_COUNTS=(2 4 6 8 10)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  分片数量性能对比实验${NC}"
echo -e "${GREEN}  实验时间: $TIMESTAMP${NC}"
echo -e "${GREEN}========================================${NC}"

# 验证目录存在
if [ ! -d "$NETWORK_DIR" ]; then
    echo -e "${RED}错误: test-network 目录不存在: $NETWORK_DIR${NC}"
    exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}错误: 项目目录不存在: $PROJECT_DIR${NC}"
    exit 1
fi

# 创建结果目录
mkdir -p "$RESULTS_DIR/$TIMESTAMP"
mkdir -p "$LOGS_DIR"

# 系统信息记录
echo "Recording system information..."
{
    echo "=== System Information ==="
    echo "Date: $(date)"
    echo "CPU Cores: $(nproc)"
    echo "Memory: $(free -h | grep Mem)"
    echo "Disk: $(df -h /)"
    echo "Network Dir: $NETWORK_DIR"
    echo "Project Dir: $PROJECT_DIR"
    echo ""
} > "$RESULTS_DIR/$TIMESTAMP/system-info.txt"

# 函数：检查资源
check_resources() {
    local mem_available=$(free -m | awk 'NR==2 {print $7}')
    if [ "$mem_available" -lt 200 ]; then
        echo -e "${RED}警告: 可用内存不足 200MB ($mem_available MB)${NC}"
        echo "建议停止其他应用或跳过大规模实验"
        read -p "是否继续? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    return 0
}

# 函数：清理网络
cleanup_network() {
    echo -e "${YELLOW}Cleaning up existing network...${NC}"
    cd "$NETWORK_DIR" || return 1
    ./network.sh down > /dev/null 2>&1
    
    # 强制清理 Docker 容器
    docker ps -aq | xargs -r docker rm -f > /dev/null 2>&1
    docker volume prune -f > /dev/null 2>&1
    
    sleep 3
}

# 函数：启动网络
start_network() {
    local peer_count=$1
    echo -e "${GREEN}Starting Fabric network with $peer_count peers...${NC}"
    
    cd "$NETWORK_DIR" || return 1
    
    # 启动网络
    ./network.sh up createChannel -c mychannel -ca
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to start network!${NC}"
        return 1
    fi
    
    # 部署 chaincode
    echo "Deploying chaincode..."
    ./network.sh deployCC -ccn ev-cc -ccp "$PROJECT_DIR/chaincode" -ccl go
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to deploy chaincode!${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Network started successfully${NC}"
    sleep 5
    return 0
}

# 函数：运行 Caliper 测试
run_caliper_test() {
    local peer_count=$1
    local result_file="$RESULTS_DIR/$TIMESTAMP/${peer_count}peers-report.html"
    
    echo -e "${GREEN}Running Caliper benchmark for $peer_count peers...${NC}"
    
    cd "$PROJECT_DIR" || return 1
    
    npx caliper launch manager \
        --caliper-workspace ./ \
        --caliper-networkconfig "experiments/network-configs/network-${peer_count}peers.yaml" \
        --caliper-benchconfig experiments/configs/benchmark-unified.yaml \
        --caliper-flow-only-test \
        --caliper-fabric-timeout-invokeorquery 60 \
        2>&1 | tee "$LOGS_DIR/${peer_count}peers-${TIMESTAMP}.log"
    
    local caliper_exit=$?
    
    # 移动报告
    if [ -f "report.html" ]; then
        mv report.html "$result_file"
        echo -e "${GREEN}✓ Report saved to: $result_file${NC}"
    else
        echo -e "${YELLOW}Warning: Report not generated${NC}"
    fi
    
    return $caliper_exit
}

# 主循环
for peers in "${PEER_COUNTS[@]}"; do
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  实验组: $peers Peers${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # 检查资源
    if ! check_resources; then
        echo "Skipping $peers peers experiment"
        continue
    fi
    
    # 清理
    cleanup_network
    
    # 启动网络
    if ! start_network "$peers"; then
        echo -e "${RED}Skipping this experiment due to network error${NC}"
        continue
    fi
    
    # 等待网络稳定
    echo "Waiting for network to stabilize..."
    sleep 10
    
    # 运行测试
    run_caliper_test "$peers"
    
    # 记录资源使用
    {
        echo "=== After $peers peers test ==="
        docker stats --no-stream
        echo ""
    } >> "$RESULTS_DIR/$TIMESTAMP/resource-usage.txt"
    
    # 清理（准备下一轮）
    cleanup_network
    
    echo -e "${GREEN}✓ Completed $peers peers experiment${NC}"
    echo "Cooling down..."
    sleep 15
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  所有实验完成!${NC}"
echo -e "${GREEN}  结果目录: $RESULTS_DIR/$TIMESTAMP${NC}"
echo -e "${GREEN}========================================${NC}"

# 生成汇总
echo "Generating summary..."
cat > "$RESULTS_DIR/$TIMESTAMP/README.txt" << SUMMARY
实验汇总报告
=============

实验时间: $TIMESTAMP
实验配置: ${PEER_COUNTS[@]} peers

结果文件:
$(ls -1 $RESULTS_DIR/$TIMESTAMP/*.html 2>/dev/null || echo "No reports generated")

日志文件:
$LOGS_DIR

下一步:
1. 查看各个 HTML 报告
2. 运行分析脚本: experiments/scripts/analyze-with-venv.sh experiments/results/$TIMESTAMP
3. 查看 resource-usage.txt 了解资源消耗

SUMMARY

cat "$RESULTS_DIR/$TIMESTAMP/README.txt"
