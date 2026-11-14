CREATE TABLE public.reward_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reward_id text NOT NULL CHECK (reward_id = 'freshy-freshy-drink'),
  points_spent integer NOT NULL CHECK (points_spent = 100),
  redeemed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.reward_redemptions ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.reward_redemptions TO authenticated;
GRANT ALL ON public.reward_redemptions TO service_role;

CREATE POLICY "Users can view their own reward redemptions"
ON public.reward_redemptions FOR SELECT TO authenticated
USING (auth.uid() = user_id);

CREATE FUNCTION public.redeem_freshy_freshy_drink()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  current_user_id uuid := auth.uid();
  remaining_points integer;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Please sign in to redeem this reward.' USING ERRCODE = '28000';
  END IF;

  UPDATE public.profiles
  SET streak_points = streak_points - 100
  WHERE id = current_user_id AND streak_points >= 100
  RETURNING streak_points INTO remaining_points;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'You need at least 100 points to redeem this reward.' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.reward_redemptions (user_id, reward_id, points_spent)
  VALUES (current_user_id, 'freshy-freshy-drink', 100);

  RETURN remaining_points;
END;
$$;

REVOKE ALL ON FUNCTION public.redeem_freshy_freshy_drink() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.redeem_freshy_freshy_drink() FROM anon;
GRANT EXECUTE ON FUNCTION public.redeem_freshy_freshy_drink() TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_freshy_freshy_drink() TO service_role;
