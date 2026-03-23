import { Descriptions, Table, Tag } from 'antd';
import type { TaxContent } from '@/types/supplier.types';

interface TaxTabProps {
  content: TaxContent;
}

const CREDIT_LEVEL_COLOR: Record<string, string> = {
  A级: 'green',
  B级: 'blue',
  C级: 'orange',
  D级: 'red',
};

/** 税务信息 Tab - 纳税信用、税务处罚、异常记录 */
export function TaxTab({ content }: TaxTabProps) {
  return (
    <div>
      <Descriptions column={3} size="small" bordered style={{ marginBottom: 16 }}>
        <Descriptions.Item label="纳税人类型">{content.tax_payer_type ?? '-'}</Descriptions.Item>
        <Descriptions.Item label="纳税信用等级">
          {content.tax_credit_level ? (
            <Tag color={CREDIT_LEVEL_COLOR[content.tax_credit_level] ?? 'default'}>
              {content.tax_credit_level}
            </Tag>
          ) : '-'}
        </Descriptions.Item>
        <Descriptions.Item label="信用评定日期">{content.tax_credit_date ?? '-'}</Descriptions.Item>
        <Descriptions.Item label="欠缴税款">
          {content.owed_tax ?? <span style={{ color: '#52c41a' }}>无</span>}
        </Descriptions.Item>
      </Descriptions>

      {(content.penalties?.length ?? 0) > 0 && (
        <>
          <div style={{ marginBottom: 8, fontWeight: 600, fontSize: 13 }}>税务处罚记录</div>
          <Table
            rowKey={(r) => `${r.type}-${r.date}`}
            dataSource={content.penalties}
            pagination={false}
            size="small"
            style={{ marginBottom: 16 }}
            columns={[
              { title: '处罚类型', dataIndex: 'type' },
              { title: '处罚金额', dataIndex: 'amount', width: 120 },
              { title: '处罚原因', dataIndex: 'reason', render: (v) => v ?? '-' },
              {
                title: '状态',
                dataIndex: 'status',
                width: 80,
                render: (s: string) => (
                  <Tag color={s === '已结清' ? 'green' : 'orange'}>{s}</Tag>
                ),
              },
              { title: '日期', dataIndex: 'date', width: 120 },
            ]}
          />
        </>
      )}

      {(content.abnormal_records?.length ?? 0) > 0 && (
        <>
          <div style={{ marginBottom: 8, fontWeight: 600, fontSize: 13 }}>异常记录</div>
          <Table
            rowKey={(r) => `${r.type}-${r.date}`}
            dataSource={content.abnormal_records}
            pagination={false}
            size="small"
            columns={[
              { title: '异常类型', dataIndex: 'type' },
              { title: '发现日期', dataIndex: 'date', width: 120 },
              { title: '原因说明', dataIndex: 'reason' },
              {
                title: '处理状态',
                dataIndex: 'status',
                width: 80,
                render: (s: string) => (
                  <Tag color={s === '已处理' ? 'green' : 'orange'}>{s}</Tag>
                ),
              },
            ]}
          />
        </>
      )}

      {!content.penalties?.length && !content.abnormal_records?.length && (
        <div style={{ textAlign: 'center', color: '#bfbfbf', padding: '24px 0' }}>
          暂无税务异常记录
        </div>
      )}
    </div>
  );
}
