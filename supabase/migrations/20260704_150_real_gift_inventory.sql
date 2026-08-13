CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.user_gift_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    gift_id UUID NOT NULL REFERENCES public.gift_catalog(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    total_received INTEGER NOT NULL DEFAULT 0 CHECK (total_received >= 0),
    total_sent INTEGER NOT NULL DEFAULT 0 CHECK (total_sent >= 0),
    last_transaction_id UUID,
    source TEXT NOT NULL DEFAULT 'app',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, gift_id)
);

CREATE INDEX IF NOT EXISTS idx_user_gift_inventory_user_updated
ON public.user_gift_inventory(user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_gift_inventory_gift
ON public.user_gift_inventory(gift_id);

ALTER TABLE public.user_gift_inventory ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own gift inventory" ON public.user_gift_inventory;
CREATE POLICY "Users can view own gift inventory"
ON public.user_gift_inventory
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role manages gift inventory" ON public.user_gift_inventory;
CREATE POLICY "Service role manages gift inventory"
ON public.user_gift_inventory
FOR ALL
USING (true)
WITH CHECK (true);

ALTER TABLE public.gift_transactions
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'sent';

ALTER TABLE public.gift_transactions
ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

INSERT INTO public.user_gift_inventory (
    user_id,
    gift_id,
    quantity,
    total_received,
    total_sent,
    last_transaction_id,
    source,
    updated_at
)
SELECT
    gt.receiver_id,
    gt.gift_id,
    COUNT(*)::integer AS quantity,
    COUNT(*)::integer AS total_received,
    0 AS total_sent,
    (array_agg(gt.id ORDER BY gt.created_at DESC))[1] AS last_transaction_id,
    'received_backfill' AS source,
    now()
FROM public.gift_transactions gt
WHERE gt.receiver_id IS NOT NULL
  AND gt.gift_id IS NOT NULL
GROUP BY gt.receiver_id, gt.gift_id
ON CONFLICT (user_id, gift_id)
DO UPDATE SET
    quantity = GREATEST(public.user_gift_inventory.quantity, EXCLUDED.quantity),
    total_received = GREATEST(public.user_gift_inventory.total_received, EXCLUDED.total_received),
    last_transaction_id = COALESCE(EXCLUDED.last_transaction_id, public.user_gift_inventory.last_transaction_id),
    updated_at = now();

DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.gift_transactions;
    EXCEPTION WHEN duplicate_object OR undefined_table THEN
        NULL;
    END;

    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.user_gift_inventory;
    EXCEPTION WHEN duplicate_object OR undefined_table THEN
        NULL;
    END;
END $$;
