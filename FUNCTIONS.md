# HARA BHARA BANK - Function Guide

How each procedure in `BankSystem.asm` works, with its code, the syllabus topic it uses and a simple explanation.

## Data layout (used by many functions)

* **Parallel arrays** (one element per account, 20 slots): `accNum`, `accPin`, `accBal` (DWORD) and `accStat` (BYTE: 0 = Working, 1 = Frozen). Slot *i* of every array belongs to the same account. An account number of 0 means the slot is empty.
* **2-D arrays**: `accName[20][24]` (names) and `history[20][5 entries x 40 bytes]` (transactions). Row address = start + row x row size.
* **Symbolic constants** (`MAX_ACC`, `NAME_LEN`, `USD_RATE`, ...) are defined at the top with `=` (Week 3).
* Everything between the labels `fileStart` and `fileEnd` is what gets saved to the file.

## Program start and menus

### `main`

**Course concepts:** Procedures (Wk 7); INVOKE / ADDR (Wk 11); shift instructions - `SHR` (Wk 10); data transfer `MOVZX` (Wk 4)

Entry point. Seeds the random generator (for transaction IDs), asks the console how wide it is (`GetMaxXY`) so text can be centred, shows the splash screen, loads saved accounts from the file, then runs the main menu. When the user picks *Exit*, `RunMenu` returns, the data is saved and the program ends. `SHR eax,1` divides by 2 to get the left margin.

```asm
main PROC
    call Randomize                  ; seed for random transaction IDs
    call GetMaxXY                   ; DX = console columns
    movzx eax, dx
    cmp  eax, 60                    ; keep 80 if the width looks wrong
    jb   WidthOk
    mov  screenW, eax
    sub  eax, 42                    ; prompts start where boxes start
    shr  eax, 1                     ; divide by 2
    mov  leftPad, eax
WidthOk:
    call SplashScreen
    call LoadData
    call PressAnyKey
    INVOKE RunMenu, ADDR mnuMain, ADDR mainProcs, 4   ; until "Exit"
    call SaveData
    INVOKE ShowMsg, lightGreen, ADDR sBye, NO_NUM
    exit
main ENDP
```

### `RunMenu`

**Course concepts:** Table-driven selection / arrays (Wk 5, 8-9); indirect `CALL` through an address table, addressing modes (Wk 4, 14); conditional jumps (Wk 8-9); stack frame parameters (Wk 11)

One menu routine is used for **all four menus**. It draws the menu, reads one key, turns `'1'` into the number 1 (`SUB eax,'0'`) and checks the range. The last option always means Back/Logout/Exit. For a valid option it calls the procedure whose address is stored in a table such as `custProcs` (`call DWORD PTR [esi + eax*4 - 4]`): option 1 is element 0, option 2 is element 1, and so on. After the procedure finishes it waits for a key and shows the menu again.

```asm
RunMenu PROC, pMenu:PTR BYTE, pProcs:PTR DWORD, nOpts:DWORD
; Shows a menu and calls the chosen procedure from a table of procedure
; addresses (table-driven selection). The last option always means Back.
RmShow:
    call ShowHeader
    mov  ebx, lightGreen
    mov  edx, pMenu
    call PrintLines                 ; draw the menu box
    INVOKE Prompt, ADDR choiceTxt
    call GetKey
    call WriteChar
    call Crlf
    movzx eax, al
    sub  eax, '0'                   ; key '1' -> number 1
    cmp  eax, nOpts
    je   RmBack
    ja   RmBad                      ; too big, or not a digit at all
    cmp  eax, 0
    je   RmBad
    mov  esi, pProcs
    call DWORD PTR [esi + eax*4 - 4]  ; call the procedure from the table
    jmp  RmPause
RmBad:
    INVOKE ShowMsg, lightRed, ADDR eChoice, NO_NUM
RmPause:
    call PressAnyKey
    jmp  RmShow
RmBack:
    ret
RunMenu ENDP
```

## Screen and colour helpers

### `PrintSpaces`

**Course concepts:** Loops with `LOOP` (Wk 5); conditional jump `JLE` (Wk 8-9); `USES` and the stack (Wk 7)

Prints ECX spaces. If ECX is 0 or negative it prints nothing (this protects `LOOP`, which would run 4 billion times if ECX were 0).

```asm
PrintSpaces PROC USES eax ecx
; Prints ECX spaces (nothing if ECX <= 0).
    cmp  ecx, 0
    jle  PsDone
    mov  al, ' '
PsLoop:
    call WriteChar
    loop PsLoop
PsDone:
    ret
PrintSpaces ENDP
```

### `PrintMargin`

**Course concepts:** Arithmetic `NEG/ADD` (Wk 4); arithmetic shift `SAR` (Wk 10)

To centre a text of length L on a screen of width W we need (W - L) / 2 spaces. `NEG` + `ADD` computes W - L and `SAR ecx,1` divides by 2.

```asm
PrintMargin PROC USES ecx
; Prints the spaces needed to centre text that is ECX characters long.
    neg  ecx
    add  ecx, screenW               ; ECX = screenW - length
    sar  ecx, 1                     ; half of it (shift right = divide by 2)
    call PrintSpaces
    ret
PrintMargin ENDP
```

### `ShowMsg`

**Course concepts:** PROC with parameters, PROTO, INVOKE, stack frame (Wk 11); comparison and jumps (Wk 8-9)

The main output routine. Prints a message centred and coloured (`SetTextColor`), then switches back to white. If the third parameter is not `NO_NUM` the number is printed after the text, e.g. *Attempts left: 2*. Every message in the program goes through here, so all messages are coloured: green = success, red = error, yellow = warning, cyan = info.

```asm
ShowMsg PROC USES eax ecx edx, color:DWORD, pText:PTR BYTE, number:DWORD
; Prints a message centred on the screen in the given colour. If number
; is not NO_NUM it is printed right after the text.
    mov  edx, pText
    call StrLength
    mov  ecx, eax
    cmp  number, NO_NUM
    je   SmCentre
    add  ecx, 6                     ; leave room for the number
SmCentre:
    call PrintMargin
    mov  eax, color
    call SetTextColor
    call WriteString
    cmp  number, NO_NUM
    je   SmDone
    mov  eax, number
    call WriteDec
SmDone:
    call Crlf
    mov  eax, white                 ; back to normal text colour
    call SetTextColor
    ret
ShowMsg ENDP
```

