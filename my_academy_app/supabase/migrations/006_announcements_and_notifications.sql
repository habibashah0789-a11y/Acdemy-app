-- =====================================================================
-- 006_announcements_and_notifications.sql
-- Quaid Academy Database - Announcements & In-App Notification History
-- =====================================================================

-- 1. Announcements Table
CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    target_class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE, -- NULL = Academy-wide
    author_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'urgent')),
    is_published BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Notification Records Table (Stores delivered push/in-app notifications)
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipient_id TEXT NOT NULL, -- Target Student ID, Teacher ID or Profile UUID
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT DEFAULT 'general' CHECK (type IN ('general', 'fee_reminder', 'attendance_alert', 'exam_schedule', 'announcement')),
    data JSONB DEFAULT '{}'::JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast query performance
CREATE INDEX IF NOT EXISTS idx_announcements_target_class ON public.announcements(target_class_id);
CREATE INDEX IF NOT EXISTS idx_announcements_published ON public.announcements(is_published);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON public.notifications(recipient_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);

-- View: Active Announcements with Target Class Name
CREATE OR REPLACE VIEW public.v_active_announcements AS
SELECT 
    a.id,
    a.title,
    a.content,
    a.target_class_id,
    c.name AS target_class_name,
    c.level AS target_class_level,
    a.priority,
    a.is_published,
    a.expires_at,
    a.created_at
FROM public.announcements a
LEFT JOIN public.classes c ON a.target_class_id = c.id
WHERE a.is_published = TRUE
  AND (a.expires_at IS NULL OR a.expires_at > NOW())
ORDER BY 
    CASE a.priority
        WHEN 'urgent' THEN 1
        WHEN 'normal' THEN 2
        WHEN 'low' THEN 3
    END,
    a.created_at DESC;
