-- V2__seed_dev_data.sql
-- 开发环境测试数据，供应商 + 指标 + 预警方案 + 评分快照 + 风险事项

-- ========== 指标库（5 个维度各 1-2 个指标）==========
INSERT INTO indicator (name, description, risk_dimension, formula, data_source, is_active) VALUES
('司法被执行次数', '近 3 年被列为被执行人的记录数量', 'legal', 'COUNT(judicial_execution WHERE date > NOW()-3yr)', 'tianyancha', TRUE),
('涉诉案件金额', '近 3 年涉诉案件总金额', 'legal', 'SUM(litigation_amount WHERE date > NOW()-3yr)', 'tianyancha', TRUE),
('资产负债率', '最近一期财报资产负债率', 'finance', 'total_liabilities / total_assets', 'erp', TRUE),
('信用评级变动', '近 12 个月信用评级下调次数', 'credit', 'COUNT(rating_downgrade WHERE date > NOW()-1yr)', 'pboc', TRUE),
('税务异常次数', '近 2 年税务处罚或异常记录', 'tax', 'COUNT(tax_abnormal WHERE date > NOW()-2yr)', 'tax_bureau', TRUE),
('经营异常列入次数', '近 3 年被列入经营异常名录次数', 'operation', 'COUNT(abnormal_listing WHERE date > NOW()-3yr)', 'qcc', TRUE);

-- ========== 预警方案 ==========
INSERT INTO alert_plan (name, description, scope_config, level_thresholds, is_active, created_by) VALUES
('标准风险方案', '适用于常规合作供应商', '{"cooperation_status":["cooperating","qualified"]}', '{"high_risk":[0,40],"attention":[40,70],"low_risk":[70,100]}', TRUE, 1);

-- ========== 方案指标权重 ==========
INSERT INTO alert_plan_indicator (plan_id, indicator_id, weight, is_redline) VALUES
(1, 1, 0.20, TRUE),
(1, 2, 0.15, FALSE),
(1, 3, 0.20, FALSE),
(1, 4, 0.15, FALSE),
(1, 5, 0.15, FALSE),
(1, 6, 0.15, FALSE);

-- ========== 供应商（10 条测试数据）==========
INSERT INTO supplier (name, unified_code, cooperation_status, region_province, region_city, listed_status, is_china_top500, is_world_top500, supplier_type, nature, supply_items, is_followed, health_score_cache, health_level_cache, week_trend_cache, cache_updated_at) VALUES
('深圳芯科半导体有限公司', '91440300TEST00001', 'cooperating', '广东省', '深圳市', 'listed', FALSE, FALSE, 'supplier', 'private', '["半导体","芯片"]', TRUE, 32.5, 'high_risk', -3.2, NOW()),
('上海精工机械股份有限公司', '91310000TEST00002', 'cooperating', '上海市', '浦东新区', 'listed', TRUE, FALSE, 'supplier', 'state', '["精密机械","轴承"]', FALSE, 45.0, 'attention', 1.5, NOW()),
('北京智驱科技有限公司', '91110000TEST00003', 'cooperating', '北京市', '海淀区', 'unlisted', FALSE, FALSE, 'supplier', 'private', '["座舱域控","智能驾驶"]', FALSE, 78.5, 'low_risk', 2.1, NOW()),
('杭州云联网络技术有限公司', '91330100TEST00004', 'qualified', '浙江省', '杭州市', 'unlisted', FALSE, FALSE, 'supplier', 'private', '["网络设备","交换机"]', FALSE, 65.0, 'attention', -1.0, NOW()),
('广州恒力电子有限公司', '91440100TEST00005', 'cooperating', '广东省', '广州市', 'unlisted', FALSE, FALSE, 'distributor', 'private', '["电子元器件","电容"]', TRUE, 85.0, 'low_risk', 0.5, NOW()),
('成都天成新材料有限公司', '91510100TEST00006', 'potential', '四川省', '成都市', 'unlisted', FALSE, FALSE, 'supplier', 'joint', '["新材料","碳纤维"]', FALSE, 55.0, 'attention', -2.5, NOW()),
('南京鼎盛化工股份有限公司', '91320100TEST00007', 'cooperating', '江苏省', '南京市', 'listed', TRUE, TRUE, 'supplier', 'state', '["化工原料","树脂"]', FALSE, 72.0, 'low_risk', 0.0, NOW()),
('武汉光谷激光设备有限公司', '91420100TEST00008', 'cooperating', '湖北省', '武汉市', 'unlisted', FALSE, FALSE, 'supplier', 'private', '["激光设备","焊接机"]', FALSE, 28.0, 'high_risk', -5.0, NOW()),
('重庆汇通汽车零部件有限公司', '91500000TEST00009', 'restricted', '重庆市', '渝北区', 'unlisted', FALSE, FALSE, 'supplier', 'foreign', '["汽车零部件","刹车片"]', FALSE, 15.0, 'high_risk', -8.0, NOW()),
('苏州纳微电子有限公司', '91320500TEST00010', 'cooperating', '江苏省', '苏州市', 'listed', FALSE, FALSE, 'supplier', 'private', '["半导体","封装测试"]', TRUE, 90.5, 'low_risk', 3.0, NOW());

