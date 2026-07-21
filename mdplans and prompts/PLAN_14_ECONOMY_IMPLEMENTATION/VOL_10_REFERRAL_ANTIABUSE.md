# PLAN 14 — Cilt 10: Referral Anti-Abuse

> **Öncelik:** P1  
> **Migration:** `20260722_080000_referral_abuse_limits.sql`

---

## 1. Mevcut Sistem

- Davet eden: +50 elmas (referred level 5)
- Davet edilen: +25 elmas
- `referral_rewards` tablosu — UNIQUE referred_id
- Self-referral kısmen gate

**Risk:** Alt hesap farm, bot kayıt.

---

## 2. Önerilen Kontroller

| Kontrol | Uygulama |
|---------|----------|
| Max referral claim / ay / user | 10 |
| Referred hesap min yaşı | 7 gün |
| Referred min dungeon clears | 10 |
| Aynı IP/device fingerprint | Flag + manual review |
| Level 5 + email verified | Zorunlu |

---

## 3. Migration Taslağı

```sql
-- claim_referral_rewards içinde:
IF (SELECT COUNT(*) FROM referral_rewards 
    WHERE referrer_id = v_me 
    AND referrer_claimed_at > now() - interval '30 days') >= 10 THEN
  RETURN jsonb_build_object('success', false, 'error', 'Monthly referral cap reached');
END IF;
```

---

## 4. Kabul Kriterleri

- [ ] Aylık cap staging test
- [ ] Bot sim referral exploit 0 başarı

---

## 5. Alt Görevler

- 10.1 Device fingerprint (opsiyonel — privacy review)
- 10.2 Referral dashboard admin
- 10.3 Anomaly alert (VOL_12)