### `PrintLines`

**Course concepts:** Strings / null-terminated arrays (Wk 13); loops (Wk 5)

Prints several strings that are stored one after another in memory, each centred on its own line, until it finds an empty string. Used to draw the box menus and the logo. `StrLength` + 1 moves EDX to the next string.

```asm
PrintLines PROC USES eax edx
; Prints the strings that start at EDX, centred, in colour EBX, until an
; empty string is reached. Used for the menus and the logo.
PlNext:
    INVOKE ShowMsg, ebx, edx, NO_NUM
    call StrLength                  ; move EDX to the next string
    add  edx, eax
    inc  edx
    cmp  BYTE PTR [edx], 0
    jne  PlNext
    ret
PrintLines ENDP
```

### `ShowHeader`

**Course concepts:** Procedures (Wk 7); INVOKE / ADDR (Wk 11)

Clears the screen and draws the bank banner: a double line, **HARA BHARA BANK** (white on green, centred), the tag line and another double line. Called at the top of every screen.

```asm
ShowHeader PROC
; Clears the screen and draws the centred bank banner.
    call Clrscr
    INVOKE ShowMsg, green, ADDR dblLine, NO_NUM
    INVOKE ShowMsg, BANNER, ADDR bankName, NO_NUM
    INVOKE ShowMsg, lightGreen, ADDR tagLine, NO_NUM
    INVOKE ShowMsg, green, ADDR dblLine, NO_NUM
    call Crlf
    ret
ShowHeader ENDP
```

### `SplashScreen`

**Course concepts:** Loops (Wk 5); `Delay` from Irvine32; character constants (Wk 3)

Shows the banner, the logo and an animated loading bar: 40 solid blocks (character 219) printed one by one with a 40 ms delay between them.

```asm
SplashScreen PROC
; Bank banner, coloured logo and an animated loading bar.
    call ShowHeader
    mov  ebx, lightGreen
    mov  edx, OFFSET logo
    call PrintLines
    call Crlf
    INVOKE ShowMsg, lightCyan, ADDR loadingTxt, NO_NUM
    mov  ecx, 40
    call PrintMargin
    mov  eax, green
    call SetTextColor
SpBar:
    mov  al, 219                    ; solid block character
    call WriteChar
    mov  eax, 40                    ; wait 40 ms per block
    call Delay
    loop SpBar
    call Crlf
    ret
SplashScreen ENDP
```

### `Prompt`

**Course concepts:** Parameters on the stack (Wk 11)

Prints a question at the left edge of the menu box in cyan, then switches to white so that what the user types is white.

```asm
Prompt PROC USES eax ecx edx, pText:PTR BYTE
; Prints a cyan prompt at the left margin; typed input will be white.
    mov  ecx, leftPad
    call PrintSpaces
    mov  eax, lightCyan
    call SetTextColor
    mov  edx, pText
    call WriteString
    mov  eax, white
    call SetTextColor
    ret
Prompt ENDP
```

### `InfoLine`

**Course concepts:** INVOKE with parameters (Wk 11)

Prints a label followed by a number, e.g. `Current Balance: Rs. 5000`. Used by the balance screen, receipts, calculators and totals.

```asm
InfoLine PROC USES eax, pText:PTR BYTE, number:DWORD
; Prints a label followed by a number, e.g. "Amount : Rs. 500".
    INVOKE Prompt, pText
    mov  eax, number
    call WriteDec
    call Crlf
    ret
InfoLine ENDP
```

### `NameLine`

**Course concepts:** INVOKE (Wk 11); 2-D array access through `GetNamePtr` (Wk 13)

Prints a label followed by the name of the account whose index is in ESI.

```asm
NameLine PROC USES edx, pText:PTR BYTE
; Prints a label followed by the name of account ESI.
    INVOKE Prompt, pText
    call GetNamePtr
    call WriteString
    call Crlf
    ret
NameLine ENDP
```

### `WriteStatus`

**Course concepts:** Arrays used as lookup tables, scaled index addressing `[eax*4]` (Wk 4, 5)

Prints **Working** in green or **Frozen** in red. The status byte (0 or 1) is used as an index into two small tables: one holds the text, the other the colour - no IF needed.

```asm
WriteStatus PROC USES eax edx
; Writes "Working" (green) or "Frozen" (red) for account ESI,
; picking the text and colour from two small tables.
    movzx eax, accStat[esi]
    mov  edx, statText[eax*4]
    mov  eax, statColor[eax*4]
    call SetTextColor
    call WriteString
    mov  eax, white
    call SetTextColor
    ret
WriteStatus ENDP
```

### `GetKey`

**Course concepts:** Conditional loop (Wk 8-9)

Waits for a key with Irvine's `ReadChar` and ignores keys that have no character (Shift, arrows ...), which return 0.

```asm
GetKey PROC
; Waits for a normal key (not Shift, arrows, ...) and returns it in AL.
GkWait:
    call ReadChar
    cmp  al, 0
    je   GkWait
    ret
GetKey ENDP
```

### `AskYesNo`

**Course concepts:** Boolean `OR` (Wk 8-9); flags / `CMP` (Wk 8-9)

Asks (Y/N). `OR al,20h` turns 'Y' into 'y' (bit 5 is the lowercase bit), then `CMP` sets the Zero flag if the answer is yes. The caller simply uses `JE`.

```asm
AskYesNo PROC USES eax edx
; Prints (Y/N) and waits. Returns ZF = 1 when the answer is Y or y.
    mov  edx, OFFSET pYesNo
    call WriteString
    call GetKey
    call WriteChar
    call Crlf
    or   al, 20h                    ; make it lowercase (Boolean OR)
    cmp  al, 'y'
    ret
AskYesNo ENDP
```

### `PressAnyKey`

**Course concepts:** Procedures (Wk 7)

