-- ============================================================
-- pgv_01_node_views.sql
-- SCM_PGV Property Graph — Node View 생성
-- ============================================================
-- 목적: 원천 테이블 13개를 수정하지 않고 View만으로
--       Oracle Property Graph의 Vertex를 정의한다.
--
-- 생성 View:
--   PGV_NODE_SITE     — 공급망 사이트 노드 (Supplier/Pack/Link/Customer)
--   PGV_NODE_MATERIAL — 자재/제품 노드 (Aerogel/Pack/Link)
--
-- 네이밍: PGV_NODE_<entity>
-- Graph : SCM_PGV (pgv_04_create_graph.sql 에서 정의)
-- ============================================================

SET ECHO ON
SET DEFINE OFF

PROMPT ============================================================
PROMPT pgv_01_node_views.sql — Node View 생성 시작
PROMPT ============================================================


-- ============================================================
-- View 1: PGV_NODE_SITE
-- ============================================================
-- 역할: 공급망에 참여하는 모든 사이트를 단일 노드 View로 통합.
--       원천 테이블의 사이트 코드를 UNION으로 파생한다.
--
-- site_type 구분:
--   Supplier  — AEROGEL_SHIPMENT_PLAN.SOURCE_SITE_CODE (협력사, 예: BYC)
--   Pack      — PACK_PRODUCTION_PLAN.PRODUCTION_SITE_CODE (팩 생산사이트)
--   Link      — LINK_PRODUCTION_PLAN.PRODUCTION_SITE_CODE (링크 생산사이트)
--   Customer  — LINK_SHIPMENT_PLAN.CUSTOMER_SITE_CODE (고객사이트)
--
-- KEY 컬럼: site_code  (Property Graph VERTEX KEY)
-- ============================================================

PROMPT [1/2] PGV_NODE_SITE 생성 중...

CREATE OR REPLACE VIEW PGV_NODE_SITE AS
SELECT
    site_code,
    site_type,
    site_name
FROM (
    -- Supplier: Aerogel 출하 출발지 (협력사)
    SELECT DISTINCT
        SOURCE_SITE_CODE            AS site_code,
        'Supplier'                  AS site_type,
        SOURCE_SITE_CODE            AS site_name   -- 사이트명 마스터 없음: site_code와 동일값 사용
    FROM AEROGEL_SHIPMENT_PLAN

    UNION

    -- Pack: 팩 생산사이트
    SELECT DISTINCT
        PRODUCTION_SITE_CODE        AS site_code,
        'Pack'                      AS site_type,
        PRODUCTION_SITE_CODE        AS site_name
    FROM PACK_PRODUCTION_PLAN

    UNION

    -- Link: 링크 생산사이트
    SELECT DISTINCT
        PRODUCTION_SITE_CODE        AS site_code,
        'Link'                      AS site_type,
        PRODUCTION_SITE_CODE        AS site_name
    FROM LINK_PRODUCTION_PLAN

    UNION

    -- Customer: 링크 출하 고객사이트
    SELECT DISTINCT
        CUSTOMER_SITE_CODE          AS site_code,
        'Customer'                  AS site_type,
        CUSTOMER_SITE_CODE          AS site_name
    FROM LINK_SHIPMENT_PLAN

    UNION

    -- Pack 출하 출발지/도착지도 사이트 노드에 포함
    SELECT DISTINCT
        SOURCE_SITE_CODE            AS site_code,
        'Pack'                      AS site_type,
        SOURCE_SITE_CODE            AS site_name
    FROM PACK_SHIPMENT_PLAN
    WHERE SOURCE_SITE_CODE NOT IN (
        SELECT DISTINCT PRODUCTION_SITE_CODE FROM PACK_PRODUCTION_PLAN
    )

    UNION

    SELECT DISTINCT
        DEST_SITE_CODE              AS site_code,
        'Link'                      AS site_type,
        DEST_SITE_CODE              AS site_name
    FROM PACK_SHIPMENT_PLAN
    WHERE DEST_SITE_CODE NOT IN (
        SELECT DISTINCT PRODUCTION_SITE_CODE FROM PACK_PRODUCTION_PLAN
        UNION
        SELECT DISTINCT PRODUCTION_SITE_CODE FROM LINK_PRODUCTION_PLAN
    )
)
;

COMMENT ON TABLE PGV_NODE_SITE IS 'SCM_PGV Property Graph — 사이트 노드 View (Supplier/Pack/Link/Customer). KEY=site_code';

PROMPT [1/2] PGV_NODE_SITE 생성 완료


-- ============================================================
-- View 2: PGV_NODE_MATERIAL
-- ============================================================
-- 역할: 공급망에서 다루는 모든 자재/제품을 단일 노드 View로 통합.
--       BOM 테이블에서 model_code + material_type을 파생한다.
--
-- material_type 구분:
--   Link    — BOM_LINK_PACK.LINK_MODEL_CODE
--   Pack    — BOM_LINK_PACK.PACK_MODEL_CODE (= BOM_PACK_AEROGEL.PACK_MODEL_CODE)
--   Aerogel — BOM_PACK_AEROGEL.AEROGEL_MATERIAL_CODE
--
-- KEY 컬럼: model_code  (Property Graph VERTEX KEY)
-- ============================================================

PROMPT [2/2] PGV_NODE_MATERIAL 생성 중...

CREATE OR REPLACE VIEW PGV_NODE_MATERIAL AS
SELECT
    model_code,
    material_type
FROM (
    -- Link 제품 (최상위 BOM)
    SELECT DISTINCT
        LINK_MODEL_CODE             AS model_code,
        'Link'                      AS material_type
    FROM BOM_LINK_PACK

    UNION

    -- Pack 부품 (중간 BOM)
    SELECT DISTINCT
        PACK_MODEL_CODE             AS model_code,
        'Pack'                      AS material_type
    FROM BOM_LINK_PACK

    UNION

    -- Aerogel 원자재 (최하위 BOM)
    SELECT DISTINCT
        AEROGEL_MATERIAL_CODE       AS model_code,
        'Aerogel'                   AS material_type
    FROM BOM_PACK_AEROGEL
)
;

COMMENT ON TABLE PGV_NODE_MATERIAL IS 'SCM_PGV Property Graph — 자재/제품 노드 View (Link/Pack/Aerogel). KEY=model_code';

PROMPT [2/2] PGV_NODE_MATERIAL 생성 완료


-- ============================================================
-- 확인
-- ============================================================
PROMPT
PROMPT === 생성된 Node View 목록 ===
SELECT view_name
FROM user_views
WHERE view_name IN ('PGV_NODE_SITE', 'PGV_NODE_MATERIAL')
ORDER BY view_name;

PROMPT
PROMPT === PGV_NODE_SITE 행 수 ===
SELECT site_type, COUNT(*) AS cnt
FROM PGV_NODE_SITE
GROUP BY site_type
ORDER BY site_type;

PROMPT
PROMPT === PGV_NODE_MATERIAL 행 수 ===
SELECT material_type, COUNT(*) AS cnt
FROM PGV_NODE_MATERIAL
GROUP BY material_type
ORDER BY material_type;

PROMPT pgv_01_node_views.sql 완료
