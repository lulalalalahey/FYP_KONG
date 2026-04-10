#!/bin/bash

echo "Real-time Resource Monitor"
echo "Press Ctrl+C to stop"
echo ""

while true; do
    clear
    echo "=== $(date) ==="
    echo ""
    echo "=== Memory Usage ==="
    free -h
    echo ""
    echo "=== Docker Containers ==="
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
    echo ""
    echo "=== Disk Usage ==="
    df -h / | tail -1
    sleep 5
done
