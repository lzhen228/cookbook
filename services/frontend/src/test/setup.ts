/**
 * Vitest 全局测试配置文件。
 *
 * - 启动 MSW 服务器拦截 HTTP 请求
 * - 引入 @testing-library/jest-dom 扩展断言
 * - 每个测试后重置请求处理器
 */
import '@testing-library/jest-dom';
import { beforeAll, afterEach, afterAll } from 'vitest';
import { cleanup } from '@testing-library/react';
import { server } from './mocks/server';

// Ant Design 需要 window.matchMedia（jsdom 不提供）
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: (query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: () => {},
    removeListener: () => {},
    addEventListener: () => {},
    removeEventListener: () => {},
    dispatchEvent: () => false,
  }),
});

// Ant Design 需要 getComputedStyle
if (!window.getComputedStyle) {
  (window as unknown as Record<string, unknown>).getComputedStyle = () => ({});
}

// MSW: 在所有测试开始前启动拦截
beforeAll(() => server.listen({ onUnhandledRequest: 'warn' }));

// 每个测试后：重置处理器 + 清理 DOM
afterEach(() => {
  server.resetHandlers();
  cleanup();
});

// 所有测试结束后关闭 MSW
afterAll(() => server.close());
