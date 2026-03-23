-- V3__add_ext_data.sql
-- 为供应商添加结构化 ext_data，供 Tab 懒加载接口（TECH_SPEC 5.4 节）返回详情数据。
-- 每个 Tab 对应 ext_data 中的一个顶层 Key：
--   basic-info / business-info / judicial / credit / tax

UPDATE supplier
SET ext_data = '{
  "basic-info": {
    "legal_rep": "陈志远",
    "reg_capital": "5000万元",
    "establishment_date": "2012-03-15",
    "registered_address": "广东省深圳市南山区科技园南区A栋501室",
    "employees_count": 280,
    "contact_phone": "0755-8888****"
  },
  "business-info": {
    "main_business": "半导体芯片设计、封装、测试及销售",
    "annual_revenue": "约3.2亿元（2025年报）",
    "shareholders": [
      {"name":"陈志远","share_ratio":"35%","contribution":"1750万元"},
      {"name":"深圳科投集团有限公司","share_ratio":"20%","contribution":"1000万元"},
      {"name":"浦发硅谷银行股权投资基金","share_ratio":"15%","contribution":"750万元"},
      {"name":"其他自然人股东","share_ratio":"30%","contribution":"1500万元"}
    ],
    "branches": [
      {"name":"上海芯科研发中心","address":"上海市浦东新区张江高科技园区","status":"正常"},
      {"name":"北京芯科销售中心","address":"北京市海淀区中关村科技园","status":"正常"}
    ]
  },
  "judicial": {
    "dishonest_count": 0,
    "execution_count": 2,
    "executions": [
      {"case_no":"(2025)粤0305执1234号","court":"深圳市南山区人民法院","amount":"300万元","status":"未结清","date":"2025-10-15"},
      {"case_no":"(2025)粤0305执2345号","court":"深圳市南山区人民法院","amount":"150万元","status":"未结清","date":"2025-11-20"}
    ],
    "litigations": [
      {"title":"买卖合同纠纷","court":"深圳市南山区人民法院","role":"被告","amount":"450万元","status":"一审中","date":"2025-09-01"},
      {"title":"货款追讨纠纷","court":"深圳市福田区人民法院","role":"原告","amount":"80万元","status":"已调解","date":"2025-06-10"}
    ]
  },
  "credit": {
    "credit_score": 58,
    "rating": "A-",
    "rating_agency": "联合信用评级有限公司",
    "rating_date": "2025-06-15",
    "rating_outlook": "负面",
    "rating_history": [
      {"rating":"A+","agency":"联合信用评级有限公司","date":"2022-06-18","change":"maintain"},
      {"rating":"AA-","agency":"联合信用评级有限公司","date":"2023-06-20","change":"upgrade"},
      {"rating":"AA-","agency":"联合信用评级有限公司","date":"2024-06-10","change":"maintain"},
      {"rating":"A-","agency":"联合信用评级有限公司","date":"2025-06-15","change":"downgrade"}
    ]
  },
  "tax": {
    "tax_payer_type": "一般纳税人",
    "tax_credit_level": "B级",
    "tax_credit_date": "2026-01-15",
    "penalties": [],
    "abnormal_records": [
      {"type":"增值税申报异常","date":"2025-08-10","reason":"连续3个月零申报，与实际经营情况不符","status":"已处理"}
    ]
  }
}'::jsonb
WHERE id = 1;

UPDATE supplier
SET ext_data = '{
  "basic-info": {
    "legal_rep": "王建国",
    "reg_capital": "12000万元",
    "establishment_date": "1998-05-20",
    "registered_address": "上海市浦东新区张江高科技园区精密路88号",
    "employees_count": 1850,
    "contact_phone": "021-6688****"
  },
  "business-info": {
    "main_business": "精密机械零部件、轴承、传动系统研发制造及销售",
    "annual_revenue": "约28亿元（2025年报）",
    "shareholders": [
      {"name":"上海国资委","share_ratio":"51%","contribution":"6120万元"},
      {"name":"社会公众股","share_ratio":"49%","contribution":"5880万元"}
    ],
    "branches": [
      {"name":"苏州精工生产基地","address":"江苏省苏州市工业园区","status":"正常"},
      {"name":"武汉精工营销中心","address":"湖北省武汉市武昌区","status":"正常"},
      {"name":"广州精工仓储物流中心","address":"广东省广州市番禺区","status":"正常"}
    ]
  },
  "judicial": {
    "dishonest_count": 0,
    "execution_count": 0,
    "executions": [],
    "litigations": [
      {"title":"专利侵权纠纷","court":"上海知识产权法院","role":"原告","amount":"500万元","status":"二审中","date":"2024-11-15"}
    ]
  },
  "credit": {
    "credit_score": 72,
    "rating": "A",
    "rating_agency": "中诚信国际信用评级有限责任公司",
    "rating_date": "2025-08-10",
    "rating_outlook": "稳定",
    "rating_history": [
      {"rating":"A","agency":"中诚信国际","date":"2022-08-05","change":"maintain"},
      {"rating":"A","agency":"中诚信国际","date":"2023-08-12","change":"maintain"},
      {"rating":"A","agency":"中诚信国际","date":"2024-08-08","change":"maintain"},
      {"rating":"A","agency":"中诚信国际","date":"2025-08-10","change":"maintain"}
    ]
  },
  "tax": {
    "tax_payer_type": "一般纳税人",
    "tax_credit_level": "A级",
    "tax_credit_date": "2026-01-15",
    "penalties": [],
    "abnormal_records": []
  }
}'::jsonb
WHERE id = 2;

