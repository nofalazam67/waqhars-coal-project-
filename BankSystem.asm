; ======================================================================
;  HARA BHARA BANK  -  Bank Management System
;  EL-2003 COAL Lab Project  (x86 Assembly, MASM + Irvine32)
; ----------------------------------------------------------------------
;  Customer : masked PIN login, balance, deposit, withdraw, transfer,
;             mini statement, interest / loan / currency calculators
;  Admin    : view, search, sort, total deposits, freeze / unfreeze,
;             delete, bar graph of balances
;  All accounts are saved to "bankdata.dat" on exit and loaded on start.
;  Colour theme (green): white = normal text, lightGreen = success and
;  titles, lightRed = errors, yellow = warnings, lightCyan = prompts.
; ======================================================================
INCLUDE Irvine32.inc
; ------------------- Symbolic constants (Week 3) ----------------------
MAX_ACC     = 20                ; maximum number of accounts
NAME_LEN    = 24                ; bytes per name (23 letters + null)
HIST_MAX    = 5                 ; transactions remembered per account
H_SIZE      = 40                ; bytes in one history entry:
H_TYPE      = 0                 ;   +0  type (1..4)
H_AMT       = 4                 ;   +4  amount
H_TXN       = 8                 ;   +8  transaction ID
H_ACC       = 12                ;   +12 other account number
H_NAME      = 16                ;   +16 other account name (24 bytes)
ROW_SIZE    = HIST_MAX * H_SIZE ; history bytes per account (200)
T_DEP       = 1                 ; transaction types
T_WD        = 2
T_SENT      = 3
T_RECV      = 4
MIN_OPEN    = 500               ; minimum opening balance
MAX_TXN     = 1000000           ; biggest amount in one transaction
DAILY_LIMIT = 50000             ; withdrawal limit per day (per run)
ADMIN_PIN   = 12345
PIN_KEY     = 5A5Ah             ; key used to scramble PINs
USD_RATE    = 280
SAR_RATE    = 300
TABLE_W     = 58                ; width of the accounts table
BAR_MAX     = 20                ; longest bar of the bar graph
BANNER      = white + (green * 16)  ; white text on green background
NO_NUM      = -1                ; ShowMsg: no number after the text
; ------------------- Prototypes for INVOKE (Week 11) ------------------
ShowMsg     PROTO, color:DWORD, pText:PTR BYTE, number:DWORD
Prompt      PROTO, pText:PTR BYTE
InfoLine    PROTO, pText:PTR BYTE, number:DWORD
NameLine    PROTO, pText:PTR BYTE
AskRange    PROTO, pText:PTR BYTE, minV:DWORD, maxV:DWORD
AskAccount  PROTO, pText:PTR BYTE
VerifyPin   PROTO, pText:PTR BYTE, pinCode:DWORD, digits:DWORD
RunMenu     PROTO, pMenu:PTR BYTE, pProcs:PTR DWORD, nOpts:DWORD
Receipt     PROTO, amount:DWORD
CompoundInt PROTO, principal:DWORD, rate:DWORD, years:DWORD
AddHistory  PROTO, idx:DWORD, tKind:DWORD, amount:DWORD, otherIdx:DWORD

.data
; ====== everything from fileStart to fileEnd is saved in the file ======
fileStart   LABEL BYTE
accCount    DWORD 0                         ; accounts in use
nextAccNo   DWORD 1001                      ; next account number to give
accNum      DWORD MAX_ACC DUP(0)            ; 0 = empty slot
accPin      DWORD MAX_ACC DUP(0)            ; scrambled PINs
accBal      DWORD MAX_ACC DUP(0)            ; balances
accStat     BYTE  MAX_ACC DUP(0)            ; 0 = Working, 1 = Frozen
accName     BYTE  MAX_ACC * NAME_LEN DUP(0) ; 2-D array [20][24]
histCnt     DWORD MAX_ACC DUP(0)            ; entries used in each row
history     BYTE  MAX_ACC * ROW_SIZE DUP(0) ; 2-D array [20][5 entries]
fileEnd     LABEL BYTE
; =======================================================================
dailyWd     DWORD MAX_ACC DUP(0)            ; withdrawn so far today
accList     DWORD MAX_ACC DUP(0)            ; list of indexes (view/sort)
curIdx      DWORD 0                         ; logged-in account
lastTxn     DWORD 0                         ; last transaction ID
tries       DWORD 0                         ; PIN attempts left
screenW     DWORD 80                        ; console width
leftPad     DWORD 19                        ; left margin of prompts
fileName    BYTE "bankdata.dat",0
inBuf       BYTE 81 DUP(0)
dblLine     BYTE 46 DUP(205), 0
tblLine     BYTE TABLE_W DUP(196), 0
tblHead     BYTE "Acc No   Name                      Status    Balance (Rs.)",0
logo        BYTE "##   ##   ######   ######  ",0
            BYTE "##   ##   ##   ##  ##   ## ",0
            BYTE "#######   ######   ######  ",0
            BYTE "##   ##   ##   ##  ##   ## ",0
            BYTE "##   ##   ######   ######  ",0,0
