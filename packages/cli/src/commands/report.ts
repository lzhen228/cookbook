import type { Command } from 'commander';
import { apiPost } from '../utils/request.js';
import { mockHealthReport } from '../utils/mock.js';
import { printJson, printReportStatus, logger } from '../utils/format.js';
import type { CliGlobalOptions, HealthReport } from '../types/index.js';

/** 注册 report 子命令组 */
export function registerReportCommand(program: Command): void {
  const report = program
    .command('report')
    .description('健康报告管理');

  report
    .command('generate <supplierId>')
    .description('触发指定供应商的健康报告生成')
    .option(
      '-p, --plan-id <planId>',
      '指定预警方案 ID（不指定则使用默认方案）'
    )
    .action(async (supplierId: string, cmdOpts: { planId?: string }) => {
      const opts = program.opts<CliGlobalOptions>();
      const id = Number(supplierId);

      if (Number.isNaN(id) || id <= 0) {
        logger.error('supplierId 必须是正整数');
        process.exitCode = 1;
        return;
      }

      const body: Record<string, unknown> = {};
      if (cmdOpts.planId) {
        const planId = Number(cmdOpts.planId);
        if (Number.isNaN(planId) || planId <= 0) {
          logger.error('planId 必须是正整数');
          process.exitCode = 1;
          return;
        }
        body['planId'] = planId;
      }

      logger.info(
        `正在触发健康报告生成: supplierId=${id} [env=${opts.env}]`
      );

      try {
        const data: HealthReport = opts.mock
          ? mockHealthReport(id)
          : await apiPost<HealthReport>(
              opts.env,
              `/suppliers/${id}/report/generate`,
              body
            );

        if (opts.mock) logger.info('使用模拟数据');

        if (opts.format === 'json') {
          printJson(data);
        } else {
          printReportStatus(data as unknown as Record<string, unknown>);
        }

        logger.info('报告生成请求已提交');
      } catch {
        process.exitCode = 1;
      }
    });
}
