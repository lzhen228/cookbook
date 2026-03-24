package com.supply.risk.model.dto;

/**
 * 风险预警事项列表查询参数。
 *
 * <p>compact constructor 负责规范化分页参数：
 * <ul>
 *   <li>page &lt;= 0 时重置为 1</li>
 *   <li>pageSize &lt;= 0 或 &gt; 100 时重置为 20</li>
 * </ul>
 *
 * @param status        状态筛选，为 null 时不过滤
 * @param riskDimension 风险维度筛选，为 null 时不过滤
 * @param keyword       关键词搜索（模糊匹配描述），为 null 时不过滤
 * @param page          页码（从 1 开始）
 * @param pageSize      每页条数
 */
public record RiskAlertQuery(
    String status,
    String riskDimension,
    String keyword,
    int page,
    int pageSize
) {

  /**
   * 规范化分页参数的 compact constructor。
   */
  public RiskAlertQuery {
    if (page <= 0) {
      page = 1;
    }
    if (pageSize <= 0 || pageSize > 100) {
      pageSize = 20;
    }
  }

  /**
   * 计算数据库查询偏移量。
   *
   * @return OFFSET 值
   */
  public int offset() {
    return (page - 1) * pageSize;
  }
}
