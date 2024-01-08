; $Id: bs3-cmn-RegCtxSaveEx.asm $
;; @file
; BS3Kit - Bs3RegCtxSaveEx.
;

;
; Copyright (C) 2007-2022 Oracle and/or its affiliates.
;
; This file is part of VirtualBox base platform packages, as
; available from https://www.virtualbox.org.
;
; This program is free software; you can redistribute it and/or
; modify it under the terms of the GNU General Public License
; as published by the Free Software Foundation, in version 3 of the
; License.
;
; This program is distributed in the hope that it will be useful, but
; WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; if not, see <https://www.gnu.org/licenses>.
;
; The contents of this file may alternatively be used under the terms
; of the Common Development and Distribution License Version 1.0
; (CDDL), a copy of it is provided in the "COPYING.CDDL" file included
; in the VirtualBox distribution, in which case the provisions of the
; CDDL are applicable instead of those of the GPL.
;
; You may elect to license modified versions of this file under the
; terms and conditions of either the GPL or the CDDL or both.
;
; SPDX-License-Identifier: GPL-3.0-only OR CDDL-1.0
;

%include "bs3kit-template-header.mac"



;*********************************************************************************************************************************
;*  External Symbols                                                                                                             *
;*********************************************************************************************************************************
BS3_EXTERN_DATA16   g_bBs3CurrentMode
%if ARCH_BITS != 64
BS3_EXTERN_DATA16   g_uBs3CpuDetected
%endif

TMPL_BEGIN_TEXT
BS3_EXTERN_CMN      Bs3Panic
BS3_EXTERN_CMN      Bs3RegCtxSave
BS3_EXTERN_CMN      Bs3SwitchTo16Bit
%if TMPL_BITS != 64
BS3_EXTERN_CMN      Bs3SwitchTo16BitV86
%endif
%if TMPL_BITS != 32
BS3_EXTERN_CMN      Bs3SwitchTo32Bit
%endif
%if TMPL_BITS != 64
BS3_EXTERN_CMN      Bs3SwitchTo64Bit
%endif
%if TMPL_BITS == 16
BS3_EXTERN_CMN      Bs3SelRealModeDataToProtFar16
BS3_EXTERN_CMN      Bs3SelProtFar16DataToRealMode
BS3_EXTERN_CMN      Bs3SelRealModeDataToFlat
BS3_EXTERN_CMN      Bs3SelProtFar16DataToFlat
%else
BS3_EXTERN_CMN      Bs3SelFlatDataToProtFar16
%endif
%if TMPL_BITS == 32
BS3_EXTERN_CMN      Bs3SelFlatDataToRealMode
%endif

BS3_BEGIN_TEXT16
%if TMPL_BITS != 16
extern              _Bs3RegCtxSave_c16
extern              _Bs3SwitchTo%[TMPL_BITS]Bit_c16
%endif

BS3_BEGIN_TEXT32
%if TMPL_BITS != 32
extern              _Bs3RegCtxSave_c32
extern              _Bs3SwitchTo%[TMPL_BITS]Bit_c32
%endif
%if TMPL_BITS == 16
extern              _Bs3SwitchTo16BitV86_c32
%endif

BS3_BEGIN_TEXT64
%if TMPL_BITS != 64
extern              _Bs3RegCtxSave_c64
extern              _Bs3SwitchTo%[TMPL_BITS]Bit_c64
%endif

TMPL_BEGIN_TEXT



;;
; Saves the current register context.
;
; @param        pRegCtx
; @param        bBitMode     (8)
; @param        cbExtraStack (16)
; @uses         xAX, xDX, xCX
;
BS3_PROC_BEGIN_CMN Bs3RegCtxSaveEx, BS3_PBC_NEAR        ; Far stub generated by the makefile/bs3kit.h.
TONLY16 CPU 8086
        BS3_CALL_CONV_PROLOG 3
        push    xBP
        mov     xBP, xSP
%if ARCH_BITS == 64
        push    rcx                     ; Save pRegCtx
%endif

        ;
        ; Get the CPU bitcount part of the current mode.
        ;
        mov     dl, [BS3_DATA16_WRT(g_bBs3CurrentMode)]
        and     dl, BS3_MODE_CODE_MASK
%if TMPL_BITS == 16
        push    dx                          ; bp - 2: previous CPU mode (16-bit)
%endif

        ;
        ; Reserve extra stack space.  Make sure we've got 20h here in case we
        ; are saving a 64-bit context.
        ;
