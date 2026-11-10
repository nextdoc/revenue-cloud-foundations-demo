// Puts the demo quote into one of the story's proposal versions (docs/nextdoc-story.md).
// Only the Power System line changes. Place Sales Transaction reprices it, because DML on
// Quantity or Discount doesn't. Its RevSalesTrxn types aren't visible to anonymous Apex.
public with sharing class QuoteStoryState {
    public enum State { V1_ORIGINAL, V2_PUSHBACK, V3_COUNTEROFFER, V4_COUNTEROFFER_20 }

    public class QuoteStoryStateException extends Exception {}

    /**
     * Reads and places the quote. Tests substitute it because Place's Quote update fires the
     * Nextdoc refresh flow, whose callout test methods reject.
     */
    public interface Gateway {
        /**
         * @param quoteNumber the quote's number
         * @return the quote's Power System line with Quote.GrandTotal
         */
        QuoteLineItem powerSystemLine(String quoteNumber);

        /**
         * @param request a RevSalesTrxn.GraphRequest, typed Object so anonymous Apex can implement Gateway
         * @param options a RevSalesTrxn.ConfigurationOptionsInput
         * @return the serialized error response, or null on success
         */
        String place(Object request, Object options);
    }

    private static final String POWER_SYSTEM = 'Power System';

    private class Target {
        final Decimal quantity;
        final Decimal discount;
        final Decimal grandTotal;

        Target(Decimal quantity, Decimal discount, Decimal grandTotal) {
            this.quantity = quantity;
            this.discount = discount;
            this.grandTotal = grandTotal;
        }
    }

    private static final Map<State, Target> TARGETS = new Map<State, Target>{
        State.V1_ORIGINAL => new Target(24, null, 418505),
        State.V2_PUSHBACK => new Target(12, null, 365825),
        State.V3_COUNTEROFFER => new Target(24, 10, 407969),
        State.V4_COUNTEROFFER_20 => new Target(24, 20, 397433)
    };

    private class OrgGateway implements Gateway {
        public QuoteLineItem powerSystemLine(String quoteNumber) {
            return [
                SELECT Id, QuoteId, Quantity, Discount, NetTotalPrice, Quote.GrandTotal
                FROM QuoteLineItem
                WHERE Quote.QuoteNumber = :quoteNumber AND RLM_ProductName__c = :POWER_SYSTEM
                LIMIT 1
            ];
        }

        public String place(Object request, Object options) {
            RevSalesTrxn.PlaceSalesTransactionResponse response = RevSalesTrxn.PlaceSalesTransactionExecutor.execute(
                (RevSalesTrxn.GraphRequest) request,
                RevSalesTrxn.PricingPreferenceEnum.Force,
                RevSalesTrxn.ConfigurationExecutionEnum.Skip,
                (RevSalesTrxn.ConfigurationOptionsInput) options,
                null);
            return response.isSuccess ? null : JSON.serialize(response.errorResponse);
        }
    }

    /**
     * Idempotent: returns without a Place call when the quote is already in the state.
     * @param quoteNumber the quote's number
     * @param state the story state to put the quote in
     * @return a description of the outcome and the resulting Power System line
     */
    public static String apply(String quoteNumber, State state) {
        return apply(quoteNumber, state, new OrgGateway());
    }

    /**
     * @param quoteNumber the quote's number
     * @param state the story state to put the quote in
     * @param gateway reads and places the quote
     * @return a description of the outcome and the resulting Power System line
     * @throws QuoteStoryStateException when Place fails or the placed quote doesn't match the state
     */
    public static String apply(String quoteNumber, State state, Gateway gateway) {
        Target target = TARGETS.get(state);
        QuoteLineItem line = gateway.powerSystemLine(quoteNumber);
        if (matches(line, target)) {
            return describe('unchanged', quoteNumber, state, line);
        }
        String error = gateway.place(graphRequest(line, target), options());
        if (error != null) {
            throw new QuoteStoryStateException('Place failed: ' + error);
        }
        QuoteLineItem placed = gateway.powerSystemLine(quoteNumber);
        if (!matches(placed, target)) {
            throw new QuoteStoryStateException(describe('mismatch after Place', quoteNumber, state, placed));
        }
        return describe('placed', quoteNumber, state, placed);
    }

    private static Boolean matches(QuoteLineItem line, Target target) {
        return line.Quantity == target.quantity
            && line.Discount == target.discount
            && line.Quote.GrandTotal == target.grandTotal;
    }

    private static RevSalesTrxn.GraphRequest graphRequest(QuoteLineItem line, Target target) {
        RevSalesTrxn.RecordResource quoteRecord =
            new RevSalesTrxn.RecordResource(Quote.getSObjectType(), 'PATCH', line.QuoteId);
        RevSalesTrxn.RecordResource lineRecord =
            new RevSalesTrxn.RecordResource(QuoteLineItem.getSObjectType(), 'PATCH', line.Id);
        lineRecord.fieldValues = new Map<String, Object>{
            'Quantity' => target.quantity,
            'Discount' => target.discount
        };
        List<RevSalesTrxn.RecordWithReferenceRequest> records = new List<RevSalesTrxn.RecordWithReferenceRequest>{
            new RevSalesTrxn.RecordWithReferenceRequest('refQuote', quoteRecord),
            new RevSalesTrxn.RecordWithReferenceRequest('refLine', lineRecord)
        };
        return new RevSalesTrxn.GraphRequest('quoteStoryState', records);
    }

    private static RevSalesTrxn.ConfigurationOptionsInput options() {
        RevSalesTrxn.ConfigurationOptionsInput options = new RevSalesTrxn.ConfigurationOptionsInput();
        options.addDefaultConfiguration = false;
        options.executeConfigurationRules = false;
        options.validateAmendRenewCancel = false;
        options.validateProductCatalog = false;
        return options;
    }

    private static String describe(String outcome, String quoteNumber, State state, QuoteLineItem line) {
        return state + ' ' + outcome + ' on quote ' + quoteNumber
            + ': Power System qty ' + line.Quantity + ', discount ' + line.Discount
            + ', line ' + line.NetTotalPrice + ', GrandTotal ' + line.Quote.GrandTotal;
    }
}
