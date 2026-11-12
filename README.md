# HARA BHARA BANK - Bank Management System

EL-2003 COAL Lab project, written in x86 assembly (MASM) with the Irvine32 library.

| File | What it is |
|------|------------|
| `BankSystem.asm` | The whole program: 996 lines of code, not counting comments and blank lines |
| `FUNCTIONS.md` | A guide to every procedure: its code, the syllabus topic it uses, and a plain explanation |

## How to build and run (Visual Studio + Irvine32)

1. Open your usual Irvine32 project template, for example `Project32_VS2022` from Kip Irvine's site.
2. Replace the project's `.asm` file with `BankSystem.asm`, or add it to the project and remove the old one.
3. Build and run with **Ctrl+F5**.
4. When you choose **Exit**, the accounts are saved to `bankdata.dat` in the project folder. They are loaded again the next time the program starts.

The box and block characters need the normal Windows console code page (437), which is the default.

## Quick facts

* The admin PIN is **12345**. Customers set their own 4-digit PIN when they create an account.
* The bank holds at most 20 accounts. Account numbers start at 1001.
* After 3 wrong PINs the program saves the data and exits. This applies to customer and admin login.
* The helpline shown for frozen accounts is 0300-1234567.
* The daily withdrawal limit is Rs. 50,000 per account for each run of the program.
* Fixed exchange rates: 1 USD = 280 PKR, 1 SAR = 300 PKR.

## Testing

The program was assembled with UASM, a MASM-compatible assembler, and linked with the real `Irvine32.lib`: 0 errors and 0 warnings. It was then run under Wine with scripted keystrokes. These cases were tested:

* Splash screen, centred bank name and centred menus at 80 and 100 columns.
* Creating an account:
  * an empty name
  * a name with spaces
  * a PIN that is too short
  * a balance with letters
  * a balance below 500
  * a balance with more than 9 digits
  * a valid account
  * the 21st account (refused with "bank full")
* Customer login: a wrong PIN, then the correct PIN. Lockout and exit after 3 wrong PINs.
* Balance inquiry and deposit.
* Withdrawal: not enough money, over the daily limit, and a valid withdrawal.
* Transfer:
  * to your own account
  * to an account that does not exist
  * to a frozen account
  * cancelled with N
  * completed with Y
* Mini statement: deposit, withdrawal, sent and received lines, and the oldest entry dropping off after 5 transactions.
* Calculators: compound interest (10000 at 10% for 2 years gives 12100), loan, USD and SAR.
* Admin panel:
  * login, and lockout after 3 wrong PINs
  * view, search, sort, total deposits
  * freeze and unfreeze, with Frozen shown in the table
  * the warning shown when a frozen account logs in
  * delete
  * bar graph
* Data saved on exit and loaded again on the next start.

Note: under Wine, keys typed very quickly, or the same key twice in a row, are sometimes lost. Irvine's `ReadKey` empties the keyboard buffer after every key, and Wine reports a repeated key from a terminal as auto-repeat. Normal typing on Windows does not have this problem.
