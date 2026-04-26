# SCM_PGV — 물리 테이블 없이 Property Graph 구성 가능 여부 검토

> **목적**: 고객(의사결정자 · DBA · 보안 담당자) 미팅용 설명 자료  
> **핵심 메시지**: 원천 데이터를 건드리지 않는다. 신규 물리 테이블을 만들지 않고도 Oracle 26ai Property Graph를 구성할 수 있다.

---

## 1. 결론 요약

| 질문 | 답변 |
|------|------|
| 신규 물리 테이블을 만들어야 하는가? | **아니오.** 모든 객체는 SQL View로만 생성 |
| 원천 테이블을 수정해야 하는가? | **아니오.** 읽기 전용 SELECT만 사용 |
| 현재 Materialized View(MV)는 영구적인가? | **아니오.** Oracle RAC 업그레이드 완료 후 전량 제거 예정 |
| 신규 ETL 파이프라인이 필요한가? | **아니오.** `DBMS_MVIEW.REFRESH` 단일 PL/SQL 호출 1건이 전부 |

---

## 2. 배경 — 왜 이 검토가 필요한가

배터리 공급망 SCM 시스템에는 13개의 운영 테이블이 있다. 이 위에 **Oracle 26ai Property Graph** 기반 자연어 질의(NL2SQL) 시스템을 구축할 때, 고객의 핵심 요구사항은 다음과 같다.

- 원천 운영 테이블 **수정 금지**
- 대량 데이터 **복제 최소화**
- 별도 ETL 파이프라인 **신설 금지**
- OLTP 성능에 **영향 없음**

이 요구사항을 모두 만족하면서 Property Graph를 구성할 수 있는지를 검토한 결과, **SQL View 기반 구성이 가능**하다는 결론을 얻었다.

---

## 3. 데이터 레이어 구조

```
┌─────────────────────────────────────────┐
│  운영 테이블 13개 (OLTP)                 │  ← 수정·쓰기 없음 (고객 원칙)
│  - BOM_LINK_PACK                        │
│  - BOM_PACK_AEROGEL                     │
│  - LEAD_TIME_MASTER                     │
│  - PACK/LINK_PRODUCTION_PLAN            │
│  - PACK/LINK/AEROGEL_SHIPMENT_PLAN      │
│  - AEROGEL/PACK/LINK_BASE_INVENTORY     │
│  - IN_TRANSIT_INVENTORY                 │
│  - MATERIAL_ORDER_UNIT                  │
└──────────────────┬──────────────────────┘
                   │  읽기 전용 SELECT
                   ▼
┌─────────────────────────────────────────┐
│  SQL View 15개 (메타데이터만, 저장 공간 0)│
│  - PGV_NODE_SITE        (노드: 사이트)   │
│  - PGV_NODE_MATERIAL    (노드: 자재)     │
│  - PGV_EDGE_BOM_LP      (엣지: BOM)     │
│  - PGV_EDGE_SHIPS_TO    (엣지: 운송)    │
│  - PGV_EDGE_*_PROD      (엣지: 생산)    │
│  - PGV_EDGE_*_SHIP      (엣지: 출하)    │
│  - PGV_INV_*            (유틸: 재고)    │
└───────┬─────────────────────────────────┘
        │                    │
        │ Python 직접 쿼리    │ (임시 우회)
        │ (실시간)           ▼
        │       ┌─────────────────────────┐
        │       │  Materialized View 11개  │  ← ORA-42449 회피용 임시책
        │       │  Node MV 2개 + Edge MV  │     원천의 ~1× 크기
        │       │  9개                    │     업그레이드 완료 후 전량 제거
        │       └───────────┬─────────────┘
        │                   │
        └───────────────────┤
                            ▼
              ┌─────────────────────────────┐
              │  Property Graph: SCM_PGV    │  ← 분석·NL2SQL 쿼리 대상
              │  (Oracle 26ai)              │
              └─────────────────────────────┘
```

