# Nextdoc Story

The people and companies come from the QuantumBit demo data. The deal and motivations are written for this demo. The quote is Quote 00000003 on `rcf-qb2`, and `QuoteStoryState` puts it into any of the three versions.

## 1. The story

Infinitech is a San Francisco technology company whose systems have outgrown the server rooms they started in. Production, pre-production and government workloads now run in scattered locations, each with its own equipment and its own limits. Seth Wilson, who leads the project at Infinitech, has been asked to bring them together in one purpose-built data center.

Seth's plan is to start with what Infinitech needs and leave room to grow. Infinitech wants enough compute for one third of the data center floor to be active, with the racks, power and cooling that compute needs. It also wants racks for a second third, ready to fill as it grows, and wants the last third left as uncovered floor. Servers can be added as demand arrives, and buying them early ties up budget in equipment that sits idle. Power is different. It is the hardest thing to add once a data center is live, because the work happens around systems that can't go down.

Kristen O'Reilly, an account executive at QuantumBit, sees a customer who needs a long-term infrastructure partner more than a one-time hardware order. The proposal lays out 24 rack positions in three equal sections. The first 8 racks are installed, full of compute and cooled. The next 8 are installed and empty, ready for servers. The last 8 positions are uncovered floor. Power sits in its own room beside the data center floor, and Kristen's proposal fills that room with Power Systems for all 24 positions from day one.

Both sides get what they came for. Infinitech pays a known cost now to remove its biggest growth risk, and can add compute and racks without touching the power room. QuantumBit wins a larger first order and becomes the natural supplier for everything that follows. The proposal makes that plan visible: one third of the floor running, one third ready and one third open, all backed by a power room that is full.

### The negotiation

The demo opens with the original proposal on screen. Kristen and Seth have already had one conversation, in which Seth saw the proposal and said he would take it back to his team. Now they meet to review it again.

Seth says he has had feedback from Infinitech's finance team, and they pushed back. They accept the need for the compute and the racks, but they question paying today for power that nothing will use until the last positions are filled. He asks: can Infinitech buy half the power now, enough for the compute it needs plus a little for growth?

**First change.** Kristen asks her agent to reduce the Power Systems on the quote from 24 to 12. That covers the 8 full racks and leaves 4 spare for growth. The revised proposal is $52,680 cheaper, and both of them can see what that saving costs. The power room is half empty, spare power falls from 16 racks to 4, and 4 of the empty racks and all of the open floor have no power behind them. Growing past 12 racks would now mean new power work around live systems, which is the risk Seth set out to remove.

**Second change.** Kristen says she has an idea: restore all the Power Systems so the power room is full again, with 10% off every one. She makes the change and the final proposal comes to $407,969, between the first two versions. Seth can show finance a $10,536 saving against the original and keeps the power that protects Infinitech's growth. Kristen gives up some margin to protect the larger order and the expansion that follows. Both of them are happy with the result.

## 2. The data

All quote figures match Salesforce pricing on `rcf-qb2`. The items under "What is assumed" are part of the story, not Salesforce data.

All prices are one-time USD list prices from the Standard Price Book.

| Line | SKU | Qty | Unit | Total | Role in the story |
|---|---|---:|---:|---:|---|
| Compute Cluster | `PROD-148835828` | 8 | $21,000 | $168,000 | The third of the compute Infinitech needs today |
| Rack Enclosure (42U) | `PROD-789058761` | 16 | $3,470 | $55,520 | 8 full racks and 8 empty racks |
| Storage Subsystem | `PROD-2116311267` | 2 | $12,000 | $24,000 | Shared storage for the consolidated workloads |
| Network Fabric | `PROD-1008704562` | 2 | $26,700 | $53,400 | Shared network, duplicated for resilience |
| Power System | `PROD-544673184` | 24 | $4,390 | $105,360 | Power for all 24 positions, 16 of them spare |
| Cooling System | `PROD-2003786421` | 8 | $845 | $6,760 | Cooling for the full racks only |
| Management & Monitoring | `PROD-1941355444` | 1 | $1,480 | $1,480 | The monitoring center |
| Security & Safety | `PROD-1744092313` | 1 | $3,985 | $3,985 | Site access and fire sensors |
| **Total** | | | | **$418,505** | |

