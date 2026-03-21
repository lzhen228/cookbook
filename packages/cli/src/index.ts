import { Command } from 'commander';
import { setLogLevel, logger } from './utils/format.js';
import { registerProfileCommand } from './commands/profile.js';
import { registerScoreCommand } from './commands/score.js';
import { registerReportCommand } from './commands/report.js';
import { registerAlertCommand } from './commands/alert.js';

const program = new Command();

program
  .name('risk-supplier')
  .description('供应链风险管理平台 CLI 测试工具')
  .version('1.0.0')
  .option(
    '-e, --env <env>',
    '目标环境 (dev/test/prod)',
    'dev'
  )
  .option(
    '-l, --log-level <level>',
    '日志级别 (debug/info/warn/error)',
    'info'
  )
  .option(
    '-f, --format <format>',
    '输出格式 (json/table)',
    'table'
  )
  .option(
    '-m, --mock',
    '使用模拟数据（无需后端服务）',
    false
  )
  .hook('preAction', () => {
    const opts = program.opts<{
      logLevel: string;
      env: string;
    }>();

    const validLevels = ['debug', 'info', 'warn', 'error'];
    if (!validLevels.includes(opts.logLevel)) {
      console.error(
        `无效的日志级别: ${opts.logLevel}，可选值: ${validLevels.join(', ')}`
      );
      process.exit(1);
    }
    setLogLevel(opts.logLevel as 'debug' | 'info' | 'warn' | 'error');

    const validEnvs = ['dev', 'test', 'prod'];
    if (!validEnvs.includes(opts.env)) {
      console.error(
        `无效的环境: ${opts.env}，可选值: ${validEnvs.join(', ')}`
      );
      process.exit(1);
    }

    if (opts.env === 'prod') {
      logger.warn('当前操作目标为生产环境，请谨慎操作！');
    }
  });

registerProfileCommand(program);
registerScoreCommand(program);
registerReportCommand(program);
registerAlertCommand(program);

program.parse();
