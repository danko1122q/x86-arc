; SPDX-License-Identifier: BSD-2-Clause
; Copyright (c) 2026 danko1122q
; All rights reserved.

as_preprocessor:
        mov     edi,as_characters
        xor     al,al
      as_make_characters_table:
        stosb
        inc     al
        if_not_zero     as_make_characters_table
        mov     esi,as_characters+'a'
        mov     edi,as_characters+'A'
        mov     ecx,26
        rep     movsb
        mov     edi,as_characters
        mov     esi,as_token_delimiters+1
        movzx   ecx,as_u8 [esi-1]
        xor     eax,eax
      as_mark_token_delimiters:
        lodsb
        mov     as_u8 [edi+eax],0
        loop    as_mark_token_delimiters
        mov     edi,as_locals_counter
        mov     ax,1 + '0' shl 8
        stos    as_u16 [edi]
        mov     edi,[as_memory_start]
        promote_edi
        mov     [as_include_paths],edi
        mov     esi,as_include_var
        call    as_get_environment_variable
        ; if env var was found, append ';' separator before -i paths
        cmp     edi,[as_include_paths]
        if_equal        as_no_env_include
        mov     as_u8 [edi],';'
        inc     edi
      as_no_env_include:
        ; append paths collected from -i flags (already ';'-separated, ends with null)
        mov     esi,as_include_extra
      as_append_include_extra:
        lodsb
        stos    as_u8 [edi]
        or      al,al
        if_not_zero     as_append_include_extra
        mov     [as_memory_start],edi
        mov     eax,[as_additional_memory]
        mov     [as_free_additional_memory],eax
        mov     eax,[as_additional_memory_end]
        mov     [as_labels_list],eax
        xor     eax,eax
        mov     [as_source_start],eax
        mov     [as_tagged_blocks],eax
        mov     [as_hash_tree],eax
        mov     [as_error],eax
        mov     [as_macro_status],al
        mov     [as_current_line],eax
        mov     esi,[as_initial_definitions]
        promote_esi
        test    esi,esi
        if_zero as_predefinitions_ok
      as_process_predefinitions:
        movzx   ecx,as_u8 [esi]
        test    ecx,ecx
        if_zero as_predefinitions_ok
        inc     esi
        lea     eax,[esi+ecx]
        push    eax
        mov     ch,10b
        call    as_add_preprocessor_symbol
        pop     esi
        mov     edi,[as_memory_start]
        promote_edi
        mov     [edx+8],edi
      as_convert_predefinition:
        cmp     edi,[as_memory_end]
        if_above_equal  as_out_of_memory
        lods    as_u8 [esi]
        or      al,al
        if_zero as_predefinition_converted
        cmp     al,20h
        if_equal        as_convert_predefinition
        mov     ah,al
        mov     ebx,as_characters
        translate_byte  as_u8 [ebx]
        or      al,al
        if_zero as_predefinition_separator
        cmp     ah,27h
        if_equal        as_predefinition_string
        cmp     ah,22h
        if_equal        as_predefinition_string
        mov     as_u8 [edi],1Ah
        scas    as_u16 [edi]
        xchg    al,ah
        stos    as_u8 [edi]
        mov     ebx,as_characters
        xor     ecx,ecx
      as_predefinition_symbol:
        lods    as_u8 [esi]
        stos    as_u8 [edi]
        translate_byte  as_u8 [ebx]
        or      al,al
        loopnzd as_predefinition_symbol
        negate  ecx
        cmp     ecx,255
        if_above        as_invalid_definition
        mov     ebx,edi
        sub     ebx,ecx
        mov     as_u8 [ebx-2],cl
      as_found_predefinition_separator:
        dec     edi
        mov     ah,[esi-1]
      as_predefinition_separator:
        xchg    al,ah
        or      al,al
        if_zero as_predefinition_converted
        cmp     al,20h
        if_equal        as_convert_predefinition
        cmp     al,3Bh
        if_equal        as_invalid_definition
        cmp     al,5Ch
        if_equal        as_predefinition_backslash
        stos    as_u8 [edi]
        jmp     as_convert_predefinition
      as_predefinition_string:
        mov     al,22h
        stos    as_u8 [edi]
        scas    as_u32 [edi]
        mov     ebx,edi
      as_copy_predefinition_string:
        lods    as_u8 [esi]
        stos    as_u8 [edi]
        or      al,al
        if_zero as_invalid_definition
        cmp     al,ah
        if_not_equal    as_copy_predefinition_string
        lods    as_u8 [esi]
        cmp     al,ah
        if_equal        as_copy_predefinition_string
        dec     esi
        dec     edi
        mov     eax,edi
        sub     eax,ebx
        mov     [ebx-4],eax
        jmp     as_convert_predefinition
      as_predefinition_backslash:
        mov     as_u8 [edi],0
        lods    as_u8 [esi]
        or      al,al
        if_zero as_invalid_definition
        cmp     al,20h
        if_equal        as_invalid_definition
        cmp     al,3Bh
        if_equal        as_invalid_definition
        mov     al,1Ah
        stos    as_u8 [edi]
        mov     ecx,edi
        mov     ax,5C01h
        stos    as_u16 [edi]
        dec     esi
      as_group_predefinition_backslashes:
        lods    as_u8 [esi]
        cmp     al,5Ch
        if_not_equal    as_predefinition_backslashed_symbol
        stos    as_u8 [edi]
        inc     as_u8 [ecx]
        jmp     as_group_predefinition_backslashes
      as_predefinition_backslashed_symbol:
        cmp     al,20h
        if_equal        as_invalid_definition
        cmp     al,22h
        if_equal        as_invalid_definition
        cmp     al,27h
        if_equal        as_invalid_definition
        cmp     al,3Bh
        if_equal        as_invalid_definition
        mov     ah,al
        mov     ebx,as_characters
        translate_byte  as_u8 [ebx]
        or      al,al
        if_zero as_predefinition_backslashed_symbol_character
        mov     al,ah
      as_convert_predefinition_backslashed_symbol:
        stos    as_u8 [edi]
        translate_byte  as_u8 [ebx]
        or      al,al
        if_zero as_found_predefinition_separator
        inc     as_u8 [ecx]
        if_zero as_invalid_definition
        lods    as_u8 [esi]
        jmp     as_convert_predefinition_backslashed_symbol
      as_predefinition_backslashed_symbol_character:
        mov     al,ah
        stos    as_u8 [edi]
        inc     as_u8 [ecx]
        jmp     as_convert_predefinition
      as_predefinition_converted:
        mov     [as_memory_start],edi
        sub     edi,[edx+8]
        mov     [edx+12],edi
        jmp     as_process_predefinitions
      as_predefinitions_ok:
        mov     esi,[as_input_file]
        promote_esi
        mov     edx,esi
        call    as_open
        if_carry        as_main_file_not_found
        mov     edi,[as_memory_start]
        promote_edi
        call    as_preprocess_file
        cmp     [as_macro_status],0
        if_equal        as_process_postponed
        mov     eax,[as_error_line]
        mov     [as_current_line],eax
        jmp     as_incomplete_macro
      as_process_postponed:
        mov     edx,as_hash_tree
        mov     ecx,32
      as_find_postponed_list:
        mov     edx,[edx]
        or      edx,edx
        loopnz  as_find_postponed_list
        if_zero as_preprocessing_finished
      as_process_postponed_list:
        mov     eax,[edx]
        or      eax,eax
        if_zero as_preprocessing_finished
        push    edx
        mov     ebx,edx
      as_find_earliest_postponed:
        mov     eax,[edx]
        or      eax,eax
        if_zero as_earliest_postponed_found
        mov     ebx,edx
        mov     edx,eax
        jmp     as_find_earliest_postponed
      as_earliest_postponed_found:
        mov     [ebx],eax
        call    as_use_postponed_macro
        pop     edx
        cmp     [as_macro_status],0
        if_equal        as_process_postponed_list
        mov     eax,[as_error_line]
        mov     [as_current_line],eax
        jmp     as_incomplete_macro
      as_preprocessing_finished:
        mov     [as_source_start],edi
        ret
      as_use_postponed_macro:
        lea     esi,[edi-1]
        push    ecx esi
        mov     [as_struc_name],0
        jmp     as_use_macro

as_preprocess_file:
        push    [as_memory_end]
        push    esi
        mov     al,2
        xor     edx,edx
        call    as_lseek
        push    eax
        xor     al,al
        xor     edx,edx
        call    as_lseek
        pop     ecx
        mov     edx,[as_memory_end]
        promote_edx
        dec     edx
        mov     as_u8 [edx],1Ah
        sub     edx,ecx
        if_carry        as_out_of_memory
        mov     esi,edx
        cmp     edx,edi
        if_below_equal  as_out_of_memory
        mov     [as_memory_end],edx
        call    as_read
        call    as_close
        pop     edx
        xor     ecx,ecx
        mov     ebx,esi
      as_preprocess_source:
        inc     ecx
        mov     [as_current_line],edi
        mov     eax,edx
        stos    as_u32 [edi]
        mov     eax,ecx
        stos    as_u32 [edi]
        mov     eax,esi
        sub     eax,ebx
        stos    as_u32 [edi]
        xor     eax,eax
        stos    as_u32 [edi]
        push    ebx edx
        call    as_convert_line
        call    as_preprocess_line
        pop     edx ebx
      as_next_line:
        cmp     as_u8 [esi-1],0
        if_equal        as_file_end
        cmp     as_u8 [esi-1],1Ah
        if_not_equal    as_preprocess_source
      as_file_end:
        pop     [as_memory_end]
        clear_carry
        ret

