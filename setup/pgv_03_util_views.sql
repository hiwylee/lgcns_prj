-- ============================================================
-- pgv_03_util_views.sql
-- SCM_PGV — 인벤토리 유틸 View 생성 (Property Graph 비포함)
-- ============================================================
-- 목적: Property Graph에는 포함하지 않지만 Python backend에서
--       직접 SELECT 쿼리에 사용할 유틸 View 4개를 생성한다.
--
-- 생성 View:
--   PGV_INV_AEROGEL  — Aerogel 기초재고
--   PGV_INV_PACK     — 팩 기초재고
--   PGV_INV_LINK     — 링크 기초재고
--   PGV_INV_TRANSIT  — 운송중 재고 (In-Transit Inventory)
--
-- 이 View들은 pgv_04_create_graph.sql 의 VERTEX/EDGE TABLE 에
-- 포함하지 않는다. Python에서 `SELECT * FROM PGV_INV_*` 로 직접 조회.
-- ============================================================

SET ECHO ON
SET DEFINE OFF

PROMPT ============================================================
PROMPT pgv_03_util_views.sql — 인벤토리 유틸 View 생성 시작
PROMPT ============================================================


-- ============================================================
-- View 1: PGV_INV_AEROGEL
-- ============================================================
-- 원천: AEROGEL_BASE_INVENTORY
--
-- 확인된 컬럼 (supply_chain_data_overview.md 기준):
--   SITE_CODE, MATERIAL_CODE, BASE_DATE, INVENTORY_QTY
--
-- DB DESC 확인 완료
--       특히 MATERIAL_CODE vs AEROGEL_MATERIAL_CODE 여부
-- ============================================================

PROMPT [1/4] PGV_INV_AEROGEL 생성 중...

CREATE OR REPLACE VIEW PGV_INV_AEROGEL AS
SELECT
    SITE_CODE                           AS site_code,         -- 재고 보유 사이트
    MATERIAL_CODE                       AS material_code,     -- Aerogel 자재코드
    BASE_DATE                           AS base_date,         -- 기초재고 기준일
    INVENTORY_QTY                       AS inventory_qty      -- 기초재고 수량
FROM AEROGEL_BASE_INVENTORY
;

COMMENT ON TABLE PGV_INV_AEROGEL IS 'SCM_PGV 유틸 — Aerogel 기초재고 View (AEROGEL_BASE_INVENTORY 기반). PG 비포함.';

PROMPT [1/4] PGV_INV_AEROGEL 생성 완료


-- ============================================================
-- View 2: PGV_INV_PACK
-- ============================================================
-- 원천: PACK_BASE_INVENTORY
--
-- 확인된 컬럼 (supply_chain_data_overview.md 기준):
--   SITE_CODE, PACK_MODEL (또는 PACK_MODEL_CODE), BASE_DATE, QTY (또는 INVENTORY_QTY)
--
-- DB DESC 확인 완료
-- ============================================================

PROMPT [2/4] PGV_INV_PACK 생성 중...

CREATE OR REPLACE VIEW PGV_INV_PACK AS
SELECT
    SITE_CODE                           AS site_code,         -- 재고 보유 사이트
    PACK_MODEL_CODE                     AS pack_model_code,   -- 팩 모델코드
    BASE_DATE                           AS base_date,         -- 기초재고 기준일
    INVENTORY_QTY                       AS inventory_qty      -- 기초재고 수량
FROM PACK_BASE_INVENTORY
;

COMMENT ON TABLE PGV_INV_PACK IS 'SCM_PGV 유틸 — 팩 기초재고 View (PACK_BASE_INVENTORY 기반). PG 비포함.';

PROMPT [2/4] PGV_INV_PACK 생성 완료


-- ============================================================
-- View 3: PGV_INV_LINK
-- ============================================================
-- 원천: LINK_BASE_INVENTORY
--
-- 확인된 컬럼 (supply_chain_data_overview.md 기준):
--   PRODUCTION_SITE (또는 SITE_CODE), LINK_MODEL (또는 LINK_MODEL_CODE),
--   BASE_DATE, QTY (또는 INVENTORY_QTY)
--
-- DB DESC 확인 완료
--       특히 PRODUCTION_SITE vs SITE_CODE,
--            LINK_MODEL vs LINK_MODEL_CODE
-- ============================================================

PROMPT [3/4] PGV_INV_LINK 생성 중...

CREATE OR REPLACE VIEW PGV_INV_LINK AS
SELECT
    PRODUCTION_SITE_CODE                AS site_code,         -- 재고 보유 사이트
    LINK_MODEL_CODE                     AS link_model_code,   -- 링크 모델코드
    BASE_DATE                           AS base_date,         -- 기초재고 기준일
    INVENTORY_QTY                       AS inventory_qty      -- 기초재고 수량
FROM LINK_BASE_INVENTORY
;

COMMENT ON TABLE PGV_INV_LINK IS 'SCM_PGV 유틸 — 링크 기초재고 View (LINK_BASE_INVENTORY 기반). PG 비포함.';

PROMPT [3/4] PGV_INV_LINK 생성 완료


-- ============================================================
-- View 4: PGV_INV_TRANSIT
-- ============================================================
-- 원천: IN_TRANSIT_INVENTORY
--
-- 확인된 컬럼 (supply_chain_data_overview.md 기준):
--   SOURCE_SITE, DEST_SITE, MODEL (자재/모델코드), BASE_DATE, QTY
--
-- DB DESC 확인 완료
--       특히 SOURCE_SITE vs SOURCE_SITE_CODE,
--            MODEL vs MODEL_CODE,
--            QTY vs TRANSIT_QTY vs INVENTORY_QTY
-- ============================================================

PROMPT [4/4] PGV_INV_TRANSIT 생성 중...

CREATE OR REPLACE VIEW PGV_INV_TRANSIT AS
SELECT
    SOURCE_SITE_CODE                    AS source_site_code,  -- 출발 사이트
    DEST_SITE_CODE                      AS dest_site_code,    -- 도착 사이트
    LINK_MODEL_CODE                     AS model_code,        -- 링크 모델코드
    BASE_DATE                           AS base_date,         -- 기준일
    IN_TRANSIT_QTY                      AS transit_qty        -- 운송중 수량
FROM IN_TRANSIT_INVENTORY
;

COMMENT ON TABLE PGV_INV_TRANSIT IS 'SCM_PGV 유틸 — 운송중 재고 View (IN_TRANSIT_INVENTORY 기반). PG 비포함.';

PROMPT [4/4] PGV_INV_TRANSIT 생성 완료


-- ============================================================
-- 확인
-- ============================================================
PROMPT
PROMPT === 생성된 유틸 View 목록 ===
SELECT view_name
FROM user_views
WHERE view_name IN (
    'PGV_INV_AEROGEL', 'PGV_INV_PACK',
    'PGV_INV_LINK',    'PGV_INV_TRANSIT'
)
ORDER BY view_name;

PROMPT pgv_03_util_views.sql 완료