Prints a yellow *Press any key to continue...* and waits.

```asm
PressAnyKey PROC USES eax
    call Crlf
    INVOKE ShowMsg, yellow, ADDR pressKey, NO_NUM
    call GetKey
    ret
PressAnyKey ENDP
```

### `GetNamePtr`

**Course concepts:** Two-dimensional arrays, row-major order (Wk 13); multiplication `IMUL` (Wk 10)

Names are stored in a 2-D byte array `accName[20][24]`. The address of row *i* is `accName + i * NAME_LEN`; this procedure returns it in EDX.

```asm
GetNamePtr PROC
; Returns EDX = address of the name of account ESI.
; Row-major 2-D array: address = accName + row * NAME_LEN
    mov  edx, esi
    imul edx, NAME_LEN
    add  edx, OFFSET accName
    ret
GetNamePtr ENDP
```

## Input validation

### `ReadNumber`

**Course concepts:** Strings (Wk 13); character arithmetic (Wk 3, 4); multiplication (Wk 10); `CLC/STC` and the Carry flag (Wk 8-9); loops (Wk 5)

**The one reusable validation routine.** Reads a line as text and checks every character. Each char has '0' subtracted; if the result is above 9 (unsigned compare) the char was not a digit. The number is built as `value = value*10 + digit`. Empty input, letters/symbols and more than 9 digits each get their own red message. Returns CF = 0 and the value in EAX, or CF = 1 on error.

```asm
ReadNumber PROC USES ebx ecx edx esi
; Reads a line and converts it to a number. Rejects empty input,
; letters / symbols and numbers longer than 9 digits.
; Returns EAX = value and CF = 0, or shows a red error and CF = 1.
    mov  edx, OFFSET inBuf
    mov  ecx, SIZEOF inBuf
    call ReadString                 ; EAX = characters typed
    mov  ecx, eax
    mov  edx, OFFSET eEmpty
    cmp  ecx, 0
    je   RnBad
    mov  edx, OFFSET eTooLong
    cmp  ecx, 9
    ja   RnBad
    mov  edx, OFFSET eDigits
    mov  esi, OFFSET inBuf
    mov  eax, 0
RnLoop:
    movzx ebx, BYTE PTR [esi]
    sub  bl, '0'                    ; '0'..'9' -> 0..9
    cmp  bl, 9
    ja   RnBad                      ; anything else is above 9 (unsigned)
    imul eax, 10                    ; value = value * 10 + digit
    add  eax, ebx
    inc  esi
    loop RnLoop
    clc
    ret
RnBad:
    INVOKE ShowMsg, lightRed, edx, NO_NUM
    stc
    ret
ReadNumber ENDP
```

### `AskRange`

**Course concepts:** Parameters (Wk 11); unsigned comparisons `JB/JBE` (Wk 8-9); conditional loop (Wk 8-9)

Keeps asking until the user types a valid number between `minV` and `maxV`, so wrong input never crashes the program - the user just gets a red message and another try.

```asm
AskRange PROC, pText:PTR BYTE, minV:DWORD, maxV:DWORD
; Keeps asking until a number from minV to maxV is typed. Returns EAX.
ArAsk:
    INVOKE Prompt, pText
    call ReadNumber
    jc   ArAsk                      ; not a valid number: ask again
    cmp  eax, minV
    jb   ArBad
    cmp  eax, maxV
    jbe  ArOk
ArBad:
    INVOKE ShowMsg, lightRed, ADDR eRange, NO_NUM
    jmp  ArAsk
ArOk:
    ret
AskRange ENDP
```

### `FindAccount`

**Course concepts:** String primitive `REPNE SCASD` (Wk 13); `SHR` to divide by 4 (Wk 10); Carry flag (Wk 8-9)

Searches the `accNum` array for the account number in EAX using the string instruction `REPNE SCASD`. When it stops, EDI points one element past the match, so `(EDI - start - 4) / 4` is the index. With EAX = 0 it finds the first empty slot (used when creating an account).

```asm
FindAccount PROC USES ecx edi
; Searches accNum for the number in EAX using the REPNE SCASD string
; primitive (EAX = 0 finds an empty slot).
; Returns ESI = index and CF = 0, or CF = 1 when it is not there.
    mov  edi, OFFSET accNum
    mov  ecx, MAX_ACC
    cld
    repne scasd                     ; compare EAX with each DWORD
    stc                             ; (STC does not change ZF)
    jne  FaDone
    mov  esi, edi                   ; EDI is one element past the match
    sub  esi, OFFSET accNum + 4
    shr  esi, 2                     ; byte offset / 4 = index
    clc
FaDone:
    ret
FindAccount ENDP
```

### `AskAccount`

**Course concepts:** INVOKE (Wk 11); Carry flag as a return value (Wk 8-9)

Asks for an account number, validates it with `ReadNumber`, and finds it. Shows *No account found with this account number.* if it does not exist.

```asm
AskAccount PROC USES eax, pText:PTR BYTE
; Asks for an account number and finds it.
; Returns ESI = index, CF = 0; or shows an error and CF = 1.
    INVOKE Prompt, pText
    call ReadNumber
    jc   AaFail
    cmp  eax, 0                     ; 0 is never a real account
    je   AaNone
    call FindAccount
    jnc  AaOk
AaNone:
    INVOKE ShowMsg, lightRed, ADDR eNotFound, NO_NUM
AaFail:
    stc
AaOk:
    ret
AskAccount ENDP
```

## PIN security

### `ReadPin`

**Course concepts:** Loops and conditional jumps (Wk 5, 8-9); `IMUL` (Wk 10)

Masked PIN entry. Reads keys one at a time with `ReadChar` (which does not echo), prints `*` for every digit, ignores everything that is not a digit, and stops at Enter. Returns the value in EAX and the number of digits in ECX.

