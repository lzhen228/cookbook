import { Descriptions, Table, Tag } from 'antd';
import type { CreditContent } from '@/types/supplier.types';

interface CreditTabProps {
  content: CreditContent;
}

const CHANGE_LABEL: Record<string, { label: string; color: string }> = {
  upgrade: { label: '上调', color: 'green' },
  downgrade: { label: '下调', color: 'red' },
  maintain: { label: '维持', color: 'default' },
};

/** 信用数据 Tab - 评级、评级历史 */
export function CreditTab({ content }: CreditTabProps) {
  return (
    <div>
      <Descriptions column={3} size="small" bordered style={{ marginBottom: 16 }}>
        <Descriptions.Item label="当前评级">
          {content.rating ? (
            <Tag color={content.rating.startsWith('AA') ? 'green' : 'orange'} style={{ fontSize: 14 }}>
              {content.rating}
            </Tag>
          ) : '-'}
        </Descriptions.Item>
        <Descriptions.Item label="评级机构">{content.rating_agency ?? '-'}</Descriptions.Item>
        <Descriptions.Item label="评级展望">
          {content.rating_outlook ? (
            <Tag color={content.rating_outlook === '稳定' ? 'green' : 'orange'}>
              {content.rating_outlook}
            </Tag>
          ) : '-'}
        </Descriptions.Item>
        <Descriptions.Item label="评级日期">{content.rating_date ?? '-'}</Descriptions.Item>
        <Descriptions.Item label="信用评分">
          {content.credit_score != null ? `${content.credit_score} 分` : '-'}
        </Descriptions.Item>
      </Descriptions>

      {(content.rating_history?.length ?? 0) > 0 && (
        <>
          <div style={{ marginBottom: 8, fontWeight: 600, fontSize: 13 }}>评级历史</div>
          <Table
            rowKey={(r) => `${r.agency}-${r.date}`}
            dataSource={content.rating_history}
            pagination={false}
            size="small"
            columns={[
              {
                title: '评级',
                dataIndex: 'rating',
                width: 80,
                render: (r: string) => (
                  <Tag color={r.startsWith('AA') ? 'green' : 'orange'}>{r}</Tag>
                ),
              },
              { title: '评级机构', dataIndex: 'agency' },
              {
                title: '变动',
                dataIndex: 'change',
                width: 80,
                render: (c: string) => {
                  const cfg = CHANGE_LABEL[c] ?? { label: c, color: 'default' };
                  return <Tag color={cfg.color}>{cfg.label}</Tag>;
                },
              },
              { title: '日期', dataIndex: 'date', width: 120 },
            ]}
          />
        </>
      )}
    </div>
  );
}
