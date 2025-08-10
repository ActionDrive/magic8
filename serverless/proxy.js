// Cloudflare Worker / Vercel Edge proxy for OpenAI-compatible API
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (!url.pathname.startsWith("/v1/")) {
      return new Response("OK", { status: 200 });
    }
    const upstream = "https://api.openai.com" + url.pathname;
    const body = await request.text();
    const res = await fetch(upstream, {
      method: request.method,
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${env.OPENAI_API_KEY}`
      },
      body
    });
    return new Response(res.body, { status: res.status, headers: res.headers });
  }
};
