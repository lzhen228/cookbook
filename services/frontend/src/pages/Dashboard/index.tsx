import { Card, Row, Col, Statistic, Table, Tag, List, Flex, Typography, Button, Spin, Alert } from 'antd';
import {
  WarningOutlined,
  ExclamationCircleOutlined,
  CheckCircleOutlined,
  ReloadOutlined,
  ArrowUpOutlined,
  ArrowDownOutlined,
  MinusOutlined,
} from '@ant-design/icons';
import ReactECharts from 'echarts-for-react';
import { useNavigate } from 'react-router-dom';
import dayjs from 'dayjs';
import { useDashboard } from '@/hooks/useDashboard';
import { HEALTH_LEVEL_CONFIG, RISK_DIMENSION_CONFIG, RISK_EVENT_STATUS_CONFIG } from '@/constants/healthLevel';
import type { TopRiskSupplier, DashboardRiskEvent } from '@/types/dashboard.types';
import type { ColumnsType } from 'antd/es/table';

const { Text, Title } = Typography;

export function Dashboard() {
  const navigate = useNavigate();
  const { data, isLoading, isError, refetch, isFetching } = useDashboard();

  if (isLoading) {
    return (
      <Flex justify="center" align="center" style={{ minHeight: 400 }}>
        <Spin size="large" />
      </Flex>
    );
  }

  if (isError || !data) {
    return (
      <Alert
        type="error"
        message="看板数据加载失败"
        description="请稍后重试或联系管理员"
        showIcon
      />
    );
  }

  const { stats, health_distribution, risk_dimension_stats, risk_trend, top_risk_suppliers, recent_events } = data;

  // ==================== ECharts 配置 ====================

  const healthPieOption = {
    tooltip: { trigger: 'item', formatter: '{b}: {c} 家 ({d}%)' },
    legend: { orient: 'vertical', right: 10, top: 'center', itemGap: 12 },
    series: [
      {
        type: 'pie',
        radius: ['45%', '70%'],
        center: ['38%', '50%'],
        avoidLabelOverlap: false,
        label: { show: false },
        emphasis: { label: { show: true, fontSize: 14, fontWeight: 'bold' } },
        data: health_distribution.map((item) => {
          const colorMap: Record<string, string> = {
            high_risk: '#f5222d',
            attention: '#fa8c16',
            low_risk: '#52c41a',
            unscored: '#bfbfbf',
          };
          const labelMap: Record<string, string> = {
            high_risk: '高风险',
            attention: '需关注',
            low_risk: '低风险',
            unscored: '未评分',
          };
          return {
            name: labelMap[item.level] ?? item.level,
            value: item.count,
            itemStyle: { color: colorMap[item.level] ?? '#bfbfbf' },
          };
        }),
      },
    ],
  };

  const trendOption = {
    tooltip: { trigger: 'axis' },
    legend: { top: 0, data: ['高风险供应商', '新增风险事项'] },
    grid: { top: 36, left: 40, right: 16, bottom: 40, containLabel: true },
    xAxis: {
      type: 'category',
      data: risk_trend.map((p) => p.date),
      axisLabel: { rotate: 30, fontSize: 11 },
    },
    yAxis: [
      { type: 'value', name: '供应商数', minInterval: 1 },
      { type: 'value', name: '事项数', minInterval: 1 },
    ],
    series: [
      {
        name: '高风险供应商',
        type: 'line',
        yAxisIndex: 0,
        smooth: true,
        symbol: 'circle',
        symbolSize: 6,
        lineStyle: { color: '#f5222d', width: 2 },
        itemStyle: { color: '#f5222d' },
        areaStyle: { color: 'rgba(245,34,45,0.08)' },
        data: risk_trend.map((p) => p.high_risk_count),
      },
      {
        name: '新增风险事项',
        type: 'bar',
        yAxisIndex: 1,
        barMaxWidth: 20,
        itemStyle: { color: '#fa8c16', borderRadius: [3, 3, 0, 0] },
        data: risk_trend.map((p) => p.new_events),
      },
    ],
  };

  const dimensionBarOption = {
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    grid: { top: 8, left: 8, right: 24, bottom: 8, containLabel: true },
    xAxis: { type: 'value', minInterval: 1 },
    yAxis: {
      type: 'category',
      data: risk_dimension_stats.map((s) => RISK_DIMENSION_CONFIG[s.dimension]?.label ?? s.dimension),
    },
    series: [
      {
        type: 'bar',
        barMaxWidth: 24,
        data: risk_dimension_stats.map((s) => ({
          value: s.open_count,
          itemStyle: { color: RISK_DIMENSION_CONFIG[s.dimension]?.color ?? '#8c8c8c', borderRadius: [0, 3, 3, 0] },
        })),
        label: { show: true, position: 'right', fontSize: 12 },
      },
    ],
  };

  // ==================== 表格列定义 ====================

  const topRiskColumns: ColumnsType<TopRiskSupplier> = [
    {
      title: '供应商',
      dataIndex: 'name',
      render: (name: string, record) => (
        <a onClick={() => navigate(`/suppliers/${record.id}`)}>{name}</a>
      ),
    },
    {
      title: '健康分',
      dataIndex: 'health_score',
      width: 80,
      render: (score: number | null, record) => (
        <Text style={{ color: HEALTH_LEVEL_CONFIG[record.health_level]?.color, fontWeight: 600 }}>
          {score != null ? score.toFixed(1) : '-'}
        </Text>
      ),
    },
    {
      title: '等级',
      dataIndex: 'health_level',
      width: 80,
      render: (level: string) => {
        const cfg = HEALTH_LEVEL_CONFIG[level as keyof typeof HEALTH_LEVEL_CONFIG];
        return <Tag color={cfg?.color}>{cfg?.label}</Tag>;
      },
    },
    {
      title: '周变化',
      dataIndex: 'week_trend',
      width: 80,
      render: (trend: number | null | undefined) => {
        if (trend == null || trend === 0) return <Text type="secondary"><MinusOutlined /> -</Text>;
        const up = trend > 0;
        return (
          <Text style={{ color: up ? '#52c41a' : '#f5222d' }}>
            {up ? <ArrowUpOutlined /> : <ArrowDownOutlined />} {Math.abs(trend)}
          </Text>
        );
      },
    },
    {
      title: '主要风险',
      dataIndex: 'top_dimension',
      width: 90,
      render: (dim: string) => {
        const cfg = RISK_DIMENSION_CONFIG[dim as keyof typeof RISK_DIMENSION_CONFIG];
        return <Tag color={cfg?.color}>{cfg?.label}</Tag>;
      },
    },
    {
      title: '待处理',
      dataIndex: 'open_events',
      width: 70,
      render: (count: number) => (
        <Tag color={count > 0 ? 'error' : 'default'}>{count}</Tag>
      ),
    },
    {
      title: '地区',
      dataIndex: 'region',
      width: 120,
    },
  ];

  return (
    <div style={{ padding: '0 4px' }}>
      {/* 页头 */}
      <Flex justify="space-between" align="center" style={{ marginBottom: 20 }}>
        <Title level={4} style={{ margin: 0 }}>风险看板</Title>
        <Flex align="center" gap={12}>
          <Text type="secondary" style={{ fontSize: 13 }}>
            数据更新：{dayjs().format('YYYY-MM-DD HH:mm')}
          </Text>
          <Button
            icon={<ReloadOutlined spin={isFetching} />}
            onClick={() => void refetch()}
            size="small"
          >
            刷新
          </Button>
        </Flex>
      </Flex>

      {/* Row 1: 统计卡片 */}
      <Row gutter={[16, 16]} style={{ marginBottom: 16 }}>
        <Col span={4}>
          <Card size="small" style={{ textAlign: 'center' }}>
            <Statistic
              title="总供应商"
              value={stats.total_suppliers}
              suffix={<Text type="secondary" style={{ fontSize: 12 }}>家</Text>}
            />
            <Text type="secondary" style={{ fontSize: 12 }}>合作中 {stats.cooperating_count}</Text>
          </Card>
        </Col>
        <Col span={4}>
          <Card size="small" style={{ textAlign: 'center', borderColor: '#ffccc7' }}>
            <Statistic
              title={<Text style={{ color: '#f5222d' }}><WarningOutlined /> 高风险</Text>}
              value={stats.high_risk_count}
              valueStyle={{ color: '#f5222d' }}
              suffix={<Text type="secondary" style={{ fontSize: 12 }}>家</Text>}
            />
          </Card>
        </Col>
        <Col span={4}>
          <Card size="small" style={{ textAlign: 'center', borderColor: '#ffe7ba' }}>
            <Statistic
              title={<Text style={{ color: '#fa8c16' }}><ExclamationCircleOutlined /> 需关注</Text>}
              value={stats.attention_count}
              valueStyle={{ color: '#fa8c16' }}
              suffix={<Text type="secondary" style={{ fontSize: 12 }}>家</Text>}
            />
          </Card>
        </Col>
        <Col span={4}>
          <Card size="small" style={{ textAlign: 'center' }}>
            <Statistic
              title={<Text style={{ color: '#52c41a' }}><CheckCircleOutlined /> 低风险</Text>}
              value={stats.low_risk_count}
              valueStyle={{ color: '#52c41a' }}
              suffix={<Text type="secondary" style={{ fontSize: 12 }}>家</Text>}
            />
          </Card>
        </Col>
        <Col span={4}>
          <Card size="small" style={{ textAlign: 'center', borderColor: '#ffccc7' }}>
            <Statistic
              title="待处理风险事项"
              value={stats.pending_risk_events}
              valueStyle={{ color: '#f5222d' }}
              suffix={<Text type="secondary" style={{ fontSize: 12 }}>条</Text>}
            />
          </Card>
        </Col>
        <Col span={4}>
          <Card size="small" style={{ textAlign: 'center' }}>
            <Statistic
              title="本周新增事项"
              value={stats.new_events_7d}
              suffix={<Text type="secondary" style={{ fontSize: 12 }}>条</Text>}
            />
          </Card>
        </Col>
      </Row>

      {/* Row 2: 健康分布 + 趋势图 */}
      <Row gutter={[16, 16]} style={{ marginBottom: 16 }}>
        <Col span={8}>
          <Card title="健康等级分布" size="small" style={{ height: 280 }}>
            <ReactECharts
              option={healthPieOption}
              style={{ height: 220 }}
              notMerge
            />
          </Card>
        </Col>
        <Col span={10}>
          <Card title="风险趋势（近 14 天）" size="small" style={{ height: 280 }}>
            <ReactECharts
              option={trendOption}
              style={{ height: 220 }}
              notMerge
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card title="待处理风险维度分布" size="small" style={{ height: 280 }}>
            <ReactECharts
              option={dimensionBarOption}
              style={{ height: 220 }}
              notMerge
            />
          </Card>
        </Col>
      </Row>

      {/* Row 3: 高风险供应商表 + 最新风险事项 */}
      <Row gutter={[16, 16]}>
        <Col span={15}>
          <Card title="高风险供应商 TOP5" size="small">
            <Table<TopRiskSupplier>
              dataSource={top_risk_suppliers}
              columns={topRiskColumns}
              rowKey="id"
              size="small"
              pagination={false}
              onRow={(record) => ({ style: { cursor: 'pointer' }, onClick: () => navigate(`/suppliers/${record.id}`) })}
            />
          </Card>
        </Col>
        <Col span={9}>
          <Card title="最新风险事项" size="small">
            <List<DashboardRiskEvent>
              dataSource={recent_events.slice(0, 6)}
              size="small"
              renderItem={(event) => {
                const dimCfg = RISK_DIMENSION_CONFIG[event.risk_dimension];
                const statusCfg = RISK_EVENT_STATUS_CONFIG[event.status];
                return (
                  <List.Item style={{ padding: '8px 0', alignItems: 'flex-start' }}>
                    <Flex vertical gap={4} style={{ width: '100%' }}>
                      <Flex justify="space-between" align="center">
                        <a onClick={() => navigate(`/suppliers/${event.supplier_id}`)}>
                          <Text strong style={{ fontSize: 13 }}>{event.supplier_name}</Text>
                        </a>
                        <Flex gap={4}>
                          <Tag color={dimCfg?.color} style={{ margin: 0, fontSize: 11 }}>{dimCfg?.label}</Tag>
                          <Tag color={statusCfg?.color} style={{ margin: 0, fontSize: 11 }}>{statusCfg?.label}</Tag>
                        </Flex>
                      </Flex>
                      <Flex justify="space-between" align="center">
                        <Text type="secondary" style={{ fontSize: 12 }} ellipsis={{ tooltip: event.description }}>
                          {event.description}
                        </Text>
                        <Text type="secondary" style={{ fontSize: 11, whiteSpace: 'nowrap', marginLeft: 8 }}>
                          {event.triggered_at ? dayjs(event.triggered_at).format('MM-DD') : '-'}
                        </Text>
                      </Flex>
                    </Flex>
                  </List.Item>
                );
              }}
            />
          </Card>
        </Col>
      </Row>
    </div>
  );
}