as_convert_line:
        push    ecx
        test    [as_macro_status],0Fh
        if_zero as_convert_line_data
        mov     ax,3Bh
        stos    as_u16 [edi]
      as_convert_line_data:
        cmp     edi,[as_memory_end]
        if_above_equal  as_out_of_memory
        lods    as_u8 [esi]
        cmp     al,20h
        if_equal        as_convert_line_data
        cmp     al,9
        if_equal        as_convert_line_data
        mov     ah,al
        mov     ebx,as_characters
        translate_byte  as_u8 [ebx]
        or      al,al
        if_zero as_convert_separator
        cmp     ah,27h
        if_equal        as_convert_string
        cmp     ah,22h
        if_equal        as_convert_string
        mov     as_u8 [edi],1Ah
        scas    as_u16 [edi]
        xchg    al,ah
        stos    as_u8 [edi]
        mov     ebx,as_characters
        xor     ecx,ecx
      as_convert_symbol:
        lods    as_u8 [esi]
        stos    as_u8 [edi]
        translate_byte  as_u8 [ebx]
        or      al,al
        loopnzd as_convert_symbol
        negate  ecx
        cmp     ecx,255
        if_above        as_name_too_long
        mov     ebx,edi
        sub     ebx,ecx
        mov     as_u8 [ebx-2],cl
      as_found_separator:
        dec     edi
        mov     ah,[esi-1]
      as_convert_separator:
        xchg    al,ah
        cmp     al,20h
        if_below        as_control_character
        if_equal        as_convert_line_data
      as_symbol_character:
        cmp     al,3Bh
        if_equal        as_ignore_comment
        cmp     al,5Ch
        if_equal        as_backslash_character
        stos    as_u8 [edi]
        jmp     as_convert_line_data
      as_control_character:
        cmp     al,1Ah
        if_equal        as_line_end
        cmp     al,0Dh
        if_equal        as_cr_character
        cmp     al,0Ah
        if_equal        as_lf_character
        cmp     al,9
        if_equal        as_convert_line_data
        or      al,al
        if_not_zero     as_symbol_character
        jmp     as_line_end
      as_lf_character:
        lods    as_u8 [esi]
        cmp     al,0Dh
        if_equal        as_line_end
        dec     esi
        jmp     as_line_end
      as_cr_character:
        lods    as_u8 [esi]
        cmp     al,0Ah
        if_equal        as_line_end
        dec     esi
        jmp     as_line_end
      as_convert_string:
        mov     al,22h
        stos    as_u8 [edi]
        scas    as_u32 [edi]
        mov     ebx,edi
      as_copy_string:
        lods    as_u8 [esi]
        stos    as_u8 [edi]
        cmp     al,0Ah
        if_equal        as_no_end_quote
        cmp     al,0Dh
        if_equal        as_no_end_quote
        or      al,al
        if_zero as_no_end_quote
        cmp     al,1Ah
        if_equal        as_no_end_quote
        cmp     al,ah
        if_not_equal    as_copy_string
        lods    as_u8 [esi]
        cmp     al,ah
        if_equal        as_copy_string
        dec     esi
        dec     edi
        mov     eax,edi
        sub     eax,ebx
        mov     [ebx-4],eax
        jmp     as_convert_line_data
      as_backslash_character:
        mov     as_u8 [edi],0
        lods    as_u8 [esi]
        cmp     al,20h
        if_equal        as_concatenate_lines
        cmp     al,9
        if_equal        as_concatenate_lines
        cmp     al,1Ah
        if_equal        as_line_end
        or      al,al
        if_zero as_line_end
        cmp     al,0Ah
        if_equal        as_concatenate_lf
        cmp     al,0Dh
        if_equal        as_concatenate_cr
        cmp     al,3Bh
        if_equal        as_find_concatenated_line
        mov     al,1Ah
        stos    as_u8 [edi]
        mov     ecx,edi
        mov     ax,5C01h
        stos    as_u16 [edi]
        dec     esi
      as_group_backslashes:
        lods    as_u8 [esi]
        cmp     al,5Ch
        if_not_equal    as_backslashed_symbol
        stos    as_u8 [edi]
        inc     as_u8 [ecx]
        if_zero as_name_too_long
        jmp     as_group_backslashes
      as_no_end_quote:
        mov     as_u8 [ebx-5],0
        jmp     as_missing_end_quote
      as_backslashed_symbol:
        cmp     al,1Ah
        if_equal        as_extra_characters_on_line
        or      al,al
        if_zero as_extra_characters_on_line
        cmp     al,0Ah
        if_equal        as_extra_characters_on_line
        cmp     al,0Dh
        if_equal        as_extra_characters_on_line
        cmp     al,20h
        if_equal        as_extra_characters_on_line
        cmp     al,9
        if_equal        as_extra_characters_on_line
        cmp     al,22h
        if_equal        as_extra_characters_on_line
        cmp     al,27h
        if_equal        as_extra_characters_on_line
        cmp     al,3Bh
        if_equal        as_extra_characters_on_line
        mov     ah,al
        mov     ebx,as_characters
        translate_byte  as_u8 [ebx]
        or      al,al
        if_zero as_backslashed_symbol_character
        mov     al,ah
      as_convert_backslashed_symbol:
        stos    as_u8 [edi]
        translate_byte  as_u8 [ebx]
        or      al,al
        if_zero as_found_separator
        inc     as_u8 [ecx]
        if_zero as_name_too_long
        lods    as_u8 [esi]
        jmp     as_convert_backslashed_symbol
      as_backslashed_symbol_character:
        mov     al,ah
        stos    as_u8 [edi]
        inc     as_u8 [ecx]
        jmp     as_convert_line_data
      as_concatenate_lines:
        lods    as_u8 [esi]
        cmp     al,20h
        if_equal        as_concatenate_lines
        cmp     al,9
        if_equal        as_concatenate_lines
        cmp     al,1Ah
        if_equal        as_line_end
        or      al,al
        if_zero as_line_end
        cmp     al,0Ah
        if_equal        as_concatenate_lf
        cmp     al,0Dh
        if_equal        as_concatenate_cr
        cmp     al,3Bh
        if_not_equal    as_extra_characters_on_line
      as_find_concatenated_line:
        lods    as_u8 [esi]
        cmp     al,0Ah
        if_equal        as_concatenate_lf
        cmp     al,0Dh
        if_equal        as_concatenate_cr
        or      al,al
        if_zero as_concatenate_ok
        cmp     al,1Ah
        if_not_equal    as_find_concatenated_line
        jmp     as_line_end
      as_concatenate_lf:
        lods    as_u8 [esi]
        cmp     al,0Dh
        if_equal        as_concatenate_ok
        dec     esi
        jmp     as_concatenate_ok
      as_concatenate_cr:
        lods    as_u8 [esi]
        cmp     al,0Ah
        if_equal        as_concatenate_ok
        dec     esi
      as_concatenate_ok:
        inc     as_u32 [esp]
        jmp     as_convert_line_data
      as_ignore_comment:
        lods    as_u8 [esi]
        cmp     al,0Ah
        if_equal        as_lf_character
        cmp     al,0Dh
        if_equal        as_cr_character
        or      al,al
        if_zero as_line_end
        cmp     al,1Ah
        if_not_equal    as_ignore_comment
      as_line_end:
        xor     al,al
        stos    as_u8 [edi]
        pop     ecx
        ret

as_lower_case:
        mov     edi,as_converted
        mov     ebx,as_characters
      as_convert_case:
        lods    as_u8 [esi]
        translate_byte  as_u8 [ebx]
        stos    as_u8 [edi]
        loop    as_convert_case
      as_case_ok:
        ret

as_get_directive:
        push    edi
        mov     edx,esi
        mov     ebp,ecx
        call    as_lower_case
        pop     edi
      as_scan_directives:
        mov     esi,as_converted
        movzx   eax,as_u8 [edi]
        or      al,al
        if_zero as_no_directive
        mov     ecx,ebp
        inc     edi
        mov     ebx,edi
        add     ebx,eax
        mov     ah,[esi]
        cmp     ah,[edi]
        if_below        as_no_directive
        if_above        as_next_directive
        cmp     cl,al
        if_not_equal    as_next_directive
        repe    cmps as_u8 [esi],[edi]
        if_below        as_no_directive
        if_equal        as_directive_found
      as_next_directive:
        mov     edi,ebx
        add     edi,2
        jmp     as_scan_directives
      as_no_directive:
        mov     esi,edx
        mov     ecx,ebp
        set_carry
        ret
      as_directive_found:
        call    as_get_directive_handler_base
      as_directive_handler:
        lea     esi,[edx+ebp]
        movzx   ecx,as_u16 [ebx]
        add     eax,ecx
        clear_carry
        ret
      as_get_directive_handler_base:
        mov     eax,[esp]
        ret

as_preprocess_line:
        mov     eax,esp
        sub     eax,[as_stack_limit]
        cmp     eax,100h
        if_below        as_stack_overflow
        push    ecx esi
      as_preprocess_current_line:
        mov     esi,[as_current_line]
        promote_esi
        add     esi,16
        cmp     as_u16 [esi],3Bh
        if_not_equal    as_line_start_ok
        add     esi,2
      as_line_start_ok:
        test    [as_macro_status],0F0h
        if_not_zero     as_macro_preprocessing
        cmp     as_u8 [esi],1Ah
        if_not_equal    as_not_fix_constant
        movzx   edx,as_u8 [esi+1]
        lea     edx,[esi+2+edx]
        cmp     as_u16 [edx],031Ah
        if_not_equal    as_not_fix_constant
        mov     ebx,as_characters
        movzx   eax,as_u8 [edx+2]
        translate_byte  as_u8 [ebx]
        ror     eax,8
        mov     al,[edx+3]
        translate_byte  as_u8 [ebx]
        ror     eax,8
        mov     al,[edx+4]
        translate_byte  as_u8 [ebx]
        ror     eax,16
        cmp     eax,'fix'
        if_equal        as_define_fix_constant
      as_not_fix_constant:
        call    as_process_fix_constants
        jmp     as_initial_preprocessing_ok
      as_macro_preprocessing:
        call    as_process_macro_operators
      as_initial_preprocessing_ok:
        mov     esi,[as_current_line]
        promote_esi
        add     esi,16
        mov     al,[as_macro_status]
        test    al,2
        if_not_zero     as_skip_macro_block
        test    al,1
        if_not_zero     as_find_macro_block
      as_preprocess_instruction:
        mov     [as_current_offset],esi
        lods    as_u8 [esi]
        movzx   ecx,as_u8 [esi]
        inc     esi
        cmp     al,1Ah
        if_not_equal    as_not_preprocessor_symbol
        cmp     cl,3
        if_below        as_not_preprocessor_directive
        push    edi
        mov     edi,as_preprocessor_directives
        call    as_get_directive
        pop     edi
        if_carry        as_not_preprocessor_directive
        mov     as_u8 [edx-2],3Bh
        jmp     near eax
      as_not_preprocessor_directive:
        xor     ch,ch
        call    as_get_preprocessor_symbol
        if_carry        as_not_macro
        mov     as_u8 [ebx-2],3Bh
        mov     [as_struc_name],0
        jmp     as_use_macro
      as_not_macro:
        mov     [as_struc_name],esi
        add     esi,ecx
        lods    as_u8 [esi]
        cmp     al,':'
        if_equal        as_preprocess_label
        cmp     al,1Ah
        if_not_equal    as_not_preprocessor_symbol
        lods    as_u8 [esi]
        cmp     al,3
        if_not_equal    as_not_symbolic_constant
        mov     ebx,as_characters
        movzx   eax,as_u8 [esi]
        translate_byte  as_u8 [ebx]
        ror     eax,8
        mov     al,[esi+1]
        translate_byte  as_u8 [ebx]
        ror     eax,8
        mov     al,[esi+2]
        translate_byte  as_u8 [ebx]
        ror     eax,16
        cmp     eax,'equ'
        if_equal        as_define_equ_constant
        mov     al,3
      as_not_symbolic_constant:
        mov     ch,1
        mov     cl,al
        call    as_get_preprocessor_symbol
        if_carry        as_not_preprocessor_symbol
        push    edx esi
        mov     esi,[as_struc_name]
        promote_esi
        mov     [as_struc_label],esi
        sub     [as_struc_label],2
        mov     cl,[esi-1]
        mov     ch,10b
        call    as_get_preprocessor_symbol
        if_carry        as_struc_name_ok
        test    edx,edx
        if_zero as_reserved_word_used_as_symbol
        mov     ecx,[edx+12]
        add     ecx,3
        lea     ebx,[edi+ecx]
        mov     ecx,edi
        sub     ecx,[as_struc_label]
        lea     esi,[edi-1]
        lea     edi,[ebx-1]
        set_direction
        rep     movs as_u8 [edi],[esi]
        clear_direction
        mov     edi,[as_struc_label]
        promote_edi
        mov     esi,[edx+8]
        mov     ecx,[edx+12]
        add     [as_struc_name],ecx
        add     [as_struc_name],3
        call    as_move_data
        mov     al,3Ah
        stos    as_u8 [edi]
        mov     ax,3Bh
        stos    as_u16 [edi]
        mov     edi,ebx
        pop     esi
        add     esi,[edx+12]
        add     esi,3
        pop     edx
        jmp     as_use_macro
      as_struc_name_ok:
        mov     edx,[as_struc_name]
        promote_edx
        movzx   eax,as_u8 [edx-1]
        add     edx,eax
        push    edi
        lea     esi,[edi-1]
        mov     ecx,edi
        sub     ecx,edx
        set_direction
        rep     movs as_u8 [edi],[esi]
        clear_direction
        pop     edi
        inc     edi
        mov     al,3Ah
        mov     [edx],al
        inc     al
        mov     [edx+1],al
        pop     esi edx
        inc     esi
        jmp     as_use_macro
      as_preprocess_label:
        dec     esi
        sub     esi,ecx
        lea     ebp,[esi-2]
        mov     ch,10b
        call    as_get_preprocessor_symbol
        if_not_carry    as_symbolic_constant_in_label
        lea     esi,[esi+ecx+1]
        cmp     as_u8 [esi],':'
        if_not_equal    as_preprocess_instruction
        inc     esi
        jmp     as_preprocess_instruction
      as_symbolic_constant_in_label:
        test    edx,edx
        if_zero as_reserved_word_used_as_symbol
        mov     ebx,[edx+8]
        mov     ecx,[edx+12]
        add     ecx,ebx
      as_check_for_broken_label:
        cmp     ebx,ecx
        if_equal        as_label_broken
        cmp     as_u8 [ebx],1Ah
        if_not_equal    as_label_broken
        movzx   eax,as_u8 [ebx+1]
        lea     ebx,[ebx+2+eax]
        cmp     ebx,ecx
        if_equal        as_label_constant_ok
        cmp     as_u8 [ebx],':'
        if_not_equal    as_label_broken
        inc     ebx
        cmp     as_u8 [ebx],':'
        if_not_equal    as_check_for_broken_label
        inc     ebx
        jmp     as_check_for_broken_label
      as_label_broken:
        call    as_replace_symbolic_constant
        jmp     as_line_preprocessed
      as_label_constant_ok:
        mov     ecx,edi
        sub     ecx,esi
        mov     edi,[edx+12]
        add     edi,ebp
        push    edi
        lea     eax,[edi+ecx]
        push    eax
        cmp     esi,edi
        if_equal        as_replace_label
        if_below        as_move_rest_of_line_up
        rep     movs as_u8 [edi],[esi]
        jmp     as_replace_label
      as_move_rest_of_line_up:
        lea     esi,[esi+ecx-1]
        lea     edi,[edi+ecx-1]
        set_direction
        rep     movs as_u8 [edi],[esi]
        clear_direction
      as_replace_label:
        mov     ecx,[edx+12]
        mov     edi,[esp+4]
        sub     edi,ecx
        mov     esi,[edx+8]
        rep     movs as_u8 [edi],[esi]
        pop     edi esi
        inc     esi
        jmp     as_preprocess_instruction
      as_not_preprocessor_symbol:
        mov     esi,[as_current_offset]
        promote_esi
        call    as_process_equ_constants
      as_line_preprocessed:
        pop     esi ecx
        ret

