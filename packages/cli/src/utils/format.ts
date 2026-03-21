import chalk from 'chalk';
import Table from 'cli-table3';

let currentLogLevel: 'debug' | 'info' | 'warn' | 'error' = 'info';

const LOG_LEVELS = { debug: 0, info: 1, warn: 2, error: 3 } as const;

/** 设置全局日志级别 */
export function setLogLevel(
  level: 'debug' | 'info' | 'warn' | 'error'
): void {
  currentLogLevel = level;
}

/** 日志工具 */
export const logger = {
  debug(msg: string): void {
    if (LOG_LEVELS[currentLogLevel] <= LOG_LEVELS.debug) {
      console.log(chalk.gray(`[DEBUG] ${msg}`));
    }
  },
  info(msg: string): void {
    if (LOG_LEVELS[currentLogLevel] <= LOG_LEVELS.info) {
      console.log(chalk.blue(`[INFO]  ${msg}`));
    }
  },
  warn(msg: string): void {
    if (LOG_LEVELS[currentLogLevel] <= LOG_LEVELS.warn) {
      console.log(chalk.yellow(`[WARN]  ${msg}`));
    }
  },
  error(msg: string): void {
    console.error(chalk.red(`[ERROR] ${msg}`));
  },
};

/** 以 JSON 格式输出数据 */
export function printJson(data: unknown): void {
  console.log(JSON.stringify(data, null, 2));
}

/** 以表格格式输出供应商画像 */
export function printSupplierProfile(
  data: Record<string, unknown>
): void {
  const table = new Table();
  const labelMap: Record<string, string> = {
    id: '供应商 ID',
    name: '企业名称',
    unifiedCreditCode: '统一信用代码',
    cooperationStatus: '合作状态',
    healthScore: '健康分',
    healthLevel: '风险等级',
    industryCategory: '行业分类',
    registeredCapital: '注册资本',
    contactPerson: '联系人',
    contactPhone: '联系电话',
    createdAt: '创建时间',
    updatedAt: '更新时间',
  };

  for (const [key, value] of Object.entries(data)) {
    const label = labelMap[key] ?? key;
    const displayValue = formatFieldValue(key, value);
    table.push({ [chalk.cyan(label)]: displayValue });
  }

  console.log(table.toString());
}

/** 以表格格式输出健康评分快照 */
export function printHealthSnapshot(
  data: Record<string, unknown>
): void {
  const indicators = data['indicators'] as
    | Array<Record<string, unknown>>
    | undefined;

  const summaryTable = new Table();
  summaryTable.push(
    { [chalk.cyan('供应商 ID')]: String(data['supplierId']) },
    { [chalk.cyan('供应商名称')]: String(data['supplierName']) },
    { [chalk.cyan('健康分')]: colorizeScore(data['healthScore'] as number) },
    { [chalk.cyan('风险等级')]: colorizeLevel(data['healthLevel'] as string) },
    { [chalk.cyan('快照日期')]: String(data['snapshotDate']) },
    { [chalk.cyan('方案名称')]: String(data['planName']) }
  );
  console.log(summaryTable.toString());

  if (indicators && indicators.length > 0) {
    console.log(chalk.bold('\n指标明细：'));
    const indicatorTable = new Table({
      head: [
        chalk.white('指标名称'),
        chalk.white('分类'),
        chalk.white('得分'),
        chalk.white('权重'),
        chalk.white('红线'),
        chalk.white('触发'),
        chalk.white('说明'),
      ],
    });

    for (const ind of indicators) {
      indicatorTable.push([
        ind['indicatorName'] as string,
        ind['category'] as string,
        String(ind['score']),
        String(ind['weight']),
        ind['isRedline'] ? chalk.red('是') : '否',
        ind['triggered'] ? chalk.red('是') : '否',
        ind['detail'] as string,
      ]);
    }
    console.log(indicatorTable.toString());
  }
}

/** 以表格格式输出预警列表 */
export function printAlertList(
  items: Array<Record<string, unknown>>,
  total: number,
  page: number,
  size: number
): void {
  console.log(
    chalk.bold(
      `\n预警列表（共 ${total} 条，第 ${page} 页，每页 ${size} 条）：`
    )
  );

  if (items.length === 0) {
    console.log(chalk.gray('  暂无预警记录'));
    return;
  }

  const table = new Table({
    head: [
      chalk.white('ID'),
      chalk.white('供应商'),
      chalk.white('预警等级'),
      chalk.white('类型'),
      chalk.white('指标'),
      chalk.white('消息'),
      chalk.white('状态'),
      chalk.white('触发时间'),
    ],
  });

  for (const item of items) {
    table.push([
      String(item['id']),
      item['supplierName'] as string,
      colorizeLevel(item['alertLevel'] as string),
      item['alertType'] as string,
      item['indicatorName'] as string,
      truncate(item['message'] as string, 30),
      item['status'] as string,
      item['triggeredAt'] as string,
    ]);
  }

  console.log(table.toString());
}

/** 输出报告生成状态 */
export function printReportStatus(
  data: Record<string, unknown>
): void {
  const table = new Table();
  table.push(
    { [chalk.cyan('报告 ID')]: String(data['reportId'] ?? '-') },
    { [chalk.cyan('供应商 ID')]: String(data['supplierId'] ?? '-') },
    { [chalk.cyan('供应商名称')]: String(data['supplierName'] ?? '-') },
    { [chalk.cyan('状态')]: colorizeReportStatus(data['status'] as string) },
    { [chalk.cyan('生成时间')]: String(data['generatedAt'] ?? '-') },
    { [chalk.cyan('下载地址')]: String(data['downloadUrl'] ?? '-') }
  );
  console.log(table.toString());
}

/** 根据分数着色 */
function colorizeScore(score: number): string {
  if (score >= 80) return chalk.green(String(score));
  if (score >= 60) return chalk.yellow(String(score));
  return chalk.red(String(score));
}

/** 根据风险等级着色 */
function colorizeLevel(level: string): string {
  const normalized = level.toLowerCase().replace(/[_-]/g, '');
  if (normalized === 'highrisk' || normalized === 'high') {
    return chalk.red(level);
  }
  if (normalized === 'mediumrisk' || normalized === 'medium') {
    return chalk.yellow(level);
  }
  if (normalized === 'lowrisk' || normalized === 'low') {
    return chalk.green(level);
  }
  return level;
}

/** 报告状态着色 */
function colorizeReportStatus(status: string): string {
  switch (status) {
    case 'completed':
      return chalk.green('已完成');
    case 'generating':
      return chalk.yellow('生成中');
    case 'pending':
      return chalk.gray('等待中');
    case 'failed':
      return chalk.red('生成失败');
    default:
      return status;
  }
}

/** 格式化特定字段的显示值 */
function formatFieldValue(key: string, value: unknown): string {
  if (value === null || value === undefined) return '-';
  if (key === 'healthScore') return colorizeScore(value as number);
  if (key === 'healthLevel') return colorizeLevel(value as string);
  if (key === 'contactPhone') return maskPhone(String(value));
  return String(value);
}

/** 手机号脱敏：保留前3后4 */
function maskPhone(phone: string): string {
  if (phone.length < 7) return phone;
  return phone.slice(0, 3) + '****' + phone.slice(-4);
}

/** 截断过长文本 */
function truncate(text: string, maxLen: number): string {
  if (text.length <= maxLen) return text;
  return text.slice(0, maxLen - 3) + '...';
}
