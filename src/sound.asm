%include "common.inc"

global sound_init, sound_play, sound_var, sound_at, sound_block, sound_mix
global sound_voices, sound_step, snd_len, snd_ptr, sound_keep, sound_keep_at
global sound_at_speed, sound_count, voices

extern set_sound, pos
extern echo_push

; a sound's numbers
SD_N        equ 0                   ; samples of one burst
SD_BURSTS   equ 4
SD_GAP      equ 8                   ; samples from one burst to the next
SD_WAVE     equ 12                  ; tone: 0 sine, 1 square, 2 saw
SD_FLAGS    equ 16                  ; 1 high pass the noise, 2 filter the tone too
SD_BGAIN    equ 20                  ; each burst this much of the last
SD_ATTACK   equ 24                  ; samples to full loudness
SD_TSTEP    equ 28                  ; tone: radians a sample
SD_TMUL     equ 32                  ; .. times this every sample (the sweep)
SD_TAMP     equ 36
SD_TDEC     equ 40                  ; .. fading by this every sample
SD_NAMP     equ 44                  ; noise
SD_NDEC     equ 48
SD_LPA      equ 52                  ; low pass coefficient
SD_LPSTEP   equ 56                  ; .. plus this every sample
SD_TREM     equ 60                  ; tremolo: radians a sample
SD_TDEPTH   equ 64
SD_BPITCH   equ 68                  ; each burst's tone this much higher
SD_GAIN     equ 72
SD_SIZE     equ 76

