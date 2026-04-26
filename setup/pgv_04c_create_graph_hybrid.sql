-- ============================================================
-- pgv_04c_create_graph_hybrid.sql
-- SCM_PGV Property Graph DDL — 하이브리드 (Node MV + Edge 원천 직접)
-- ============================================================
-- 배경 및 근거 (docs/pgv_mv_role.md §"DB 실증 데이터" 참고):
--
--   [왜 Node MV가 필요한가]
--   - 사이트/자재 마스터 테이블 없음 → UNION DISTINCT 필수 → View 필요
--   - ORA-42449: RAC 롤링 업그레이드 중 View → PG 직접 참조 불가
--   - MV(=물리 스냅샷)로 UNION 결과를 저장해야만 그래프 Vertex로 사용 가능
--   - 실증: 고유 사이트 25개 (6개 원천 분산), 고유 자재 30개 (BOM 3개 분산)
--
--   [왜 Edge MV를 없앨 수 있는가]
--   - ORA-42449는 "View → PG 테이블" 경로에만 적용
--   - 원천 테이블(물리 테이블)은 ORA-42449 무관
--   - 실증: 9개 원천 Edge 테이블 모두 자연 키 중복 0건 → KEY 정의 가능
--
--   [효과]
--   - 현재: MV 11개 (Node 2 + Edge 9)
--   - 이 스크립트: MV 2개 (Node만) — Edge는 원천 테이블 직접 참조
--   - 복제 데이터: ~전체 원천 → 55행 (사이트 25 + 자재 30) 으로 축소
--
-- 주의: PROPERTIES ALL COLUMNS 사용 시 원천 테이블 컬럼명이 노출됨.
--   일부 컬럼은 Edge View에서 별칭이 있었음 (예: SHIPMENT_PLAN_DATE → shipment_date).
--   이 스크립트에서는 원천명 그대로 사용 → 기존 GRAPH_TABLE 쿼리 조정 필요.
--   (e.shipment_plan_date 로 참조, e.shipment_date 는 더 이상 불가)
--
-- 사전 요건:
--   pgv_04a_mviews.sql 에서 PGV_MV_NODE_SITE, PGV_MV_NODE_MATERIAL 생성 완료
--   (Edge MV PGV_MV_EDGE_* 는 없어도 됨)
--
-- 실행 유저: LGESSCM (또는 그래프 소유 유저)
-- ============================================================

SET ECHO ON
SET DEFINE OFF
SET SERVEROUTPUT ON

PROMPT ============================================================
PROMPT pgv_04c_create_graph_hybrid.sql — SCM_PGV 하이브리드 생성
PROMPT Node: PGV_MV_NODE_* (MV 유지)
PROMPT Edge: 원천 테이블 직접 참조 (MV 없음)
PROMPT ============================================================

BEGIN
    EXECUTE IMMEDIATE 'DROP PROPERTY GRAPH SCM_PGV';
    DBMS_OUTPUT.PUT_LINE('기존 SCM_PGV 삭제 완료');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE NOT IN (-42421, -40908) THEN RAISE; END IF;
        DBMS_OUTPUT.PUT_LINE('SCM_PGV 없음 — 새로 생성');
END;
/

