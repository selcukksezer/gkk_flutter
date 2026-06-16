GRANT EXECUTE ON FUNCTION public.qa_segment_for_bot(integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.qa_assert_qa_mode() TO authenticated;
GRANT EXECUTE ON FUNCTION public.qa_call_as_bot(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.qa_cleanup_bots() TO authenticated;
GRANT EXECUTE ON FUNCTION public.qa_seed_mekans(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.qa_run_exploit_battery(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.qa_export_run_summary(uuid) TO authenticated;