-- =====================================================================
-- 002_students_and_teachers.sql
-- Quaid Academy Database - Students, Teachers, Enrollments & Assignments
-- =====================================================================

-- 1. Students Table
CREATE TABLE IF NOT EXISTS public.students (
    id TEXT PRIMARY KEY, -- Supports existing Firestore ID or UUID
    student_code TEXT NOT NULL UNIQUE, -- e.g. 'QA-11-2026-001'
    first_name TEXT NOT NULL,
    last_name TEXT DEFAULT '',
    father_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    email TEXT DEFAULT '',
    class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
    class_type TEXT DEFAULT 'FSc', -- 'FSc', 'Matric', 'MDCAT'
    grade TEXT DEFAULT 'First Year', -- 'Ninth', 'Tenth', 'First Year', 'Second Year'
    subject TEXT DEFAULT 'Biology', -- Legacy comma-separated or primary subject
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

-- 2. Teachers Table
CREATE TABLE IF NOT EXISTS public.teachers (
    id TEXT PRIMARY KEY, -- Firebase Auth UID or UUID
    teacher_id TEXT NOT NULL UNIQUE, -- e.g. 'T-001'
    name TEXT NOT NULL,
    phone TEXT DEFAULT '',
    email TEXT UNIQUE NOT NULL,
    subject TEXT NOT NULL, -- Primary subject specialization
    section TEXT DEFAULT 'FSc', -- 'FSc', 'Matric', 'Both'
    profile_pic_url TEXT DEFAULT '',
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'on_leave')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Student Subject Enrollments (Relational mapping between student, class & subject)
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

-- 4. Teacher Class/Subject Assignments (Relational mapping)
CREATE TABLE IF NOT EXISTS public.teacher_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id TEXT NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
    class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_teacher_class_subject UNIQUE (teacher_id, class_id, subject_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_students_student_code ON public.students(student_code);
CREATE INDEX IF NOT EXISTS idx_students_class_id ON public.students(class_id);
CREATE INDEX IF NOT EXISTS idx_students_status ON public.students(enrollment_status);
CREATE INDEX IF NOT EXISTS idx_teachers_teacher_id ON public.teachers(teacher_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_student_id ON public.enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_subject_id ON public.enrollments(subject_id);
