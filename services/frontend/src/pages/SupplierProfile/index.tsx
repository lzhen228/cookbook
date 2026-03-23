import { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  Card,
  Row,
  Col,
  Descriptions,
  Tag,
  Button,
  Skeleton,
  Alert,
  Tabs,
  Divider,
  Space,
  Spin,
  Flex,
  message,
  Typography,
  Tooltip,
} from 'antd';
import {
  ArrowLeftOutlined,
  StarOutlined,
  StarFilled,
  DownloadOutlined,
  FileTextOutlined,
} from '@ant-design/icons';
import { HealthBadge } from '@/components/HealthBadge';
import {
  useSupplierProfile,
  useSupplierTab,
  useReportDownloadUrl,
  useProfileFollow,
} from '@/hooks/useSupplierProfile';
import { formatDate, formatDateTime } from '@/utils/formatters';
import {
  COOPERATION_STATUS_CONFIG,
  HEALTH_LEVEL_CONFIG,
  RISK_DIMENSION_CONFIG,
} from '@/constants/healthLevel';
import type {
  TabName,
  BasicInfoContent,
  BusinessInfoContent,
  JudicialContent,
  CreditContent,
  TaxContent,
} from '@/types/supplier.types';
import { HealthScoreGauge } from './components/HealthScoreGauge';
import { DimensionScores } from './components/DimensionScores';
import { RiskEventTable } from './components/RiskEventTable';
import { BasicInfoTab } from './components/tabs/BasicInfoTab';
import { BusinessInfoTab } from './components/tabs/BusinessInfoTab';
import { JudicialTab } from './components/tabs/JudicialTab';
import { CreditTab } from './components/tabs/CreditTab';
import { TaxTab } from './components/tabs/TaxTab';

// suppress unused import warning – used in JSX below
void HEALTH_LEVEL_CONFIG;
void RISK_DIMENSION_CONFIG;

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
  const followMutation = useProfileFollow(supplierId);
  const [activeTab, setActiveTab] = useState<TabName>('basic-info');

  if (isLoading) {
    return (
      <Space direction="vertical" size="middle" style={{ width: '100%' }}>
        <Skeleton.Input active style={{ width: 200 }} />
        <Row gutter={16}>
          <Col span={8}>
            <Skeleton active paragraph={{ rows: 8 }} />
          </Col>
          <Col span={16}>
            <Skeleton active paragraph={{ rows: 12 }} />
          </Col>
        </Row>
      </Space>
    );
  }

  if (error || !profile) {
    return (
      <Alert
        type="error"
        message="加载失败"
        description="供应商画像数据加载失败，请稍后重试"
        showIcon
        action={
          <Button size="small" onClick={() => navigate('/suppliers')}>
            返回列表
          </Button>
        }
      />
    );
  }

  const { basic, health, risk_events, risk_events_total } = profile;

  const cooperationLabel =
    COOPERATION_STATUS_CONFIG[basic.cooperation_status]?.label ?? basic.cooperation_status;

  const handleFollow = () => {
    const next = !basic.is_followed;
    followMutation.mutate(next, {
      onSuccess: () => message.success(next ? '已关注' : '已取消关注'),
    });
  };

  return (
    <Space direction="vertical" size="middle" style={{ width: '100%' }}>
      {/* ── 顶部导航 ── */}
      <Button
        type="link"
        icon={<ArrowLeftOutlined />}
        style={{ paddingLeft: 0 }}
        onClick={() => navigate('/suppliers')}
      >
        返回供应商列表
      </Button>

      {/* ── 公司标题卡 ── */}
      <Card size="small">
        <Flex justify="space-between" align="flex-start" wrap="wrap" gap={12}>
          <div>
            <Flex align="center" gap={10} wrap="wrap">
              <Typography.Title level={4} style={{ margin: 0 }}>
                {basic.name}
              </Typography.Title>
              <HealthBadge level={health.level} />
              <Tag color="blue">{cooperationLabel}</Tag>
              {basic.listed_status === 'listed' && <Tag color="purple">上市企业</Tag>}
              {basic.is_china_top500 && <Tag color="gold">中国 500 强</Tag>}
              {basic.is_world_top500 && <Tag color="volcano">世界 500 强</Tag>}
            </Flex>
            <div style={{ marginTop: 6, color: '#8c8c8c', fontSize: 12 }}>
              统一信用代码：{basic.unified_code}&nbsp;·&nbsp;
              {basic.region || '-'}&nbsp;·&nbsp;
              {basic.supplier_type || '-'}&nbsp;·&nbsp;
              {basic.nature || '-'}
            </div>
          </div>

          <Space>
            <Button
              icon={basic.is_followed ? <StarFilled style={{ color: '#faad14' }} /> : <StarOutlined />}
              onClick={handleFollow}
              loading={followMutation.isPending}
            >
              {basic.is_followed ? '已关注' : '关注'}
            </Button>
            <ReportButton supplierId={supplierId} reportStatus={health.report_status} />
          </Space>
        </Flex>
      </Card>

      {/* ── 主内容区（双栏） ── */}
      <Row gutter={16} align="stretch">
        {/* 左栏：健康评分卡 */}
        <Col xs={24} md={8}>
          <Card
            title="健康评分"
            extra={
              health.snapshot_date && (
                <span style={{ fontSize: 12, color: '#8c8c8c' }}>
                  {formatDate(health.snapshot_date)}
                </span>
              )
            }
            style={{ height: '100%' }}
          >
            <HealthScoreGauge score={health.score} level={health.level} />
            <Divider style={{ margin: '12px 0' }} />
            <div style={{ marginBottom: 6, fontWeight: 600, fontSize: 13 }}>维度评分</div>
            <DimensionScores scores={health.dimension_scores} />
          </Card>
        </Col>

        {/* 右栏：基础信息 + 风险事项 */}
        <Col xs={24} md={16}>
          <Space direction="vertical" size="middle" style={{ width: '100%' }}>
            {/* 基础信息 */}
            <Card title="基础信息" size="small">
              <Descriptions column={2} size="small">
                <Descriptions.Item label="统一信用代码">
                  <Typography.Text copyable>{basic.unified_code}</Typography.Text>
                </Descriptions.Item>
                <Descriptions.Item label="合作状态">
                  <Tag color="blue">{cooperationLabel}</Tag>
                </Descriptions.Item>
                <Descriptions.Item label="注册地区">{basic.region || '-'}</Descriptions.Item>
                <Descriptions.Item label="上市状态">
                  {basic.listed_status === 'listed' ? (
                    <Tag color="purple">上市</Tag>
                  ) : (
                    <Tag>非上市</Tag>
                  )}
                </Descriptions.Item>
                <Descriptions.Item label="供应商类型">
                  {basic.supplier_type || '-'}
                </Descriptions.Item>
                <Descriptions.Item label="企业性质">{basic.nature || '-'}</Descriptions.Item>
                <Descriptions.Item label="供应物品" span={2}>
                  {basic.supply_items?.length ? (
                    <Space size={4} wrap>
                      {basic.supply_items.map((item) => (
                        <Tag key={item}>{item}</Tag>
                      ))}
                    </Space>
                  ) : (
                    '-'
                  )}
                </Descriptions.Item>
              </Descriptions>
            </Card>

            {/* 风险事项 */}
            <Card
              title={
                <span>
                  风险事项
                  {risk_events_total > 0 && (
                    <Tag color="red" style={{ marginLeft: 8 }}>
                      {risk_events_total} 条
                    </Tag>
                  )}
                </span>
              }
              size="small"
            >
              <RiskEventTable events={risk_events} total={risk_events_total} />
            </Card>
          </Space>
        </Col>
      </Row>

      {/* ── 详情 Tab 区 ── */}
      <Card>
        <Tabs
          activeKey={activeTab}
          onChange={(key) => setActiveTab(key as TabName)}
          items={TAB_ITEMS.map((tab) => ({
            key: tab.key,
            label: tab.label,
            children: (
              <TabContent
                supplierId={supplierId}
                tabName={tab.key}
                active={activeTab === tab.key}
              />
            ),
          }))}
        />
      </Card>
    </Space>
  );
}

