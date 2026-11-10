/**
 * Coverage for QuoteStoryState. A fake Gateway stands in for the org, so no Quote update fires
 * the Nextdoc refresh flow and its callout.
 */
@IsTest
private class QuoteStoryStateTest {
    private static final String QUOTE_NUMBER = '00000003';

    /**
     * Returns `current` until a successful place, then `afterPlace`.
     */
    private class FakeGateway implements QuoteStoryState.Gateway {
        private QuoteLineItem current;
        private final QuoteLineItem afterPlace;
        private final String placeError;
        private Integer placeCount = 0;

        /**
         * @param current the line before Place
         * @param afterPlace the line after a successful Place
         * @param placeError the error Place returns, or null for success
         */
        FakeGateway(QuoteLineItem current, QuoteLineItem afterPlace, String placeError) {
            this.current = current;
            this.afterPlace = afterPlace;
            this.placeError = placeError;
        }

        public QuoteLineItem powerSystemLine(String quoteNumber) {
            return current;
        }

        public String place(Object request, Object options) {
            placeCount++;
            if (placeError == null) {
                current = afterPlace;
            }
            return placeError;
        }
    }

    /**
     * @param quantity line quantity
     * @param discount line discount percent, or null
     * @param grandTotal the quote's GrandTotal
     * @return an in-memory Power System line with its Quote
     */
    private static QuoteLineItem line(Decimal quantity, Decimal discount, Decimal grandTotal) {
        // Quote.GrandTotal is a read-only relationship field, so it can only be set through deserialization.
        return (QuoteLineItem) JSON.deserialize(JSON.serialize(new Map<String, Object>{
                'attributes' => new Map<String, Object>{ 'type' => 'QuoteLineItem' },
                'Quantity' => quantity,
                'Discount' => discount,
                'NetTotalPrice' => 1000,
                'Quote' => new Map<String, Object>{
                        'attributes' => new Map<String, Object>{ 'type' => 'Quote' },
                        'GrandTotal' => grandTotal }
        }), QuoteLineItem.class);
    }

    @IsTest
    static void applyRejectsUnknownQuote() {
        try {
            QuoteStoryState.apply('NO-SUCH-QUOTE', QuoteStoryState.State.V1_ORIGINAL);
            System.assert(false, 'expected QueryException');
        } catch (QueryException e) {
            System.assert(e.getMessage().contains('no rows'), e.getMessage());
        }
    }

    @IsTest
    static void applyIsUnchangedWhenAlreadyInState() {
        FakeGateway gateway = new FakeGateway(line(24, null, 418505), null, null);

        String result = QuoteStoryState.apply(QUOTE_NUMBER, QuoteStoryState.State.V1_ORIGINAL, gateway);

        System.assertEquals('V1_ORIGINAL unchanged on quote 00000003: Power System qty 24.0, '
                + 'discount null, line 1000.0, GrandTotal 418505.0', result);
        System.assertEquals(0, gateway.placeCount, 'no Place when already in state');
    }

    @IsTest
    static void applyPlacesWhenStateDiffers() {
        FakeGateway gateway = new FakeGateway(line(24, null, 418505), line(24, 20, 397433), null);

        String result = QuoteStoryState.apply(QUOTE_NUMBER, QuoteStoryState.State.V4_COUNTEROFFER_20, gateway);

        System.assertEquals('V4_COUNTEROFFER_20 placed on quote 00000003: Power System qty 24.0, '
                + 'discount 20.0, line 1000.0, GrandTotal 397433.0', result);
        System.assertEquals(1, gateway.placeCount);
    }

    @IsTest
    static void applyThrowsWhenPlaceFails() {
        FakeGateway gateway = new FakeGateway(line(24, null, 418505), null, '{"code":"BAD"}');

        try {
            QuoteStoryState.apply(QUOTE_NUMBER, QuoteStoryState.State.V2_PUSHBACK, gateway);
            System.assert(false, 'expected QuoteStoryStateException');
        } catch (QuoteStoryState.QuoteStoryStateException e) {
            System.assertEquals('Place failed: {"code":"BAD"}', e.getMessage());
        }
    }

    @IsTest
    static void applyThrowsWhenPlacedQuoteMismatches() {
        FakeGateway gateway = new FakeGateway(line(24, null, 418505), line(12, null, 999), null);

        try {
            QuoteStoryState.apply(QUOTE_NUMBER, QuoteStoryState.State.V2_PUSHBACK, gateway);
            System.assert(false, 'expected QuoteStoryStateException');
        } catch (QuoteStoryState.QuoteStoryStateException e) {
            System.assert(e.getMessage().startsWith('V2_PUSHBACK mismatch after Place on quote 00000003'),
                    e.getMessage());
        }
    }
}
