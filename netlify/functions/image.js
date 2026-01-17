exports.handler = async (event) => {
  try {
    const rawUrl = event.queryStringParameters?.url;
    if (!rawUrl) {
      return {
        statusCode: 400,
        headers: { "Access-Control-Allow-Origin": "*" },
        body: "Missing ?url=",
      };
    }

    // decodifica o parâmetro
    const targetUrl = decodeURIComponent(rawUrl);

    // valida destino (segurança básica)
    let u;
    try {
      u = new URL(targetUrl);
    } catch {
      return {
        statusCode: 400,
        headers: { "Access-Control-Allow-Origin": "*" },
        body: "Invalid url",
      };
    }

    const allowedHosts = new Set([
      "i.redd.it",
      "external-preview.redd.it",
      "preview.redd.it",
      "styles.redditmedia.com",
      "i.imgur.com",
      "imgur.com",
    ]);

    if (!allowedHosts.has(u.hostname)) {
      return {
        statusCode: 403,
        headers: { "Access-Control-Allow-Origin": "*" },
        body: `Host not allowed: ${u.hostname}`,
      };
    }

    // busca a imagem com User-Agent (muito importante)
    const resp = await fetch(targetUrl, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36",
        "Accept":
          "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
        "Referer": "https://www.reddit.com/",
      },
      redirect: "follow",
    });

    if (!resp.ok) {
      const txt = await resp.text().catch(() => "");
      return {
        statusCode: resp.status,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Cache-Control": "public, max-age=60",
        },
        body: `Upstream error ${resp.status}: ${txt.slice(0, 200)}`,
      };
    }

    const contentType =
      resp.headers.get("content-type") || "application/octet-stream";

    const arrayBuffer = await resp.arrayBuffer();
    const base64 = Buffer.from(arrayBuffer).toString("base64");

    return {
      statusCode: 200,
      isBase64Encoded: true,
      headers: {
        "Content-Type": contentType,
        "Access-Control-Allow-Origin": "*",
        "Cache-Control": "public, max-age=3600",
      },
      body: base64,
    };
  } catch (e) {
    return {
      statusCode: 500,
      headers: { "Access-Control-Allow-Origin": "*" },
      body: `Internal error: ${String(e)}`,
    };
  }
};