// ── 报告下载按钮 ────────────────────────────────────────────────────

interface ReportButtonProps {
  supplierId: number;
  reportStatus: string;
}

function ReportButton({ supplierId, reportStatus }: ReportButtonProps) {
  const { refetch, isFetching } = useReportDownloadUrl(supplierId, false);

  const handleDownload = async () => {
    const result = await refetch();
    if (result.data?.url) {
      window.open(result.data.url, '_blank');
    } else {
      message.error('获取报告链接失败，请稍后重试');
    }
  };

  if (reportStatus === 'generating') {
    return (
      <Button icon={<FileTextOutlined />} disabled>
        报告生成中…
      </Button>
    );
  }

  if (reportStatus !== 'ready') {
    return (
      <Tooltip title="报告尚未生成">
        <Button icon={<FileTextOutlined />} disabled>
          下载报告
        </Button>
      </Tooltip>
    );
  }

  return (
    <Button
      type="primary"
      icon={<DownloadOutlined />}
      loading={isFetching}
      onClick={handleDownload}
    >
      下载报告
    </Button>
  );
}

// ── Tab 懒加载内容 ────────────────────────────────────────────────────

interface TabContentProps {
  supplierId: number;
  tabName: TabName;
  active: boolean;
}

function TabContent({ supplierId, tabName, active }: TabContentProps) {
  const { data, isLoading, error } = useSupplierTab(supplierId, tabName, active);

  if (!active) return null;
  if (isLoading) return <Spin style={{ display: 'block', padding: '32px 0' }} />;
  if (error) return <Alert type="error" message="数据加载失败，请稍后重试" showIcon />;
  if (!data) return null;

  const staleWarning = data.is_stale && (
    <Alert
      type="warning"
      message={`数据来源时间：${formatDateTime(data.data_as_of)}（当日拉取失败，展示历史数据）`}
      style={{ marginBottom: 16 }}
      showIcon
    />
  );

  const content = data.content as Record<string, unknown>;

  return (
    <div>
      {staleWarning}
      {tabName === 'basic-info' && (
        <BasicInfoTab content={content as unknown as BasicInfoContent} />
      )}
      {tabName === 'business-info' && (
        <BusinessInfoTab content={content as unknown as BusinessInfoContent} />
      )}
      {tabName === 'judicial' && (
        <JudicialTab content={content as unknown as JudicialContent} />
      )}
      {tabName === 'credit' && <CreditTab content={content as unknown as CreditContent} />}
      {tabName === 'tax' && <TaxTab content={content as unknown as TaxContent} />}
    </div>
  );
}