UPDATE supplier
SET ext_data = '{
  "basic-info": {
    "legal_rep": "李明",
    "reg_capital": "3000万元",
    "establishment_date": "2015-09-10",
    "registered_address": "北京市海淀区中关村科技园D区18号楼",
    "employees_count": 420,
    "contact_phone": "010-8899****"
  },
  "business-info": {
    "main_business": "座舱域控制器、智能驾驶辅助系统（ADAS）软硬件研发",
    "annual_revenue": "约5.8亿元（2025年报）",
    "shareholders": [
      {"name":"李明","share_ratio":"28%","contribution":"840万元"},
      {"name":"北京智创投资基金","share_ratio":"22%","contribution":"660万元"},
      {"name":"某知名整车厂战略投资","share_ratio":"20%","contribution":"600万元"},
      {"name":"员工持股平台","share_ratio":"30%","contribution":"900万元"}
    ],
    "branches": [
      {"name":"上海智驾研发中心","address":"上海市闵行区紫竹高新技术园","status":"正常"},
      {"name":"深圳智驾测试基地","address":"广东省深圳市坪山区","status":"正常"}
    ]
  },
  "judicial": {
    "dishonest_count": 0,
    "execution_count": 0,
    "executions": [],
    "litigations": []
  },
  "credit": {
    "credit_score": 85,
    "rating": "AA-",
    "rating_agency": "大公国际资信评估有限公司",
    "rating_date": "2025-09-20",
    "rating_outlook": "稳定",
    "rating_history": [
      {"rating":"A+","agency":"大公国际","date":"2022-09-18","change":"maintain"},
      {"rating":"AA-","agency":"大公国际","date":"2023-09-22","change":"upgrade"},
      {"rating":"AA-","agency":"大公国际","date":"2024-09-15","change":"maintain"},
      {"rating":"AA-","agency":"大公国际","date":"2025-09-20","change":"maintain"}
    ]
  },
  "tax": {
    "tax_payer_type": "一般纳税人",
    "tax_credit_level": "A级",
    "tax_credit_date": "2026-01-15",
    "penalties": [],
    "abnormal_records": []
  }
}'::jsonb
WHERE id = 3;

UPDATE supplier
SET ext_data = '{
  "basic-info": {
    "legal_rep": "张恒",
    "reg_capital": "800万元",
    "establishment_date": "2008-07-30",
    "registered_address": "重庆市渝北区两江新区金渝大道88号",
    "employees_count": 95,
    "contact_phone": "023-6677****"
  },
  "business-info": {
    "main_business": "汽车刹车片、制动系统零部件生产及销售",
    "annual_revenue": "约0.6亿元（2025年报）",
    "shareholders": [
      {"name":"张恒","share_ratio":"60%","contribution":"480万元"},
      {"name":"某外资汽配集团","share_ratio":"40%","contribution":"320万元"}
    ],
    "branches": []
  },
  "judicial": {
    "dishonest_count": 1,
    "execution_count": 3,
    "executions": [
      {"case_no":"(2025)渝0112执0456号","court":"重庆市渝北区人民法院","amount":"120万元","status":"未结清","date":"2025-03-10"},
      {"case_no":"(2025)渝0112执0789号","court":"重庆市渝北区人民法院","amount":"80万元","status":"未结清","date":"2025-05-20"},
      {"case_no":"(2024)渝0112执1023号","court":"重庆市渝北区人民法院","amount":"50万元","status":"未结清","date":"2024-11-05"}
    ],
    "litigations": [
      {"title":"产品质量赔偿纠纷","court":"重庆市第一中级人民法院","role":"被告","amount":"200万元","status":"一审中","date":"2025-06-01"},
      {"title":"劳动合同纠纷","court":"重庆市渝北区劳动仲裁委员会","role":"被申请人","amount":"15万元","status":"已裁决","date":"2025-01-10"}
    ]
  },
  "credit": {
    "credit_score": 28,
    "rating": "BB",
    "rating_agency": "联合信用评级有限公司",
    "rating_date": "2025-07-01",
    "rating_outlook": "负面",
    "rating_history": [
      {"rating":"BBB-","agency":"联合信用评级","date":"2022-07-10","change":"maintain"},
      {"rating":"BB+","agency":"联合信用评级","date":"2023-07-08","change":"downgrade"},
      {"rating":"BB","agency":"联合信用评级","date":"2024-07-15","change":"downgrade"},
      {"rating":"BB","agency":"联合信用评级","date":"2025-07-01","change":"maintain"}
    ]
  },
  "tax": {
    "tax_payer_type": "一般纳税人",
    "tax_credit_level": "D级",
    "tax_credit_date": "2026-01-15",
    "owed_tax": "欠缴税款约200万元",
    "penalties": [
      {"type":"增值税偷税处罚","amount":"36万元","date":"2025-04-15","status":"未缴清","reason":"虚开增值税专用发票"},
      {"type":"企业所得税滞纳金","amount":"8.5万元","date":"2025-02-20","status":"已缴清","reason":"逾期申报"}
    ],
    "abnormal_records": [
      {"type":"非正常户认定","date":"2024-09-01","reason":"连续6个月未申报","status":"已处理"},
      {"type":"增值税申报异常","date":"2025-03-15","reason":"进销比严重异常","status":"调查中"}
    ]
  }
}'::jsonb
WHERE id = 9;
