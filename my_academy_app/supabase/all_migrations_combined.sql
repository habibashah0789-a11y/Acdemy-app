-- =====================================================================
-- MASTER SUPABASE SQL SCRIPT FOR QUAID ACADEMY
-- Run this entire script in Supabase Dashboard -> SQL Editor -> Run
-- =====================================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================================
-- 1. BASE SCHEMA & PROFILES
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    phone TEXT DEFAULT '',
    role TEXT NOT NULL CHECK (role IN ('admin', 'teacher', 'student')),
    avatar_url TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.academic_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_current BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.classes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    level TEXT NOT NULL,
    academic_session_id UUID REFERENCES public.academic_sessions(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_class_per_session UNIQUE (name, academic_session_id)
);

CREATE TABLE IF NOT EXISTS public.subjects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    code TEXT NOT NULL UNIQUE,
    description TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================================
-- 2. STUDENTS & TEACHERS
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.students (
    id TEXT PRIMARY KEY,
    student_code TEXT NOT NULL UNIQUE,
    first_name TEXT NOT NULL,
    last_name TEXT DEFAULT '',
    father_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    email TEXT DEFAULT '',
    class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
    class_type TEXT DEFAULT 'FSc',
    grade TEXT DEFAULT 'First Year',
    subject TEXT DEFAULT 'Biology',
    fee_submitted NUMERIC(10, 2) DEFAULT 0.00,
    fee_remaining NUMERIC(10, 2) DEFAULT 0.00,
    profile_pic_url TEXT DEFAULT '',
    date_of_birth DATE,
    address TEXT DEFAULT '',
    admission_date DATE DEFAULT CURRENT_DATE,
    enrollment_status TEXT DEFAULT 'active' CHECK (enrollment_status IN ('active', 'inactive', 'suspended', 'graduated')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.teachers (
    id TEXT PRIMARY KEY,
    teacher_id TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    phone TEXT DEFAULT '',
    email TEXT UNIQUE NOT NULL,
    subject TEXT NOT NULL,
    section TEXT DEFAULT 'FSc',
    profile_pic_url TEXT DEFAULT '',
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'on_leave')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.enrollments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
    class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
    subject_fee NUMERIC(10, 2) DEFAULT 0.00,
    enrolled_at TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'dropped')),
    CONSTRAINT unique_student_subject_enrollment UNIQUE (student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS public.teacher_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id TEXT NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
    class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_teacher_class_subject UNIQUE (teacher_id, class_id, subject_id)
);

-- =====================================================================
-- 3. FEES & PAYMENTS
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.fees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    academic_session_id UUID REFERENCES public.academic_sessions(id) ON DELETE SET NULL,
    billing_month TEXT NOT NULL,
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    discount_amount NUMERIC(10, 2) DEFAULT 0.00,
    due_date DATE NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'partial', 'paid', 'overdue')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.fee_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fee_id UUID REFERENCES public.fees(id) ON DELETE SET NULL,
    student_id TEXT NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    amount_paid NUMERIC(10, 2) NOT NULL,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'online', 'bank_transfer', 'easypaisa', 'jazzcash')),
    transaction_reference TEXT DEFAULT '',
    received_by TEXT DEFAULT 'Admin',
    payment_date DATE DEFAULT CURRENT_DATE,
    receipt_number TEXT UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================================
-- 4. ATTENDANCE
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
    subject_id UUID REFERENCES public.subjects(id) ON DELETE SET NULL,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL CHECK (status IN ('present', 'absent', 'late', 'leave')),
    marked_by TEXT DEFAULT 'Teacher',
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_daily_attendance_record UNIQUE (student_id, date, subject_id)
);

-- =====================================================================
-- 5. TIMETABLE
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.timetables (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
    teacher_id TEXT REFERENCES public.teachers(id) ON DELETE SET NULL,
    day_of_week TEXT NOT NULL CHECK (day_of_week IN (
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    )),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    room TEXT DEFAULT 'Room 1',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT valid_timetable_slot CHECK (
        start_time >= '07:00:00'::TIME 
        AND end_time <= '22:00:00'::TIME 
        AND end_time > start_time
    ),
    CONSTRAINT unique_class_slot UNIQUE (class_id, day_of_week, start_time)
);

