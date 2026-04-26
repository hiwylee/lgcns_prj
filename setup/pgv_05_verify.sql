-- ============================================================
-- pgv_05_verify.sql
-- SCM_PGV Property Graph 생성 검증
-- ============================================================
-- 목적: pgv_01~04 실행 후 View/Graph가 정상 생성됐는지 확인한다.
--
-- 검증 항목:
--   [A] 그래프 존재 확인
--   [B] Node View 행 수 확인
--   [C] Edge View 행 수 확인
--   [D] 그래프 요소(라벨) 목록
--   [E] 기본 GRAPH_TABLE 쿼리 테스트
-- ============================================================

SET ECHO ON
SET PAGESIZE 200
SET LINESIZE 300

PROMPT ============================================================
PROMPT pgv_05_verify.sql — SCM_PGV 검증 시작
PROMPT ============================================================


PROMPT ============================================================
PROMPT [A] Property Graph 존재 확인
PROMPT ============================================================

SELECT graph_name, owner
FROM user_property_graphs
WHERE graph_name = 'SCM_PGV';

-- 기대값: SCM_PGV 1건


PROMPT ============================================================
PROMPT [B] Node View 행 수 확인
PROMPT ============================================================

SELECT 'PGV_NODE_SITE'     AS view_name, site_type   AS category, COUNT(*) AS cnt
FROM PGV_NODE_SITE
GROUP BY site_type

UNION ALL

SELECT 'PGV_NODE_MATERIAL' AS view_name, material_type AS category, COUNT(*) AS cnt
FROM PGV_NODE_MATERIAL
GROUP BY material_type

ORDER BY view_name, category;

-- 기대값:
--   PGV_NODE_MATERIAL / Aerogel  : 1
--   PGV_NODE_MATERIAL / Link     : ~24
--   PGV_NODE_MATERIAL / Pack     : ~5
--   PGV_NODE_SITE / Customer     : ~20
--   PGV_NODE_SITE / Link         : 1
--   PGV_NODE_SITE / Pack         : ~3
--   PGV_NODE_SITE / Supplier     : 1


PROMPT ============================================================
PROMPT [C] Edge View 행 수 확인
PROMPT ============================================================

SELECT 'PGV_EDGE_BOM_LP'       AS view_name, COUNT(*) AS cnt FROM PGV_EDGE_BOM_LP
UNION ALL
SELECT 'PGV_EDGE_BOM_PA'       AS view_name, COUNT(*) AS cnt FROM PGV_EDGE_BOM_PA
UNION ALL
SELECT 'PGV_EDGE_SHIPS_TO'     AS view_name, COUNT(*) AS cnt FROM PGV_EDGE_SHIPS_TO
UNION ALL
SELECT 'PGV_EDGE_PACK_PROD'    AS view_name, COUNT(*) AS cnt FROM PGV_EDGE_PACK_PROD
UNION ALL
SELECT 'PGV_EDGE_LINK_PROD'    AS view_name, COUNT(*) AS cnt FROM PGV_EDGE_LINK_PROD
UNION ALL
SELECT 'PGV_EDGE_PACK_SHIP'    AS view_name, COUNT(*) AS cnt FROM PGV_EDGE_PACK_SHIP
UNION ALL
SELECT 'PGV_EDGE_LINK_SHIP'    AS view_name, COUNT(*) AS cnt FROM PGV_EDGE_LINK_SHIP
UNION ALL
SELECT 'PGV_EDGE_AEROGEL_SHIP' AS view_name, COUNT(*) AS cnt FROM PGV_EDGE_AEROGEL_SHIP
ORDER BY view_name;

