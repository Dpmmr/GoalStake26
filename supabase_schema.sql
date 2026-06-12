-- Supabase Database Schema Updates for GOALSTAKE 26
-- Copy-paste these SQL queries into the SQL Editor in your Supabase Dashboard

-- ==========================================
-- STEP 1: CONVERT FOREIGN KEYS TO public.users
-- ==========================================
-- Since SMS OTP Auth is removed, users are created directly in public.users anonymously.
-- We must remove constraints referencing auth.users(id) and redirect them to public.users(id).

-- 1. Modify public.users Table
-- Make sure public.users.id generates a random UUID automatically on insert
ALTER TABLE IF EXISTS public.users DROP CONSTRAINT IF EXISTS users_id_fkey;
ALTER TABLE public.users ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- 2. Modify public.bets Table
ALTER TABLE IF EXISTS public.bets DROP CONSTRAINT IF EXISTS bets_user_id_fkey;
ALTER TABLE public.bets ADD CONSTRAINT bets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- 3. Modify public.last_dance_bets Table
ALTER TABLE IF EXISTS public.last_dance_bets DROP CONSTRAINT IF EXISTS last_dance_bets_user_id_fkey;
ALTER TABLE public.last_dance_bets ADD CONSTRAINT last_dance_bets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


-- ==========================================
-- STEP 2: CREATE NEW TABLES & TRIGGERS
-- ==========================================

-- 1. Create table for Public Predictions (Community Feed)
CREATE TABLE IF NOT EXISTS public.public_predictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    gs_id TEXT NOT NULL,
    full_name TEXT NOT NULL,
    prediction_text TEXT NOT NULL,
    home_team TEXT NOT NULL,
    away_team TEXT NOT NULL,
    home_score_pred INT NOT NULL DEFAULT 0,
    away_score_pred INT NOT NULL DEFAULT 0,
    likes_count INT NOT NULL DEFAULT 0,
    liked_by_users UUID[] DEFAULT '{}',
    comments JSONB DEFAULT '[]',
    shares_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    is_featured BOOLEAN DEFAULT false
);

-- Enable RLS and Policies for public_predictions
ALTER TABLE public.public_predictions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to predictions" 
ON public.public_predictions FOR SELECT USING (true);

CREATE POLICY "Allow public insert of predictions" 
ON public.public_predictions FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow public update of predictions" 
ON public.public_predictions FOR UPDATE USING (true);


-- 2. Create table for App Traffic Analytics
CREATE TABLE IF NOT EXISTS public.analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL, -- e.g., 'share', 'view', 'click', 'conversion'
    match_id TEXT,
    source TEXT NOT NULL, -- e.g., 'whatsapp', 'telegram', 'facebook', 'x', 'instagram'
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS and Policies for analytics
ALTER TABLE public.analytics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public insert of analytics" 
ON public.analytics FOR INSERT WITH CHECK (true);


-- 3. Add suspension column to users table (if not exists)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;


-- 4. Create trigger to update user stats on Bet transitions
CREATE OR REPLACE FUNCTION public.handle_bet_stat_update()
RETURNS TRIGGER AS $$
BEGIN
    -- If bet was approved (status: pending -> active)
    IF OLD.status = 'pending' AND NEW.status = 'active' THEN
        UPDATE public.users 
        SET total_bets = total_bets + 1,
            total_staked = total_staked + NEW.amount
        WHERE id = NEW.user_id;
    END IF;

    -- If bet was settled as won
    IF OLD.status = 'active' AND NEW.status = 'won' THEN
        UPDATE public.users 
        SET wins = wins + 1,
            total_earned = total_earned + NEW.potential_payout
        WHERE id = NEW.user_id;
    END IF;

    -- If bet was settled as lost
    IF OLD.status = 'active' AND NEW.status = 'lost' THEN
        UPDATE public.users 
        SET losses = losses + 1
    WHERE id = NEW.user_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER tr_update_user_stats
AFTER UPDATE ON public.bets
FOR EACH ROW
EXECUTE FUNCTION public.handle_bet_stat_update();


-- 5. Helper function for incrementing Country Pool Staking
CREATE OR REPLACE FUNCTION public.increment_country_pool(p_country TEXT, p_amount NUMERIC)
RETURNS VOID AS $$
BEGIN
    UPDATE public.country_pool
    SET total_staked = total_staked + p_amount,
        participants = participants + 1
    WHERE country = p_country;
END;
$$ LANGUAGE plpgsql;
