-- V4__more_dev_data.sql
-- 补充测试数据：更多供应商、14 天历史快照、各维度风险事项

-- ========== 新增供应商（ID 11-30）==========
INSERT INTO supplier (name, unified_code, cooperation_status, region_province, region_city,
    listed_status, is_china_top500, is_world_top500, supplier_type, nature,
    supply_items, is_followed, health_score_cache, health_level_cache, week_trend_cache, cache_updated_at)
VALUES
('天津海博机电科技有限公司',    '91120000TEST00011', 'cooperating', '天津市',   '滨海新区', 'unlisted', FALSE, FALSE, 'supplier',     'private', '["电机","减速器"]',       FALSE, 38.0, 'high_risk', -4.5, NOW()),
('西安烽火光电技术有限公司',    '91610100TEST00012', 'cooperating', '陕西省',   '西安市',   'listed',   FALSE, FALSE, 'supplier',     'state',   '["光纤","通信模块"]',     FALSE, 67.5, 'attention', -0.5, NOW()),
('深圳迈瑞医疗器械有限公司',    '91440300TEST00013', 'cooperating', '广东省',   '深圳市',   'listed',   TRUE,  TRUE,  'supplier',     'private', '["医疗器械","传感器"]',   TRUE,  92.0, 'low_risk',   2.5, NOW()),
('合肥京东方显示技术有限公司',  '91340100TEST00014', 'cooperating', '安徽省',   '合肥市',   'listed',   TRUE,  TRUE,  'supplier',     'state',   '["显示面板","OLED"]',    FALSE, 88.5, 'low_risk',   1.0, NOW()),
('郑州煤电机械有限公司',        '91410100TEST00015', 'cooperating', '河南省',   '郑州市',   'unlisted', FALSE, FALSE, 'supplier',     'state',   '["采矿设备","液压件"]',   FALSE, 42.0, 'attention', -2.0, NOW()),
('宁波镇海化工有限公司',        '91330200TEST00016', 'restricted',  '浙江省',   '宁波市',   'unlisted', FALSE, FALSE, 'supplier',     'private', '["化工原料","溶剂"]',     FALSE, 22.5, 'high_risk', -6.0, NOW()),
('厦门海沧橡胶制品有限公司',    '91350200TEST00017', 'cooperating', '福建省',   '厦门市',   'unlisted', FALSE, FALSE, 'supplier',     'joint',   '["密封件","橡胶管"]',     FALSE, 74.0, 'low_risk',   0.5, NOW()),
('沈阳铁西重工制造有限公司',    '91210100TEST00018', 'cooperating', '辽宁省',   '沈阳市',   'unlisted', FALSE, FALSE, 'supplier',     'state',   '["铸造件","锻压件"]',     FALSE, 51.5, 'attention', -1.5, NOW()),
('长沙中南智联仪器有限公司',    '91430100TEST00019', 'cooperating', '湖南省',   '长沙市',   'unlisted', FALSE, FALSE, 'supplier',     'private', '["仪表","检测设备"]',     FALSE, 80.0, 'low_risk',   1.5, NOW()),
('昆明滇池能源开发有限公司',    '91530100TEST00020', 'potential',   '云南省',   '昆明市',   'unlisted', FALSE, FALSE, 'distributor',  'state',   '["电力设备","变压器"]',   FALSE, 60.0, 'attention', -0.5, NOW()),
('济南钢铁集团有限公司',        '91370100TEST00021', 'cooperating', '山东省',   '济南市',   'listed',   TRUE,  FALSE, 'supplier',     'state',   '["钢材","型材"]',         FALSE, 58.0, 'attention',  2.0, NOW()),
('青岛海隆船舶配件有限公司',    '91370200TEST00022', 'cooperating', '山东省',   '青岛市',   'unlisted', FALSE, FALSE, 'supplier',     'private', '["船舶配件","螺旋桨"]',   FALSE, 83.5, 'low_risk',   0.0, NOW()),
('贵阳黔南材料科技有限公司',    '91520100TEST00023', 'cooperating', '贵州省',   '贵阳市',   'unlisted', FALSE, FALSE, 'supplier',     'private', '["稀土材料","永磁体"]',   FALSE, 35.5, 'high_risk', -3.0, NOW()),
('太原晋能煤矿设备有限公司',    '91140100TEST00024', 'cooperating', '山西省',   '太原市',   'unlisted', FALSE, FALSE, 'supplier',     'state',   '["矿山设备","破碎机"]',   FALSE, 47.0, 'attention', -1.0, NOW()),
('哈尔滨东安汽车发动机有限公司','91230100TEST00025', 'cooperating', '黑龙江省', '哈尔滨市', 'listed',   TRUE,  FALSE, 'supplier',     'state',   '["发动机","变速箱"]',     FALSE, 70.0, 'low_risk',   0.5, NOW()),
('福州海纳电子有限公司',        '91350100TEST00026', 'qualified',   '福建省',   '福州市',   'unlisted', FALSE, FALSE, 'supplier',     'private', '["PCB","电路板"]',        FALSE, 63.0, 'attention',  1.0, NOW()),
('乌鲁木齐西北能源有限公司',    '91650100TEST00027', 'cooperating', '新疆',     '乌鲁木齐', 'unlisted', FALSE, FALSE, 'distributor',  'state',   '["天然气","管道设备"]',   FALSE, 76.5, 'low_risk',   1.5, NOW()),
('石家庄晶澳太阳能有限公司',    '91130100TEST00028', 'cooperating', '河北省',   '石家庄市', 'listed',   FALSE, FALSE, 'supplier',     'private', '["太阳能电池","组件"]',   TRUE,  89.0, 'low_risk',   2.0, NOW()),
('兰州西固石化设备有限公司',    '91620100TEST00029', 'cooperating', '甘肃省',   '兰州市',   'unlisted', FALSE, FALSE, 'supplier',     'state',   '["石化设备","换热器"]',   FALSE, 53.5, 'attention', -1.5, NOW()),
('南昌洪都航空工业有限公司',    '91360100TEST00030', 'cooperating', '江西省',   '南昌市',   'listed',   TRUE,  FALSE, 'supplier',     'state',   '["航空零件","复合材料"]', FALSE, 81.5, 'low_risk',   1.0, NOW());