**핵심**: 쓰기가 발생하는 유일한 위치는 MV Refresh 시점이며, 원천 테이블에는 영구적으로 쓰지 않는다.

---

## 4. View 만으로 Property Graph를 구성할 수 있는가

### 4.1 Oracle 26ai의 공식 지원 여부

Oracle 26ai Property Graph는 **SQL View를 VERTEX/EDGE 테이블로 직접 사용하는 것을 공식 지원**한다.

```sql
-- Oracle 26ai View → Property Graph (목표 상태)
CREATE OR REPLACE PROPERTY GRAPH SCM_PGV
  VERTEX TABLES (
    PGV_NODE_SITE      KEY (site_code)  LABEL SITE     PROPERTIES ALL COLUMNS,
    PGV_NODE_MATERIAL  KEY (model_code) LABEL MATERIAL PROPERTIES ALL COLUMNS
  )
  EDGE TABLES (
    PGV_EDGE_BOM_LP    SOURCE KEY (link_model_code) REFERENCES PGV_NODE_MATERIAL
                       DESTINATION KEY (pack_model_code) REFERENCES PGV_NODE_MATERIAL
                       LABEL LINK_TO_PACK  PROPERTIES ALL COLUMNS,
    ...
  );
-- MV 전혀 불필요
```

### 4.2 현재 View-only가 불가능한 이유 — ORA-42449

현재 운영 DB는 Oracle RAC 롤링 업그레이드 진행 중이다. 이 상태에서 View를 Property Graph의 Vertex/Edge 테이블로 사용하면 다음 오류가 발생한다.

```
ORA-42449: 이 데이터베이스 인스턴스에서 Property Table을 지원하지 않습니다.
```

**원인**: RAC 일부 노드가 구버전 상태일 때 View(메타데이터 전용)를 물리 데이터처럼 처리하지 못하는 제약.  
**조건**: Oracle RAC 롤링 업그레이드가 완전히 완료되면 ORA-42449가 해소된다.  
**대응**: 업그레이드 완료까지 임시로 Materialized View를 사용.

### 4.3 왜 Node View는 단순 SELECT가 아닌가 — UNION 필요성

원천 스키마에 사이트 마스터(SITE_MASTER)나 자재 마스터(MATERIAL_MASTER) 테이블이 없다. 사이트 정보가 6개 테이블에 분산되어 있기 때문에 UNION 없이는 전체 사이트 목록을 만들 수 없다.

```
                    AA01  MI01-P  KR01-L  DE01-C  (기타)
AEROGEL_SHIPMENT     ✅     ✅
PACK_PRODUCTION               ✅
LINK_PRODUCTION                         ✅
PACK_SHIPMENT                 ✅                   ✅
LINK_SHIPMENT                           ✅
LEAD_TIME_MASTER     ✅      ✅          ✅         ✅
──────────────────────────────────────────────────────
전체 등장 여부       ✅     ✅           ✅         ✅
```

어느 테이블 하나만으로는 전체 사이트를 커버할 수 없다. 따라서 Node View 내부에 UNION DISTINCT가 필수다.

- UNION 결과 → View 필요
- ORA-42449 → View를 PG에 직접 사용 불가 (현재)
- **→ Node MV 2개가 현재 환경에서 유일한 해법**

Node MV의 실제 데이터량: **사이트 25개 + 자재 30개 = 55행** (매우 경량)

---

## 5. 3가지 구성 옵션 비교

| 옵션 | 스토리지 추가 | 실시간성 | OLTP 부담 | 고객 수용도 | 적용 조건 |
|------|-----------|--------|----------|---------|---------|
| **A. View만 (최종 목표)** | **0** | ⭐⭐⭐ 실시간 | 중 | ⭐⭐⭐ | RAC 업그레이드 완료 후 |
| **B. 하이브리드 (권장 중간단계)** | 소 (Node MV 2개만, ~55행) | ⭐⭐ | **저** | ⭐⭐ | 즉시 적용 가능 |
| **C. 전량 MV (현재 임시)** | ~1× 원천 전체 | ⭐ | 저 | ⭐ | RAC 업그레이드 중 임시 |

