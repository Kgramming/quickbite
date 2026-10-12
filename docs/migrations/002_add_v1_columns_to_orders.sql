-- Migration 002: add v1 API columns to orders table.
--
-- Adds the following nullable columns needed by the v1 API:
--   - user_id: FK to users.id, allows filtering orders by customer
--   - restaurant_id: FK to restaurants.id, identifies the restaurant
--   - currency: currency code (default INR)
--   - total_amount_minor: total amount in minor units (e.g. 24999 = INR 249.99)
--   - version: optimistic locking version (default 1)
--   - failure_code: stable code for FAILED or PAYMENT_FAILED orders
--
-- All columns are nullable for backward compatibility with legacy orders.
-- This migration is idempotent and preserves all existing data.
--
-- Usage:
--   psql "$DATABASE_URL" -f docs/migrations/002_add_v1_columns_to_orders.sql
--

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'orders' AND column_name = 'user_id'
    ) THEN
        ALTER TABLE orders ADD COLUMN user_id VARCHAR(36) NULL;
        RAISE NOTICE 'orders: added user_id column';
    ELSE
        RAISE NOTICE 'orders: user_id column already present, skipping';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'orders' AND column_name = 'restaurant_id'
    ) THEN
        ALTER TABLE orders ADD COLUMN restaurant_id VARCHAR(36) NULL;
        RAISE NOTICE 'orders: added restaurant_id column';
    ELSE
        RAISE NOTICE 'orders: restaurant_id column already present, skipping';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'orders' AND column_name = 'currency'
    ) THEN
        ALTER TABLE orders ADD COLUMN currency VARCHAR(3) NULL DEFAULT 'INR';
        RAISE NOTICE 'orders: added currency column';
    ELSE
        RAISE NOTICE 'orders: currency column already present, skipping';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'orders' AND column_name = 'total_amount_minor'
    ) THEN
        ALTER TABLE orders ADD COLUMN total_amount_minor INTEGER NULL;
        RAISE NOTICE 'orders: added total_amount_minor column';
    ELSE
        RAISE NOTICE 'orders: total_amount_minor column already present, skipping';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'orders' AND column_name = 'version'
    ) THEN
        ALTER TABLE orders ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
        RAISE NOTICE 'orders: added version column';
    ELSE
        RAISE NOTICE 'orders: version column already present, skipping';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'orders' AND column_name = 'failure_code'
    ) THEN
        ALTER TABLE orders ADD COLUMN failure_code VARCHAR(100) NULL;
        RAISE NOTICE 'orders: added failure_code column';
    ELSE
        RAISE NOTICE 'orders: failure_code column already present, skipping';
    END IF;
END
$$;

-- Create individual indexes for query performance
CREATE INDEX IF NOT EXISTS ix_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS ix_orders_restaurant_id ON orders(restaurant_id);
CREATE INDEX IF NOT EXISTS ix_orders_user_status ON orders(user_id, status);
