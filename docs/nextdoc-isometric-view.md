# Nextdoc Isometric View

The view shows the Infinitech quote's line items as a roof-off data center. Quote figures come from `nextdoc-story.md` section 2. Figures marked "calculated" are worked out from them here and are not stored in Salesforce.

The base drawing is version 2, because it has every component state: 8 full racks, 8 empty racks, 8 uncovered positions, and 12 Power Systems in 24 slots. Labels (E24 to E27) sit on top of the base drawing.

Highlights are conditional overlays on the base drawing: a color highlight, a connecting line and an explanation at the side, such as the share of power that is overprovisioned.

## Style guide

The style is an isometric data center floor plan with power and operations rooms. Counts and placement come from this file.

| Our element | Style |
|---|---|
| E2 Rack Enclosure, E1 Compute Cluster | Black rack with lit servers and colored cabling |
| E4 Network Fabric | Blue overhead run, drawn twice |
| E5 Power System | Grey cabinet with a screen, drawn as identical countable units |
| E6 Cooling System | White unit on top of a rack, on full racks only |
| E8 Security & Safety | Keypad on the wall |
| E16 Building | Roof-off shell with white walls and glass panels |
| E17 Data center floor | Light grey tiles |
| E20 Power room | Walled room beside the data center floor |
| E21 Monitoring center | Room with desks, screens and a wall dashboard |
| E23 Power connection | Orange, red and black overhead cables |

E3 Storage Subsystem, E8's fire sensors, E10 empty rack, E11 and E18 uncovered position markings, E28 empty power slot, and the labels E24 to E27 have their own designs.

## 1. Visual inventory

### Quote line items

These elements are the 8 lines on the quote.

| Code | Element | Where it sits | Version 1 | Version 2 | Version 3 |
|---|---|---|---:|---:|---:|
| E1 | Compute Cluster | Inside the full racks | 8 | 8 | 8 |
| E2 | Rack Enclosure (42U) | Full and empty sections | 16 | 16 | 16 |
| E3 | Storage Subsystem | Inside the full racks | 2 | 2 | 2 |
| E4 | Network Fabric | Inside the full racks | 2 | 2 | 2 |
| E5 | Power System | Power room | 24 | 12 | 24 at 10% off |
| E6 | Cooling System | On the full racks only | 8 | 8 | 8 |
| E7 | Management & Monitoring | Monitoring center | 1 | 1 | 1 |
| E8 | Security & Safety | Site access and fire sensors | 1 | 1 | 1 |

### Calculated states

These elements have no quote line of their own. Their counts come from the line quantities and the 24 positions. Power is assumed to cover the full racks first, then the empty racks, then the open floor.

| Code | Element | Calculation | Version 1 | Version 2 | Version 3 |
|---|---|---|---:|---:|---:|
| E9 | Full racks | Compute Clusters | 8 | 8 | 8 |
| E10 | Empty racks | Rack Enclosures − Compute Clusters | 8 | 8 | 8 |
| E11 | Open rack positions | 24 − Rack Enclosures | 8 | 8 | 8 |
| E12 | Power Systems in use | Full racks | 8 | 8 | 8 |
| E13 | Spare Power Systems | Power Systems − full racks | 16 | 4 | 16 |
| E14 | Powered positions | Power Systems | 24 | 12 | 24 |
| E15 | Positions with no power | 24 − Power Systems | 0 | 12 | 0 |
| E28 | Empty slots in the power room | 24 − Power Systems | 0 | 12 | 0 |
| E29 | Empty racks with no power | Part of E15 | 0 | 4 | 0 |
| E30 | Open positions with no power | Part of E15 | 0 | 8 | 0 |

### Building and space

These elements appear in the picture but are not for sale on the quote.

| Code | Element | Purpose |
|---|---|---|
| E16 | Building with the roof off | Lets the viewer see every room at once |
| E17 | Data center floor | Holds the 24 positions |
| E18 | 24 position markings | Show the full size of the data center, including uncovered floor |
| E19 | Three section boundaries | Separate the full, empty and open sections |
| E20 | Power room | Walled room beside the data center floor, inside the building, holding E5 in 24 slots |
| E21 | Monitoring center | Room that holds E7, with desks and a wall dashboard |

### Connections and labels

These elements explain the picture.

| Code | Element | Purpose |
|---|---|---|
| E23 | Power connection from E20 to E17 | Shows which positions have power, and is absent for E15 |
| E24 | Section labels | Name the three sections: running, ready and open |
| E25 | Quantity labels | Tie each drawn item to its quote quantity |
| E26 | Price labels | Tie each area to its cost (see the table below) |
| E27 | Version and quote total | Say which proposal is on screen |

### Cost by area (calculated)