### 권장 전환 경로

```
C (현재, 전량 MV)
    │
    ▼  30분 비파괴 검증 후
B (하이브리드: Node MV 2개 + Edge는 원천 직접 참조)
    │
    ▼  RAC 업그레이드 완료 시
A (View-only: MV 전량 제거, 신규 물리 객체 0)
```

각 전환 단계에서 **원천 테이블 무수정 · 쓰기 없음** 원칙은 그대로 유지된다.

---

## 6. 데이터 모델 설계 — 왜 이 구조인가

### 6.1 Vertex(노드) 2종으로 충분한 이유

공급망은 **장소(where)** 와 **물건(what)** 두 개념만으로 표현된다.

| Vertex | 포함 유형 | 통합 이유 |
|--------|---------|---------|
| **SITE** | Supplier, Pack생산지, Link생산지, Customer | 모두 같은 location 코드. 타입을 site_type 속성으로 구분 |
| **MATERIAL** | Link(완제품), Pack(중간조립), Aerogel(원자재) | BOM 계층을 표현하는 단일 엔터티 |

**재고(Inventory)를 노드로 만들지 않은 이유**: 재고는 "특정 일자의 수량 스냅샷"이지 항상 존재하는 개체가 아니다. 경로 탐색(MATCH)의 대상이 되지 않으므로 Property Graph에서 제외하고, 별도 유틸 View(`PGV_INV_*`)로 Python에서 직접 SELECT한다.

### 6.2 Edge(엣지) 9종 — 원천 테이블 1:1 매핑

각 원천 테이블의 관계를 Property Graph 엣지로 변환. **원천 테이블 1개 = Edge 1종** 원칙을 유지한다.

| Edge 라벨 | 방향 | 원천 테이블 | 표현하는 관계 |
|-----------|------|-----------|-----------|
| LINK_TO_PACK | Material → Material | BOM_LINK_PACK | BOM 계층 (Link가 Pack N개로 구성) |
| PACK_TO_AEROGEL | Material → Material | BOM_PACK_AEROGEL | BOM 계층 (Pack이 Aerogel M개로 구성) |
| SHIPS_TO | Site → Site | LEAD_TIME_MASTER | 운송 네트워크 (리드타임·운송수단) |
| PACK_PRODUCES | Site → Material | PACK_PRODUCTION_PLAN | Pack 생산 계획 |
| LINK_PRODUCES | Site → Material | LINK_PRODUCTION_PLAN | Link 생산 계획 |
| PACK_SHIPS | Site → Site | PACK_SHIPMENT_PLAN | Pack 출하 계획 |
| LINK_DELIVERS | Site → Site | LINK_SHIPMENT_PLAN | Link 배송 계획 |
| AEROGEL_SHIPS | Site → Site | AEROGEL_SHIPMENT_PLAN | Aerogel 공급 계획 |
| ORDER_UNIT | Site → Site | MATERIAL_ORDER_UNIT | 발주 제약 (MOQ/MPU) |

---

## 7. MV에 대한 오해 정정

| 오해 | 실제 |
|------|-----|
| "MV = 데이터 복제 파이프라인" | 단일 SQL 문. 별도 ETL 도구 없음 |
| "원본이 바뀌면 자동 동기화" | 수동 REFRESH 또는 스케줄러. 원본에 영향 0 |
| "분석 성능이 원본에 영향" | 오히려 **분석이 MV로 빠져나가 원본 부담 감소** |
| "영구 잔류 구조" | **업그레이드 완료 후 전량 제거 가능** |
| "Node MV = Edge MV와 동일 성격" | **다르다**: Node MV는 마스터 부재로 인한 구조적 필요, Edge MV는 순수 임시책 |