; ------ Menus: lines of text, ended by an empty string -----------------
mnuMain     BYTE 201, 40 DUP(205), 187, 0
            BYTE 186,"            *  MAIN MENU  *             ",186,0
            BYTE 204, 40 DUP(205), 185, 0
            BYTE 186,"   1. Customer Login                    ",186,0
            BYTE 186,"   2. Admin Login                       ",186,0
            BYTE 186,"   3. Create New Account                ",186,0
            BYTE 186,"   4. Exit                              ",186,0
            BYTE 200, 40 DUP(205), 188, 0, 0
mnuCust     BYTE 201, 40 DUP(205), 187, 0
            BYTE 186,"          *  CUSTOMER MENU  *           ",186,0
            BYTE 204, 40 DUP(205), 185, 0
            BYTE 186,"   1. Balance Inquiry                   ",186,0
            BYTE 186,"   2. Deposit Money                     ",186,0
            BYTE 186,"   3. Withdraw Money                    ",186,0
            BYTE 186,"   4. Transfer Money                    ",186,0
            BYTE 186,"   5. Mini Statement                    ",186,0
            BYTE 186,"   6. Financial Calculators             ",186,0
            BYTE 186,"   7. Logout                            ",186,0
            BYTE 200, 40 DUP(205), 188, 0, 0
mnuAdmin    BYTE 201, 40 DUP(205), 187, 0
            BYTE 186,"           *  ADMIN PANEL  *            ",186,0
            BYTE 204, 40 DUP(205), 185, 0
            BYTE 186,"   1. View All Accounts                 ",186,0
            BYTE 186,"   2. Search Account                    ",186,0
            BYTE 186,"   3. Sort Accounts by Balance          ",186,0
            BYTE 186,"   4. Total Deposits                    ",186,0
            BYTE 186,"   5. Freeze / Unfreeze Account         ",186,0
            BYTE 186,"   6. Delete Account                    ",186,0
            BYTE 186,"   7. Balance Bar Graph                 ",186,0
            BYTE 186,"   8. Logout                            ",186,0
            BYTE 200, 40 DUP(205), 188, 0, 0
mnuCalc     BYTE 201, 40 DUP(205), 187, 0
            BYTE 186,"      *  FINANCIAL CALCULATORS  *       ",186,0
            BYTE 204, 40 DUP(205), 185, 0
            BYTE 186,"   1. Compound Interest Calculator      ",186,0
            BYTE 186,"   2. Loan Calculator                   ",186,0
            BYTE 186,"   3. US Dollar (USD) to PKR            ",186,0
            BYTE 186,"   4. Saudi Riyal (SAR) to PKR          ",186,0
            BYTE 186,"   5. Back                              ",186,0
            BYTE 200, 40 DUP(205), 188, 0, 0
; ------ Table-driven selection: procedure address for each option ------
mainProcs   DWORD CustomerLogin, AdminLogin, CreateAccount
custProcs   DWORD BalanceInquiry, Deposit, Withdraw, Transfer, MiniStatement, Calculators
calcProcs   DWORD InterestCalc, LoanCalc, CurrencyCalc, CurrencyCalc
adminProcs  DWORD ViewAccounts, SearchAccount, SortAccounts, TotalDeposits
            DWORD FreezeAccount, DeleteAccount, BarGraph
