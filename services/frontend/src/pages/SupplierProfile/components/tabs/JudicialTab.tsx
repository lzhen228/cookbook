import { Statistic, Table, Tag, Row, Col } from 'antd';
import type { JudicialContent } from '@/types/supplier.types';

interface JudicialTabProps {
  content: JudicialContent;
}

/** 司法诉讼 Tab - 被执行、诉讼案件 */
export function JudicialTab({ content }: JudicialTabProps) {
  return (
    <div>
      <Row gutter={24} style={{ marginBottom: 16 }}>
        <Col span={8}>
          <Statistic
            title="失信被执行次数"
            value={content.dishonest_count ?? 0}
            valueStyle={{ color: (content.dishonest_count ?? 0) > 0 ? '#f5222d' : '#52c41a' }}
          />
        </Col>
        <Col span={8}>
          <Statistic
            title="被执行记录数"
            value={content.execution_count ?? content.executions?.length ?? 0}
            valueStyle={{
              color:
                (content.execution_count ?? content.executions?.length ?? 0) > 0
                  ? '#fa8c16'
                  : '#52c41a',
            }}
          />
        </Col>
        <Col span={8}>
          <Statistic
            title="涉诉案件数"
            value={content.litigations?.length ?? 0}
            valueStyle={{ color: (content.litigations?.length ?? 0) > 0 ? '#fa8c16' : '#52c41a' }}
          />
        </Col>
      </Row>

      {(content.executions?.length ?? 0) > 0 && (
        <>
          <div style={{ marginBottom: 8, fontWeight: 600, fontSize: 13 }}>被执行记录</div>
          <Table
            rowKey="case_no"
            dataSource={content.executions}
            pagination={false}
            size="small"
            style={{ marginBottom: 16 }}
            columns={[
              { title: '案号', dataIndex: 'case_no', width: 200 },
              { title: '执行法院', dataIndex: 'court' },
              { title: '执行金额', dataIndex: 'amount', width: 120 },
              {
                title: '状态',
                dataIndex: 'status',
                width: 80,
                render: (s: string) => <Tag color={s === '已结清' ? 'green' : 'red'}>{s}</Tag>,
              },
              { title: '立案日期', dataIndex: 'date', width: 120 },
            ]}
          />
        </>
      )}

      {(content.litigations?.length ?? 0) > 0 && (
        <>
          <div style={{ marginBottom: 8, fontWeight: 600, fontSize: 13 }}>涉诉案件</div>
          <Table
            rowKey="title"
            dataSource={content.litigations}
            pagination={false}
            size="small"
            columns={[
              { title: '案由', dataIndex: 'title' },
              { title: '法院', dataIndex: 'court' },
              {
                title: '角色',
                dataIndex: 'role',
                width: 80,
                render: (r: string) => <Tag color={r === '被告' ? 'red' : 'blue'}>{r}</Tag>,
              },
              { title: '涉案金额', dataIndex: 'amount', width: 120, render: (v) => v ?? '-' },
              { title: '状态', dataIndex: 'status', width: 100 },
              { title: '立案日期', dataIndex: 'date', width: 120 },
            ]}
          />
        </>
      )}

      {!content.executions?.length && !content.litigations?.length && (
        <div style={{ textAlign: 'center', color: '#bfbfbf', padding: '24px 0' }}>
          暂无司法诉讼记录
        </div>
      )}
    </div>
  );
}