as_get_preprocessor_symbol:
        push    ebp edi esi
        mov     ebp,ecx
        shl     ebp,22
        mov     al,ch
        and     al,11b
        movzx   ecx,cl
        cmp     al,10b
        if_not_equal    as_no_preprocessor_special_symbol
        cmp     cl,4
        if_below_equal  as_no_preprocessor_special_symbol
        mov     ax,'__'
        cmp     ax,[esi]
        if_not_equal    as_no_preprocessor_special_symbol
        cmp     ax,[esi+ecx-2]
        if_not_equal    as_no_preprocessor_special_symbol
        add     esi,2
        sub     ecx,4
        push    ebp
        mov     edi,as_preprocessor_special_symbols
        call    as_get_directive
        pop     ebp
        if_carry        as_preprocessor_special_symbol_not_recognized
        add     esi,2
        xor     edx,edx
        jmp     as_preprocessor_symbol_found
      as_preprocessor_special_symbol_not_recognized:
        add     ecx,4
        sub     esi,2
      as_no_preprocessor_special_symbol:
        mov     ebx,as_hash_tree
        mov     edi,10
      as_follow_hashes_roots:
        mov     edx,[ebx]
        or      edx,edx
        if_zero as_preprocessor_symbol_not_found
        xor     eax,eax
        shl     ebp,1
        add_with_carry  eax,0
        lea     ebx,[edx+eax*4]
        dec     edi
        if_not_zero     as_follow_hashes_roots
        mov     edi,ebx
        call    as_calculate_hash
        mov     ebp,eax
        and     ebp,3FFh
        shl     ebp,10
        xor     ebp,eax
        mov     ebx,edi
        mov     edi,22
      as_follow_hashes_tree:
        mov     edx,[ebx]
        or      edx,edx
        if_zero as_preprocessor_symbol_not_found
        xor     eax,eax
        shl     ebp,1
        add_with_carry  eax,0
        lea     ebx,[edx+eax*4]
        dec     edi
        if_not_zero     as_follow_hashes_tree
        mov     al,cl
        mov     edx,[ebx]
        or      edx,edx
        if_zero as_preprocessor_symbol_not_found
      as_compare_with_preprocessor_symbol:
        mov     edi,[edx+4]
        cmp     edi,1
        if_below_equal  as_next_equal_hash
        repe    cmps as_u8 [esi],[edi]
        if_equal        as_preprocessor_symbol_found
        mov     cl,al
        mov     esi,[esp]
      as_next_equal_hash:
        mov     edx,[edx]
        or      edx,edx
        if_not_zero     as_compare_with_preprocessor_symbol
      as_preprocessor_symbol_not_found:
        pop     esi edi ebp
        set_carry
        ret
      as_preprocessor_symbol_found:
        pop     ebx edi ebp
        clear_carry
        ret
      as_calculate_hash:
        xor     ebx,ebx
        mov     eax,2166136261
        mov     ebp,16777619
      as_fnv1a_hash:
        xor     al,[esi+ebx]
        mul     ebp
        inc     bl
        cmp     bl,cl
        if_below        as_fnv1a_hash
        ret
as_add_preprocessor_symbol:
        push    edi esi
        xor     eax,eax
        or      cl,cl
        if_zero as_reshape_hash
        cmp     ch,11b
        if_equal        as_preprocessor_symbol_name_ok
        push    ecx
        movzx   ecx,cl
        mov     edi,as_preprocessor_directives
        call    as_get_directive
        if_not_carry    as_reserved_word_used_as_symbol
        pop     ecx
      as_preprocessor_symbol_name_ok:
        call    as_calculate_hash
      as_reshape_hash:
        mov     ebp,eax
        and     ebp,3FFh
        shr     eax,10
        xor     ebp,eax
        shl     ecx,22
        or      ebp,ecx
        mov     ebx,as_hash_tree
        mov     ecx,32
      as_find_leave_for_symbol:
        mov     edx,[ebx]
        or      edx,edx
        if_zero as_extend_hashes_tree
        xor     eax,eax
        rol     ebp,1
        add_with_carry  eax,0
        lea     ebx,[edx+eax*4]
        dec     ecx
        if_not_zero     as_find_leave_for_symbol
        mov     edx,[ebx]
        or      edx,edx
        if_zero as_add_symbol_entry
        shr     ebp,30
        cmp     ebp,11b
        if_equal        as_reuse_symbol_entry
        cmp     as_u32 [edx+4],0
        if_not_equal    as_add_symbol_entry
      as_find_entry_to_reuse:
        mov     edi,[edx]
        or      edi,edi
        if_zero as_reuse_symbol_entry
        cmp     as_u32 [edi+4],0
        if_not_equal    as_reuse_symbol_entry
        mov     edx,edi
        jmp     as_find_entry_to_reuse
      as_add_symbol_entry:
        mov     eax,edx
        mov     edx,[as_labels_list]
        promote_edx
        sub     edx,16
        cmp     edx,[as_free_additional_memory]
        if_below        as_out_of_memory
        mov     [as_labels_list],edx
        mov     [edx],eax
        mov     [ebx],edx
      as_reuse_symbol_entry:
        pop     esi edi
        mov     [edx+4],esi
        ret
      as_extend_hashes_tree:
        mov     edx,[as_labels_list]
        promote_edx
        sub     edx,8
        cmp     edx,[as_free_additional_memory]
        if_below        as_out_of_memory
        mov     [as_labels_list],edx
        xor     eax,eax
        mov     [edx],eax
        mov     [edx+4],eax
        shl     ebp,1
        add_with_carry  eax,0
        mov     [ebx],edx
        lea     ebx,[edx+eax*4]
        dec     ecx
        if_not_zero     as_extend_hashes_tree
        mov     edx,[as_labels_list]
        promote_edx
        sub     edx,16
        cmp     edx,[as_free_additional_memory]
        if_below        as_out_of_memory
        mov     [as_labels_list],edx
        mov     as_u32 [edx],0
        mov     [ebx],edx
        pop     esi edi
        mov     [edx+4],esi
        ret

as_define_fix_constant:
        add     edx,5
        add     esi,2
        push    edx
        mov     ch,11b
        jmp     as_define_preprocessor_constant
as_define_equ_constant:
        add     esi,3
        push    esi
        call    as_process_equ_constants
        mov     esi,[as_struc_name]
        promote_esi
        mov     ch,10b
      as_define_preprocessor_constant:
        mov     as_u8 [esi-2],3Bh
        mov     cl,[esi-1]
        call    as_add_preprocessor_symbol
        pop     ebx
        mov     ecx,edi
        dec     ecx
        sub     ecx,ebx
        mov     [edx+8],ebx
        mov     [edx+12],ecx
        jmp     as_line_preprocessed
as_define_symbolic_constant:
        lods    as_u8 [esi]
        cmp     al,1Ah
        if_not_equal    as_invalid_name
        lods    as_u8 [esi]
        mov     cl,al
        mov     ch,10b
        call    as_add_preprocessor_symbol
        movzx   eax,as_u8 [esi-1]
        add     esi,eax
        lea     ecx,[edi-1]
        sub     ecx,esi
        mov     [edx+8],esi
        mov     [edx+12],ecx
        jmp     as_line_preprocessed

as_define_struc:
        mov     ch,1
        jmp     as_make_macro
