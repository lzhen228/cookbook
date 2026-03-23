import ReactECharts from 'echarts-for-react';
import { HEALTH_LEVEL_CONFIG } from '@/constants/healthLevel';
import type { HealthLevel } from '@/types/supplier.types';

interface HealthScoreGaugeProps {
  score: number | null;
  level: HealthLevel | null;
}

/** ECharts 环形仪表盘，展示综合健康分 */
export function HealthScoreGauge({ score, level }: HealthScoreGaugeProps) {
  const levelConfig = level ? HEALTH_LEVEL_CONFIG[level] : null;
  const color = levelConfig?.color ?? '#bfbfbf';
  const displayValue = score ?? 0;

  const option = {
    series: [
      {
        type: 'gauge',
        startAngle: 210,
        endAngle: -30,
        radius: '88%',
        min: 0,
        max: 100,
        progress: {
          show: true,
          width: 18,
          itemStyle: { color },
        },
        pointer: { show: false },
        axisLine: {
          lineStyle: {
            width: 18,
            color: [[1, '#f0f0f0']],
          },
        },
        axisTick: { show: false },
        splitLine: { show: false },
        axisLabel: { show: false },
        anchor: { show: false },
        title: {
          show: true,
          offsetCenter: ['0%', '32%'],
          fontSize: 14,
          color: '#8c8c8c',
        },
        detail: {
          show: true,
          offsetCenter: ['0%', '-8%'],
          fontSize: score != null ? 40 : 28,
          fontWeight: 'bold',
          color,
          formatter: () => (score != null ? score.toFixed(1) : '未评分'),
        },
        data: [{ value: displayValue, name: levelConfig?.label ?? '' }],
      },
    ],
  };

  return <ReactECharts option={option} style={{ height: 200 }} notMerge />;
}
