# Nextdoc Setup

How to build a Revenue Cloud scratch org with QuantumBit data, working quoting and a working docgen render, ready for docgen on the quote process.

The steps run from a Revenue Cloud Foundations checkout at commit `c850652` (Release 264, API v68.0). The examples use the org alias `rcf-qb2`.

## What you get

- **Working**
  - QuantumBit products: 314 of 314 matched by SKU
  - Standard Price Book entries: all 1,862 source rows
  - Quote creation and pricing through the Place Sales Transaction API
  - Docgen `.docx` and `.pdf` from `RLM_QuoteProposal` and `RLM_QuoteProposal_CS`
- **Deployed**
  - Revenue Cloud app and record pages
  - Guided selling
  - Sales rep persona user
- **Turned off**
  - Billing, billing UI and collections
  - CRM Analytics, which rating needs
  - Agents
  - Partner Relationship Management (PRM) and PRM pricing
- **Not created**
  - `RLM_ContractsContext`. The flow continues without it.

## Steps

- **1. Prerequisites on the host**
  - Install Docker, the `sf` CLI and a Dev Hub login
  - Clone Revenue Cloud Foundations
  - Build the image locally rather than pulling the published one
    - `docker build -f docker/Dockerfile -t rlm-base:latest .`
    - The image snapshots the repo at build time, and the build runs from this image, not your checkout
  - Do not run `direnv allow`, because `.envrc` exports `SF_TEMP_SHOW_SECRETS=true`
- **2. Create the org definition**
  - Copy `orgs/dev.json` to `orgs/dev-nextdoc.json`
  - Remove the `Chatbot` feature if your Dev Hub rejects it
  - The file is for this setup only, so don't commit it
- **3. Create the scratch org**
  - Run this from the Revenue Cloud Foundations checkout
    - `sf org create scratch --definition-file orgs/dev-nextdoc.json --alias rcf-qb2 --target-dev-hub <dev-hub-alias> --no-namespace --duration-days 30`
  - Confirm there is no namespace
    - `sf data query -o rcf-qb2 -q "SELECT Id, NamespacePrefix FROM Organization"`
    - `NamespacePrefix` must be `null`
    - A namespaced org deploys everything with a prefix, which breaks references in flexipages and context plans
  - `features.N: Invalid input` warnings can appear during creation. The org is still created.
- **4. Start a build container**
  - Use a named volume and no bind mount, so container code can't write to your checkout
    - `docker run -d --name rcf-qb2-build -v rcf-qb2-state:/home/rlm/.rlm-state rlm-base:latest serve`
  - Run every later container command as `docker exec rcf-qb2-build bash -c '...'`
    - **Do not use `sh -c`.** `sh` skips the container's env file, so CCI writes org files it later can't decrypt
    - If that happens, move every `.org` file except `rcf-qb2.org` out of `~/.cumulusci/rlm-base/`
- **5. Log in to the org inside the container**
  - `SF_TEMP_SHOW_SECRETS=true sf org auth show-sfdx-auth-url -o rcf-qb2 --json | docker exec -i rcf-qb2-build rlm login --auth-url --alias rcf-qb2`
  - This also registers the org with CCI and sets it as the default
  - Log in only the target org, and keep the Dev Hub out of the container
- **6. Turn off the features the org doesn't support or the demo doesn't need**
  - Work in `/opt/rlm-base-dev` inside the container
  - In `cumulusci.yml`, set these under `project.custom` to `false`
    - `agents`, `prm`, `prm_pricing`, `analytics`: not needed for this demo
    - `billing`: the flow fails with `createBillingSchedulesFromBillingTransaction` not found and `enableSequenceService` rejected
    - `billing_ui`: its components deploy inside the billing flow, so its pages fail without them
    - `collections`: the flow fails because `CollectionPlan` doesn't exist
  - Leave `qb`, `quantumbit`, `docgen`, `constraints`, `guidedselling`, `personas`, `ux`, `sample_data` on
- **7. Remove metadata that fails without those features**
  - Make these edits in the container only
  - Move `unpackaged/post_quantumbit/settings/Analytics.settings-meta.xml` out of the source tree
    - Otherwise `deploy_quantumbit` fails with `Update of AnalyticsSettings Analytics: Error: sonicEnabled`
  - Move `templates/flexipages/standalone/payments/RLM_Invoice_Record_Page.flexipage-meta.xml` out of the source tree
    - Otherwise the UX deploy fails because the `InvoiceDocuments` related list doesn't exist
  - In `templates/applications/quantumbit/RLM_Revenue_Cloud.app-meta.xml`, remove each `actionOverrides` block whose `content` is one of these
    - `RLM_Usage_Entitlement_Bucket_Record_Page`
    - `RLM_Usage_Aggregation_Policy_Record_Page`
    - `RLM_Usage_Entitlement_Entry_Record_Page`
    - `RLM_Usage_Product_Grant_Binding_Policy_Record_Page`
    - `RLM_Usage_Ratable_Summary_Record_Page`
    - `RLM_Usage_Resource_Record_Page`
  - In `templates/applications/base/RLM_Revenue_Cloud.app-meta.xml`, remove the same overrides, plus these
    - `RLM_Billing_Schedule_Record_Page`
    - `RLM_General_Ledger_Account_Assignment_Rule_Record_Page`
    - `RLM_General_Ledger_Account_Layout`
    - `RLM_Invoice_Line_Record_Page`
    - `RLM_Invoice_Record_Page`
  - In `templates/profiles/base/RLM Sales Representative.profile-meta.xml`, remove the `layoutAssignments` for these
    - `GeneralLedgerAccount-RLM General Ledger Account Layout`
    - `InvoiceLine-RLM Invoice Line Layout`
    - `UsageResource-RLM Usage Resource Layout`
  - Usage and billing records then use Salesforce's default pages
  - Never edit `unpackaged/post_ux/` directly, because it is generated from `templates/`