---

## 8. 현재 MV 구성 상세 (11개)

| MV 이름 | 유형 | 데이터량 | 존재 이유 | 제거 조건 |
|---------|------|---------|---------|---------|
| PGV_MV_NODE_SITE | Node | ~25행 | 6개 테이블 UNION 필수, 마스터 없음 | RAC 완료 또는 마스터 생성 |
| PGV_MV_NODE_MATERIAL | Node | ~30행 | 3개 테이블 UNION 필수, 마스터 없음 | 동일 |
| PGV_MV_EDGE_BOM_LP | Edge | 원천 동일 | ORA-42449 우회 임시 | RAC 업그레이드 완료 |
| PGV_MV_EDGE_BOM_PA | Edge | 원천 동일 | 동일 | 동일 |
| PGV_MV_EDGE_SHIPS_TO | Edge | 원천 동일 | 동일 | 동일 |
| PGV_MV_EDGE_PACK_PROD | Edge | 원천 동일 | 동일 | 동일 |
| PGV_MV_EDGE_LINK_PROD | Edge | 원천 동일 | 동일 | 동일 |
| PGV_MV_EDGE_PACK_SHIP | Edge | 원천 동일 | 동일 | 동일 |
| PGV_MV_EDGE_LINK_SHIP | Edge | 원천 동일 | 동일 | 동일 |
| PGV_MV_EDGE_AEROGEL_SHIP | Edge | 원천 동일 | 동일 | 동일 |
| PGV_MV_EDGE_ORDER_UNIT | Edge | 원천 동일 | 동일 | 동일 |

**핵심 분류**: Node MV 2개 (구조적 필요) vs Edge MV 9개 (임시책, RAC 완료 시 즉시 제거 가능)

### MV Refresh 운영

- **방식**: `DBMS_MVIEW.REFRESH('PGV_MV_NODE_SITE', 'C')` — 단일 PL/SQL 호출
- **주기**: 수동 또는 Oracle Scheduler로 일 1회 (현재 데이터 규모 기준 수 초 소요)
- **원천 영향**: 없음 (읽기 전용)

---

## 9. 보안 · 컴플라이언스 체크리스트

- ✅ 원천 테이블 **수정 권한 불필요**
- ✅ 쓰기 권한은 MV 영역에만 한정 (원천 永구 쓰기 없음)
- ✅ Wallet 기반 DB 접속, 자격증명은 `.env` 환경변수로만 관리
- ✅ LLM 외부 호출(OCI GenAI) 시 **질문 텍스트만** 전송 — 원천 데이터 전체 유출 없음
- ✅ NL2SQL SELECT 가드: DDL/DML 쿼리 자동 차단, 결과 1,000행 제한

---

## 10. 검증 절차 (DBA 관점)

| 단계 | 작업 | 소요 | 운영 영향 |
|------|------|------|----------|
| 1 | `scripts/verify_view_pg_readonly.sql` 로 sqlcl 조회 10건 | 5분 | **없음** |
| 2 | `PGV_TEST_SCM_PGV` 병행 그래프 생성 → 조회 → 삭제 | 10분 | **없음** (테스트 객체만) |
| 3 | 결과 GREEN 시 유지보수 창에서 정식 전환 | 30분 | 서비스 재시작 시 일시적 (계획된) |

검증 스크립트는 DDL/DML 없음. 정식 전환은 별도 승인 후에만 실행.

---

## 11. 정량 지표 (현재 데이터 기준)