as_define_macro:
        xor     ch,ch
      as_make_macro:
        lods    as_u8 [esi]
        cmp     al,1Ah
        if_not_equal    as_invalid_name
        lods    as_u8 [esi]
        mov     cl,al
        call    as_add_preprocessor_symbol
        mov     eax,[as_current_line]
        mov     [edx+12],eax
        movzx   eax,as_u8 [esi-1]
        add     esi,eax
        mov     [edx+8],esi
        mov     al,[as_macro_status]
        and     al,0F0h
        or      al,1
        mov     [as_macro_status],al
        mov     eax,[as_current_line]
        mov     [as_error_line],eax
        xor     ebp,ebp
        lods    as_u8 [esi]
        or      al,al
        if_zero as_line_preprocessed
        cmp     al,'{'
        if_equal        as_found_macro_block
        dec     esi
      as_skip_macro_arguments:
        lods    as_u8 [esi]
        cmp     al,1Ah
        if_equal        as_skip_macro_argument
        cmp     al,'['
        if_not_equal    as_invalid_macro_arguments
        or      ebp,-1
        if_zero as_invalid_macro_arguments
        lods    as_u8 [esi]
        cmp     al,1Ah
        if_not_equal    as_invalid_macro_arguments
      as_skip_macro_argument:
        movzx   eax,as_u8 [esi]
        inc     esi
        add     esi,eax
        lods    as_u8 [esi]
        cmp     al,':'
        if_equal        as_macro_argument_with_default_value
        cmp     al,'='
        if_equal        as_macro_argument_with_default_value
        cmp     al,'*'
        if_not_equal    as_macro_argument_end
        lods    as_u8 [esi]
      as_macro_argument_end:
        cmp     al,','
        if_equal        as_skip_macro_arguments
        cmp     al,'&'
        if_equal        as_macro_arguments_finisher
        cmp     al,']'
        if_not_equal    as_end_macro_arguments
        not     ebp
      as_macro_arguments_finisher:
        lods    as_u8 [esi]
      as_end_macro_arguments:
        or      ebp,ebp
        if_not_zero     as_invalid_macro_arguments
        or      al,al
        if_zero as_line_preprocessed
        cmp     al,'{'
        if_equal        as_found_macro_block
        jmp     as_invalid_macro_arguments
      as_macro_argument_with_default_value:
        or      [as_skip_default_argument_value],-1
        call    as_skip_macro_argument_value
        inc     esi
        jmp     as_macro_argument_end
      as_skip_macro_argument_value:
        cmp     as_u8 [esi],'<'
        if_not_equal    as_simple_argument
        mov     ecx,1
        inc     esi
      as_enclosed_argument:
        lods    as_u8 [esi]
        or      al,al
        if_zero as_invalid_macro_arguments
        cmp     al,1Ah
        if_equal        as_enclosed_symbol
        cmp     al,22h
        if_equal        as_enclosed_string
        cmp     al,'>'
        if_equal        as_enclosed_argument_end
        cmp     al,'<'
        if_not_equal    as_enclosed_argument
        inc     ecx
        jmp     as_enclosed_argument
      as_enclosed_symbol:
        movzx   eax,as_u8 [esi]
        inc     esi
        add     esi,eax
        jmp     as_enclosed_argument
      as_enclosed_string:
        lods    as_u32 [esi]
        add     esi,eax
        jmp     as_enclosed_argument
      as_enclosed_argument_end:
        loop    as_enclosed_argument
        lods    as_u8 [esi]
        or      al,al
        if_zero as_argument_value_end
        cmp     al,','
        if_equal        as_argument_value_end
        cmp     [as_skip_default_argument_value],0
        if_equal        as_invalid_macro_arguments
        cmp     al,'{'
        if_equal        as_argument_value_end
        cmp     al,'&'
        if_equal        as_argument_value_end
        or      ebp,ebp
        if_zero as_invalid_macro_arguments
        cmp     al,']'
        if_equal        as_argument_value_end
        jmp     as_invalid_macro_arguments
      as_simple_argument:
        lods    as_u8 [esi]
        or      al,al
        if_zero as_argument_value_end
        cmp     al,','
        if_equal        as_argument_value_end
        cmp     al,22h
        if_equal        as_argument_string
        cmp     al,1Ah
        if_equal        as_argument_symbol
        cmp     [as_skip_default_argument_value],0
        if_equal        as_simple_argument
        cmp     al,'{'
        if_equal        as_argument_value_end
        cmp     al,'&'
        if_equal        as_argument_value_end
        or      ebp,ebp
        if_zero as_simple_argument
        cmp     al,']'
        if_equal        as_argument_value_end
      as_argument_symbol:
        movzx   eax,as_u8 [esi]
        inc     esi
        add     esi,eax
        jmp     as_simple_argument
      as_argument_string:
        lods    as_u32 [esi]
        add     esi,eax
        jmp     as_simple_argument
      as_argument_value_end:
        dec     esi
        ret
      as_find_macro_block:
        add     esi,2
        lods    as_u8 [esi]
        or      al,al
        if_zero as_line_preprocessed
        cmp     al,'{'
        if_not_equal    as_unexpected_characters
      as_found_macro_block:
        or      [as_macro_status],2
      as_skip_macro_block:
        lods    as_u8 [esi]
        cmp     al,1Ah
        if_equal        as_skip_macro_symbol
        cmp     al,3Bh
        if_equal        as_skip_macro_symbol
        cmp     al,22h
        if_equal        as_skip_macro_string
        or      al,al
        if_zero as_line_preprocessed
        cmp     al,'}'
        if_not_equal    as_skip_macro_block
        mov     al,[as_macro_status]
        and     [as_macro_status],0F0h
        test    al,8
        if_not_zero     as_use_instant_macro
        cmp     as_u8 [esi],0
        if_equal        as_line_preprocessed
        mov     ecx,edi
        sub     ecx,esi
        mov     edx,esi
        lea     esi,[esi+ecx-1]
        lea     edi,[edi+1+16]
        mov     ebx,edi
        dec     edi
        set_direction
        rep     movs as_u8 [edi],[esi]
        clear_direction
        mov     edi,edx
        xor     al,al
        stos    as_u8 [edi]
        mov     esi,[as_current_line]
        promote_esi
        mov     [as_current_line],edi
        mov     ecx,4
        rep     movs as_u32 [edi],[esi]
        mov     edi,ebx
        jmp     as_initial_preprocessing_ok
      as_skip_macro_symbol:
        movzx   eax,as_u8 [esi]
        inc     esi
        add     esi,eax
        jmp     as_skip_macro_block
      as_skip_macro_string:
        lods    as_u32 [esi]
        add     esi,eax
        jmp     as_skip_macro_block
as_postpone_directive:
        push    esi
        mov     esi,edx
        xor     ecx,ecx
        call    as_add_preprocessor_symbol
        mov     eax,[as_current_line]
        mov     [as_error_line],eax
        mov     [edx+12],eax
        pop     esi
        mov     [edx+8],esi
        mov     al,[as_macro_status]
        and     al,0F0h
        or      al,1
        mov     [as_macro_status],al
        lods    as_u8 [esi]
        or      al,al
        if_zero as_line_preprocessed
        cmp     al,'{'
        if_not_equal    as_unexpected_characters
        jmp     as_found_macro_block
as_rept_directive:
        mov     [as_base_code],0
        jmp     as_define_instant_macro
as_irp_directive:
        mov     [as_base_code],1
        jmp     as_define_instant_macro
as_irps_directive:
        mov     [as_base_code],2
        jmp     as_define_instant_macro
as_irpv_directive:
        mov     [as_base_code],3
        jmp     as_define_instant_macro
as_match_directive:
        mov     [as_base_code],10h
as_define_instant_macro:
        mov     al,[as_macro_status]
        and     al,0F0h
        or      al,8+1
        mov     [as_macro_status],al
        mov     eax,[as_current_line]
        mov     [as_error_line],eax
        mov     [as_instant_macro_start],esi
        cmp     [as_base_code],10h
        if_equal        as_prepare_match
      as_skip_parameters:
        lods    as_u8 [esi]
        or      al,al
        if_zero as_parameters_skipped
        cmp     al,'{'
        if_equal        as_parameters_skipped
        cmp     al,22h
        if_equal        as_skip_quoted_parameter
        cmp     al,1Ah
        if_not_equal    as_skip_parameters
        lods    as_u8 [esi]
        movzx   eax,al
        add     esi,eax
        jmp     as_skip_parameters
      as_skip_quoted_parameter:
        lods    as_u32 [esi]
        add     esi,eax
        jmp     as_skip_parameters
      as_parameters_skipped:
        dec     esi
        mov     [as_parameters_end],esi
        lods    as_u8 [esi]
        cmp     al,'{'
        if_equal        as_found_macro_block
        or      al,al
        if_not_zero     as_invalid_macro_arguments
        jmp     as_line_preprocessed
as_prepare_match:
        call    as_skip_pattern
        mov     [as_value_type],80h+10b
        call    as_process_symbolic_constants
        jmp     as_parameters_skipped
      as_skip_pattern:
        lods    as_u8 [esi]
        or      al,al
        if_zero as_invalid_macro_arguments
        cmp     al,','
        if_equal        as_pattern_skipped
        cmp     al,22h
        if_equal        as_skip_quoted_string_in_pattern
        cmp     al,1Ah
        if_equal        as_skip_symbol_in_pattern
        cmp     al,'='
        if_not_equal    as_skip_pattern
        mov     al,[esi]
        cmp     al,1Ah
        if_equal        as_skip_pattern
        cmp     al,22h
        if_equal        as_skip_pattern
        inc     esi
        jmp     as_skip_pattern
      as_skip_symbol_in_pattern:
        lods    as_u8 [esi]
        movzx   eax,al
        add     esi,eax
        jmp     as_skip_pattern
      as_skip_quoted_string_in_pattern:
        lods    as_u32 [esi]
        add     esi,eax
        jmp     as_skip_pattern
      as_pattern_skipped:
        ret

as_purge_macro:
        xor     ch,ch
        jmp     as_restore_preprocessor_symbol
as_purge_struc:
        mov     ch,1
        jmp     as_restore_preprocessor_symbol
as_restore_equ_constant:
        mov     ch,10b
      as_restore_preprocessor_symbol:
        push    ecx
        lods    as_u8 [esi]
        cmp     al,1Ah
        if_not_equal    as_invalid_name
        lods    as_u8 [esi]
        mov     cl,al
        call    as_get_preprocessor_symbol
        if_carry        as_no_symbol_to_restore
        test    edx,edx
        if_zero as_symbol_restored
        mov     as_u32 [edx+4],0
        jmp     as_symbol_restored
      as_no_symbol_to_restore:
        add     esi,ecx
      as_symbol_restored:
        pop     ecx
        lods    as_u8 [esi]
        cmp     al,','
        if_equal        as_restore_preprocessor_symbol
        or      al,al
        if_not_zero     as_extra_characters_on_line
        jmp     as_line_preprocessed

as_process_fix_constants:
        mov     [as_value_type],11b
        jmp     as_process_symbolic_constants
as_process_equ_constants:
        mov     [as_value_type],10b
      as_process_symbolic_constants:
        mov     ebp,esi
        lods    as_u8 [esi]
        cmp     al,1Ah
        if_equal        as_check_symbol
        cmp     al,22h
        if_equal        as_ignore_string
        cmp     al,'{'
        if_equal        as_check_brace
        or      al,al
        if_not_zero     as_process_symbolic_constants
        ret
      as_ignore_string:
        lods    as_u32 [esi]
        add     esi,eax
        jmp     as_process_symbolic_constants
      as_check_brace:
        test    [as_value_type],80h
        if_zero as_process_symbolic_constants
        ret
      as_no_replacing:
        movzx   ecx,as_u8 [esi-1]
        add     esi,ecx
        jmp     as_process_symbolic_constants
      as_check_symbol:
        mov     cl,[esi]
        inc     esi
        mov     ch,[as_value_type]
        call    as_get_preprocessor_symbol
        if_carry        as_no_replacing
        mov     [as_current_section],edi
      as_replace_symbolic_constant:
        test    edx,edx
        if_zero as_replace_special_symbolic_constant
        mov     ecx,[edx+12]
        mov     edx,[edx+8]
        xchg    esi,edx
        call    as_move_data
        mov     esi,edx
      as_process_after_replaced:
        lods    as_u8 [esi]
        cmp     al,1Ah
        if_equal        as_symbol_after_replaced
        stos    as_u8 [edi]
        cmp     al,22h
        if_equal        as_string_after_replaced
        cmp     al,'{'
        if_equal        as_brace_after_replaced
        or      al,al
        if_not_zero     as_process_after_replaced
        mov     ecx,edi
        sub     ecx,esi
        mov     edi,ebp
        call    as_move_data
        mov     esi,edi
        ret
      as_move_data:
        lea     eax,[edi+ecx]
        cmp     eax,[as_memory_end]
        if_above_equal  as_out_of_memory
        shr     ecx,1
        if_not_carry    as_movsb_ok
        movs    as_u8 [edi],[esi]
      as_movsb_ok:
        shr     ecx,1
        if_not_carry    as_movsw_ok
        movs    as_u16 [edi],[esi]
      as_movsw_ok:
        rep     movs as_u32 [edi],[esi]
        ret
      as_string_after_replaced:
        lods    as_u32 [esi]
        stos    as_u32 [edi]
        mov     ecx,eax
        call    as_move_data
        jmp     as_process_after_replaced
      as_brace_after_replaced:
        test    [as_value_type],80h
        if_zero as_process_after_replaced
        mov     edx,edi
        mov     ecx,[as_current_section]
        promote_ecx
        sub     edx,ecx
        sub     ecx,esi
        rep     movs as_u8 [edi],[esi]
        mov     ecx,edi
        sub     ecx,esi
        mov     edi,ebp
        call    as_move_data
        lea     esi,[ebp+edx]
        ret
      as_symbol_after_replaced:
        mov     cl,[esi]
        inc     esi
        mov     ch,[as_value_type]
        call    as_get_preprocessor_symbol
        if_not_carry    as_replace_symbolic_constant
        movzx   ecx,as_u8 [esi-1]
        mov     al,1Ah
        mov     ah,cl
        stos    as_u16 [edi]
        call    as_move_data
        jmp     as_process_after_replaced
      as_replace_special_symbolic_constant:
        jmp     near eax
      as_preprocessed_file_value:
        call    as_get_current_line_from_file
        test    ebx,ebx
        if_zero as_process_after_replaced
        push    esi edi
        mov     esi,[ebx]
        mov     edi,esi
        xor     al,al
        or      ecx,-1
        repne   scas as_u8 [edi]
        add     ecx,2
        negate  ecx
        pop     edi
        lea     eax,[edi+1+4+ecx]
        cmp     eax,[as_memory_end]
        if_above        as_out_of_memory
        mov     al,22h
        stos    as_u8 [edi]
        mov     eax,ecx
        stos    as_u32 [edi]
        rep     movs as_u8 [edi],[esi]
        pop     esi
        jmp     as_process_after_replaced
      as_preprocessed_line_value:
        call    as_get_current_line_from_file
        test    ebx,ebx
        if_zero as_process_after_replaced
        lea     eax,[edi+1+4+20]
        cmp     eax,[as_memory_end]
        if_above        as_out_of_memory
        mov     ecx,[ebx+4]
        call    as_store_number_symbol
        jmp     as_process_after_replaced
      as_get_current_line_from_file:
        mov     ebx,[as_current_line]
        promote_ebx
      as_find_line_from_file:
        test    ebx,ebx
        if_zero as_line_from_file_found
        test    as_u8 [ebx+7],80h
        if_zero as_line_from_file_found
        mov     ebx,[ebx+8]
        jmp     as_find_line_from_file
      as_line_from_file_found:
        ret

