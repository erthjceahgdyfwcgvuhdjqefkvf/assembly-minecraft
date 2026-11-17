%include "common.inc"

global world_slot_of, world_find, world_get, world_set, world_mark_dirty
global world_set_noliquid, world_poke
global world_gen_sync, world_finish_slot, world_reserve, world_raycast
global world_gen_begin, world_gen_step, gen_active
global chunk_blocks, chunk_hmap, chunk_info, block_flags

extern liquid_push_around, light_chunk, chunk_fill, chunk_path, wire_hook
extern fill_staged, mapgen_begin, mapgen_step

section .rodata
block_flags:
    db 0                                    ; air
    db F_SOLID | F_OPAQUE | F_GROUND        ; stone
    db F_SOLID | F_OPAQUE | F_GROUND        ; dirt
    db F_SOLID | F_OPAQUE | F_GROUND        ; grass
    db F_SOLID | F_OPAQUE | F_GROUND        ; sand
    db F_LIQUID                             ; water
    db F_SOLID | F_OPAQUE                   ; log
    db F_SOLID | F_ALPHA                    ; leaves
    db F_SOLID | F_OPAQUE | F_GROUND        ; dirt with snow
    db F_SOLID | F_OPAQUE | F_GROUND        ; desert sand
    db F_SOLID | F_OPAQUE | F_GROUND        ; desert stone
    db F_SOLID | F_OPAQUE | F_GROUND        ; dry grass
    db F_SOLID | F_OPAQUE                   ; cobble
    db F_SOLID | F_OPAQUE                   ; planks
    db F_SOLID | F_ALPHA                    ; glass
    db F_SOLID | F_OPAQUE | F_GROUND        ; gravel
    db F_SOLID | F_OPAQUE                   ; cactus
    db F_SOLID | F_ALPHA                    ; pine needles
    db F_SOLID | F_OPAQUE | F_GROUND        ; snow block
    db F_SOLID | F_OPAQUE                   ; pine log
    db F_SOLID | F_OPAQUE                   ; brick
    times 7 db F_LIQUID                     ; flowing water levels 1..7
    db F_SOLID | F_OPAQUE                   ; bedrock
    db F_SOLID | F_OPAQUE                   ; coal ore
    db F_SOLID | F_OPAQUE                   ; iron ore
    db F_SOLID | F_OPAQUE                   ; gold ore
    db F_SOLID | F_OPAQUE                   ; diamond ore
    db F_SOLID | F_OPAQUE                   ; crafting table
    db F_SOLID | F_OPAQUE                   ; furnace
    db F_SOLID | F_OPAQUE                   ; furnace, burning
    db F_CROSS                              ; torch
    db F_SOLID | F_OPAQUE | F_GROUND        ; clay
    times 4 db F_SOLID | F_OPAQUE           ; iron, gold, diamond, coal blocks
    db F_SOLID | F_OPAQUE | F_GROUND        ; farmland
    times 13 db F_CROSS                     ; tall grass, wheat, carrots
    db F_SOLID | F_FENCE                    ; fence
    times 2 db F_SOLID | F_FENCE            ; fence gates, closed
    times 2 db F_FENCE                      ; fence gates, open
    times 16 db F_SOLID | F_OPAQUE          ; wool
    times 16 db F_SOLID | F_OPAQUE          ; concrete
    times 2 db F_CROSS                      ; flowers
    times 2 db F_HALF                       ; bed, foot and head
    db F_SOLID | F_OPAQUE                   ; dye maker
    times 4 db F_LIQUID                     ; lava, flowing lava 1..3
    db F_SOLID | F_OPAQUE                   ; obsidian
    db F_SOLID | F_OPAQUE                   ; TNT
    db F_CROSS                              ; fire
    db F_SOLID | F_OPAQUE | F_GROUND        ; netherrack
    db F_ALPHA                              ; nether portal (walk in)
    db F_SOLID | F_ALPHA                    ; slime block
    times 16 db F_SOLID | F_ALPHA           ; stained glass (blended)
    db F_SOLID | F_OPAQUE                   ; beacon
    db F_CROSS                              ; torch on a wall
    times 2 db F_SOLID | F_OPAQUE           ; bluestone ore, block of bluestone
    times 62 db F_CROSS                     ; dust, torch, lever, button, plate,
                                            ; repeater, comparator: walked through
    times 2 db F_SOLID | F_OPAQUE           ; lamp
    times 30 db F_SOLID | F_CROSS           ; pistons and their heads
    times 22 db F_CROSS                     ; rails
    db F_SOLID | F_CROSS, F_CROSS           ; door, lower half: shut, open
    db F_SOLID | F_CROSS, F_CROSS           ; upper half
    db F_SOLID | F_CROSS, F_CROSS           ; trapdoor
    times 4 db F_SOLID | F_OPAQUE           ; birch, dark oak logs and planks
    db F_SOLID | F_CROSS                    ; slab, stairs or chest
    db F_SOLID | F_OPAQUE                   ; unknown (not loaded)