-- ========== 14 天历史健康快照（全量供应商）==========
-- 为看板趋势图提供连续数据，健康分在基准上每天随机±小幅波动
INSERT INTO supplier_health_snapshot (supplier_id, plan_id, health_score, health_level, dimension_scores, snapshot_date)
SELECT
    s.id,
    1,
    GREATEST(0, LEAST(100,
        s.health_score_cache + (EXTRACT(EPOCH FROM gs.d)::bigint % 7 - 3) * 0.8
    ))::decimal(5,2),
    CASE
        WHEN GREATEST(0, LEAST(100, s.health_score_cache + (EXTRACT(EPOCH FROM gs.d)::bigint % 7 - 3) * 0.8)) < 40 THEN 'high_risk'
        WHEN GREATEST(0, LEAST(100, s.health_score_cache + (EXTRACT(EPOCH FROM gs.d)::bigint % 7 - 3) * 0.8)) < 70 THEN 'attention'
        ELSE 'low_risk'
    END,
    json_build_object(
        'legal',     GREATEST(0, s.health_score_cache - 5  + (EXTRACT(EPOCH FROM gs.d)::bigint % 5) * 0.6)::decimal(5,2),
        'finance',   GREATEST(0, s.health_score_cache + 5  - (EXTRACT(EPOCH FROM gs.d)::bigint % 4) * 0.7)::decimal(5,2),
        'credit',    GREATEST(0, s.health_score_cache      + (EXTRACT(EPOCH FROM gs.d)::bigint % 6) * 0.5)::decimal(5,2),
        'tax',       GREATEST(0, s.health_score_cache + 3  - (EXTRACT(EPOCH FROM gs.d)::bigint % 3) * 0.4)::decimal(5,2),
        'operation', GREATEST(0, s.health_score_cache - 2  + (EXTRACT(EPOCH FROM gs.d)::bigint % 5) * 0.9)::decimal(5,2)
    ),
    gs.d::date
FROM supplier s
CROSS JOIN generate_series(
    CURRENT_DATE - INTERVAL '13 days',
    CURRENT_DATE - INTERVAL '1 day',   -- 当日快照由 V2 已插入
    INTERVAL '1 day'
) AS gs(d)
WHERE s.id BETWEEN 1 AND 30
ON CONFLICT (supplier_id, snapshot_date) DO NOTHING;