as_process_macro_operators:
        xor     dl,dl
        mov     ebp,edi
      as_before_macro_operators:
        mov     edi,esi
        lods    as_u8 [esi]
        cmp     al,'`'
        if_equal        as_symbol_conversion
        cmp     al,'#'
        if_equal        as_concatenation
        cmp     al,1Ah
        if_equal        as_symbol_before_macro_operators
        cmp     al,3Bh
        if_equal        as_no_more_macro_operators
        cmp     al,22h
        if_equal        as_string_before_macro_operators
        xor     dl,dl
        or      al,al
        if_not_zero     as_before_macro_operators
        mov     edi,esi
        ret
      as_no_more_macro_operators:
        mov     edi,ebp
        ret
      as_symbol_before_macro_operators:
        mov     dl,1Ah
        mov     ebx,esi
        lods    as_u8 [esi]
        movzx   ecx,al
        jecxz   as_symbol_before_macro_operators_ok
        mov     edi,esi
        cmp     as_u8 [esi],'\'
        if_equal        as_escaped_symbol
      as_symbol_before_macro_operators_ok:
        add     esi,ecx
        jmp     as_before_macro_operators
      as_string_before_macro_operators:
        mov     dl,22h
        mov     ebx,esi
        lods    as_u32 [esi]
        add     esi,eax
        jmp     as_before_macro_operators
      as_escaped_symbol:
        dec     as_u8 [edi-1]
        dec     ecx
        inc     esi
        cmp     ecx,1
        rep     movs as_u8 [edi],[esi]
        if_not_equal    as_after_macro_operators
        mov     al,[esi-1]
        mov     ecx,ebx
        mov     ebx,as_characters
        translate_byte  as_u8 [ebx]
        mov     ebx,ecx
        or      al,al
        if_not_zero     as_after_macro_operators
        sub     edi,3
        mov     al,[esi-1]
        stos    as_u8 [edi]
        xor     dl,dl
        jmp     as_after_macro_operators
      as_reduce_symbol_conversion:
        inc     esi
      as_symbol_conversion:
        mov     edx,esi
        mov     al,[esi]
        cmp     al,1Ah
        if_not_equal    as_symbol_character_conversion
        lods    as_u16 [esi]
        movzx   ecx,ah
        lea     ebx,[edi+3]
        jecxz   as_convert_to_quoted_string
        cmp     as_u8 [esi],'\'
        if_not_equal    as_convert_to_quoted_string
        inc     esi
        dec     ecx
        dec     ebx
        jmp     as_convert_to_quoted_string
      as_symbol_character_conversion:
        cmp     al,22h
        if_equal        as_after_macro_operators
        cmp     al,'`'
        if_equal        as_reduce_symbol_conversion
        lea     ebx,[edi+5]
        xor     ecx,ecx
        or      al,al
        if_zero as_convert_to_quoted_string
        cmp     al,'#'
        if_equal        as_convert_to_quoted_string
        inc     ecx
      as_convert_to_quoted_string:
        sub     ebx,edx
        if_above        as_shift_line_data
        mov     al,22h
        mov     dl,al
        stos    as_u8 [edi]
        mov     ebx,edi
        mov     eax,ecx
        stos    as_u32 [edi]
        rep     movs as_u8 [edi],[esi]
        cmp     edi,esi
        if_equal        as_before_macro_operators
        jmp     as_after_macro_operators
      as_shift_line_data:
        push    ecx
        mov     edx,esi
        lea     esi,[ebp-1]
        add     ebp,ebx
        lea     edi,[ebp-1]
        lea     ecx,[esi+1]
        sub     ecx,edx
        set_direction
        rep     movs as_u8 [edi],[esi]
        clear_direction
        pop     eax
        sub     edi,3
        mov     dl,22h
        mov     [edi-1],dl
        mov     ebx,edi
        mov     [edi],eax
        lea     esi,[edi+4+eax]
        jmp     as_before_macro_operators
      as_concatenation:
        cmp     dl,1Ah
        if_equal        as_symbol_concatenation
        cmp     dl,22h
        if_equal        as_string_concatenation
      as_no_concatenation:
        cmp     esi,edi
        if_equal        as_before_macro_operators
        jmp     as_after_macro_operators
      as_symbol_concatenation:
        cmp     as_u8 [esi],1Ah
        if_not_equal    as_no_concatenation
        inc     esi
        lods    as_u8 [esi]
        movzx   ecx,al
        jecxz   as_do_symbol_concatenation
        cmp     as_u8 [esi],'\'
        if_equal        as_concatenate_escaped_symbol
      as_do_symbol_concatenation:
        add     [ebx],cl
        if_carry        as_name_too_long
        rep     movs as_u8 [edi],[esi]
        jmp     as_after_macro_operators
      as_concatenate_escaped_symbol:
        inc     esi
        dec     ecx
        if_zero as_do_symbol_concatenation
        movzx   eax,as_u8 [esi]
        cmp     as_u8 [as_characters+eax],0
        if_not_equal    as_do_symbol_concatenation
        sub     esi,3
        jmp     as_no_concatenation
      as_string_concatenation:
        cmp     as_u8 [esi],22h
        if_equal        as_do_string_concatenation
        cmp     as_u8 [esi],'`'
        if_not_equal    as_no_concatenation
      as_concatenate_converted_symbol:
        inc     esi
        mov     al,[esi]
        cmp     al,'`'
        if_equal        as_concatenate_converted_symbol
        cmp     al,22h
        if_equal        as_do_string_concatenation
        cmp     al,1Ah
        if_not_equal    as_concatenate_converted_symbol_character
        inc     esi
        lods    as_u8 [esi]
        movzx   ecx,al
        jecxz   as_finish_concatenating_converted_symbol
        cmp     as_u8 [esi],'\'
        if_not_equal    as_finish_concatenating_converted_symbol
        inc     esi
        dec     ecx
      as_finish_concatenating_converted_symbol:
        add     [ebx],ecx
        rep     movs as_u8 [edi],[esi]
        jmp     as_after_macro_operators
      as_concatenate_converted_symbol_character:
        or      al,al
        if_zero as_after_macro_operators
        cmp     al,'#'
        if_equal        as_after_macro_operators
        inc     as_u32 [ebx]
        movs    as_u8 [edi],[esi]
        jmp     as_after_macro_operators
      as_do_string_concatenation:
        inc     esi
        lods    as_u32 [esi]
        mov     ecx,eax
        add     [ebx],eax
        rep     movs as_u8 [edi],[esi]
      as_after_macro_operators:
        lods    as_u8 [esi]
        cmp     al,'`'
        if_equal        as_symbol_conversion
        cmp     al,'#'
        if_equal        as_concatenation
        stos    as_u8 [edi]
        cmp     al,1Ah
        if_equal        as_symbol_after_macro_operators
        cmp     al,3Bh
        if_equal        as_no_more_macro_operators
        cmp     al,22h
        if_equal        as_string_after_macro_operators
        xor     dl,dl
        or      al,al
        if_not_zero     as_after_macro_operators
        ret
      as_symbol_after_macro_operators:
        mov     dl,1Ah
        mov     ebx,edi
        lods    as_u8 [esi]
        stos    as_u8 [edi]
        movzx   ecx,al
        jecxz   as_symbol_after_macro_operatorss_ok
        cmp     as_u8 [esi],'\'
        if_equal        as_escaped_symbol
      as_symbol_after_macro_operatorss_ok:
        rep     movs as_u8 [edi],[esi]
        jmp     as_after_macro_operators
      as_string_after_macro_operators:
        mov     dl,22h
        mov     ebx,edi
        lods    as_u32 [esi]
        stos    as_u32 [edi]
        mov     ecx,eax
        rep     movs as_u8 [edi],[esi]
        jmp     as_after_macro_operators

as_use_macro:
        push    [as_free_additional_memory]
        push    [as_macro_symbols]
        mov     [as_macro_symbols],0
        push    [as_counter_limit]
        push    as_u32 [edx+4]
        mov     as_u32 [edx+4],1
        push    edx
        mov     ebx,esi
        mov     esi,[edx+8]
        mov     eax,[edx+12]
        mov     [as_macro_line],eax
        mov     [as_counter_limit],0
        xor     ebp,ebp
      as_process_macro_arguments:
        mov     al,[esi]
        or      al,al
        if_zero as_arguments_end
        cmp     al,'{'
        if_equal        as_arguments_end
        inc     esi
        cmp     al,'['
        if_not_equal    as_get_macro_arguments
        mov     ebp,esi
        inc     esi
        inc     [as_counter_limit]
      as_get_macro_arguments:
        call    as_get_macro_argument
        lods    as_u8 [esi]
        cmp     al,','
        if_equal        as_next_argument
        cmp     al,']'
        if_equal        as_next_arguments_group
        cmp     al,'&'
        if_equal        as_arguments_end
        dec     esi
        jmp     as_arguments_end
      as_next_argument:
        cmp     as_u8 [ebx],','
        if_not_equal    as_process_macro_arguments
        inc     ebx
        jmp     as_process_macro_arguments
      as_next_arguments_group:
        cmp     as_u8 [ebx],','
        if_not_equal    as_arguments_end
        inc     ebx
        inc     [as_counter_limit]
        mov     esi,ebp
        jmp     as_process_macro_arguments
      as_get_macro_argument:
        lods    as_u8 [esi]
        movzx   ecx,al
        mov     eax,[as_counter_limit]
        call    as_add_macro_symbol
        add     esi,ecx
        xor     eax,eax
        mov     [as_default_argument_value],eax
        cmp     as_u8 [esi],'*'
        if_equal        as_required_value
        cmp     as_u8 [esi],':'
        if_equal        as_get_default_value
        cmp     as_u8 [esi],'='
        if_not_equal    as_default_value_ok
      as_get_default_value:
        inc     esi
        mov     [as_default_argument_value],esi
        or      [as_skip_default_argument_value],-1
        call    as_skip_macro_argument_value
        jmp     as_default_value_ok
      as_required_value:
        inc     esi
        or      [as_default_argument_value],-1
      as_default_value_ok:
        xchg    esi,ebx
        mov     [edx+12],esi
        mov     [as_skip_default_argument_value],0
        cmp     as_u8 [ebx],'&'
        if_equal        as_greedy_macro_argument
        call    as_skip_macro_argument_value
        call    as_finish_macro_argument
        jmp     as_got_macro_argument
      as_greedy_macro_argument:
        call    as_skip_foreign_line
        dec     esi
        mov     eax,[edx+12]
        mov     ecx,esi
        sub     ecx,eax
        mov     [edx+8],ecx
      as_got_macro_argument:
        xchg    esi,ebx
        cmp     as_u32 [edx+8],0
        if_not_equal    as_macro_argument_ok
        mov     eax,[as_default_argument_value]
        or      eax,eax
        if_zero as_macro_argument_ok
        cmp     eax,-1
        if_equal        as_invalid_macro_arguments
        mov     [edx+12],eax
        call    as_finish_macro_argument
      as_macro_argument_ok:
        ret
      as_finish_macro_argument:
        mov     eax,[edx+12]
        mov     ecx,esi
        sub     ecx,eax
        cmp     as_u8 [eax],'<'
        if_not_equal    as_argument_value_length_ok
        inc     as_u32 [edx+12]
        sub     ecx,2
        or      ecx,80000000h
      as_argument_value_length_ok:
        mov     [edx+8],ecx
        ret
      as_arguments_end:
        cmp     as_u8 [ebx],0
        if_not_equal    as_invalid_macro_arguments
        mov     eax,[esp+4]
        dec     eax
        call    as_process_macro
        pop     edx
        pop     as_u32 [edx+4]
        pop     [as_counter_limit]
        pop     [as_macro_symbols]
        pop     [as_free_additional_memory]
        jmp     as_line_preprocessed
