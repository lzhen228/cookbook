import { Layout, Menu } from 'antd';
import {
  DashboardOutlined,
  TeamOutlined,
  AlertOutlined,
  // SettingOutlined,
} from '@ant-design/icons';
import { useNavigate, useLocation, Outlet } from 'react-router-dom';
import type { ReactNode } from 'react';

const { Header, Sider, Content } = Layout;

interface PageLayoutProps {
  children?: ReactNode;
}

const menuItems = [
  { key: '/dashboard', icon: <DashboardOutlined />, label: '风险看板' },
  { key: '/suppliers', icon: <TeamOutlined />, label: '供应商管理' },
  { key: '/risk-events', icon: <AlertOutlined />, label: '预警中心' },
  // { key: '/settings', icon: <SettingOutlined />, label: '预警配置' },
];

/** 页面整体布局组件 */
export function PageLayout({ children }: PageLayoutProps) {
  const navigate = useNavigate();
  const location = useLocation();

  const selectedKey = menuItems.find((item) => location.pathname.startsWith(item.key))?.key || '';

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider theme="light" width={200}>
        <div style={{ height: 64, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <h2 style={{ margin: 0, fontSize: 16 }}>SCRM</h2>
        </div>
        <Menu
          mode="inline"
          selectedKeys={[selectedKey]}
          items={menuItems}
          onClick={({ key }) => navigate(key)}
        />
      </Sider>
      <Layout>
        <Header
          style={{
            background: '#fff',
            padding: '0 24px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'flex-end',
            borderBottom: '1px solid #f0f0f0',
          }}
        >
          <span>供应链风险管理平台</span>
        </Header>
        <Content style={{ margin: 24 }}>{children || <Outlet />}</Content>
      </Layout>
    </Layout>
  );
}
