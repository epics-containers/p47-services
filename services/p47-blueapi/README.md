To request an Ingress for `p47-blueapi.diamond.ac.uk` in the `p47-beamline` namespace:

1. Go to the Scientific Computing Help Desk at [schelpdesk.diamond.ac.uk](https://schelpdesk.diamond.ac.uk) and navigate to [Cloud → New Beamline Ingress](https://jira.diamond.ac.uk/servicedesk/customer/portal/2/create/156) for beamline clusters, or [Cloud → New Ingress](https://jira.diamond.ac.uk/servicedesk/customer/portal/2/create/91) for Argus / Pollux.
2. Provide the following details:

    - **Beamline Cluster Name** or **Cluster Name**: 
      `pollux`
    - **Namespace Name:**  
      `p47-beamline`
    - **Ingress Name:**  
      `p47-blueapi.diamond.ac.uk`

3. Configure numtracker using the numtracker CLI client:
  Load the numtracker module on any DLS Red Hat workstation:

  ```
  module load numtracker/staging
  ```
 
  For configuration details, see the [numtracker documentation](https://github.com/diamondLightSource/numtracker#configure-1).

  Example configuration, please adapt this to beamlines requirements. The values in curly braces are intentional placeholders that will be populated by numtracker. They do not need to be manually replaced.
  ```
  numtracker client configure p47 \
  --directory '/dls/{instrument}/data/{year}/{visit}' \
  --scan '{subdirectory}/{instrument}-{scan_number}' \
  --detector '{subdirectory}/{scan_number}/{instrument}-{scan_number}-{detector}'
  ```

  **Note:** `numtracker-staging` will be replaced with `numtracker`. See [this issue](https://github.com/epics-containers/services-template-helm/issues/97) for more details.

4. If blueapi auth is enabled, add the client secret and cookie secret to `templates/secret.yaml`:

  - To obtain the client secret, Create a ticket in [Keycloak Client registration](https://jira.diamond.ac.uk/servicedesk/customer/portal/5/create/176) with  
    - Hostname: `https://p47-blueapi.diamond.ac.uk`
    - Keycloak Environment: Dev/Test and Production
    - ClientId: `p47Blueapi`
    - GPG Public Key: Please follow docs [here](https://dev-guide.diamond.ac.uk/authn/how-tos/request-a-registration-with-keycloak/)

    You may receive separate credentials for the identity, identity-dev, and identity-test Diamond Keycloak services. By default use the identity credentials.

  - To generate a cookie secret, refer to the [OAuth2 Proxy documentation](https://oauth2-proxy.github.io/oauth2-proxy/configuration/overview#generating-a-cookie-secret).


  To seal both secrets, ensure you are connected to the correct cluster via:
  ```
  module load pollux
  ```
  Then, having obtaining both secrets, seal them with the following commands:
  ```
  echo -n <secret> | kubeseal --raw --namespace p47-beamline --name blueapi-secret
  ```

  And place each in the appropriate field in `templates/secret.yaml`

5. If tiled insertion is enabled, request a service account through [Keycloak Client registration](https://jira.diamond.ac.uk/servicedesk/customer/portal/5/create/176) with the following hardcoded claims:
  - Applicaiton Hostname: tiled.diamond.ac.uk
  - Keycloak Environment: Dev/Test and Production
  - Client ID: p47TiledWriter
  - Claim Name: `beamline`
  - Claim Value: `p47`
  - Claim JSON Type: `String`
  - Audience: `tiled-writer`

  You may receive separate credentials for the identity, identity-dev, and identity-test Diamond Keycloak services. By default use the identity credentials.
  
  The client secret for the p47TiledWriter should be added to `templates/secret.yaml` -> `tiled-writer-secret`.
