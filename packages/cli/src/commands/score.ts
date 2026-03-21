import type { Command } from 'commander';
import { apiPost } from '../utils/request.js';
import { mockHealthSnapshot } from '../utils/mock.js';
import {
  printJson,
  printHealthSnapshot,
  logger,
} from '../utils/format.js';
import type { CliGlobalOptions, HealthSnapshot } from '../types/index.js';

/** 注册 score 子命令 */
export function registerScoreCommand(program: Command): void {
  program
    .command('score <supplierId>')
    .description('手动触发单个供应商评分')
    .option('-p, --plan-id <planId>', '指定预警方案 ID', '1')
    .action(async (supplierId: string, cmdOpts: { planId: string }) => {
      const opts = program.opts<CliGlobalOptions>();
      const id = Number(supplierId);
      const planId = Number(cmdOpts.planId);

      if (Number.isNaN(id) || id <= 0) {
        logger.error('supplierId 必须是正整数');
        process.exitCode = 1;
        return;
      }

      if (Number.isNaN(planId) || planId <= 0) {
        logger.error('planId 必须是正整数');
        process.exitCode = 1;
        return;
      }

      logger.info(
        `正在触发供应商评分: supplierId=${id}, planId=${planId} [env=${opts.env}]`
      );

      try {
        const data: HealthSnapshot = opts.mock
          ? mockHealthSnapshot(id)
          : await apiPost<HealthSnapshot>(
              opts.env,
              `/suppliers/${id}/score`,
              { planId }
            );

        if (opts.mock) logger.info('使用模拟数据');

        if (opts.format === 'json') {
          printJson(data);
        } else {
          printHealthSnapshot(data as unknown as Record<string, unknown>);
        }

        logger.info('评分完成');
      } catch {
        process.exitCode = 1;
      }
    });
}