align 4
f_big:  dd 1.0e30
f_one:  dd 1.0
f_zero: dd 0.0

section .bss
alignb 4096
chunk_blocks:   resb NUM_SLOTS * CHUNK_VOX
chunk_hmap:     resw NUM_SLOTS * 256
chunk_info:     resb NUM_SLOTS * CI_SIZE
sync_path:      resb 256
sync_buf:       resb CHUNK_VOX * 2 + 16
gen_active:     resd 1              ; world_gen_step: 1 making a chunk, 2 lighting it
gen_slot:       resd 1
gen_maxy:       resd 1

section .text

; int world_slot_of(int cx, int cz)
world_slot_of:
    mov eax, esi
    and eax, SLOT_MASK
    shl eax, SLOT_BITS
    mov ecx, edi
    and ecx, SLOT_MASK
    or eax, ecx
    ret

; int world_find(int cx, int cz) - slot of a ready chunk or -1
world_find:
    mov eax, esi
    and eax, SLOT_MASK
    shl eax, SLOT_BITS
    mov ecx, edi
    and ecx, SLOT_MASK
    or eax, ecx
    mov ecx, eax
    shl rcx, CI_SHIFT
    lea rdx, [chunk_info]
    add rdx, rcx
    cmp byte [rdx + CI_STATE], ST_READY
    jne .no
    cmp [rdx + CI_CX], edi
    jne .no
    cmp [rdx + CI_CZ], esi
    jne .no
    ret
.no:
    mov eax, -1
    ret

; int world_get(int x, int y, int z)
world_get:
    add esi, -WORLD_YMIN
    js .below
    cmp esi, WORLD_H
    jae .above
    mov r8d, edi
    mov r9d, edx
    mov r10d, esi
    sar edi, 4
    mov esi, edx
    sar esi, 4
    call world_find
    test eax, eax
    js .unknown
    shl eax, 16
    and r9d, 15
    shl r9d, 12
    or eax, r9d
    and r8d, 15
    shl r8d, 8
    or eax, r8d
    or eax, r10d
    lea rcx, [chunk_blocks]
    movzx eax, byte [rcx + rax]
    ret
.below:
    mov eax, B_STONE
    ret
.above:
    xor eax, eax
    ret
.unknown:
    mov eax, B_UNKNOWN
    ret

; void world_mark_dirty(int cx, int cz) - remesh a chunk
world_mark_dirty:
    call world_find
    test eax, eax
    js .no
    shl rax, CI_SHIFT
    lea rcx, [chunk_info]
    mov byte [rcx + rax + CI_DIRTY], 1
.no:
    ret

; mark_relight(int cx, int cz) - recompute light (and so remesh) a chunk
mark_relight:
    call world_find
    test eax, eax
    js .no
    shl rax, CI_SHIFT
    lea rcx, [chunk_info]
    mov byte [rcx + rax + CI_LIGHTDIRTY], RELIGHT_STEPS
    mov byte [rcx + rax + CI_DIRTY], 1
.no:
    ret

; void world_set(int x, int y, int z, int block)
; Changes a node, its chunk's heightmap, marks it modified, queues relight
; of the chunk and its neighbours and wakes nearby water.
world_set:
    mov r8d, 1
    jmp world_set_common
; same without waking water (used when loading)
world_set_noliquid:
    xor r8d, r8d