-- =====================================================================
-- 6. ANNOUNCEMENTS & NOTIFICATIONS
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    target_class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE,
    author_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'urgent')),
    is_published BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipient_id TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT DEFAULT 'general' CHECK (type IN ('general', 'fee_reminder', 'attendance_alert', 'exam_schedule', 'announcement')),
    data JSONB DEFAULT '{}'::JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================================
-- 7. STUDENT DEVICES
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.student_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    device_identifier TEXT NOT NULL,
    device_model TEXT DEFAULT '',
    platform TEXT DEFAULT 'android' CHECK (platform IN ('android', 'ios', 'web', 'windows', 'macos', 'linux')),
    fcm_token TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT TRUE,
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_student_device UNIQUE (student_id, device_identifier)
);

-- =====================================================================
-- 8. INDEXES & VIEWS
-- =====================================================================
CREATE INDEX IF NOT EXISTS idx_students_code ON public.students(student_code);
CREATE INDEX IF NOT EXISTS idx_attendance_student_date ON public.attendance(student_id, date);
CREATE INDEX IF NOT EXISTS idx_fee_payments_student ON public.fee_payments(student_id);
CREATE INDEX IF NOT EXISTS idx_timetables_class_day ON public.timetables(class_id, day_of_week);
CREATE INDEX IF NOT EXISTS idx_announcements_active ON public.announcements(is_published);

-- Analytical Views
CREATE OR REPLACE VIEW public.v_student_fee_summary AS
SELECT 
    s.id AS student_id,
    s.student_code,
    s.first_name,
    s.last_name,
    s.father_name,
    s.phone,
    s.grade,
    s.subject,
    COALESCE(SUM(f.total_amount - f.discount_amount), 0.00) AS total_fee_billed,
    COALESCE(SUM(fp.amount_paid), 0.00) AS total_fee_paid,
    GREATEST(0.00, COALESCE(SUM(f.total_amount - f.discount_amount), 0.00) - COALESCE(SUM(fp.amount_paid), 0.00)) AS outstanding_balance
FROM public.students s
LEFT JOIN public.fees f ON s.id = f.student_id
LEFT JOIN public.fee_payments fp ON s.id = fp.student_id
GROUP BY s.id, s.student_code, s.first_name, s.last_name, s.father_name, s.phone, s.grade, s.subject;

CREATE OR REPLACE VIEW public.v_student_attendance_summary AS
SELECT 
    s.id AS student_id,
    s.student_code,
    s.first_name,
    s.last_name,
    COUNT(a.id) AS total_days_recorded,
    COUNT(CASE WHEN a.status = 'present' THEN 1 END) AS days_present,
    COUNT(CASE WHEN a.status = 'absent' THEN 1 END) AS days_absent,
    COUNT(CASE WHEN a.status = 'late' THEN 1 END) AS days_late,
    COUNT(CASE WHEN a.status = 'leave' THEN 1 END) AS days_leave,
    ROUND(
        (COUNT(CASE WHEN a.status = 'present' THEN 1 END)::NUMERIC / NULLIF(COUNT(a.id), 0)::NUMERIC) * 100, 
        2
    ) AS attendance_percentage
FROM public.students s
LEFT JOIN public.attendance a ON s.id = a.student_id
GROUP BY s.id, s.student_code, s.first_name, s.last_name;

CREATE OR REPLACE VIEW public.v_class_timetables AS
SELECT 
    t.id,
    t.class_id,
    c.name AS class_name,
    c.level AS class_level,
    t.subject_id,
    s.name AS subject_name,
    s.code AS subject_code,
    t.teacher_id,
    tc.name AS teacher_name,
    t.day_of_week,
    t.start_time,
    t.end_time,
    t.room,
    t.is_active
FROM public.timetables t
JOIN public.classes c ON t.class_id = c.id
JOIN public.subjects s ON t.subject_id = s.id
LEFT JOIN public.teachers tc ON t.teacher_id = tc.id;

-- =====================================================================
-- 9. FUNCTIONS & PROCEDURES
-- =====================================================================
CREATE OR REPLACE FUNCTION public.fn_sync_student_balance_on_payment()
RETURNS TRIGGER AS $$
DECLARE
    v_total_paid NUMERIC(10, 2);
    v_total_fee NUMERIC(10, 2);
