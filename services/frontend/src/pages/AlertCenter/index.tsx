import { useState } from 'react';
import {
  Card,
  Table,
  Tag,
  Input,
  Select,
  Button,
  Flex,
  Typography,
  Space,
  Popconfirm,
  Badge,
  Tabs,
  Tooltip,
} from 'antd';
import {
  ExportOutlined,
  LinkOutlined,
} from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
import 'dayjs/locale/zh-cn';
import { useRiskAlerts, useUpdateAlertStatus } from '@/hooks/useAlertCenter';
import { RISK_DIMENSION_CONFIG, RISK_EVENT_STATUS_CONFIG } from '@/constants/healthLevel';
import type { RiskAlert, RiskAlertQuery } from '@/types/alertCenter.types';
import type { RiskEventStatus, RiskDimension } from '@/types/supplier.types';
import type { ColumnsType } from 'antd/es/table';

dayjs.extend(relativeTime);
dayjs.locale('zh-cn');

const { Title, Text } = Typography;

const STATUS_COLORS: Record<string, string> = {
  open: '#f5222d',
  confirmed: '#fa8c16',
  processing: '#1890ff',
  closed: '#52c41a',
  dismissed: '#bfbfbf',
};

export function AlertCenter() {
  const navigate = useNavigate();
  const [activeStatus, setActiveStatus] = useState<RiskEventStatus | 'all'>('all');
  const [query, setQuery] = useState<RiskAlertQuery>({ page: 1, page_size: 20 });

  const { data, isLoading } = useRiskAlerts({
    ...query,
    status: activeStatus === 'all' ? undefined : activeStatus,
  });
  const updateStatus = useUpdateAlertStatus();

  const stats = data?.stats;

  function handleStatusTabChange(key: string) {
    setActiveStatus(key as RiskEventStatus | 'all');
    setQuery((q) => ({ ...q, page: 1 }));
  }

  function handleAction(alertId: number, newStatus: RiskEventStatus) {
    updateStatus.mutate({ alertId, status: newStatus });
  }

  function renderActions(record: RiskAlert) {
    switch (record.status) {
      case 'open':
        return (
          <Space size={4}>
            <Button
              size="small"
              type="primary"
              onClick={() => handleAction(record.id, 'confirmed')}
            >
              确认
            </Button>
            <Popconfirm
              title="确定忽略此预警？"
              description="忽略后该预警将不再出现在待处理列表中"
              onConfirm={() => handleAction(record.id, 'dismissed')}
              okText="确定忽略"
              cancelText="取消"
            >
              <Button size="small">忽略</Button>
            </Popconfirm>
          </Space>
        );
      case 'confirmed':
        return (
          <Space size={4}>
            <Button
              size="small"
              type="primary"
              onClick={() => handleAction(record.id, 'processing')}
            >
              开始处理
            </Button>
            <Popconfirm
              title="确定忽略此预警？"
              onConfirm={() => handleAction(record.id, 'dismissed')}
              okText="确定"
              cancelText="取消"
            >
              <Button size="small">忽略</Button>
            </Popconfirm>
          </Space>
        );
      case 'processing':
        return (
          <Button
            size="small"
            type="primary"
            ghost
            onClick={() => handleAction(record.id, 'closed')}
          >
            关闭
          </Button>
        );
      default:
        return record.comment ? (
          <Tooltip title={record.comment}>
            <Text type="secondary" style={{ fontSize: 12, cursor: 'pointer' }}>
              查看备注
            </Text>
          </Tooltip>
        ) : (
          <Text type="secondary" style={{ fontSize: 12 }}>-</Text>
        );
    }
  }

  const columns: ColumnsType<RiskAlert> = [
    {
      title: '供应商',
      dataIndex: 'supplier_name',
      width: 180,
      render: (name: string, record) => (
        <a onClick={() => navigate(`/suppliers/${record.supplier_id}`)}>{name}</a>
      ),
    },
    {
      title: '风险维度',
      dataIndex: 'risk_dimension',
      width: 100,
      render: (dim: RiskDimension) => {
        const cfg = RISK_DIMENSION_CONFIG[dim];
        return <Tag color={cfg?.color}>{cfg?.label}</Tag>;
      },
    },
    {
      title: '预警描述',
      dataIndex: 'description',
      ellipsis: { showTitle: false },
      render: (desc: string, record) => (
        <Flex align="center" gap={6}>
          <Tooltip title={desc} placement="topLeft">
            <Text style={{ fontSize: 13 }} ellipsis>{desc}</Text>
          </Tooltip>
          {record.source_url && (
            <a href={record.source_url} target="_blank" rel="noreferrer">
              <LinkOutlined style={{ fontSize: 12, color: '#8c8c8c' }} />
            </a>
          )}
        </Flex>
      ),
    },
    {
      title: '触发时间',
      dataIndex: 'triggered_at',
      width: 130,
      sorter: (a, b) => dayjs(a.triggered_at).unix() - dayjs(b.triggered_at).unix(),
      defaultSortOrder: 'descend',
      render: (t: string) => (
        <Flex vertical gap={2}>
          <Text style={{ fontSize: 12 }}>{dayjs(t).format('MM-DD HH:mm')}</Text>
          <Text type="secondary" style={{ fontSize: 11 }}>{dayjs(t).fromNow()}</Text>
        </Flex>
      ),
    },
    {
      title: '状态',
      dataIndex: 'status',
      width: 90,
      render: (s: RiskEventStatus) => {
        const cfg = RISK_EVENT_STATUS_CONFIG[s];
        return <Tag color={cfg?.color}>{cfg?.label}</Tag>;
      },
    },
    {
      title: '负责人',
      dataIndex: 'handler',
      width: 80,
      render: (handler: string | null) =>
        handler ? (
          <Text style={{ fontSize: 13 }}>{handler}</Text>
        ) : (
          <Text type="secondary" style={{ fontSize: 12 }}>未分配</Text>
        ),
    },
    {
      title: '操作',
      key: 'actions',
      width: 160,
      fixed: 'right',
      render: (_, record) => renderActions(record),
    },
  ];

  const tabItems = [
    {
      key: 'all',
      label: (
        <Badge count={stats?.total ?? 0} size="small" color="#595959" offset={[8, -2]} overflowCount={99}>
          <span style={{ paddingRight: 4 }}>全部</span>
        </Badge>
      ),
    },
    {
      key: 'open',
      label: (
        <Badge count={stats?.open ?? 0} size="small" color={STATUS_COLORS.open} offset={[8, -2]} overflowCount={99}>
          <span style={{ paddingRight: 4 }}>待处理</span>
        </Badge>
      ),
    },
    {
      key: 'confirmed',
      label: (
        <Badge count={stats?.confirmed ?? 0} size="small" color={STATUS_COLORS.confirmed} offset={[8, -2]} overflowCount={99}>
          <span style={{ paddingRight: 4 }}>已确认</span>
        </Badge>
      ),
    },
    {
      key: 'processing',
      label: (
        <Badge count={stats?.processing ?? 0} size="small" color={STATUS_COLORS.processing} offset={[8, -2]} overflowCount={99}>
          <span style={{ paddingRight: 4 }}>处理中</span>
        </Badge>
      ),
    },
    {
      key: 'closed',
      label: (
        <Badge count={stats?.closed ?? 0} size="small" color={STATUS_COLORS.closed} offset={[8, -2]} overflowCount={99}>
          <span style={{ paddingRight: 4 }}>已关闭</span>
        </Badge>
      ),
    },
    {
      key: 'dismissed',
      label: (
        <Badge count={stats?.dismissed ?? 0} size="small" color={STATUS_COLORS.dismissed} offset={[8, -2]} overflowCount={99}>
          <span style={{ paddingRight: 4 }}>已忽略</span>
        </Badge>
      ),
    },
  ];

  return (
    <div>
      {/* 页头 */}
      <Flex justify="space-between" align="center" style={{ marginBottom: 16 }}>
        <Title level={4} style={{ margin: 0 }}>预警中心</Title>
        <Button icon={<ExportOutlined />} size="small">导出</Button>
      </Flex>

      <Card styles={{ body: { padding: '0 0 16px 0' } }}>
        {/* 状态 Tab + 筛选器 */}
        <Tabs
          activeKey={activeStatus}
          onChange={handleStatusTabChange}
          items={tabItems}
          style={{ padding: '0 16px' }}
          tabBarExtraContent={
            <Space style={{ paddingBottom: 8 }}>
              <Select
                placeholder="风险维度"
                allowClear
                style={{ width: 120 }}
                onChange={(v: RiskDimension | undefined) =>
                  setQuery((q) => ({ ...q, page: 1, risk_dimension: v }))
                }
                options={Object.entries(RISK_DIMENSION_CONFIG).map(([key, cfg]) => ({
                  value: key,
                  label: cfg.label,
                }))}
              />
              <Input.Search
                placeholder="搜索供应商名称"
                allowClear
                style={{ width: 200 }}
                onSearch={(v) => setQuery((q) => ({ ...q, page: 1, keyword: v || undefined }))}
              />
            </Space>
          }
        />

        {/* 表格 */}
        <div style={{ padding: '0 16px' }}>
          <Table<RiskAlert>
            dataSource={data?.items ?? []}
            columns={columns}
            rowKey="id"
            size="small"
            loading={isLoading}
            scroll={{ x: 900 }}
            pagination={{
              current: query.page,
              pageSize: query.page_size,
              total: data?.total,
              showSizeChanger: true,
              pageSizeOptions: ['20', '50', '100'],
              showTotal: (total) => `共 ${total} 条预警`,
              onChange: (page, pageSize) =>
                setQuery((q) => ({ ...q, page, page_size: pageSize })),
            }}
            rowClassName={(record) =>
              record.status === 'open' ? 'alert-row--open' : ''
            }
          />
        </div>
      </Card>

      <style>{`
        .alert-row--open td:first-child {
          border-left: 3px solid #f5222d;
        }
      `}</style>
    </div>
  );
}
