#!/usr/bin/env python3
# 使用方法: source venv/bin/activate && python3 experiments/scripts/analyze-results.py <results_dir>

import os
import sys
import re
import json
from pathlib import Path

# 尝试导入，如果失败给出友好提示
try:
    import matplotlib.pyplot as plt
    import pandas as pd
except ImportError:
    print("Error: Required packages not found!")
    print("Please run:")
    print("  source venv/bin/activate")
    print("  pip3 install matplotlib pandas tabulate")
    sys.exit(1)

def parse_caliper_log(log_file):
    """从 Caliper 日志中提取关键指标"""
    metrics = {
        'peer_count': 0,
        'tps_max': 0,
        'tps_avg': 0,
        'latency_avg': 0,
        'latency_max': 0,
        'success_rate': 0,
        'throughput': 0
    }
    
    try:
        with open(log_file, 'r') as f:
            content = f.read()
            
            # 提取 peer 数量
            peer_match = re.search(r'(\d+)peers', log_file)
            if peer_match:
                metrics['peer_count'] = int(peer_match.group(1))
            
            # 提取 TPS
            tps_pattern = r'Succ.*?(\d+\.?\d*)\s*tps'
            tps_matches = re.findall(tps_pattern, content, re.IGNORECASE)
            if tps_matches:
                tps_values = [float(x) for x in tps_matches]
                metrics['tps_avg'] = sum(tps_values) / len(tps_values)
                metrics['tps_max'] = max(tps_values)
            
            # 提取延迟
            latency_pattern = r'avg.*?(\d+\.?\d*)\s*ms'
            latency_matches = re.findall(latency_pattern, content, re.IGNORECASE)
            if latency_matches:
                latency_values = [float(x) for x in latency_matches]
                metrics['latency_avg'] = sum(latency_values) / len(latency_values)
            
            # 提取成功率
            success_pattern = r'(\d+)\s*\(\s*(\d+\.?\d*)\s*%\)'
            success_matches = re.findall(success_pattern, content)
            if success_matches:
                success_rates = [float(x[1]) for x in success_matches]
                metrics['success_rate'] = sum(success_rates) / len(success_rates)
    
    except Exception as e:
        print(f"Error parsing {log_file}: {e}")
    
    return metrics

def generate_charts(results_df, output_dir):
    """生成对比图表"""
    
    # 设置字体
    plt.rcParams['font.sans-serif'] = ['DejaVu Sans']
    plt.rcParams['axes.unicode_minus'] = False
    
    fig, axes = plt.subplots(2, 2, figsize=(15, 10))
    fig.suptitle('Fabric Sharding Performance Comparison', fontsize=16, fontweight='bold')
    
    # 1. TPS 对比
    axes[0, 0].bar(results_df['peer_count'], results_df['tps_avg'], color='steelblue', alpha=0.7)
    axes[0, 0].set_xlabel('Number of Peers')
    axes[0, 0].set_ylabel('Average TPS')
    axes[0, 0].set_title('Throughput vs Peer Count')
    axes[0, 0].grid(axis='y', alpha=0.3)
    
    # 2. 延迟对比
    axes[0, 1].plot(results_df['peer_count'], results_df['latency_avg'], 
                    marker='o', linewidth=2, markersize=8, color='coral')
    axes[0, 1].set_xlabel('Number of Peers')
    axes[0, 1].set_ylabel('Average Latency (ms)')
    axes[0, 1].set_title('Latency vs Peer Count')
    axes[0, 1].grid(alpha=0.3)
    
    # 3. 成功率对比
    axes[1, 0].bar(results_df['peer_count'], results_df['success_rate'], color='lightgreen', alpha=0.7)
    axes[1, 0].set_xlabel('Number of Peers')
    axes[1, 0].set_ylabel('Success Rate (%)')
    axes[1, 0].set_title('Success Rate vs Peer Count')
    axes[1, 0].set_ylim([0, 105])
    axes[1, 0].grid(axis='y', alpha=0.3)
    
    # 4. 综合指标
    efficiency = results_df['tps_avg'] / (results_df['latency_avg'] + 1)
    axes[1, 1].bar(results_df['peer_count'], efficiency, color='mediumpurple', alpha=0.7)
    axes[1, 1].set_xlabel('Number of Peers')
    axes[1, 1].set_ylabel('Efficiency (TPS/Latency)')
    axes[1, 1].set_title('Efficiency Metric')
    axes[1, 1].grid(axis='y', alpha=0.3)
    
    plt.tight_layout()
    output_path = os.path.join(output_dir, 'performance-comparison.png')
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"✓ Charts saved to {output_path}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 analyze-results.py <results_timestamp_dir>")
        print("Example: python3 analyze-results.py experiments/results/20260126_143000")
        sys.exit(1)
    
    results_dir = sys.argv[1]
    logs_dir = "experiments/logs"
    
    if not os.path.exists(results_dir):
        print(f"Error: Directory {results_dir} not found")
        sys.exit(1)
    
    print("Analyzing experiment results...")
    print(f"Results directory: {results_dir}")
    
    # 收集所有日志文件
    log_files = sorted(Path(logs_dir).glob("*peers-*.log"))
    
    if not log_files:
        print("No log files found!")
        sys.exit(1)
    
    # 解析每个日志文件
    all_metrics = []
    for log_file in log_files:
        print(f"Parsing {log_file.name}...")
        metrics = parse_caliper_log(str(log_file))
        if metrics['peer_count'] > 0:
            all_metrics.append(metrics)
    
    if not all_metrics:
        print("No valid metrics extracted!")
        sys.exit(1)
    
    # 创建 DataFrame
    df = pd.DataFrame(all_metrics)
    df = df.sort_values('peer_count')
    
    # 打印结果表格
    print("\n" + "="*80)
    print("EXPERIMENT RESULTS SUMMARY")
    print("="*80)
    print(df.to_string(index=False))
    print("="*80)
    
    # 保存 CSV
    csv_path = os.path.join(results_dir, 'metrics-summary.csv')
    df.to_csv(csv_path, index=False)
    print(f"\n✓ Results saved to: {csv_path}")
    
    # 生成图表
    try:
        generate_charts(df, results_dir)
    except Exception as e:
        print(f"Warning: Could not generate charts: {e}")
    
    # 生成 Markdown 报告
    report_path = os.path.join(results_dir, 'REPORT.md')
    with open(report_path, 'w') as f:
        f.write("# Fabric Sharding Performance Test Report\n\n")
        f.write(f"**Test Date:** {Path(results_dir).name}\n\n")
        f.write("## Results Summary\n\n")
        f.write("```\n")
        f.write(df.to_string(index=False))
        f.write("\n```\n\n")
        f.write("## Key Findings\n\n")
        
        # 自动分析
        best_tps = df.loc[df['tps_avg'].idxmax()]
        best_latency = df.loc[df['latency_avg'].idxmin()]
        
        f.write(f"- **Best Throughput:** {best_tps['peer_count']} peers with {best_tps['tps_avg']:.2f} TPS\n")
        f.write(f"- **Best Latency:** {best_latency['peer_count']} peers with {best_latency['latency_avg']:.2f} ms\n")
        f.write(f"- **Overall Success Rate:** {df['success_rate'].mean():.2f}%\n")
    
    print(f"✓ Report saved to: {report_path}")
    print("\n✓ Analysis complete!")

if __name__ == "__main__":
    main()