-- 기대값:
--   PGV_EDGE_BOM_LP       : ~28   (BOM_LINK_PACK 건수)
--   PGV_EDGE_BOM_PA       : ~6    (BOM_PACK_AEROGEL 건수)
--   PGV_EDGE_SHIPS_TO     : ~22   (LEAD_TIME_MASTER 건수)
--   PGV_EDGE_PACK_PROD    : ~178  (PACK_PRODUCTION_PLAN 건수)
--   PGV_EDGE_LINK_PROD    : ~230  (LINK_PRODUCTION_PLAN 건수)
--   PGV_EDGE_PACK_SHIP    : ~178  (PACK_SHIPMENT_PLAN 건수)
--   PGV_EDGE_LINK_SHIP    : ~140  (LINK_SHIPMENT_PLAN 건수)
--   PGV_EDGE_AEROGEL_SHIP : ~4    (AEROGEL_SHIPMENT_PLAN 건수)


PROMPT ============================================================
PROMPT [D] SCM_PGV 그래프 요소(라벨) 목록
PROMPT ============================================================

SELECT ELEMENT_KIND, ELEMENT_NAME, PROPERTY_NAME, PROPERTY_TYPE
FROM USER_PROPERTY_GRAPH_ELEMENTS
WHERE GRAPH_NAME = 'SCM_PGV'
ORDER BY ELEMENT_KIND, ELEMENT_NAME, PROPERTY_NAME;


PROMPT ============================================================
PROMPT [E] GRAPH_TABLE 기본 쿼리 테스트
PROMPT ============================================================

PROMPT --- E1: SITE 노드 샘플 ---
SELECT * FROM GRAPH_TABLE (SCM_PGV
    MATCH (s IS SITE)
    COLUMNS (s.site_code, s.site_type)
) FETCH FIRST 5 ROWS ONLY;

PROMPT --- E2: MATERIAL 노드 샘플 ---
SELECT * FROM GRAPH_TABLE (SCM_PGV
    MATCH (m IS MATERIAL)
    COLUMNS (m.model_code, m.material_type)
) FETCH FIRST 5 ROWS ONLY;

PROMPT --- E3: BOM 2-hop (Link → Pack → Aerogel) ---
SELECT * FROM GRAPH_TABLE (SCM_PGV
    MATCH (link IS MATERIAL) -[b1 IS LINK_TO_PACK]-> (pack IS MATERIAL) -[b2 IS PACK_TO_AEROGEL]-> (aerogel IS MATERIAL)
    COLUMNS (
        link.model_code         AS link_code,
        pack.model_code         AS pack_code,
        b1.pack_qty_per_link    AS pack_per_link,
        aerogel.model_code      AS aerogel_code,
        b2.aerogel_qty_per_pack AS aerogel_per_pack,
        b1.pack_qty_per_link * b2.aerogel_qty_per_pack AS total_aerogel_per_link
    )
) FETCH FIRST 10 ROWS ONLY;

PROMPT --- E4: 운송 경로 1-hop (SHIPS_TO) ---
SELECT * FROM GRAPH_TABLE (SCM_PGV
    MATCH (s IS SITE) -[e IS SHIPS_TO]-> (d IS SITE)
    COLUMNS (
        s.site_code         AS src,
        s.site_type         AS src_type,
        d.site_code         AS dst,
        d.site_type         AS dst_type,
        e.transport_mode    AS mode,
        e.lead_time_days    AS lt_days
    )
) FETCH FIRST 10 ROWS ONLY;

PROMPT --- E5: Aerogel → Pack Site → Link Site (2-hop SHIPS_TO) ---
SELECT * FROM GRAPH_TABLE (SCM_PGV
    MATCH (supplier IS SITE) -[e1 IS AEROGEL_SHIPS]-> (pack_site IS SITE) -[e2 IS PACK_SHIPS]-> (link_site IS SITE)
    COLUMNS (
        supplier.site_code  AS supplier,
        pack_site.site_code AS pack_site,
        link_site.site_code AS link_site,
        e1.transport_mode   AS mode1,
        e2.transport_mode   AS mode2
    )
) FETCH FIRST 10 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT pgv_05_verify.sql 검증 완료
PROMPT ============================================================
EXIT;
