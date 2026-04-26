-- ============================================================
-- pgv_02_edge_views.sql
-- SCM_PGV Property Graph — Edge View 생성 (9개)
-- ============================================================
-- 목적: 원천 테이블에서 그래프 Edge 역할을 하는 View 9개를 생성한다.
--       각 View는 SOURCE KEY, DESTINATION KEY 컬럼을 포함해야 한다.
--
-- Edge View 목록:
--   PGV_EDGE_BOM_LP       LINK_TO_PACK      BOM_LINK_PACK
--   PGV_EDGE_BOM_PA       PACK_TO_AEROGEL   BOM_PACK_AEROGEL
--   PGV_EDGE_SHIPS_TO     SHIPS_TO          LEAD_TIME_MASTER
--   PGV_EDGE_PACK_PROD    PACK_PRODUCES     PACK_PRODUCTION_PLAN
--   PGV_EDGE_LINK_PROD    LINK_PRODUCES     LINK_PRODUCTION_PLAN
--   PGV_EDGE_PACK_SHIP    PACK_SHIPS        PACK_SHIPMENT_PLAN
--   PGV_EDGE_LINK_SHIP    LINK_DELIVERS     LINK_SHIPMENT_PLAN
--   PGV_EDGE_AEROGEL_SHIP AEROGEL_SHIPS     AEROGEL_SHIPMENT_PLAN
--   PGV_EDGE_ORDER_UNIT   ORDER_UNIT        MATERIAL_ORDER_UNIT
-- ============================================================

SET ECHO ON
SET DEFINE OFF

PROMPT ============================================================
PROMPT pgv_02_edge_views.sql — Edge View 생성 시작
PROMPT ============================================================


-- ============================================================
-- Edge 1: PGV_EDGE_BOM_LP
-- ============================================================
-- Label  : LINK_TO_PACK
-- Source : link_model_code → PGV_NODE_MATERIAL (model_code)
-- Dest   : pack_model_code → PGV_NODE_MATERIAL (model_code)
-- 원천   : BOM_LINK_PACK
-- ============================================================

PROMPT [1/8] PGV_EDGE_BOM_LP 생성 중...

CREATE OR REPLACE VIEW PGV_EDGE_BOM_LP AS
SELECT
    LINK_MODEL_CODE                     AS link_model_code,    -- SOURCE KEY
    PACK_MODEL_CODE                     AS pack_model_code,    -- DESTINATION KEY
    PACK_QTY_PER_LINK                   AS pack_qty_per_link   -- 링크 1개당 팩 소요 수량
FROM BOM_LINK_PACK
;

COMMENT ON TABLE PGV_EDGE_BOM_LP IS 'SCM_PGV Edge — BOM Link→Pack (LINK_TO_PACK). SRC=link_model_code, DST=pack_model_code';

PROMPT [1/8] PGV_EDGE_BOM_LP 생성 완료


-- ============================================================
-- Edge 2: PGV_EDGE_BOM_PA
-- ============================================================
-- Label  : PACK_TO_AEROGEL
-- Source : pack_model_code → PGV_NODE_MATERIAL (model_code)
-- Dest   : aerogel_material_code → PGV_NODE_MATERIAL (model_code)
-- 원천   : BOM_PACK_AEROGEL
-- ============================================================

PROMPT [2/8] PGV_EDGE_BOM_PA 생성 중...

CREATE OR REPLACE VIEW PGV_EDGE_BOM_PA AS
SELECT
    PACK_MODEL_CODE                     AS pack_model_code,        -- SOURCE KEY
    AEROGEL_MATERIAL_CODE               AS aerogel_material_code,  -- DESTINATION KEY
    AEROGEL_QTY_PER_PACK                AS aerogel_qty_per_pack    -- 팩 1개당 Aerogel 소요 수량
FROM BOM_PACK_AEROGEL
;

COMMENT ON TABLE PGV_EDGE_BOM_PA IS 'SCM_PGV Edge — BOM Pack→Aerogel (PACK_TO_AEROGEL). SRC=pack_model_code, DST=aerogel_material_code';

