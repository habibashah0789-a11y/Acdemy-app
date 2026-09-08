-- =====================================================================
-- 009_functions_triggers.sql
-- Quaid Academy Database - Triggers, Analytical Functions & Stored Procedures
-- =====================================================================

-- 1. Automatic Timestamp Update Trigger Function
CREATE OR REPLACE FUNCTION public.trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to relevant tables
DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();

DROP TRIGGER IF EXISTS trg_students_updated_at ON public.students;
CREATE TRIGGER trg_students_updated_at
    BEFORE UPDATE ON public.students
    FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();

DROP TRIGGER IF EXISTS trg_teachers_updated_at ON public.teachers;
CREATE TRIGGER trg_teachers_updated_at
    BEFORE UPDATE ON public.teachers
    FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();

DROP TRIGGER IF EXISTS trg_fees_updated_at ON public.fees;
CREATE TRIGGER trg_fees_updated_at
    BEFORE UPDATE ON public.fees
    FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();

DROP TRIGGER IF EXISTS trg_timetables_updated_at ON public.timetables;
CREATE TRIGGER trg_timetables_updated_at
    BEFORE UPDATE ON public.timetables
    FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();

DROP TRIGGER IF EXISTS trg_announcements_updated_at ON public.announcements;
CREATE TRIGGER trg_announcements_updated_at
    BEFORE UPDATE ON public.announcements
    FOR EACH ROW EXECUTE FUNCTION public.trigger_set_updated_at();

-- 2. Stored Procedure: Auto-update Student Balance upon Payment
CREATE OR REPLACE FUNCTION public.fn_sync_student_balance_on_payment()
RETURNS TRIGGER AS $$
DECLARE
    v_total_paid NUMERIC(10, 2);
    v_total_fee NUMERIC(10, 2);
BEGIN
    -- Calculate total payments made by the student
    SELECT COALESCE(SUM(amount_paid), 0.00)
    INTO v_total_paid
    FROM public.fee_payments
    WHERE student_id = NEW.student_id;

    -- Calculate total fees assigned to the student
    SELECT COALESCE(SUM(total_amount - discount_amount), 0.00)
    INTO v_total_fee
    FROM public.fees
    WHERE student_id = NEW.student_id;

    -- Update student summary record
    UPDATE public.students
    SET 
        fee_submitted = v_total_paid,
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

-- 3. Stored Procedure: Monthly Revenue & Collection Analytics Report
CREATE OR REPLACE FUNCTION public.fn_monthly_revenue_report(
    p_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT,
    p_month INT DEFAULT EXTRACT(MONTH FROM CURRENT_DATE)::INT
)
RETURNS TABLE (
    total_revenue NUMERIC(12, 2),
    total_transactions BIGINT,
    cash_payments NUMERIC(12, 2),
    online_payments NUMERIC(12, 2),
    bank_payments NUMERIC(12, 2),
    unique_students_paid BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(SUM(fp.amount_paid), 0.00)::NUMERIC(12, 2) AS total_revenue,
        COUNT(fp.id)::BIGINT AS total_transactions,
        COALESCE(SUM(CASE WHEN LOWER(fp.payment_method) = 'cash' THEN fp.amount_paid ELSE 0 END), 0.00)::NUMERIC(12, 2) AS cash_payments,
        COALESCE(SUM(CASE WHEN LOWER(fp.payment_method) IN ('online', 'easypaisa', 'jazzcash') THEN fp.amount_paid ELSE 0 END), 0.00)::NUMERIC(12, 2) AS online_payments,
        COALESCE(SUM(CASE WHEN LOWER(fp.payment_method) = 'bank' THEN fp.amount_paid ELSE 0 END), 0.00)::NUMERIC(12, 2) AS bank_payments,
        COUNT(DISTINCT fp.student_id)::BIGINT AS unique_students_paid
    FROM public.fee_payments fp
    WHERE EXTRACT(YEAR FROM fp.payment_date) = p_year
      AND EXTRACT(MONTH FROM fp.payment_date) = p_month;
END;
$$ LANGUAGE plpgsql STABLE;

-- 4. Stored Procedure: Academy Dashboard Overall Statistics
CREATE OR REPLACE FUNCTION public.fn_academy_dashboard_stats()
RETURNS TABLE (
    total_active_students BIGINT,
    total_active_teachers BIGINT,
    total_classes BIGINT,
    total_monthly_revenue NUMERIC(12, 2),
    total_pending_fees NUMERIC(12, 2),
    today_attendance_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM public.students WHERE is_active = TRUE)::BIGINT AS total_active_students,
        (SELECT COUNT(*) FROM public.teachers WHERE is_active = TRUE)::BIGINT AS total_active_teachers,
        (SELECT COUNT(*) FROM public.classes)::BIGINT AS total_classes,
        (
            SELECT COALESCE(SUM(amount_paid), 0.00)::NUMERIC(12, 2)
            FROM public.fee_payments
            WHERE payment_date >= DATE_TRUNC('month', CURRENT_DATE)
        ) AS total_monthly_revenue,
        (
            SELECT COALESCE(SUM(fee_remaining), 0.00)::NUMERIC(12, 2)
            FROM public.students
            WHERE is_active = TRUE
        ) AS total_pending_fees,
        (
            SELECT COUNT(*)
            FROM public.attendance
            WHERE date = CURRENT_DATE AND status = 'present'
        )::BIGINT AS today_attendance_count;
END;
$$ LANGUAGE plpgsql STABLE;
