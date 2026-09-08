-- =====================================================================
-- 004_attendance.sql
-- Quaid Academy Database - Daily Attendance Tracking & Percentage Views
-- =====================================================================

-- 1. Attendance Table
CREATE TABLE IF NOT EXISTS public.attendance (
    id TEXT PRIMARY KEY, -- e.g., 'att_1741234567_student123' or UUID
    student_id TEXT NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    student_code TEXT DEFAULT '',
    student_name TEXT DEFAULT '',
    class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
    class_type TEXT DEFAULT 'FSc',
    grade TEXT DEFAULT '',
    subject_id UUID REFERENCES public.subjects(id) ON DELETE SET NULL,
    subject TEXT DEFAULT '',
    attendance_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL CHECK (status IN ('present', 'absent', 'late', 'leave')),
    remarks TEXT DEFAULT '',
    marked_by TEXT NOT NULL DEFAULT 'Admin',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_daily_student_attendance UNIQUE (student_id, attendance_date, subject)
);

-- 2. SQL View for Attendance Analytics per Student
CREATE OR REPLACE VIEW public.v_student_attendance_summary AS
SELECT 
    student_id,
    COUNT(*) AS total_classes,
    COUNT(*) FILTER (WHERE status = 'present') AS total_present,
    COUNT(*) FILTER (WHERE status = 'absent') AS total_absent,
    COUNT(*) FILTER (WHERE status = 'late') AS total_late,
    COUNT(*) FILTER (WHERE status = 'leave') AS total_leave,
    ROUND(
        (COUNT(*) FILTER (WHERE status IN ('present', 'late'))::NUMERIC / NULLIF(COUNT(*), 0)) * 100, 
        2
    ) AS attendance_percentage
FROM public.attendance
GROUP BY student_id;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_attendance_student_id ON public.attendance(student_id);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON public.attendance(attendance_date);
CREATE INDEX IF NOT EXISTS idx_attendance_status ON public.attendance(status);
CREATE INDEX IF NOT EXISTS idx_attendance_class_type ON public.attendance(class_type);
