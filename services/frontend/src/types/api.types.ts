/** 统一响应体，对齐后端 ApiResponse<T> */
export interface ApiResponse<T> {
  code: number;
  msg: string;
  data: T;
  traceId: string;
}

/** 分页响应通用结构 */
export interface PaginatedData<T> {
  total: number;
  page: number;
  page_size: number;
  next_cursor: string | null;
  items: T[];
}
