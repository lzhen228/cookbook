import { Descriptions } from 'antd';
import type { BasicInfoContent } from '@/types/supplier.types';

interface BasicInfoTabProps {
  content: BasicInfoContent;
}

/** 基本信息 Tab - 展示工商基础登记信息 */
export function BasicInfoTab({ content }: BasicInfoTabProps) {
  return (
    <Descriptions column={2} size="small" bordered>
      <Descriptions.Item label="法定代表人">{content.legal_rep ?? '-'}</Descriptions.Item>
      <Descriptions.Item label="注册资本">{content.reg_capital ?? '-'}</Descriptions.Item>
      <Descriptions.Item label="成立日期">{content.establishment_date ?? '-'}</Descriptions.Item>
      <Descriptions.Item label="员工人数">
        {content.employees_count != null ? `${content.employees_count} 人` : '-'}
      </Descriptions.Item>
      <Descriptions.Item label="联系电话">{content.contact_phone ?? '-'}</Descriptions.Item>
      <Descriptions.Item label="注册地址" span={2}>
        {content.registered_address ?? '-'}
      </Descriptions.Item>
    </Descriptions>
  );
}
