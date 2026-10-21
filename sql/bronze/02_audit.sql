CREATE TABLE IF NOT EXISTS audit.etl_batch_audit (
    batch_id      BIGSERIAL PRIMARY KEY,
    batch_date    DATE NOT NULL,
    status        TEXT NOT NULL DEFAULT 'RUNNING',
    rows_read     INTEGER DEFAULT 0,
    rows_loaded   INTEGER DEFAULT 0,
    started_at    TIMESTAMPTZ DEFAULT now(),
    finished_at   TIMESTAMPTZ,
    error_message TEXT
);
