// ============================================================================
// Quote Original — Sampler step-runner
// ============================================================================
//
// Runs the "Quote Original Static" data source steps against a real rcf-qb2
// Quote and diffs the output against the prod sample "Quote Original v1 Original".
// Every call goes to prod Nextdoc through the nxd__Sampler named credential.
// No fixtures: the steps read persisted org data, so all callouts sit in LOAD.
//
// ============================================================================

// === CLASSES ===

class QuoteOriginalSampler {
    private final String SAMPLER_ENDPOINT = 'callout:nxd__Sampler/d/sampler';
    private final String DOC_NAME = 'Quote Original';
    private final String REFERENCE_SAMPLE = 'Quote Original v1 Original';
    private final String QUOTE_NUMBER = '00000003';
    private final String DIFF_MODE = 'KEYS_ONLY';
    // true saves the live steps to prod Nextdoc as CAPTURE_SAMPLE_NAME; survives the rollback.
    private final Boolean CAPTURE = false;
    private final String CAPTURE_SAMPLE_NAME = 'Quote Original v1 Original';
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
        diff();
        if (CAPTURE) capture();
    }

    nxd.Stream3SamplerAPI.StepBuilder builder() {
        nxd.Stream3SamplerAPI.SoqlOpts single =
                new nxd.Stream3SamplerAPI.SoqlOpts().singleResult(true).rawResults(true);
        nxd.Stream3SamplerAPI.SoqlOpts many =
                new nxd.Stream3SamplerAPI.SoqlOpts().singleResult(false).rawResults(true);
        return new nxd.Stream3SamplerAPI.StepBuilder()
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
                        // SELECT Id, RLM_ProductName__c, Quantity, ListPrice, Discount, NetUnitPrice, NetTotalPrice FROM QuoteLineItem WHERE QuoteId = '{{parameters.recordId}}' ORDER BY SortOrder
                        'SELECT Id, RLM_ProductName__c, Quantity, ListPrice, Discount, '
                        + 'NetUnitPrice, NetTotalPrice FROM QuoteLineItem '
                        + 'WHERE QuoteId = \'{{parameters.recordId}}\' ORDER BY SortOrder',
                        many);
    }

    void diff() {
        nxd.Stream3SamplerAPI.DiffResult result =
                sampler.sampleStepDiff(sampleId, DIFF_MODE, liveSteps);
        System.debug(LoggingLevel.ERROR, 'DIFF ' + DIFF_MODE + ' match: ' + result.match);
        for (nxd.Stream3SamplerAPI.DiffEntry entry : result.diffs) {
            System.debug(LoggingLevel.ERROR,
                    entry.step + ' missing: ' + entry.missing + ' extra: ' + entry.extra);
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

new QuoteOriginalSampler().run();