world_set_common:
    ENTER_FN 16
    mov [rsp + 4], r8d
    add esi, -WORLD_YMIN
    js .out
    cmp esi, WORLD_H
    jae .out
    mov r12d, edi                   ; x
    mov r13d, esi                   ; yi
    mov r14d, edx                   ; z
    mov r15d, ecx                   ; block
    sar edi, 4
    mov esi, edx
    sar esi, 4
    call world_find
    test eax, eax
    js .out
    mov ebx, eax                    ; slot
    mov eax, r14d
    and eax, 15
    shl eax, 4
    mov ecx, r12d
    and ecx, 15
    or eax, ecx                     ; column
    mov [rsp], eax
    shl eax, 8
    or eax, r13d
    mov ecx, ebx
    shl ecx, 16
    or eax, ecx
    lea rcx, [chunk_blocks]
    movzx edx, byte [rcx + rax]
    mov [rsp + 8], edx              ; what was there
    mov [rcx + rax], r15b
    ; chunk info
    mov eax, ebx
    shl eax, CI_SHIFT
    lea rdx, [chunk_info]
    add rdx, rax
    mov byte [rdx + CI_DIRTY], 1
    mov byte [rdx + CI_LIGHTDIRTY], RELIGHT_STEPS
    mov byte [rdx + CI_MODIFIED], 1
    test r15d, r15d
    jz .nomax
    cmp r13d, [rdx + CI_MAXY]
    jle .nomax
    mov [rdx + CI_MAXY], r13d
.nomax:
    ; heightmap
    mov eax, ebx
    shl eax, 8
    add eax, [rsp]
    lea rdx, [chunk_hmap]
    lea rdx, [rdx + rax*2]          ; &hmap[column]
    movzx eax, word [rdx]
    lea rcx, [block_flags]
    test byte [rcx + r15], F_OPAQUE
    jz .clear
    lea ecx, [r13 + 1]
    cmp ecx, eax
    jbe .hdone
    mov [rdx], cx
    jmp .hdone
.clear:
    lea ecx, [r13 + 1]
    cmp ecx, eax
    jne .hdone
    ; removed the top opaque node: scan down
    mov r8d, ebx
    shl r8d, 16
    mov eax, [rsp]
    shl eax, 8
    or r8d, eax                     ; column base index
    lea r9, [chunk_blocks]
    lea r10, [block_flags]
    mov ecx, r13d
.scan:
    dec ecx
    js .none
    lea eax, [r8 + rcx]
    movzx eax, byte [r9 + rax]
    test byte [r10 + rax], F_OPAQUE
    jz .scan
    inc ecx
    mov [rdx], cx
    jmp .hdone
.none:
    mov word [rdx], 0
.hdone:
    ; wake up liquids around the change
    cmp dword [rsp + 4], 0
    je .nowater
    mov edi, r12d
    lea esi, [r13 + WORLD_YMIN]
    mov edx, r14d
    call liquid_push_around
    ; and the bluestone parts next to it
    mov edi, r12d
    lea esi, [r13 + WORLD_YMIN]
    mov edx, r14d
    mov ecx, [rsp + 8]
    mov r8d, r15d
    call wire_hook
.nowater:
    ; light reaches up to 15 nodes: the eight chunks round it relight too
%macro RELIGHT 2
    mov edi, r12d
    sar edi, 4
    add edi, %1
    mov esi, r14d
    sar esi, 4
    add esi, %2
    call mark_relight
%endmacro
    RELIGHT -1, -1
    RELIGHT 0, -1
    RELIGHT 1, -1
    RELIGHT -1, 0
    RELIGHT 1, 0
    RELIGHT -1, 1
    RELIGHT 0, 1
    RELIGHT 1, 1
.out:
    LEAVE_FN

; void world_poke(int x, int y, int z, int block) - change a node that
; neither blocks light nor gives any off, quietly: only its chunk's mesh
; is redone (bluestone parts changing state)
world_poke:
    push rbx
    push r12
    push r13
    push r14
    push r15
    add esi, -WORLD_YMIN
    js .out
    cmp esi, WORLD_H
    jae .out
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx
    sar edi, 4
    mov esi, edx
    sar esi, 4
    call world_find
    test eax, eax
    js .out
    mov ecx, eax
    shl ecx, CI_SHIFT
    lea rdx, [chunk_info]
    mov byte [rdx + rcx + CI_DIRTY], 1
    mov byte [rdx + rcx + CI_MODIFIED], 1
    shl eax, 16
    and r14d, 15
    shl r14d, 12
    or eax, r14d
    and r12d, 15
    shl r12d, 8
    or eax, r12d
    or eax, r13d
    lea rcx, [chunk_blocks]
    mov [rcx + rax], r15b
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; int world_reserve(int cx, int cz) - claim the slot for (cx, cz) as pending
world_reserve:
    call world_slot_of
    mov ecx, eax
    shl rcx, CI_SHIFT
    lea rdx, [chunk_info]
    add rdx, rcx
    mov [rdx + CI_CX], edi
    mov [rdx + CI_CZ], esi
    mov byte [rdx + CI_STATE], ST_PENDING
    mov byte [rdx + CI_MESHED], 0
    mov byte [rdx + CI_DIRTY], 0
    mov byte [rdx + CI_MODIFIED], 0
    mov byte [rdx + CI_LIGHTDIRTY], 0
    ret