stmtMsg     DWORD mDeposited, mWithdrew, mSent, mReceived   ; by type 1..4
stmtColor   DWORD lightGreen, yellow, yellow, lightGreen
stmtDir     DWORD 0, 0, mTo, mFrom
statText    DWORD stWorking, stFrozen                       ; by status 0..1
statColor   DWORD lightGreen, lightRed
rates       DWORD USD_RATE, SAR_RATE                       ; PKR per unit
rateTxt     DWORD lRateUsd, lRateSar
; ------------------------------ Text ----------------------------------
bankName    BYTE " HARA BHARA BANK ",0
tagLine     BYTE "Grow Your Savings, Green Your Future",0
loadingTxt  BYTE "Loading, please wait...",0
choiceTxt   BYTE "Press a number key: ",0
pressKey    BYTE "Press any key to continue...",0
pName       BYTE "Enter full name (max 23 characters): ",0
pNewPin     BYTE "Set a 4-digit PIN: ",0
pOpenBal    BYTE "Enter starting balance (Minimum 500 balance required): ",0
pAccNo      BYTE "Enter Account Number: ",0
pRecvNo     BYTE "Enter receiver's Account Number: ",0
pPin        BYTE "Enter 4-digit PIN: ",0
pAdminPin   BYTE "Enter Admin PIN: ",0
pAmount     BYTE "Enter amount (1 - 1000000): ",0
pRate       BYTE "Enter yearly interest rate in % (1 - 20): ",0
pYears      BYTE "Enter number of years (1 - 20): ",0
pYesNo      BYTE " (Y/N): ",0
eEmpty      BYTE "Input cannot be empty. Please type a value.",0
eDigits     BYTE "Only digits (0-9) are allowed. Letters/symbols are not accepted.",0
eTooLong    BYTE "Number is too long. Please enter at most 9 digits.",0
eRange      BYTE "Value is outside the allowed limit given in the question.",0
eChoice     BYTE "Invalid choice. Please press one of the numbers shown in the menu.",0
ePinLen     BYTE "PIN must be exactly 4 digits.",0
eBankFull   BYTE "Bank is full. Maximum 20 accounts are allowed.",0
eNotFound   BYTE "No account found with this account number.",0
eWrongPin   BYTE "Incorrect PIN. Attempts left: ",0
eLockout    BYTE "3 incorrect PIN attempts. For your security the program will now exit.",0
eFrozen     BYTE "WARNING: Your account is FROZEN. Contact our helpline: 0300-1234567",0
eNoMoneyWd  BYTE "Not enough money to withdraw.",0
eNoMoneyTr  BYTE "Not enough money to transfer.",0
eDaily      BYTE "Daily limit is Rs. 50000. You can withdraw only Rs. ",0
eSelf       BYTE "You cannot transfer money to your own account.",0
eRecvFrozen BYTE "Receiver's account is FROZEN. Transfer cannot be made.",0
eCancel     BYTE "Transfer cancelled. No money was moved.",0
eNoAcc      BYTE "There are no accounts in the bank yet.",0
eNoHist     BYTE "No transactions yet on this account.",0
eSaveFail   BYTE "ERROR: Could not save data to bankdata.dat.",0
sCreated    BYTE "Account created successfully! Your Account Number is: ",0
sFrozen     BYTE "Account is now FROZEN. Account No. ",0
sUnfrozen   BYTE "Account is now Working again. Account No. ",0
sDeleted    BYTE "Account deleted successfully. Account No. ",0
sSaved      BYTE "All accounts saved to bankdata.dat.",0
sLoaded     BYTE "Saved data loaded. Accounts found: ",0
sNoFile     BYTE "No saved data found. Starting with an empty bank.",0
sBye        BYTE "Thank you for banking with HARA BHARA BANK. Goodbye!",0
lHolder     BYTE "Account Holder : ",0
lAccNo      BYTE "Account Number : ",0
lBalance    BYTE "Current Balance: Rs. ",0
lStatus     BYTE "Account Status : ",0
lTxnId      BYTE "Transaction ID : ",0
lAmount     BYTE "Amount         : Rs. ",0
lNewBal     BYTE "New Balance    : Rs. ",0
lThanks     BYTE "Thank you for banking with us!",0
lTotalAcc   BYTE "Total accounts       : ",0
lTotalDep   BYTE "Total deposits (Rs.) : ",0
lMaturity   BYTE "Amount after interest: Rs. ",0
lEarned     BYTE "Interest earned      : Rs. ",0
lLoanInt    BYTE "Total interest       : Rs. ",0
lLoanTotal  BYTE "Total amount to pay  : Rs. ",0
lMonthly    BYTE "Monthly installment  : Rs. ",0
lRateUsd    BYTE "Fixed rate: 1 USD = 280 PKR",0
lRateSar    BYTE "Fixed rate: 1 SAR = 300 PKR",0
lPkr        BYTE "Converted amount: PKR ",0
lConfirmTr  BYTE "Confirm transfer of Rs. ",0
tReceipt    BYTE "TRANSACTION RECEIPT",0
stWorking   BYTE "Working   ",0
stFrozen    BYTE "Frozen    ",0
mGap        BYTE "  ",0
mRs         BYTE " - Rs. ",0
mDeposited  BYTE "You deposited - Rs. ",0
mWithdrew   BYTE "You withdrew - Rs. ",0
mSent       BYTE "You sent - Rs. ",0
mReceived   BYTE "You received - Rs. ",0
mTo         BYTE " to ",0
mFrom       BYTE " from ",0
mAccTxt     BYTE " - Account No. ",0

