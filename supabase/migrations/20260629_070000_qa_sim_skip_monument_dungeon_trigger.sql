-- QA sim dungeon_runs insert: skip monument loot trigger (bot auth_id vs inventory FK)

CREATE OR REPLACE FUNCTION public.apply_monument_dungeon_drops()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_zone INT;
  v_is_boss BOOLEAN;
  v_structural INT := 0;
  v_mystical INT := 0;
  v_critical INT := 0;
BEGIN
  IF coalesce(current_setting('app.qa_mode', true), '') = 'true' THEN
    RETURN NEW;
  END IF;

  IF NOT NEW.success THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(d.zone, 1), COALESCE(d.is_boss, false)
  INTO v_zone, v_is_boss
  FROM public.dungeons d
  WHERE d.id = NEW.dungeon_id;

  IF v_zone <= 3 THEN
    v_structural := 2 + floor(random() * 9)::INT;
  ELSIF v_zone <= 5 THEN
    v_structural := 5 + floor(random() * 16)::INT;
  ELSE
    v_structural := 10 + floor(random() * 21)::INT;
  END IF;

  IF v_is_boss THEN
    IF v_zone <= 3 THEN
      v_mystical := 5 + floor(random() * 16)::INT;
    ELSIF v_zone <= 5 THEN
      v_mystical := 15 + floor(random() * 26)::INT;
    ELSE
      v_mystical := 30 + floor(random() * 51)::INT;
    END IF;
  END IF;

  IF v_zone >= 6 THEN
    IF v_zone >= 7 AND random() <= 0.50 THEN
      v_critical := 2 + floor(random() * 4)::INT;
    ELSIF random() <= 0.30 THEN
      v_critical := 1 + floor(random() * 3)::INT;
    END IF;
  END IF;

  IF v_is_boss AND v_zone >= 5 THEN
    v_critical := v_critical + 5 + floor(random() * 11)::INT;
  END IF;

  PERFORM public.grant_monument_resource_items(NEW.player_id, v_structural, v_mystical, v_critical);
  RETURN NEW;
END;
$$;