```asm
ReadPin PROC USES ebx edx
; Masked PIN entry: a '*' is shown for each digit, Enter finishes.
; Returns EAX = PIN value, ECX = number of digits typed.
    mov  ebx, 0
    mov  ecx, 0
RpKey:
    call ReadChar
    cmp  al, 13                     ; Enter key
    je   RpDone
    sub  al, '0'
    cmp  al, 9
    ja   RpKey                      ; ignore anything that is not a digit
    movzx edx, al
    imul ebx, 10
    add  ebx, edx
    inc  ecx
    mov  al, '*'
    call WriteChar
    jmp  RpKey
RpDone:
    call Crlf
    mov  eax, ebx
    ret
ReadPin ENDP
```

### `Scramble`

**Course concepts:** Boolean `XOR` (Wk 8-9); rotate `ROL` (Wk 10)

PINs are never stored as plain numbers. The PIN is XOR-ed with a key and rotated left 7 bits. To check a PIN we scramble what the user typed and compare the two scrambled values. (Coursework-level protection, not real encryption.)

```asm
Scramble PROC
; Scrambles the PIN in EAX so it is never stored as plain digits.
    xor  eax, PIN_KEY
    rol  eax, 7
    ret
Scramble ENDP
```

### `VerifyPin`

**Course concepts:** Stack parameters (Wk 11); counters and conditional jumps (Wk 8-9)

Gives 3 tries. Each wrong try shows *Incorrect PIN. Attempts left: N*. After the 3rd wrong PIN it shows a red message, **saves the data and exits the program** - for both customer and admin login. It only returns when the PIN (and its number of digits) is correct.

```asm
VerifyPin PROC USES eax ecx, pText:PTR BYTE, pinCode:DWORD, digits:DWORD
; Gives 3 tries to type the PIN (pinCode is the scrambled correct PIN).
; Returns only when the PIN is right; exits the program after 3 failures.
    mov  tries, 3
VpAsk:
    INVOKE Prompt, pText
    call ReadPin                    ; EAX = PIN, ECX = digits
    call Scramble
    cmp  ecx, digits
    jne  VpWrong
    cmp  eax, pinCode
    je   VpOk
VpWrong:
    dec  tries
    jz   VpLock
    INVOKE ShowMsg, lightRed, ADDR eWrongPin, tries
    jmp  VpAsk
VpLock:
    INVOKE ShowMsg, lightRed, ADDR eLockout, NO_NUM
    call SaveData
    call PressAnyKey
    exit
VpOk:
    ret
VerifyPin ENDP
```

## Accounts and login

### `CreateAccount`

**Course concepts:** Arrays (Wk 5); 2-D arrays (Wk 13); INVOKE (Wk 11); data transfer (Wk 4)

Finds an empty slot (bank full -> *Bank is full* message), reads the name straight into its row of the 2-D name array (spaces allowed, max 23 chars), asks for a 4-digit masked PIN, then the starting balance with the prompt *Minimum 500 balance required*. Gives the next unique account number (1001, 1002, ...) and records the opening deposit in the history.

```asm
CreateAccount PROC
    mov  eax, 0                     ; find an empty slot
    call FindAccount                ; ESI = free index
    jnc  CaName
    INVOKE ShowMsg, lightRed, ADDR eBankFull, NO_NUM
    ret
CaName:
    INVOKE Prompt, ADDR pName       ; ---- name (spaces allowed) ----
    call GetNamePtr                 ; read straight into the name row
    mov  ecx, NAME_LEN
    call ReadString                 ; keeps at most 23 characters
    cmp  eax, 0
    jne  CaPin
    INVOKE ShowMsg, lightRed, ADDR eEmpty, NO_NUM
    jmp  CaName
CaPin:
    INVOKE Prompt, ADDR pNewPin     ; ---- 4-digit PIN ----
    call ReadPin
    cmp  ecx, 4
    je   CaPinOk
    INVOKE ShowMsg, lightRed, ADDR ePinLen, NO_NUM
    jmp  CaPin
CaPinOk:
    call Scramble
    mov  accPin[esi*4], eax
    INVOKE AskRange, ADDR pOpenBal, MIN_OPEN, MAX_TXN   ; opening balance
    mov  accBal[esi*4], eax
    mov  histCnt[esi*4], 0
    mov  dailyWd[esi*4], 0
    mov  ebx, nextAccNo             ; unique account number
    mov  accNum[esi*4], ebx
    inc  nextAccNo
    inc  accCount
    INVOKE AddHistory, esi, T_DEP, eax, esi
    INVOKE ShowMsg, lightGreen, ADDR sCreated, ebx
    ret
CreateAccount ENDP
```

### `CustomerLogin`

**Course concepts:** Conditional processing (Wk 8-9); INVOKE (Wk 11)

Asks for the account number and the PIN (3 tries). If the account is frozen it shows *WARNING: Your account is FROZEN. Contact our helpline: 0300-1234567* and does not open it. Otherwise it runs the customer menu.

```asm
CustomerLogin PROC
    INVOKE AskAccount, ADDR pAccNo  ; ESI = account index
    jc   ClEnd
    mov  curIdx, esi
    INVOKE VerifyPin, ADDR pPin, accPin[esi*4], 4
    cmp  accStat[esi], 1            ; PIN is right; is it frozen?
    jne  ClOpen
    INVOKE ShowMsg, lightRed, ADDR eFrozen, NO_NUM
ClEnd:
    ret
ClOpen:
    INVOKE RunMenu, ADDR mnuCust, ADDR custProcs, 7
    ret
CustomerLogin ENDP
```

### `AdminLogin`

**Course concepts:** INVOKE (Wk 11)

Asks only for the admin PIN (12345, 5 digits, same 3-try lockout), then runs the centred admin panel.

```asm
AdminLogin PROC
    mov  eax, ADMIN_PIN
    call Scramble
    INVOKE VerifyPin, ADDR pAdminPin, eax, 5
    INVOKE RunMenu, ADDR mnuAdmin, ADDR adminProcs, 8
    ret
AdminLogin ENDP
```

## Customer operations

### `BalanceInquiry`

**Course concepts:** Indexed addressing `accBal[esi*4]` (Wk 4)

Shows holder name, account number, balance and status of the logged-in account.