| Area | Lines included | Version 1 | Version 2 | Version 3 |
|---|---|---:|---:|---:|
| Full racks | 8 clusters, 8 racks, 8 cooling | $202,520 | $202,520 | $202,520 |
| Empty racks | 8 racks | $27,760 | $27,760 | $27,760 |
| Open floor | None | $0 | $0 | $0 |
| Power room | All Power Systems | $105,360 | $52,680 | $94,824 |
| Shared systems | Storage, network, monitoring, security | $82,865 | $82,865 | $82,865 |
| **Quote total** | | **$418,505** | **$365,825** | **$407,969** |

## 2. What the seller wants to highlight

Kristen wants a larger first order and to become the natural supplier for what follows.

| Code | Point | Figure | Elements |
|---|---|---:|---|
| S1 | The power room is full and covers the whole data center from day one | 24 Power Systems | E5, E20, E23 |
| S2 | Infinitech can add compute and racks without touching the power room | 16 spare Power Systems | E13, E14, E18 |
| S3 | The floor has a clear plan: one third running, one third ready and one third open | 8, 8, 8 | E9, E10, E11, E19 |
| S4 | Cutting power to half leaves 4 empty racks and the last third of the floor with none behind them | 12 positions | E15, E28, E29, E30, E23 |
| S5 | The next purchase is compute, cooling and racks, with no new power | $377,280 at today's list prices | E11, E10, E6 |
| S6 | The shared systems are already in place for later racks | $82,865 | E3, E4, E7, E8 |

In buyer-facing documents, S5 is presented as Infinitech's cost to grow.

## 3. What the buyer wants to understand

Seth wants to remove the growth risk and needs a case that survives Infinitech's finance team.

| Code | Question | Answer in the view | Elements |
|---|---|---|---|
| B1 | What am I buying today? | 8 full racks, 8 empty racks, 24 Power Systems and the shared systems | E1 to E8 |
| B2 | What will run on day one, and what will sit idle? | 8 racks run. Spare power and empty racks sit idle: $98,000, about 23% of version 1 | E9, E10, E13 |
| B3 | What does the idle spend protect against? | New power work around live systems when growing past the powered positions | E14, E15, E20 |
| B4 | What will growth cost later? | See the growth table below | E10, E11, E13 |
| B5 | What else must I buy as I grow? | One Cooling System per added full rack, because cooling covers full racks only | E6 |
| B6 | What is not included? | The building, floor and rooms, which appear in the picture but not on the quote | E16 to E21 |
| B7 | What changed in this version? | Power quantity, spare power, unit price and total | E5, E13, E15, E27, E28 |

### Idle spend and growth (calculated)

Growth figures use today's list prices. The quote does not hold those prices for later purchases.

| Measure | Version 1 | Version 2 | Version 3 |
|---|---:|---:|---:|
| Spare Power Systems | $70,240 | $17,560 | $63,216 |
| Empty racks | $27,760 | $27,760 | $27,760 |
| Idle spend | $98,000 | $45,320 | $90,976 |
| Idle spend as share of quote | 23.4% | 12.4% | 22.3% |
| Cost to fill all 24 positions later | $377,280 | $429,960, plus unpriced power work | $377,280 |
| Total for the full data center | $795,785 | $795,785, plus unpriced power work | $785,249 |

Version 2 defers $52,680 but saves nothing over the full build, and it adds the power work. Version 3 is the only version that lowers the full-build total.

## 4. What the buyer can negotiate

| Code | Lever | Effect | Change in the view | In the story |
|---|---|---|---|---|
| N1 | Reduce Power Systems from 24 to 12 | $52,680 lower now | E5 and E13 shrink, E28 appears, and E23 stops short of E29 and E30 | Yes |
| N2 | 10% off every Power System | $10,536 lower | No change to the drawing, only E26 and E27 | Yes |
| N3 | Discount of 15% or more on a line | Larger saving, and a red "Manager" approval flag | Price labels only | No |
| N4 | Buy fewer empty racks now | $3,470 lower per rack | E10 shrinks and E11 grows | No |
| N5 | Hold today's prices for later purchases | Makes the $377,280 firm | Possibly a label on the growth figure | No |

## 5. Design rules

1. Open floor = 24 − Rack Enclosures.
2. Each full rack holds one Compute Cluster. E4 Network Fabric is the two blue overhead runs, and E3 Storage Subsystem is a visibly different unit inside 2 of the full racks.
3. Power Systems sit in a separate power room, following the story rather than the catalog's rack-level products.
4. The power room is a walled room inside the building, beside the data center floor.
5. E8 is a keypad plus a few small ceiling-level fire sensors, with one shared label.
6. Version 2 keeps all 16 racks, so 4 empty racks have no power behind them.
7. The 24 positions are 4 rows of 6, with full racks at the back, then empty racks, then uncovered floor at the front.
8. E5 is drawn as identical countable units, matching each version: 24, 12 or 24.
9. Audience-specific figures, such as overprovisioned power, are conditional highlights on the base drawing.