TONLY16 mov     ax, [xBP + xCB + cbCurRetAddr + sCB + xCB]
TNOT16  movzx   eax, word [xBP + xCB + cbCurRetAddr + sCB + xCB]
%ifdef BS3_STRICT
        cmp     xAX, 4096
        jb      .extra_stack_ok
        call    Bs3Panic
.extra_stack_ok:
%endif
        cmp     xAX, 20h
        jae     .at_least_20h_extra_stack
        add     xAX, 20h
.at_least_20h_extra_stack:
        sub     xSP, xAX

        ;
        ; Are we just saving the mode we're already in?
        ;
        mov     al, [xBP + xCB + cbCurRetAddr + sCB]
        and     al, BS3_MODE_CODE_MASK
        cmp     dl, al
        jne     .not_the_same_mode

%if TMPL_BITS == 16
        push    word [xBP + xCB + cbCurRetAddr + 2]
        push    word [xBP + xCB + cbCurRetAddr]
%elif TMPL_BITS == 32
        push    dword [xBP + xCB + cbCurRetAddr]
%endif
        call    Bs3RegCtxSave               ; 64-bit: rcx is untouched thus far.


        ;
        ; Return - no need to pop xAX and xDX as the last two
        ;          operations preserves all registers.
        ;
.return:
        mov     xSP, xBP
        pop     xBP
        BS3_CALL_CONV_EPILOG 3
        BS3_HYBRID_RET

        ;
        ; Turns out we have to do switch to a different bitcount before saving.
        ;
.not_the_same_mode:
        cmp     al, BS3_MODE_CODE_16
        je      .code_16

TONLY16 CPU 386
%if TMPL_BITS != 32
        cmp     al, BS3_MODE_CODE_32
        je      .code_32
%endif
%if TMPL_BITS != 64
        cmp     al, BS3_MODE_CODE_V86
        je      .code_v86
        cmp     al, BS3_MODE_CODE_64
        jne     .bad_input_mode
        jmp     .code_64
%endif

        ; Bad input (al=input, dl=current).
.bad_input_mode:
        call    Bs3Panic


        ;
        ; Save a 16-bit context.
        ;
        ; Convert pRegCtx to 16:16 protected mode and make sure we're in the
        ; 16-bit code segment.
        ;
.code_16:
%if TMPL_BITS == 16
 %ifdef BS3_STRICT
        cmp     dl, BS3_MODE_CODE_V86
        jne     .bad_input_mode
 %endif
        push    word [xBP + xCB + cbCurRetAddr + 2]
        push    word [xBP + xCB + cbCurRetAddr]
        call    Bs3SelRealModeDataToProtFar16
        add     sp, 4h
        push    dx                          ; Parameter #0 for _Bs3RegCtxSave_c16
        push    ax
%else
 %if TMPL_BITS == 32
        push    dword [xBP + xCB + cbCurRetAddr]
 %endif
        call    Bs3SelFlatDataToProtFar16   ; 64-bit: BS3_CALL not needed, ecx not touched thus far.
        mov     [xSP], eax                  ; Parameter #0 for _Bs3RegCtxSave_c16
        jmp     .code_16_safe_segment
        BS3_BEGIN_TEXT16
        BS3_SET_BITS TMPL_BITS
.code_16_safe_segment:
%endif
        call    Bs3SwitchTo16Bit
        BS3_SET_BITS 16

        call    _Bs3RegCtxSave_c16

%if TMPL_BITS == 16
        call    _Bs3SwitchTo16BitV86_c16
%else
        call    _Bs3SwitchTo%[TMPL_BITS]Bit_c16
%endif
        BS3_SET_BITS TMPL_BITS
        jmp     .supplement_and_return
        TMPL_BEGIN_TEXT

TONLY16 CPU 386


%if TMPL_BITS != 64
        ;
        ; Save a v8086 context.
        ;
.code_v86:
 %if TMPL_BITS == 16
  %ifdef BS3_STRICT
        cmp     dl, BS3_MODE_CODE_16
        jne     .bad_input_mode
  %endif
        push    word [xBP + xCB + cbCurRetAddr + 2]
        push    word [xBP + xCB + cbCurRetAddr]
        call    Bs3SelProtFar16DataToRealMode
        add     sp, 4h
        push    dx                          ; Parameter #0 for _Bs3RegCtxSave_c16
        push    ax
 %else
        push    dword [xBP + xCB + cbCurRetAddr]
        call    Bs3SelFlatDataToRealMode
        mov     [xSP], eax                  ; Parameter #0 for _Bs3RegCtxSave_c16
        jmp     .code_v86_safe_segment
        BS3_BEGIN_TEXT16
        BS3_SET_BITS TMPL_BITS