```asm
BalanceInquiry PROC
; Shows holder, account number, balance and status. Sets ESI = curIdx.
    mov  esi, curIdx
    INVOKE NameLine, ADDR lHolder
    INVOKE InfoLine, ADDR lAccNo, accNum[esi*4]
    INVOKE InfoLine, ADDR lBalance, accBal[esi*4]
    INVOKE Prompt, ADDR lStatus
    call WriteStatus
    call Crlf
    ret
BalanceInquiry ENDP
```

### `Deposit`

**Course concepts:** Arithmetic `ADD` on memory (Wk 4); INVOKE (Wk 11)

Asks for an amount (1 - 1,000,000), adds it to the balance, records it in the history and prints a receipt.

```asm
Deposit PROC
    INVOKE AskRange, ADDR pAmount, 1, MAX_TXN   ; EAX = amount
    mov  esi, curIdx
    add  accBal[esi*4], eax
    INVOKE AddHistory, esi, T_DEP, eax, esi
    INVOKE Receipt, eax
    ret
Deposit ENDP
```

### `Withdraw`

**Course concepts:** Unsigned comparison `CMP/JBE` (Wk 8-9); `SUB` (Wk 4)

Refuses with *Not enough money to withdraw.* if the amount is more than the balance, and with a daily-limit message if today's total would pass Rs. 50,000 (it tells how much can still be withdrawn). Otherwise subtracts, records history and prints a receipt.

```asm
Withdraw PROC
    INVOKE AskRange, ADDR pAmount, 1, MAX_TXN   ; EAX = amount
    mov  esi, curIdx
    cmp  eax, accBal[esi*4]         ; enough money?
    jbe  WdDaily
    INVOKE ShowMsg, lightRed, ADDR eNoMoneyWd, NO_NUM
    ret
WdDaily:
    mov  ebx, dailyWd[esi*4]        ; daily limit not crossed?
    add  ebx, eax
    cmp  ebx, DAILY_LIMIT
    jbe  WdOk
    mov  ebx, DAILY_LIMIT           ; amount still allowed today
    sub  ebx, dailyWd[esi*4]
    INVOKE ShowMsg, lightRed, ADDR eDaily, ebx
    ret
WdOk:
    mov  dailyWd[esi*4], ebx
    sub  accBal[esi*4], eax
    INVOKE AddHistory, esi, T_WD, eax, esi
    INVOKE Receipt, eax
    ret
Withdraw ENDP
```

### `Transfer`

**Course concepts:** Conditional processing (Wk 8-9); INVOKE with register arguments (Wk 11)

Finds the receiver and checks: not your own account, receiver not frozen, enough money (*Not enough money to transfer.*). Shows the receiver's name, asks for confirmation (Y/N), then moves the money and adds a *sent* entry to the sender's history and a *received* entry to the receiver's.

```asm
Transfer PROC
    INVOKE AskAccount, ADDR pRecvNo ; ESI = receiver
    jc   TrEnd
    mov  edx, OFFSET eSelf
    cmp  esi, curIdx
    je   TrError
    mov  edx, OFFSET eRecvFrozen
    cmp  accStat[esi], 1
    je   TrError
    mov  ebx, esi                   ; EBX = receiver, ESI = sender
    INVOKE NameLine, ADDR lHolder
    INVOKE AskRange, ADDR pAmount, 1, MAX_TXN   ; EAX = amount
    mov  esi, curIdx
    mov  edx, OFFSET eNoMoneyTr
    cmp  eax, accBal[esi*4]
    ja   TrError
    INVOKE Prompt, ADDR lConfirmTr  ; "Confirm transfer of Rs. X (Y/N)"
    call WriteDec
    call AskYesNo
    je   TrDo
    mov  edx, OFFSET eCancel
TrError:
    INVOKE ShowMsg, lightRed, edx, NO_NUM
TrEnd:
    ret
TrDo:
    sub  accBal[esi*4], eax         ; sender pays
    add  accBal[ebx*4], eax         ; receiver gets the money
    INVOKE AddHistory, ebx, T_RECV, eax, esi
    INVOKE AddHistory, esi, T_SENT, eax, ebx
    INVOKE Receipt, eax
    ret
Transfer ENDP
```

### `AddHistory`

**Course concepts:** 2-D arrays of records (Wk 13); string primitive `REP MOVSB` (Wk 13); `IMUL` (Wk 10); `RandomRange`

Every account has a row of 5 history entries (40 bytes each: type, amount, transaction ID, other account number, other name). If the row is full, `REP MOVSB` shifts entries 1-4 down to 0-3, dropping the oldest. The new entry gets a random 6-digit transaction ID, and the other person's name is copied with `REP MOVSB`.

```asm
AddHistory PROC USES eax ebx ecx edx esi edi,
            idx:DWORD, tKind:DWORD, amount:DWORD, otherIdx:DWORD
; Adds a transaction to row idx of the history 2-D array with a random
; transaction ID. When the row already has 5 entries the oldest is dropped.
    mov  esi, idx
    mov  ebx, esi                   ; EBX = history + idx * ROW_SIZE
    imul ebx, ROW_SIZE
    add  ebx, OFFSET history
    cmp  histCnt[esi*4], HIST_MAX
    jb   AhRoom
    mov  edi, ebx                   ; row is full: move entries 1..4 to 0..3
    lea  esi, [ebx + H_SIZE]
    mov  ecx, (HIST_MAX - 1) * H_SIZE
    cld
    rep  movsb                      ; string primitive: copy bytes
    mov  esi, idx
    dec  histCnt[esi*4]
AhRoom:
    mov  eax, histCnt[esi*4]        ; EBX = address of the new entry
    imul eax, H_SIZE
    add  ebx, eax
    inc  histCnt[esi*4]
    mov  eax, tKind
    mov  [ebx + H_TYPE], eax
    mov  eax, amount
    mov  [ebx + H_AMT], eax
    mov  eax, 900000                ; random ID from 100000 to 999999
    call RandomRange
    add  eax, 100000
    mov  [ebx + H_TXN], eax
    mov  lastTxn, eax
    mov  esi, otherIdx              ; (deposit / withdraw pass their own)
    mov  eax, accNum[esi*4]         ; remember the other account
    mov  [ebx + H_ACC], eax
    call GetNamePtr
    mov  esi, edx
    lea  edi, [ebx + H_NAME]
    mov  ecx, NAME_LEN
    rep  movsb                      ; copy the other person's name
    ret
AddHistory ENDP
```

