-- ============================================================
-- pgv_06_rolling_views.sql
-- SCM_PGV — 날짜별 Rolling BOH View (수불부)
-- ============================================================
-- 목적: 기초재고(PGV_INV_*) + 입고(생산/입하) - 출고(출하) 를
--       날짜별로 누적해 BOH를 계산하는 View.
--       simulator/boh.py 에서 수불부 조회 시 사용.
--
-- 생성 View:
--   PGV_V_DAILY_LINK_BOH     — 링크 모델 날짜별 BOH
--   PGV_V_DAILY_PACK_BOH     — 팩 모델 날짜별 BOH
--   PGV_V_DAILY_AEROGEL_BOH  — 에어로겔 날짜별 BOH
--
-- BOH(t) = base_inv + Σinflow(base_date..t) - Σoutflow(base_date..t)
-- daily_cap_proxy = 7일 이동평균 생산량 × 1.1  (증산 여유 판단용)
-- ============================================================

SET ECHO ON
SET DEFINE OFF

PROMPT ============================================================
PROMPT pgv_06_rolling_views.sql — Rolling BOH View 생성 시작
PROMPT ============================================================


-- ============================================================
-- View 1: PGV_V_DAILY_LINK_BOH
-- ============================================================
PROMPT [1/3] PGV_V_DAILY_LINK_BOH 생성 중...

