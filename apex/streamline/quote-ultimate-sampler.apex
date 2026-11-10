// ============================================================================
// Quote Ultimate — Sampler step-runner
// ============================================================================
//
// Runs the "Quote Ultimate Static" data source steps against a real
// rcf-qb2 Quote. The Apex steps use the deployed QuoteUltimateStep class
// (force-app), selected by its `section` config: partyRoles, definitions,
// floorPlan or discountFlag.
//
// PARITY compares each Apex step's values with the reference sample
// REFERENCE_SAMPLE, which uses different step keys.
//
// ============================================================================

// === CLASSES ===

class QuoteUltimateSampler {
    private final String SAMPLER_ENDPOINT = 'callout:nxd__Sampler/d/sampler';
    private final String DOC_NAME = 'Quote Ultimate';
    private final String REFERENCE_SAMPLE = 'story-v1-original';
    private final String QUOTE_NUMBER = '00000003';
    // Live Apex step key => the reference sample's key holding the same values.
    private final Map<String, String> PARITY = new Map<String, String>{
            'definitions' => 'QuoteDefinitions',
            'floorPlan' => 'QuoteFloorPlan',
            'discountFlag' => 'quote discount flag'
    };
    // true saves the live steps to prod Nextdoc as CAPTURE_SAMPLE_NAME; survives the rollback.
    private final Boolean CAPTURE = false;
    private final String CAPTURE_SAMPLE_NAME = 'Quote Ultimate v1 Original';
    private final String CAPTURE_ROLE = 'TEST';
    private final String CAPTURE_PROFILE = 'System Administrator';

    private final nxd.Stream3SamplerAPI.Sampler sampler =
            new nxd.Stream3SamplerAPI.Sampler(SAMPLER_ENDPOINT);
    private String documentId;
    private String sampleId;
    private Id recordId;
    private List<Map<String, Object>> liveSteps;

    void run() {
        documentId = sampler.documentId(DOC_NAME);
        sampleId = sampler.searchSamples(documentId).get(REFERENCE_SAMPLE);
        recordId = [SELECT Id FROM Quote WHERE QuoteNumber = :QUOTE_NUMBER LIMIT 1].Id;
        liveSteps = sampler.runSteps(builder());
        for (Map<String, Object> step : liveSteps) {
            System.debug(LoggingLevel.ERROR,
                    'STEP ' + step.get('name') + ': ' + JSON.serialize(step.get('content')));
        }
        parity();
        if (CAPTURE) capture();
    }

    nxd.Stream3SamplerAPI.StepBuilder builder() {
        nxd.Stream3SamplerAPI.SoqlOpts single =
                new nxd.Stream3SamplerAPI.SoqlOpts().singleResult(true).rawResults(true);
        nxd.Stream3SamplerAPI.SoqlOpts many =
                new nxd.Stream3SamplerAPI.SoqlOpts().singleResult(false).rawResults(true);
        nxd.Stream3SamplerAPI.StepBuilder steps = new nxd.Stream3SamplerAPI.StepBuilder()
                .client('LWC_DESKTOP')
                .parameters(new Map<String, Object>{ 'recordId' => recordId })
                .soql('quote',
                        // SELECT Id, QuoteNumber, CreatedDate, ExpirationDate, GrandTotal, Account.Name, CreatedBy.Name, CreatedBy.Title, CreatedBy.Email FROM Quote WHERE Id = '{{parameters.recordId}}'
                        'SELECT Id, QuoteNumber, CreatedDate, ExpirationDate, GrandTotal, '
                        + 'Account.Name, CreatedBy.Name, CreatedBy.Title, CreatedBy.Email '
                        + 'FROM Quote WHERE Id = \'{{parameters.recordId}}\'',
                        single)
                .soql('sellerOrganization',
                        // SELECT Id, Name, Country FROM Organization LIMIT 1
                        'SELECT Id, Name, Country FROM Organization LIMIT 1',
                        single)
                .soql('quoteLines',
                        // SELECT Id, RLM_ProductName__c, Product2.ProductCode, Quantity, ListPrice, Discount, NetUnitPrice, NetTotalPrice FROM QuoteLineItem WHERE QuoteId = '{{parameters.recordId}}' ORDER BY SortOrder
                        'SELECT Id, RLM_ProductName__c, Product2.ProductCode, Quantity, ListPrice, Discount, '
                        + 'NetUnitPrice, NetTotalPrice FROM QuoteLineItem '
                        + 'WHERE QuoteId = \'{{parameters.recordId}}\' ORDER BY SortOrder',
                        many);
        apexStep(steps, 'partyRoles', new Map<String, Object>());
        apexStep(steps, 'definitions', new Map<String, Object>{ 'agreement' => 'Master Subscription Agreement' });
        apexStep(steps, 'floorPlan', new Map<String, Object>{ 'rackPositions' => 24 });
        apexStep(steps, 'discountFlag', new Map<String, Object>());
        return steps;
    }

    void apexStep(nxd.Stream3SamplerAPI.StepBuilder steps, String section, Map<String, Object> stepConfig) {
        stepConfig.put('name', section);
        stepConfig.put('section', section);
        steps.apexDeferred(new QuoteUltimateStep(), stepConfig);
    }

    void parity() {
        Map<String, String> reference = sampler.sampleContents(sampleId);
        for (Map<String, Object> step : liveSteps) {
            String referenceKey = PARITY.get((String) step.get('name'));
            if (referenceKey == null) continue;
            Object live = JSON.deserializeUntyped((String) step.get('content'));
            Object referenceValue = JSON.deserializeUntyped(reference.get(referenceKey));
            System.debug(LoggingLevel.ERROR, 'PARITY ' + step.get('name') + ' vs ' + referenceKey + ': '
                    + (live == referenceValue));
        }
    }

    void capture() {
        String source = sampler.dataSourceId(documentId, REFERENCE_SAMPLE);
        String existingId = sampler.searchSamples(documentId).get(CAPTURE_SAMPLE_NAME);
        String savedId = (existingId == null)
                ? sampler.createSample(CAPTURE_SAMPLE_NAME, source,
                        CAPTURE_ROLE, CAPTURE_PROFILE, liveSteps)
                : sampler.updateSample(existingId, CAPTURE_SAMPLE_NAME, source,
                        CAPTURE_ROLE, CAPTURE_PROFILE, liveSteps);
        System.debug(LoggingLevel.ERROR, 'CAPTURE source ' + source + ' saved sampleId: ' + savedId);
    }
}

// === LOAD ===

new QuoteUltimateSampler().run();
