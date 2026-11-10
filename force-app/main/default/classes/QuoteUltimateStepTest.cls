/**
 * Coverage for QuoteUltimateStep. Runs each `section` against in-memory quote lines, so no DML
 * or org data is needed.
 */
@IsTest
private class QuoteUltimateStepTest {

    /**
     * @param productName value for the RLM_ProductName__c formula field
     * @param quantity line quantity, or null
     * @param discount line discount percent, or null
     * @return an in-memory quote line
     */
    private static QuoteLineItem line(String productName, Decimal quantity, Decimal discount) {
        // RLM_ProductName__c is a formula field, so it can only be set through deserialization.
        return (QuoteLineItem) JSON.deserialize(JSON.serialize(new Map<String, Object>{
                'attributes' => new Map<String, Object>{ 'type' => 'QuoteLineItem' },
                'RLM_ProductName__c' => productName,
                'Quantity' => quantity,
                'Discount' => discount
        }), QuoteLineItem.class);
    }

    /**
     * @param powerDiscount discount percent on the first Power System line, or null
     * @return 8 compute, 4 storage, 10 racks over two lines and 24 Power Systems plus a null-quantity line
     */
    private static List<QuoteLineItem> storyLines(Decimal powerDiscount) {
        return new List<QuoteLineItem>{
                line('Compute Cluster', 8, null),
                line('Storage Subsystem', 4, null),
                line('Rack Enclosure (42U)', 6, null),
                line('Rack Enclosure (42U)', 4, null),
                line('Power System', 24, powerDiscount),
                line('Power System', null, null)
        };
    }

    /**
     * Runs the step and checks it writes under its configured name.
     * @param config step config
     * @param quoteLines upstream quoteLines step result, or null to omit it
     * @return the value the step wrote to the context results
     */
    private static Object run(Map<String, Object> config, List<QuoteLineItem> quoteLines) {
        nxd.DataContext context = new nxd.DataContext();
        if (quoteLines != null) {
            context.results.put('quoteLines', quoteLines);
        }
        QuoteUltimateStep step = new QuoteUltimateStep();
        step.addConfig(config);
        step.execute(context);
        System.assertEquals(config.get('name'), step.getName(), 'name comes from config');
        return context.results.get(step.getName());
    }

    @IsTest
    static void partyRolesLabelsBuyerAndSeller() {
        Map<String, Object> roles = (Map<String, Object>) run(
                new Map<String, Object>{ 'name' => 'partyRoles', 'section' => 'partyRoles' }, null);

        System.assertEquals('Buyer', ((Map<String, Object>) roles.get('Buyer')).get('RoleLabel'));
        System.assertEquals('Seller', ((Map<String, Object>) roles.get('Seller')).get('RoleLabel'));
    }

    @IsTest
    static void definitionsNumberTermsWithDividersBetween() {
        List<Object> definitions = (List<Object>) run(new Map<String, Object>{
                'name' => 'definitions', 'section' => 'definitions',
                'agreement' => 'Master Subscription Agreement' }, null);

        System.assertEquals(4, definitions.size());
        Map<String, Object> first = (Map<String, Object>) definitions[0];
        Map<String, Object> last = (Map<String, Object>) definitions[3];
        System.assertEquals(1, first.get('Sequence'));
        System.assertEquals('Affiliate', first.get('Term'));
        System.assertEquals(true, first.get('DividerAfter'));
        System.assertEquals(4, last.get('Sequence'));
        System.assertEquals('Malicious Code', last.get('Term'));
        System.assertEquals(false, last.get('DividerAfter'), 'no divider after the last definition');
    }

    @IsTest
    static void definitionsRejectUnknownAgreement() {
        try {
            run(new Map<String, Object>{
                    'name' => 'definitions', 'section' => 'definitions', 'agreement' => 'NDA' }, null);
            System.assert(false, 'expected IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assertEquals('No definitions for agreement: NDA', e.getMessage());
        }
    }

    @IsTest
    static void floorPlanAddsDiscountAndUncoveredCallouts() {
        Map<String, Object> floorPlan = (Map<String, Object>) run(new Map<String, Object>{
                'name' => 'floorPlan', 'section' => 'floorPlan', 'rackPositions' => '12' }, storyLines(10));

        Map<String, Object> quantities = (Map<String, Object>) floorPlan.get('Quantities');
        System.assertEquals(8, quantities.get('ComputeClusters'));
        System.assertEquals(4, quantities.get('StorageSubsystems'));
        System.assertEquals(10, quantities.get('RackEnclosures'), 'sums every rack line');
        System.assertEquals(24, quantities.get('PowerSystems'), 'a null quantity counts as 0');
        System.assertEquals(10, quantities.get('PowerSystemDiscountPercent'));

        List<Object> callouts = (List<Object>) floorPlan.get('Callouts');
        System.assertEquals(6, callouts.size());
        Map<String, Object> roomToGrow = (Map<String, Object>) callouts[2];
        System.assertEquals('2 empty racks', roomToGrow.get('Description'));
        System.assertEquals(9, roomToGrow.get('TargetPosition'));
        Map<String, Object> discount = (Map<String, Object>) callouts[4];
        System.assertEquals('10% off', discount.get('Title'));
        System.assertEquals('power-system', discount.get('TargetType'));
        System.assertEquals(24, discount.get('TargetPosition'));
        Map<String, Object> uncovered = (Map<String, Object>) callouts[5];
        System.assertEquals('Uncovered positions', uncovered.get('Title'));
        System.assertEquals('2 open positions', uncovered.get('Description'));
        System.assertEquals(11, uncovered.get('TargetPosition'));
        System.assertEquals('warning', uncovered.get('Tone'));
    }

    @IsTest
    static void floorPlanOmitsOptionalCalloutsWithoutDiscountOrRackPositions() {
        Map<String, Object> floorPlan = (Map<String, Object>) run(new Map<String, Object>{
                'name' => 'floorPlan', 'section' => 'floorPlan' }, storyLines(0));

        Map<String, Object> quantities = (Map<String, Object>) floorPlan.get('Quantities');
        System.assertEquals(0, quantities.get('PowerSystemDiscountPercent'));
        System.assertEquals(4, ((List<Object>) floorPlan.get('Callouts')).size());
    }

    @IsTest
    static void discountFlagReflectsAnyDiscountedLine() {
        Map<String, Object> config = new Map<String, Object>{ 'name' => 'discountFlag', 'section' => 'discountFlag' };

        System.assertEquals(true, ((Map<String, Object>) run(config, storyLines(10))).get('HasDiscount'));
        System.assertEquals(false, ((Map<String, Object>) run(config, storyLines(null))).get('HasDiscount'));
    }

    @IsTest
    static void unknownSectionThrows() {
        try {
            run(new Map<String, Object>{ 'name' => 'mystery', 'section' => 'mystery' }, null);
            System.assert(false, 'expected IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assertEquals('Unknown QuoteUltimateStep section: mystery', e.getMessage());
        }
    }
}
