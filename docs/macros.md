# x86-ARC Macro Reference

Complete reference for x86-ARC's macro system, from basic usage to advanced features.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Defining Macros](#2-defining-macros)
3. [Parameters](#3-parameters)
4. [Default Arguments](#4-default-arguments)
5. [Variadic Macros](#5-variadic-macros)
6. [Local Labels](#6-local-labels)
7. [Token Concatenation](#7-token-concatenation)
8. [Repetition: rept](#8-repetition-rept)
9. [Repetition: irp](#9-repetition-irp)
10. [Repetition: irps](#10-repetition-irps)
11. [Repetition: irpv](#11-repetition-irpv)
12. [Pattern Matching: match](#12-pattern-matching-match)
13. [Structures: struc](#13-structures-struc)
14. [Symbolic Constants: define](#14-symbolic-constants-define)
15. [Removing Macros: purge](#15-removing-macros-purge)
16. [Nested and Recursive Macros](#16-nested-and-recursive-macros)
17. [Complete Examples](#17-complete-examples)
18. [Deferred Execution: postpone](#18-deferred-execution-postpone)
19. [Clearing equ / define: restore and restruc](#19-clearing-equ--define-restore-and-restruc)
20. [Built-in Preprocessor Symbols: \_\_file\_\_ and \_\_line\_\_](#20-built-in-preprocessor-symbols-__file__-and-__line__)

---

## 1. Overview

Macros in x86-ARC are **text substitutions performed at the preprocessing phase**, before the assembler processes any instructions. When a macro is invoked, its body is expanded inline as if the programmer had typed it directly.

Preprocessing runs as a single full pass over the entire source. After that, the assembler runs its own (potentially multi-pass) resolution for labels and forward references.

**Key points:**

- Macro names are **case-insensitive**, just like instruction mnemonics.
- A macro may be invoked before it is defined. x86-ARC will postpone the expansion and resolve it at the end of preprocessing.
- Macros may call other macros (nested invocation).
- Macros are **not** inherently recursive-safe. Unbounded recursion will exhaust the assembler's memory.
- Macro expansion happens before expression evaluation, so parameters are token sequences, not computed values.

---

## 2. Defining Macros

```asm
macro name [param1, param2, ...] {
    ; macro body
}
```

The opening brace `{` may appear on the same line as `macro` or on the next line. The closing brace `}` must appear alone on its own line.

### Macro with no parameters

```asm
macro prologue {
    push ebp
    mov  ebp, esp
    sub  esp, 64
}

macro epilogue {
    mov  esp, ebp
    pop  ebp
    ret
}

my_func:
    prologue
    ; ... function body ...
    epilogue
```

### Macro with one parameter

```asm
macro sys_exit code {
    mov eax, 1
    mov ebx, code
    trap 0x80
}

sys_exit 0      ; exit success
sys_exit 255    ; exit with error code
```

### Macro with multiple parameters

```asm
macro write fd, buf, len {
    mov eax, 4
    mov ebx, fd
    mov ecx, buf
    mov edx, len
    trap 0x80
}

write 1, msg, msg_len    ; write to stdout
write 2, err, err_len    ; write to stderr
```

---

## 3. Parameters

Parameters are passed as **token sequences**, not as evaluated values. A single argument may be:

- A numeric literal: `42`, `0xFF`, `1010b`
- A register: `eax`, `ecx`
- A label or symbol: `msg`, `BUFSIZE`
- An expression: `eax+4`, `n*2`
- A string literal: `'hello'`
- A memory reference: `[ebp+8]`

```asm
macro load reg, mem {
    mov reg, [mem]
}

load eax, buf      ; expands to: mov eax, [buf]
load ecx, ebp+8    ; expands to: mov ecx, [ebp+8]
```

### Angle bracket grouping `< >`

If an argument contains commas or tokens that would be misread as argument separators, wrap it in `< >` to treat the entire contents as a single argument.

```asm
macro two a, b {
    u32 a
    u32 b
}

two 1, 2            ; a=1  b=2    fine
two <1, 2>, 3       ; a="1, 2"  b=3
```

This is also useful when passing a memory operand that contains arithmetic:

```asm
macro store dst, val {
    mov [dst], val
}

store <ebp-8>, eax    ; dst = "ebp-8" treated as one token group
```

---

## 4. Default Arguments

A parameter may have a default value using `:` or `=` after its name. If the caller omits that argument (leaves it blank), the default is used.

```asm
macro sys_write fd:1, buf, len {
    mov eax, 4
    mov ebx, fd
    mov ecx, buf
    mov edx, len
    trap 0x80
}

sys_write 1, msg, msg_len    ; fd = 1  (explicit)
sys_write  , msg, msg_len    ; fd = 1  (default)
```

Default values may be any valid token sequence. Use `< >` when the default contains spaces or commas:

```asm
macro clear reg:<eax> {
    xor reg, reg
}

clear          ; expands to: xor eax, eax
clear ecx      ; expands to: xor ecx, ecx
```

```asm
macro alloc size, align:4 {
    sub esp, size
    and esp, -align
}

alloc 64        ; align = 4  (default)
alloc 64, 16    ; align = 16
```

---

## 5. Variadic Macros

A **variadic** parameter accepts any number of arguments. Declare it with square brackets: `[name]`.

```asm
macro name [arg] {
    ; body
}
```

Inside a variadic macro body, three block keywords control iteration:

| Block | Executes |
|-------|----------|
| `common` | Once, before iterating over arguments |
| `forward` | Once per argument, left to right |
| `reverse` | Once per argument, right to left |

Blocks may be combined freely and in any order. Each block continues until the next block keyword or the closing `}`.

### Push and pop multiple registers

```asm
macro push_regs [r] {
    forward
        push r
}

macro pop_regs [r] {
    reverse
        pop r
}

push_regs eax, ebx, ecx
; expands to:
;   push eax
;   push ebx
;   push ecx

pop_regs eax, ebx, ecx
; expands to:
;   pop ecx
;   pop ebx
;   pop eax
```

### common + forward: initialise then iterate

```asm
macro sum_args [v] {
    common
        xor eax, eax
    forward
        add eax, v
}

sum_args 1, 2, 3, 4
; expands to:
;   xor eax, eax
;   add eax, 1
;   add eax, 2
;   add eax, 3
;   add eax, 4
```

### Mixing common, forward, and reverse

All three blocks may appear in the same macro. `common` typically handles setup and teardown, while `forward` and `reverse` handle per-argument work:

```asm
macro save_and_zero [r] {
    common
        ; save all regs first
    forward
        push r
    common
        ; now zero them all
    forward
        xor r, r
}
```

---

## 6. Local Labels

Labels defined inside a macro body with `.name:` are file-scoped — two invocations of the same macro will produce duplicate labels and cause an error.

Use the `local` directive to generate a **unique label per invocation**:

```asm
macro abs_val reg {
    local .skip
    test reg, reg
    if_not_sign .skip
    negate reg
    .skip:
}

abs_val eax    ; .skip becomes a unique internal name, e.g. .skip?00
abs_val ebx    ; .skip becomes a different unique name,  e.g. .skip?01
```

`local` must appear at the start of the macro body, before any instructions. Multiple local labels are declared in a comma-separated list:

```asm
macro clamp reg, lo, hi {
    local .below, .done
    cmp reg, lo
    if_greater_equal .below
    mov reg, lo
    jmp .done
    .below:
    cmp reg, hi
    if_less_equal .done
    mov reg, hi
    .done:
}
```

---

## 7. Token Concatenation

Inside a macro body, `#` concatenates adjacent tokens into a single identifier. This lets you build symbol names from parameters.

```asm
macro make_pair name {
    name#_lo u16 ?
    name#_hi u16 ?
}

make_pair val
; expands to:
;   val_lo u16 ?
;   val_hi u16 ?
```

Concatenation also works with string literals:

```asm
macro msg_entry tag, text {
    tag#_str  u8 text, 0
    tag#_len  = $ - tag#_str
}

msg_entry hello, 'Hello, world!'
; expands to:
;   hello_str  u8 'Hello, world!', 0
;   hello_len  = $ - hello_str
```

### Line continuation `\`

A backslash `\` at the end of a line **inside a macro body** joins it with the next line, allowing a long logical line to be split for readability. This only works within a `macro { }` body — it is **not** a general multi-statement separator and cannot be used to join arbitrary lines outside a macro.

```asm
macro long_mov dst, src {
    mov \
        dst, \
        src
}
```

---

## 8. Repetition: rept

`rept` repeats a block a fixed number of times. Two syntaxes are available:

- `rept n { }` — brace syntax, **top-level only** (cannot be used inside a macro body)
- `repeat n` / `end repeat` — block syntax, works everywhere including inside macro bodies

### Fixed repetition (top-level only)

```asm
rept 4 {
    nop
}
; expands to: nop nop nop nop
```

### Block form: repeat / end repeat

Use `repeat` / `end repeat` when inside a macro body, or when you need the iteration counter `%`:

```asm
repeat 5
    u32 %
end repeat
; emits dwords: 1, 2, 3, 4, 5
```

```asm
repeat 8
    u8 1 shl (% - 1)
end repeat
; emits bytes: 1, 2, 4, 8, 16, 32, 64, 128
```

### Generating a lookup table

```asm
repeat 256
    u8 (% - 1) xor 0x5A
end repeat
```

### rept inside a macro body

**`rept n { }` cannot be used inside a macro body.** The macro parser uses `{` / `}` as its own block delimiters, so the `}` that closes `rept` is consumed by the outer macro parser, causing an `unterminated macro` error. Always use `repeat` / `end repeat` inside macros:

```asm
; WRONG — the } closes the macro body, not rept:
macro zero_n n {
    rept n {
        u8 0
    }
}

; CORRECT:
macro zero_n n {
    repeat n
        u8 0
    end repeat
}
```

This is by design — the same behaviour as FASM 1, on which the macro system is based.

**Note:** `%` (the current iteration index) only works inside `repeat` / `end repeat`. Inside `rept { }`, `%` always evaluates to 0.

---

## 9. Repetition: irp

`irp` (Iterate over Repeat Parameters) repeats a block once for each item in a comma-separated list. The current item is bound to the named parameter.

```asm
irp name, arg1, arg2, arg3 {
    ; body — name = arg1, then arg2, then arg3
}
```

### Emit data for each value

```asm
irp val, 10, 20, 30, 40 {
    u32 val
}
; emits dwords: 10, 20, 30, 40
```

### Generate code for each register

```asm
irp reg, eax, ebx, ecx, edx {
    xor reg, reg
}
; expands to:
;   xor eax, eax
;   xor ebx, ebx
;   xor ecx, ecx
;   xor edx, edx
```

### irp with a default value

If the argument list is omitted, a default can be provided with `:`:

```asm
irp val:0, {
    u32 val     ; emits one dword = 0
}
```

---

## 10. Repetition: irps

`irps` (Iterate over Repeat String) iterates over the **characters** of a string or the tokens of a whitespace-separated list, one item per iteration.

```asm
irps name, "string" {
    ; name = one character at a time
}
```

### Emit each character as a byte

```asm
irps ch, "Hello" {
    u8 ch
}
; emits bytes: 'H', 'e', 'l', 'l', 'o'
```

### Iterate over a token list

`irps` also accepts a whitespace-separated list of single tokens:

```asm
irps reg, al bl cl dl {
    mov reg, 0
}
; expands to:
;   mov al, 0
;   mov bl, 0
;   mov cl, 0
;   mov dl, 0
```

---

## 11. Repetition: irpv

`irpv` (Iterate over Repeat Variable) iterates over a list built with `define`. The bound variable works as a normal token and can be used as a data value, instruction operand, or with the backtick stringify operator `` ` ``.

**Critical restriction:** `define name` (bare, without a value) must **not** be used as the first line. If the first entry in the list is an empty `define name`, irpv will fail with `invalid argument` for every use. Always start the list with a real value: `define name, firstvalue`.

### Emit data values

```asm
define vals, 10
define vals, 20
define vals, 30

irpv v, vals {
    u32 v
}
; emits dwords: 10, 20, 30
```

### Generate instructions

```asm
define regs, eax
define regs, ebx

irpv r, regs {
    xor r, r
}
; expands to: xor eax, eax  xor ebx, ebx
```

### Stringify with backtick `` ` ``

```asm
define names, alpha
define names, beta
define names, gamma

irpv n, names {
    u8 `n, 0      ; emits null-terminated string: "alpha\0", "beta\0", "gamma\0"
}
```

See [Section 14](#14-symbolic-constants-define) for how `define` variables work.

---

## 12. Pattern Matching: match

`match` tests whether a token sequence matches a pattern. If it does, free variables in the pattern are bound to the corresponding tokens and the body executes. If it does not match, the body is skipped entirely.

```asm
match pattern, tokens {
    ; executed only if tokens match pattern
}
```

### Literal match with `=`

A `=` prefix forces a token in the pattern to match literally (verbatim). Without `=`, a name in the pattern acts as a capture variable.

```asm
; match the exact token "nop"
match =nop, nop {
    u8 0x90    ; manually emit nop opcode
}
```

### Capturing variables

Without `=`, a name in the pattern captures whatever token appears in that position:

```asm
match first second, foo bar {
    ; first = foo
    ; second = bar
}
```

Multiple tokens can be captured with a trailing name that absorbs the rest:

```asm
match head tail, one two three four {
    ; head = one
    ; tail = "two three four"
}
```

### Using match inside macros for overloading

`match` inside a macro body lets you dispatch on what the argument looks like.

**Important:** all `match` blocks in a macro body evaluate **independently** — they are not a switch/case. A free-variable pattern such as `match num, v` is a catch-all that always succeeds, so it will fire even if an earlier specific pattern already matched. Only use a free-variable pattern when it is the only block, or when you are certain it will not conflict with literal patterns above it.

```asm
macro emit_val v {
    match =zero, v \{
        u32 0
    \}
    match =max, v \{
        u32 0xFFFFFFFF
    \}
}

emit_val zero    ; u32 0
emit_val max     ; u32 0xFFFFFFFF
; For a plain numeric value, call u32 directly — there is no safe catch-all here
; because a free-variable match would also fire for "zero" and "max".
```

### Checking if an argument equals a specific token

Use a literal pattern (`=token`) to fire only when the argument matches exactly. Because all `match` blocks are independent, avoid adding a free-variable fallback alongside a literal pattern — it would always fire and undo the conditional behaviour.

```asm
macro maybe_push reg, guard {
    match =go, guard \{
        push reg
    \}
}

maybe_push eax, go      ; push eax
maybe_push eax, skip    ; nothing emitted
```

### Escaping braces inside a macro body `\{ \}`

When `match` is nested inside a macro body, its braces must be escaped with `\` so the outer macro parser does not consume them:

```asm
macro try_42 val {
    match =42, val \{
        u8 'forty-two', 0
    \}
}

try_42 42     ; emits the string
try_42 99     ; emits nothing
```

---

## 13. Structures: struc

`struc` defines a **structure template** — a named macro that, when invoked, lays out a set of fields at the current position. It is the closest equivalent to a C `struct`.

```asm
struc name [params] {
    ; field definitions using . prefix
}
```

### Defining a structure

```asm
struc point {
    .x u32 ?
    .y u32 ?
}
```

Fields use a `.` prefix to become sub-labels of the instance name. The assembler sets `$` to the label at the invocation site, so `.x` becomes `label.x`.

### Instantiating a structure

```asm
p1 point
p2 point
```

This expands to:

```asm
p1:
    p1.x u32 ?
    p1.y u32 ?
p2:
    p2.x u32 ?
    p2.y u32 ?
```

Access fields by name:

```asm
mov eax, [p1.x]
mov [p2.y], ebx
```

### Structure with initial values

```asm
struc rect {
    .left  u32 0
    .top   u32 0
    .right u32 0
    .bot   u32 0
}

bounds rect
; bounds.left = 0, bounds.top = 0, bounds.right = 0, bounds.bot = 0
```

### Structure with parameters

```asm
struc vec3 x, y, z {
    .x u32 x
    .y u32 y
    .z u32 z
}

origin vec3 0, 0, 0
camera vec3 100, 200, 0
; camera.x = 100, camera.y = 200, camera.z = 0
```

### Nested structures

```asm
struc color {
    .r u8 ?
    .g u8 ?
    .b u8 ?
    .a u8 ?
}

struc sprite {
    .x    u32 ?
    .y    u32 ?
    .tint color
}

player sprite
; player.x, player.y, player.tint.r, player.tint.g, ...
```

### Computing structure size

```asm
struc header {
    .magic   u32 ?
    .version u16 ?
    .flags   u16 ?
    .size    u32 ?
}

hdr header
HEADER_SIZE = $ - hdr    ; = 12 bytes
```

### Overlaying a structure on existing memory (virtual)

To describe the layout of an existing buffer without allocating bytes, combine `struc` with `virtual at`:

```asm
struc tcp_header {
    .src_port  u16 ?
    .dst_port  u16 ?
    .seq       u32 ?
    .ack       u32 ?
    .flags     u16 ?
    .window    u16 ?
    .checksum  u16 ?
    .urgent    u16 ?
}

virtual at packet_buf
    pkt tcp_header
end virtual

; pkt.src_port, pkt.dst_port, etc. are now usable as address constants
mov ax, [pkt.src_port]
```

No bytes are emitted by the `virtual` block — it only defines the symbolic offsets.

---

## 14. Symbolic Constants: define

`define` creates a **preprocessor variable** — a symbol whose value is a token sequence that can be updated and accumulated over multiple assignments.

```asm
define name [, value]
```

Each `define name, token` **appends** a new value to the variable's list. Always start the list with a real value — a bare `define name` (no value) creates an empty first entry that breaks `irpv` for all uses.

### Note: not usable with `if defined`

**`if defined` does not recognise `define` variables** — it only works with numeric constants (`=` assignments and `-d` CLI flags). Using `if defined` on a `define` variable produces a `malformed expression` error.

```asm
; Does NOT work — define variable is invisible to 'defined'
define DEBUG
if defined DEBUG   ; error: malformed expression
end if

; Works — numeric constant recognised by 'defined'
DEBUG = 1
if defined DEBUG
    ; debug-only code
end if
```

### Accumulating a list

Start the list with a real value — do **not** open with a bare `define ports` (no value). An empty first entry breaks `irpv` for all uses.

```asm
define ports, 80
define ports, 443
define ports, 8080

irpv p, ports {
    u16 p
}
; emits words: 80, 443, 8080
```

### Comparison with other constant forms

| Directive | Type | Mutable | Multi-value |
|-----------|------|---------|-------------|
| `NAME = expr` | Numeric constant | No | No |
| `NAME equ tokens` | Token alias | No | No |
| `define NAME [, val]` | Preprocessor variable | Yes (append) | Yes |

---

## 15. Removing Macros: purge

`purge` undefines a macro, struc, or `define` variable, making the name available for redefinition or preventing further use.

```asm
purge name
```

### Removing a macro

```asm
macro greet {
    u8 'hello', 0
}

greet       ; expands normally

purge greet

greet       ; ERROR — greet is no longer defined
```

### Redefining a macro

To redefine a macro with a different body, `purge` the old definition first:

```asm
macro version {
    u8 '1.0', 0
}

purge version

macro version {
    u8 '2.0', 0
}
```

---

## 16. Nested and Recursive Macros

### Calling a macro from inside a macro

A macro body may invoke other macros freely. The inner macro must be defined by the time the outer macro is **expanded** (not necessarily before it is defined, since x86-ARC postpones expansion).

```asm
macro push_frame {
    prologue
    save_regs eax, ebx, ecx
}

macro prologue {
    push ebp
    mov  ebp, esp
}

macro save_regs [r] {
    forward push r
}

push_frame
; expands to:
;   push ebp
;   mov  ebp, esp
;   push eax
;   push ebx
;   push ecx
```

### Depth-limited recursion

x86-ARC has no built-in recursion limit. Recursion must be bounded by a conditional so it terminates:

```asm
macro emit_n val, n {
    if n > 0
        u32 val
        emit_n val, n-1
    end if
}

emit_n 0xFF, 4
; emits four dwords of 0xFF
```

> **Note:** Recursion works only for small depths, as each level consumes preprocessing memory. For repetition, prefer `rept`, `irp`, or `repeat` — they are more efficient and have no depth limit.

### Generating structured names with local + `#`

Combining `local` and `#` generates unique, structured identifiers per invocation:

```asm
macro entry name, val {
    local .lbl
    .lbl#_name  u8 `name, 0
    .lbl#_value u32 val
}

entry foo, 10
entry bar, 20
; .lbl?00_name / .lbl?00_value  (unique per invocation)
; .lbl?01_name / .lbl?01_value
```

---

## 17. Complete Examples

### 17.1 Linux syscall wrappers

```asm
format elf executable 3

macro sys_exit code {
    mov eax, 1
    mov ebx, code
    trap 0x80
}

macro sys_write fd, buf, len {
    mov eax, 4
    mov ebx, fd
    mov ecx, buf
    mov edx, len
    trap 0x80
}

macro sys_read fd, buf, len {
    mov eax, 3
    mov ebx, fd
    mov ecx, buf
    mov edx, len
    trap 0x80
}

segment readable executable

    sys_write 1, msg, msg_len
    sys_exit 0

segment readable

msg     u8 'Hello, world!', 10
msg_len = $ - msg
```

### 17.2 Type-safe memory access

```asm
macro load8  reg, mem { movzx reg, as_u8  [mem] }
macro load16 reg, mem { movzx reg, as_u16 [mem] }
macro load32 reg, mem { mov   reg, as_u32 [mem] }

macro store8  mem, val { mov as_u8  [mem], val }
macro store16 mem, val { mov as_u16 [mem], val }
macro store32 mem, val { mov as_u32 [mem], val }

load8  eax, byte_field
store32 dword_field, ebx
```

### 17.3 Ring buffer with struc

```asm
struc ring_buf {
    .data  rd 256
    .head  u32 0
    .tail  u32 0
    .count u32 0
}

rb ring_buf

macro rb_push buf, val {
    local .full
    cmp  [buf.count], 256
    if_equal .full
    mov  eax, [buf.tail]
    mov  [buf.data + eax*4], val
    inc  eax
    and  eax, 255
    mov  [buf.tail], eax
    inc  as_u32 [buf.count]
    .full:
}

macro rb_pop buf, dst {
    local .empty
    cmp  [buf.count], 0
    if_equal .empty
    mov  eax, [buf.head]
    mov  dst, [buf.data + eax*4]
    inc  eax
    and  eax, 255
    mov  [buf.head], eax
    dec  as_u32 [buf.count]
    .empty:
}
```

### 17.4 Dispatch table with irp or irpv

Both `irp` and `irpv` can build a dispatch table. Use `irp` when the list is fixed at write time; use `irpv` when the list is accumulated with `define` (remember: start the define list with a real value, not a bare `define name`).

```asm
; irp — fixed list
extrn handle_read
extrn handle_write
extrn handle_close

dispatch_table:
irp fn, handle_read, handle_write, handle_close {
    u32 fn
}
```

```asm
; irpv — accumulated list (no bare define name as first entry)
define handlers, handle_read
define handlers, handle_write
define handlers, handle_close

dispatch_table:
irpv fn, handlers {
    u32 fn
}
```

### 17.5 Argument overloading with match

`match` blocks fire independently, so a free-variable catch-all also fires for inputs that already matched an earlier literal pattern. For `mov_ex eax, mem buf`, both `match =mem addr` (correct) and `match reg` (capturing "mem buf" → error) would fire.

Safe overloading with `match` requires that only one block can structurally match a given input. The patterns below work because a two-token input (`=mem addr`, `=imm val`) cannot match the single-variable `match reg` pattern when there are exactly two tokens — but in x86-ARC a single free variable absorbs the entire remainder, so overlap is still possible for multi-token inputs.

The safest approach is to use disjoint sentinel keywords for every case and have no catch-all:

```asm
; mov_ex: keyword-prefixed dispatch — no catch-all, no overlap
macro mov_ex dst, src {
    match =mem addr, src \{
        mov dst, [addr]
    \}
    match =imm val, src \{
        mov dst, val
    \}
    match =reg r, src \{
        mov dst, r
    \}
}

mov_ex eax, mem buf    ; mov eax, [buf]
mov_ex eax, imm 42     ; mov eax, 42
mov_ex eax, reg ebx    ; mov eax, ebx
```

### 17.6 Counting arguments at assemble time

```asm
macro count_args [arg] {
    common
        ARG_COUNT = 0
    forward
        ARG_COUNT = ARG_COUNT + 1
}

count_args a, b, c, d, e
; ARG_COUNT = 5
```

### 17.7 String table builder

```asm
macro add_string name, text {
    name#_str u8 text, 0
    name#_len = $ - name#_str
}

add_string greet,     'Hello'
add_string farewell,  'Goodbye'
add_string error_msg, 'Error occurred'

; offset table — irp for a fixed list, or irpv for a define-accumulated list
string_table:
irp s, greet, farewell, error_msg {
    u32 s#_str
}
```

---

## Quick Reference

### Macro directives

| Directive | Description |
|-----------|-------------|
| `macro name params { }` | Define a named macro |
| `struc name params { }` | Define a structure template |
| `purge name` | Undefine a macro or struc |
| `restruc name` | Undefine a struc (alias for `purge` on strucs) |
| `postpone { }` | Define a block executed after full preprocessing |
| `restore name [, name2]` | Clear an `equ` or `define` variable |
| `local .a, .b` | Unique labels per invocation (inside macro only) |
| `define name [, val]` | Create or append to a preprocessor variable |

### Iteration directives

| Directive | Iterates over |
|-----------|---------------|
| `rept n { }` | Fixed repetition, **top-level only** — cannot be used inside macro bodies; `%` always 0 here |
| `repeat n` / `end repeat` | Block form; works everywhere including inside macros; `%` = current index (1-based) |
| `irp v, a, b, c { }` | Comma-separated token list |
| `irps v, "str" { }` | Characters of a string |
| `irpv v, var { }` | Entries of a `define` list; first entry must be a real value, not bare `define name` |

### Variadic block keywords

| Keyword | Runs |
|---------|------|
| `common` | Once, before all argument iterations |
| `forward` | Once per argument, left to right |
| `reverse` | Once per argument, right to left |

### match pattern syntax

| Pattern element | Matches |
|-----------------|---------|
| `=token` | Exactly the literal token |
| `name` | Any single token, captured as `name` |
| `head tail` | `head` = first token, `tail` = remainder |

### Special tokens inside macro bodies

| Token | Meaning |
|-------|---------|
| `%` | Current iteration index inside `repeat` / `end repeat` (1-based); always 0 inside `rept { }` — use `repeat`/`end repeat` when you need the counter |
| `#` | Concatenate adjacent tokens into one identifier |
| `\` (end of line) | Line continuation |
| `< >` | Group tokens as a single argument |
| `\{ \}` | Escaped braces for nested `match` inside a macro |

---

## 18. Deferred Execution: postpone

`postpone { }` defines a block that is **queued and executed after the entire source file has been preprocessed**, not at the point it appears. This is distinct from a regular macro invocation.

```asm
postpone {
    ; body
}
```

The body is stored when the directive is encountered. After preprocessing finishes, all queued `postpone` blocks run in the order they were defined.

### When to use

Use `postpone` when the body depends on labels or constants that are defined *later* in the file. A regular macro invoked inline would fail because forward references are not yet resolved at preprocessing time.

```asm
; runs after the entire file, when both labels exist.
postpone {
    assert hdr_end - hdr_start = 16
}

hdr_start:
    u32 0x7F454C46
    u32 0
    u32 0
    u32 0
hdr_end:
```

### Difference from macro

| | `macro` | `postpone` |
|--|---------|------------|
| Executed | at the call site | after full preprocessing |
| Can be called again | yes | no — runs once |
| Forward refs in body | may fail | safe |

---

## 19. Clearing equ / define: restore and restruc

### restore

`restore` clears the value of one or more `equ` or `define` symbols, making them appear undefined to subsequent preprocessing. It does **not** affect numeric constants defined with `=`.

```asm
restore name
restore name1, name2, name3
```

```asm
FOO equ hello
; ... FOO expands to hello here ...
restore FOO
; FOO is now undefined — using it is an error
```

**Difference from `purge`**: `purge` removes a `macro` or `struc`. `restore` clears `equ` / `define` variables. They are not interchangeable.

| Directive | Removes |
|-----------|---------|
| `purge name` | macro or struc |
| `restore name` | `equ` or `define` variable |

### restruc

`restruc` is an alias for removing a `struc` definition. It is equivalent to `purge` when applied to a structure, but the name makes the intent explicit.

```asm
restruc point
; point is no longer defined as a struc
```

---

## 20. Built-in Preprocessor Symbols: `__file__` and `__line__`

Two read-only symbols are available anywhere in source or macro bodies, accessed with the double-underscore prefix and suffix convention.

| Symbol | Expands to |
|--------|-----------|
| `__file__` | String literal — path of the current source file being processed |
| `__line__` | Numeric literal — line number of the current source line |

These expand during preprocessing, so they reflect the file and line *at the point of expansion*, not at the point of macro definition.

```asm
; Emit a null-terminated filename string
src_path u8 __file__, 0

; Include the line number in an assert message
assert stack_size > 0    ; if this fires, __line__ tells you where
```

### Inside macros

When used inside a macro body, `__file__` and `__line__` expand to the file and line of the **call site**, not the macro definition.

```asm
macro check_positive reg {
    cmp reg, 0
    if_less .fail
    jmp .ok
    .fail:
        ; __line__ here = line of the macro call
    .ok:
}
```

### Note on `__file__` type

`__file__` produces a quoted string token (like `'path/to/file.s'`), usable directly as an argument to `u8` to embed the filename in the binary.
