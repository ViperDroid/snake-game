; =============================================================================
;          SNAKE GAME for MS-DOS by Viper Droid!
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; To Assemble and Run:
; 1. Install NASM Assembler and DOSBox.
; 2. nasm snake.asm -f bin -o snake.com
; 3. Run snake.com inside DOSBox.
; =============================================================================

ORG 100h                ; Use .COM file format

SECTION .text

_start:
    call    Game_Setup
    jmp     Game_Loop

; =============================================================================
;   DATA AND VARIABLES
; =============================================================================
; --- Game Settings ---
GAME_SPEED      equ     50      ; Delay in milliseconds, lower is faster
SNAKE_MAX_LEN   equ     512     ; Maximum snake length
SCREEN_WIDTH    equ     320
SCREEN_HEIGHT   equ     200

; --- Snake Variables ---
snake_x:        times SNAKE_MAX_LEN dw 0
snake_y:        times SNAKE_MAX_LEN dw 0
snake_len:      dw      3       ; Start with 3 segments
snake_dir_x:    dw      1       ; Start moving right (1, 0, -1)
snake_dir_y:    dw      0       ; Start moving right (1, 0, -1)

; --- Food Variables ---
food_x:         dw      0
food_y:         dw      0

; --- Game State ---
game_over_flag: db      0       ; 0 = running, 1 = game over

; --- Color Palette ---
COLOR_BG        equ     0       ; Black
COLOR_SNAKE     equ     10      ; Light Green
COLOR_FOOD      equ     12      ; Light Red
COLOR_GAMEOVER  equ     4       ; Red

; =============================================================================
;   GAME LOGIC
; =============================================================================

Game_Setup:
    ; Set video mode to 320x200, 256 colors
    mov     ah, 0
    mov     al, 13h
    int     10h

    ; Initialize snake starting position
    mov     word [snake_x], 160
    mov     word [snake_y], 100
    mov     word [snake_x+2], 159
    mov     word [snake_y+2], 100
    mov     word [snake_x+4], 158
    mov     word [snake_y+4], 100

    ; Place first food
    call    Place_Food
    ret

Game_Loop:
    call    Handle_Input
    call    Delay
    call    Update_Game_State
    call    Draw_Screen

    ; Check if game over
    cmp     byte [game_over_flag], 1
    jne     Game_Loop

    ; Game is over, wait for a key press and exit
    call    Game_Over_Screen
    mov     ah, 0           ; Wait for key press
    int     16h
    
    ; Restore text mode and exit to DOS
    mov     ax, 3           ; 80x25 text mode
    int     10h
    mov     ax, 4c00h       ; Exit program
    int     21h

Update_Game_State:
    ; Calculate new head position
    mov     ax, [snake_x]
    add     ax, [snake_dir_x]
    mov     bx, ax          ; Store new head X in BX

    mov     ax, [snake_y]
    add     ax, [snake_dir_y]
    mov     cx, ax          ; Store new head Y in CX

    ; Check for wall collision
    cmp     bx, 0
    jl      Set_Game_Over
    cmp     bx, SCREEN_WIDTH-1
    jg      Set_Game_Over
    cmp     cx, 0
    jl      Set_Game_Over
    cmp     cx, SCREEN_HEIGHT-1
    jg      Set_Game_Over

    ; Check for self-collision
    mov     si, 0
    mov     di, [snake_len]
.check_self_collision:
    cmp     si, di
    jge     .no_self_collision
    mov     ax, [snake_x+si*2]
    cmp     ax, bx
    jne     .next_segment
    mov     ax, [snake_y+si*2]
    cmp     ax, cx
    jne     .next_segment
    ; Collision detected
    call    Set_Game_Over
    jmp     .no_self_collision
.next_segment:
    inc     si
    jmp     .check_self_collision
.no_self_collision:

    ; Check for food collision
    mov     ax, [food_x]
    cmp     bx, ax
    jne     .no_food_eaten
    mov     ax, [food_y]
    cmp     cx, ax
    jne     .no_food_eaten

    ; Food eaten: increase length and place new food
    inc     word [snake_len]
    call    Place_Food
    jmp     .update_snake_body

.no_food_eaten:
    ; Erase old tail pixel from screen
    mov     di, [snake_len]
    dec     di
    mov     ax, [snake_x+di*2]
    mov     bx, [snake_y+di*2]
    call    Draw_Pixel_BG
    
.update_snake_body:
    ; Shift snake body segments
    mov     cx, [snake_len]
    mov     si, cx
    dec     si
.shift_loop:
    cmp     si, 1
    jl      .shift_done
    ; Move snake_x[i] to snake_x[i+1]
    mov     ax, [snake_x+(si-1)*2]
    mov     [snake_x+si*2], ax
    ; Move snake_y[i] to snake_y[i+1]
    mov     ax, [snake_y+(si-1)*2]
    mov     [snake_y+si*2], ax
    dec     si
    jmp     .shift_loop
.shift_done:

    ; Add new head
    mov     ax, bx
    mov     [snake_x], ax
    mov     ax, cx
    mov     [snake_y], ax
    ret

Set_Game_Over:
    mov     byte [game_over_flag], 1
    ret

; =============================================================================
;   DRAWING ROUTINES
; =============================================================================

Draw_Screen:
    ; Draw Snake
    mov     si, 0
    mov     cx, [snake_len]
