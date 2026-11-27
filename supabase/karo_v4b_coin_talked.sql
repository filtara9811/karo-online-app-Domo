-- v4b: pool sirf un vendors me jinse grahak ne baat ki (replied); chune gaye ka hissa win_weight (2) guna.
-- Extra "jeet coin" ab default band (win_extra=false). Poora function Supabase migration
-- "karo_v4b_coin_talked_weighted" aur "karo_v4c_sim_text" me laga hai.
update ko_settings set v = v || jsonb_build_object('win_weight',2,'win_extra',false) where k='coin_cfg' and not (v ? 'win_weight');
-- Formula (settle par):
--   W = Σ weight (jinse baat hui; chuna gaya = win_weight, baaki = 1)
--   hissa = pool × weight / W × (jaldi ho to 1 − fast_pct%)
--   jinse baat nahi hui → roke hue coin poore wapas
-- Example: pool 5, 3 se baat, 1 chuna → chuna 2.5, baaki 1.25 + 1.25 = 5 coin company
