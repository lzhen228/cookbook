import { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  Card,
  Descriptions,
  Tabs,
  Tag,
  Table,
  Statistic,
  Row,
  Col,
  Button,
  Spin,
  Alert,
  Space,
  Skeleton,
} from 'antd';
import { ArrowLeftOutlined, DownloadOutlined } from '@ant-design/icons';
import { HealthBadge } from '@/components/HealthBadge';
import { RiskDimensionTag } from '@/components/RiskDimensionTag';
import { useSupplierProfile, useSupplierTab, useReportDownloadUrl } from '@/hooks/useSupplierProfile';
import { formatScore, formatDateTime, formatDate } from '@/utils/formatters';
import { COOPERATION_STATUS_CONFIG, RISK_EVENT_STATUS_CONFIG } from '@/constants/healthLevel';
import type { TabName, RiskEventBrief, RiskDimension } from '@/types/supplier.types';

const TAB_ITEMS: { key: TabName; label: string }[] = [
  { key: 'basic-info', label: '基本信息' },
  { key: 'business-info', label: '经营信息' },
  { key: 'judicial', label: '司法诉讼' },
  { key: 'credit', label: '信用数据' },
  { key: 'tax', label: '税务信息' },
];

/** 供应商画像详情页 */
export function SupplierProfile() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const supplierId = Number(id);

  const { data: profile, isLoading, error } = useSupplierProfile(supplierId);
  const [activeTab, setActiveTab] = useState<TabName>('basic-info');

  if (isLoading) {
    return <Skeleton active paragraph={{ rows: 10 }} />;
  }

  if (error || !profile) {
    return <Alert type="error" message="加载供应商画像失败" showIcon />;
  }

  const { basic, health, risk_events, risk_events_total } = profile;

  return (
    <Space direction="vertical" size="middle" style={{ width: '100%' }}>
      <Button type="link" icon={<ArrowLeftOutlined />} onClick={() => navigate('/suppliers')}>
        返回列表
      </Button>

      {/* 基础信息卡片 */}
      <Card title={basic.name}>
        <Descriptions column={3} bordered size="small">
          <Descriptions.Item label="统一信用代码">{basic.unified_code}</Descriptions.Item>
          <Descriptions.Item label="合作状态">
            {COOPERATION_STATUS_CONFIG[basic.cooperation_status]?.label || basic.cooperation_status}
          </Descriptions.Item>
          <Descriptions.Item label="地区">{basic.region}</Descriptions.Item>
          <Descriptions.Item label="上市状态">
            {basic.listed_status === 'listed' ? '上市' : '非上市'}
          </Descriptions.Item>
          <Descriptions.Item label="供应商类型">{basic.supplier_type || '-'}</Descriptions.Item>
          <Descriptions.Item label="企业性质">{basic.nature || '-'}</Descriptions.Item>
          <Descriptions.Item label="供应物" span={3}>
            {basic.supply_items?.map((item) => (
              <Tag key={item}>{item}</Tag>
            )) || '-'}
          </Descriptions.Item>
        </Descriptions>
      </Card>

      {/* 健康评分卡 */}
      <Card title="健康评分">
        <Row gutter={24}>
          <Col span={4}>
            <Statistic
              title="综合健康分"
              value={formatScore(health.score)}
              valueStyle={{ color: health.level === 'high_risk' ? '#f5222d' : undefined }}
            />
          </Col>
          <Col span={4}>
            <div style={{ marginBottom: 8, color: 'rgba(0,0,0,0.45)', fontSize: 14 }}>
              健康等级
            </div>
            <HealthBadge level={health.level} />
          </Col>
          <Col span={4}>
            <Statistic title="评分日期" value={formatDate(health.snapshot_date)} />
          </Col>
          {health.dimension_scores &&
            Object.entries(health.dimension_scores).map(([dim, score]) => (
              <Col span={3} key={dim}>
                <Statistic title={dim} value={formatScore(score)} suffix="分" />
              </Col>
            ))}
          <Col span={4}>
            <ReportDownloadButton supplierId={supplierId} reportStatus={health.report_status} />
          </Col>
        </Row>
      </Card>

      {/* 风险事项卡片 */}
      <Card title={`风险事项（共 ${risk_events_total} 条）`}>
        <Table<RiskEventBrief>
          rowKey="id"
          dataSource={risk_events}
          pagination={false}
          size="small"
          columns={[
            {
              title: '风险维度',
              dataIndex: 'risk_dimension',
              width: 100,
              render: (dim: RiskDimension) => <RiskDimensionTag dimension={dim} />,
            },
            { title: '描述', dataIndex: 'description' },
            {
              title: '状态',
              dataIndex: 'status',
              width: 80,
              render: (status: string) => {
                const cfg = RISK_EVENT_STATUS_CONFIG[status as keyof typeof RISK_EVENT_STATUS_CONFIG];
                return cfg ? <Tag color={cfg.color}>{cfg.label}</Tag> : status;
              },
            },
            {
              title: '触发时间',
              dataIndex: 'triggered_at',
              width: 160,
              render: formatDateTime,
            },
            {
              title: '来源',
              dataIndex: 'source_url',
              width: 80,
              render: (url: string | null) =>
                url ? (
                  <a href={url} target="_blank" rel="noopener noreferrer">
                    查看
                  </a>
                ) : (
                  '-'
                ),
            },
          ]}
        />
      </Card>

      {/* Tab 懒加载区域 */}
      <Card>
        <Tabs
          activeKey={activeTab}
          onChange={(key) => setActiveTab(key as TabName)}
          items={TAB_ITEMS.map((tab) => ({
            key: tab.key,
            label: tab.label,
            children: <TabContent supplierId={supplierId} tabName={tab.key} active={activeTab === tab.key} />,
          }))}
        />
      </Card>
    </Space>
  );
}

/** Tab 内容组件（懒加载） */
function TabContent({
  supplierId,
  tabName,
  active,
}: {
  supplierId: number;
  tabName: TabName;
  active: boolean;
}) {
  const { data, isLoading, error } = useSupplierTab(supplierId, tabName, active);

  if (!active) return null;
  if (isLoading) return <Spin />;
  if (error) return <Alert type="error" message="加载失败" showIcon />;
  if (!data) return null;

  return (
    <div>
      {data.is_stale && (
        <Alert
          type="warning"
          message={`数据来源时间：${formatDateTime(data.data_as_of)}（当日拉取失败，展示历史数据）`}
          style={{ marginBottom: 16 }}
          showIcon
        />
      )}
      <pre style={{ background: '#fafafa', padding: 16, borderRadius: 4, overflow: 'auto' }}>
        {JSON.stringify(data.content, null, 2)}
      </pre>
    </div>
  );
}

/** 报告下载按钮 */
function ReportDownloadButton({
  supplierId,
  reportStatus,
}: {
  supplierId: number;
  reportStatus: string;
}) {
  const { refetch } = useReportDownloadUrl(
    supplierId,
    false,
  );

  const handleDownload = async () => {
    const result = await refetch();
    if (result.data?.url) {
      window.open(result.data.url, '_blank');
    }
  };

  if (reportStatus !== 'ready') {
    return (
      <Statistic
        title="报告状态"
        value={reportStatus === 'generating' ? '生成中...' : '未生成'}
      />
    );
  }

  return (
    <div>
      <div style={{ marginBottom: 8, color: 'rgba(0,0,0,0.45)', fontSize: 14 }}>健康报告</div>
      <Button type="primary" icon={<DownloadOutlined />} onClick={handleDownload}>
        下载报告
      </Button>
    </div>
  );
}