.draw_snake_loop:
    cmp     si, cx
    jge     .draw_snake_done
    mov     ax, [snake_x+si*2]  ; X coord
    mov     bx, [snake_y+si*2]  ; Y coord
    push    cx                  ; Save loop counter
    mov     cl, COLOR_SNAKE     ; Color
    call    Draw_Pixel
    pop     cx
    inc     si
    jmp     .draw_snake_loop
.draw_snake_done:

    ; Draw Food
    mov     ax, [food_x]
    mov     bx, [food_y]
    mov     cl, COLOR_FOOD
    call    Draw_Pixel
    ret

Draw_Pixel:
    ; INPUT: AX = X, BX = Y, CL = Color
    push    ax
    push    bx
    push    dx
    push    es

    mov     dx, 320         ; Screen width
    mul     bx              ; AX = Y * 320
    add     ax, [esp+6]     ; Add X (original AX from stack)
    mov     di, ax          ; DI = offset
    
    mov     ax, 0A000h      ; Video segment
    mov     es, ax          ; ES = video segment
    mov     [es:di], cl     ; Draw pixel

    pop     es
    pop     dx
    pop     bx
    pop     ax
    ret

Draw_Pixel_BG:
    ; Draws a background-colored pixel to erase
    mov     cl, COLOR_BG
    call    Draw_Pixel
    ret

Game_Over_Screen:
    ; A simple way to signal game over is to paint the whole screen red
    mov     ax, 0A000h
    mov     es, ax
    mov     di, 0
    mov     cx, 320*200/2       ; Number of words to write
    mov     al, COLOR_GAMEOVER
    mov     ah, al
    rep     stosw               ; Fill screen with color
    ret

; =============================================================================
;   INPUT AND TIMING
; =============================================================================

Handle_Input:
    mov     ah, 1       ; Check for keypress
    int     16h
    jz      .no_key     ; No key pressed, so exit

    mov     ah, 0       ; Key is waiting, get it
    int     16h
    
    ; AH = scan code
    cmp     ah, 72      ; Up arrow
    je      .go_up
    cmp     ah, 80      ; Down arrow
    je      .go_down
    cmp     ah, 75      ; Left arrow
    je      .go_left
    cmp     ah, 77      ; Right arrow
    je      .go_right
    cmp     al, 27      ; ESC key
    je      Set_Game_Over
    jmp     .no_key

.go_up:
    cmp     word [snake_dir_y], 1  ; Prevent moving back on itself
    jne     .set_up
    jmp     .no_key
.set_up:
    mov     word [snake_dir_x], 0
    mov     word [snake_dir_y], -1
    jmp     .no_key

.go_down:
    cmp     word [snake_dir_y], -1 ; Prevent moving back on itself
    jne     .set_down
    jmp     .no_key
.set_down:
    mov     word [snake_dir_x], 0
    mov     word [snake_dir_y], 1
    jmp     .no_key
    
.go_left:
    cmp     word [snake_dir_x], 1  ; Prevent moving back on itself
    jne     .set_left
    jmp     .no_key
.set_left:
    mov     word [snake_dir_x], -1
    mov     word [snake_dir_y], 0
    jmp     .no_key

.go_right:
    cmp     word [snake_dir_x], -1 ; Prevent moving back on itself
    jne     .set_right
    jmp     .no_key
.set_right:
    mov     word [snake_dir_x], 1
    mov     word [snake_dir_y], 0

.no_key:
    ret

Delay:
    ; Simple delay routine using BIOS timer
    mov     ah, 0
    int     1Ah             ; Get current timer ticks into CX:DX
    mov     bx, dx          ; Store lower word of ticks
    
    mov     ax, GAME_SPEED
    mov     cx, 1000
    div     cx              ; AX = GAME_SPEED / 1000
    mov     cx, 55          ; Ticks per millisecond is ~54.9
    mul     cx              ; AX = number of ticks to wait
    add     bx, ax          ; Target tick count
    
.wait_loop:
    mov     ah, 0
    int     1Ah
    cmp     dx, bx
    jl      .wait_loop
    ret

; =============================================================================
;   UTILITY ROUTINES
; =============================================================================

Place_Food:
    ; Generate a random position for the food
.retry_food_placement:
    call    Get_Random
    mov     dx, SCREEN_WIDTH
    div     dx
    mov     [food_x], dx    ; Random X in DX

    call    Get_Random
    mov     dx, SCREEN_HEIGHT
    div     dx
    mov     [food_y], dx    ; Random Y in DX
    
    ; Check if food spawned on the snake
    mov     si, 0
    mov     di, [snake_len]
.check_spawn_collision:
    cmp     si, di
    jge     .spawn_ok
    mov     ax, [snake_x+si*2]
    cmp     ax, [food_x]
    jne     .next_spawn_check
    mov     ax, [snake_y+si*2]
    cmp     ax, [food_y]
    jne     .next_spawn_check
    jmp     .retry_food_placement ; Collision, try again
.next_spawn_check:
    inc     si
    jmp     .check_spawn_collision
.spawn_ok:
    ret

Get_Random:
    ; Simple pseudo-random number using system timer tick
    ; Returns a 16-bit random number in AX
    mov     ah, 0
    int     1Ah             ; CX:DX = timer tick count
    mov     ax, dx
    ret

SECTION .data
    ; Any initialized data would go here, but we are using a .COM file
    ; so we keep data mixed with code for simplicity.
