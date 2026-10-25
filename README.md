# Karo Online — Customer App

- `docs/` — ऐप की सारी screens (prototype)। GitHub Pages पर **LIVE** चलती हैं।
  यहाँ बदलाव push होते ही 1–2 मिनट में ऐप में दिखने लगता है — APK दोबारा install नहीं करनी।
- `app/` — Flutter ऐप (WebView)। Net न हो तो अंदर रखी offline copy चलती है।
- `.github/workflows/build.yml` — हर push पर नई APK बनती है (Actions → Artifacts)।

Powered by Filipra Private Limited
