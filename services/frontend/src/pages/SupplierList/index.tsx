import { useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Table, Card, Input, Select, Space, Button, Tooltip, message } from 'antd';
import { StarOutlined, StarFilled, SearchOutlined } from '@ant-design/icons';
import type { ColumnsType, TablePaginationConfig } from 'antd/es/table';
import { HealthBadge } from '@/components/HealthBadge';
import { useSupplierList, useToggleFollow } from '@/hooks/useSupplierList';
import { formatTrend, formatScore, formatRelativeTime } from '@/utils/formatters';
import { HEALTH_LEVEL_CONFIG, COOPERATION_STATUS_CONFIG } from '@/constants/healthLevel';
import type { SupplierListItem, SupplierListQuery, HealthLevel } from '@/types/supplier.types';

const healthLevelOptions = Object.entries(HEALTH_LEVEL_CONFIG).map(([value, config]) => ({
  label: config.label,
  value,
}));

const cooperationStatusOptions = Object.entries(COOPERATION_STATUS_CONFIG).map(
  ([value, config]) => ({
    label: config.label,
    value,
  }),
);

/** 供应商列表页 */
export function SupplierList() {
  const navigate = useNavigate();
  const [query, setQuery] = useState<SupplierListQuery>({
    page: 1,
    page_size: 20,
    sort_by: 'health_score',
    sort_order: 'asc',
  });

  const { data, isLoading } = useSupplierList(query);
  const toggleFollow = useToggleFollow();

  const handleSearch = useCallback((keyword: string) => {
    setQuery((prev) => ({ ...prev, keyword: keyword || undefined, page: 1, cursor: undefined }));
  }, []);

  const handleFilterChange = useCallback((key: keyof SupplierListQuery, value: unknown) => {
    setQuery((prev) => ({
      ...prev,
      [key]: value || undefined,
      page: 1,
      cursor: undefined,
    }));
  }, []);

  const handleTableChange = useCallback(
    (pagination: TablePaginationConfig) => {
      if (data?.next_cursor && pagination.current && pagination.current > (query.page || 1)) {
        setQuery((prev) => ({
          ...prev,
          cursor: data.next_cursor || undefined,
          page: pagination.current,
        }));
      } else {
        setQuery((prev) => ({
          ...prev,
          page: pagination.current || 1,
          page_size: pagination.pageSize || 20,
          cursor: undefined,
        }));
      }
    },
    [data?.next_cursor, query.page],
  );

  const handleFollowToggle = useCallback(
    (supplierId: number, currentFollowed: boolean) => {
      toggleFollow.mutate(
        { supplierId, isFollowed: !currentFollowed },
        { onSuccess: () => message.success(currentFollowed ? '已取消关注' : '已关注') },
      );
    },
    [toggleFollow],
  );

  const columns: ColumnsType<SupplierListItem> = [
    {
      title: '供应商名称',
      dataIndex: 'name',
      key: 'name',
      width: 240,
      render: (name: string, record) => (
        <Button type="link" onClick={() => navigate(`/suppliers/${record.id}`)}>
          {name}
        </Button>
      ),
    },
    {
      title: '健康等级',
      dataIndex: 'health_level',
      key: 'health_level',
      width: 100,
      render: (level: HealthLevel | null) => <HealthBadge level={level} />,
    },
    {
      title: '健康分',
      dataIndex: 'health_score',
      key: 'health_score',
      width: 80,
      sorter: true,
      render: (score: number | null) => formatScore(score),
    },
    {
      title: '周趋势',
      dataIndex: 'week_trend',
      key: 'week_trend',
      width: 80,
      render: (trend: number | null) => {
        const text = formatTrend(trend);
        const color = trend != null ? (trend > 0 ? '#52c41a' : trend < 0 ? '#f5222d' : '') : '';
        return <span style={{ color }}>{text}</span>;
      },
    },
    {
      title: '地区',
      dataIndex: 'region',
      key: 'region',
      width: 140,
    },
    {
      title: '合作状态',
      dataIndex: 'cooperation_status',
      key: 'cooperation_status',
      width: 100,
      render: (status: string) =>
        COOPERATION_STATUS_CONFIG[status as keyof typeof COOPERATION_STATUS_CONFIG]?.label ||
        status,
    },
    {
      title: '数据时效',
      dataIndex: 'cache_updated_at',
      key: 'cache_updated_at',
      width: 120,
      render: (val: string | null) => (
        <Tooltip title={val}>{formatRelativeTime(val)}</Tooltip>
      ),
    },
    {
      title: '操作',
      key: 'actions',
      width: 80,
      render: (_: unknown, record) => (
        <Button
          type="text"
          icon={record.is_followed ? <StarFilled style={{ color: '#faad14' }} /> : <StarOutlined />}
          onClick={() => handleFollowToggle(record.id, record.is_followed)}
        />
      ),
    },
  ];

  return (
    <Card title="供应商列表">
      <Space style={{ marginBottom: 16 }} wrap>
        <Input.Search
          placeholder="搜索供应商名称"
          allowClear
          onSearch={handleSearch}
          style={{ width: 240 }}
          prefix={<SearchOutlined />}
        />
        <Select
          mode="multiple"
          placeholder="健康等级"
          options={healthLevelOptions}
          onChange={(val) => handleFilterChange('health_level', val?.join(','))}
          style={{ minWidth: 160 }}
          allowClear
        />
        <Select
          mode="multiple"
          placeholder="合作状态"
          options={cooperationStatusOptions}
          onChange={(val) => handleFilterChange('cooperation_status', val?.join(','))}
          style={{ minWidth: 160 }}
          allowClear
        />
      </Space>

      <Table<SupplierListItem>
        rowKey="id"
        columns={columns}
        dataSource={data?.items}
        loading={isLoading}
        pagination={{
          current: query.page,
          pageSize: query.page_size,
          total: data?.total,
          showSizeChanger: true,
          showTotal: (total) => `共 ${total} 条`,
          pageSizeOptions: ['20', '50', '100'],
        }}
        onChange={handleTableChange}
        scroll={{ x: 1000 }}
      />
    </Card>
  );
}