as_use_instant_macro:
        push    edi
        push    [as_current_line]
        push    esi
        mov     eax,[as_error_line]
        mov     [as_current_line],eax
        mov     [as_macro_line],eax
        mov     esi,[as_instant_macro_start]
        promote_esi
        cmp     [as_base_code],10h
        if_above_equal  as_do_match
        cmp     [as_base_code],0
        if_not_equal    as_do_irp
        call    as_precalculate_value
        cmp     eax,0
        if_less as_value_out_of_range
        push    [as_free_additional_memory]
        push    [as_macro_symbols]
        mov     [as_macro_symbols],0
        push    [as_counter_limit]
        mov     [as_struc_name],0
        mov     [as_counter_limit],eax
        lods    as_u8 [esi]
        or      al,al
        if_zero as_rept_counters_ok
        cmp     al,'{'
        if_equal        as_rept_counters_ok
        cmp     al,1Ah
        if_not_equal    as_invalid_macro_arguments
      as_add_rept_counter:
        lods    as_u8 [esi]
        movzx   ecx,al
        xor     eax,eax
        call    as_add_macro_symbol
        add     esi,ecx
        xor     eax,eax
        mov     as_u32 [edx+12],eax
        inc     eax
        mov     as_u32 [edx+8],eax
        lods    as_u8 [esi]
        cmp     al,':'
        if_not_equal    as_rept_counter_added
        push    edx
        call    as_precalculate_value
        mov     edx,eax
        add     edx,[as_counter_limit]
        if_overflow     as_value_out_of_range
        pop     edx
        mov     as_u32 [edx+8],eax
        lods    as_u8 [esi]
      as_rept_counter_added:
        cmp     al,','
        if_not_equal    as_rept_counters_ok
        lods    as_u8 [esi]
        cmp     al,1Ah
        if_not_equal    as_invalid_macro_arguments
        jmp     as_add_rept_counter
      as_rept_counters_ok:
        dec     esi
        cmp     [as_counter_limit],0
        if_equal        as_instant_macro_finish
      as_instant_macro_parameters_ok:
        xor     eax,eax
        call    as_process_macro
      as_instant_macro_finish:
        pop     [as_counter_limit]
        pop     [as_macro_symbols]
        pop     [as_free_additional_memory]
      as_instant_macro_done:
        pop     ebx esi edx
        cmp     as_u8 [ebx],0
        if_equal        as_line_preprocessed
        mov     [as_current_line],edi
        mov     ecx,4
        rep     movs as_u32 [edi],[esi]
        test    [as_macro_status],0Fh
        if_zero as_instant_macro_attached_line
        mov     ax,3Bh
        stos    as_u16 [edi]
      as_instant_macro_attached_line:
        mov     esi,ebx
        sub     edx,ebx
        mov     ecx,edx
        call    as_move_data
        jmp     as_initial_preprocessing_ok
      as_precalculate_value:
        push    edi
        call    as_convert_expression
        mov     al,')'
        stosb
        push    esi
        mov     esi,[esp+4]
        mov     [as_error_line],0
        mov     [as_value_size],0
        call    as_calculate_expression
        cmp     [as_error_line],0
        if_equal        as_value_precalculated
        jmp     [as_error]
      as_value_precalculated:
        mov     eax,[edi]
        mov     ecx,[edi+4]
        sign_extend_dword
        cmp     edx,ecx
        if_not_equal    as_value_out_of_range
        cmp     dl,[edi+13]
        if_not_equal    as_value_out_of_range
        pop     esi edi
        ret
as_do_irp:
        cmp     as_u8 [esi],1Ah
        if_not_equal    as_invalid_macro_arguments
        movzx   eax,as_u8 [esi+1]
        lea     esi,[esi+2+eax]
        lods    as_u8 [esi]
        cmp     [as_base_code],1
        if_above        as_irps_name_ok
        cmp     al,':'
        if_equal        as_irp_with_default_value
        cmp     al,'='
        if_equal        as_irp_with_default_value
        cmp     al,'*'
        if_not_equal    as_irp_name_ok
        lods    as_u8 [esi]
      as_irp_name_ok:
        cmp     al,','
        if_not_equal    as_invalid_macro_arguments
        jmp     as_irp_parameters_start
      as_irp_with_default_value:
        xor     ebp,ebp
        or      [as_skip_default_argument_value],-1
        call    as_skip_macro_argument_value
        cmp     as_u8 [esi],','
        if_not_equal    as_invalid_macro_arguments
        inc     esi
        jmp     as_irp_parameters_start
      as_irps_name_ok:
        cmp     al,','
        if_not_equal    as_invalid_macro_arguments
        cmp     [as_base_code],3
        if_equal        as_irp_parameters_start
        mov     al,[esi]
        or      al,al
        if_zero as_instant_macro_done
        cmp     al,'{'
        if_equal        as_instant_macro_done
      as_irp_parameters_start:
        xor     eax,eax
        push    [as_free_additional_memory]
        push    [as_macro_symbols]
        mov     [as_macro_symbols],eax
        push    [as_counter_limit]
        mov     [as_counter_limit],eax
        mov     [as_struc_name],eax
        cmp     [as_base_code],3
        if_equal        as_get_irpv_parameter
        mov     ebx,esi
        cmp     [as_base_code],2
        if_equal        as_get_irps_parameter
        mov     edx,[as_parameters_end]
        promote_edx
        mov     al,[edx]
        push    eax
        mov     as_u8 [edx],0
      as_get_irp_parameter:
        inc     [as_counter_limit]
        mov     esi,[as_instant_macro_start]
        promote_esi
        inc     esi
        call    as_get_macro_argument
        cmp     as_u8 [ebx],','
        if_not_equal    as_irp_parameters_end
        inc     ebx
        jmp     as_get_irp_parameter
      as_irp_parameters_end:
        mov     esi,ebx
        pop     eax
        mov     [esi],al
        jmp     as_instant_macro_parameters_ok
      as_get_irps_parameter:
        mov     esi,[as_instant_macro_start]
        promote_esi
        inc     esi
        lods    as_u8 [esi]
        movzx   ecx,al
        inc     [as_counter_limit]
        mov     eax,[as_counter_limit]
        call    as_add_macro_symbol
        mov     [edx+12],ebx
        cmp     as_u8 [ebx],1Ah
        if_equal        as_irps_symbol
        cmp     as_u8 [ebx],22h
        if_equal        as_irps_quoted_string
        mov     eax,1
        jmp     as_irps_parameter_ok
      as_irps_quoted_string:
        mov     eax,[ebx+1]
        add     eax,1+4
        jmp     as_irps_parameter_ok
      as_irps_symbol:
        movzx   eax,as_u8 [ebx+1]
        add     eax,1+1
      as_irps_parameter_ok:
        mov     [edx+8],eax
        add     ebx,eax
        cmp     as_u8 [ebx],0
        if_equal        as_irps_parameters_end
        cmp     as_u8 [ebx],'{'
        if_not_equal    as_get_irps_parameter
      as_irps_parameters_end:
        mov     esi,ebx
        jmp     as_instant_macro_parameters_ok
      as_get_irpv_parameter:
        lods    as_u8 [esi]
        cmp     al,1Ah
        if_not_equal    as_invalid_macro_arguments
        lods    as_u8 [esi]
        mov     ebp,esi
        mov     cl,al
        mov     ch,10b
        call    as_get_preprocessor_symbol
        if_carry        as_instant_macro_finish
        test    edx,edx
        if_zero as_invalid_use_of_symbol
        push    edx
      as_mark_variable_value:
        cmp     as_u32 [edx+12],0
        if_zero as_next_variable_value
        inc     [as_counter_limit]
        mov     [edx+4],ebp
      as_next_variable_value:
        mov     edx,[edx]
        or      edx,edx
        if_zero as_variable_values_marked
        mov     eax,[edx+4]
        cmp     eax,1
        if_below_equal  as_next_variable_value
        mov     esi,ebp
        movzx   ecx,as_u8 [esi-1]
        xchg    edi,eax
        repe    cmps as_u8 [esi],[edi]
        xchg    edi,eax
        if_equal        as_mark_variable_value
        jmp     as_next_variable_value
      as_variable_values_marked:
        pop     edx
        push    [as_counter_limit]
      as_add_irpv_value:
        push    edx
        mov     esi,[as_instant_macro_start]
        promote_esi
        inc     esi
        lods    as_u8 [esi]
        movzx   ecx,al
        mov     eax,[esp+4]
        call    as_add_macro_symbol
        mov     ebx,edx
        pop     edx
        mov     ecx,[edx+12]
        mov     eax,[edx+8]
        ; skip leading comma separator stored by `define`
        or      ecx,ecx
        if_zero as_irpv_value_ptr_ok
        cmp     as_u8 [eax],','
        if_not_equal    as_irpv_value_ptr_ok
        inc     eax
        dec     ecx
      as_irpv_value_ptr_ok:
        mov     [ebx+12],eax
        mov     [ebx+8],ecx
      as_collect_next_variable_value:
        mov     edx,[edx]
        or      edx,edx
        if_zero as_variable_values_collected
        cmp     ebp,[edx+4]
        if_not_equal    as_collect_next_variable_value
        dec     as_u32 [esp]
        if_not_zero     as_add_irpv_value
      as_variable_values_collected:
        pop     eax
        mov     esi,ebp
        movzx   ecx,as_u8 [esi-1]
        add     esi,ecx
        cmp     as_u8 [esi],0
        if_equal        as_instant_macro_parameters_ok
        cmp     as_u8 [esi],'{'
        if_not_equal    as_invalid_macro_arguments
        jmp     as_instant_macro_parameters_ok

