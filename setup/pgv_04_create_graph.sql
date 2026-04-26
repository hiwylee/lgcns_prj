-- ============================================================
-- pgv_04_create_graph.sql
-- SCM_PGV Property Graph DDL
-- ============================================================
-- 목적: pgv_01~03 에서 생성한 View를 토대로
--       Oracle Property Graph SCM_PGV를 정의한다.
--
-- 사전 요건:
--   pgv_01_node_views.sql 실행 완료 (PGV_NODE_SITE, PGV_NODE_MATERIAL)
--   pgv_02_edge_views.sql 실행 완료 (PGV_EDGE_* 8개)
--
-- 기존 그래프 LGES_SCM_PG와 구별하기 위해 SCM_PGV 사용.
-- 원천 테이블/기존 PG_*/V_* 객체는 수정·삭제하지 않는다.
--
-- 실행:
--   SQLcl> @pgv_04_create_graph.sql
-- ============================================================

SET ECHO ON
SET DEFINE OFF

PROMPT ============================================================
PROMPT pgv_04_create_graph.sql — SCM_PGV Property Graph 생성 시작
PROMPT ============================================================

-- 기존 SCM_PGV 그래프가 있으면 먼저 DROP (재실행 안전)
BEGIN
    EXECUTE IMMEDIATE 'DROP PROPERTY GRAPH SCM_PGV';
    DBMS_OUTPUT.PUT_LINE('기존 SCM_PGV 그래프 삭제 완료');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -40908 THEN   -- ORA-40908: property graph not found
            RAISE;
        END IF;
        DBMS_OUTPUT.PUT_LINE('SCM_PGV 그래프 없음 — 새로 생성합니다');
END;
/

PROMPT SCM_PGV Property Graph 생성 중...

CREATE OR REPLACE PROPERTY GRAPH SCM_PGV
  -- ============================================================
  -- VERTEX TABLES
  -- ============================================================
  VERTEX TABLES (

    -- [V1] 사이트 노드: Supplier / Pack / Link / Customer
    PGV_NODE_SITE
      KEY (site_code)
      LABEL SITE
      PROPERTIES ALL COLUMNS,

    -- [V2] 자재/제품 노드: Link / Pack / Aerogel
    PGV_NODE_MATERIAL
      KEY (model_code)
      LABEL MATERIAL
      PROPERTIES ALL COLUMNS

  )

  -- ============================================================
  -- EDGE TABLES
  -- ============================================================
  EDGE TABLES (

    -- [E1] BOM: Link → Pack (Material → Material)
    PGV_EDGE_BOM_LP
      KEY (link_model_code, pack_model_code)
      SOURCE KEY (link_model_code)
        REFERENCES PGV_NODE_MATERIAL (model_code)
      DESTINATION KEY (pack_model_code)
        REFERENCES PGV_NODE_MATERIAL (model_code)
      LABEL LINK_TO_PACK
      PROPERTIES ALL COLUMNS,

    -- [E2] BOM: Pack → Aerogel (Material → Material)
    PGV_EDGE_BOM_PA
      KEY (pack_model_code, aerogel_material_code)
      SOURCE KEY (pack_model_code)
        REFERENCES PGV_NODE_MATERIAL (model_code)
      DESTINATION KEY (aerogel_material_code)
        REFERENCES PGV_NODE_MATERIAL (model_code)
      LABEL PACK_TO_AEROGEL
      PROPERTIES ALL COLUMNS,

    -- [E3] 운송 경로: Site → Site (리드타임 마스터)
    PGV_EDGE_SHIPS_TO
      KEY (source_site_code, dest_site_code, transport_mode)
      SOURCE KEY (source_site_code)
        REFERENCES PGV_NODE_SITE (site_code)
      DESTINATION KEY (dest_site_code)
        REFERENCES PGV_NODE_SITE (site_code)
      LABEL SHIPS_TO
      PROPERTIES ALL COLUMNS,

    -- [E4] 팩 생산: Pack Site → Pack Material
    PGV_EDGE_PACK_PROD
      KEY (production_site_code, pack_model_code, production_plan_date)
      SOURCE KEY (production_site_code)
        REFERENCES PGV_NODE_SITE (site_code)
      DESTINATION KEY (pack_model_code)
        REFERENCES PGV_NODE_MATERIAL (model_code)
      LABEL PACK_PRODUCES
      PROPERTIES ALL COLUMNS,

    -- [E5] 링크 생산: Link Site → Link Material
    PGV_EDGE_LINK_PROD
      KEY (production_site_code, link_model_code, production_plan_date)
      SOURCE KEY (production_site_code)
        REFERENCES PGV_NODE_SITE (site_code)
      DESTINATION KEY (link_model_code)
        REFERENCES PGV_NODE_MATERIAL (model_code)
      LABEL LINK_PRODUCES
      PROPERTIES ALL COLUMNS,

    -- [E6] 팩 출하: Pack Site → Link Site
    PGV_EDGE_PACK_SHIP
      KEY (source_site_code, dest_site_code, pack_model_code, shipment_date)
      SOURCE KEY (source_site_code)
        REFERENCES PGV_NODE_SITE (site_code)
      DESTINATION KEY (dest_site_code)
        REFERENCES PGV_NODE_SITE (site_code)
      LABEL PACK_SHIPS
      PROPERTIES ALL COLUMNS,

    -- [E7] 링크 출하: Link Site → Customer Site
    PGV_EDGE_LINK_SHIP
      KEY (source_site_code, customer_site_code, link_model_code, shipment_date)
      SOURCE KEY (source_site_code)
        REFERENCES PGV_NODE_SITE (site_code)
      DESTINATION KEY (customer_site_code)
        REFERENCES PGV_NODE_SITE (site_code)
      LABEL LINK_DELIVERS
      PROPERTIES ALL COLUMNS,

    -- [E8] Aerogel 출하: Supplier → Pack Site
    PGV_EDGE_AEROGEL_SHIP
      KEY (source_site_code, dest_site_code, shipment_date)
      SOURCE KEY (source_site_code)
        REFERENCES PGV_NODE_SITE (site_code)
      DESTINATION KEY (dest_site_code)
        REFERENCES PGV_NODE_SITE (site_code)
      LABEL AEROGEL_SHIPS
      PROPERTIES ALL COLUMNS,

    -- [E9] 발주단위 제약: Site → Site (MOQ/MPU)
    PGV_EDGE_ORDER_UNIT
      KEY (source_site_code, dest_site_code, material_code, order_type)
      SOURCE KEY (source_site_code)
        REFERENCES PGV_NODE_SITE (site_code)
      DESTINATION KEY (dest_site_code)
        REFERENCES PGV_NODE_SITE (site_code)
      LABEL ORDER_UNIT
      PROPERTIES ALL COLUMNS

  )
;

PROMPT SCM_PGV Property Graph 생성 완료

-- 생성 확인
PROMPT
PROMPT === 등록된 Property Graph ===
SELECT graph_name FROM user_property_graphs WHERE graph_name = 'SCM_PGV';

PROMPT
PROMPT === SCM_PGV Vertex/Edge 라벨 목록 ===
SELECT ELEMENT_KIND, ELEMENT_NAME, PROPERTY_NAME, PROPERTY_TYPE
FROM USER_PROPERTY_GRAPH_ELEMENTS
WHERE GRAPH_NAME = 'SCM_PGV'
ORDER BY ELEMENT_KIND, ELEMENT_NAME, PROPERTY_NAME;

PROMPT pgv_04_create_graph.sql 완료
