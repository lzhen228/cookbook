import type { Command } from 'commander';
import { apiGet } from '../utils/request.js';
import { mockAlertList } from '../utils/mock.js';
import { printJson, printAlertList, logger } from '../utils/format.js';
import type {
  CliGlobalOptions,
  AlertItem,
  PageResult,
} from '../types/index.js';

/** 注册 alert 子命令组 */
export function registerAlertCommand(program: Command): void {
  const alert = program
    .command('alert')
    .description('风险预警管理');

  alert
    .command('list')
    .description('查询风险预警列表')
    .option('--page <page>', '页码', '1')
    .option('--size <size>', '每页条数（最大 100）', '20')
    .option('--level <level>', '按预警等级筛选（high/medium/low）')
    .option('--status <status>', '按状态筛选（pending/resolved/ignored）')
    .option('--supplier-id <supplierId>', '按供应商 ID 筛选')
    .action(
      async (cmdOpts: {
        page: string;
        size: string;
        level?: string;
        status?: string;
        supplierId?: string;
      }) => {
        const opts = program.opts<CliGlobalOptions>();
        const page = Number(cmdOpts.page);
        const size = Number(cmdOpts.size);

        if (Number.isNaN(page) || page < 1) {
          logger.error('page 必须是大于 0 的整数');
          process.exitCode = 1;
          return;
        }

        if (Number.isNaN(size) || size < 1 || size > 100) {
          logger.error('size 必须是 1-100 之间的整数');
          process.exitCode = 1;
          return;
        }

        const params: Record<string, unknown> = { page, size };
        if (cmdOpts.level) params['level'] = cmdOpts.level;
        if (cmdOpts.status) params['status'] = cmdOpts.status;
        if (cmdOpts.supplierId) {
          params['supplierId'] = Number(cmdOpts.supplierId);
        }

        logger.info(
          `正在查询预警列表: page=${page}, size=${size} [env=${opts.env}]`
        );

        try {
          const data: PageResult<AlertItem> = opts.mock
            ? mockAlertList(page, size)
            : await apiGet<PageResult<AlertItem>>(
                opts.env,
                '/alerts',
                params
              );

          if (opts.mock) logger.info('使用模拟数据');

          if (opts.format === 'json') {
            printJson(data);
          } else {
            printAlertList(
              data.items as unknown as Array<Record<string, unknown>>,
              data.total,
              page,
              size
            );
          }
        } catch {
          process.exitCode = 1;
        }
      }
    );
}