PROMPT [2/8] PGV_EDGE_BOM_PA 생성 완료


-- ============================================================
-- Edge 3: PGV_EDGE_SHIPS_TO
-- ============================================================
-- Label  : SHIPS_TO
-- Source : source_site_code → PGV_NODE_SITE (site_code)
-- Dest   : dest_site_code   → PGV_NODE_SITE (site_code)
-- 원천   : LEAD_TIME_MASTER
-- KEY    : (source_site_code, dest_site_code, transport_mode) — 복합 유니크
-- ============================================================

PROMPT [3/8] PGV_EDGE_SHIPS_TO 생성 중...

CREATE OR REPLACE VIEW PGV_EDGE_SHIPS_TO AS
SELECT
    SOURCE_SITE_CODE                    AS source_site_code,  -- SOURCE KEY
    DEST_SITE_CODE                      AS dest_site_code,    -- DESTINATION KEY
    TRANSPORT_MODE                      AS transport_mode,    -- 운송 모드 (TRK/SEA/AIR)
    LEAD_TIME_DAYS                      AS lead_time_days,    -- 리드타임 (일)
    INCOTERMS                           AS incoterms          -- 인코텀즈
FROM LEAD_TIME_MASTER
;

COMMENT ON TABLE PGV_EDGE_SHIPS_TO IS 'SCM_PGV Edge — 사이트 간 운송 경로 (SHIPS_TO). SRC=source_site_code, DST=dest_site_code';

PROMPT [3/8] PGV_EDGE_SHIPS_TO 생성 완료


-- ============================================================
-- Edge 4: PGV_EDGE_PACK_PROD
-- ============================================================
-- Label  : PACK_PRODUCES
-- Source : production_site_code → PGV_NODE_SITE (site_code)
-- Dest   : pack_model_code      → PGV_NODE_MATERIAL (model_code)
-- 원천   : PACK_PRODUCTION_PLAN
-- KEY    : (production_site_code, pack_model_code, production_plan_date)
-- ============================================================

PROMPT [4/8] PGV_EDGE_PACK_PROD 생성 중...

CREATE OR REPLACE VIEW PGV_EDGE_PACK_PROD AS
SELECT
    PRODUCTION_SITE_CODE                AS production_site_code,    -- SOURCE KEY
    PACK_MODEL_CODE                     AS pack_model_code,         -- DESTINATION KEY
    PRODUCTION_PLAN_DATE                AS production_plan_date,    -- 생산 계획일
    PRODUCTION_PLAN_QTY                 AS production_plan_qty      -- 생산 계획 수량
FROM PACK_PRODUCTION_PLAN
;

COMMENT ON TABLE PGV_EDGE_PACK_PROD IS 'SCM_PGV Edge — 팩 생산 계획 (PACK_PRODUCES). SRC=production_site_code (Site), DST=pack_model_code (Material)';

PROMPT [4/8] PGV_EDGE_PACK_PROD 생성 완료


-- ============================================================
-- Edge 5: PGV_EDGE_LINK_PROD
-- ============================================================
-- Label  : LINK_PRODUCES
-- Source : production_site_code → PGV_NODE_SITE (site_code)
-- Dest   : link_model_code      → PGV_NODE_MATERIAL (model_code)
-- 원천   : LINK_PRODUCTION_PLAN
-- KEY    : (production_site_code, link_model_code, production_plan_date)
-- ============================================================

PROMPT [5/8] PGV_EDGE_LINK_PROD 생성 중...

CREATE OR REPLACE VIEW PGV_EDGE_LINK_PROD AS
SELECT
    PRODUCTION_SITE_CODE                AS production_site_code,  -- SOURCE KEY
    LINK_MODEL_CODE                     AS link_model_code,       -- DESTINATION KEY
    PRODUCTION_PLAN_DATE                AS production_plan_date,  -- 생산 계획일
    PRODUCTION_PLAN_QTY                 AS production_plan_qty    -- 생산 계획 수량
FROM LINK_PRODUCTION_PLAN
;

