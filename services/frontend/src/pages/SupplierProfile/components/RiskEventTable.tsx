import { Table, Tag, Button } from 'antd';
import { RiskDimensionTag } from '@/components/RiskDimensionTag';
import { formatRelativeTime } from '@/utils/formatters';
import { RISK_EVENT_STATUS_CONFIG } from '@/constants/healthLevel';
import type { RiskEventBrief, RiskDimension } from '@/types/supplier.types';

interface RiskEventTableProps {
  events: RiskEventBrief[];
  total: number;
}

/** 风险事项表格（展示最新 5 条，附总数提示） */
export function RiskEventTable({ events, total }: RiskEventTableProps) {
  return (
    <Table<RiskEventBrief>
      rowKey="id"
      dataSource={events}
      pagination={false}
      size="small"
      locale={{ emptyText: '暂无风险事项' }}
      columns={[
        {
          title: '风险维度',
          dataIndex: 'risk_dimension',
          width: 96,
          render: (dim: RiskDimension) => <RiskDimensionTag dimension={dim} />,
        },
        {
          title: '事项描述',
          dataIndex: 'description',
          ellipsis: true,
        },
        {
          title: '状态',
          dataIndex: 'status',
          width: 80,
          render: (status: string) => {
            const cfg = RISK_EVENT_STATUS_CONFIG[status as keyof typeof RISK_EVENT_STATUS_CONFIG];
            return cfg ? <Tag color={cfg.color}>{cfg.label}</Tag> : <Tag>{status}</Tag>;
          },
        },
        {
          title: '触发时间',
          dataIndex: 'triggered_at',
          width: 100,
          render: (val: string) => formatRelativeTime(val),
        },
        {
          title: '来源',
          dataIndex: 'source_url',
          width: 56,
          render: (url: string | null) =>
            url ? (
              <Button
                type="link"
                size="small"
                style={{ padding: 0 }}
                href={url}
                target="_blank"
                rel="noopener noreferrer"
              >
                查看
              </Button>
            ) : (
              '-'
            ),
        },
      ]}
      footer={
        total > events.length
          ? () => (
              <span style={{ fontSize: 12, color: '#8c8c8c' }}>
                共 {total} 条风险事项，仅展示最新 {events.length} 条
              </span>
            )
          : undefined
      }
    />
  );
}
