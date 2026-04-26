-- ============================================================
-- pgv_04a_mviews.sql
-- SCM_PGV Property Graph — Materialized View 생성
-- ============================================================
-- 목적:
--   Oracle RAC 롤링 업그레이드 중에는 일반 View를 Property Graph
--   테이블로 사용할 수 없습니다 (ORA-42449).
--   Materialized View(MV)는 결과를 물리적으로 저장하므로
--   Property Graph가 일반 테이블처럼 인식합니다.
--
-- 네이밍:
--   PGV_MV_NODE_*  — Node MV (Property Graph Vertex 용)
--   PGV_MV_EDGE_*  — Edge MV (Property Graph Edge 용)
--   PGV_NODE_*     — 기존 View 유지 (Python 직접 쿼리 용)
--   PGV_EDGE_*     — 기존 View 유지 (Python 직접 쿼리 용)
--
-- 사전 요건:
--   pgv_01_node_views.sql, pgv_02_edge_views.sql 실행 완료
--
-- 실행 후:
--   pgv_04_create_graph.sql 에서 SCM_PGV 그래프 생성 (MV 기반)
-- ============================================================

SET ECHO ON
SET DEFINE OFF

PROMPT ============================================================
PROMPT pgv_04a_mviews.sql — Materialized View 생성 시작
PROMPT ============================================================


-- ============================================================
-- [공통 설명] MATERIALIZED VIEW란?
-- ============================================================
-- 일반 View  : SELECT 실행 시마다 원천 테이블을 실시간 조회
-- Materialized View(MV): SELECT 결과를 물리적으로 저장해 두고
--               REFRESH 시점에 한 번만 원천 테이블을 조회
--
-- Property Graph는 "실제 데이터가 있는 테이블"을 요구합니다.
-- MV는 내부적으로 테이블처럼 취급되므로 이 제약을 우회합니다.
--
-- REFRESH COMPLETE ON DEMAND:
--   수동으로 DBMS_MVIEW.REFRESH('PGV_MV_NODE_SITE') 호출 시 갱신.
--   원천 데이터(생산계획 등)가 바뀌면 refresh 해야 합니다.
-- ============================================================


-- ============================================================
-- NODE MV 1: PGV_MV_NODE_SITE
-- ============================================================
PROMPT [1/10] PGV_MV_NODE_SITE 생성 중...

BEGIN
    EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW PGV_MV_NODE_SITE';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE MATERIALIZED VIEW PGV_MV_NODE_SITE
    BUILD IMMEDIATE
    REFRESH COMPLETE ON DEMAND
AS
SELECT site_code, site_type, site_name
FROM PGV_NODE_SITE
;

COMMENT ON MATERIALIZED VIEW PGV_MV_NODE_SITE
    IS 'SCM_PGV PG Vertex용 MV — 사이트 노드 (Supplier/Pack/Link/Customer). KEY=site_code';

PROMPT [1/10] PGV_MV_NODE_SITE 완료


-- ============================================================
-- NODE MV 2: PGV_MV_NODE_MATERIAL
-- ============================================================
PROMPT [2/10] PGV_MV_NODE_MATERIAL 생성 중...

BEGIN
    EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW PGV_MV_NODE_MATERIAL';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE MATERIALIZED VIEW PGV_MV_NODE_MATERIAL
    BUILD IMMEDIATE
    REFRESH COMPLETE ON DEMAND
AS
SELECT model_code, material_type
FROM PGV_NODE_MATERIAL
;

COMMENT ON MATERIALIZED VIEW PGV_MV_NODE_MATERIAL
    IS 'SCM_PGV PG Vertex용 MV — 자재/제품 노드 (Link/Pack/Aerogel). KEY=model_code';

PROMPT [2/10] PGV_MV_NODE_MATERIAL 완료


-- ============================================================
-- EDGE MV 1: PGV_MV_EDGE_BOM_LP  (Link → Pack BOM)
-- ============================================================
PROMPT [3/10] PGV_MV_EDGE_BOM_LP 생성 중...

BEGIN EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW PGV_MV_EDGE_BOM_LP'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE MATERIALIZED VIEW PGV_MV_EDGE_BOM_LP
    BUILD IMMEDIATE REFRESH COMPLETE ON DEMAND
AS SELECT link_model_code, pack_model_code, pack_qty_per_link
   FROM PGV_EDGE_BOM_LP;

PROMPT [3/10] PGV_MV_EDGE_BOM_LP 완료


-- ============================================================
-- EDGE MV 2: PGV_MV_EDGE_BOM_PA  (Pack → Aerogel BOM)
-- ============================================================
PROMPT [4/10] PGV_MV_EDGE_BOM_PA 생성 중...

BEGIN EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW PGV_MV_EDGE_BOM_PA'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE MATERIALIZED VIEW PGV_MV_EDGE_BOM_PA
    BUILD IMMEDIATE REFRESH COMPLETE ON DEMAND
AS SELECT pack_model_code, aerogel_material_code, aerogel_qty_per_pack
   FROM PGV_EDGE_BOM_PA;

PROMPT [4/10] PGV_MV_EDGE_BOM_PA 완료


-- ============================================================
-- EDGE MV 3: PGV_MV_EDGE_SHIPS_TO  (사이트 간 운송 경로)
-- ============================================================
PROMPT [5/10] PGV_MV_EDGE_SHIPS_TO 생성 중...