### `Receipt`

**Course concepts:** INVOKE (Wk 11)

Prints a small receipt: title, transaction ID, amount and new balance.

```asm
Receipt PROC USES esi, amount:DWORD
; Prints a small receipt for the last transaction.
    call Crlf
    INVOKE ShowMsg, lightGreen, ADDR tReceipt, NO_NUM
    INVOKE ShowMsg, green, ADDR dblLine, NO_NUM
    INVOKE InfoLine, ADDR lTxnId, lastTxn
    INVOKE InfoLine, ADDR lAmount, amount
    mov  esi, curIdx
    INVOKE InfoLine, ADDR lNewBal, accBal[esi*4]
    INVOKE ShowMsg, green, ADDR dblLine, NO_NUM
    INVOKE ShowMsg, lightGreen, ADDR lThanks, NO_NUM
    ret
Receipt ENDP
```

### `MiniStatement`

**Course concepts:** Lookup tables indexed by type (Wk 5); based addressing `[ebx + H_AMT]` (Wk 4, 14); loops (Wk 5)

Shows the last 5 transactions as sentences: *You deposited - Rs. 5000*, *You withdrew - Rs. 1000*, *You sent - Rs. 500 to Sara Ahmed - Account No. 1002*, *You received - Rs. 100 from Ali Khan - Account No. 1001*. The type (1..4) picks the sentence and its colour from tables.

```asm
MiniStatement PROC
; Prints the last 5 transactions of the logged-in account as sentences.
    call BalanceInquiry             ; account details, ESI = curIdx
    call Crlf
    mov  ecx, histCnt[esi*4]
    cmp  ecx, 0
    jne  MsHave
    INVOKE ShowMsg, yellow, ADDR eNoHist, NO_NUM
    ret
MsHave:
    mov  ebx, esi                   ; EBX = first entry of this row
    imul ebx, ROW_SIZE
    add  ebx, OFFSET history
MsLoop:                             ; ECX is not changed by the calls
    INVOKE InfoLine, ADDR lTxnId, DWORD PTR [ebx + H_TXN]
    INVOKE Prompt, ADDR mGap
    mov  esi, [ebx + H_TYPE]        ; type 1..4 picks message and colour
    mov  eax, stmtColor[esi*4 - 4]
    call SetTextColor
    mov  edx, stmtMsg[esi*4 - 4]
    call WriteString
    mov  eax, [ebx + H_AMT]
    call WriteDec
    cmp  esi, T_SENT
    jb   MsNext                     ; deposit / withdrawal: sentence ends
    mov  edx, stmtDir[esi*4 - 4]    ; " to " or " from "
    call WriteString                ; then "NAME - Account No. N"
    lea  edx, [ebx + H_NAME]
    call WriteString
    mov  edx, OFFSET mAccTxt
    call WriteString
    mov  eax, [ebx + H_ACC]
    call WriteDec
MsNext:
    call Crlf
    add  ebx, H_SIZE                ; next entry
    loop MsLoop
    ret
MiniStatement ENDP
```

## Financial calculators

### `Calculators`

**Course concepts:** Table-driven selection (Wk 8-9)

Runs the calculator sub-menu with `RunMenu`.

```asm
Calculators PROC
    INVOKE RunMenu, ADDR mnuCalc, ADDR calcProcs, 5
    ret
Calculators ENDP
```

### `AskCalcInputs`

**Course concepts:** INVOKE (Wk 11)

Reads amount, yearly rate (1-20 %) and years (1-20), returned in ESI, EBX and ECX.

```asm
AskCalcInputs PROC
; Reads the amount, yearly rate and years.
; Returns ESI = amount, EBX = rate, ECX = years.
    INVOKE AskRange, ADDR pAmount, 1, MAX_TXN
    mov  esi, eax
    INVOKE AskRange, ADDR pRate, 1, 20
    mov  ebx, eax
    INVOKE AskRange, ADDR pYears, 1, 20
    mov  ecx, eax
    ret
AskCalcInputs ENDP
```

### `InterestCalc`

**Course concepts:** INVOKE (Wk 11)

Calls the recursive `CompoundInt` and shows the final amount and the interest earned.

```asm
InterestCalc PROC
    call AskCalcInputs              ; ESI = amount, EBX = rate, ECX = years
    INVOKE CompoundInt, esi, ebx, ecx   ; EAX = final amount
    INVOKE InfoLine, ADDR lMaturity, eax
    sub  eax, esi
    INVOKE InfoLine, ADDR lEarned, eax
    ret
InterestCalc ENDP
```

### `CompoundInt`

**Course concepts:** **Recursion** and stack frames (Wk 11); `MUL/DIV` (Wk 10)

Compound interest, added once a year. Base case: 0 years left -> return the amount. Otherwise add this year's interest (`P * r / 100`) and call itself with one year less. Each call has its own stack frame holding its parameters.

```asm
CompoundInt PROC USES ebx edx, principal:DWORD, rate:DWORD, years:DWORD
; RECURSIVE compound interest (interest added once a year):
;   amount(P, r, 0) = P
;   amount(P, r, n) = amount(P + P*r/100, r, n-1)
    mov  eax, principal
    cmp  years, 0
    je   CiDone                     ; base case: no years left
    mul  rate                       ; EDX:EAX = P * r
    mov  ebx, 100
    div  ebx                        ; EAX = this year's interest
    add  eax, principal
    mov  ebx, years
    dec  ebx
    INVOKE CompoundInt, eax, rate, ebx  ; recursive call
CiDone:
    ret
CompoundInt ENDP
```

### `LoanCalc`

**Course concepts:** `MUL/DIV/IMUL` (Wk 10)

Simple-interest loan: interest = P x R x Y / 100, total = P + interest, monthly installment = total / (Y x 12).