CREATE OR REPLACE VIEW PGV_V_DAILY_LINK_BOH AS
WITH base AS (
    SELECT site_code,
           link_model_code AS model_code,
           base_date,
           inventory_qty   AS base_inv
    FROM PGV_INV_LINK
),
flows AS (
    -- 생산 입고 (LINK_PRODUCTION_PLAN)
    SELECT p.PRODUCTION_SITE_CODE AS site_code,
           p.LINK_MODEL_CODE      AS model_code,
           p.PRODUCTION_PLAN_DATE AS cal_date,
           p.PRODUCTION_PLAN_QTY  AS daily_inflow,
           0                      AS daily_outflow
    FROM LINK_PRODUCTION_PLAN p
    UNION ALL
    -- 출하 출고 (LINK_SHIPMENT_PLAN)
    SELECT s.SOURCE_SITE_CODE   AS site_code,
           s.LINK_MODEL_CODE    AS model_code,
           s.SHIPMENT_PLAN_DATE AS cal_date,
           0                    AS daily_inflow,
           s.SHIPMENT_PLAN_QTY  AS daily_outflow
    FROM LINK_SHIPMENT_PLAN s
),
daily AS (
    SELECT f.site_code,
           f.model_code,
           f.cal_date,
           SUM(f.daily_inflow)  AS daily_inflow,
           SUM(f.daily_outflow) AS daily_outflow,
           b.base_inv,
           b.base_date
    FROM flows f
    JOIN base b
      ON b.site_code  = f.site_code
     AND b.model_code = f.model_code
    WHERE f.cal_date >= b.base_date
    GROUP BY f.site_code, f.model_code, f.cal_date, b.base_inv, b.base_date
)
SELECT
    site_code,
    model_code,
    cal_date,
    daily_inflow,
    daily_outflow,
    daily_inflow - daily_outflow AS daily_net,
    base_inv + SUM(daily_inflow - daily_outflow) OVER (
        PARTITION BY site_code, model_code
        ORDER BY cal_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS boh_qty,
    ROUND(AVG(daily_inflow) OVER (
        PARTITION BY site_code, model_code
        ORDER BY cal_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) * 1.1) AS daily_cap_proxy
FROM daily;

COMMENT ON TABLE PGV_V_DAILY_LINK_BOH IS 'Rolling BOH — 링크 모델 날짜별 재고 (기초재고+입고-출고)';
PROMPT [1/3] PGV_V_DAILY_LINK_BOH 생성 완료


-- ============================================================
-- View 2: PGV_V_DAILY_PACK_BOH
-- ============================================================
PROMPT [2/3] PGV_V_DAILY_PACK_BOH 생성 중...

CREATE OR REPLACE VIEW PGV_V_DAILY_PACK_BOH AS
WITH base AS (
    SELECT site_code,
           pack_model_code AS model_code,
           base_date,
           inventory_qty   AS base_inv
    FROM PGV_INV_PACK
),
flows AS (
    -- 팩 생산 입고
    SELECT p.PRODUCTION_SITE_CODE AS site_code,
           p.PACK_MODEL_CODE      AS model_code,
           p.PRODUCTION_PLAN_DATE AS cal_date,
           p.PRODUCTION_PLAN_QTY  AS daily_inflow,
           0                      AS daily_outflow
    FROM PACK_PRODUCTION_PLAN p
    UNION ALL
    -- 팩 출하 출고
    SELECT s.SOURCE_SITE_CODE    AS site_code,
           s.PACK_MODEL_CODE     AS model_code,
           s.SHIPMENT_PLAN_DATE  AS cal_date,
           0                     AS daily_inflow,
           s.SHIPMENT_PLAN_QTY   AS daily_outflow
    FROM PACK_SHIPMENT_PLAN s
),
daily AS (
    SELECT f.site_code,
           f.model_code,
           f.cal_date,
           SUM(f.daily_inflow)  AS daily_inflow,
           SUM(f.daily_outflow) AS daily_outflow,
           b.base_inv,
           b.base_date
    FROM flows f
    JOIN base b
      ON b.site_code  = f.site_code
     AND b.model_code = f.model_code
    WHERE f.cal_date >= b.base_date
    GROUP BY f.site_code, f.model_code, f.cal_date, b.base_inv, b.base_date
)
SELECT
    site_code,
    model_code,
    cal_date,
    daily_inflow,
    daily_outflow,
    daily_inflow - daily_outflow AS daily_net,
    base_inv + SUM(daily_inflow - daily_outflow) OVER (
        PARTITION BY site_code, model_code
        ORDER BY cal_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS boh_qty,
    ROUND(AVG(daily_inflow) OVER (
        PARTITION BY site_code, model_code
        ORDER BY cal_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) * 1.1) AS daily_cap_proxy
FROM daily;

COMMENT ON TABLE PGV_V_DAILY_PACK_BOH IS 'Rolling BOH — 팩 모델 날짜별 재고 (기초재고+입고-출고)';
PROMPT [2/3] PGV_V_DAILY_PACK_BOH 생성 완료


-- ============================================================
-- View 3: PGV_V_DAILY_AEROGEL_BOH
-- ============================================================
PROMPT [3/3] PGV_V_DAILY_AEROGEL_BOH 생성 중...

CREATE OR REPLACE VIEW PGV_V_DAILY_AEROGEL_BOH AS
WITH base AS (
    SELECT site_code,
           material_code AS model_code,
           base_date,
           inventory_qty AS base_inv
    FROM PGV_INV_AEROGEL
),
flows AS (
    -- 에어로겔 입하 (AEROGEL_SHIPMENT_PLAN — 팩 사이트 도착 기준)
    SELECT s.DEST_SITE_CODE      AS site_code,
           s.MODEL_CODE          AS model_code,
           s.SHIPMENT_PLAN_DATE  AS cal_date,
           s.SHIPMENT_PLAN_QTY   AS daily_inflow,
           0                     AS daily_outflow
    FROM AEROGEL_SHIPMENT_PLAN s
    UNION ALL
    -- 에어로겔 소모 (팩 생산 BOM 역산: 팩생산qty × aerogel_qty_per_pack)
    SELECT p.PRODUCTION_SITE_CODE              AS site_code,
           ba.AEROGEL_MATERIAL_CODE            AS model_code,
           p.PRODUCTION_PLAN_DATE              AS cal_date,
           0                                   AS daily_inflow,
           p.PRODUCTION_PLAN_QTY
               * ba.AEROGEL_QTY_PER_PACK       AS daily_outflow
    FROM PACK_PRODUCTION_PLAN p
    JOIN BOM_PACK_AEROGEL ba
      ON ba.PACK_MODEL_CODE = p.PACK_MODEL_CODE
),
daily AS (
    SELECT f.site_code,
           f.model_code,
           f.cal_date,
           SUM(f.daily_inflow)  AS daily_inflow,
           SUM(f.daily_outflow) AS daily_outflow,
           b.base_inv,
           b.base_date
    FROM flows f
    JOIN base b
      ON b.site_code  = f.site_code
     AND b.model_code = f.model_code
    WHERE f.cal_date >= b.base_date
    GROUP BY f.site_code, f.model_code, f.cal_date, b.base_inv, b.base_date
)
SELECT
    site_code,
    model_code,
    cal_date,
    daily_inflow,
    daily_outflow,
    daily_inflow - daily_outflow AS daily_net,
    base_inv + SUM(daily_inflow - daily_outflow) OVER (
        PARTITION BY site_code, model_code
        ORDER BY cal_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS boh_qty,
    ROUND(AVG(daily_inflow) OVER (
        PARTITION BY site_code, model_code
        ORDER BY cal_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) * 1.1) AS daily_cap_proxy
FROM daily;

COMMENT ON TABLE PGV_V_DAILY_AEROGEL_BOH IS 'Rolling BOH — 에어로겔 날짜별 재고 (입하-BOM소모)';
PROMPT [3/3] PGV_V_DAILY_AEROGEL_BOH 생성 완료


-- ============================================================
-- 확인
-- ============================================================
PROMPT
PROMPT === 생성된 Rolling BOH View 목록 ===
SELECT view_name
FROM user_views
WHERE view_name IN (
    'PGV_V_DAILY_LINK_BOH',
    'PGV_V_DAILY_PACK_BOH',
    'PGV_V_DAILY_AEROGEL_BOH'
)
ORDER BY view_name;

PROMPT pgv_06_rolling_views.sql 완료
