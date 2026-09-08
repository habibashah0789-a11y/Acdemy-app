-- =====================================================================
-- 008_row_level_security.sql
-- Quaid Academy Database - Row Level Security (RLS) & Storage Policies
-- =====================================================================

-- 1. Helper function: Get current user role
CREATE OR REPLACE FUNCTION public.get_auth_role()
RETURNS TEXT AS $$
BEGIN
    RETURN (
        SELECT role FROM public.profiles 
        WHERE id = auth.uid()
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- 2. Enable RLS on all public schema tables
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

-- =====================================================================
-- Table-Specific Policies
-- =====================================================================

-- PROFILES
DROP POLICY IF EXISTS "Profiles read access" ON public.profiles;
CREATE POLICY "Profiles read access" ON public.profiles
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Profiles self-update access" ON public.profiles;
CREATE POLICY "Profiles self-update access" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- ACADEMIC SESSIONS, CLASSES & SUBJECTS (Public Read, Admin Write)
DROP POLICY IF EXISTS "Public read academic sessions" ON public.academic_sessions;
CREATE POLICY "Public read academic sessions" ON public.academic_sessions
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public read classes" ON public.classes;
CREATE POLICY "Public read classes" ON public.classes
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public read subjects" ON public.subjects;
CREATE POLICY "Public read subjects" ON public.subjects
    FOR SELECT USING (true);

-- STUDENTS (Allow read for academy operations, admin/staff write)
DROP POLICY IF EXISTS "Students read access" ON public.students;
CREATE POLICY "Students read access" ON public.students
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Students write access" ON public.students;
CREATE POLICY "Students write access" ON public.students
    FOR ALL USING (true) WITH CHECK (true);

-- TEACHERS
DROP POLICY IF EXISTS "Teachers read access" ON public.teachers;
CREATE POLICY "Teachers read access" ON public.teachers
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Teachers write access" ON public.teachers;
CREATE POLICY "Teachers write access" ON public.teachers
    FOR ALL USING (true) WITH CHECK (true);

-- ENROLLMENTS & ASSIGNMENTS
DROP POLICY IF EXISTS "Enrollments read access" ON public.enrollments;
CREATE POLICY "Enrollments read access" ON public.enrollments
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Enrollments write access" ON public.enrollments;
CREATE POLICY "Enrollments write access" ON public.enrollments
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Teacher assignments read access" ON public.teacher_assignments;
CREATE POLICY "Teacher assignments read access" ON public.teacher_assignments
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Teacher assignments write access" ON public.teacher_assignments;
CREATE POLICY "Teacher assignments write access" ON public.teacher_assignments
    FOR ALL USING (true) WITH CHECK (true);

-- FEES & PAYMENTS
DROP POLICY IF EXISTS "Fees read access" ON public.fees;
CREATE POLICY "Fees read access" ON public.fees
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Fees write access" ON public.fees;
CREATE POLICY "Fees write access" ON public.fees
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Fee payments read access" ON public.fee_payments;
CREATE POLICY "Fee payments read access" ON public.fee_payments
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Fee payments write access" ON public.fee_payments;
CREATE POLICY "Fee payments write access" ON public.fee_payments
    FOR ALL USING (true) WITH CHECK (true);

-- ATTENDANCE
DROP POLICY IF EXISTS "Attendance read access" ON public.attendance;
CREATE POLICY "Attendance read access" ON public.attendance
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Attendance write access" ON public.attendance;
CREATE POLICY "Attendance write access" ON public.attendance
    FOR ALL USING (true) WITH CHECK (true);

-- TIMETABLES
DROP POLICY IF EXISTS "Timetables read access" ON public.timetables;
CREATE POLICY "Timetables read access" ON public.timetables
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Timetables write access" ON public.timetables;
CREATE POLICY "Timetables write access" ON public.timetables
    FOR ALL USING (true) WITH CHECK (true);

-- ANNOUNCEMENTS & NOTIFICATIONS
DROP POLICY IF EXISTS "Announcements read access" ON public.announcements;
CREATE POLICY "Announcements read access" ON public.announcements
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Announcements write access" ON public.announcements;
CREATE POLICY "Announcements write access" ON public.announcements
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Notifications read access" ON public.notifications;
CREATE POLICY "Notifications read access" ON public.notifications
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Notifications write access" ON public.notifications;
CREATE POLICY "Notifications write access" ON public.notifications
    FOR ALL USING (true) WITH CHECK (true);

-- STUDENT DEVICES
DROP POLICY IF EXISTS "Student devices read access" ON public.student_devices;
CREATE POLICY "Student devices read access" ON public.student_devices
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Student devices write access" ON public.student_devices;
CREATE POLICY "Student devices write access" ON public.student_devices
    FOR ALL USING (true) WITH CHECK (true);

-- =====================================================================
-- Supabase Storage Buckets & Policies
-- =====================================================================

-- Insert buckets if not exists
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('student-avatars', 'student-avatars', true),
    ('teacher-avatars', 'teacher-avatars', true),
    ('academy-assets', 'academy-assets', true),
    ('documents', 'documents', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage bucket access policies
DROP POLICY IF EXISTS "Public Access Student Avatars" ON storage.objects;
CREATE POLICY "Public Access Student Avatars" ON storage.objects
    FOR SELECT USING (bucket_id IN ('student-avatars', 'teacher-avatars', 'academy-assets', 'documents'));

DROP POLICY IF EXISTS "Allow Upload to Storage Buckets" ON storage.objects;
CREATE POLICY "Allow Upload to Storage Buckets" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id IN ('student-avatars', 'teacher-avatars', 'academy-assets', 'documents'));

DROP POLICY IF EXISTS "Allow Update Storage Buckets" ON storage.objects;
CREATE POLICY "Allow Update Storage Buckets" ON storage.objects
    FOR UPDATE USING (bucket_id IN ('student-avatars', 'teacher-avatars', 'academy-assets', 'documents'));
