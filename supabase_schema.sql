-- Supabase Database Schema for GOALSTAKE 26
-- Copy-paste these SQL queries into the SQL Editor in your Supabase Dashboard

-- 1. Create table for Public Predictions (Community Feed)
CREATE TABLE IF NOT EXISTS public.public_predictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
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

CREATE POLICY "Allow authenticated insert of predictions" 
ON public.public_predictions FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow user update of own predictions" 
ON public.public_predictions FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Allow admin to manage all predictions" 
ON public.public_predictions FOR ALL 
USING (
    EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() AND is_admin = true
    )
);

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

CREATE POLICY "Allow admin read of analytics" 
ON public.analytics FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() AND is_admin = true
    )
);

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
