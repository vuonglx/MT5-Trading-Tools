Write an MQL5 Expert Advisor script called "Ultimate 6-Button Trading Panel" that creates a professional trading panel with six buttons aligned under the MT5 default Buy/Sell panel. The buttons should be:

1. Quick Buy – instantly open a buy order with default lot size, SL, TP.
2. Quick Sell – instantly open a sell order with default lot size, SL, TP.
3. Update Min SL/TP – adjust all positions to the smallest SL/TP distance found or default 70 pips.
4. Update Max SL/TP – adjust all positions to the largest SL/TP distance found or default 70 pips.
5. Close All – close all positions with the EA’s magic number.
6. Close Except Best – close all positions except the most profitable one.

Requirements:
- Use `CTrade` class for trade operations.
- Inputs: lot size, SL in pips, TP in pips, trailing stop in pips, magic number, comment.
- Include trailing stop logic in `OnTick` that moves SL once price moves beyond trailing threshold.
- Special handling for XAUUSD/GOLD: scale pip offsets by 0.1 instead of 10 * point.
- Buttons should flash green briefly when clicked.
- Clean up buttons on deinitialization.
- Print logs for success/failure of trade actions.

Deliver the full MQL5 code with proper structure, comments, and functions for each button action.
