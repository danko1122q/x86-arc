# x86-ARC — x86 32-bit Assembler & Runtime Core

x86-ARC is a self-hosted 32-bit x86 assembler & runtime core targeting Linux. Run 32-bit programs — requires QEMU for execution on non-x86 or 64-bit-only hosts. Produces ELF32 executables, ELF32 relocatable objects, DOS COM binaries, and raw flat binaries.

x86-ARC has its own syntax. See [`docs/syntax.md`](docs/syntax.md) for the full language reference and [`docs/macros.md`](docs/macros.md) for the macro system.

The assembler binary is named **`arc`**.

---

## Build

**Bootstrap** from `tas32` (included separately):

```sh
tas32 arc.s arc
chmod +x arc
```

**Self-hosted** once you have a working `arc` binary:

```sh
./arc arc.s arc
chmod +x arc
```

---

## Usage

```
arc <source> [output]
```

| Option | Description |
|--------|-------------|
| `-m <kb>` | Assembler working memory in kilobytes (default: 16384) |
| `-p <n>` | Maximum number of assembly passes |
| `-d NAME=value` | Define a numeric symbol on the command line |
| `-s <file>` | Write symbol table to file for debugging |
| `-i <path>` | Add directory to the include search path |

```sh
arc hello.s hello
arc -d DEBUG=1 prog.s prog
arc -m 65536 large.s large
arc -s prog.sym prog.s prog
```

---

## Output Formats

Declared with a `format` directive at the top of the source file.

| Directive | Output | Extension |
|-----------|--------|-----------|
| `format elf executable 3` | Linux ELF32 executable | *(none)* |
| `format elf` | ELF32 relocatable object | `.o` |
| `format binary` | Raw flat binary, no headers | `.bin` |
| `format com` | DOS COM binary (origin at 100h) | `.com` |

64-bit output is not supported.

---

## Hello World

```asm
format elf executable 3
entry _start

segment readable executable
_start:
    mov  eax, 4        ; sys_write
    mov  ebx, 1        ; stdout
    mov  ecx, msg
    mov  edx, msg_len
    trap 0x80
    mov  eax, 1        ; sys_exit
    xor  ebx, ebx
    trap 0x80

segment readable
msg     u8 'Hello, world!', 10
msg_len = $ - msg
```

```sh
arc hello.s hello && ./hello
```

---

## DOS COM

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

## ELF Object

```asm
format elf

section '.text' executable

public add_ints
add_ints:
    mov  eax, [esp+4]
    add  eax, [esp+8]
    ret
```

```sh
arc lib.s lib.o
ld -m elf_i386 -o prog main.o lib.o
```

---

## Syntax at a Glance

### Data

```asm
name   u8  'text', 13, 10, 0   ; bytes
value  u32 0xDEADBEEF           ; dword
table  u16 1, 2, 3, 4           ; word array

buf    rb 256                   ; reserve 256 bytes
nums   rd 16                    ; reserve 16 dwords
```

### Size overrides

```asm
mov  as_u8  [ptr], 7
mov  as_u32 [ptr], 0
movzx eax, as_u8 [ptr]
```

### Conditionals

```asm
cmp  eax, 0
if_less     .negative
if_equal    .zero
if_greater  .positive
```

### Macros

```asm
macro syscall nr, arg1, arg2, arg3 {
    mov eax, nr
    mov ebx, arg1
    mov ecx, arg2
    mov edx, arg3
    trap 0x80
}

syscall 4, 1, msg, msg_len    ; sys_write
syscall 1, 0, 0, 0            ; sys_exit
```

---

## Project Layout

```
arc.s                 main source (entry point, CLI, top-level flow)
core/
  platform32.s      shared macros and ABI conventions
  linux32.s         Linux syscall I/O layer
  scan.s            lexer / tokeniser
  expand.s          macro preprocessor
  tokens.s          token stream utilities
  emit.s            instruction encoder
  calc.s            constant expression evaluator
  output_fmt.s      output format writers (ELF, COFF, binary, COM)
  state.s           assembler state variables
  structs.s         keyword and mnemonic tables
  msgdata.s         error message strings
  fault.s           error reporting
  dump.s            symbol dump
  version.s             version constant
arch/
  x86.s             x86-32 instruction set
  vec.s             SSE/AVX vector instructions
docs/
  syntax.md         language reference
  macros.md         macro system reference
```
---

## Instruction Names

x86-ARC uses its own instruction names. These are the **native syntax** of the assembler — not aliases on top of another tool. For reference, the x86 mnemonic each name maps to is listed alongside.

### Quick reference

| x86-ARC | x86 mnemonic | Notes |
|---------|--------------|-------|
| `trap n` | `int n` | `trap 0x80` — Linux syscall |
| `no_op` | `nop` | |
| `halt` | `hlt` | Ring 0 |
| `return_from_interrupt` | `iret` | Ring 0 |
| `system_call` | `syscall` | |
| `create_frame size, nest` | `enter size, nest` | |
| `destroy_frame` | `leave` | |
| `byte_swap reg` | `bswap reg` | |
| `exchange_add dst, src` | `xadd dst, src` | |
| `compare_exchange dst, src` | `cmpxchg dst, src` | |
| `compare_exchange_8b mem` | `cmpxchg8b mem` | |
| `read_port dx` | `in al/ax/eax, dx` | Ring 0 / IOPL |
| `write_port dx` | `out dx, al/ax/eax` | Ring 0 / IOPL |
| `load_fence` | `lfence` | |
| `store_fence` | `sfence` | |
| `memory_fence` | `mfence` | |
| `cpu_info` | `cpuid` | |
| `read_timestamp` | `rdtsc` | |

All 28 conditional-move variants follow the pattern `move_if_<condition>`:

| x86-ARC | x86 mnemonic |
|---------|--------------|
| `move_if_equal` | `cmove` |
| `move_if_not_equal` | `cmovne` |
| `move_if_zero` | `cmovz` |
| `move_if_not_zero` | `cmovnz` |
| `move_if_above` | `cmova` |
| `move_if_below` | `cmovb` |
| `move_if_above_equal` | `cmovae` |
| `move_if_below_equal` | `cmovbe` |
| `move_if_carry` | `cmovc` |
| `move_if_not_carry` | `cmovnc` |
| `move_if_not_above` | `cmovna` |
| `move_if_not_below` | `cmovnb` |
| `move_if_not_above_equal` | `cmovnae` |
| `move_if_not_below_equal` | `cmovnbe` |
| `move_if_greater` | `cmovg` |
| `move_if_less` | `cmovl` |
| `move_if_greater_equal` | `cmovge` |
| `move_if_less_equal` | `cmovle` |
| `move_if_not_greater` | `cmovng` |
| `move_if_not_less` | `cmovnl` |
| `move_if_not_greater_equal` | `cmovnge` |
| `move_if_not_less_equal` | `cmovnle` |
| `move_if_overflow` | `cmovo` |
| `move_if_not_overflow` | `cmovno` |
| `move_if_sign` | `cmovs` |
| `move_if_not_sign` | `cmovns` |
| `move_if_parity` | `cmovp` |
| `move_if_not_parity` | `cmovnp` |


---

## License

x86-ARC is licensed under the **BSD 2-Clause License**.

Copyright (c) 2026 danko1122q. See the [`LICENSE`](LICENSE) file for the full terms.
