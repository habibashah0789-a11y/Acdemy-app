-- =====================================================================
-- 007_student_devices.sql
-- Quaid Academy Database - Student Device Binding & Session Management
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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_student_devices_student ON public.student_devices(student_id);
CREATE INDEX IF NOT EXISTS idx_student_devices_active ON public.student_devices(is_active);
CREATE INDEX IF NOT EXISTS idx_student_devices_token ON public.student_devices(fcm_token);

-- Procedure / Function: Register or refresh student device
CREATE OR REPLACE FUNCTION public.fn_register_student_device(
    p_student_id TEXT,
    p_device_id TEXT,
    p_model TEXT,
    p_platform TEXT,
    p_fcm_token TEXT
)
RETURNS UUID AS $$
DECLARE
    v_device_row_id UUID;
BEGIN
    INSERT INTO public.student_devices (
        student_id, device_identifier, device_model, platform, fcm_token, is_active, last_seen, updated_at
    )
    VALUES (
        p_student_id, p_device_id, p_model, p_platform, p_fcm_token, TRUE, NOW(), NOW()
    )
    ON CONFLICT (student_id, device_identifier)
    DO UPDATE SET
        device_model = EXCLUDED.device_model,
        platform = EXCLUDED.platform,
        fcm_token = EXCLUDED.fcm_token,
        is_active = TRUE,
        last_seen = NOW(),
        updated_at = NOW()
    RETURNING id INTO v_device_row_id;

    RETURN v_device_row_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
