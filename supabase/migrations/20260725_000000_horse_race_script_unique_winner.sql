-- Fix race script: winner uniquely first at t=1.0 (old scripts tied multiple horses at 1.0).
CREATE OR REPLACE FUNCTION public._horse_race_generate_race_script(
  p_winner_id TEXT,
  p_horse_ids TEXT[],
  p_duration_ms INTEGER DEFAULT 8000
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_finish_order TEXT[] := ARRAY[]::TEXT[];
  v_remaining TEXT[];
  v_leader TEXT;
  v_hid TEXT;
  v_positions JSONB := '{}'::jsonb;
  v_keyframes JSONB := '[]'::jsonb;
  v_t NUMERIC;
  v_progress NUMERIC;
  v_i INTEGER;
  v_j INTEGER;
  v_n INTEGER;
  v_surge NUMERIC;
  v_times NUMERIC[] := ARRAY[0.0, 0.18, 0.38, 0.58, 0.78, 0.90, 1.0];
BEGIN
  v_remaining := ARRAY(SELECT unnest(p_horse_ids) EXCEPT SELECT unnest(ARRAY[p_winner_id]));
  v_remaining := ARRAY(SELECT x FROM unnest(v_remaining) AS x ORDER BY random());
  -- Winner first in finish_order (= 1st place).
  v_finish_order := ARRAY[p_winner_id] || v_remaining;
  v_n := GREATEST(array_length(v_finish_order, 1), 1);

  FOREACH v_t IN ARRAY v_times LOOP
    v_positions := '{}'::jsonb;
    -- Temporary mid-race leaders from non-winners for drama.
    IF v_t < 0.78 AND array_length(v_remaining, 1) IS NOT NULL THEN
      v_leader := v_remaining[1 + (FLOOR(v_t * 4)::INTEGER % GREATEST(array_length(v_remaining, 1), 1))];
    ELSE
      v_leader := p_winner_id;
    END IF;

    FOR v_i IN 1..array_length(p_horse_ids, 1) LOOP
      v_hid := p_horse_ids[v_i];
      v_j := array_position(v_finish_order, v_hid);
      IF v_j IS NULL THEN
        v_j := v_n;
      END IF;

      IF v_t >= 0.90 THEN
        -- Locked unique finish: winner=1.0, 2nd=0.96, 3rd=0.92, ...
        v_progress := GREATEST(0.55, 1.0 - (v_j - 1) * 0.04);
      ELSIF v_t >= 0.78 THEN
        -- Final stretch: winner surges clear of pack.
        v_surge := (v_t - 0.78) / 0.22;
        IF v_hid = p_winner_id THEN
          v_progress := 0.72 + v_surge * 0.28;
        ELSE
          v_progress := 0.62 + v_surge * (0.30 - (v_j - 1) * 0.04);
          v_progress := LEAST(v_progress, 0.72 + v_surge * 0.28 - 0.04 * v_j);
        END IF;
      ELSE
        -- Mid race scramble; non-winners can lead briefly.
        v_progress := v_t * (0.50 + (v_n - v_j + 1)::NUMERIC * 0.07);
        IF v_hid = v_leader THEN
          v_progress := v_progress + 0.08;
        END IF;
        IF v_hid = p_winner_id THEN
          v_progress := LEAST(v_progress, v_t * 0.88);
        END IF;
      END IF;

      v_positions := v_positions || jsonb_build_object(
        v_hid,
        ROUND(GREATEST(0, LEAST(1, v_progress))::NUMERIC, 4)
      );
    END LOOP;

    v_keyframes := v_keyframes || jsonb_build_array(
      jsonb_build_object('t', v_t, 'positions', v_positions, 'leader_id', v_leader)
    );
  END LOOP;

  RETURN jsonb_build_object(
    'duration_ms', p_duration_ms,
    'finish_order', to_jsonb(v_finish_order),
    'winner_id', p_winner_id,
    'keyframes', v_keyframes
  );
END;
$$;