BEGIN EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW PGV_MV_EDGE_SHIPS_TO'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE MATERIALIZED VIEW PGV_MV_EDGE_SHIPS_TO
    BUILD IMMEDIATE REFRESH COMPLETE ON DEMAND
AS SELECT source_site_code, dest_site_code, transport_mode, lead_time_days, incoterms
   FROM PGV_EDGE_SHIPS_TO;

PROMPT [5/10] PGV_MV_EDGE_SHIPS_TO 완료


-- ============================================================
-- EDGE MV 4: PGV_MV_EDGE_PACK_PROD  (팩 생산 계획)
-- ============================================================
PROMPT [6/10] PGV_MV_EDGE_PACK_PROD 생성 중...

BEGIN EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW PGV_MV_EDGE_PACK_PROD'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE MATERIALIZED VIEW PGV_MV_EDGE_PACK_PROD
    BUILD IMMEDIATE REFRESH COMPLETE ON DEMAND
AS SELECT production_site_code, pack_model_code, production_plan_date, production_plan_qty
   FROM PGV_EDGE_PACK_PROD;

PROMPT [6/10] PGV_MV_EDGE_PACK_PROD 완료


-- ============================================================
-- EDGE MV 5: PGV_MV_EDGE_LINK_PROD  (링크 생산 계획)
-- ============================================================
PROMPT [7/10] PGV_MV_EDGE_LINK_PROD 생성 중...

BEGIN EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW PGV_MV_EDGE_LINK_PROD'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE MATERIALIZED VIEW PGV_MV_EDGE_LINK_PROD
    BUILD IMMEDIATE REFRESH COMPLETE ON DEMAND
AS SELECT production_site_code, link_model_code, production_plan_date, production_plan_qty
   FROM PGV_EDGE_LINK_PROD;

PROMPT [7/10] PGV_MV_EDGE_LINK_PROD 완료


-- ============================================================
-- EDGE MV 6: PGV_MV_EDGE_PACK_SHIP  (팩 출하 계획)
-- ============================================================
PROMPT [8/10] PGV_MV_EDGE_PACK_SHIP 생성 중...

BEGIN EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW PGV_MV_EDGE_PACK_SHIP'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE MATERIALIZED VIEW PGV_MV_EDGE_PACK_SHIP
    BUILD IMMEDIATE REFRESH COMPLETE ON DEMAND
AS SELECT source_site_code, dest_site_code, pack_model_code, transport_mode, shipment_date, shipment_qty
   FROM PGV_EDGE_PACK_SHIP;

PROMPT [8/10] PGV_MV_EDGE_PACK_SHIP 완료


-- ============================================================
-- EDGE MV 7: PGV_MV_EDGE_LINK_SHIP  (링크 출하 → 고객)
-- ============================================================
PROMPT [9/10] PGV_MV_EDGE_LINK_SHIP 생성 중...

BEGIN EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW PGV_MV_EDGE_LINK_SHIP'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE MATERIALIZED VIEW PGV_MV_EDGE_LINK_SHIP
    BUILD IMMEDIATE REFRESH COMPLETE ON DEMAND
AS SELECT source_site_code, customer_site_code, link_model_code, shipment_date, shipment_qty
   FROM PGV_EDGE_LINK_SHIP;

PROMPT [9/10] PGV_MV_EDGE_LINK_SHIP 완료


-- ============================================================
-- EDGE MV 8: PGV_MV_EDGE_AEROGEL_SHIP  (Aerogel 출하)
-- ============================================================
PROMPT [10/10] PGV_MV_EDGE_AEROGEL_SHIP 생성 중...

BEGIN EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW PGV_MV_EDGE_AEROGEL_SHIP'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE MATERIALIZED VIEW PGV_MV_EDGE_AEROGEL_SHIP
    BUILD IMMEDIATE REFRESH COMPLETE ON DEMAND
AS SELECT source_site_code, dest_site_code, model_code, transport_mode, shipment_date, shipment_qty
   FROM PGV_EDGE_AEROGEL_SHIP;

PROMPT [10/10] PGV_MV_EDGE_AEROGEL_SHIP 완료


-- ============================================================
-- EDGE MV 9: PGV_MV_EDGE_ORDER_UNIT  (발주단위 제약)
-- ============================================================
PROMPT [11/11] PGV_MV_EDGE_ORDER_UNIT 생성 중...

BEGIN EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW PGV_MV_EDGE_ORDER_UNIT'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE MATERIALIZED VIEW PGV_MV_EDGE_ORDER_UNIT
    BUILD IMMEDIATE REFRESH COMPLETE ON DEMAND
AS SELECT source_site_code, dest_site_code, material_code, order_type, order_qty
   FROM PGV_EDGE_ORDER_UNIT;

PROMPT [11/11] PGV_MV_EDGE_ORDER_UNIT 완료


-- ============================================================
-- 생성 확인
-- ============================================================
PROMPT
PROMPT === 생성된 Materialized View 목록 및 행 수 ===
SELECT mview_name,
       last_refresh_date,
       staleness
FROM user_mviews
WHERE mview_name LIKE 'PGV_MV_%'
ORDER BY mview_name;

PROMPT pgv_04a_mviews.sql 완료
PROMPT 다음: pgv_04b_create_graph_mv.sql 실행
