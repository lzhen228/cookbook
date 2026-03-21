export interface CliGlobalOptions {
  env: 'dev' | 'test' | 'prod';
  logLevel: 'debug' | 'info' | 'warn' | 'error';
  format: 'json' | 'table';
  mock: boolean;
}

export interface ApiResponse<T> {
  code: number;
  msg: string;
  data: T;
  traceId: string;
}

export interface PageResult<T> {
  items: T[];
  total: number;
  page: number;
  size: number;
}

export interface SupplierProfile {
  id: number;
  name: string;
  unifiedCreditCode: string;
  cooperationStatus: string;
  healthScore: number;
  healthLevel: string;
  industryCategory: string;
  registeredCapital: string;
  contactPerson: string;
  contactPhone: string;
  createdAt: string;
  updatedAt: string;
}

export interface HealthSnapshot {
  supplierId: number;
  supplierName: string;
  healthScore: number;
  healthLevel: string;
  snapshotDate: string;
  planId: number;
  planName: string;
  indicators: IndicatorResult[];
}

export interface IndicatorResult {
  indicatorId: number;
  indicatorName: string;
  category: string;
  score: number;
  weight: number;
  isRedline: boolean;
  triggered: boolean;
  detail: string;
}

export interface HealthReport {
  reportId: string;
  supplierId: number;
  supplierName: string;
  status: 'pending' | 'generating' | 'completed' | 'failed';
  generatedAt: string;
  downloadUrl: string;
}

export interface AlertItem {
  id: number;
  supplierId: number;
  supplierName: string;
  alertLevel: string;
  alertType: string;
  indicatorName: string;
  message: string;
  status: string;
  triggeredAt: string;
  resolvedAt: string | null;
}

export interface AuthToken {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  obtainedAt: number;
}

export interface EnvConfig {
  baseUrl: string;
  authUrl: string;
}