```asm
LoanCalc PROC
; interest = P * R * Y / 100,  installment = (P + interest) / (Y * 12)
    call AskCalcInputs              ; ESI = P, EBX = R, ECX = Y
    mov  eax, esi
    mul  ebx
    mul  ecx                        ; EAX = P * R * Y
    mov  ebx, 100
    div  ebx                        ; EAX = total interest
    INVOKE InfoLine, ADDR lLoanInt, eax
    add  eax, esi                   ; EAX = total to pay back
    INVOKE InfoLine, ADDR lLoanTotal, eax
    imul ecx, 12                    ; ECX = number of months
    mov  edx, 0
    div  ecx
    INVOKE InfoLine, ADDR lMonthly, eax
    ret
LoanCalc ENDP
```

### `CurrencyCalc`

**Course concepts:** Lookup tables (Wk 5); `MUL` (Wk 10); symbolic constants (Wk 3)

Rates are fixed constants (USD = 280 PKR, SAR = 300 PKR); the user only types the amount. The menu option (3 or 4) selects the rate and its text from two tables.

```asm
CurrencyCalc PROC
; EAX = menu option (3 = USD, 4 = SAR). Rate and text come from tables.
    mov  ebx, rates[eax*4 - 12]     ; option 3 -> element 0
    INVOKE ShowMsg, yellow, rateTxt[eax*4 - 12], NO_NUM
    INVOKE AskRange, ADDR pAmount, 1, MAX_TXN
    mul  ebx                        ; EAX = amount * fixed rate
    INVOKE ShowMsg, lightGreen, ADDR lPkr, eax
    ret
CurrencyCalc ENDP
```

## Admin panel

### `BuildList`

**Course concepts:** Arrays and loops (Wk 5)

Collects the index of every used slot into `accList` and returns how many there are. View, Sort and the graph all work from this list.

```asm
BuildList PROC USES esi
; Copies the index of every used slot into accList. Returns ECX = count.
    mov  esi, 0
    mov  ecx, 0
BlLoop:
    cmp  accNum[esi*4], 0
    je   BlNext
    mov  accList[ecx*4], esi
    inc  ecx
BlNext:
    inc  esi
    cmp  esi, MAX_ACC
    jb   BlLoop
    ret
BuildList ENDP
```

### `PrintTable`

**Course concepts:** Loops (Wk 5); string length and padding (Wk 13)

Prints the accounts in `accList` as a centred table with columns **Acc No, Name, Status, Balance**. The name is padded with spaces to a fixed width so the columns line up even with spaces in names. Used by View, Search and Sort so all three look the same.

```asm
PrintTable PROC USES eax ecx edx esi edi
; Prints the ECX accounts listed in accList as a table:
;   Acc No | Name | Status | Balance
    cmp  ecx, 0
    jne  PtHave
    INVOKE ShowMsg, yellow, ADDR eNoAcc, NO_NUM
    ret
PtHave:
    INVOKE ShowMsg, green, ADDR tblLine, NO_NUM
    INVOKE ShowMsg, lightGreen, ADDR tblHead, NO_NUM
    INVOKE ShowMsg, green, ADDR tblLine, NO_NUM
    mov  edi, 0
PtRow:
    push ecx
    mov  esi, accList[edi*4]
    mov  ecx, TABLE_W
    call PrintMargin
    mov  eax, accNum[esi*4]
    call WriteDec
    mov  ecx, 5
    call PrintSpaces
    call GetNamePtr                 ; name, padded to 26 columns
    call WriteString
    call StrLength
    mov  ecx, 26
    sub  ecx, eax
    call PrintSpaces
    call WriteStatus
    mov  eax, accBal[esi*4]
    call WriteDec
    call Crlf
    inc  edi
    pop  ecx
    loop PtRow
    INVOKE ShowMsg, green, ADDR tblLine, NO_NUM
    ret
PrintTable ENDP
```

### `ViewAccounts`

**Course concepts:** Procedures (Wk 7)

Shows all accounts in the table and the total count.

```asm
ViewAccounts PROC
    call BuildList
    call PrintTable
    INVOKE ShowMsg, lightCyan, ADDR lTotalAcc, accCount
    ret
ViewAccounts ENDP
```

### `SearchAccount`

**Course concepts:** Procedures (Wk 7)

Finds one account by its number and shows it in the same table format, including Status.

```asm
SearchAccount PROC
; Finds one account by number and shows it in the same table format.
    INVOKE AskAccount, ADDR pAccNo
    jc   SaEnd
    mov  accList, esi
    mov  ecx, 1
    call PrintTable
SaEnd:
    ret
SearchAccount ENDP
```

### `SortAccounts`

**Course concepts:** Nested loops / **bubble sort** (Wk 5); `PUSH/POP` to save the outer counter (Wk 7)

Sorts by balance, highest first. Only the list of indexes is swapped - the real account arrays never move - then prints the same table.

```asm
SortAccounts PROC
; Bubble sort of accList by balance, highest first.
; Only the index list is sorted; the account arrays do not move.
    call BuildList                  ; ECX = n
    push ecx
    dec  ecx                        ; outer loop runs n - 1 times
    jle  SoPrint                    ; 0 or 1 account: already sorted
SoOuter:
    push ecx
    mov  esi, 0
SoInner:
    mov  eax, accList[esi*4]
    mov  ebx, accList[esi*4 + 4]
    mov  edx, accBal[eax*4]
    cmp  edx, accBal[ebx*4]
    jae  SoNext
    mov  accList[esi*4], ebx        ; swap the two indexes
    mov  accList[esi*4 + 4], eax
SoNext:
    inc  esi
    loop SoInner
    pop  ecx
    loop SoOuter
SoPrint:
    pop  ecx
    call PrintTable
    ret
SortAccounts ENDP
```

### `TotalDeposits`

**Course concepts:** **Extended addition `ADD` / `ADC`** (Wk 11)

Adds every balance into a 64-bit total held in EDX:EAX: `ADD` adds into the low part and `ADC edx,0` carries any overflow into the high part.