; void world_finish_slot(int slot, int maxy)
world_finish_slot:
    ENTER_FN 0
    mov eax, edi
    shl rax, CI_SHIFT
    lea rbx, [chunk_info]
    add rbx, rax
    mov [rbx + CI_MAXY], esi
    mov byte [rbx + CI_DIRTY], 1
    mov byte [rbx + CI_MESHED], 0
    mov byte [rbx + CI_STATE], ST_READY
    mov r12d, [rbx + CI_CX]
    mov r13d, [rbx + CI_CZ]
    lea edi, [r12 - 1]
    mov esi, r13d
    call world_mark_dirty
    lea edi, [r12 + 1]
    mov esi, r13d
    call world_mark_dirty
    mov edi, r12d
    lea esi, [r13 - 1]
    call world_mark_dirty
    mov edi, r12d
    lea esi, [r13 + 1]
    call world_mark_dirty
    LEAVE_FN

; void world_gen_sync(int cx, int cz, int seed) - load or generate a chunk
; on this thread (spawn area, or when there is no second core)
world_gen_sync:
    ENTER_FN 0
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
.flush:
    cmp dword [gen_active], 0       ; a chunk half made by world_gen_step
    je .free                        ; comes first: the generator's state
    call world_gen_step             ; is its
    jmp .flush
.free:
    mov edi, r12d
    mov esi, r13d
    call world_reserve
    mov ebx, eax
    mov edi, r12d
    mov esi, r13d
    lea rdx, [sync_path]
    call chunk_path
    mov edi, ebx
    mov esi, r12d
    mov edx, r13d
    mov ecx, r14d
    lea r8, [sync_path]
    lea r9, [sync_buf]
    call chunk_fill
    mov r15d, eax
    mov edi, ebx
    xor esi, esi
    call light_chunk
    mov edi, ebx
    mov esi, r15d
    call world_finish_slot
    LEAVE_FN

; int world_gen_begin(int cx, int cz, int seed) - the same a slice at a
; time, for one core: 1 if the chunk is ready already (loaded from its file,
; the nether), 0 if world_gen_step has to be called until it says 1
world_gen_begin:
    ENTER_FN 0
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    call world_reserve
    mov ebx, eax
    mov edi, r12d
    mov esi, r13d
    lea rdx, [sync_path]
    call chunk_path
    mov dword [fill_staged], 1
    mov edi, ebx
    mov esi, r12d
    mov edx, r13d
    mov ecx, r14d
    lea r8, [sync_path]
    lea r9, [sync_buf]
    call chunk_fill
    mov dword [fill_staged], 0
    mov r15d, eax
    test eax, eax
    js .staged
    mov edi, ebx
    xor esi, esi
    call light_chunk
    mov edi, ebx
    mov esi, r15d
    call world_finish_slot
    mov eax, 1
    LEAVE_FN
.staged:
    mov [gen_slot], ebx
    mov dword [gen_active], 1
    mov eax, ebx
    mov rdi, rax
    shl rdi, 16
    lea rcx, [chunk_blocks]
    add rdi, rcx
    mov rsi, rax
    shl rsi, 9
    lea rcx, [chunk_hmap]
    add rsi, rcx
    mov edx, r12d
    mov ecx, r13d
    mov r8d, r14d
    call mapgen_begin
    xor eax, eax
    LEAVE_FN

; int world_gen_step(void) - the next slice of the chunk begun; 1 when it
; is finished (lit and ready), 0 while there is more
world_gen_step:
    sub rsp, 8
    mov eax, [gen_active]
    test eax, eax
    jz .done
    cmp eax, 2
    je .light
    call mapgen_step
    test eax, eax
    js .more
    mov [gen_maxy], eax
    mov dword [gen_active], 2
.more:
    xor eax, eax
    add rsp, 8
    ret
.light:
    mov edi, [gen_slot]
    xor esi, esi
    call light_chunk
    mov edi, [gen_slot]
    mov esi, [gen_maxy]
    call world_finish_slot
    mov dword [gen_active], 0
