import { Descriptions, Table, Tag } from 'antd';
import type { BusinessInfoContent } from '@/types/supplier.types';

interface BusinessInfoTabProps {
  content: BusinessInfoContent;
}

/** 经营信息 Tab - 主营业务、股东、分支机构 */
export function BusinessInfoTab({ content }: BusinessInfoTabProps) {
  return (
    <div>
      <Descriptions column={2} size="small" bordered style={{ marginBottom: 16 }}>
        <Descriptions.Item label="主营业务" span={2}>
          {content.main_business ?? '-'}
        </Descriptions.Item>
        <Descriptions.Item label="年营收规模">{content.annual_revenue ?? '-'}</Descriptions.Item>
      </Descriptions>

      {(content.shareholders?.length ?? 0) > 0 && (
        <>
          <div style={{ marginBottom: 8, fontWeight: 600, fontSize: 13 }}>股东信息</div>
          <Table
            rowKey="name"
            dataSource={content.shareholders}
            pagination={false}
            size="small"
            style={{ marginBottom: 16 }}
            columns={[
              { title: '股东名称', dataIndex: 'name' },
              { title: '持股比例', dataIndex: 'share_ratio', width: 100 },
              { title: '出资额', dataIndex: 'contribution', width: 120, render: (v) => v ?? '-' },
            ]}
          />
        </>
      )}

      {(content.branches?.length ?? 0) > 0 && (
        <>
          <div style={{ marginBottom: 8, fontWeight: 600, fontSize: 13 }}>分支机构</div>
          <Table
            rowKey="name"
            dataSource={content.branches}
            pagination={false}
            size="small"
            columns={[
              { title: '机构名称', dataIndex: 'name' },
              { title: '地址', dataIndex: 'address' },
              {
                title: '状态',
                dataIndex: 'status',
                width: 80,
                render: (s: string) => (
                  <Tag color={s === '正常' ? 'green' : 'red'}>{s}</Tag>
                ),
              },
            ]}
          />
        </>
      )}
    </div>
  );
}