as_do_match:
        mov     ebx,esi
        call    as_skip_pattern
        call    as_exact_match
        mov     edx,edi
        mov     al,[ebx]
        cmp     al,1Ah
        if_equal        as_free_match
        cmp     al,','
        if_not_equal    as_instant_macro_done
        cmp     esi,[as_parameters_end]
        if_equal        as_matched_pattern
        jmp     as_instant_macro_done
      as_free_match:
        add     edx,12
        cmp     edx,[as_memory_end]
        if_above        as_out_of_memory
        mov     [edx-12],ebx
        mov     [edx-8],esi
        call    as_skip_match_element
        if_carry        as_try_different_matching
        mov     [edx-4],esi
        movzx   eax,as_u8 [ebx+1]
        lea     ebx,[ebx+2+eax]
        cmp     as_u8 [ebx],1Ah
        if_equal        as_free_match
      as_find_exact_match:
        call    as_exact_match
        cmp     esi,[as_parameters_end]
        if_equal        as_end_matching
        cmp     as_u8 [ebx],1Ah
        if_equal        as_free_match
        mov     ebx,[edx-12]
        movzx   eax,as_u8 [ebx+1]
        lea     ebx,[ebx+2+eax]
        mov     esi,[edx-4]
        jmp     as_match_more_elements
      as_try_different_matching:
        sub     edx,12
        cmp     edx,edi
        if_equal        as_instant_macro_done
        mov     ebx,[edx-12]
        movzx   eax,as_u8 [ebx+1]
        lea     ebx,[ebx+2+eax]
        cmp     as_u8 [ebx],1Ah
        if_equal        as_try_different_matching
        mov     esi,[edx-4]
      as_match_more_elements:
        call    as_skip_match_element
        if_carry        as_try_different_matching
        mov     [edx-4],esi
        jmp     as_find_exact_match
      as_skip_match_element:
        cmp     esi,[as_parameters_end]
        if_equal        as_cannot_match
        mov     al,[esi]
        cmp     al,1Ah
        if_equal        as_skip_match_symbol
        cmp     al,22h
        if_equal        as_skip_match_quoted_string
        add     esi,1
        ret
      as_skip_match_quoted_string:
        mov     eax,[esi+1]
        add     esi,5
        jmp     as_skip_match_ok
      as_skip_match_symbol:
        movzx   eax,as_u8 [esi+1]
        add     esi,2
      as_skip_match_ok:
        add     esi,eax
        ret
      as_cannot_match:
        set_carry
        ret
      as_exact_match:
        cmp     esi,[as_parameters_end]
        if_equal        as_exact_match_complete
        mov     ah,[esi]
        mov     al,[ebx]
        cmp     al,','
        if_equal        as_exact_match_complete
        cmp     al,1Ah
        if_equal        as_exact_match_complete
        cmp     al,'='
        if_equal        as_match_verbatim
        call    as_match_elements
        if_equal        as_exact_match
      as_exact_match_complete:
        ret
      as_match_verbatim:
        inc     ebx
        call    as_match_elements
        if_equal        as_exact_match
        dec     ebx
        ret
      as_match_elements:
        mov     al,[ebx]
        cmp     al,1Ah
        if_equal        as_match_symbols
        cmp     al,22h
        if_equal        as_match_quoted_strings
        cmp     al,ah
        if_equal        as_token_delimiters_matched
        ret
      as_token_delimiters_matched:
        lea     ebx,[ebx+1]
        lea     esi,[esi+1]
        ret
      as_match_quoted_strings:
        mov     ecx,[ebx+1]
        add     ecx,5
        jmp     as_compare_elements
      as_match_symbols:
        movzx   ecx,as_u8 [ebx+1]
        add     ecx,2
      as_compare_elements:
        mov     eax,esi
        mov     ebp,edi
        mov     edi,ebx
        repe    cmps as_u8 [esi],[edi]
        if_not_equal    as_elements_mismatch
        mov     ebx,edi
        mov     edi,ebp
        ret
      as_elements_mismatch:
        mov     esi,eax
        mov     edi,ebp
        ret
      as_end_matching:
        cmp     as_u8 [ebx],','
        if_not_equal    as_instant_macro_done
      as_matched_pattern:
        xor     eax,eax
        push    [as_free_additional_memory]
        push    [as_macro_symbols]
        mov     [as_macro_symbols],eax
        push    [as_counter_limit]
        mov     [as_counter_limit],eax
        mov     [as_struc_name],eax
        push    esi edi edx
      as_add_matched_symbol:
        cmp     edi,[esp]
        if_equal        as_matched_symbols_ok
        mov     esi,[edi]
        inc     esi
        lods    as_u8 [esi]
        movzx   ecx,al
        xor     eax,eax
        call    as_add_macro_symbol
        mov     eax,[edi+4]
        mov     as_u32 [edx+12],eax
        mov     ecx,[edi+8]
        sub     ecx,eax
        mov     as_u32 [edx+8],ecx
        add     edi,12
        jmp     as_add_matched_symbol
      as_matched_symbols_ok:
        pop     edx edi esi
        jmp     as_instant_macro_parameters_ok

as_process_macro:
        push    as_u32 [as_macro_status]
        or      [as_macro_status],10h
        push    [as_counter]
        push    [as_macro_block]
        push    [as_macro_block_line]
        push    [as_macro_block_line_number]
        push    [as_struc_label]
        push    [as_struc_name]
        push    eax
        push    [as_current_line]
        lods    as_u8 [esi]
        cmp     al,'{'
        if_equal        as_macro_instructions_start
        or      al,al
        if_not_zero     as_unexpected_characters
      as_find_macro_instructions:
        mov     [as_macro_line],esi
        add     esi,16+2
        lods    as_u8 [esi]
        or      al,al
        if_zero as_find_macro_instructions
        cmp     al,'{'
        if_equal        as_macro_instructions_start
        cmp     al,3Bh
        if_not_equal    as_unexpected_characters
        call    as_skip_foreign_symbol
        jmp     as_find_macro_instructions
      as_macro_instructions_start:
        mov     ecx,80000000h
        mov     [as_macro_block],esi
        mov     eax,[as_macro_line]
        mov     [as_macro_block_line],eax
        mov     [as_macro_block_line_number],ecx
        xor     eax,eax
        mov     [as_counter],eax
        cmp     [as_counter_limit],eax
        if_equal        as_process_macro_line
        inc     [as_counter]
      as_process_macro_line:
        lods    as_u8 [esi]
        or      al,al
        if_zero as_process_next_line
        cmp     al,'}'
        if_equal        as_macro_block_processed
        dec     esi
        mov     [as_current_line],edi
        lea     eax,[edi+10h]
        cmp     eax,[as_memory_end]
        if_above_equal  as_out_of_memory
        mov     eax,[esp+4]
        or      eax,eax
        if_zero as_instant_macro_line_header
        stos    as_u32 [edi]
        mov     eax,ecx
        stos    as_u32 [edi]
        mov     eax,[esp]
        stos    as_u32 [edi]
        mov     eax,[as_macro_line]
        stos    as_u32 [edi]
        jmp     as_macro_line_header_ok
      as_instant_macro_line_header:
        mov     eax,[esp]
        add     eax,16
      as_find_defining_directive:
        inc     eax
        cmp     as_u8 [eax-1],3Bh
        if_equal        as_defining_directive_ok
        cmp     as_u8 [eax-1],1Ah
        if_not_equal    as_find_defining_directive
        push    eax
        movzx   eax,as_u8 [eax]
        inc     eax
        add     [esp],eax
        pop     eax
        jmp     as_find_defining_directive
      as_defining_directive_ok:
        stos    as_u32 [edi]
        mov     eax,ecx
        stos    as_u32 [edi]
        mov     eax,[as_macro_line]
        stos    as_u32 [edi]
        stos    as_u32 [edi]
      as_macro_line_header_ok:
        or      [as_macro_status],20h
        push    ebx ecx
        test    [as_macro_status],0Fh
        if_zero as_process_macro_line_element
        mov     ax,3Bh
        stos    as_u16 [edi]
      as_process_macro_line_element:
        lea     eax,[edi+100h]
        cmp     eax,[as_memory_end]
        if_above_equal  as_out_of_memory
        lods    as_u8 [esi]
        cmp     al,'}'
        if_equal        as_macro_line_processed
        or      al,al
        if_zero as_macro_line_processed
        cmp     al,1Ah
        if_equal        as_process_macro_symbol
        cmp     al,3Bh
        if_equal        as_macro_foreign_line
        and     [as_macro_status],not 20h
        stos    as_u8 [edi]
        cmp     al,22h
        if_not_equal    as_process_macro_line_element
      as_copy_macro_string:
        mov     ecx,[esi]
        add     ecx,4
        call    as_move_data
        jmp     as_process_macro_line_element
      as_process_macro_symbol:
        push    esi edi
        test    [as_macro_status],20h
        if_zero as_not_macro_directive
        movzx   ecx,as_u8 [esi]
        inc     esi
        mov     edi,as_macro_directives
        call    as_get_directive
        if_not_carry    as_process_macro_directive
        dec     esi
        jmp     as_not_macro_directive
      as_process_macro_directive:
        mov     edx,eax
        pop     edi eax
        mov     as_u8 [edi],0
        inc     edi
        pop     ecx ebx
        jmp     near edx
      as_not_macro_directive:
        and     [as_macro_status],not 20h
        movzx   ecx,as_u8 [esi]
        inc     esi
        mov     eax,[as_counter]
        call    as_get_macro_symbol
        if_not_carry    as_group_macro_symbol
        xor     eax,eax
        cmp     [as_counter],eax
        if_equal        as_multiple_macro_symbol_values
        call    as_get_macro_symbol
        if_carry        as_not_macro_symbol
      as_replace_macro_symbol:
        pop     edi eax
        mov     ecx,[edx+8]
        mov     edx,[edx+12]
        or      edx,edx
        if_zero as_replace_macro_counter
        and     ecx,not 80000000h
        xchg    esi,edx
        call    as_move_data
        mov     esi,edx
        jmp     as_process_macro_line_element
      as_group_macro_symbol:
        xor     eax,eax
        cmp     [as_counter],eax
        if_equal        as_replace_macro_symbol
        push    esi edx
        sub     esi,ecx
        call    as_get_macro_symbol
        mov     ebx,edx
        pop     edx esi
        if_carry        as_replace_macro_symbol
        cmp     edx,ebx
        if_above        as_replace_macro_symbol
        mov     edx,ebx
        jmp     as_replace_macro_symbol
      as_multiple_macro_symbol_values:
        inc     eax
        push    eax
        call    as_get_macro_symbol
        pop     eax
        if_carry        as_not_macro_symbol
        pop     edi
        push    ecx
        mov     ecx,[edx+8]
        mov     edx,[edx+12]
        xchg    esi,edx
        bit_test_reset  ecx,31
        if_carry        as_enclose_macro_symbol_value
        rep     movs as_u8 [edi],[esi]
        jmp     as_macro_symbol_value_ok
      as_enclose_macro_symbol_value:
        mov     as_u8 [edi],'<'
        inc     edi
        rep     movs as_u8 [edi],[esi]
        mov     as_u8 [edi],'>'
        inc     edi
      as_macro_symbol_value_ok:
        cmp     eax,[as_counter_limit]
        if_equal        as_multiple_macro_symbol_values_ok
        mov     as_u8 [edi],','
        inc     edi
        mov     esi,edx
        pop     ecx
        push    edi
        sub     esi,ecx
        jmp     as_multiple_macro_symbol_values
      as_multiple_macro_symbol_values_ok:
        pop     ecx eax
        mov     esi,edx
        jmp     as_process_macro_line_element
      as_replace_macro_counter:
        mov     eax,[as_counter]
        and     eax,not 80000000h
        if_zero as_group_macro_counter
        add     ecx,eax
        dec     ecx
        call    as_store_number_symbol
        jmp     as_process_macro_line_element
      as_group_macro_counter:
        mov     edx,ecx
        xor     ecx,ecx
      as_multiple_macro_counter_values:
        push    ecx edx
        add     ecx,edx
        call    as_store_number_symbol
        pop     edx ecx
        inc     ecx
        cmp     ecx,[as_counter_limit]
        if_equal        as_process_macro_line_element
        mov     as_u8 [edi],','
        inc     edi
        jmp     as_multiple_macro_counter_values
      as_store_number_symbol:
        cmp     ecx,0
        if_greater_equal        as_numer_symbol_sign_ok
        negate  ecx
        mov     al,'-'
        stos    as_u8 [edi]
      as_numer_symbol_sign_ok:
        mov     ax,1Ah
        stos    as_u16 [edi]
        push    edi
        mov     eax,ecx
        mov     ecx,1000000000
        xor     edx,edx
        xor     bl,bl
      as_store_number_digits:
        div     ecx
        push    edx
        or      bl,bl
        if_not_zero     as_store_number_digit
        cmp     ecx,1
        if_equal        as_store_number_digit
        or      al,al
        if_zero as_number_digit_ok
        not     bl
      as_store_number_digit:
        add     al,30h
        stos    as_u8 [edi]
      as_number_digit_ok:
        mov     eax,ecx
        xor     edx,edx
        mov     ecx,10
        div     ecx
        mov     ecx,eax
        pop     eax
        or      ecx,ecx
        if_not_zero     as_store_number_digits
        pop     ebx
        mov     eax,edi
        sub     eax,ebx
        mov     [ebx-1],al
        ret
      as_not_macro_symbol:
        pop     edi esi
        mov     al,1Ah
        stos    as_u8 [edi]
        mov     al,[esi]
        inc     esi
        stos    as_u8 [edi]
        cmp     as_u8 [esi],'.'
        if_not_equal    as_copy_raw_symbol
        mov     ebx,[esp+8+8]
        or      ebx,ebx
        if_zero as_copy_raw_symbol
        cmp     al,1
        if_equal        as_copy_struc_name
        xchg    esi,ebx
        movzx   ecx,as_u8 [esi-1]
        add     [edi-1],cl
        if_carry        as_name_too_long
        rep     movs as_u8 [edi],[esi]
        xchg    esi,ebx
      as_copy_raw_symbol:
        movzx   ecx,al
        rep     movs as_u8 [edi],[esi]
        jmp     as_process_macro_line_element
      as_copy_struc_name:
        inc     esi
        xchg    esi,ebx
        movzx   ecx,as_u8 [esi-1]
        mov     [edi-1],cl
        rep     movs as_u8 [edi],[esi]
        xchg    esi,ebx
        mov     eax,[esp+8+12]
        cmp     as_u8 [eax],3Bh
        if_equal        as_process_macro_line_element
        cmp     as_u8 [eax],1Ah
        if_not_equal    as_disable_replaced_struc_name
        mov     as_u8 [eax],3Bh
        jmp     as_process_macro_line_element
      as_disable_replaced_struc_name:
        mov     ebx,[esp+8+8]
        push    esi edi
        lea     edi,[ebx-3]
        lea     esi,[edi-2]
        lea     ecx,[esi+1]
        sub     ecx,eax
        set_direction
        rep     movs as_u8 [edi],[esi]
        clear_direction
        mov     as_u16 [eax],3Bh
        pop     edi esi
        jmp     as_process_macro_line_element
      as_skip_foreign_symbol:
        lods    as_u8 [esi]
        movzx   eax,al
        add     esi,eax
      as_skip_foreign_line:
        lods    as_u8 [esi]
        cmp     al,1Ah
        if_equal        as_skip_foreign_symbol
        cmp     al,3Bh
        if_equal        as_skip_foreign_symbol
        cmp     al,22h
        if_equal        as_skip_foreign_string
        or      al,al
        if_not_zero     as_skip_foreign_line
        ret
      as_skip_foreign_string:
        lods    as_u32 [esi]
        add     esi,eax
        jmp     as_skip_foreign_line
      as_macro_foreign_line:
        call    as_skip_foreign_symbol
      as_macro_line_processed:
        mov     as_u8 [edi],0
        inc     edi
        push    eax
        call    as_preprocess_line
        pop     eax
        pop     ecx ebx
        cmp     al,'}'
        if_equal        as_macro_block_processed
      as_process_next_line:
        inc     ecx
        mov     [as_macro_line],esi
        add     esi,16+2
        jmp     as_process_macro_line
      as_macro_block_processed:
        call    as_close_macro_block
        if_carry        as_process_macro_line
        pop     [as_current_line]
        add     esp,12
        pop     [as_macro_block_line_number]
        pop     [as_macro_block_line]
        pop     [as_macro_block]
        pop     [as_counter]
        pop     eax
        and     al,0F0h
        and     [as_macro_status],0Fh
        or      [as_macro_status],al
        ret

