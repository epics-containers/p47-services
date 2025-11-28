To request an Ingress for `p47-blueapi.diamond.ac.uk` in the `p47-beamline` namespace:

1. Go to the Scientific Computing Help Desk at [schelpdesk.diamond.ac.uk](https://schelpdesk.diamond.ac.uk) and navigate to **Cloud → New Ingress**.
2. Provide the following details:

    - **Cluster Name:**  
      Use `pollux` in the description if the cluster is not Argus or Pollux.
    - **Namespace Name:**  
      `p47-beamline`
    - **Ingress Name:**  
      `p47-blueapi.diamond.ac.uk`

Please add the instrument session in the worker.env.metadata.instrument_session


3. Add the client secret and cookie secret to `templates/secret.yaml`:
  - To obtain the client secret, message on slack #athena-components and request a Keycloak client named `p47-blueapi` on `authn.diamond.ac.uk` for blueapi, specifying the ingress `p47-blueapi.diamond.ac.uk`. The support team will send you the required secret.
  - To generate a cookie secret, refer to the [OAuth2 Proxy documentation](https://oauth2-proxy.github.io/oauth2-proxy/configuration/overview#generating-a-cookie-secret).

  After obtaining both secrets, seal them with the following commands:
  ```
  echo -n <secret> | kubeseal --raw --namespace p47-beamline --name blueapi-secret
  ```

  And place each in the appropriate field in `templates/secret.yaml`


