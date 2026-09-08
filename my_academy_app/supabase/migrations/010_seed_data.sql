-- =====================================================================
-- 010_seed_data.sql
-- Quaid Academy Database - Default Seed Data (Academic Session, Classes, Subjects)
-- =====================================================================

-- 1. Default Academic Session (2026-2027)
INSERT INTO public.academic_sessions (id, name, start_date, end_date, is_current)
VALUES 
    ('a0000000-0000-0000-0000-000000000001', 'Session 2026-2027', '2026-04-01', '2027-03-31', TRUE)
ON CONFLICT (name) DO UPDATE SET is_current = TRUE;

-- 2. Default Classes for Quaid Academy
INSERT INTO public.classes (id, name, level, academic_session_id)
VALUES 
    ('c0000000-0000-0000-0000-000000000001', '9th Class', 'Matric', 'a0000000-0000-0000-0000-000000000001'),
    ('c0000000-0000-0000-0000-000000000002', '10th Class', 'Matric', 'a0000000-0000-0000-0000-000000000001'),
    ('c0000000-0000-0000-0000-000000000003', '1st Year (11th)', 'FSc', 'a0000000-0000-0000-0000-000000000001'),
    ('c0000000-0000-0000-0000-000000000004', '2nd Year (12th)', 'FSc', 'a0000000-0000-0000-0000-000000000001'),
    ('c0000000-0000-0000-0000-000000000005', 'MDCAT Preparation', 'MDCAT', 'a0000000-0000-0000-0000-000000000001')
ON CONFLICT (name, academic_session_id) DO NOTHING;

-- 3. Core Academic Subjects
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