BEGIN
    SELECT COALESCE(SUM(amount_paid), 0.00) INTO v_total_paid
    FROM public.fee_payments WHERE student_id = NEW.student_id;

    SELECT COALESCE(SUM(total_amount - discount_amount), 0.00) INTO v_total_fee
    FROM public.fees WHERE student_id = NEW.student_id;

    UPDATE public.students
    SET fee_submitted = v_total_paid,
        fee_remaining = GREATEST(0.00, v_total_fee - v_total_paid),
        updated_at = NOW()
    WHERE id = NEW.student_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_student_fee_balance ON public.fee_payments;
CREATE TRIGGER trg_sync_student_fee_balance
    AFTER INSERT OR UPDATE OR DELETE ON public.fee_payments
    FOR EACH ROW EXECUTE FUNCTION public.fn_sync_student_balance_on_payment();

-- =====================================================================
-- 10. ROW LEVEL SECURITY
-- =====================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.academic_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timetables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_devices ENABLE ROW LEVEL SECURITY;

DO $$ 
DECLARE
    tbl text;
BEGIN
    FOR tbl IN 
        SELECT tablename FROM pg_tables WHERE schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Public read %I" ON public.%I', tbl, tbl);
        EXECUTE format('CREATE POLICY "Public read %I" ON public.%I FOR SELECT USING (true)', tbl, tbl);
        EXECUTE format('DROP POLICY IF EXISTS "Public write %I" ON public.%I', tbl, tbl);
        EXECUTE format('CREATE POLICY "Public write %I" ON public.%I FOR ALL USING (true) WITH CHECK (true)', tbl, tbl);
    END LOOP;
END $$;

-- Storage buckets
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('student-avatars', 'student-avatars', true),
    ('teacher-avatars', 'teacher-avatars', true),
    ('academy-assets', 'academy-assets', true),
    ('documents', 'documents', true),
    ('announcements', 'announcements', true),
    ('notices', 'notices', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- =====================================================================
-- 11. SEED DATA
-- =====================================================================
INSERT INTO public.academic_sessions (id, name, start_date, end_date, is_current)
VALUES ('a0000000-0000-0000-0000-000000000001', 'Session 2026-2027', '2026-04-01', '2027-03-31', TRUE)
ON CONFLICT (name) DO UPDATE SET is_current = TRUE;

INSERT INTO public.classes (id, name, level, academic_session_id)
VALUES 
    ('c0000000-0000-0000-0000-000000000001', '9th Class', 'Matric', 'a0000000-0000-0000-0000-000000000001'),
    ('c0000000-0000-0000-0000-000000000002', '10th Class', 'Matric', 'a0000000-0000-0000-0000-000000000001'),
    ('c0000000-0000-0000-0000-000000000003', '1st Year (11th)', 'FSc', 'a0000000-0000-0000-0000-000000000001'),
    ('c0000000-0000-0000-0000-000000000004', '2nd Year (12th)', 'FSc', 'a0000000-0000-0000-0000-000000000001'),
    ('c0000000-0000-0000-0000-000000000005', 'MDCAT Preparation', 'MDCAT', 'a0000000-0000-0000-0000-000000000001')
ON CONFLICT (name, academic_session_id) DO NOTHING;

INSERT INTO public.subjects (id, name, code, description)
VALUES 
    ('s0000000-0000-0000-0000-000000000001', 'Biology', 'BIO', 'Biological Sciences & Anatomy'),
    ('s0000000-0000-0000-0000-000000000002', 'Physics', 'PHY', 'Physics Theory & Numerical Labs'),
    ('s0000000-0000-0000-0000-000000000003', 'Chemistry', 'CHEM', 'Organic, Inorganic & Physical Chemistry'),
    ('s0000000-0000-0000-0000-000000000004', 'Mathematics', 'MATH', 'Algebra, Calculus & Geometry'),
    ('s0000000-0000-0000-0000-000000000005', 'English', 'ENG', 'English Grammar, Literature & Composition'),
    ('s0000000-0000-0000-0000-000000000006', 'Computer Science', 'CS', 'Programming, Algorithms & ICT'),
    ('s0000000-0000-0000-0000-000000000007', 'Urdu', 'URDU', 'Urdu Literature & Grammar'),
    ('s0000000-0000-0000-0000-000000000008', 'Islamic Studies', 'ISL', 'Islamiyat Compulsory'),
    ('s0000000-0000-0000-0000-000000000009', 'Pakistan Studies', 'PST', 'Pakistan History & Geography')
ON CONFLICT (name) DO NOTHING;