MAX_VOICES  equ 12
; (the voice record and the recorded sounds' ids are in common.inc)
MIX_MAX     equ 1024                ; most samples sound_mix makes at once
HEAR        equ 28                  ; nodes a sound in the world carries

; materials: sound 2 * m is the tap, 2 * m + 1 the breaking
M_STONE     equ 0
M_DIRT      equ 1
M_SAND      equ 2
M_WOOD      equ 3
M_CLOTH     equ 4
M_GLASS     equ 5
M_GRASS     equ 6
M_METAL     equ 7
M_NONE      equ 255

section .rodata
align 4
f_one:      dd 1.0
f_mone:     dd -1.0
f_half:     dd 0.5
f_two:      dd 2.0
f_2pi:      dd 6.28318531
f_inv2pi:   dd 0.159154943
f_inv2_31:  dd 4.65661287e-10
f_inv64:    dd 0.015625
f_lpmin:    dd 0.0005
f_full:     dd 32767.0
f_256:      dd 256.0
f_65536:    dd 65536.0
f_vary:     dd 0.16                 ; speed 0.92 .. 1.08 of the one asked for
f_varylo:   dd 0.92
f_inv_hear: dd 0.0357142857         ; 1 / HEAR
f_quiet:    dd 0.02
f_dirtput:  dd 1.35
f_inv16:    dd 1.52587891e-5        ; 1 / 65536
; how a block's tap is played: dig, (break), place, step - loudness, speed
kind_vol:   dd 0.70, 1.00, 0.85, 0.30
kind_speed: dd 1.00, 1.00, 0.78, 0.70
; blocks that do not sound like stone: first id, how many, material
mat_list:
    db B_DIRT, 1, M_DIRT
    db B_GRASS, 1, M_GRASS
    db B_SNOWDIRT, 1, M_DIRT
    db B_DRYGRASS, 1, M_DIRT
    db B_CLAY, 1, M_DIRT
    db B_FARMLAND, 1, M_DIRT
    db B_SAND, 1, M_SAND
    db B_DSAND, 1, M_SAND
    db B_GRAVEL, 1, M_SAND
    db B_SNOW, 1, M_SAND
    db B_LOG, 1, M_WOOD
    db B_PINELOG, 1, M_WOOD
    db B_PLANKS, 1, M_WOOD
    db B_CRAFTTABLE, 1, M_WOOD
    db B_TORCH, 1, M_WOOD
    db B_TORCH_WALL, 1, M_WOOD
    db B_FENCE, 5, M_WOOD           ; fence and gates
    db B_BED_FOOT, 3, M_WOOD        ; bed, dye maker
    db B_LEAVES, 1, M_CLOTH
    db B_CACTUS, 2, M_CLOTH         ; cactus, pine needles
    db B_TALLGRASS, 13, M_CLOTH     ; tall grass and crops
    db B_WOOL, 16, M_CLOTH
    db B_FLOWER_Y, 2, M_CLOTH
    db B_TNT, 1, M_CLOTH
    db B_SLIME, 1, M_CLOTH
    db B_IRONBLOCK, 4, M_METAL      ; iron, gold, diamond, coal blocks
    db B_GLASS, 1, M_GLASS
    db B_SGLASS, 17, M_GLASS        ; stained glass, beacon
    db B_BLUEBLOCK, 1, M_METAL
    db W_LAMP, 2, M_GLASS
    db W_RAIL, 22, M_METAL
    db W_DOOR, 6, M_WOOD
    db W_BIRCHLOG, 5, M_WOOD
    db B_AIR, 1, M_NONE
    db B_WATER, 1, M_NONE
    db B_WFLOW1, 7, M_NONE
    db B_LAVA, 4, M_NONE
    db B_FIRE, 1, M_NONE
    db B_PORTAL, 1, M_NONE
    db 0, 0, 0

section .data
snd_seed:   dd 0x1234ABCD           ; the noise (the same every run)
var_seed:   dd 0x2468ACE1           ; the speed of each play
sound_count: dd ALL_SOUNDS

section .bss
alignb 16
snd_pcm:    resw SOUND_SAMPLES
mix_acc:    resd MIX_MAX
snd_ptr:    resq ALL_SOUNDS
snd_len:    resd ALL_SOUNDS
voices:     resb MAX_VOICES * V_SIZE
voice_next: resd 1
sound_voices: resd 1                ; voices playing after the last mix
sound_ready: resd 1
step_dist:  resd 1                  ; nodes walked since the last step sound
snd_mat:    resb 256

section .rodata
; recorded sounds: 22050 Hz mono signed 16-bit (tools/prepsounds.py)
align 2
rec_cave1:  incbin "sounds/cave1.s16"
rec_cave1_len equ ($ - rec_cave1) / 2
rec_cave2:  incbin "sounds/cave2.s16"
rec_cave2_len equ ($ - rec_cave2) / 2
rec_cave3:  incbin "sounds/cave3.s16"
rec_cave3_len equ ($ - rec_cave3) / 2
rec_drip1:  incbin "sounds/drip1.s16"
rec_drip1_len equ ($ - rec_drip1) / 2
rec_drip2:  incbin "sounds/drip2.s16"
rec_drip2_len equ ($ - rec_drip2) / 2
rec_drip3:  incbin "sounds/drip3.s16"
rec_drip3_len equ ($ - rec_drip3) / 2
rec_drip4:  incbin "sounds/drip4.s16"
rec_drip4_len equ ($ - rec_drip4) / 2
rec_drip5:  incbin "sounds/drip5.s16"
rec_drip5_len equ ($ - rec_drip5) / 2
rec_roar:   incbin "sounds/roar.s16"
rec_roar_len equ ($ - rec_roar) / 2

section .text

; void sound_init(void) - make every sound (once)
; locals: [0] phase, [4] step, [8] tone amp, [12] noise amp, [16] lp,
;         [20] lp2, [24] a, [28] burst gain, [32] burst pitch, [36] scratch,
;         [40] sound, [44] burst
sound_init:
    ENTER_FN 48
    cmp dword [sound_ready], 0
    jne .out
    mov dword [sound_ready], 1
    ; the material of every block
    lea rsi, [mat_list]
.m:
    movzx eax, byte [rsi]
    movzx ecx, byte [rsi + 1]
    test ecx, ecx
    jz .m_done
    mov dl, [rsi + 2]
    lea rdi, [snd_mat]
.mf:
    mov [rdi + rax], dl
    inc eax
    dec ecx
    jnz .mf
    add rsi, 3
    jmp .m
.m_done:
    lea r12, [snd_pcm]
    mov dword [rsp + 40], 0
.sound:
    mov eax, [rsp + 40]
    cmp eax, NUM_SOUNDS
    jae .out
    imul ebx, eax, SD_SIZE
    lea rcx, [sound_defs]
    add rbx, rcx
    lea rcx, [snd_ptr]
    mov [rcx + rax*8], r12
    mov ecx, [rbx + SD_BURSTS]
    dec ecx
    imul ecx, [rbx + SD_GAP]
    add ecx, [rbx + SD_N]
    lea rdx, [snd_len]
    mov [rdx + rax*4], ecx
    mov r15d, [rbx + SD_N]
    mov dword [snd_seed], 0x1234ABCD    ; the same noise for every sound
    mov dword [rsp + 28], 0x3f800000
    mov dword [rsp + 32], 0x3f800000
    mov dword [rsp + 44], 0
.burst:
    mov dword [rsp], 0
    movss xmm0, [rbx + SD_TSTEP]
    mulss xmm0, [rsp + 32]
    movss [rsp + 4], xmm0
    mov eax, [rbx + SD_TAMP]
    mov [rsp + 8], eax
    mov eax, [rbx + SD_NAMP]
    mov [rsp + 12], eax
    mov dword [rsp + 16], 0
    mov dword [rsp + 20], 0
    mov eax, [rbx + SD_LPA]
    mov [rsp + 24], eax
    mov r13d, [rsp + 44]
    imul r13d, [rbx + SD_GAP]
    lea r13, [r12 + r13*2]          ; where this burst starts
    xor r14d, r14d
.s:
    cmp r14d, r15d
    jae .burst_done
    ; noise
    imul eax, [snd_seed], 1664525
    add eax, 1013904223
    mov [snd_seed], eax
    cvtsi2ss xmm0, eax
    mulss xmm0, [f_inv2_31]
    mulss xmm0, [rsp + 12]
    ; tone
    mov eax, [rbx + SD_WAVE]
    test eax, eax
    jnz .shaped
    fld dword [rsp]
    fsin
    fstp dword [rsp + 36]
    movss xmm1, [rsp + 36]
    jmp .tone
.shaped:
    movss xmm1, [rsp]
    mulss xmm1, [f_inv2pi]          ; 0 .. 1 through the cycle
    cmp eax, 1
    jne .saw
    comiss xmm1, [f_half]
    movss xmm1, [f_one]
    jb .tone
    movss xmm1, [f_mone]
    jmp .tone
.saw:
    addss xmm1, xmm1
    subss xmm1, [f_one]
.tone:
    mulss xmm1, [rsp + 8]
    ; two low passes in a row
    movss xmm2, [rsp + 24]
    movaps xmm3, xmm0
    test dword [rbx + SD_FLAGS], 2
    jz .lp
    addss xmm3, xmm1                ; the tone goes through too
.lp:
    movss xmm4, [rsp + 16]
    subss xmm3, xmm4
    mulss xmm3, xmm2
    addss xmm4, xmm3
    movss [rsp + 16], xmm4
    movss xmm5, [rsp + 20]
    subss xmm4, xmm5
    mulss xmm4, xmm2
    addss xmm5, xmm4
    movss [rsp + 20], xmm5          ; xmm5 = the filtered sound
    test dword [rbx + SD_FLAGS], 2
    jnz .env
    test dword [rbx + SD_FLAGS], 1
    jz .add_tone
    subss xmm0, xmm5                ; high pass: what the low pass took out
    movaps xmm5, xmm0
.add_tone:
    addss xmm5, xmm1
.env:
    ; in over the attack, out over the last 64 samples
    cvtsi2ss xmm3, r14d
    divss xmm3, [rbx + SD_ATTACK]
    minss xmm3, [f_one]
    mov eax, r15d
    dec eax
    sub eax, r14d
    cvtsi2ss xmm4, eax
    mulss xmm4, [f_inv64]
    minss xmm3, xmm4
    mulss xmm5, xmm3
    ; tremolo
    movss xmm3, [rbx + SD_TDEPTH]
    xorps xmm4, xmm4
    comiss xmm3, xmm4
    jbe .write
    cvtsi2ss xmm4, r14d
    mulss xmm4, [rbx + SD_TREM]
    movss [rsp + 36], xmm4
    fld dword [rsp + 36]
    fsin
    fstp dword [rsp + 36]
    movss xmm4, [rsp + 36]
    mulss xmm4, [f_half]
    addss xmm4, [f_half]
    mulss xmm4, xmm3
    movss xmm3, [f_one]
    subss xmm3, xmm4
    mulss xmm5, xmm3
.write:
    mulss xmm5, [rsp + 28]
    mulss xmm5, [rbx + SD_GAIN]
    mulss xmm5, [f_full]
    cvttss2si eax, xmm5
    movsx ecx, word [r13 + r14*2]
    add eax, ecx
    cmp eax, 32767
    jle .c1
    mov eax, 32767
.c1:
    cmp eax, -32767
    jge .c2
    mov eax, -32767
.c2:
    mov [r13 + r14*2], ax
    ; on to the next sample
    movss xmm0, [rsp]
    addss xmm0, [rsp + 4]
    comiss xmm0, [f_2pi]
    jbe .ph
    subss xmm0, [f_2pi]
.ph:
    movss [rsp], xmm0
    movss xmm0, [rsp + 4]
    mulss xmm0, [rbx + SD_TMUL]
    movss [rsp + 4], xmm0
    movss xmm0, [rsp + 8]
    mulss xmm0, [rbx + SD_TDEC]
    movss [rsp + 8], xmm0
    movss xmm0, [rsp + 12]
    mulss xmm0, [rbx + SD_NDEC]
    movss [rsp + 12], xmm0
    movss xmm0, [rsp + 24]
    addss xmm0, [rbx + SD_LPSTEP]
    maxss xmm0, [f_lpmin]
    minss xmm0, [f_one]
    movss [rsp + 24], xmm0
    inc r14d
    jmp .s
.burst_done:
    movss xmm0, [rsp + 28]
    mulss xmm0, [rbx + SD_BGAIN]
    movss [rsp + 28], xmm0
    movss xmm0, [rsp + 32]
    mulss xmm0, [rbx + SD_BPITCH]
    movss [rsp + 32], xmm0
    inc dword [rsp + 44]
    mov eax, [rsp + 44]
    cmp eax, [rbx + SD_BURSTS]
    jb .burst
    ; the next sound starts after this one
    mov eax, [rsp + 40]
    lea rcx, [snd_len]
    mov eax, [rcx + rax*4]
    lea r12, [r12 + rax*2]
    inc dword [rsp + 40]
    jmp .sound
.out:
    ; the recorded ones, as they are
%macro RECORDED 2
    lea rax, [%2]
    lea rcx, [snd_ptr]
    mov [rcx + (%1) * 8], rax
    lea rcx, [snd_len]
    mov dword [rcx + (%1) * 4], %2_len
%endmacro
    RECORDED S_CAVE1, rec_cave1
    RECORDED S_CAVE2, rec_cave2
    RECORDED S_CAVE3, rec_cave3
    RECORDED S_DRIP1, rec_drip1
    RECORDED S_DRIP1 + 1, rec_drip2
    RECORDED S_DRIP1 + 2, rec_drip3
    RECORDED S_DRIP1 + 3, rec_drip4
    RECORDED S_DRIP1 + 4, rec_drip5
    RECORDED S_ROAR, rec_roar
    LEAVE_FN

; voice *sound_play(int id, float loudness, float speed) - loudness 1 is
; the sound as made; speed 1 its own pitch. Returns the voice (0 if none:
; its loudness can be changed while it plays, see weather.asm)
sound_play:
    xor eax, eax
    cmp dword [set_sound], 0
    je .out
    cmp dword [sound_ready], 0
    je .out
    cmp edi, ALL_SOUNDS
    jae .out
    ; a free voice, or else the next in turn
    lea rax, [voices]
    xor ecx, ecx
.f:
    cmp dword [rax + V_ON], 0
    je .got
    add rax, V_SIZE
    inc ecx
    cmp ecx, MAX_VOICES
    jb .f
    mov ecx, [voice_next]
    inc ecx
    cmp ecx, MAX_VOICES
    jb .turn
    xor ecx, ecx
.turn:
    mov [voice_next], ecx
    shl ecx, 5
    lea rax, [voices]
    add rax, rcx
.got:
    lea rcx, [snd_ptr]
    mov rdx, [rcx + rdi*8]
    mov [rax + V_PTR], rdx
    lea rcx, [snd_len]
    mov edx, [rcx + rdi*4]
    mov [rax + V_LEN], edx
    mov qword [rax + V_POS], 0
    mulss xmm1, [f_65536]
    cvttss2si edx, xmm1
    cmp edx, 0x4000                 ; a quarter to four times the speed
    jge .s1
    mov edx, 0x4000
.s1:
    cmp edx, 0x40000
    jle .s2
    mov edx, 0x40000
.s2:
    mov [rax + V_STEP], edx
    mulss xmm0, [f_256]
    cvttss2si edx, xmm0
    cmp edx, 512
    jle .v1
    mov edx, 512
.v1:
    test edx, edx
    jle .out
    mov [rax + V_VOL], edx
    mov dword [rax + V_ON], 1
.out:
    ret

; xmm1 = xmm1 * (0.92 .. 1.08): no two plays quite alike
vary:
    imul eax, [var_seed], 1103515245
    add eax, 12345
    mov [var_seed], eax
    shr eax, 16
    and eax, 0xff
    cvtsi2ss xmm4, eax
    mulss xmm4, [f_vary]
    divss xmm4, [f_256]
    addss xmm4, [f_varylo]
    mulss xmm1, xmm4
    ret

; void sound_var(int id, float loudness, float speed) - sound_play at a
; speed a little off the one given
sound_var:
    call vary
    jmp sound_play

; void sound_at(int id, float x, float y, float z, float loudness) - a
; sound somewhere in the world: quieter with distance, silent past HEAR
sound_at:
    movss xmm5, [f_one]
; the same at speed xmm5
sound_at_speed:
    subss xmm0, [pos]
    subss xmm1, [pos + 4]
    subss xmm2, [pos + 8]
    mulss xmm0, xmm0
    mulss xmm1, xmm1
    mulss xmm2, xmm2
    addss xmm0, xmm1
    addss xmm0, xmm2
    sqrtss xmm0, xmm0
    mulss xmm0, [f_inv_hear]
    movss xmm1, [f_one]
    subss xmm1, xmm0
    xorps xmm0, xmm0
    maxss xmm1, xmm0
    mulss xmm1, xmm1
    mulss xmm3, xmm1
    comiss xmm3, [f_quiet]
    jb .out
    movaps xmm0, xmm3
    movaps xmm1, xmm5
    jmp sound_var
.out:
    ret

; void sound_block(int block, int kind, float x, float y, float z) - the
; sound of a block: kind 0 a dig tap, 1 breaking, 2 placed, 3 a step on it
; (the player's own: x, y, z are not looked at)
sound_block:
    movzx edi, dil
    lea rax, [snd_mat]
    movzx eax, byte [rax + rdi]
    cmp eax, M_NONE
    je .out
    lea edi, [rax + rax]
    cmp esi, 1
    jne .tap
    inc edi
.tap:
    lea rax, [kind_vol]
    movss xmm3, [rax + rsi*4]
    lea rax, [kind_speed]
    movss xmm5, [rax + rsi*4]
    cmp esi, 2                      ; dirt put down: slowed down it boomed
    jne .notdirt                    ; like a dropped bin, so higher and softer
    cmp edi, 2 * M_DIRT
    jne .notdirt
    movss xmm5, [f_dirtput]
    mulss xmm3, [f_half]
.notdirt:
    cmp esi, 3
    jne sound_at_speed
    movaps xmm0, xmm3
    movaps xmm1, xmm5
    call echo_push                  ; in a cave a step comes back off the rock
    jmp sound_var
.out:
    ret

; void sound_step(int block, float walked) - the player walked this far on
; this block: a step sound every 2.2 nodes
sound_step:
    addss xmm0, [step_dist]
    movss [step_dist], xmm0
    comiss xmm0, [f_stride]
    jb .out
    mov dword [step_dist], 0
    mov esi, 3
    jmp sound_block
.out:
    ret

; SFX and SFX_AT (common.inc) come here: [rsp + 8] = id | loudness % << 8 |
; speed % << 20. Nothing the caller has is changed.
%macro KEEP_ENTER 0
    push rbp
    mov rbp, rsp
    pushfq
    and rsp, -16
    sub rsp, 176
    mov [rsp], rax
    mov [rsp + 8], rcx
    mov [rsp + 16], rdx
    mov [rsp + 24], rsi
    mov [rsp + 32], rdi
    mov [rsp + 40], r8
    mov [rsp + 48], r9
    mov [rsp + 56], r10
    mov [rsp + 64], r11
    movups [rsp + 72], xmm0
    movups [rsp + 88], xmm1
    movups [rsp + 104], xmm2
    movups [rsp + 120], xmm3
    movups [rsp + 136], xmm4
    movups [rsp + 152], xmm5
%endmacro
%macro KEEP_LEAVE 0
    mov rax, [rsp]
    mov rcx, [rsp + 8]
    mov rdx, [rsp + 16]
    mov rsi, [rsp + 24]
    mov rdi, [rsp + 32]
    mov r8, [rsp + 40]
    mov r9, [rsp + 48]
    mov r10, [rsp + 56]
    mov r11, [rsp + 64]
    movups xmm0, [rsp + 72]
    movups xmm1, [rsp + 88]
    movups xmm2, [rsp + 104]
    movups xmm3, [rsp + 120]
    movups xmm4, [rsp + 136]
    movups xmm5, [rsp + 152]
    lea rsp, [rbp - 8]
    popfq
    pop rbp
    ret
%endmacro

sound_keep:
    KEEP_ENTER
    mov eax, [rbp + 16]
    movzx edi, al
    mov ecx, eax
    shr ecx, 8
    and ecx, 0xfff
    cvtsi2ss xmm0, ecx
    mulss xmm0, [f_pct]
    shr eax, 20
    cvtsi2ss xmm1, eax
    mulss xmm1, [f_pct]
    call sound_var
    KEEP_LEAVE

sound_keep_at:
    KEEP_ENTER
    mov eax, [rbp + 16]
    movzx edi, al
    mov ecx, eax
    shr ecx, 8
    and ecx, 0xfff
    cvtsi2ss xmm3, ecx
    mulss xmm3, [f_pct]
    shr eax, 20
    cvtsi2ss xmm5, eax
    mulss xmm5, [f_pct]
    call sound_at_speed
    KEEP_LEAVE

; void sound_mix(s16 *out, int samples) - the next samples of everything
; playing (silence when nothing is)
sound_mix:
    ENTER_FN 0
    mov r12, rdi
    mov r13d, esi
    cmp r13d, MIX_MAX
    jle .n
    mov r13d, MIX_MAX
.n:
    lea rdi, [mix_acc]
    xor eax, eax
    mov ecx, r13d
    rep stosd
    mov dword [sound_voices], 0
    lea rbx, [voices]
    xor r14d, r14d
.v:
    cmp dword [rbx + V_ON], 0
    je .vnext
    mov rsi, [rbx + V_PTR]
    mov r8, [rbx + V_POS]
    mov r9d, [rbx + V_STEP]
    mov r10d, [rbx + V_VOL]
    mov r11d, [rbx + V_LEN]
    lea rdi, [mix_acc]
    xor ecx, ecx
.vs:
    cmp ecx, r13d
    jae .vkeep
    mov rax, r8
    shr rax, 16
    cmp rax, r11
    jae .vend
    movsx eax, word [rsi + rax*2]
    imul eax, r10d
    sar eax, 8
    add [rdi + rcx*4], eax
    add r8, r9
    inc ecx
    jmp .vs
.vend:
    mov dword [rbx + V_ON], 0
    jmp .vnext
.vkeep:
    mov [rbx + V_POS], r8
    inc dword [sound_voices]
.vnext:
    add rbx, V_SIZE
    inc r14d
    cmp r14d, MAX_VOICES
    jb .v
    ; the volume setting (10 = as made), clipped
    imul r8d, [set_sound], 26
    lea rsi, [mix_acc]
    xor ecx, ecx
.o:
    cmp ecx, r13d
    jae .out
    mov eax, [rsi + rcx*4]
    imul eax, r8d
    sar eax, 8
    cmp eax, 32767
    jle .o1
    mov eax, 32767
.o1:
    cmp eax, -32768
    jge .o2
    mov eax, -32768
.o2:
    mov [r12 + rcx*2], ax
    inc ecx
    jmp .o
.out:
    LEAVE_FN

section .rodata
align 4
f_stride:   dd 2.2
f_pct:      dd 0.01

%include "sound_data.inc"

NOEXECSTACK
