import { Client } from '@microsoft/microsoft-graph-client';
import 'isomorphic-fetch';

export default async function (context, req) {
  try {
    const userId = req.headers['x-ms-client-principal-id'];

    const tenantId = '9ff87f7c-8358-46b5-88bc-d73c09ce789f';
    const clientId = '8dcec823-8928-41f7-a9b5-e85db1dc6c12';
    const clientSecret = 'fcy8Q~E2wPa6u5EyxLOrbS4Pp8dePnFbMFkQXc7Y';

    const tokenResponse = await fetch(
      \https://login.microsoftonline.com/\/oauth2/v2.0/token\,
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

    const user = await client.api(\/users/\\)
      .select('displayName,givenName,surname,mail,userPrincipalName').get();

    const methodsResponse = await client.api(\/users/\/authentication/methods\).get();

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