-- ========== 补充风险事项（覆盖各维度，14 天内均匀分布）==========
INSERT INTO risk_event (supplier_id, indicator_id, risk_dimension, description, source_url, status, triggered_at)
VALUES
-- legal 维度
(11, 1, 'legal',     '被列为失信被执行人，限制高消费',                 NULL, 'open',       NOW() - INTERVAL '2 days'),
(16, 1, 'legal',     '存在 3 起未结清民事执行案件，涉案合计 850 万',   'https://wenshu.court.gov.cn/t16', 'confirmed', NOW() - INTERVAL '4 days'),
(23, 2, 'legal',     '近 3 年新增诉讼 7 起，其中 2 起处于执行阶段',   NULL, 'open',       NOW() - INTERVAL '6 days'),
(24, 1, 'legal',     '法人代表涉刑事案件，已被采取强制措施',           NULL, 'processing', NOW() - INTERVAL '9 days'),
(15, 2, 'legal',     '商标侵权纠纷，索赔金额 200 万',                  NULL, 'open',       NOW() - INTERVAL '11 days'),

-- finance 维度
(11, 3, 'finance',   '资产负债率升至 89%，连续两季度超警戒线',         NULL, 'open',       NOW() - INTERVAL '1 day'),
(15, 3, 'finance',   '应收账款周转天数超 180 天，流动性压力显著',       NULL, 'confirmed',  NOW() - INTERVAL '5 days'),
(18, 3, 'finance',   '净利润同比下降 35%，亏损扩大趋势明显',           NULL, 'open',       NOW() - INTERVAL '8 days'),
(29, 3, 'finance',   '存货积压严重，资产减值风险较高',                  NULL, 'processing', NOW() - INTERVAL '12 days'),

-- credit 维度
(16, 4, 'credit',    '信用评级被下调至 BBB−，低于投资级',              NULL, 'open',       NOW() - INTERVAL '3 days'),
(11, 4, 'credit',    '主要债权银行收紧授信额度，已下调 30%',            NULL, 'confirmed',  NOW() - INTERVAL '7 days'),
(23, 4, 'credit',    '供应链金融平台黑名单预警',                        NULL, 'open',       NOW() - INTERVAL '10 days'),
(24, 4, 'credit',    '商业汇票承兑拒绝率升至 12%',                      NULL, 'open',       NOW() - INTERVAL '13 days'),

-- tax 维度
(16, 5, 'tax',       '涉嫌虚开增值税发票，税务稽查立案调查',           NULL, 'open',       NOW() - INTERVAL '2 days'),
(29, 5, 'tax',       '欠缴企业所得税 150 万，进入强制执行程序',         NULL, 'confirmed',  NOW() - INTERVAL '5 days'),
(15, 5, 'tax',       '被税务局列入非正常户名单',                        NULL, 'open',       NOW() - INTERVAL '8 days'),
(18, 5, 'tax',       '申报数据与财报差异较大，存在纳税调整风险',        NULL, 'processing', NOW() - INTERVAL '11 days'),

-- operation 维度
(16, 6, 'operation', '营业执照即将到期，未见续期申请',                  NULL, 'open',       NOW() - INTERVAL '1 day'),
(23, 6, 'operation', '连续 3 年被工商部门列入经营异常名录',             NULL, 'confirmed',  NOW() - INTERVAL '6 days'),
(11, 6, 'operation', '主要生产资质认证已过期',                          NULL, 'open',       NOW() - INTERVAL '9 days'),
(15, 6, 'operation', '安全生产许可证因事故被暂扣',                      NULL, 'processing', NOW() - INTERVAL '12 days'),

-- 已关闭事项（历史数据，丰富维度分布）
(12, 1, 'legal',     '涉知识产权纠纷（已调解结案）',                    NULL, 'closed',     NOW() - INTERVAL '20 days'),
(13, 3, 'finance',   '季度财报延迟披露（已整改）',                       NULL, 'closed',     NOW() - INTERVAL '25 days'),
(14, 6, 'operation', '工厂消防检查不合格（已整改完毕）',                 NULL, 'dismissed',  NOW() - INTERVAL '30 days');
