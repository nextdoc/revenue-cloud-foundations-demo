/**
 * Stream3 step for the Quote Ultimate template. One class serves every Apex step of the data
 * source, selected by the `section` config: partyRoles, definitions, floorPlan or discountFlag.
 * It holds the data and logic the org has no records for. floorPlan and discountFlag read the
 * upstream `quoteLines` SOQL step, which must select RLM_ProductName__c, Quantity and Discount.
 */
// `global` is required for the runner to instantiate it via Type.forName across the namespace boundary.
global with sharing class QuoteUltimateStep implements nxd.Step {
    private static final String QUOTE_LINES_STEP = 'quoteLines';
    private static final String COMPUTE_CLUSTER = 'Compute Cluster';
    private static final String STORAGE_SUBSYSTEM = 'Storage Subsystem';
    private static final String RACK_ENCLOSURE = 'Rack Enclosure (42U)';
    private static final String POWER_SYSTEM = 'Power System';
    private static final String MASTER_SUBSCRIPTION_AGREEMENT = 'Master Subscription Agreement';

    private final Map<String, Object> config = new Map<String, Object>();

    /**
     * @return the results key this step writes to, from the `name` config
     */
    public String getName() {
        return (String) config.get('name');
    }

    /**
     * @param config step config: `name`, `section`, plus `agreement` (definitions)
     *               or `rackPositions` (floorPlan)
     */
    public void addConfig(Map<String, Object> config) {
        this.config.putAll(config);
    }

    /**
     * Builds the configured section and stores it in the context results under getName().
     * @param context the data context holding earlier step results
     */
    public void execute(nxd.DataContext context) {
        context.results.put(getName(), build(context));
    }

    /**
     * @param context the data context holding earlier step results
     * @return the value of the configured section
     * @throws IllegalArgumentException when the section is unknown
     */
    private Object build(nxd.DataContext context) {
        String section = (String) config.get('section');
        switch on section {
            when 'partyRoles' { return partyRoles(); }
            when 'definitions' { return definitions((String) config.get('agreement')); }
            when 'floorPlan' { return floorPlan(quoteLines(context), configInteger('rackPositions')); }
            when 'discountFlag' { return new Map<String, Object>{ 'HasDiscount' => hasDiscount(quoteLines(context)) }; }
        }
        throw new IllegalArgumentException('Unknown QuoteUltimateStep section: ' + section);
    }

    // --- inputs ---

    /**
     * @param context the data context holding earlier step results
     * @return the records of the upstream quoteLines SOQL step
     */
    private List<QuoteLineItem> quoteLines(nxd.DataContext context) {
        List<QuoteLineItem> quoteLines = new List<QuoteLineItem>();
        for (SObject record : (List<SObject>) context.results.get(QUOTE_LINES_STEP)) {
            quoteLines.add((QuoteLineItem) record);
        }
        return quoteLines;
    }

    /**
     * @param key config key
     * @return the config value as an Integer, or 0 when absent
     */
    private Integer configInteger(String key) {
        Object value = config.get(key);
        return value == null ? 0 : Integer.valueOf(String.valueOf(value));
    }

    // --- party roles ---

    /**
     * @return the Buyer and Seller role labels
     */
    private Map<String, Object> partyRoles() {
        return new Map<String, Object>{
                'Buyer' => roleLabel('Buyer'),
                'Seller' => roleLabel('Seller')
        };
    }

    /**
     * @param label role label
     * @return a party role holding the label
     */
    private Map<String, Object> roleLabel(String label) {
        return new Map<String, Object>{ 'RoleLabel' => label };
    }

    // --- quote line queries ---

    /**
     * @param quoteLines the quote's lines
     * @param productName product name to match
     * @return the total quantity across the product's lines
     */
    private Integer quantityOf(List<QuoteLineItem> quoteLines, String productName) {
        Decimal total = 0;
        for (QuoteLineItem line : linesFor(quoteLines, productName)) {
            total += line.Quantity == null ? 0 : line.Quantity;
        }
        return total.intValue();
    }

    /**
     * @param quoteLines the quote's lines
     * @param productName product name to match
     * @return the discount percent of the product's first discounted line, or 0
     */
    private Integer discountOf(List<QuoteLineItem> quoteLines, String productName) {
        for (QuoteLineItem line : linesFor(quoteLines, productName)) {
            if (isDiscounted(line)) return line.Discount.intValue();
        }
        return 0;
    }

    /**
     * @param quoteLines the quote's lines
     * @return true when any line is discounted
     */
    private Boolean hasDiscount(List<QuoteLineItem> quoteLines) {
        for (QuoteLineItem line : quoteLines) {
            if (isDiscounted(line)) return true;
        }
        return false;
    }

    /**
     * @param line a quote line
     * @return true when the line's discount is above 0
     */
    private Boolean isDiscounted(QuoteLineItem line) {
        return line.Discount != null && line.Discount > 0;
    }

    /**
     * @param quoteLines the quote's lines
     * @param productName product name to match against RLM_ProductName__c
     * @return the lines for the product
     */
    private List<QuoteLineItem> linesFor(List<QuoteLineItem> quoteLines, String productName) {
        List<QuoteLineItem> matches = new List<QuoteLineItem>();
        for (QuoteLineItem line : quoteLines) {
            if (line.RLM_ProductName__c == productName) matches.add(line);
        }
        return matches;
    }

    // --- floor plan ---

    /**
     * @param quoteLines the quote's lines
     * @param rackPositions number of rack positions in the data center
     * @return the floor plan's Quantities and Callouts
     */
    private Map<String, Object> floorPlan(List<QuoteLineItem> quoteLines, Integer rackPositions) {
        Map<String, Object> quantities = floorPlanQuantities(quoteLines);
        return new Map<String, Object>{
                'Quantities' => quantities,
                'Callouts' => floorPlanCallouts(quantities, rackPositions)
        };
    }

    /**
     * @param quoteLines the quote's lines
     * @return the floor plan product quantities and the Power System discount percent
     */
    private Map<String, Object> floorPlanQuantities(List<QuoteLineItem> quoteLines) {
        return new Map<String, Object>{
                'ComputeClusters' => quantityOf(quoteLines, COMPUTE_CLUSTER),
                'StorageSubsystems' => quantityOf(quoteLines, STORAGE_SUBSYSTEM),
                'RackEnclosures' => quantityOf(quoteLines, RACK_ENCLOSURE),
                'PowerSystems' => quantityOf(quoteLines, POWER_SYSTEM),
                'PowerSystemDiscountPercent' => discountOf(quoteLines, POWER_SYSTEM)
        };
    }

    /**
     * Adds a discount callout when Power Systems are discounted, and an uncovered positions
     * callout when the racks don't fill every position.
     * @param quantities output of floorPlanQuantities
     * @param rackPositions number of rack positions in the data center
     * @return the floor plan callouts
     */
    private List<Object> floorPlanCallouts(Map<String, Object> quantities, Integer rackPositions) {
        Integer compute = (Integer) quantities.get('ComputeClusters');
        Integer storage = (Integer) quantities.get('StorageSubsystems');
        Integer racks = (Integer) quantities.get('RackEnclosures');
        Integer power = (Integer) quantities.get('PowerSystems');
        Integer powerDiscount = (Integer) quantities.get('PowerSystemDiscountPercent');

        List<Object> callouts = new List<Object>{
                callout('Compute clusters', compute + ' racks of compute', 'rack', 1, 'accent'),
                callout('Storage subsystems', storage + ' shared storage units', 'rack', compute, 'positive'),
                callout('Room to grow', (racks - compute) + ' empty racks', 'rack', compute + 1, 'neutral'),
                callout('Power feeds', power + ' Power Systems', 'power-system', 1, 'neutral')
        };
        if (powerDiscount > 0) {
            callouts.add(callout(powerDiscount + '% off', 'Power Systems discounted',
                    'power-system', power, 'positive'));
        }
        if (rackPositions > racks) {
            callouts.add(callout('Uncovered positions', (rackPositions - racks) + ' open positions',
                    'rack', racks + 1, 'warning'));
        }
        return callouts;
    }

    /**
     * @param title callout title
     * @param description callout description
     * @param targetType floor plan element type, rack or power-system
     * @param targetPosition 1-based position of the target element
     * @param tone visual tone: accent, positive, neutral or warning
     * @return a floor plan callout
     */
    private Map<String, Object> callout(String title, String description, String targetType,
            Integer targetPosition, String tone) {
        return new Map<String, Object>{
                'Title' => title,
                'Description' => description,
                'TargetType' => targetType,
                'TargetPosition' => targetPosition,
                'Tone' => tone
        };
    }

    // --- definitions ---

    /**
     * @param agreement agreement name
     * @return the agreement's numbered definitions, with a divider after each but the last
     */
    private List<Object> definitions(String agreement) {
        List<List<String>> terms = definitionTerms(agreement);
        List<Object> result = new List<Object>();
        for (Integer i = 0; i < terms.size(); i++) {
            Boolean isLast = i == terms.size() - 1;
            result.add(definition(i + 1, terms[i][0], terms[i][1], !isLast));
        }
        return result;
    }

    /**
     * @param agreement agreement name
     * @return the agreement's term and meaning pairs
     * @throws IllegalArgumentException when the agreement has no definitions
     */
    private List<List<String>> definitionTerms(String agreement) {
        if (agreement != MASTER_SUBSCRIPTION_AGREEMENT) {
            throw new IllegalArgumentException('No definitions for agreement: ' + agreement);
        }
        return new List<List<String>>{
                new List<String>{ 'Affiliate', 'means any entity which directly or indirectly controls, is '
                        + 'controlled by, or is under common control with the subject entity. “Control,” for '
                        + 'purposes of this definition, means direct or indirect ownership or control of more '
                        + 'than 50% of the voting interests of the subject entity.' },
                new List<String>{ 'Agreement', 'means this Master Subscription Agreement.' },
                new List<String>{ 'Documentation', 'means Our online help and training materials for the '
                        + 'Services accessible via our portals as updated from time to time.' },
                new List<String>{ 'Malicious Code', 'means code, files, scripts, agents or programs intended '
                        + 'to do harm, including, for example, viruses, worms, time bombs and Trojan horses.' }
        };
    }

    /**
     * @param sequence 1-based definition number
     * @param term defined term
     * @param meaning the term's meaning
     * @param dividerAfter true to draw a divider after the definition
     * @return a definition
     */
    private Map<String, Object> definition(Integer sequence, String term, String meaning, Boolean dividerAfter) {
        return new Map<String, Object>{
                'Sequence' => sequence,
                'Term' => term,
                'Meaning' => meaning,
                'DividerAfter' => dividerAfter
        };
    }
}
