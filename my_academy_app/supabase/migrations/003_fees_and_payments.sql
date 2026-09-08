-- =====================================================================
-- 003_fees_and_payments.sql
-- Quaid Academy Database - Structured Fees, Payment Ledgers & Balance Views
-- =====================================================================

-- 1. Subject-Wise Fee Structures (Due per student / enrollment)
CREATE TABLE IF NOT EXISTS public.fees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES public.subjects(id) ON DELETE SET NULL,
    subject_name TEXT NOT NULL, -- 'Biology', 'Physics', 'Chemistry', 'Maths', 'English'
    amount_due NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    academic_session_id UUID REFERENCES public.academic_sessions(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_student_subject_fee UNIQUE (student_id, subject_name)
);

-- 2. Fee Payments Ledger (All transactions, receipts, payment methods)
CREATE TABLE IF NOT EXISTS public.fee_payments (
    id TEXT PRIMARY KEY, -- e.g., 'tx_1741234567_student123'
    student_id TEXT NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    fee_id UUID REFERENCES public.fees(id) ON DELETE SET NULL,
    amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    remaining_after NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    subject TEXT DEFAULT '',
    class_type TEXT DEFAULT 'FSc',
    grade TEXT DEFAULT '',
    payment_method TEXT NOT NULL DEFAULT 'Cash' CHECK (payment_method IN ('Cash', 'Bank Transfer', 'EasyPaisa', 'JazzCash', 'Online', 'Other')),
    receipt_no TEXT DEFAULT '',
    note TEXT DEFAULT '',
    recorded_by TEXT DEFAULT 'Admin',
    payment_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. SQL View for Real-time Student Fee Balances
CREATE OR REPLACE VIEW public.v_student_fee_summary AS
SELECT 
    s.id AS student_id,
    s.student_code,
    s.first_name,
    s.last_name,
    s.class_type,
    s.grade,
    COALESCE(SUM(f.amount_due), 0.00) AS total_fee_due,
    COALESCE(p.total_paid, 0.00) AS total_fee_paid,
    GREATEST(0.00, COALESCE(SUM(f.amount_due), 0.00) - COALESCE(p.total_paid, 0.00)) AS total_fee_remaining
FROM public.students s
LEFT JOIN public.fees f ON f.student_id = s.id
LEFT JOIN (
    SELECT student_id, SUM(amount) AS total_paid
    FROM public.fee_payments
    GROUP BY student_id
) p ON p.student_id = s.id
GROUP BY s.id, s.student_code, s.first_name, s.last_name, s.class_type, s.grade, p.total_paid;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_fees_student_id ON public.fees(student_id);
CREATE INDEX IF NOT EXISTS idx_fee_payments_student_id ON public.fee_payments(student_id);
CREATE INDEX IF NOT EXISTS idx_fee_payments_date ON public.fee_payments(payment_date);