CREATE OR REPLACE PROPERTY GRAPH SCM_PGV

  VERTEX TABLES (

    -- Node MV 유지: UNION DISTINCT 결과를 물리 저장 (ORA-42449 우회 필수)
    PGV_MV_NODE_SITE
      KEY (site_code)
      LABEL SITE
      PROPERTIES ALL COLUMNS,

    PGV_MV_NODE_MATERIAL
      KEY (model_code)
      LABEL MATERIAL
      PROPERTIES ALL COLUMNS

  )

  EDGE TABLES (

    -- ─── BOM 구조 ───────────────────────────────────────────
    -- [E1] Link → Pack (BOM_LINK_PACK)
    -- 원천 컬럼: LINK_MODEL_CODE, PACK_MODEL_CODE, PACK_QTY_PER_LINK
    BOM_LINK_PACK
      KEY (LINK_MODEL_CODE, PACK_MODEL_CODE)
      SOURCE KEY (LINK_MODEL_CODE)
        REFERENCES PGV_MV_NODE_MATERIAL (model_code)
      DESTINATION KEY (PACK_MODEL_CODE)
        REFERENCES PGV_MV_NODE_MATERIAL (model_code)
      LABEL LINK_TO_PACK
      PROPERTIES ALL COLUMNS,

    -- [E2] Pack → Aerogel (BOM_PACK_AEROGEL)
    -- 원천 컬럼: PACK_MODEL_CODE, AEROGEL_MATERIAL_CODE, AEROGEL_QTY_PER_PACK
    BOM_PACK_AEROGEL
      KEY (PACK_MODEL_CODE, AEROGEL_MATERIAL_CODE)
      SOURCE KEY (PACK_MODEL_CODE)
        REFERENCES PGV_MV_NODE_MATERIAL (model_code)
      DESTINATION KEY (AEROGEL_MATERIAL_CODE)
        REFERENCES PGV_MV_NODE_MATERIAL (model_code)
      LABEL PACK_TO_AEROGEL
      PROPERTIES ALL COLUMNS,

    -- ─── 운송 경로 ──────────────────────────────────────────
    -- [E3] Site → Site 운송 (LEAD_TIME_MASTER)
    -- 원천 컬럼: SOURCE_SITE_CODE, DEST_SITE_CODE, TRANSPORT_MODE, LEAD_TIME_DAYS, INCOTERMS
    LEAD_TIME_MASTER
      KEY (SOURCE_SITE_CODE, DEST_SITE_CODE, TRANSPORT_MODE)
      SOURCE KEY (SOURCE_SITE_CODE)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      DESTINATION KEY (DEST_SITE_CODE)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      LABEL SHIPS_TO
      PROPERTIES ALL COLUMNS,

    -- ─── 생산 계획 ──────────────────────────────────────────
    -- [E4] Pack Site → Pack 자재 (PACK_PRODUCTION_PLAN)
    -- 원천 컬럼: PRODUCTION_SITE_CODE, PACK_MODEL_CODE, PRODUCTION_PLAN_DATE, PRODUCTION_PLAN_QTY
    PACK_PRODUCTION_PLAN
      KEY (PRODUCTION_SITE_CODE, PACK_MODEL_CODE, PRODUCTION_PLAN_DATE)
      SOURCE KEY (PRODUCTION_SITE_CODE)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      DESTINATION KEY (PACK_MODEL_CODE)
        REFERENCES PGV_MV_NODE_MATERIAL (model_code)
      LABEL PACK_PRODUCES
      PROPERTIES ALL COLUMNS,

    -- [E5] Link Site → Link 자재 (LINK_PRODUCTION_PLAN)
    -- 원천 컬럼: PRODUCTION_SITE_CODE, LINK_MODEL_CODE, PRODUCTION_PLAN_DATE, PRODUCTION_PLAN_QTY
    LINK_PRODUCTION_PLAN
      KEY (PRODUCTION_SITE_CODE, LINK_MODEL_CODE, PRODUCTION_PLAN_DATE)
      SOURCE KEY (PRODUCTION_SITE_CODE)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      DESTINATION KEY (LINK_MODEL_CODE)
        REFERENCES PGV_MV_NODE_MATERIAL (model_code)
      LABEL LINK_PRODUCES
      PROPERTIES ALL COLUMNS,

    -- ─── 출하 계획 ──────────────────────────────────────────
    -- [E6] Pack 출하 Site → 납품 Site (PACK_SHIPMENT_PLAN)
    -- 원천 컬럼: SOURCE_SITE_CODE, DEST_SITE_CODE, PACK_MODEL_CODE,
    --            TRANSPORT_MODE, SHIPMENT_PLAN_DATE, SHIPMENT_PLAN_QTY, CATEGORY
    -- 주의: Edge View에서는 SHIPMENT_PLAN_DATE → shipment_date 로 별칭.
    --       GRAPH_TABLE 쿼리에서 e.shipment_plan_date 로 참조할 것.
    PACK_SHIPMENT_PLAN
      KEY (SOURCE_SITE_CODE, DEST_SITE_CODE, PACK_MODEL_CODE, SHIPMENT_PLAN_DATE)
      SOURCE KEY (SOURCE_SITE_CODE)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      DESTINATION KEY (DEST_SITE_CODE)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      LABEL PACK_SHIPS
      PROPERTIES ALL COLUMNS,

    -- [E7] Link 출하 Site → 고객 Site (LINK_SHIPMENT_PLAN)
    -- 원천 컬럼: SOURCE_SITE_CODE, CUSTOMER_SITE_CODE, LINK_MODEL_CODE,
    --            SHIPMENT_PLAN_DATE, SHIPMENT_PLAN_QTY, CATEGORY
    -- 주의: GRAPH_TABLE 쿼리에서 e.shipment_plan_date, dst_s = CUSTOMER_SITE_CODE 로 참조.
    LINK_SHIPMENT_PLAN
      KEY (SOURCE_SITE_CODE, CUSTOMER_SITE_CODE, LINK_MODEL_CODE, SHIPMENT_PLAN_DATE)
      SOURCE KEY (SOURCE_SITE_CODE)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      DESTINATION KEY (CUSTOMER_SITE_CODE)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      LABEL LINK_DELIVERS
      PROPERTIES ALL COLUMNS,

    -- [E8] Aerogel Supplier → Pack Site (AEROGEL_SHIPMENT_PLAN)
    -- 원천 컬럼: SOURCE_SITE_CODE, DEST_SITE_CODE, MODEL_CODE,
    --            TRANSPORT_MODE, SHIPMENT_PLAN_DATE, SHIPMENT_PLAN_QTY, CATEGORY
    -- 주의: GRAPH_TABLE 쿼리에서 e.shipment_plan_date 로 참조.
    AEROGEL_SHIPMENT_PLAN
      KEY (SOURCE_SITE_CODE, DEST_SITE_CODE, SHIPMENT_PLAN_DATE)
      SOURCE KEY (SOURCE_SITE_CODE)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      DESTINATION KEY (DEST_SITE_CODE)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      LABEL AEROGEL_SHIPS
      PROPERTIES ALL COLUMNS,

    -- ─── 발주 단위 제약 ─────────────────────────────────────
    -- [E9] 공급 Site → 발주 Site (MATERIAL_ORDER_UNIT)
    -- 원천 컬럼: SOURCE_SITE_CODE, DEST_SITE_CODE, MATERIAL_CODE, ORDER_TYPE, ORDER_QTY
    MATERIAL_ORDER_UNIT
      KEY (SOURCE_SITE_CODE, DEST_SITE_CODE, MATERIAL_CODE, ORDER_TYPE)
      SOURCE KEY (SOURCE_SITE_CODE)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      DESTINATION KEY (DEST_SITE_CODE)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      LABEL ORDER_UNIT
      PROPERTIES ALL COLUMNS

  )
