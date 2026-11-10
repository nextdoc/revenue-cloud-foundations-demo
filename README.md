# Nextdoc Revenue Cloud Demo

Installs Nextdoc into a Revenue Cloud scratch org and deploys the demo's quote
documents, record page and supporting Apex.

The scratch org must already exist and be built with Revenue Cloud Foundations.
To build one, follow `docs/nextdoc-setup.md`. The docs use the alias `rcf-qb2`
as an example. Use any alias you like.

Both scripts read the org alias from the `ORG_ALIAS` environment variable and
stop if it is not set:

```bash
export ORG_ALIAS=<your-org-alias>
```

Nextdoc provides three values: the package installation key, the OAuth client
ID and the OAuth client secret.

1. **Install Nextdoc into the org.** Run `./script/setup-org.sh <installation-key>`,
   or set `NEXTDOC_INSTALLATION_KEY` and run it with no argument. This installs
   the Nextdoc package, deploys this project's metadata, assigns the permission
   sets, and opens the org.

2. **Request org activation from Nextdoc.** Ask Nextdoc to activate this org,
   providing the **Org ID** printed at the end of step 1. Nextdoc returns the
   **OAuth client ID** and **client secret** for the external connection.

3. **Configure the Nextdoc connection.** Run `./script/setup-connection.sh <client-id>`,
   or set `NEXTDOC_CLIENT_ID` and run it with no argument. Set
   `NEXTDOC_CLIENT_SECRET` beforehand, or enter the secret when prompted (input
   is masked).

4. **Post-install configuration.**
   - Configure the platform cache.
   - Configure the stream viewer in an App Builder FlexiPage. See
     `docs/scratch-org-notes.md`.
   - Enable callouts on the Sampler named credential. Salesforce installs managed
     package named credentials with callouts disabled. In Setup, open
     **Named Credentials / Sampler** (`nxd__Sampler`), click **Edit**, tick
     **Enabled for Callouts** and save.

## Related repositories

- **[Revenue Cloud Foundations](https://github.com/SalesforceLabs/revenue-cloud-foundations)**
  builds and configures the Revenue Cloud org this project deploys into. Run it
  before step 1 above.
