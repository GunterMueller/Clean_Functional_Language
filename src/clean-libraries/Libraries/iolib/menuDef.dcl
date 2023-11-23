definition module menuDef;

/* The type definitions fot the menu device. */

import commonDef;
    
:: MenuDef * s * io
       = PullDownMenu MenuId MenuTitle SelectState [MenuElement s io];
:: MenuElement * s * io
       = MenuItem MenuItemId ItemTitle KeyShortcut SelectState (MenuFunction s io)
       |  CheckMenuItem MenuItemId ItemTitle KeyShortcut SelectState MarkState
                        (MenuFunction s io)
       |  SubMenuItem MenuId ItemTitle SelectState [MenuElement s io]
       |  MenuItemGroup MenuItemGroupId [MenuElement s io]
       |  MenuRadioItems MenuItemId [RadioElement s io]
       |  MenuSeparator;
:: RadioElement * s * io
       = MenuRadioItem MenuItemId ItemTitle KeyShortcut SelectState
                        (MenuFunction s io);
::	MenuTitle       :== String;
:: MenuFunction * s * io :== s ->  * (io -> *(s, io)) ;
:: MenuId          :== Int;
:: MenuItemId      :== Int;
:: MenuItemGroupId :== Int;
:: KeyShortcut     = Key KeyCode | NoKey;