;

PROMPT === 생성 결과 확인 ===
SELECT graph_name, num_vertex_tables, num_edge_tables
FROM user_property_graphs
WHERE graph_name = 'SCM_PGV';

PROMPT
PROMPT === Edge 원천 테이블 행 수 (MV 없이 직접) ===
SELECT 'BOM_LINK_PACK'         AS tbl, COUNT(*) AS cnt FROM BOM_LINK_PACK        UNION ALL
SELECT 'BOM_PACK_AEROGEL',            COUNT(*) FROM BOM_PACK_AEROGEL      UNION ALL
SELECT 'LEAD_TIME_MASTER',            COUNT(*) FROM LEAD_TIME_MASTER       UNION ALL
SELECT 'PACK_PRODUCTION_PLAN',        COUNT(*) FROM PACK_PRODUCTION_PLAN   UNION ALL
SELECT 'LINK_PRODUCTION_PLAN',        COUNT(*) FROM LINK_PRODUCTION_PLAN   UNION ALL
SELECT 'PACK_SHIPMENT_PLAN',          COUNT(*) FROM PACK_SHIPMENT_PLAN     UNION ALL
SELECT 'LINK_SHIPMENT_PLAN',          COUNT(*) FROM LINK_SHIPMENT_PLAN     UNION ALL
SELECT 'AEROGEL_SHIPMENT_PLAN',       COUNT(*) FROM AEROGEL_SHIPMENT_PLAN  UNION ALL
SELECT 'MATERIAL_ORDER_UNIT',         COUNT(*) FROM MATERIAL_ORDER_UNIT;

PROMPT
PROMPT === Node MV 행 수 ===
SELECT 'PGV_MV_NODE_SITE'     AS mv, COUNT(*) AS cnt FROM PGV_MV_NODE_SITE     UNION ALL
SELECT 'PGV_MV_NODE_MATERIAL',       COUNT(*) FROM PGV_MV_NODE_MATERIAL;

PROMPT
PROMPT pgv_04c_create_graph_hybrid.sql 완료
PROMPT MV 수: 2개 (Node만) — Edge MV 9개 제거됨
PROMPT GRAPH_TABLE 쿼리 유의: Edge 컬럼명은 원천 테이블 명칭 사용 (별칭 없음)
PROMPT   예) e.shipment_date → e.shipment_plan_date
