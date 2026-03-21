import axios from 'axios';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import type { AuthToken, EnvConfig } from '../types/index.js';
import { getEnvConfig } from './request.js';
import { logger } from './format.js';

const TOKEN_DIR = join(homedir(), '.scrm-cli');
const TOKEN_FILE = join(TOKEN_DIR, 'auth.json');

/** 从磁盘读取已缓存的 Token */
function readCachedToken(): AuthToken | null {
  if (!existsSync(TOKEN_FILE)) {
    return null;
  }
  try {
    const raw = readFileSync(TOKEN_FILE, 'utf-8');
    return JSON.parse(raw) as AuthToken;
  } catch {
    return null;
  }
}

/** 将 Token 缓存到磁盘 */
function writeCachedToken(token: AuthToken): void {
  if (!existsSync(TOKEN_DIR)) {
    mkdirSync(TOKEN_DIR, { recursive: true });
  }
  writeFileSync(TOKEN_FILE, JSON.stringify(token, null, 2), 'utf-8');
}

/** 判断 Access Token 是否已过期（提前 60 秒视为过期） */
function isTokenExpired(token: AuthToken): boolean {
  const now = Date.now();
  const expiresAt = token.obtainedAt + token.expiresIn * 1000;
  return now >= expiresAt - 60_000;
}

/** 通过用户名密码获取新 Token（从环境变量读取凭据） */
async function fetchNewToken(envConfig: EnvConfig): Promise<AuthToken> {
  const username = process.env['SCRM_CLI_USERNAME'];
  const password = process.env['SCRM_CLI_PASSWORD'];

  if (!username || !password) {
    throw new Error(
      '未设置认证凭据。请设置环境变量 SCRM_CLI_USERNAME 和 SCRM_CLI_PASSWORD'
    );
  }

  logger.debug(`正在请求新 Token: ${envConfig.authUrl}/auth/token`);

  const response = await axios.post(
    `${envConfig.authUrl}/auth/token`,
    { username, password },
    {
      timeout: 10_000,
      headers: { 'Content-Type': 'application/json' },
    }
  );

  const data = response.data as {
    access_token: string;
    refresh_token: string;
    expires_in: number;
  };

  const token: AuthToken = {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresIn: data.expires_in,
    obtainedAt: Date.now(),
  };

  writeCachedToken(token);
  logger.info('Token 获取成功');
  return token;
}

/** 使用 Refresh Token 刷新 Access Token */
async function refreshAccessToken(
  envConfig: EnvConfig,
  refreshToken: string
): Promise<AuthToken> {
  logger.debug('正在刷新 Token...');

  try {
    const response = await axios.post(
      `${envConfig.authUrl}/auth/refresh`,
      { refresh_token: refreshToken },
      {
        timeout: 10_000,
        headers: { 'Content-Type': 'application/json' },
      }
    );

    const data = response.data as {
      access_token: string;
      refresh_token: string;
      expires_in: number;
    };

    const token: AuthToken = {
      accessToken: data.access_token,
      refreshToken: data.refresh_token,
      expiresIn: data.expires_in,
      obtainedAt: Date.now(),
    };

    writeCachedToken(token);
    logger.info('Token 刷新成功');
    return token;
  } catch {
    logger.warn('Refresh Token 已失效，重新获取 Token');
    return fetchNewToken(envConfig);
  }
}

/**
 * 获取有效的 Access Token。
 * 优先使用缓存 Token，过期时自动刷新，刷新失败时重新获取。
 */
export async function getAccessToken(env: string): Promise<string> {
  const envConfig = getEnvConfig(env);
  const cached = readCachedToken();

  if (cached && !isTokenExpired(cached)) {
    logger.debug('使用缓存 Token');
    return cached.accessToken;
  }

  if (cached?.refreshToken) {
    const refreshed = await refreshAccessToken(envConfig, cached.refreshToken);
    return refreshed.accessToken;
  }

  const newToken = await fetchNewToken(envConfig);
  return newToken.accessToken;
}

/** 清除本地缓存的 Token */
export function clearCachedToken(): void {
  if (existsSync(TOKEN_FILE)) {
    writeFileSync(TOKEN_FILE, '', 'utf-8');
    logger.info('已清除本地 Token 缓存');
  }
}
