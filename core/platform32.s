; SPDX-License-Identifier: BSD-2-Clause
; Copyright (c) 2026 danko1122q
; All rights reserved.

; asm platform32 .as
; Compatibility macros for pure 32-bit ELF build.
; Unlike platform .as (which runs core 32-bit code on x64 ELF64),
; this file targets a native 32-bit ELF binary.
; No use32/use64 bridging is needed: the whole binary IS 32-bit.

; No esp alias needed - we're genuinely 32-bit here
; No pushD/popD macros needed - push/pop work natively on 32-bit dwords

; The 'use32' macro below installs the same push/pop/jmp/call/salc/jcxz
; overrides that core code expects (they are identity mappings in real 32-bit mode)
macro use32
{
	; In a real 32-bit binary, push/pop/jmp/call/salc/jcxz work natively.
	; We define them as pass-throughs so the core source compiles unchanged.
	macro push args
	\{
		push args
	\}

	macro pop args
	\{
		pop args
	\}

	macro jmp arg
	\{
		jmp arg
	\}

	macro call arg
	\{
		call arg
	\}

	macro salc
	\{
		salc
	\}

	macro jcxz target
	\{
		jcxz target
	\}

	use32

}

macro use16
{
	purge push,pop,jmp,call,salc,jcxz
	use16
}

; Pointer-promotion helpers: no-ops in 32-bit mode (addressing is already 32-bit native)
macro promote_esi { }
macro promote_edi { }
macro promote_ebx { }
macro promote_ecx { }
macro promote_edx { }

use32

; ---- Field-update helpers (x86-ARC internal) ----
; update_field dst, src, dirty_reg
;   Writes src->dst, sets dirty_reg nonzero if value changed.
macro update_field dst, src, dirty {
    cmp   src, dst
    mov   dst, src
    setne dirty
}

; mark_dirty accumulator, test_reg
;   ORs test_reg into accumulator (ah).
macro mark_dirty acc, flag {
    or acc, flag
}

; sign_update field, new_sign, mask
;   XOR-updates a sign/flag byte field.
macro sign_update field, newsign, mask {
    mov   al, newsign
    xor   al, field
    and   al, mask
    or    ah, al
    xor   field, al
}