COMMENT ON TABLE PGV_EDGE_LINK_PROD IS 'SCM_PGV Edge — 링크 생산 계획 (LINK_PRODUCES). SRC=production_site_code (Site), DST=link_model_code (Material)';

PROMPT [5/8] PGV_EDGE_LINK_PROD 생성 완료


-- ============================================================
-- Edge 6: PGV_EDGE_PACK_SHIP
-- ============================================================
-- Label  : PACK_SHIPS
-- Source : source_site_code → PGV_NODE_SITE (site_code)
-- Dest   : dest_site_code   → PGV_NODE_SITE (site_code)
-- 원천   : PACK_SHIPMENT_PLAN
-- KEY    : (source_site_code, dest_site_code, pack_model_code, shipment_date)
--
-- 확인된 컬럼: SOURCE_SITE_CODE, DEST_SITE_CODE, PACK_MODEL_CODE,
--              TRANSPORT_MODE, SHIPMENT_PLAN_DATE, SHIPMENT_PLAN_QTY, CATEGORY
-- ============================================================

PROMPT [6/8] PGV_EDGE_PACK_SHIP 생성 중...

CREATE OR REPLACE VIEW PGV_EDGE_PACK_SHIP AS
SELECT
    SOURCE_SITE_CODE                    AS source_site_code,   -- SOURCE KEY
    DEST_SITE_CODE                      AS dest_site_code,     -- DESTINATION KEY
    PACK_MODEL_CODE                     AS pack_model_code,    -- 팩 모델코드
    TRANSPORT_MODE                      AS transport_mode,     -- 운송 모드
    SHIPMENT_PLAN_DATE                  AS shipment_date,      -- 출하 계획일
    SHIPMENT_PLAN_QTY                   AS shipment_qty        -- 출하 계획 수량
FROM PACK_SHIPMENT_PLAN
;

COMMENT ON TABLE PGV_EDGE_PACK_SHIP IS 'SCM_PGV Edge — 팩 출하 계획 (PACK_SHIPS). SRC=source_site_code, DST=dest_site_code';

PROMPT [6/8] PGV_EDGE_PACK_SHIP 생성 완료


-- ============================================================
-- Edge 7: PGV_EDGE_LINK_SHIP
-- ============================================================
-- Label  : LINK_DELIVERS
-- Source : source_site_code   → PGV_NODE_SITE (site_code)
-- Dest   : customer_site_code → PGV_NODE_SITE (site_code)
-- 원천   : LINK_SHIPMENT_PLAN
-- KEY    : (source_site_code, customer_site_code, link_model_code, shipment_date)
--
-- 확인된 컬럼: CUSTOMER_SITE_CODE, SOURCE_SITE_CODE, LINK_MODEL_CODE,
--              SHIPMENT_PLAN_DATE, SHIPMENT_PLAN_QTY, CATEGORY
-- ============================================================

PROMPT [7/8] PGV_EDGE_LINK_SHIP 생성 중...

CREATE OR REPLACE VIEW PGV_EDGE_LINK_SHIP AS
SELECT
    SOURCE_SITE_CODE                    AS source_site_code,    -- SOURCE KEY
    CUSTOMER_SITE_CODE                  AS customer_site_code,  -- DESTINATION KEY
    LINK_MODEL_CODE                     AS link_model_code,     -- 링크 모델코드
    SHIPMENT_PLAN_DATE                  AS shipment_date,       -- 출하 계획일
    SHIPMENT_PLAN_QTY                   AS shipment_qty         -- 출하 계획 수량
FROM LINK_SHIPMENT_PLAN
;

COMMENT ON TABLE PGV_EDGE_LINK_SHIP IS 'SCM_PGV Edge — 링크 출하 계획→고객 (LINK_DELIVERS). SRC=source_site_code, DST=customer_site_code';

PROMPT [7/8] PGV_EDGE_LINK_SHIP 생성 완료


