-- =====================================================================
-- 005_timetable.sql
-- Quaid Academy Database - Timetable & Scheduling (7:00 AM to 10:00 PM)
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
    -- Academy operational hours constraint: 7:00 AM (07:00) to 10:00 PM (22:00)
    CONSTRAINT valid_timetable_slot CHECK (
        start_time >= '07:00:00'::TIME 
        AND end_time <= '22:00:00'::TIME 
        AND end_time > start_time
    ),
    -- Prevent overlapping class schedules for the same slot
    CONSTRAINT unique_class_slot UNIQUE (class_id, day_of_week, start_time)
);

-- Indexes for lightning fast timetable lookups
CREATE INDEX IF NOT EXISTS idx_timetables_class ON public.timetables(class_id);
CREATE INDEX IF NOT EXISTS idx_timetables_teacher ON public.timetables(teacher_id);
CREATE INDEX IF NOT EXISTS idx_timetables_day ON public.timetables(day_of_week);

-- View: Complete timetable details with Class, Subject & Teacher names
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
    tc.email AS teacher_email,
    t.day_of_week,
    t.start_time,
    t.end_time,
    t.room,
    t.is_active,
    t.created_at
FROM public.timetables t
JOIN public.classes c ON t.class_id = c.id
JOIN public.subjects s ON t.subject_id = s.id
LEFT JOIN public.teachers tc ON t.teacher_id = tc.id
ORDER BY 
    CASE t.day_of_week
        WHEN 'Monday' THEN 1
        WHEN 'Tuesday' THEN 2
        WHEN 'Wednesday' THEN 3
        WHEN 'Thursday' THEN 4
        WHEN 'Friday' THEN 5
        WHEN 'Saturday' THEN 6
        WHEN 'Sunday' THEN 7
    END,
    t.start_time ASC;
