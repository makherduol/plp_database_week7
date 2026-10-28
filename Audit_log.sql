-- ==============================================================================
-- PostgreSQL Advanced Lab: Auditing, Hierarchical Data, & Security
-- ==============================================================================

-- ==========================================
-- Step 1: Build a Reusable Audit Log
-- ==========================================
CREATE TABLE audit_log (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tbl TEXT,
  op TEXT,
  old_row JSONB,
  new_row JSONB,
  changed_by TEXT DEFAULT current_user,
  at TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE FUNCTION audit() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_log(tbl, op, old_row, new_row)
  VALUES (
    TG_TABLE_NAME,
    TG_OP,
    to_jsonb(OLD),
    to_jsonb(NEW)
  );
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Assuming a 'students' table already exists
CREATE TRIGGER trg_audit
AFTER INSERT OR UPDATE OR DELETE
ON students
FOR EACH ROW
EXECUTE FUNCTION audit();


-- ==========================================
-- Step 2: Watch the Audit Log Work
-- ==========================================
-- Example operations to trigger the audit log:
-- UPDATE students SET name = 'Kofi M.' WHERE id = 1;
-- DELETE FROM students WHERE id = 3;

-- Query to inspect the audit trail:
SELECT
  tbl,
  op,
  old_row->>'name' AS was,
  new_row->>'name' AS now,
  at
FROM audit_log
ORDER BY at DESC;


-- ==========================================
-- Step 3: Model a Category Tree (Recursive CTE)
-- ==========================================
CREATE TABLE categories (
  id SERIAL PRIMARY KEY,
  name TEXT,
  parent_id INT REFERENCES categories(id)
);

INSERT INTO categories (name, parent_id) VALUES
  ('Electronics', NULL),
  ('Computers', 1),
  ('Laptops', 2),
  ('Phones', 1);

-- Walk the hierarchical tree using a recursive CTE
WITH RECURSIVE tree AS (
  SELECT id, name, parent_id, 0 AS depth
  FROM categories
  WHERE parent_id IS NULL

  UNION ALL

  SELECT c.id, c.name, c.parent_id, t.depth + 1
  FROM categories c
  JOIN tree t ON c.parent_id = t.id
)
SELECT repeat('  ', depth) || name AS tree
FROM tree
ORDER BY depth, name;


-- ==========================================
-- Step 4: Run Versioned Migrations (Flyway Reference)
-- ==========================================
-- Organize schema changes as ordered migration files inside a migrations/ folder:
--   V1__core_tables.sql
--   V2__audit_log.sql
--   V3__categories.sql
-- 
-- Run via terminal:
-- flyway -url=jdbc:postgresql://localhost/bootcamp -user=postgres migrate
-- flyway info


-- ==========================================
-- Step 5: Apply Least-Privilege Security
-- ==========================================
CREATE ROLE app_read;
CREATE ROLE app_write;

GRANT CONNECT ON DATABASE bootcamp TO app_read, app_write;
GRANT USAGE ON SCHEMA public TO app_read, app_write;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_read;
GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public TO app_write;

CREATE USER api
LOGIN PASSWORD 'strong-secret'
IN ROLE app_write;