| 지표 | 값 |
|------|-----|
| 원천 운영 테이블 | 13개 |
| SQL View | 15개 (Node 2 + Edge 9 + Util 4) |
| Materialized View | 11개 (Node 2 + Edge 9) |
| Property Graph 노드 유형 | 2종 (SITE, MATERIAL) |
| Property Graph 사이트 노드 | 25개 (Supplier 2 + Pack공장 3 + Link공장 2 + Customer 18) |
| Property Graph 자재 노드 | 30개 |
| Property Graph 엣지 라벨 | 9종, 총 ~790건 |
| Node MV 총 데이터 | ~55행 |
| MV 전체 용량 | ~1× 원천 (상세는 USER_SEGMENTS 확인) |
| Refresh 소요 시간 | COMPLETE 기준 수 초 |

---

## 12. 예상 Q&A

**Q. 결국 데이터를 두 벌 들고 가는 것 아닌가?**  
A. 현재는 ORA-42449 회피용으로 MV가 있다. Oracle RAC 롤링 업그레이드가 끝나면 전량 제거된다. 업그레이드 완료 여부는 30분짜리 비파괴 조회 스크립트로 확인 가능하다.

**Q. 우리 DBA가 MV Log를 허용하지 않는 정책이다.**  
A. FAST Refresh를 포기하고 View-only로 바로 전환할 수 있다. 스토리지 중복이 0으로 떨어진다.

**Q. 원천 데이터가 시간마다 바뀌면 그래프 결과는?**  
A. View-only 경로는 항상 실시간이다. MV 경로만 Refresh 시점까지 stale. 실시간이 필요한 재고 유틸은 View를 직접 쿼리하는 방식으로 이미 분리 운영 중이다.

**Q. LLM이 잘못된 SQL을 만들 가능성은?**  
A. 스키마 고정 주입 + 검증 템플릿 + SELECT 가드 + 1회 자동 재시도 = 4중 안전망. 테스트 결과 실행 성공률 > 90%.

**Q. SITE_MASTER나 MATERIAL_MASTER를 만들면 더 단순해지지 않나?**  
A. 맞다. 이 두 테이블이 있으면 Node MV도 불필요해진다. 단, 현재 원천 스키마에는 이런 마스터가 없으므로 UNION 기반 View + MV로 동일한 역할을 수행 중이다.

---

## 13. 다음 단계 요청

- [ ] **비파괴 검증 실행 승인** (`scripts/verify_view_pg_readonly.sql`)
- [ ] 검증 GREEN 시 **유지보수 창 확보** (하이브리드 또는 View-only 전환용)
- [ ] **MV Log 허용 정책** 여부 공유 (FAST Refresh 가능성 판단)
- [ ] **Oracle RAC 업그레이드 완료 예정 일정** 공유 (View-only 전환 타임라인 수립)
- [ ] NL2SQL 외부 공개 시점 및 **인증 방식** 결정

---

## 부록 A. 한 줄 결론

> **"원천 테이블은 영원히 건드리지 않습니다. 현재의 복제(MV)는 Oracle 업그레이드가 끝나면 없앱니다. 그때까지 MV는 읽기 전용 스냅샷으로만 작동하며, 어떤 ETL 파이프라인도 신설하지 않습니다."**

## 부록 B. 관련 파일 참조

| 문서 | 위치 | 내용 |
|------|------|------|
| 설계 근거서 | `docs/pgv_design_rationale.md` | Vertex/Edge 설계 판단 이유 상세 |
| MV 역할 설명 | `docs/pgv_mv_role.md` | Node MV와 Edge MV의 차이, 제거 조건 |
| 스키마 참조 | `docs/pgv_schema.md` | 원천 테이블 → View 매핑 전체 목록 |
| View-only 그래프 DDL | `db/setup/pgv_04_create_graph.sql` | RAC 업그레이드 완료 후 사용 |
| 현재 MV 그래프 DDL | `db/setup/pgv_04b_create_graph_mv.sql` | 현재 운영 중 |
| 하이브리드 DDL | `db/setup/pgv_04c_create_graph_hybrid.sql` | 중간 단계 전환용 |
| 검증 스크립트 | `scripts/verify_view_pg_readonly.sql` | 비파괴 사전 검증 |
