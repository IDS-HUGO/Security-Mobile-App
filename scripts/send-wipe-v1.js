const crypto = require("crypto");
const fs = require("fs");
const https = require("https");
const path = require("path");
const querystring = require("querystring");

const repoRoot = path.resolve(__dirname, "..");

const defaults = {
  googleServicesPath: path.join(repoRoot, "android", "app", "google-services.json"),
  serviceAccountPath: "C:\\Users\\Esparrago\\Downloads\\service-account.json",
  token:
    "f1s-RnHLTM67igFbt--PMd:APA91bF-LjmQOYsInJaPeYN0K_Yn30J1WfO-YwUrioQXv4z7gUes1dd9gkhFfHG7Tan_mJlb9tRS-P5sGV-gZg6HRxRHN_xKwOSmr8UN07B-qGC8xpVVKUM",
  email: "demo@demo.com",
  word: "aguacate",
};

function parseArgs(argv) {
  const args = { ...defaults };

  for (let i = 2; i < argv.length; i += 1) {
    const name = argv[i];
    const value = argv[i + 1];

    if (name === "--help" || name === "-h") {
      printUsage();
      process.exit(0);
    }

    if (!name.startsWith("--") || value === undefined || value.startsWith("--")) {
      throw new Error(`Parametro invalido o incompleto: ${name}`);
    }

    if (name === "--token") args.token = value;
    else if (name === "--email") args.email = value;
    else if (name === "--word") args.word = value;
    else if (name === "--service-account") args.serviceAccountPath = value;
    else if (name === "--google-services") args.googleServicesPath = value;
    else throw new Error(`Parametro desconocido: ${name}`);

    i += 1;
  }

  return args;
}

function printUsage() {
  console.log(`
Uso:
  node scripts/send-wipe-v1.js

Uso con valores personalizados:
  node scripts/send-wipe-v1.js --email demo@demo.com --token FCM_TOKEN

Parametros opcionales:
  --email             Correo del usuario objetivo. Default: ${defaults.email}
  --token             Token FCM del dispositivo objetivo.
  --word              Palabra de activacion. Default: ${defaults.word}
  --service-account   Ruta al JSON de cuenta de servicio.
                      Default: ${defaults.serviceAccountPath}
  --google-services   Ruta a android/app/google-services.json.
`);
}

function readJson(filePath, label) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`No existe ${label}: ${filePath}`);
  }
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function base64Url(input) {
  return Buffer.from(input)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function createJwt(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = {
    alg: "RS256",
    typ: "JWT",
  };
  const claim = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const unsignedJwt = `${base64Url(JSON.stringify(header))}.${base64Url(
    JSON.stringify(claim),
  )}`;

  const signature = crypto
    .createSign("RSA-SHA256")
    .update(unsignedJwt)
    .sign(serviceAccount.private_key);

  return `${unsignedJwt}.${base64Url(signature)}`;
}

function requestJson({ method, hostname, path: requestPath, headers, body }) {
  return new Promise((resolve, reject) => {
    const request = https.request(
      {
        method,
        hostname,
        path: requestPath,
        headers: {
          ...(headers || {}),
          "Content-Length": Buffer.byteLength(body || ""),
        },
      },
      (response) => {
        let responseBody = "";
        response.setEncoding("utf8");
        response.on("data", (chunk) => {
          responseBody += chunk;
        });
        response.on("end", () => {
          let parsed = null;
          try {
            parsed = responseBody ? JSON.parse(responseBody) : null;
          } catch (_) {
            parsed = responseBody;
          }

          if (response.statusCode < 200 || response.statusCode >= 300) {
            reject(
              new Error(
                `HTTP ${response.statusCode}: ${
                  typeof parsed === "string" ? parsed : JSON.stringify(parsed)
                }`,
              ),
            );
            return;
          }

          resolve(parsed);
        });
      },
    );

    request.on("error", reject);
    request.write(body || "");
    request.end();
  });
}

async function getAccessToken(serviceAccount) {
  const assertion = createJwt(serviceAccount);
  const body = querystring.stringify({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion,
  });

  const response = await requestJson({
    method: "POST",
    hostname: "oauth2.googleapis.com",
    path: "/token",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });

  if (!response.access_token) {
    throw new Error(`Google OAuth no devolvio access_token: ${JSON.stringify(response)}`);
  }

  return response.access_token;
}

async function sendWipeMessage({ projectId, accessToken, token, email, word }) {
  const payload = {
    message: {
      token,
      data: {
        action: "wipe",
        word,
        target_email: email,
      },
      android: {
        priority: "HIGH",
      },
    },
  };

  return requestJson({
    method: "POST",
    hostname: "fcm.googleapis.com",
    path: `/v1/projects/${encodeURIComponent(projectId)}/messages:send`,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify(payload),
  });
}

async function main() {
  const args = parseArgs(process.argv);
  const googleServices = readJson(args.googleServicesPath, "google-services.json");
  const serviceAccount = readJson(args.serviceAccountPath, "service-account.json");
  const projectId = googleServices.project_info && googleServices.project_info.project_id;

  if (!projectId) {
    throw new Error("No se pudo leer project_info.project_id desde google-services.json.");
  }

  console.log("Proyecto Firebase:", projectId);
  console.log("Usuario objetivo:", args.email);
  console.log("Palabra de activacion:", args.word);
  console.log("Token FCM:", `${args.token.slice(0, 24)}...`);

  const accessToken = await getAccessToken(serviceAccount);
  const response = await sendWipeMessage({
    projectId,
    accessToken,
    token: args.token,
    email: args.email,
    word: args.word,
  });

  console.log("Mensaje enviado correctamente:");
  console.log(JSON.stringify(response, null, 2));
}

main().catch((error) => {
  console.error("No se pudo enviar el wipe remoto.");
  console.error(error.message);
  console.error("");
  printUsage();
  process.exit(1);
});
