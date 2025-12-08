-- Create jobs table for unified job tracking
CREATE TABLE IF NOT EXISTS jobs (
    id SERIAL PRIMARY KEY,
    job_id VARCHAR(100) UNIQUE NOT NULL,
    job_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    error_message TEXT,
    result_summary TEXT,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_jobs_job_id ON jobs(job_id);
CREATE INDEX IF NOT EXISTS idx_jobs_type ON jobs(job_type);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON jobs(created_at DESC);

-- Add comments
COMMENT ON TABLE jobs IS 'Unified table for tracking all background jobs (scans, exports, etc.)';
COMMENT ON COLUMN jobs.job_type IS 'Type of job: scan, export, etc.';
COMMENT ON COLUMN jobs.status IS 'Job status: pending, processing, completed, failed';
COMMENT ON COLUMN jobs.result_summary IS 'JSON summary of job results';