as_local_symbols:
        lods    as_u8 [esi]
        cmp     al,1Ah
        if_not_equal    as_invalid_argument
        mov     as_u8 [edi-1],3Bh
        xor     al,al
        stos    as_u8 [edi]
      as_make_local_symbol:
        push    ecx
        lods    as_u8 [esi]
        movzx   ecx,al
        mov     eax,[as_counter]
        call    as_add_macro_symbol
        mov     [edx+12],edi
        movzx   eax,[as_locals_counter]
        add     eax,ecx
        inc     eax
        cmp     eax,100h
        if_above_equal  as_name_too_long
        lea     ebp,[edi+2+eax]
        cmp     ebp,[as_memory_end]
        if_above_equal  as_out_of_memory
        mov     ah,al
        mov     al,1Ah
        stos    as_u16 [edi]
        rep     movs as_u8 [edi],[esi]
        mov     al,'?'
        stos    as_u8 [edi]
        push    esi
        mov     esi,as_locals_counter+1
        movzx   ecx,[as_locals_counter]
        rep     movs as_u8 [edi],[esi]
        pop     esi
        mov     eax,edi
        sub     eax,[edx+12]
        mov     [edx+8],eax
        xor     al,al
        stos    as_u8 [edi]
        mov     eax,as_locals_counter
        movzx   ecx,as_u8 [eax]
      as_counter_loop:
        inc     as_u8 [eax+ecx]
        cmp     as_u8 [eax+ecx],'9'+1
        if_below        as_counter_ok
        if_not_equal    as_letter_digit
        mov     as_u8 [eax+ecx],'A'
        jmp     as_counter_ok
      as_letter_digit:
        cmp     as_u8 [eax+ecx],'Z'+1
        if_below        as_counter_ok
        if_not_equal    as_small_letter_digit
        mov     as_u8 [eax+ecx],'a'
        jmp     as_counter_ok
      as_small_letter_digit:
        cmp     as_u8 [eax+ecx],'z'+1
        if_below        as_counter_ok
        mov     as_u8 [eax+ecx],'0'
        loop    as_counter_loop
        inc     as_u8 [eax]
        movzx   ecx,as_u8 [eax]
        mov     as_u8 [eax+ecx],'0'
      as_counter_ok:
        pop     ecx
        lods    as_u8 [esi]
        cmp     al,'}'
        if_equal        as_macro_block_processed
        or      al,al
        if_zero as_process_next_line
        cmp     al,','
        if_not_equal    as_extra_characters_on_line
        dec     edi
        lods    as_u8 [esi]
        cmp     al,1Ah
        if_equal        as_make_local_symbol
        jmp     as_invalid_argument
as_common_block:
        call    as_close_macro_block
        if_carry        as_process_macro_line
        mov     [as_counter],0
        jmp     as_new_macro_block
as_forward_block:
        cmp     [as_counter_limit],0
        if_equal        as_common_block
        call    as_close_macro_block
        if_carry        as_process_macro_line
        mov     [as_counter],1
        jmp     as_new_macro_block
as_reverse_block:
        cmp     [as_counter_limit],0
        if_equal        as_common_block
        call    as_close_macro_block
        if_carry        as_process_macro_line
        mov     eax,[as_counter_limit]
        or      eax,80000000h
        mov     [as_counter],eax
      as_new_macro_block:
        mov     [as_macro_block],esi
        mov     eax,[as_macro_line]
        mov     [as_macro_block_line],eax
        mov     [as_macro_block_line_number],ecx
        jmp     as_process_macro_line
as_close_macro_block:
        cmp     esi,[as_macro_block]
        if_equal        as_block_closed
        cmp     [as_counter],0
        if_equal        as_block_closed
        if_less as_reverse_counter
        mov     eax,[as_counter]
        cmp     eax,[as_counter_limit]
        if_equal        as_block_closed
        inc     [as_counter]
        jmp     as_continue_block
      as_reverse_counter:
        mov     eax,[as_counter]
        dec     eax
        cmp     eax,80000000h
        if_equal        as_block_closed
        mov     [as_counter],eax
      as_continue_block:
        mov     esi,[as_macro_block]
        promote_esi
        mov     eax,[as_macro_block_line]
        mov     [as_macro_line],eax
        mov     ecx,[as_macro_block_line_number]
        promote_ecx
        set_carry
        ret
      as_block_closed:
        clear_carry
        ret
as_get_macro_symbol:
        push    ecx
        call    as_find_macro_symbol_leaf
        if_carry        as_macro_symbol_not_found
        mov     edx,[ebx]
        mov     ebx,esi
      as_try_macro_symbol:
        or      edx,edx
        if_zero as_macro_symbol_not_found
        mov     ecx,[esp]
        mov     edi,[edx+4]
        repe    cmps as_u8 [esi],[edi]
        if_equal        as_macro_symbol_found
        mov     esi,ebx
        mov     edx,[edx]
        jmp     as_try_macro_symbol
      as_macro_symbol_found:
        pop     ecx
        clear_carry
        ret
      as_macro_symbol_not_found:
        pop     ecx
        set_carry
        ret
      as_find_macro_symbol_leaf:
        shl     eax,8
        mov     al,cl
        mov     ebp,eax
        mov     ebx,as_macro_symbols
      as_follow_macro_symbols_tree:
        mov     edx,[ebx]
        or      edx,edx
        if_zero as_no_such_macro_symbol
        xor     eax,eax
        shr     ebp,1
        add_with_carry  eax,0
        lea     ebx,[edx+eax*4]
        or      ebp,ebp
        if_not_zero     as_follow_macro_symbols_tree
        add     ebx,8
        clear_carry
        ret
      as_no_such_macro_symbol:
        set_carry
        ret
as_add_macro_symbol:
        push    ebx ebp
        call    as_find_macro_symbol_leaf
        if_carry        as_extend_macro_symbol_tree
        mov     eax,[ebx]
      as_make_macro_symbol:
        mov     edx,[as_free_additional_memory]
        promote_edx
        add     edx,16
        cmp     edx,[as_labels_list]
        if_above        as_out_of_memory
        xchg    edx,[as_free_additional_memory]
        mov     [ebx],edx
        mov     [edx],eax
        mov     [edx+4],esi
        pop     ebp ebx
        ret
      as_extend_macro_symbol_tree:
        mov     edx,[as_free_additional_memory]
        promote_edx
        add     edx,16
        cmp     edx,[as_labels_list]
        if_above        as_out_of_memory
        xchg    edx,[as_free_additional_memory]
        xor     eax,eax
        mov     [edx],eax
        mov     [edx+4],eax
        mov     [edx+8],eax
        mov     [edx+12],eax
        shr     ebp,1
        add_with_carry  eax,0
        mov     [ebx],edx
        lea     ebx,[edx+eax*4]
        or      ebp,ebp
        if_not_zero     as_extend_macro_symbol_tree
        add     ebx,8
        xor     eax,eax
        jmp     as_make_macro_symbol

as_include_file:
        lods    as_u8 [esi]
        cmp     al,22h
        if_not_equal    as_invalid_argument
        lods    as_u32 [esi]
        cmp     as_u8 [esi+eax],0
        if_not_equal    as_extra_characters_on_line
        push    esi
        push    edi
        mov     ebx,[as_current_line]
        promote_ebx
      as_find_current_file_path:
        mov     esi,[ebx]
        test    as_u8 [ebx+7],80h
        if_zero as_copy_current_file_path
        mov     ebx,[ebx+8]
        jmp     as_find_current_file_path
      as_copy_current_file_path:
        lods    as_u8 [esi]
        stos    as_u8 [edi]
        or      al,al
        if_not_zero     as_copy_current_file_path
      as_cut_current_file_name:
        cmp     edi,[esp]
        if_equal        as_current_file_path_ok
        cmp     as_u8 [edi-1],'\'
        if_equal        as_current_file_path_ok
        cmp     as_u8 [edi-1],'/'
        if_equal        as_current_file_path_ok
        dec     edi
        jmp     as_cut_current_file_name
      as_current_file_path_ok:
        mov     esi,[esp+4]
        call    as_expand_path
        pop     edx
        mov     esi,edx
        call    as_open
        if_not_carry    as_include_path_ok
        mov     ebp,[as_include_paths]
      as_try_include_directories:
        mov     edi,esi
        mov     esi,ebp
        cmp     as_u8 [esi],0
        if_equal        as_try_in_current_directory
        push    ebp
        push    edi
        call    as_get_include_directory
        mov     [esp+4],esi
        mov     esi,[esp+8]
        call    as_expand_path
        pop     edx
        mov     esi,edx
        call    as_open
        pop     ebp
        if_not_carry    as_include_path_ok
        jmp     as_try_include_directories
        mov     edi,esi
      as_try_in_current_directory:
        mov     esi,[esp]
        push    edi
        call    as_expand_path
        pop     edx
        mov     esi,edx
        call    as_open
        if_carry        as_file_not_found
      as_include_path_ok:
        mov     edi,[esp]
      as_copy_preprocessed_path:
        lods    as_u8 [esi]
        stos    as_u8 [edi]
        or      al,al
        if_not_zero     as_copy_preprocessed_path
        pop     esi
        lea     ecx,[edi-1]
        sub     ecx,esi
        mov     [esi-4],ecx
        push    as_u32 [as_macro_status]
        and     [as_macro_status],0Fh
        call    as_preprocess_file
        pop     eax
        and     al,0F0h
        and     [as_macro_status],0Fh
        or      [as_macro_status],al
        jmp     as_line_preprocessed