-- ========== 健康评分快照（当日）==========
INSERT INTO supplier_health_snapshot (supplier_id, plan_id, health_score, health_level, dimension_scores, snapshot_date) VALUES
(1, 1, 32.5, 'high_risk', '{"legal":10.0,"finance":45.0,"credit":60.0,"tax":80.0,"operation":30.0}', CURRENT_DATE),
(2, 1, 45.0, 'attention', '{"legal":50.0,"finance":35.0,"credit":55.0,"tax":40.0,"operation":60.0}', CURRENT_DATE),
(3, 1, 78.5, 'low_risk', '{"legal":85.0,"finance":70.0,"credit":80.0,"tax":75.0,"operation":82.0}', CURRENT_DATE),
(4, 1, 65.0, 'attention', '{"legal":70.0,"finance":55.0,"credit":60.0,"tax":68.0,"operation":72.0}', CURRENT_DATE),
(5, 1, 85.0, 'low_risk', '{"legal":90.0,"finance":80.0,"credit":85.0,"tax":82.0,"operation":88.0}', CURRENT_DATE),
(6, 1, 55.0, 'attention', '{"legal":60.0,"finance":48.0,"credit":55.0,"tax":58.0,"operation":54.0}', CURRENT_DATE),
(7, 1, 72.0, 'low_risk', '{"legal":75.0,"finance":68.0,"credit":70.0,"tax":78.0,"operation":69.0}', CURRENT_DATE),
(8, 1, 28.0, 'high_risk', '{"legal":5.0,"finance":30.0,"credit":40.0,"tax":50.0,"operation":15.0}', CURRENT_DATE),
(9, 1, 15.0, 'high_risk', '{"legal":0.0,"finance":20.0,"credit":25.0,"tax":30.0,"operation":0.0}', CURRENT_DATE),
(10, 1, 90.5, 'low_risk', '{"legal":95.0,"finance":88.0,"credit":92.0,"tax":85.0,"operation":93.0}', CURRENT_DATE);

-- ========== 风险事项 ==========
INSERT INTO risk_event (supplier_id, indicator_id, risk_dimension, description, source_url, status, triggered_at) VALUES
(1, 1, 'legal', '存在未结清执行案件，涉案金额 300 万', 'https://wenshu.court.gov.cn/example1', 'open', NOW() - INTERVAL '1 day'),
(1, 2, 'legal', '近期新增民事诉讼 2 起，涉案金额 150 万', 'https://wenshu.court.gov.cn/example2', 'confirmed', NOW() - INTERVAL '3 days'),
(1, 6, 'operation', '被列入经营异常名录', NULL, 'open', NOW() - INTERVAL '5 days'),
(2, 3, 'finance', '最近一期资产负债率达 82%，超出阈值', NULL, 'processing', NOW() - INTERVAL '2 days'),
(2, 4, 'credit', '信用评级由 AA 下调至 A', NULL, 'open', NOW() - INTERVAL '1 day'),
(8, 1, 'legal', '存在 5 起未结清执行案件，涉案金额 1200 万', 'https://wenshu.court.gov.cn/example3', 'open', NOW() - INTERVAL '1 day'),
(8, 6, 'operation', '营业执照已被吊销', NULL, 'confirmed', NOW() - INTERVAL '7 days'),
(9, 1, 'legal', '法定代表人被限制高消费', NULL, 'open', NOW()),
(9, 5, 'tax', '欠缴税款 200 万，已进入强制执行', NULL, 'open', NOW()),
(9, 6, 'operation', '连续 2 年被列入经营异常名录', NULL, 'dismissed', NOW() - INTERVAL '30 days');

-- ========== 审计日志示例 ==========
INSERT INTO audit_log (operator_id, operator_name, action, target_type, target_id, diff) VALUES
(1, '系统管理员', 'CREATE_PLAN', 'alert_plan', 1, '{"after":{"name":"标准风险方案","is_active":true}}'),
(1, '系统管理员', 'ACTIVATE_PLAN', 'alert_plan', 1, '{"before":{"is_active":false},"after":{"is_active":true}}');
