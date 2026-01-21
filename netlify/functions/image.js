export default async (req, context) => {
  const imageUrl = req.queryStringParameters?.url;

  if (!imageUrl) {
    return {
      statusCode: 400,
      body: "Missing image URL",
    };
  }

  try {
    const response = await fetch(imageUrl, {
      headers: {
        // ⚠️ ISSO É O QUE FAZ FUNCIONAR
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36",
        "Referer": "https://www.reddit.com/",
        "Accept": "image/*,*/*;q=0.8",
      },
    });

    if (!response.ok) {
      return {
        statusCode: response.status,
        body: `Upstream error ${response.status}`,
      };
    }

    const buffer = Buffer.from(await response.arrayBuffer());

    return {
      statusCode: 200,
      headers: {
        "Content-Type": response.headers.get("content-type") || "image/jpeg",
        "Cache-Control": "public, max-age=86400",
      },
      body: buffer.toString("base64"),
      isBase64Encoded: true,
    };
  } catch (err) {
    return {
      statusCode: 500,
      body: "Internal error",
    };
  }
};
