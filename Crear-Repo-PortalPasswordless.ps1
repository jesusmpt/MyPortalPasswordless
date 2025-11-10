# Define la carpeta raíz del proyecto
$root = "C:\PortalPasswordless"

# Crea estructura de carpetas
$folders = @(
    "$root\frontend\src",
    "$root\api\methods",
    "$root\.github\workflows"
)

foreach ($f in $folders) {
    if (-not (Test-Path $f)) {
        New-Item -ItemType Directory -Path $f | Out-Null
    }
}

# ---------- FRONTEND ----------

# package.json
$frontendPackage = @"
{
  "name": "portal-passwordless",
  "version": "1.0.0",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "@azure/msal-browser": "^4.22.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.0.0",
    "vite": "^5.4.21"
  }
}
"@
Set-Content -Path "$root\frontend\package.json" -Value $frontendPackage

# vite.config.js
$viteConfig = @"
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  base: './'
});
"@
Set-Content -Path "$root\frontend\vite.config.js" -Value $viteConfig

# index.html
$indexHtml = @"
<!DOCTYPE html>
<html lang='es'>
  <head>
    <meta charset='UTF-8' />
    <meta name='viewport' content='width=device-width, initial-scale=1.0' />
    <title>Portal Passwordless</title>
    <link rel='icon' type='image/png' href='./favicon.ico' />
  </head>
  <body>
    <div id='root'></div>
    <script type='module' src='./src/main.jsx'></script>
  </body>
</html>
"@
Set-Content -Path "$root\frontend\index.html" -Value $indexHtml

# src/main.jsx
$mainJsx = @"
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
"@
Set-Content -Path "$root\frontend\src\main.jsx" -Value $mainJsx

# src/App.jsx
$appJsx = @"
import React, { useEffect, useState } from 'react';

function App() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  const fetchData = () => {
    setLoading(true);
    fetch('/api/methods')
      .then(res => res.json())
      .then(json => setData(json))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    fetchData();
  }, []);

  if (loading) return <p>Cargando...</p>;
  if (!data) return <p>Error al obtener información</p>;

  const { user, availableMethods, missingPasswordless } = data;

  return (
    <div style={{ padding: '20px', fontFamily: 'Arial' }}>
      <h1>Portal Passwordless</h1>
      <h2>Información del usuario:</h2>
      <ul>
        <li>Nombre: {user.givenName} {user.surname}</li>
        <li>Correo: {user.mail || user.userPrincipalName}</li>
      </ul>

      <h2>Métodos de autenticación configurados:</h2>
      <ul>
        {availableMethods.map((m,i)=>(
          <li key={i}>{m.displayName || m.type} {m.phoneNumber ? '- '+m.phoneNumber : ''}</li>
        ))}
      </ul>

      {missingPasswordless.length>0 ? (
        <>
          <h2>Para habilitar passwordless necesitas:</h2>
          <ul>
            {missingPasswordless.map((m,i)=><li key={i}>{m}</li>)}
          </ul>
        </>
      ) : (<p>¡Ya tienes passwordless configurado!</p>)}

      <button onClick={fetchData} style={{ marginTop: '20px' }}>Volver a comprobar</button>
      <button onClick={() => window.location.href='/logout'} style={{ marginLeft: '10px' }}>Logout</button>
    </div>
  );
}

export default App;
"@
Set-Content -Path "$root\frontend\src\App.jsx" -Value $appJsx

# ---------- BACKEND API ----------

$apiJs = @"
import { Client } from '@microsoft/microsoft-graph-client';
import 'isomorphic-fetch';

export default async function (context, req) {
  try {
    const userId = req.headers['x-ms-client-principal-id'];

    const tenantId = '9ff87f7c-8358-46b5-88bc-d73c09ce789f';
    const clientId = '8dcec823-8928-41f7-a9b5-e85db1dc6c12';
    const clientSecret = 'fcy8Q~E2wPa6u5EyxLOrbS4Pp8dePnFbMFkQXc7Y';

    const tokenResponse = await fetch(
      \`https://login.microsoftonline.com/\${tenantId}/oauth2/v2.0/token\`,
      {
        method:'POST',
        headers:{'Content-Type':'application/x-www-form-urlencoded'},
        body: new URLSearchParams({
          client_id: clientId,
          scope: 'https://graph.microsoft.com/.default',
          client_secret: clientSecret,
          grant_type: 'client_credentials'
        })
      }
    );

    const tokenData = await tokenResponse.json();
    const accessToken = tokenData.access_token;

    const client = Client.init({ authProvider: done => done(null, accessToken) });

    const user = await client.api(\`/users/\${userId}\`)
      .select('displayName,givenName,surname,mail,userPrincipalName').get();

    const methodsResponse = await client.api(\`/users/\${userId}/authentication/methods\`).get();

    const availableMethods = methodsResponse.value.map(m => ({
      type: m['@odata.type'].split('.').pop(),
      displayName: m.displayName || '',
      phoneNumber: m.phoneNumber || ''
    }));

    const passwordlessMethods = ['fido2AuthenticationMethod','microsoftAuthenticatorAuthenticationMethod'];
    const missing = passwordlessMethods.filter(m => !availableMethods.some(am => am.type.toLowerCase()===m.toLowerCase()));

    context.res = { status:200, body:{ user, availableMethods, missingPasswordless: missing } };

  } catch(error) {
    console.error(error);
    context.res = { status:500, body:{error: error.message} };
  }
}
"@
Set-Content -Path "$root\api\methods\index.js" -Value $apiJs


Set-Content -Path "$root\.github\workflows\azure-static-web-apps.yml" -Value $workflow

Write-Host "Estructura de portal Passwordless creada en $root"
