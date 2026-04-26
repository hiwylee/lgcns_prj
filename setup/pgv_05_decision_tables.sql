-- pgv_05_decision_tables.sql
-- SCM 의사결정 지원 테이블 (ES1-ES5 확장 시나리오)
-- Oracle 26ai / SCM_PGV Property Graph 프로젝트

-- SCM_SAFETY_STOCK: 자재별/사이트별 안전재고 기준
CREATE TABLE SCM_SAFETY_STOCK (
  model_code     VARCHAR2(30)   NOT NULL,
  site_code      VARCHAR2(20)   DEFAULT 'ALL' NOT NULL,  -- 'ALL' = 전체 사이트 공통
  material_type  VARCHAR2(20)   NOT NULL,                -- Link/Pack/Aerogel
  safety_days    NUMBER(10,2),                           -- 안전재고 일수 기준
  safety_qty     NUMBER(15,2),                           -- 안전재고 절대 수량
  calc_method    VARCHAR2(10)   DEFAULT 'DAYS',          -- DAYS/QTY/PCT
  service_level  NUMBER(5,4)    DEFAULT 0.95,            -- 서비스 레벨
  updated_at     DATE           DEFAULT SYSDATE,
  CONSTRAINT pk_safety_stock PRIMARY KEY (model_code, site_code)
);

-- SCM_EVENT_LOG: 이벤트 판정 이력
CREATE TABLE SCM_EVENT_LOG (
  event_id       NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_type     VARCHAR2(20)   NOT NULL,   -- SHORTAGE/SURPLUS/SURGE/STABLE
  link_model     VARCHAR2(30)   NOT NULL,
  plan_date      DATE           NOT NULL,
  delta_qty      NUMBER(10),
  site_code      VARCHAR2(20),
  aerogel_status VARCHAR2(10),              -- OK/LOW/CRITICAL
  pack_status    VARCHAR2(10),
  created_at     DATE           DEFAULT SYSDATE
);

-- SCM_RESPONSE_PLAN: 대응 계획 이력
CREATE TABLE SCM_RESPONSE_PLAN (
  plan_id        NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_id       NUMBER,                    -- FK to SCM_EVENT_LOG(event_id)
  link_model     VARCHAR2(30)   NOT NULL,
  plan_type      VARCHAR2(20)   NOT NULL,   -- INCREASE/DECREASE/HOLD
  req_link_qty   NUMBER(15,2),
  req_pack_qty   NUMBER(15,2),
  req_aerogel_qty NUMBER(15,2),
  feasible       VARCHAR2(10),             -- Y/N/PARTIAL
  plan_dates     VARCHAR2(500),            -- comma-separated dates
  created_at     DATE           DEFAULT SYSDATE
);

-- SCM_ROUTE_ANALYSIS: 운송 경로 분석 이력
CREATE TABLE SCM_ROUTE_ANALYSIS (
  analysis_id    NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source_site    VARCHAR2(20)   NOT NULL,
  dest_site      VARCHAR2(20)   NOT NULL,
  transport_mode VARCHAR2(10),
  lead_time_days NUMBER(6,1),
  hops           NUMBER(2),
  blocked        VARCHAR2(3)    DEFAULT 'N',  -- Y/N
  blocked_mode   VARCHAR2(10),               -- 차단된 운송 모드
  analysis_date  DATE           NOT NULL,
  created_at     DATE           DEFAULT SYSDATE
);

-- SCM_ALTERNATIVE_PLAN: 대안 계획 이력
CREATE TABLE SCM_ALTERNATIVE_PLAN (
  alt_id         NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  trigger_type   VARCHAR2(30)   NOT NULL,   -- ROUTE_BLOCK/MATERIAL_HOLD
  link_model     VARCHAR2(30),
  original_info  VARCHAR2(200),             -- 원래 경로/계획
  alt_info       VARCHAR2(200),             -- 대안 경로/계획
  alt_lt_days    NUMBER(6,1),
  savings_days   NUMBER(6,1),
  selected       VARCHAR2(3)    DEFAULT 'N', -- Y/N
  created_at     DATE           DEFAULT SYSDATE
);

-- 샘플 데이터 (site_code='ALL' = 전사 기준)
INSERT INTO SCM_SAFETY_STOCK (model_code, site_code, material_type, safety_days, calc_method, service_level)
VALUES ('ZOY1551VFW3V-VVV', 'ALL', 'Link', 7, 'DAYS', 0.95);
INSERT INTO SCM_SAFETY_STOCK (model_code, site_code, material_type, safety_days, calc_method, service_level)
VALUES ('MPD00001AA', 'ALL', 'Aerogel', 14, 'DAYS', 0.95);
COMMIT;
