# x86-ARC Syntax Reference

---

## Table of Contents

1. [Format Directives](#1-format-directives)
2. [Segments and Sections](#2-segments-and-sections)
3. [Entry Point](#3-entry-point)
4. [Data Directives](#4-data-directives)
5. [Reserve Directives](#5-reserve-directives)
6. [Memory Size Overrides](#6-memory-size-overrides)
7. [Code Type: use16 and use32](#7-code-type-use16-and-use32)
8. [Numeric Literals](#8-numeric-literals)
9. [Operators](#9-operators)
10. [Position and Address Symbols](#10-position-and-address-symbols)
11. [Labels and Symbols](#11-labels-and-symbols)
12. [Conditional Jumps](#12-conditional-jumps)
13. [Unconditional Jump and Call](#13-unconditional-jump-and-call)
14. [Flag Instructions](#14-flag-instructions)
15. [Arithmetic Extensions](#15-arithmetic-extensions)
16. [Bit Operations](#16-bit-operations)
17. [Sign Extension](#17-sign-extension)
18. [String and Table Instructions](#18-string-and-table-instructions)
19. [Addressing Modes](#19-addressing-modes)
20. [Macros](#20-macros)
21. [Preprocessor Directives](#21-preprocessor-directives)
22. [CLI Options](#22-cli-options)
23. [Instruction Names](#23-instruction-names)

---

## 1. Format Directives

Every source file must begin with a `format` directive.

| Directive | Output | Default code type |
|-----------|--------|-------------------|
| `format elf executable 3` | Linux ELF32 executable | 32-bit |
| `format elf` | ELF32 relocatable object file (`.o`) | 32-bit |
| `format binary` | Raw flat binary, no headers (`.bin`) | **16-bit** |
| `format com` | DOS COM binary — origin fixed at 100h (`.com`) | **16-bit** |

`format binary` defaults to 16-bit mode. Use `use32` at the top of the file if you are targeting 32-bit code.

64-bit output (`elf64`) is not supported and will produce an error.

---

## 2. Segments and Sections

### ELF32 Executable (`format elf executable 3`)

Uses `segment`. All segments are implicitly readable.

```asm
segment readable executable    ; code  (r-x)
segment readable writeable     ; data  (rw-)
segment readable               ; rodata (r--)
```

### ELF32 Object (`format elf`)

Uses `section 'name'` with optional flags.

```asm
section '.text' executable
section '.data' writeable
section '.rodata'
section '.bss' writeable
```

### Section Flags

| Flag | ELF object | ELF executable |
|------|------------|----------------|
| `readable` | ❌ | ✅ (`segment` only) |
| `writeable` | ✅ | ✅ |
| `executable` | ✅ | ✅ |

### Flat Binary (`format binary`)

No segments. Code starts at the first byte of output.

```asm
format binary
    mov eax, 42
    ret
```

### COM Binary (`format com`)

No segments. Execution begins at offset 100h automatically.

```asm
format com
    mov  ah, 9
    mov  dx, msg
    int  21h
    mov  ax, 4C00h
    int  21h
msg u8 'Hello!', 13, 10, '$'
```

---

## 3. Entry Point

For ELF executables, specify an entry label explicitly:

```asm
format elf executable 3
entry my_start

segment readable executable
my_start:
    ; execution begins here
```

If omitted, execution begins at the first byte of the first segment.

---

## 4. Data Directives

`db`, `dw`, `dd`, `dq` do not exist in x86-ARC. Use typed directives:

| Directive | Size |
|-----------|------|
| `u8 val` | 1 byte |
| `u16 val` | 2 bytes |
| `u32 val` | 4 bytes |
| `u64 val` | 8 bytes |
| `u80 val` | 10 bytes (x87 extended precision) — supports `?`, integer literals, and float literals |
| `u128 val` | 16 bytes |
| `u256 val` | 32 bytes |
| `u512 val` | 64 bytes |

Uninitialized (zero-fill at link time): use `?` as the value.

Multiple values and strings are comma-separated on one line:

```asm
msg    u8  'Hello', 13, 10, 0
point  u32 100, 200
blank  u32 ?
```

---

## 5. Reserve Directives

Reserve uninitialized space. Place in a writeable segment or section.

| Directive | Reserves |
|-----------|----------|
| `rb n` | n bytes |
| `rw n` | n × 2 bytes |
| `rd n` | n × 4 bytes |
| `rq n` | n × 8 bytes |

```asm
segment readable writeable
buf  rb 64     ; 64-byte buffer
nums rd 16     ; 16 dwords
```

---

## 6. Memory Size Overrides

Use when the assembler cannot infer operand size from context.

| Override | Size |
|----------|------|
| `as_u8` | 1 byte |
| `as_u16` | 2 bytes |
| `as_u32` | 4 bytes |
| `as_u64` | 8 bytes |
| `as_u128` | 16 bytes |
| `as_u256` | 32 bytes |
| `as_u512` | 64 bytes |

```asm
mov  as_u8  [buf], 7
mov  as_u32 [ptr], 0
movzx eax, as_u8 [byte_var]
```

**Note:** `mov eax, [byte_var]` where `byte_var` is a `u8` label will error with a size mismatch. Use `movzx eax, as_u8 [byte_var]` or `mov al, [byte_var]` instead.

---

## 7. Code Type: use16 and use32

`use16` and `use32` switch the assembler between 16-bit and 32-bit code generation. They can appear anywhere in the source and take effect immediately from that point onward.

| Directive | Effect |
|-----------|--------|
| `use16` | Emit 16-bit instructions; 32-bit operands get a `0x66` prefix |
| `use32` | Emit 32-bit instructions; 16-bit operands get a `0x66` prefix |

The default code type depends on the format directive:

| Format | Default |
|--------|---------|
| `format binary` | 16-bit |
| `format com` | 16-bit |
| `format elf` | 32-bit |
| `format elf executable 3` | 32-bit |

### 32-bit flat binary

```asm
format binary
use32           ; override the 16-bit default

    mov eax, 1
    xor ebx, ebx
    trap 0x80
```

### 16-bit DOS COM

```asm
format com      ; implicitly use16 + org 100h

    mov  ah, 9
    mov  dx, msg
    int  21h
    mov  ax, 4C00h
    int  21h

msg u8 'Hello!', 13, 10, '$'
```

### Mixing 16-bit and 32-bit in one file

`use16` and `use32` can be interleaved to emit a mixed-mode binary, for example a real-mode stub followed by protected-mode code:

```asm
format binary

use16
    ; real-mode stub
    mov ax, 0x1234
    int 21h

use32
    ; protected-mode code
    mov eax, 1
    xor ebx, ebx
    trap 0x80
```

---

## 8. Numeric Literals

| Format | Example | Value |
|--------|---------|-------|
| Decimal | `255` | 255 |
| Hex (0x prefix) | `0xFF` | 255 |
| Hex (h suffix) | `0FFh` | 255 |
| Binary (b suffix) | `11111111b` | 255 |
| Octal (o suffix) | `0377o` | 255 |
| Character | `'A'` | 65 |

The `0b...` binary prefix is not valid. Use the `b` suffix: `11111111b`.

**Do not mix the two hex formats.** `0xFF` and `0FFh` are separate notations — the parser accepts each on its own but treats `0xFF80h` as an error (it reads `0xFF` as a complete literal, then sees `80h` as an unexpected suffix). Write `0xFF80` or `0FF80h`, never both prefixes and suffixes in the same token.

---

## 9. Operators

### Expression operators

Used in constant expressions, data definitions, and symbol assignments.

| Operator | Description |
|----------|-------------|
| `+` `-` `*` `/` | Arithmetic |
| `mod` | Modulo |
| `shl` `shr` | Bit shift |
| `and` `or` `xor` `not` | Bitwise |

```asm
FLAGS   = 1 shl 4
MASK    = 0xFF xor 0xF0
REMAIN  = 17 mod 5             ; 2
BOTH    = (0xF0 or 0x0F) and 0x55
```

### Comparison operators

`=` `<>` `<` `>` `<=` `>=` are **not** expression operators. They are only valid inside preprocessor conditional contexts: `if`, `else if`, `while`, `assert`, and `match`. Using them in a data definition or symbol assignment is an error.

```asm
; VALID — inside preprocessor conditional
if BUFSIZE > 4096
    ; large-buffer path
end if

assert BUFSIZE > 0

; INVALID — comparison is not an expression operator
SIZE = 4 > 2       ; error: trailing characters on line
u8 (5 = 5)         ; error: invalid argument
```

---

## 10. Position and Address Symbols

| Symbol | Meaning |
|--------|---------|
| `$` | Current address (next byte to emit) |
| `$$` | Start of current segment or section |
| `align n` | Pad with `0x90` (NOP) bytes to the next n-byte boundary |
| `times n stmt` | Emit `stmt` inline n times |
| `repeat n` / `end repeat` | Repeat a block n times |
| `%` | Current iteration index inside `repeat` (1-based) |
| `org addr` | Set assumed virtual load address |
| `__file__` | String — path of the file being assembled (preprocessor-time) |
| `__line__` | Number — line number of the current source line (preprocessor-time) |

```asm
msg     u8 'hello', 10
msg_len = $ - msg          ; 6

align 16

times 4 nop

repeat 8
  u32 %                    ; emits 1, 2, 3, 4, 5, 6, 7, 8
end repeat
```

---

## 11. Labels and Symbols

| Syntax | Description |
|--------|-------------|
| `label:` | Regular label — file-wide scope |
| `.local:` | Local label — scoped to the enclosing regular label |
| `@@:` | Anonymous label |
| `@b` | Reference to nearest previous `@@` |
| `@f` | Reference to nearest following `@@` |
| `local .name` | Unique label per macro invocation (inside macros only) |
| `NAME = value` | Numeric constant |
| `NAME equ tokens` | Token-level text substitution |
| `public name` | Export symbol (ELF object or ELF section) |
| `extrn name` | Declare external symbol (ELF object) |

```asm
BUFSIZE = 1024

loop_top:
  .retry:
    dec ecx
    if_not_zero .retry   ; local to loop_top:

@@:
  dec edx
  if_not_zero @b         ; back to @@
```

---

## 12. Conditional Jumps

| Mnemonic | Condition | Flags |
|----------|-----------|-------|
| `if_equal label` | Equal / zero | ZF=1 |
| `if_not_equal label` | Not equal / not zero | ZF=0 |
| `if_zero label` | Zero | ZF=1 |
| `if_not_zero label` | Not zero | ZF=0 |
| `if_above label` | Unsigned > | CF=0 and ZF=0 |
| `if_below label` | Unsigned < | CF=1 |
| `if_above_equal label` | Unsigned ≥ | CF=0 |
| `if_below_equal label` | Unsigned ≤ | CF=1 or ZF=1 |
| `if_greater label` | Signed > | ZF=0 and SF=OF |
| `if_less label` | Signed < | SF≠OF |
| `if_greater_equal label` | Signed ≥ | SF=OF |
| `if_less_equal label` | Signed ≤ | ZF=1 or SF≠OF |
| `if_carry label` | Carry set | CF=1 |
| `if_not_carry label` | Carry clear | CF=0 |
| `if_overflow label` | Overflow set | OF=1 |
| `if_not_overflow label` | Overflow clear | OF=0 |
| `if_sign label` | Negative result | SF=1 |
| `if_not_sign label` | Non-negative result | SF=0 |
| `if_parity label` | Parity even | PF=1 |
| `if_not_parity label` | Parity odd | PF=0 |

```asm
cmp eax, 0
if_less  .negative
if_equal .zero
; falls through to positive case
```

---

## 13. Unconditional Jump and Call

| Mnemonic | Description |
|----------|-------------|
| `jmp label` | Near jump (relative, ±2 GB) |
| `jmp short label` | Short jump (relative, −128 to +127 bytes) |
| `jmp reg` | Indirect jump via register |
| `jmp as_u32 [mem]` | Indirect jump via memory — size override required |
| `call label` | Near call |
| `call near as_u32 [mem]` | Indirect call via memory — size override required |
| `call reg` | Call via register |
| `ret` | Near return |
| `ret n` | Return and pop n bytes from stack |
| `loop label` | Decrement ECX, jump if ECX ≠ 0 |
| `loope label` | Decrement ECX, jump if ECX ≠ 0 and ZF=1 |
| `loopne label` | Decrement ECX, jump if ECX ≠ 0 and ZF=0 |

---

## 14. Flag Instructions

| Mnemonic | Description |
|----------|-------------|
| `set_carry` | Set carry flag (CF=1) |
| `clear_carry` | Clear carry flag (CF=0) |
| `complement_carry` | Flip carry flag |
| `set_direction` | DF=1 — string ops decrement |
| `clear_direction` | DF=0 — string ops increment (default) |
| `set_interrupt` | Enable hardware interrupts (IF=1) |
| `clear_interrupt` | Disable hardware interrupts (IF=0) |
| `push_flags` | Push EFLAGS onto stack |
| `pop_flags` | Pop EFLAGS from stack |
| `load_flags_to_ah` | Copy SF/ZF/AF/PF/CF into AH |
| `store_ah_to_flags` | Restore SF/ZF/AF/PF/CF from AH |

---

## 15. Arithmetic Extensions

| Mnemonic | Description |
|----------|-------------|
| `add_with_carry dst, src` | `dst = dst + src + CF` |
| `sub_with_borrow dst, src` | `dst = dst − src − CF` |
| `negate dst` | Two's complement negation |
| `signed_multiply dst, src` | Signed multiply (two-operand) |
| `signed_divide src` | Signed divide: EDX:EAX ÷ src |

```asm
; multiply
mov  eax, 6
mov  ecx, 7
signed_multiply eax, ecx    ; eax = 42

; divide 100 / 4
mov  eax, 100
sign_extend_dword           ; EDX:EAX = 100
mov  ecx, 4
signed_divide ecx           ; eax = 25, edx = 0

; negate
mov  eax, 10
negate eax                  ; eax = -10

; multi-precision add (64-bit)
mov  eax, [lo]
mov  edx, [hi]
add_with_carry eax, [other_lo]
add_with_carry edx, [other_hi]
```

---

## 16. Bit Operations

| Mnemonic | Description |
|----------|-------------|
| `bit_test dst, n` | CF ← bit n of dst |
| `bit_test_set dst, n` | CF ← bit n, then set that bit |
| `bit_test_reset dst, n` | CF ← bit n, then clear that bit |
| `bit_scan_forward dst, src` | dst = index of lowest set bit |
| `bit_scan_reverse dst, src` | dst = index of highest set bit |

```asm
mov  eax, 0x18
bit_test eax, 3
if_carry .bit3_set

bit_scan_forward  ecx, eax   ; ecx = 3
bit_scan_reverse  ecx, eax   ; ecx = 4
```

---

## 17. Sign Extension

Prepare EAX before `signed_divide`.

| Mnemonic | Operation |
|----------|-----------|
| `sign_extend_byte` | AL → AX |
| `sign_extend_word` | AX → EAX |
| `sign_extend_dword` | EAX → EDX:EAX |

```asm
mov  eax, -7
sign_extend_dword
mov  ecx, 2
signed_divide ecx           ; eax = -3
```

---

## 18. String and Table Instructions

Use the suffix form with `rep`. Direction is controlled by `clear_direction` (forward, default) and `set_direction` (backward).

| Mnemonic | Description |
|----------|-------------|
| `rep` | Repeat while ECX ≠ 0 |
| `repe` / `repz` | Repeat while ECX ≠ 0 and ZF=1 |
| `repne` / `repnz` | Repeat while ECX ≠ 0 and ZF=0 |
| `movsb` / `movsw` / `movsd` | Copy [ESI] → [EDI], advance both |
| `cmpsb` / `cmpsw` / `cmpsd` | Compare [ESI] with [EDI], advance both |
| `scasb` / `scasw` / `scasd` | Compare AL/AX/EAX with [EDI], advance EDI |
| `lodsb` / `lodsw` / `lodsd` | Load [ESI] → AL/AX/EAX, advance ESI |
| `stosb` / `stosw` / `stosd` | Store AL/AX/EAX → [EDI], advance EDI |
| `translate_byte [src]` | AL = [src + AL] — table lookup |

```asm
; copy 16 bytes
mov esi, src
mov edi, dst
mov ecx, 16
rep movsb

; zero-fill 32 dwords
mov edi, buf
xor eax, eax
mov ecx, 32
rep stosd

; scan for newline (max 256 bytes)
mov edi, str
mov al,  0x0A
mov ecx, 256
repne scasb           ; EDI points one past match

; table lookup
mov ebx, table
mov al, 3
translate_byte [ebx]  ; al = table[3]
```

---

## 19. Addressing Modes

| Mode | Example |
|------|---------|
| Register | `mov eax, ebx` |
| Immediate | `mov eax, 42` |
| Direct | `mov eax, [label]` |
| Register indirect | `mov eax, [ebx]` |
| Base + displacement | `mov eax, [ebx+8]` |
| Base + index | `mov eax, [ebx+ecx]` |
| Base + index × scale | `mov eax, [ebx+ecx*4]` |
| Base + index × scale + disp | `mov eax, [ebx+ecx*8+16]` |
| With size override | `mov as_u32 [ebx], 0` |

Valid scale values: `1`, `2`, `4`, `8`.

---

## 20. Macros

See [`docs/macros.md`](macros.md) for the complete macro reference.

### Simple macro

```asm
macro exit code {
    mov ebx, code
    mov eax, 1
    trap 0x80
}

exit 0
```

### Macro with local label

```asm
macro abs_val reg {
    local .skip
    test reg, reg
    if_not_sign .skip
    negate reg
    .skip:
}

abs_val eax
abs_val ebx
```

### Variadic macro

```asm
macro push_all [r] {
    forward push r
}
macro pop_all [r] {
    reverse pop r
}

push_all eax, ebx, ecx
pop_all  eax, ebx, ecx
```

---

## 21. Preprocessor Directives

### include

```asm
include 'core/linux32.s'
include 'lib/utils.s'
```

Search path is extended with `-i` on the command line.

### Conditional assembly

```asm
if BUFSIZE > 4096
    ; large buffer path
else
    ; small buffer path
end if
```

`if defined NAME` checks whether `NAME` has been defined as a numeric constant (via `=` assignment or `-d` on the CLI). It does **not** work with `define` variables — `define` creates a preprocessor accumulator, not a symbol that `defined` recognises.

```asm
; Works: symbol defined with '='
MY_CONST = 42
if defined MY_CONST
    ; included
end if

; Works: symbol defined via CLI flag
;   arc -d RELEASE=1 prog.s prog
if defined RELEASE
    ; strip debug info
end if

; Does NOT work: define variable is invisible to 'defined'
define DEBUG
if defined DEBUG   ; error: malformed expression
end if
```

### assert

Halts assembly with an error if the condition is false.

```asm
assert BUFSIZE > 0
assert $ - start < 512
```

### postpone

Queues a block to be executed **after the entire file has been preprocessed**. Useful when the body references labels or constants defined later in the file.

```asm
postpone {
    assert hdr_end - hdr_start = 16
}
```

See [`docs/macros.md` §18](macros.md#18-deferred-execution-postpone) for details.

### restore

Clears the value of an `equ` or `define` symbol, making it appear undefined. Accepts a comma-separated list of names. Does not affect `=` constants.

```asm
FOO equ hello
restore FOO        ; FOO is now undefined
```

### restruc

Alias for removing a `struc` definition. Equivalent to `purge` when applied to structures.

```asm
restruc point      ; removes the struc definition named point
```

---

## 22. CLI Options

```
arc <source> [output]
```

| Option | Description |
|--------|-------------|
| `-m <kb>` | Working memory limit in kilobytes (default: 16384) |
| `-p <n>` | Maximum assembly passes |
| `-d NAME=value` | Define a numeric symbol |
| `-s <file>` | Write symbol table to file |
| `-i <path>` | Add include search path |

```sh
arc prog.s prog
arc -d RELEASE=1 prog.s prog
arc -m 32768 bigprog.s bigprog
arc -i /usr/local/arc/include prog.s prog
```

Symbols defined with `-d NAME=value` are numeric constants and work with `if defined`:

```asm
; assembled with: arc -d RELEASE=1 prog.s prog
if defined RELEASE
    ; strip debug info
end if
```

---

## 23. Instruction Names

x86-ARC uses its own instruction names. These are native to the assembler — no include or declaration needed.

### System and control

| Mnemonic | Notes |
|----------|-------|
| `trap n` | `trap 0x80` for Linux syscalls |
| `no_op` | No operation |
| `halt` | Ring 0 |
| `return_from_interrupt` | Ring 0 |
| `system_call` | Fast system call |

```asm
; Linux sys_exit(0)
xor  eax, eax
mov  al,  1
xor  ebx, ebx
trap 0x80
```

### Stack frame

| Mnemonic | Description |
|----------|-----------|
| `create_frame size, nesting` | Create stack frame with local storage |
| `destroy_frame` | Restore stack and frame pointer |

```asm
my_func:
    create_frame 16, 0    ; allocate 16 bytes of locals
    ; ...
    destroy_frame
    ret
```

### Atomic and byte operations

| Mnemonic | Description |
|----------|-------------|
| `byte_swap reg` | Reverse byte order in a 32-bit register |
| `exchange_add dst, src` | Swap then add: `tmp=dst; dst+=src; src=tmp` |
| `compare_exchange dst, src` | CAS: if `eax==dst` → `dst=src`, else `eax=dst` |
| `compare_exchange_8b mem` | 64-bit CAS using EDX:EAX and ECX:EBX |

### I/O port

| Mnemonic | Notes |
|----------|-------|
| `read_port dx` | Read from I/O port into AL/AX/EAX — Ring 0 or IOPL |
| `write_port dx` | Write AL/AX/EAX to I/O port — Ring 0 or IOPL |

### Memory fence

| Mnemonic | Description |
|----------|-------------|
| `load_fence` | Serialize all loads before this point |
| `store_fence` | Serialize all stores before this point |
| `memory_fence` | Serialize all loads and stores |

### CPU utilities

| Mnemonic | Description |
|----------|-------------|
| `cpu_info` | CPU identification; input leaf in EAX |
| `read_timestamp` | Read Time Stamp Counter → EDX:EAX |

### Conditional move (`move_if_*`)

All 28 conditional move variants follow the `move_if_<condition>` pattern. The instruction moves `src` into `dst` only when the condition is true; flags are not modified.

**Unsigned / direct flag**

| Mnemonic | Condition |
|----------|----------|
| `move_if_equal dst, src` | ZF=1 |
| `move_if_not_equal dst, src` | ZF=0 |
| `move_if_zero dst, src` | ZF=1 |
| `move_if_not_zero dst, src` | ZF=0 |
| `move_if_above dst, src` | CF=0 and ZF=0 |
| `move_if_below dst, src` | CF=1 |
| `move_if_above_equal dst, src` | CF=0 |
| `move_if_below_equal dst, src` | CF=1 or ZF=1 |
| `move_if_carry dst, src` | CF=1 |
| `move_if_not_carry dst, src` | CF=0 |
| `move_if_not_above dst, src` | CF=1 or ZF=1 |
| `move_if_not_below dst, src` | CF=0 |
| `move_if_not_above_equal dst, src` | CF=1 |
| `move_if_not_below_equal dst, src` | CF=0 and ZF=0 |

**Signed**

| Mnemonic | Condition |
|----------|----------|
| `move_if_greater dst, src` | ZF=0 and SF=OF |
| `move_if_less dst, src` | SF≠OF |
| `move_if_greater_equal dst, src` | SF=OF |
| `move_if_less_equal dst, src` | ZF=1 or SF≠OF |
| `move_if_not_greater dst, src` | ZF=1 or SF≠OF |
| `move_if_not_less dst, src` | SF=OF |
| `move_if_not_greater_equal dst, src` | SF≠OF |
| `move_if_not_less_equal dst, src` | ZF=0 and SF=OF |

**Overflow / sign / parity**

| Mnemonic | Condition |
|----------|----------|
| `move_if_overflow dst, src` | OF=1 |
| `move_if_not_overflow dst, src` | OF=0 |
| `move_if_sign dst, src` | SF=1 |
| `move_if_not_sign dst, src` | SF=0 |
| `move_if_parity dst, src` | PF=1 |
| `move_if_not_parity dst, src` | PF=0 |

```asm
; Branchless abs(eax)
mov  ebx, eax
negate eax
move_if_not_sign eax, ebx    ; if eax was >= 0, restore original

; Branchless max(eax, ebx) → eax
cmp  eax, ebx
move_if_less eax, ebx
```
