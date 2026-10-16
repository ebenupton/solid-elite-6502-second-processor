CPU 1
P = &70 : Q = &72 : T = &73 : T1 = &74
QSL = &7600
QSH = &7800
ORG &2000
INCLUDE "body.asm"
ORG QSL
FOR n, 0, 511
 EQUB LO(n * n DIV 4)
NEXT
ORG QSH
FOR n, 0, 511
 EQUB HI(n * n DIV 4)
NEXT
SAVE "new.bin", &2000, &2400
SAVE "tab.bin", QSL, QSH + 512