.code
; ======================================================================
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
; ----------------------------------------------------------------------
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
; ======================================================================
;                          SCREEN HELPERS
; ======================================================================
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
; ----------------------------------------------------------------------
PrintMargin PROC USES ecx
; Prints the spaces needed to centre text that is ECX characters long.
    neg  ecx
    add  ecx, screenW               ; ECX = screenW - length
    sar  ecx, 1                     ; half of it (shift right = divide by 2)
    call PrintSpaces
    ret
PrintMargin ENDP
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
InfoLine PROC USES eax, pText:PTR BYTE, number:DWORD
; Prints a label followed by a number, e.g. "Amount : Rs. 500".
    INVOKE Prompt, pText
    mov  eax, number
    call WriteDec
    call Crlf
    ret
InfoLine ENDP
; ----------------------------------------------------------------------
NameLine PROC USES edx, pText:PTR BYTE
; Prints a label followed by the name of account ESI.
    INVOKE Prompt, pText
    call GetNamePtr
    call WriteString
    call Crlf
    ret
NameLine ENDP
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
GetKey PROC
; Waits for a normal key (not Shift, arrows, ...) and returns it in AL.
GkWait:
    call ReadChar
    cmp  al, 0
    je   GkWait
    ret
GetKey ENDP
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
PressAnyKey PROC USES eax
    call Crlf
    INVOKE ShowMsg, yellow, ADDR pressKey, NO_NUM
    call GetKey
    ret
PressAnyKey ENDP
; ----------------------------------------------------------------------
GetNamePtr PROC
; Returns EDX = address of the name of account ESI.
; Row-major 2-D array: address = accName + row * NAME_LEN
    mov  edx, esi
    imul edx, NAME_LEN
    add  edx, OFFSET accName
    ret
GetNamePtr ENDP
; ======================================================================
;                 INPUT VALIDATION (one reusable routine)
; ======================================================================
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
Scramble PROC
; Scrambles the PIN in EAX so it is never stored as plain digits.
    xor  eax, PIN_KEY
    rol  eax, 7
    ret
Scramble ENDP
; ----------------------------------------------------------------------
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
; ======================================================================
;                     CREATE ACCOUNT AND LOGIN
; ======================================================================
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
AdminLogin PROC
    mov  eax, ADMIN_PIN
    call Scramble
    INVOKE VerifyPin, ADDR pAdminPin, eax, 5
    INVOKE RunMenu, ADDR mnuAdmin, ADDR adminProcs, 8
    ret
AdminLogin ENDP
; ======================================================================
;                        CUSTOMER OPERATIONS
; ======================================================================
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
; ----------------------------------------------------------------------
Deposit PROC
    INVOKE AskRange, ADDR pAmount, 1, MAX_TXN   ; EAX = amount
    mov  esi, curIdx
    add  accBal[esi*4], eax
    INVOKE AddHistory, esi, T_DEP, eax, esi
    INVOKE Receipt, eax
    ret
Deposit ENDP
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ======================================================================
;                       FINANCIAL CALCULATORS
; ======================================================================
Calculators PROC
    INVOKE RunMenu, ADDR mnuCalc, ADDR calcProcs, 5
    ret
Calculators ENDP
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
InterestCalc PROC
    call AskCalcInputs              ; ESI = amount, EBX = rate, ECX = years
    INVOKE CompoundInt, esi, ebx, ecx   ; EAX = final amount
    INVOKE InfoLine, ADDR lMaturity, eax
    sub  eax, esi
    INVOKE InfoLine, ADDR lEarned, eax
    ret
InterestCalc ENDP
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
CurrencyCalc PROC
; EAX = menu option (3 = USD, 4 = SAR). Rate and text come from tables.
    mov  ebx, rates[eax*4 - 12]     ; option 3 -> element 0
    INVOKE ShowMsg, yellow, rateTxt[eax*4 - 12], NO_NUM
    INVOKE AskRange, ADDR pAmount, 1, MAX_TXN
    mul  ebx                        ; EAX = amount * fixed rate
    INVOKE ShowMsg, lightGreen, ADDR lPkr, eax
    ret
CurrencyCalc ENDP
; ======================================================================
;                             ADMIN PANEL
; ======================================================================
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
ViewAccounts PROC
    call BuildList
    call PrintTable
    INVOKE ShowMsg, lightCyan, ADDR lTotalAcc, accCount
    ret
ViewAccounts ENDP
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ----------------------------------------------------------------------
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
; ======================================================================
;                       FILE HANDLING (save / load)
; ======================================================================
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
; ----------------------------------------------------------------------
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
END main
