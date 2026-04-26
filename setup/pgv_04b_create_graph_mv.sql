-- ============================================================
-- pgv_04b_create_graph_mv.sql
-- SCM_PGV Property Graph DDL — Materialized View 기반
-- ============================================================
-- 배경:
--   Oracle RAC 롤링 업그레이드 중 ORA-42449 발생으로
--   일반 View를 Property Graph 테이블로 사용 불가.
--   pgv_04a_mviews.sql 에서 생성한 PGV_MV_* MV를 대신 사용.
--
-- 사전 요건:
--   pgv_01_node_views.sql  실행 완료 (PGV_NODE_*)
--   pgv_02_edge_views.sql  실행 완료 (PGV_EDGE_*)
--   pgv_04a_mviews.sql     실행 완료 (PGV_MV_*)
-- ============================================================

SET ECHO ON
SET DEFINE OFF

PROMPT ============================================================
PROMPT pgv_04b_create_graph_mv.sql — SCM_PGV (MV 기반) 생성 시작
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

    PGV_MV_EDGE_BOM_LP
      KEY (link_model_code, pack_model_code)
      SOURCE KEY (link_model_code)
        REFERENCES PGV_MV_NODE_MATERIAL (model_code)
      DESTINATION KEY (pack_model_code)
        REFERENCES PGV_MV_NODE_MATERIAL (model_code)
      LABEL LINK_TO_PACK
      PROPERTIES ALL COLUMNS,

    PGV_MV_EDGE_BOM_PA
      KEY (pack_model_code, aerogel_material_code)
      SOURCE KEY (pack_model_code)
        REFERENCES PGV_MV_NODE_MATERIAL (model_code)
      DESTINATION KEY (aerogel_material_code)
        REFERENCES PGV_MV_NODE_MATERIAL (model_code)
      LABEL PACK_TO_AEROGEL
      PROPERTIES ALL COLUMNS,

    PGV_MV_EDGE_SHIPS_TO
      KEY (source_site_code, dest_site_code, transport_mode)
      SOURCE KEY (source_site_code)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      DESTINATION KEY (dest_site_code)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      LABEL SHIPS_TO
      PROPERTIES ALL COLUMNS,

    PGV_MV_EDGE_PACK_PROD
      KEY (production_site_code, pack_model_code, production_plan_date)
      SOURCE KEY (production_site_code)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      DESTINATION KEY (pack_model_code)
        REFERENCES PGV_MV_NODE_MATERIAL (model_code)
      LABEL PACK_PRODUCES
      PROPERTIES ALL COLUMNS,

    PGV_MV_EDGE_LINK_PROD
      KEY (production_site_code, link_model_code, production_plan_date)
      SOURCE KEY (production_site_code)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      DESTINATION KEY (link_model_code)
        REFERENCES PGV_MV_NODE_MATERIAL (model_code)
      LABEL LINK_PRODUCES
      PROPERTIES ALL COLUMNS,

    PGV_MV_EDGE_PACK_SHIP
      KEY (source_site_code, dest_site_code, pack_model_code, shipment_date)
      SOURCE KEY (source_site_code)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      DESTINATION KEY (dest_site_code)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      LABEL PACK_SHIPS
      PROPERTIES ALL COLUMNS,

    PGV_MV_EDGE_LINK_SHIP
      KEY (source_site_code, customer_site_code, link_model_code, shipment_date)
      SOURCE KEY (source_site_code)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      DESTINATION KEY (customer_site_code)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      LABEL LINK_DELIVERS
      PROPERTIES ALL COLUMNS,

    PGV_MV_EDGE_AEROGEL_SHIP
      KEY (source_site_code, dest_site_code, shipment_date)
      SOURCE KEY (source_site_code)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      DESTINATION KEY (dest_site_code)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      LABEL AEROGEL_SHIPS
      PROPERTIES ALL COLUMNS,

    PGV_MV_EDGE_ORDER_UNIT
      KEY (source_site_code, dest_site_code, material_code, order_type)
      SOURCE KEY (source_site_code)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      DESTINATION KEY (dest_site_code)
        REFERENCES PGV_MV_NODE_SITE (site_code)
      LABEL ORDER_UNIT
      PROPERTIES ALL COLUMNS

  )
;

PROMPT SCM_PGV 생성 완료

SELECT graph_name FROM user_property_graphs WHERE graph_name = 'SCM_PGV';

PROMPT pgv_04b_create_graph_mv.sql 완료
