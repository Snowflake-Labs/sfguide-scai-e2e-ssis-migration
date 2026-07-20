# Migration Success Checklist

Use this checklist to verify a migration run is complete and ready for sign-off.


## 1. Migration Dashboard (`/dash`)

### Registration
- [ ] **19 / 19 objects registered** (completed: 19)

### Conversion
- [ ] **19 / 19 objects converted** (completed: 19, 100%)
- [ ] Databases: **1 / 1**
- [ ] ETLs: **1 / 1**
- [ ] Functions: **1 / 1** (100%)
- [ ] Procedures: **1 / 1**
- [ ] Schemas: **2 / 2**
- [ ] Tables: **11 / 11**
- [ ] Unknowns: **1 / 1**
- [ ] Views: **1 / 1**
- [ ] No unresolved `!!!RESOLVE EWI!!!` markers in any deployed object

### Deployment
- [ ] **19 / 19 objects deployed** (100%)
  - [ ] Unknown type objects resolved or explicitly excluded from deployment scope

### Data Migration
- [ ] **11 / 11 tables loaded** (completed: 11)
  - [ ] COUNTRY loaded with 0 errors
  - [ ] EMPLOYEESHIFT loaded with 0 errors
  - [ ] MENUITEM loaded with 0 errors
  - [ ] ORDERDETAIL loaded with 0 errors
  - [ ] `errors.csv` in latest workflow folder is empty (header only)

### Testing (Optional)
- [ ] **Testing started** — at minimum 2 / 19 completed (baseline)
- [ ] No pending test failures blocking deployment

---

## 2. Migration Folder — `/snowflake/` Contents

- [ ] `snowflake/` folder exists and contains **19+ SQL files**
- [ ] No `!!!RESOLVE EWI!!!` strings present in any file under `snowflake/`
- [ ] `snowflake/tastybytesdb/tastybytes/` contains:
  - [ ] `table/` — 11 table DDL files
  - [ ] `view/` — at least 1 view file
  - [ ] `function/` — at least 1 function file
  - [ ] `procedure/` — at least 1 procedure file
- [ ] `snowflake/_etl/daily_sales_agg/` exists with:
  - [ ] `daily_sales_agg.sql` (Task Graph)
  - [ ] `df_load_daily_sales/` (dbt project)
- [ ] `snowflake/_etl/etl_configuration/` exists (runtime framework)
- [ ] `snowflake/UDF Helpers/` exists (JSON helpers, LOG_INFO_UDP)

---

## 3. ETL / dbt

- [ ] dbt project deployed as Snowflake object:
  ```sql
  SHOW DBT PROJECTS IN SCHEMA TASTYBYTESDB.TASTYBYTES;
  -- Should return: df_load_daily_sales
  ```
- [ ] Task Graph deployed and tasks exist:
  ```sql
  SHOW TASKS IN SCHEMA TASTYBYTESDB.TASTYBYTES;
  -- Should return 4 tasks: daily_sales_agg + 3 children
  ```
- [ ] Task Graph can execute end-to-end without errors (manual test run):
  ```sql
  EXECUTE TASK TASTYBYTESDB.TASTYBYTES.daily_sales_agg;
  ```
- [ ] ETL configuration framework deployed:
  - [ ] `control_variables` table exists
  - [ ] `GetControlVariableUDF`, `BuildDbtVarsJsonUDF`, `ResolveVariablePlaceholders` exist

---

## 4. Data Validation (Optional)

- [ ] Data validation workflow created and executed (`scai data validate`)
- [ ] Row counts match between source SQL Server and target Snowflake for all 11 tables
- [ ] No schema differences (column names, data types) between source and target

---

## 5. Git / Audit Trail

- [ ] All converted SQL committed to git (`git status` is clean)
- [ ] Latest deployment reports exist in `reports/DeploymentReport.*.csv`
- [ ] Latest data migration report exists in `reports/data-migration/workflow-*/` with 0 errors
- [ ] `artifacts/` folder has timestamped deterministic snapshots for all objects