.done:
    mov eax, 1
    add rsp, 8
    ret

; FLOORF dst32, src xmm, tmp xmm - true floor
%macro FLOORF 3
    cvttss2si %1, %2
    cvtsi2ss %3, %1
    comiss %3, %2
    jbe %%ok
    dec %1
%%ok:
%endmacro

; int world_raycast(float ox, oy, oz, float dx, dy, dz, float maxd, int out[6])
; Amanatides-Woo voxel walk; out = hit cell, then the empty cell before it.
; locals: 0 cell[3], 12 step[3], 24 tmax[3], 36 tdelta[3], 48 origin[3], 60 dir[3]
world_raycast:
    ENTER_FN 80
    mov r15, rdi
    movss [rsp + 48], xmm0
    movss [rsp + 52], xmm1
    movss [rsp + 56], xmm2
    movss [rsp + 60], xmm3
    movss [rsp + 64], xmm4
    movss [rsp + 68], xmm5
    movss [rsp + 72], xmm6
    xor ebx, ebx
.axis:
    movss xmm0, [rsp + 48 + rbx*4]  ; origin
    movss xmm1, [rsp + 60 + rbx*4]  ; dir
    FLOORF eax, xmm0, xmm2
    mov [rsp + rbx*4], eax
    cvtsi2ss xmm2, eax              ; cell
    comiss xmm1, [f_zero]
    ja .pos
    jb .neg
    mov dword [rsp + 12 + rbx*4], 0
    movss xmm3, [f_big]
    movss [rsp + 24 + rbx*4], xmm3
    movss [rsp + 36 + rbx*4], xmm3
    jmp .anext
.pos:
    mov dword [rsp + 12 + rbx*4], 1
    movss xmm3, [f_one]
    divss xmm3, xmm1
    movss [rsp + 36 + rbx*4], xmm3
    addss xmm2, [f_one]
    subss xmm2, xmm0
    mulss xmm2, xmm3
    movss [rsp + 24 + rbx*4], xmm2
    jmp .anext
.neg:
    mov dword [rsp + 12 + rbx*4], -1
    movss xmm3, [f_one]
    divss xmm3, xmm1                ; 1/d (negative)
    xorps xmm4, xmm4
    subss xmm4, xmm3
    movss [rsp + 36 + rbx*4], xmm4  ; tdelta = -1/d
    subss xmm0, xmm2                ; o - cell
    mulss xmm0, xmm4
    movss [rsp + 24 + rbx*4], xmm0
.anext:
    inc ebx
    cmp ebx, 3
    jb .axis

    mov r12d, [rsp]
    mov r13d, [rsp + 4]
    mov r14d, [rsp + 8]
    mov ebx, 512                    ; step limit
.walk:
    mov edi, [rsp]
    mov esi, [rsp + 4]
    mov edx, [rsp + 8]
    call world_get
    test eax, eax
    jz .empty
    lea rcx, [block_flags]
    test byte [rcx + rax], F_LIQUID
    jnz .empty                      ; aim through water and lava
    cmp eax, B_UNKNOWN
    je .miss
    mov eax, [rsp]
    mov [r15], eax
    mov eax, [rsp + 4]
    mov [r15 + 4], eax
    mov eax, [rsp + 8]
    mov [r15 + 8], eax
    mov [r15 + 12], r12d
    mov [r15 + 16], r13d
    mov [r15 + 20], r14d
    mov eax, 1
    jmp .done
.empty:
    mov r12d, [rsp]
    mov r13d, [rsp + 4]
    mov r14d, [rsp + 8]
    ; axis with the smallest tmax
    xor ecx, ecx
    movss xmm0, [rsp + 24]
    comiss xmm0, [rsp + 28]
    jbe .c1
    mov ecx, 1
    movss xmm0, [rsp + 28]
.c1:
    comiss xmm0, [rsp + 32]
    jbe .c2
    mov ecx, 2
    movss xmm0, [rsp + 32]
.c2:
    comiss xmm0, [rsp + 72]
    ja .miss
    mov eax, [rsp + 12 + rcx*4]
    add [rsp + rcx*4], eax
    addss xmm0, [rsp + 36 + rcx*4]
    movss [rsp + 24 + rcx*4], xmm0
    dec ebx
    jnz .walk
.miss:
    xor eax, eax
.done:
    LEAVE_FN

NOEXECSTACK
