/**
 * MSW 测试服务器，在 Node 环境（Vitest）中使用。
 */
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);
