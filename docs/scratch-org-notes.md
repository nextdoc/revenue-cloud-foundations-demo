# Scratch Org Notes

How the Nextdoc Quote templates get their data from the `rcf-qb2` scratch org, and how the Quote record page streams them. Each template's data source steps run against Quote 00000003 with the Streamline Sampler scripts in `apex/streamline/`.

## Story data states

The 3 story states ("Proposal versions" in `docs/nextdoc-story.md`) are applied outside a Streamline run.

- **Platform rules:** DML on `QuoteLineItem.Quantity` or `Discount` doesn't reprice. `NetUnitPrice`, `NetTotalPrice` and `Quote.GrandTotal` keep their old values, and the net price fields can't be updated. The `RevSalesTrxn` Place types aren't visible to anonymous Apex (Streamline included), but they compile in a deployed class. Callouts can't follow DML in one transaction.
- **State class:** the deployed class `QuoteStoryState` calls `RevSalesTrxn.PlaceSalesTransactionExecutor` (`pricingPref` Force) to set the Power System line for a state, and skips the call when the quote is already in it. Place runs inside the caller's transaction, so in Streamline it is a dry run that rolls back. `apex/streamline/quote-story-state.apex` picks the state, and `sf apex run -o rcf-qb2 -f apex/streamline/quote-story-state.apex` applies it.
- **Capture order:** apply a state with `sf apex run`, run a template's sampler script with `CAPTURE` true and that state's sample name, then set the sample's description in the Nextdoc editor. Leave the quote at `V1_ORIGINAL` at the end.
- **Naming:** states are `V1_ORIGINAL`, `V2_PUSHBACK` and `V3_COUNTEROFFER`. Samples are "Quote <Template> v1 Original", "… v2 Pushback" and "… v3 Counteroffer", for example "Quote Design v2 Pushback".
- `runSteps` runs locally with no callout, so it sees DML made earlier in the same transaction.

## Quote Original

- The script `apex/streamline/quote-original-sampler.apex` runs the data source "Quote Original Static" steps and diffs them against the sample "Quote Original v1 Original". Its `CAPTURE` flag saves the result as `CAPTURE_SAMPLE_NAME`.
- The story state samples are "Quote Original v1 Original", "Quote Original v2 Pushback" and "Quote Original v3 Counteroffer". Each has a description.
- All three render on renderer 3.62 at 3 pages. Page 1 shows the story totals: $418,505, $365,825 (Power System 12, $52,680) and $407,969 (Power System 24 at 10% off, unit $3,951, $94,824). The 10% shows only on that row. No line states the saving.
- The data source has 3 steps: `quote` (with `Account.Name` and `CreatedBy` fields as parent lookups), `sellerOrganization` and `quoteLines`. `Organization` has no relationship to `Quote`, so it is a separate step.
- Three fields are null in the org, so the template renders them blank:
  - `Quote.ExpirationDate`: "QUOTE EXPIRES:" shows no date.
  - `QuoteLineItem.Discount`: the "Discount (%)" column is empty on all 8 lines in v1.
  - `User.Title` on the quote creator: the role line under "Quote created by" hides when its data is missing.
- The time zone is mapped to `env.timeZone`, the Salesforce user's zone (`America/Los_Angeles` on this org). The created date renders in local time.
- The seller organization name comes from the org, "Salesforce Agentforce Revenue Management", not "QuantumBit". The template doesn't render it.
- The quote creator is the scratch org admin, "User User", not a sales rep persona.

## Streaming to the Quote page

The Quote record page in rcf-qb2 shows the "Quote Variations" packet through the Nextdoc v3 Desktop component.

### Nextdoc

1. **Packet:** "Quote Variations" holds "Quote Original".
2. **Salesforce connection:** created in Setup, Connected Apps.
   - Server Domain is the org's My Domain host with no scheme, for example `<my-domain>.scratch.my.salesforce.com`.
   - Connected App Key and Secret are the consumer key and secret that Nextdoc provides. Then click Connect.
3. **Stream:** "Quote Variations" runs on renderer 3.62 with that connection, at API version 66.
4. **Deployment:** the stream's actions and deployment are set in the Nextdoc UI. The deployed version is `26-11-10_0005`.

### Salesforce (rcf-qb2)

