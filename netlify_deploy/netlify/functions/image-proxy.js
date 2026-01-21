export async function handler(event) {
  const imageUrl = event.queryStringParameters?.url;

  if (!imageUrl) {
    return {
      statusCode: 400,
      body: "Missing url parameter",
    };
  }

  try {
    const response = await fetch(imageUrl);

    return {
      statusCode: response.status,
      headers: {
        "Content-Type": response.headers.get("content-type") || "image/jpeg",
        "Access-Control-Allow-Origin": "*",
      },
      body: await response.arrayBuffer(),
      isBase64Encoded: false,
    };
  } catch (err) {
    return {
      statusCode: 500,
      body: err.toString(),
    };
  }
}
