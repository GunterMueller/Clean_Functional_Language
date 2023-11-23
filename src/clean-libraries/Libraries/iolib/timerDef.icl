implementation module timerDef;

/* The type definitions for the timer module.
*/

import commonDef;

    
:: TimerDef * s * io
        = Timer TimerId SelectState TimerInterval (TimerFunction s io);
::	TimerId       :== Int;
:: TimerInterval :== Int;
:: TimerFunction * s * io :== TimerState ->  s -> * ( io -> *(s,io) ) ;
:: TimerState    :== Int;