.code_v86_safe_segment:
 %endif
        call    Bs3SwitchTo16BitV86
        BS3_SET_BITS 16

        call    _Bs3RegCtxSave_c16

        call    _Bs3SwitchTo%[TMPL_BITS]Bit_c16
        BS3_SET_BITS TMPL_BITS
        jmp     .supplement_and_return
TMPL_BEGIN_TEXT
%endif


%if TMPL_BITS != 32
        ;
        ; Save a 32-bit context.
        ;
.code_32:
 %if TMPL_BITS == 16
        push    word [xBP + xCB + cbCurRetAddr + 2]
        push    word [xBP + xCB + cbCurRetAddr]
        test    dl, BS3_MODE_CODE_V86
        jnz     .code_32_from_v86
        call    Bs3SelProtFar16DataToFlat
        jmp     .code_32_flat_ptr
.code_32_from_v86:
        call    Bs3SelRealModeDataToFlat
.code_32_flat_ptr:
        add     sp, 4h
        push    dx                          ; Parameter #0 for _Bs3RegCtxSave_c32
        push    ax
 %else
        mov     [rsp], ecx                  ; Parameter #0 for _Bs3RegCtxSave_c16
 %endif
        call    Bs3SwitchTo32Bit
        BS3_SET_BITS 32

        call    _Bs3RegCtxSave_c32

 %if TMPL_BITS == 16
        cmp     byte [bp - 2], BS3_MODE_CODE_V86
        je      .code_32_back_to_v86
        call    _Bs3SwitchTo16Bit_c32
        BS3_SET_BITS TMPL_BITS
        jmp     .supplement_and_return
.code_32_back_to_v86:
        BS3_SET_BITS 32
        call    _Bs3SwitchTo16BitV86_c32
        BS3_SET_BITS TMPL_BITS
        jmp     .return
 %else
        call    _Bs3SwitchTo64Bit_c32
        BS3_SET_BITS TMPL_BITS
        jmp     .supplement_and_return
 %endif
%endif


%if TMPL_BITS != 64
        ;
        ; Save a 64-bit context.
        ;
        CPU     x86-64
.code_64:
 %if TMPL_BITS == 16
  %ifdef BS3_STRICT
        cmp     dl, BS3_MODE_CODE_16
        jne     .bad_input_mode
  %endif
        push    word [xBP + xCB + cbCurRetAddr + 2]
        push    word [xBP + xCB + cbCurRetAddr]
        call    Bs3SelProtFar16DataToFlat
        add     sp, 4h
        mov     cx, dx                      ; Parameter #0 for _Bs3RegCtxSave_c64
        shl     ecx, 16
        mov     cx, ax
 %else
        mov     ecx, [xBP + xCB + cbCurRetAddr] ; Parameter #0 for _Bs3RegCtxSave_c64
 %endif
        call    Bs3SwitchTo64Bit            ; (preserves all 32-bit GPRs)
        BS3_SET_BITS 64

        call    _Bs3RegCtxSave_c64          ; No BS3_CALL as rcx is already ready.

        call    _Bs3SwitchTo%[TMPL_BITS]Bit_c64
        BS3_SET_BITS TMPL_BITS
        jmp     .return
%endif


        ;
        ; Supplement the state out of the current context and then return.
        ;
.supplement_and_return:
%if ARCH_BITS == 16
        CPU 8086
        ; Skip 286 and older.  Also make 101% sure we not in real mode or v8086 mode.
        cmp     byte [BS3_DATA16_WRT(g_uBs3CpuDetected)], BS3CPU_80386
        jb      .return                 ; Just skip if 286 or older.
        test    byte [BS3_DATA16_WRT(g_bBs3CurrentMode)], BS3_MODE_CODE_V86
        jnz     .return
        cmp     byte [BS3_DATA16_WRT(g_bBs3CurrentMode)], BS3_MODE_RM
        jne     .return                 ; paranoia
        CPU 386
%endif

        ; Load the context pointer into a suitable register.
%if ARCH_BITS == 64
 %define pRegCtx rcx
        mov     rcx, [xBP - xCB]
