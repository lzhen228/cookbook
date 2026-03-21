-- V1__init_schema.sql
-- 初始化核心表结构，对齐 TECH_SPEC v2.0 第 4 节数据模型

-- pg_trgm 扩展（关键字搜索 trigram 索引）
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ========== supplier（供应商主表）==========
CREATE TABLE supplier (
    id                  BIGSERIAL PRIMARY KEY,
    name                VARCHAR(200)    NOT NULL,
    unified_code        VARCHAR(50)     UNIQUE,
    cooperation_status  VARCHAR(20)     NOT NULL DEFAULT 'potential',
    region_province     VARCHAR(50),
    region_city         VARCHAR(50),
    listed_status       VARCHAR(10),
    is_china_top500     BOOLEAN         NOT NULL DEFAULT FALSE,
    is_world_top500     BOOLEAN         NOT NULL DEFAULT FALSE,
    supplier_type       VARCHAR(20),
    nature              VARCHAR(20),
    supply_items        JSONB,
    is_followed         BOOLEAN         NOT NULL DEFAULT FALSE,
    ext_data            JSONB,
    health_score_cache  DECIMAL(5,2),
    health_level_cache  VARCHAR(20),
    week_trend_cache    DECIMAL(5,2),
    cache_updated_at    TIMESTAMPTZ,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_supplier_composite
    ON supplier(cooperation_status, health_level_cache, listed_status);
CREATE INDEX idx_supplier_cursor
    ON supplier(health_score_cache ASC NULLS LAST, id ASC);
CREATE INDEX idx_supplier_list_covering
    ON supplier(health_score_cache ASC, id ASC)
    INCLUDE (name, health_level_cache, cooperation_status, week_trend_cache, cache_updated_at);
CREATE INDEX idx_supplier_name_trgm
    ON supplier USING GIN(name gin_trgm_ops);
CREATE INDEX idx_supplier_supply_items
    ON supplier USING GIN(supply_items);
CREATE INDEX idx_supplier_followed
    ON supplier(is_followed) WHERE is_followed = TRUE;

-- ========== indicator（指标库表）==========
CREATE TABLE indicator (
    id             BIGSERIAL    PRIMARY KEY,
    name           VARCHAR(100) NOT NULL,
    description    TEXT,
    risk_dimension VARCHAR(50)  NOT NULL,
    formula        TEXT,
    data_source    VARCHAR(50),
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ========== alert_plan（预警方案主表）==========
CREATE TABLE alert_plan (
    id               BIGSERIAL    PRIMARY KEY,
    name             VARCHAR(30)  NOT NULL UNIQUE,
    description      VARCHAR(100),
    scope_config     JSONB,
    level_thresholds JSONB        NOT NULL,
    is_active        BOOLEAN      NOT NULL DEFAULT FALSE,
    created_by       BIGINT,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ========== alert_plan_indicator（方案指标权重关联表）==========
CREATE TABLE alert_plan_indicator (
    id           BIGSERIAL    PRIMARY KEY,
    plan_id      BIGINT       NOT NULL REFERENCES alert_plan(id) ON DELETE CASCADE,
    indicator_id BIGINT       NOT NULL REFERENCES indicator(id),
    weight       DECIMAL(5,4) NOT NULL CHECK (weight > 0 AND weight <= 1),
    is_redline   BOOLEAN      NOT NULL DEFAULT FALSE,
    UNIQUE (plan_id, indicator_id)
);

CREATE INDEX idx_plan_indicator_plan      ON alert_plan_indicator(plan_id);
CREATE INDEX idx_plan_indicator_indicator ON alert_plan_indicator(indicator_id);

-- ========== supplier_health_snapshot（健康评分快照表）==========
CREATE TABLE supplier_health_snapshot (
    id               BIGSERIAL    PRIMARY KEY,
    supplier_id      BIGINT       NOT NULL REFERENCES supplier(id),
    plan_id          BIGINT       NOT NULL REFERENCES alert_plan(id),
    health_score     DECIMAL(5,2) NOT NULL CHECK (health_score >= 0 AND health_score <= 100),
    health_level     VARCHAR(20)  NOT NULL,
    dimension_scores JSONB,
    snapshot_date    DATE         NOT NULL,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_snapshot_supplier_date
    ON supplier_health_snapshot(supplier_id, snapshot_date DESC);
CREATE INDEX idx_snapshot_level
    ON supplier_health_snapshot(health_level, snapshot_date DESC);

-- ========== risk_event（风险事项表）==========
CREATE TABLE risk_event (
    id             BIGSERIAL    PRIMARY KEY,
    supplier_id    BIGINT       NOT NULL REFERENCES supplier(id),
    indicator_id   BIGINT       REFERENCES indicator(id),
    risk_dimension VARCHAR(50),
    description    TEXT         NOT NULL,
    source_url     VARCHAR(500),
    status         VARCHAR(20)  NOT NULL DEFAULT 'open',
    assignee_id    BIGINT,
    close_note     TEXT,
    closed_at      TIMESTAMPTZ,
    is_notified    BOOLEAN      NOT NULL DEFAULT FALSE,
    triggered_at   TIMESTAMPTZ  NOT NULL,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_risk_event_supplier  ON risk_event(supplier_id, triggered_at DESC);
CREATE INDEX idx_risk_event_dimension ON risk_event(risk_dimension, triggered_at DESC);
CREATE INDEX idx_risk_event_status    ON risk_event(status, triggered_at DESC);
CREATE INDEX idx_risk_event_notified  ON risk_event(is_notified) WHERE is_notified = FALSE;

-- ========== audit_log（操作审计表）==========
CREATE TABLE audit_log (
    id            BIGSERIAL    PRIMARY KEY,
    operator_id   BIGINT       NOT NULL,
    operator_name VARCHAR(100),
    action        VARCHAR(50)  NOT NULL,
    target_type   VARCHAR(50),
    target_id     BIGINT,
    diff          JSONB,
    operated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_operator ON audit_log(operator_id, operated_at DESC);
CREATE INDEX idx_audit_target   ON audit_log(target_type, target_id, operated_at DESC);
