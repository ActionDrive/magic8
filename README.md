# Magic 8 — Pro
1) Cloudflare Workers: задеплой `serverless/proxy.js`, добавь секрет `OPENAI_API_KEY`, скопируй https://xxx.workers.dev
2) Codemagic: подключи репозиторий, задай `AI_BASE_URL=https://xxx.workers.dev`, `AI_MODEL=gpt-4o-mini`, `AI_KEY` пусто. Start build.
3) APK возьми из Artifacts (app-debug.apk для теста). В приложении включи ИИ и поставь Base URL.