-- ============================================================
-- Edge 8: PGV_EDGE_AEROGEL_SHIP
-- ============================================================
-- Label  : AEROGEL_SHIPS
-- Source : source_site_code → PGV_NODE_SITE (site_code)
-- Dest   : dest_site_code   → PGV_NODE_SITE (site_code)
-- 원천   : AEROGEL_SHIPMENT_PLAN
-- KEY    : (source_site_code, dest_site_code, shipment_date)
--
-- 확인된 컬럼: SOURCE_SITE_CODE, DEST_SITE_CODE, MODEL_CODE,
--              TRANSPORT_MODE, SHIPMENT_PLAN_DATE, SHIPMENT_PLAN_QTY, CATEGORY
-- ============================================================

PROMPT [8/8] PGV_EDGE_AEROGEL_SHIP 생성 중...

CREATE OR REPLACE VIEW PGV_EDGE_AEROGEL_SHIP AS
SELECT
    SOURCE_SITE_CODE                    AS source_site_code,  -- SOURCE KEY
    DEST_SITE_CODE                      AS dest_site_code,    -- DESTINATION KEY
    MODEL_CODE                          AS model_code,        -- Aerogel 자재코드 (예: MPD00001AA)
    TRANSPORT_MODE                      AS transport_mode,    -- 운송 모드 (Sea/Air)
    SHIPMENT_PLAN_DATE                  AS shipment_date,     -- 출하 계획일
    SHIPMENT_PLAN_QTY                   AS shipment_qty       -- 출하 계획 수량
FROM AEROGEL_SHIPMENT_PLAN
;

COMMENT ON TABLE PGV_EDGE_AEROGEL_SHIP IS 'SCM_PGV Edge — Aerogel 출하 계획 협력사→팩사이트 (AEROGEL_SHIPS). SRC=source_site_code, DST=dest_site_code';

PROMPT [8/8] PGV_EDGE_AEROGEL_SHIP 생성 완료


-- ============================================================
-- Edge 9: PGV_EDGE_ORDER_UNIT
-- ============================================================
-- Label  : ORDER_UNIT
-- Source : source_site_code → PGV_NODE_SITE (site_code)  (공급 사이트)
-- Dest   : dest_site_code   → PGV_NODE_SITE (site_code)  (발주 사이트)
-- 원천   : MATERIAL_ORDER_UNIT
-- KEY    : (source_site_code, dest_site_code, material_code, order_type)
-- 비고   : MOQ(최소 발주 수량) / MPU(배수 발주 단위) 구매 제약 정보
-- ============================================================

PROMPT [9/9] PGV_EDGE_ORDER_UNIT 생성 중...

CREATE OR REPLACE VIEW PGV_EDGE_ORDER_UNIT AS
SELECT
    SOURCE_SITE_CODE                    AS source_site_code,  -- SOURCE KEY
    DEST_SITE_CODE                      AS dest_site_code,    -- DESTINATION KEY
    MATERIAL_CODE                       AS material_code,     -- 자재코드
    ORDER_TYPE                          AS order_type,        -- MOQ / MPU
    ORDER_QTY                           AS order_qty          -- 발주 수량 제약
FROM MATERIAL_ORDER_UNIT
;

COMMENT ON TABLE PGV_EDGE_ORDER_UNIT IS 'SCM_PGV Edge — 자재 발주단위 제약 (ORDER_UNIT). SRC=source_site_code, DST=dest_site_code. MOQ/MPU 구매 제약 정보';

PROMPT [9/9] PGV_EDGE_ORDER_UNIT 생성 완료


-- ============================================================
-- 확인
-- ============================================================
PROMPT
PROMPT === 생성된 Edge View 목록 ===
SELECT view_name
FROM user_views
WHERE view_name IN (
    'PGV_EDGE_BOM_LP', 'PGV_EDGE_BOM_PA', 'PGV_EDGE_SHIPS_TO',
    'PGV_EDGE_PACK_PROD', 'PGV_EDGE_LINK_PROD', 'PGV_EDGE_PACK_SHIP',
    'PGV_EDGE_LINK_SHIP', 'PGV_EDGE_AEROGEL_SHIP', 'PGV_EDGE_ORDER_UNIT'
)
ORDER BY view_name;

PROMPT pgv_02_edge_views.sql 완료