- **8. Run the build**
  - `docker exec rcf-qb2-build bash -c 'cd /opt/rlm-base-dev && mkdir -p target/tmp && cci flow run prepare_rlm_org --org rcf-qb2 > target/tmp/prepare_rlm_org.log 2>&1; echo flow_exit=$?'`
    - Check `flow_exit`, because the `docker exec` itself exits 0 even when the flow fails
  - Filter the log when reading it, because logs can contain tokens
  - **If a step fails**
    - CCI has no resume option, so add a temporary flow to the container's `cumulusci.yml` holding only the remaining steps
    - Don't rerun completed steps, because `insert_qb_approvals_data` uses Insert and can duplicate records
  - **Errors that don't stop the flow**
    - `RLM_ContractsContext` fails with `UNKNOWN_EXCEPTION`
    - 34 `PricebookEntry` rows fail to delete with `SqlNoDataFoundException`. They come with the org and have no product or pricebook
  - `assemble_and_deploy_ux` and `extend_context_contracts` take no `--org` when run alone, and use CCI's default org
- **9. Check the data**
  - `SELECT COUNT() FROM Product2` returns 314
  - `SELECT Pricebook2.Name, COUNT(Id) c FROM PricebookEntry GROUP BY Pricebook2.Name` returns 1,862 for Standard Price Book and 34 for null
  - `SELECT Name, Status FROM DocumentTemplate` shows `RLM_QuoteProposal` and `RLM_QuoteProposal_CS` as Active
- **10. Wait for decision tables to finish syncing**
  - The flow's last steps start the refresh, and tables keep syncing for about a minute after the flow ends
  - A quote placed before the sync finishes shows the right `ListPrice`, with `UnitPrice` and `TotalPrice` at 0
  - Check before creating a quote
    - `SELECT DeveloperName, LastSyncDate FROM DecisionTable ORDER BY LastSyncDate DESC LIMIT 5`
- **11. Create a test quote**
  - Use the transaction API, because direct `QuoteLineItem` inserts are not viable for term-defined products
  - Use one-time products, which avoid billing treatments
  - Query a `PricebookEntry` for `Product2Id` and `Id`, using `CurrencyIsoCode='USD'` and `ProductSellingModel.SellingModelType='OneTime'`
  - Save this as `place.json`, filling in your IDs

    ```json
    {
      "pricingPref": "system",
      "configurationPref": {
        "configurationMethod": "skip",
        "configurationOptions": {
          "validateProductCatalog": false,
          "validateAmendRenewCancel": false,
          "executeConfigurationRules": false,
          "addDefaultConfiguration": false
        }
      },
      "graph": {
        "graphId": "qbDocgenTest",
        "records": [
          { "referenceId": "refQuote", "record": {
              "attributes": { "type": "Quote", "method": "POST" },
              "Name": "QB Docgen Test",
              "QuoteAccountId": "<ACCOUNT_ID>",
              "CurrencyIsoCode": "USD",
              "Status": "Draft",
              "Pricebook2Id": "<PRICEBOOK_ID>" } },
          { "referenceId": "refL1", "record": {
              "attributes": { "type": "QuoteLineItem", "method": "POST" },
              "QuoteId": "@{refQuote.id}",
              "Product2Id": "<PRODUCT2_ID>",
              "PricebookEntryId": "<PBE_ID>",
              "Quantity": 2,
              "StartDate": "<YYYY-MM-DD>" } }
        ]
      }
    }
    ```

  - Place the quote
    - `sf api request rest -o rcf-qb2 --method POST --body @place.json /services/data/v68.0/connect/rev/sales-transaction/actions/place`
  - Check the response, because HTTP 200 alone doesn't mean success
    - `isSuccess` must be `true` and `errorResponse` must be empty
  - Read the lines back and confirm `UnitPrice` and `TotalPrice` are not 0
- **12. Render a document**
  - Get the template ID
    - `SELECT Id FROM DocumentTemplate WHERE Name='RLM_QuoteProposal' AND IsActive=true`
  - Render inside the container
    - `docker exec rcf-qb2-build bash -c "cd /opt/rlm-base-dev; python scripts/docgen/docgen_template_generate.py --record-id <QUOTE_ID> --template-id <TEMPLATE_ID> --org rcf-qb2 --title 'QB Test'"`
    - Success prints `Status: Success` and two `ContentVersion` IDs, one `.docx` and one `.pdf`
  - Download a file from the host
    - `sf api request rest -o rcf-qb2 --stream-to-file out.docx /services/data/v68.0/sobjects/ContentVersion/<068_ID>/VersionData`
  - **Which template to use**
    - **`RLM_QuoteProposal` (recommended):** formatted currency and correct discounted unit prices. The rep name comes from the quote's creator.
    - **`RLM_QuoteProposal_CS`:** prints the rep name from `RLM_Sales_Rep_Name__c`, but shows `38500` rather than `$38,500.00` and prints list price as the unit price on discounted lines
- **13. Open the org**
  - `sf org open -o rcf-qb2`
- **14. Clean up**
  - Delete test quotes you don't want in the demo
  - The org expires after 30 days, and the build has to be repeated on a new org
  - The edits in steps 6 and 7 exist only in the container, so copy them across or remake them if the container is removed
