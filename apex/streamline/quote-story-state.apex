// Puts demo Quote 00000003 into one story state through the deployed QuoteStoryState class.
// Meant for Execute Anonymous, which commits: sf apex run -o rcf-qb2 -f apex/streamline/quote-story-state.apex
// In Streamline the same run is a dry run, because Streamline rolls it back.
// Set STATE to V1_ORIGINAL (Qty 24, $418,505), V2_PUSHBACK (Qty 12, $365,825)
// or V3_COUNTEROFFER (Qty 24, 10% off, $407,969). Rerunning a state changes nothing.

QuoteStoryState.State STATE = QuoteStoryState.State.V1_ORIGINAL;

System.debug(LoggingLevel.ERROR, QuoteStoryState.apply('00000003', STATE));