### Proposal versions

The table above is version 1. Versions 2 and 3 change only the Power System line.

| Version | Power Systems | Spare power | Power System total | Quote total |
|---|---:|---:|---:|---:|
| 1. Original proposal | 24 at list | 16 racks | $105,360 | $418,505 |
| 2. Seth's pushback | 12 at list | 4 racks | $52,680 | $365,825 |
| 3. Kristen's counteroffer | 24 at 10% off | 16 racks | $94,824 | $407,969 |

### How the numbers support the story

- **Infrastructure ahead of demand:** the 16 spare Power Systems cost $70,240 and the 8 empty racks cost $27,760. Together that $98,000 is what Infinitech pays now to remove its growth risk, and it is about 23% of the deal.
- **Future revenue:** filling the data center takes 16 more Compute Clusters, 16 more Cooling Systems and 8 more Rack Enclosures, which cost $377,280 at today's list prices. This is QuantumBit's follow-on opportunity and needs no new power purchase.
- **Floor plan:** the quote quantities and the 24 positions set the three sections, so the visual can calculate them.
  - Full racks = Compute Clusters = 8
  - Empty racks = Rack Enclosures − Compute Clusters = 8
  - Open floor = 24 − Rack Enclosures = 8
  - Spare power = Power Systems − Compute Clusters = 16, 4 or 16 by version
- **Not line items:** the building, the open floor, the power room and the monitoring center room appear in the visual but not on the quote. Storage and network sit inside the 8 full racks.

### What is assumed

- One Compute Cluster fills one rack, and one Power System supports one full rack. These are the deal's main assumptions, and the catalog states neither.
- The 24 positions are set by the story. Nothing in Salesforce defines the size of the data center.
- Cooling is bought rack by rack as compute arrives, because the catalog's Cooling System is rack-level equipment.
- Rack-space, power and floor-space figures come from `QuoteUltimateStep`, not from Salesforce.
- The catalog's power products are rack-level PDUs and UPS units, so the separate power room is part of the story rather than a product definition.

## 3. How the demo behaves

### Quote and parties

- Quote 00000003, "Infinitech Data Center", has 8 lines and is linked to Opportunity "Infinitech Data Center Consolidation" at stage Proposal/Price Quote.
- `QuoteAccountId` is Infinitech, `ContactId` is Seth Wilson and `OwnerId` is Kristen O'Reilly.
- Opportunity `Amount` stays empty, because quote sync is off.
- Each version is a Place Sales Transaction call with `pricingPref` Force that patches the Power System line. The quote keeps the same 8 lines in every version.
- In version 3 the Power System line has `UnitPrice` $4,390 and `NetUnitPrice` $3,951, and the quote's `Discount` reads 2.5175%.
- Line order is not guaranteed by the data, so each document sets its own order.

### Approval

Approval levels are set per line, and the quote takes the highest level on any line.

| Line discount | Level | Approvers |
|---|---:|---|
| Under 15% | 0 | None |
| 15% to under 25% | 1 | Manager |
| 25% to under 35% | 2 | Manager, then Director |
| 35% and above | 3 | Manager, Director, then VP |

- Any payment term other than "Net 30" also starts an approval. The demo quote is on "Net 30".
- The 10% discount in version 3 needs no approval. A submission at 10% approves itself.
- At 15% or more, the line shows a red "Manager" flag.
- A seller submits with the Submit for Approval action on the Quote page. Discount edits never submit on their own.
- An approved quote can still be edited, and an edit does not clear `RLM_Approval_Status__c`. Submit only on the final version.

### Standard quote documents

The org's docgen templates print the right quantities, line totals and quote total in every version.

- **`RLM_QuoteProposal`:** formatted currency and a correct discounted unit price. The rep name comes from the quote's creator.
- **`RLM_QuoteProposal_CS`:** prints the rep name from `RLM_Sales_Rep_Name__c`. Currency is unformatted, and the discounted row shows list price as the unit price.
- Neither template prints the saving, the contact or the expiry date. The Nextdoc templates are described in `docs/scratch-org-notes.md`.
