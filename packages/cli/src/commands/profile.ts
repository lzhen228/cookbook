import type { Command } from 'commander';
import { apiGet } from '../utils/request.js';
import { mockSupplierProfile } from '../utils/mock.js';
import {
  printJson,
  printSupplierProfile,
  logger,
} from '../utils/format.js';
import type { CliGlobalOptions, SupplierProfile } from '../types/index.js';

/** 注册 profile 子命令 */
export function registerProfileCommand(program: Command): void {
  program
    .command('profile <supplierId>')
    .description('查询供应商画像信息')
    .action(async (supplierId: string) => {
      const opts = program.opts<CliGlobalOptions>();
      const id = Number(supplierId);

      if (Number.isNaN(id) || id <= 0) {
        logger.error('supplierId 必须是正整数');
        process.exitCode = 1;
        return;
      }

      logger.info(`正在查询供应商画像: ${id} [env=${opts.env}]`);

      try {
        const data: SupplierProfile = opts.mock
          ? mockSupplierProfile(id)
          : await apiGet<SupplierProfile>(
              opts.env,
              `/suppliers/${id}/profile`
            );

        if (opts.mock) logger.info('使用模拟数据');

        if (opts.format === 'json') {
          printJson(data);
        } else {
          printSupplierProfile(data as unknown as Record<string, unknown>);
        }
      } catch {
        process.exitCode = 1;
      }
    });
}
