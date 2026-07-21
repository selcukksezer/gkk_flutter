-- Client mekan create screen: type costs/levels from same source as open_mekan.

CREATE OR REPLACE FUNCTION public.get_mekan_type_catalog()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN jsonb_build_object(
    'success', true,
    'types', jsonb_build_array(
      jsonb_build_object('type', 'bar', 'cost', 5000000, 'req_level', 15),
      jsonb_build_object('type', 'kahvehane', 'cost', 8000000, 'req_level', 20),
      jsonb_build_object('type', 'dovus_kulubu', 'cost', 15000000, 'req_level', 30),
      jsonb_build_object('type', 'luks_lounge', 'cost', 50000000, 'req_level', 45),
      jsonb_build_object('type', 'yeralti', 'cost', 200000000, 'req_level', 60)
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_mekan_type_catalog() TO authenticated;