%elif ARCH_BITS == 32
 %define pRegCtx ecx
        mov     ecx, [xBP + xCB + cbCurRetAddr]
%else
 %define pRegCtx es:bx
        push    es
        push    bx
        les     bx, [xBP + xCB + cbCurRetAddr]
%endif
%if ARCH_BITS == 64
        ; If we're in 64-bit mode we can capture and restore the high bits.
        test    byte [pRegCtx + BS3REGCTX.fbFlags], BS3REG_CTX_F_NO_AMD64
        jz      .supplemented_64bit_registers
        mov     [pRegCtx + BS3REGCTX.r8], r8
        mov     [pRegCtx + BS3REGCTX.r9], r9
        mov     [pRegCtx + BS3REGCTX.r10], r10
        mov     [pRegCtx + BS3REGCTX.r11], r11
        mov     [pRegCtx + BS3REGCTX.r12], r12
        mov     [pRegCtx + BS3REGCTX.r13], r13
        mov     [pRegCtx + BS3REGCTX.r14], r14
        mov     [pRegCtx + BS3REGCTX.r15], r15
        shr     rax, 32
        mov     [pRegCtx + BS3REGCTX.rax + 4], eax
        mov     rax, rbx
        shr     rax, 32
        mov     [pRegCtx + BS3REGCTX.rbx + 4], eax
        mov     rax, rcx
        shr     rax, 32
        mov     [pRegCtx + BS3REGCTX.rcx + 4], eax
        mov     rax, rdx
        shr     rax, 32
        mov     [pRegCtx + BS3REGCTX.rdx + 4], eax
        mov     rax, rsp
        shr     rax, 32
        mov     [pRegCtx + BS3REGCTX.rsp + 4], eax
        mov     rax, rbp
        shr     rax, 32
        mov     [pRegCtx + BS3REGCTX.rbp + 4], eax
        mov     rax, rsi
        shr     rax, 32
        mov     [pRegCtx + BS3REGCTX.rsi + 4], eax
        mov     rax, rdi
        shr     rax, 32
        mov     [pRegCtx + BS3REGCTX.rdi + 4], eax
        and     byte [pRegCtx + BS3REGCTX.fbFlags], ~BS3REG_CTX_F_NO_AMD64
.supplemented_64bit_registers:
%endif
        ; The rest requires ring-0 (at least during restore).
        mov     ax, ss
        test    ax, 3
        jnz     .done_supplementing

        ; Do control registers.
        test    byte [pRegCtx + BS3REGCTX.fbFlags], BS3REG_CTX_F_NO_CR2_CR3 | BS3REG_CTX_F_NO_CR0_IS_MSW | BS3REG_CTX_F_NO_CR4
        jz      .supplemented_control_registers
        mov     sAX, cr0
        mov     [pRegCtx + BS3REGCTX.cr0], sAX
        mov     sAX, cr2
        mov     [pRegCtx + BS3REGCTX.cr2], sAX
        mov     sAX, cr3
        mov     [pRegCtx + BS3REGCTX.cr3], sAX
        and     byte [pRegCtx + BS3REGCTX.fbFlags], ~(BS3REG_CTX_F_NO_CR2_CR3 | BS3REG_CTX_F_NO_CR0_IS_MSW)

%if ARCH_BITS != 64
        test    byte [1 + BS3_DATA16_WRT(g_uBs3CpuDetected)], (BS3CPU_F_CPUID >> 8)
        jz      .supplemented_control_registers
%endif
        mov     sAX, cr4
        mov     [pRegCtx + BS3REGCTX.cr4], sAX
        and     byte [pRegCtx + BS3REGCTX.fbFlags], ~BS3REG_CTX_F_NO_CR4
.supplemented_control_registers:

        ; Supply tr and ldtr if necessary
        test    byte [pRegCtx + BS3REGCTX.fbFlags], BS3REG_CTX_F_NO_TR_LDTR
        jz      .done_supplementing
        str     [pRegCtx + BS3REGCTX.tr]
        sldt    [pRegCtx + BS3REGCTX.ldtr]
        and     byte [pRegCtx + BS3REGCTX.fbFlags], ~BS3REG_CTX_F_NO_TR_LDTR

.done_supplementing:
TONLY16 pop     bx
TONLY16 pop     es
        jmp     .return
%undef pRegCtx
BS3_PROC_END_CMN   Bs3RegCtxSaveEx

