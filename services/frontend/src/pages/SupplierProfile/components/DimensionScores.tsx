import { Progress } from 'antd';
import { RISK_DIMENSION_CONFIG } from '@/constants/healthLevel';
import type { RiskDimension } from '@/types/supplier.types';

interface DimensionScoresProps {
  scores: Record<string, number> | null;
}

const DIMENSION_ORDER: RiskDimension[] = ['legal', 'finance', 'credit', 'tax', 'operation'];

/** 维度评分进度条列表 */
export function DimensionScores({ scores }: DimensionScoresProps) {
  if (!scores) {
    return <div style={{ color: '#bfbfbf', fontSize: 13, textAlign: 'center' }}>暂无维度评分</div>;
  }

  return (
    <div>
      {DIMENSION_ORDER.map((dim) => {
        const score = scores[dim];
        const config = RISK_DIMENSION_CONFIG[dim];
        if (score == null) return null;

        return (
          <div key={dim} style={{ marginBottom: 10 }}>
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                marginBottom: 3,
                fontSize: 12,
              }}
            >
              <span style={{ color: '#595959' }}>{config.label}</span>
              <span style={{ fontWeight: 600, color: config.color }}>{score.toFixed(1)}</span>
            </div>
            <Progress
              percent={score}
              strokeColor={config.color}
              trailColor="#f5f5f5"
              showInfo={false}
              size="small"
              strokeLinecap="square"
            />
          </div>
        );
      })}
    </div>
  );
}