1. The page is `force-app/main/default/flexipages/Nextdoc_Quote_Record_Page.flexipage-meta.xml` (master label "Nextdoc Quote Record Page"), based on `FlexiPage:RLM_Quote_Record_Page`.
2. Its header region holds `nxd:stream3Desktop2` with `deployedVersion` `26-11-10_0005` and `document` "Quote Original". The package is installed, so the component needs the `nxd:` prefix.
3. Deploy it: `sf project deploy start -o rcf-qb2 -d force-app/main/default/flexipages/Nextdoc_Quote_Record_Page.flexipage-meta.xml`.
4. Activate it. The Quote `View` (Large) override is set in two places, and both must point at the page:
   - App default: `<actionOverrides>` for `Quote` in `CustomApplication:RLM_Revenue_Cloud`.
   - Org default: the `View` Large `<actionOverrides>` in `CustomObject:Quote`.

   Retrieve each with `--target-metadata-dir target/tmp/...`, change `<content>` to `Nextdoc_Quote_Record_Page`, and deploy with `--metadata-dir` and a one-type `package.xml`. Retrieve profiles together with the app to see any profile overrides. rcf-qb2 has none.
5. To switch back, redeploy the app and object with `<content>RLM_Quote_Record_Page</content>`.

### Live refresh flow

An open Quote page restreams when a flow calls the Nextdoc render action. `force-app/main/default/flows/Nextdoc_Refresh_Quote.flow-meta.xml` is an active, record-triggered after-save flow on Quote update that calls `nxd__Stream3FlowRender` with `$Record.Id`. It is based on the package's Opportunity template `nxd__Nextdoc_Refresh_Opportunity`.

Deploy it: `sf project deploy start -o rcf-qb2 -d force-app/main/default/flows`. It is active as soon as it deploys.

The flow fires only when the Quote record itself is updated. A quote line change restreams the page when repricing writes the new totals back to the Quote, as applying a story state does.

## Quote Design

- The script `apex/streamline/quote-design-sampler.apex` runs the data source "Quote Design Static" steps and diffs them against "Quote Design v1 Original". `CAPTURE` works the same as in the Original script.
- The source has Original's 3 steps: `quote` (with `Account.Name` and `CreatedBy` fields as parent lookups), `sellerOrganization` and `quoteLines` (which adds `Product2.ProductCode`). 15 mappings read from these paths.
- The story state samples are "Quote Design v1 Original", "Quote Design v2 Pushback" and "Quote Design v3 Counteroffer". Each has a description.
- All three render on renderer 3.62 at 3 pages:
  - The seller title and expiry date nodes hide when data is missing (`hide-incomplete`), like Original. The "Quote expires" label stays with no date.
  - The thank-you line on page 3 blanks the missing title (`hide-incomplete-merges`), so it reads "User User,".
  - The "Total row" columns are [6, 6], so v3's $407,969.00 fits in the total card.

## Quote Ultimate

- The script `apex/streamline/quote-ultimate-sampler.apex` runs the data source "Quote Ultimate Static" steps and compares them with a reference sample. `CAPTURE` works the same as in the Original script.
- The source uses Original's 3 SOQL steps (`quote`, `sellerOrganization`, `quoteLines`) plus 4 Apex steps: `partyRoles`, `definitions`, `floorPlan` and `discountFlag`. All 4 run one deployed class, `QuoteUltimateStep`, and its `section` config picks the output.
- `floorPlan` and `discountFlag` read the `quoteLines` result from `context.results` and run no SOQL. `floorPlan` turns the line quantities into rack counts and callouts. `discountFlag` sets `HasDiscount`, which shows the Discount column only in v3.
- The definitions, role labels, callout wording and product names are hard-coded in the class.
- 32 mappings read from these paths.
- The story state samples are "Quote Ultimate v1 Original", "Quote Ultimate v2 Pushback" and "Quote Ultimate v3 Counteroffer". Each has a description.
- All three render on renderer 3.62 at 4 pages, using floor plan plug-in version 0.1.9:
  - The floor plan on page 2 follows the state. v2 shows 12 Power Systems, and v3 adds a "10% off" callout with the discounted units in green.
  - The seller organization renders on the page 4 signature card as "Salesforce Agentforce Revenue Management", the org's name.
  - The seller title and expiry date hide when data is missing, and the thank-you line reads "User User,", as in Design.