```asm
TotalDeposits PROC
; Adds all balances as a 64-bit number in EDX:EAX using ADD and ADC.
    mov  eax, 0                     ; low 32 bits
    mov  edx, 0                     ; high 32 bits
    mov  ecx, MAX_ACC
TdLoop:
    add  eax, accBal[ecx*4 - 4]     ; empty slots hold 0
    adc  edx, 0                     ; carry goes into the high part
    loop TdLoop
    INVOKE InfoLine, ADDR lTotalAcc, accCount
    INVOKE InfoLine, ADDR lTotalDep, eax   ; (high part is 0 for 20 accounts)
    ret
TotalDeposits ENDP
```

### `FreezeAccount`

**Course concepts:** Boolean `XOR` (Wk 8-9)

Toggles the status: `XOR accStat[esi],1` turns 0 into 1 (freeze) and 1 into 0 (unfreeze), then reports which happened.

```asm
FreezeAccount PROC
; Working -> Frozen, or Frozen -> Working.
    INVOKE AskAccount, ADDR pAccNo
    jc   FrEnd
    xor  accStat[esi], 1            ; flip 0 <-> 1 (Boolean XOR)
    mov  edx, OFFSET sFrozen
    cmp  accStat[esi], 1
    je   FrShow
    mov  edx, OFFSET sUnfrozen
FrShow:
    INVOKE ShowMsg, lightGreen, edx, accNum[esi*4]
FrEnd:
    ret
FreezeAccount ENDP
```

### `DeleteAccount`

**Course concepts:** Data transfer (Wk 4)

Shows whose account it is, then empties the slot (account number set to 0) so it can be reused.

```asm
DeleteAccount PROC
    INVOKE AskAccount, ADDR pAccNo
    jc   DaEnd
    INVOKE NameLine, ADDR lHolder   ; show whose account it was
    INVOKE ShowMsg, lightGreen, ADDR sDeleted, accNum[esi*4]
    mov  accNum[esi*4], 0           ; empty the slot
    mov  accBal[esi*4], 0
    mov  accStat[esi], 0
    dec  accCount
DaEnd:
    ret
DeleteAccount ENDP
```

### `BarGraph`

**Course concepts:** `MUL/DIV` for scaling (Wk 10); Boolean `AND` (Wk 8-9); loops (Wk 5)

Finds the highest balance, then draws one coloured bar per account: length = balance x 20 / highest (at least 1 block). `AND eax,3` + `lightGreen` rotates between 4 colours.

```asm
BarGraph PROC
; Bar length = balance * BAR_MAX / highest balance, in rotating colours.
    mov  ebx, 1                     ; EBX = highest balance (at least 1)
    mov  ecx, MAX_ACC               ; (empty slots hold 0, so including
BgMax:                              ;  them does not change the maximum)
    cmp  accBal[ecx*4 - 4], ebx
    jbe  BgMaxNext
    mov  ebx, accBal[ecx*4 - 4]
BgMaxNext:
    loop BgMax
    call BuildList                  ; ECX = number of accounts
    cmp  ecx, 0
    jne  BgHave
    INVOKE ShowMsg, yellow, ADDR eNoAcc, NO_NUM
    ret
BgHave:
    mov  edi, 0                     ; EDI = row number
BgRow:
    push ecx
    mov  esi, accList[edi*4]
    INVOKE Prompt, ADDR mGap        ; left margin
    mov  eax, edi                   ; colour 10..13 chosen by row number
    and  eax, 3
    add  eax, lightGreen
    call SetTextColor
    mov  eax, accBal[esi*4]
    mov  ecx, BAR_MAX
    mul  ecx
    div  ebx                        ; EAX = balance * BAR_MAX / highest
    lea  ecx, [eax + 1]             ; every bar has at least one block
    mov  al, 219
BgBlock:
    call WriteChar
    loop BgBlock
    mov  al, ' '                    ; then "NAME - Rs. BALANCE"
    call WriteChar
    call GetNamePtr
    call WriteString
    mov  edx, OFFSET mRs
    call WriteString
    mov  eax, accBal[esi*4]
    call WriteDec
    call Crlf
    inc  edi
    pop  ecx
    loop BgRow
    ret
BarGraph ENDP
```

## File handling

### `SaveData`

**Course concepts:** File handling basics (Wk 15); `OFFSET` operator arithmetic (Wk 5)

All account data sits in one block of memory between the labels `fileStart` and `fileEnd`. The block is written to `bankdata.dat` in one `WriteToFile` call; its size is `OFFSET fileEnd - OFFSET fileStart`.

```asm
SaveData PROC USES eax ebx ecx edx
; Writes the whole data block (fileStart .. fileEnd) to bankdata.dat.
    mov  edx, OFFSET fileName
    call CreateOutputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   SdFail
    mov  ebx, eax                   ; EBX = file handle
    mov  edx, OFFSET fileStart
    mov  ecx, OFFSET fileEnd - OFFSET fileStart
    call WriteToFile
    mov  eax, ebx
    call CloseFile
    INVOKE ShowMsg, lightGreen, ADDR sSaved, NO_NUM
    ret
SdFail:
    INVOKE ShowMsg, lightRed, ADDR eSaveFail, NO_NUM
    ret
SaveData ENDP
```

### `LoadData`

**Course concepts:** File handling basics (Wk 15)

At start-up, if `bankdata.dat` exists the same block is read back with `ReadFromFile`, so every account, PIN, status and history comes back exactly as it was.

```asm
LoadData PROC USES ebx
; Reads bankdata.dat back into the data block if the file exists.
    mov  edx, OFFSET fileName
    call OpenInputFile
    cmp  eax, INVALID_HANDLE_VALUE
    jne  LdRead
    INVOKE ShowMsg, lightCyan, ADDR sNoFile, NO_NUM
    ret
LdRead:
    mov  ebx, eax                   ; EBX = file handle
    mov  edx, OFFSET fileStart
    mov  ecx, OFFSET fileEnd - OFFSET fileStart
    call ReadFromFile
    mov  eax, ebx
    call CloseFile
    INVOKE ShowMsg, lightGreen, ADDR sLoaded, accCount
    ret
LoadData ENDP
```
