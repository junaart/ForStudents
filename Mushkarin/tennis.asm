format ELF64
public _start



; --------------------------------------------------------------------------------------------------------------------

extrn initscr
extrn noecho
extrn refresh
extrn endwin
extrn exit
extrn curs_set
extrn keypad
extrn nodelay
extrn stdscr
extrn getmaxx
extrn getmaxy
extrn move
extrn addstr
extrn addch
extrn getch
extrn napms
extrn clear
extrn mvprintw
extrn start_color
extrn init_pair
extrn attron
extrn attroff
extrn has_colors
extrn bkgd

; --------------------------------------------------------------------------------------------------------------------





; --------------------------------------------------------------------------------------------------------------------

macro pusha_std {
    push rax
    push rdi
    push rsi
    push rdx
    push rcx
}
macro popa_std {
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop rax
}

; --------------------------------------------------------------------------------------------------------------------


; Константы
SYS_OPEN  = 2
SYS_READ  = 0
SYS_CLOSE = 3

KEY_LEFT_CODE  = 260
KEY_RIGHT_CODE = 261
KEY_QUIT_CODE  = 'q'

MAX_LIVES      = 200
GAME_OVER_Y_LINE = 1

COLOR_RED_      = 1
COLOR_BLUE_     = 4
COLOR_GREEN_    = 2
COLOR_YELLOW_   = 3
COLOR_WHITE_    = 7
COLOR_PURPLE_   = 5
COLOR_BLACK_    = 0

BALL_COLOR_PAIR_RED     = 1
BALL_COLOR_PAIR_BLUE    = 2
BALL_COLOR_PAIR_GREEN   = 3
BALL_COLOR_PAIR_YELLOW  = 4
BALL_COLOR_PAIR_WHITE   = 5
BALL_COLOR_PAIR_PURPLE  = 6
SCREEN_BACKGROUND_PAIR  = 7

MAX_BALLS           = 3
BALL_TYPES          = 6

PADDLE_MOVE_SPEED       = 20
PADDLE_WIDTH_PERCENT    = 10
MIN_PADDLE_WIDTH        = 3

BONUS_NONE          = 0
BONUS_EXTRA_LIFE    = 1
BONUS_EXTRA_DAMAGE  = 2
BONUS_PHASING       = 3
BONUS_ACC_DX        = 4
BONUS_ACC_DY        = 5

INTERNAL_SCALE      = 24
FRAME_TIME          = 25              ; 1000//FPS

struc AllBallsData
{
    .x_coords           dw MAX_BALLS dup (?)
    .y_coords           dw MAX_BALLS dup (?)
    .old_x_pos          dw MAX_BALLS dup (?)
    .old_y_pos          dw MAX_BALLS dup (?)
    .dx_speeds          db MAX_BALLS dup (?)
    .dy_speeds          db MAX_BALLS dup (?)
    .chtypes            dd MAX_BALLS dup (?)
    .is_active_flags    db MAX_BALLS dup (?)
    .bonus_types        db MAX_BALLS dup (?)
}


; --------------------------------------------------------------------------------------------------------------------




section '.data' writable

    ball_char_val   db 'o'
    db 0
    paddle_char     db '=', 0
    db 0
    paddle_str      rb 101
    empty_char      db " "
    db 0
    f_urandom_path  db "/dev/urandom"
    db 0
    lives_format_str db "Lives: %3d"
    db 0
    game_over_msg   db "GAME OVER. Press 'q' to exit."
    db 0
    game_over_msg_actual_len = ($-game_over_msg) - 1
    db 0
    initial_lives   db 100
    db 0
    speed_map_table db -2, 2, -3, 3, -4, 4, -5, 5, -6, 6, -7, 7, -8, 8
    db 0

; --------------------------------------------------------------------------------------------------------------------




section '.bss' writable

    screen_width_symbols    dw 0
    screen_height_symbols   dw 0

    paddle_x_internal       dw 0
    paddle_y_internal       dw 0
    paddle_old_x_internal   dw 0
    paddle_char_count       dw 0
    paddle_speed            dw 0

    all_balls               AllBallsData

    player_lives            db 0
    game_over_flag          db 0
    key_pressed             dd 0

    urandom_fd              dd -1
    random_byte_storage     rb 1

    ball_init_color_idx     db 0

; --------------------------------------------------------------------------------------------------------------------




section '.text' executable

_start:
    call    init_ncurses_base
    call    init_color_settings
    call    init_ncurses_input
    call    get_screen_dimensions

    call    open_urandom_device

    mov     al, [initial_lives]
    mov     [player_lives], al
    mov     byte [game_over_flag], 0

    call    init_paddle_state
    call    init_balls_array
    call    draw_initial_scene


game_loop:
    call    getch
    mov     [key_pressed], eax

    cmp     eax, KEY_QUIT_CODE
    je      _cleanup_and_exit

    cmp     byte [game_over_flag], 1
    jne     .game_is_active

    call    draw_game_over
    call    draw_lives
    call    refresh

    mov     rdi, FRAME_TIME
    call    napms
    jmp     game_loop


.game_is_active:
    mov     ax, [paddle_x_internal]
    mov     [paddle_old_x_internal], ax

    mov     eax, [key_pressed]
    cmp     eax, KEY_LEFT_CODE
    jne     .check_right_key_active

    mov     ax, [paddle_speed]            
    imul    ax, INTERNAL_SCALE
    sub     word [paddle_x_internal], ax        ; Движение весла влево

    jmp     .paddle_input_processed_active


.check_right_key_active:
    cmp     eax, KEY_RIGHT_CODE
    jne     .paddle_input_processed_active

    mov     ax, [paddle_speed]
    imul    ax, INTERNAL_SCALE
    add     word [paddle_x_internal], ax        ; Движение весла вправо


.paddle_input_processed_active:
    call    ensure_paddle_within_bounds

    mov     rcx, MAX_BALLS
    mov     rsi, 0 


    .ball_update_and_collision_loop: 
        push    rcx
        push    rsi
        
        mov     rdi, rsi 
        cmp     byte [all_balls.is_active_flags + rdi], 1
        jne     .skip_this_ball_update_coll

        call    update_one_ball_state

        mov     rdi, rsi 
        call    handle_one_ball_collision 

    .skip_this_ball_update_coll:
        pop     rsi
        pop     rcx

        inc     rsi
        loop    .ball_update_and_collision_loop

    call    clear_old_positions
    call    draw_current_positions
    
    call    draw_lives

    cmp     byte [game_over_flag],1
    jne     .skip_draw_game_over_in_loop

    call    draw_game_over


.skip_draw_game_over_in_loop:
    call    refresh
    mov     rdi, FRAME_TIME
    call    napms
    jmp     game_loop


_cleanup_and_exit:
    call    close_urandom_device
    call    endwin
    mov     rdi,0
    call    exit

init_ncurses_base:
    pusha_std

    call    initscr
    call    refresh

    popa_std
    ret


init_color_settings:
    pusha_std

    call    start_color

    mov     edi, BALL_COLOR_PAIR_RED
    mov     esi, COLOR_RED_
    mov     edx, COLOR_BLACK_
    call    init_pair

    mov     edi, BALL_COLOR_PAIR_BLUE
    mov     esi, COLOR_BLUE_
    mov     edx, COLOR_BLACK_
    call    init_pair

    mov     edi, BALL_COLOR_PAIR_GREEN
    mov     esi, COLOR_GREEN_
    mov     edx, COLOR_BLACK_
    call    init_pair

    mov     edi, BALL_COLOR_PAIR_YELLOW
    mov     esi, COLOR_YELLOW_
    mov     edx, COLOR_BLACK_
    call    init_pair

    mov     edi, BALL_COLOR_PAIR_WHITE
    mov     esi, COLOR_WHITE_
    mov     edx, COLOR_BLACK_
    call    init_pair

    mov     edi, BALL_COLOR_PAIR_PURPLE
    mov     esi, COLOR_PURPLE_
    mov     edx, COLOR_BLACK_
    call    init_pair

    mov     edi, SCREEN_BACKGROUND_PAIR
    mov     esi, COLOR_BLACK_
    mov     edx, COLOR_BLACK_
    call    init_pair

    popa_std
    ret


init_ncurses_input:
    pusha_std

    call    noecho
    mov     rdi, 0
    call    curs_set

    mov     rdi, [stdscr]
    mov     rsi, 1
    call    keypad

    mov     rdi, [stdscr]
    mov     rsi, 1
    call    nodelay

    popa_std
    ret



get_screen_dimensions:
    pusha_std

    mov     rdi,[stdscr]
    call    getmaxy
    mov     [screen_height_symbols],ax

    mov     rdi,[stdscr]
    call    getmaxx
    mov     [screen_width_symbols],ax

    popa_std
    ret



init_paddle_state:
    pusha_std

    mov     ax, [screen_width_symbols]
    mov     bx, PADDLE_WIDTH_PERCENT
    mul     bx
    mov     bx, 100
    div     bx

    cmp     ax, 3                   ; Минимальная ширина ракетки
    jge     .width_min_ok
    mov     ax, 3

.width_min_ok:
    mov     [paddle_char_count], ax
    mov     ax, [screen_height_symbols]
    sub     ax, 3
    mov     cx, INTERNAL_SCALE
    imul    ax, cx
    mov     [paddle_y_internal], ax

    mov     ax, [screen_width_symbols]
    mov     cx, INTERNAL_SCALE
    imul    ax, cx

    mov     bx, [paddle_char_count]
    mov     dx, INTERNAL_SCALE
    imul    bx, dx

    sub     ax, bx
    shr     ax, 1
    mov     [paddle_x_internal], ax
    mov     [paddle_old_x_internal], ax

    mov     rdi, paddle_str
    movzx   rcx, word [paddle_char_count]
    jecxz   .paddle_string_done
    mov     al, [paddle_char]
    .fill_paddle_str_loop:
        mov     [rdi], al
        inc     rdi
        loop    .fill_paddle_str_loop
    .paddle_string_done:
        mov     byte [rdi], 0

    mov     ax, [paddle_char_count]
    mov     bx, PADDLE_MOVE_SPEED
    mul     bx
    mov     bx, 100
    div     bx

    cmp     ax, 0
    jg      .speed_ok
    mov     ax, 1

.speed_ok:
    mov     [paddle_speed], ax


    popa_std
    ret


_reset_ball_at_index:
    pusha_std

    mov     rsi, rdi 

    mov     ax, [screen_height_symbols]
    shr     ax, 1
    mov     word [all_balls.old_y_pos + rsi * 2], ax
    mov     cx, INTERNAL_SCALE
    imul    ax, cx
    mov     word [all_balls.y_coords + rsi * 2], ax
    

    mov     ax, [screen_width_symbols]
    shr     ax, 1
    mov     word [all_balls.old_x_pos + rsi * 2], ax
    mov     cx, INTERNAL_SCALE
    imul    ax, cx
    mov     word [all_balls.x_coords + rsi * 2], ax
    

    .random_dx_loop:
        call    read_one_random_byte
        jnc     .got_rand_dx
        jmp     .random_dx_loop


    .got_rand_dx:
        mov     al, [random_byte_storage]
        call    map_byte_to_speed_component
        mov     byte [all_balls.dx_speeds + rsi], bl

    .random_dy_loop:
        call    read_one_random_byte
        jnc     .got_rand_dy
        jmp     .random_dy_loop


    .got_rand_dy:
        mov     al, [random_byte_storage]
        call    map_byte_to_speed_component
        mov     byte [all_balls.dy_speeds + rsi], bl

        
        




    mov     cl, byte [ball_init_color_idx]
    mov     byte [all_balls.bonus_types + rsi], BONUS_NONE
    mov     ebx, BALL_COLOR_PAIR_BLUE

    cmp     cl, 0
    je      .a0_b_r

    cmp     cl, 1
    je      .a1_b_r

    cmp     cl, 2
    je      .a2_b_r

    cmp     cl, 3
    je      .a3_b_r

    cmp     cl, 4
    je      .a4_b_r

    cmp     cl, 5
    je      .a5_b_r

    jmp     .cht_s_r
    
.a0_b_r:
    mov     byte [all_balls.bonus_types + rsi], BONUS_EXTRA_DAMAGE
    mov     ebx, BALL_COLOR_PAIR_RED
    jmp     .cht_s_r

.a1_b_r:
    mov     byte [all_balls.bonus_types + rsi], BONUS_EXTRA_LIFE
    mov     ebx, BALL_COLOR_PAIR_GREEN
    jmp     .cht_s_r

.a2_b_r:
    mov     ebx, BALL_COLOR_PAIR_BLUE
    jmp     .cht_s_r

.a3_b_r:
    mov     byte [all_balls.bonus_types + rsi], BONUS_PHASING
    mov     ebx, BALL_COLOR_PAIR_YELLOW
    jmp     .cht_s_r

.a4_b_r:
    mov     byte [all_balls.bonus_types + rsi], BONUS_ACC_DY
    mov     ebx, BALL_COLOR_PAIR_WHITE
    jmp     .cht_s_r

.a5_b_r:
    mov     byte [all_balls.bonus_types + rsi], BONUS_ACC_DX
    mov     ebx, BALL_COLOR_PAIR_PURPLE
    jmp     .cht_s_r


.cht_s_r:
    movzx   eax, byte [ball_char_val]
    shl     ebx, 8
    or      eax, ebx
    mov     dword [all_balls.chtypes + rsi * 4], eax

    inc     byte [ball_init_color_idx]
    mov     al, [ball_init_color_idx]
    cmp     al, BALL_TYPES
    jl      .idx_ok_r_r

    mov     byte [ball_init_color_idx], 0

.idx_ok_r_r:
    mov     byte [all_balls.is_active_flags + rsi], 1

    popa_std
    ret



init_balls_array:
    push    rcx
    push    rdi

    mov     byte [ball_init_color_idx], 0
    mov     rcx, MAX_BALLS
    xor     rdi, rdi

    .init_loop_iba:
        push    rcx
        push    rdi

        call    _reset_ball_at_index

        pop     rdi
        pop     rcx

        inc     rdi
        loop    .init_loop_iba

    pop     rdi
    pop     rcx
    ret



draw_initial_scene:
    pusha_std

    mov     ebx, SCREEN_BACKGROUND_PAIR
    shl     ebx, 8
    mov     eax, ' '
    or      eax, ebx 
    mov     rdi, rax
    call    bkgd
    call    refresh

    mov     edi, 0
    mov     esi, 0
    call    move

    mov     rdi, empty_char
    call    addstr
    call    refresh

    call    draw_current_paddle_position
    mov     rcx, MAX_BALLS
    xor     rdi, rdi

    .draw_initial_balls_loop:
        push    rcx
        push    rdi

        call    draw_one_ball

        pop     rdi
        pop     rcx

        inc     rdi
        loop    .draw_initial_balls_loop

    call    draw_lives
    call    refresh
    popa_std
    ret




draw_current_paddle_position:
    pusha_std

    mov     ax, [paddle_y_internal]
    xor     dx, dx 
    mov     cx, INTERNAL_SCALE
    div     cx 
    movzx   edi, al

    mov     ax, [paddle_x_internal]
    xor     dx, dx 
    mov     cx, INTERNAL_SCALE
    div     cx 
    movzx   esi, al

    call    move
    mov     rdi, paddle_str
    call    addstr

    popa_std
    ret



clear_old_paddle_position:
    pusha_std
    push    r10
    push    r11
    mov     ax, [paddle_y_internal]
    xor     dx, dx
    mov     cx, INTERNAL_SCALE
    div     cx
    movzx   edi, al
    mov     ax, [paddle_old_x_internal]
    xor     dx, dx
    mov     cx, INTERNAL_SCALE
    div     cx
    movzx   esi, al
    call    move
    mov     r10, paddle_char_count
    mov     rcx, r10
    inc     r10
    sub     rsp, r10
    mov     r11, rsp
    mov     rdi, r11

    .fill_paddle_spaces_loop:
        mov     byte [rdi], ' '
        inc     rdi
        loop    .fill_paddle_spaces_loop

    mov     byte [rdi], 0
    mov     rdi, r11
    call    addstr
    add     rsp, r10
    pop     r11
    pop     r10
    popa_std
    ret




draw_one_ball:
    pusha_std
    push    r8
    push    r10

    mov     r10, rdi 
    cmp     byte [all_balls.is_active_flags + r10], 1
    jne     .skip_one_ball_draw

    mov     ax, [all_balls.y_coords + r10 * 2]
    xor     dx, dx
    mov     bx, INTERNAL_SCALE
    div     bx

    cmp     ax, [all_balls.old_y_pos + r10 * 2]
    jne     .different_pos

    mov     ax, [all_balls.x_coords + r10 * 2]
    xor     dx, dx
    mov     bx, INTERNAL_SCALE
    div     bx

    cmp     ax, [all_balls.old_x_pos + r10 * 2]
    je     .skip_one_ball_draw
    
.different_pos:
    mov     r8, r10 

    mov     ax, [all_balls.y_coords + r10 * 2]
    xor     dx, dx
    mov     bx, INTERNAL_SCALE
    div     bx
    movzx   edi, al 

    mov     ax, [all_balls.x_coords + r10 * 2]
    xor     dx, dx
    mov     bx, INTERNAL_SCALE
    div     bx
    movzx   esi, al 
 
    call    is_coord_visible_for_drawing
    jc      .skip_one_ball_draw

    call    move

    mov     edi, [all_balls.chtypes + r10 * 4]
    call    addch

.skip_one_ball_draw:
    pop     r10
    pop     r8
    popa_std
    ret



; rdi - номер шара
clear_one_ball_old_pos:
    pusha_std
    push r8
    push r10

    mov     r10, rdi 
    cmp     byte [all_balls.is_active_flags + r10], 1
    jne     .skip_one_ball_clear

    mov     ax, [all_balls.y_coords + r10 * 2]
    xor     dx, dx
    mov     bx, INTERNAL_SCALE
    div     bx

    cmp     ax, [all_balls.old_y_pos + r10 * 2]
    jne     .different_pos

    mov     ax, [all_balls.x_coords + r10 * 2]
    xor     dx, dx
    mov     bx, INTERNAL_SCALE
    div     bx

    cmp     ax, [all_balls.old_x_pos + r10 * 2]
    je     .skip_one_ball_clear


.different_pos:
    mov     r8, r10 

    movzx   edi, [all_balls.old_y_pos + r10 * 2]
    movzx   esi, [all_balls.old_x_pos + r10 * 2]
    
    call    is_coord_visible_for_drawing
    jc      .skip_one_ball_clear
    
    call    move
    mov     rdi, empty_char
    call    addstr

.skip_one_ball_clear:
    pop r10
    pop r8
    popa_std
    ret




clear_old_positions:
    mov     ax, [paddle_x_internal]
    mov     bx, [paddle_old_x_internal]
    cmp     ax, bx
    je      .skip_clear_paddle

    call    clear_old_paddle_position

.skip_clear_paddle:

    mov     rcx, MAX_BALLS
    xor     rdi, rdi

    .clear_balls_loop:
        push    rcx
        push    rdi

        call    clear_one_ball_old_pos

        pop     rdi
        pop     rcx

        inc     rdi
        loop    .clear_balls_loop
    
    ret



draw_current_positions:
    call    draw_current_paddle_position
    mov     rcx, MAX_BALLS
    xor     rdi, rdi

    .draw_balls_loop:
        push    rcx
        push    rdi

        call    draw_one_ball

        pop     rdi
        pop     rcx

        inc     rdi
        loop    .draw_balls_loop
    
    ret



draw_lives:
    pusha_std

    mov     edi, 0
    mov     esi, 0
    mov     rdx, lives_format_str
    xor     eax, eax
    movzx   ecx, byte [player_lives]
    call    mvprintw

    popa_std
    ret



draw_game_over:
    pusha_std

    mov     ax, word [screen_height_symbols]
    shr     ax, 1
    mov     bx, word [screen_width_symbols]
    mov     cl, byte game_over_msg_actual_len
    sub     bl, cl
    shr     bl, 1
    mov     edi, eax
    movzx   esi, bl
    mov     rdx, game_over_msg
    xor     eax, eax
    call    mvprintw

    popa_std
    ret



ensure_paddle_within_bounds:
    mov     ax, [paddle_x_internal]
    cmp     ax, 0
    jge     .paddle_check_right

    mov     word [paddle_x_internal], 0
    jmp     .paddle_check_done

.paddle_check_right:
    mov     ax, [paddle_x_internal]
    mov     bx, [paddle_char_count]
    mov     cx, INTERNAL_SCALE
    imul    bx, cx                          ; Внутреняя длина ракетки
    add     ax, bx
    mov     bx, [screen_width_symbols]
    mov     cx, INTERNAL_SCALE
    imul    bx, cx                          ; Внутреняя длина поля
    cmp     ax, bx
    jle     .paddle_check_done

    mov     ax, [screen_width_symbols]
    mov     cx, INTERNAL_SCALE
    imul    ax, cx
    mov     dx, [paddle_char_count]
    mov     si, INTERNAL_SCALE
    imul    dx, si
    sub     ax, dx
    mov     word [paddle_x_internal], ax

.paddle_check_done:
    ret



update_one_ball_state:
    push    rax
    push    rbx
    push    rdx
    push    r8

    mov     r8, rdi
    mov     ax, [all_balls.x_coords + r8 * 2]
    xor     dx, dx
    mov     bx, INTERNAL_SCALE
    div     bx
    mov     word [all_balls.old_x_pos + r8 * 2], ax

    mov     ax, [all_balls.y_coords + r8 * 2]
    xor     dx, dx
    mov     bx, INTERNAL_SCALE
    div     bx
    mov     word [all_balls.old_y_pos + r8 * 2], ax

    movsx   ax, byte [all_balls.dx_speeds + rdi]
    add     word [all_balls.x_coords + r8 * 2], ax

    movsx   ax, byte [all_balls.dy_speeds + rdi]
    add     word [all_balls.y_coords + r8 * 2], ax

    pop     r8
    pop     rdx
    pop     rbx
    pop     rax
    ret



handle_one_ball_collision:
    pusha_std
    push    r8
    push    r9 

    mov     r9, rdi 
    mov     r8, rdi 
    mov     ax, word [all_balls.x_coords + r8 * 2]
    cmp     ax, 0
    jg      .right_wall_check

    mov     al, byte [all_balls.bonus_types + r9]
    cmp     al, BONUS_PHASING
    jne     .skip_phasing_left

    mov     ax, word [all_balls.x_coords + r8 * 2]
    mov     bx, word [screen_width_symbols]
    mov     cx, INTERNAL_SCALE
    imul    bx, cx
    dec     bx
    mov     word [all_balls.x_coords + r8 * 2], bx
    jmp     .top_wall_check

.skip_phasing_left:
    mov     word [all_balls.x_coords + r8 * 2], 0
    mov     cl, [all_balls.dx_speeds + r9]
    neg     cl
    mov     byte [all_balls.dx_speeds + r9], cl
    mov     ax, 0 
    jmp     .top_wall_check

.right_wall_check:
    mov     ax, word [all_balls.x_coords + r8 * 2]
    mov     cx, word [screen_width_symbols]
    mov     dx, INTERNAL_SCALE
    imul    cx, dx
    dec     cx
    cmp     ax, cx
    jl      .top_wall_check

    mov     al, byte [all_balls.bonus_types + r9]
    cmp     al, BONUS_PHASING
    jne     .skip_phasing_right

    mov     word [all_balls.x_coords + r8 * 2], 0
    mov     ax, 0
    jmp     .top_wall_check

.skip_phasing_right:
    mov     word [all_balls.x_coords + r8 * 2], cx
    mov     cl, [all_balls.dx_speeds + r9]
    neg     cl
    mov     byte [all_balls.dx_speeds + r9], cl
    mov     ax, cx

.top_wall_check:
    mov     dx, word [all_balls.y_coords + r8 * 2] 
    cmp     dx, 0
    jg      .paddle_check
    mov     word [all_balls.y_coords + r8 * 2], 0
    mov     cl,[all_balls.dy_speeds + r9]
    neg     cl
    mov     byte [all_balls.dy_speeds + r9], cl
    mov     dx, 0 
    jmp     .collision_done

.paddle_check:
    mov     ax, word [all_balls.y_coords + r8 * 2] 
    mov     cx, word [paddle_y_internal]   

    cmp     ax, cx
    jle     .bottom_wall_check

    mov     ax, word [all_balls.x_coords + r8 * 2] 
    mov     cx, word [paddle_x_internal]              
    mov     si, word [paddle_x_internal]            
    mov     bx, [paddle_char_count]
    mov     di, INTERNAL_SCALE 
    imul    bx, di
    add     si, bx
    dec     si

    cmp     ax, cx
    jl      .bottom_wall_check 

    cmp     ax, si
    jg      .bottom_wall_check 

    neg     byte [all_balls.dy_speeds + r9]

    mov     ax, [paddle_y_internal]
    mov     cx, INTERNAL_SCALE
    sub     ax, cx
    inc     ax
    mov     word [all_balls.y_coords + r8 * 2], ax
    mov     bx, [paddle_char_count]
    mov     di, INTERNAL_SCALE
    imul    bx, di 
    mov     ax, word [all_balls.x_coords + r8 * 2] 
    sub     ax, word [paddle_x_internal] 
    mov     cx, bx 
    shr     cx, 1
    cmp     ax, cx 
    jl      .paddle_hit_left
    jg      .paddle_hit_right

.paddle_hit_center:
    jmp     .paddle_dx_set

.paddle_hit_left:
    neg     byte [all_balls.dx_speeds + r9]
    jmp     .paddle_dx_set

.paddle_hit_right:
    jmp     .paddle_dx_set

.paddle_dx_set:
    inc     byte [player_lives]

    mov     al, byte [all_balls.bonus_types + r9]
    cmp     al, BONUS_EXTRA_LIFE
    jne     .1

    inc     byte [player_lives]
    jmp     .check_max_life

.1:
    mov     al, byte [all_balls.bonus_types + r9]
    cmp     al, BONUS_ACC_DX
    jne     .2

    mov     al, [all_balls.dx_speeds + r9]
    cmp     al, 0
    jg      .inc_dx

    dec     [all_balls.dx_speeds + r9]
    dec     [all_balls.dx_speeds + r9]
    dec     [all_balls.dx_speeds + r9]

    jmp     .check_max_life

    .inc_dx:
    inc     [all_balls.dx_speeds + r9]
    inc     [all_balls.dx_speeds + r9]
    inc     [all_balls.dx_speeds + r9]

    jmp     .check_max_life

.2:
    mov     al, byte [all_balls.bonus_types + r9]
    cmp     al, BONUS_ACC_DY
    jne     .check_max_life

    mov     al, [all_balls.dy_speeds + r9]
    cmp     al, 0
    jg      .inc_dy
    
    dec     [all_balls.dy_speeds + r9]
    dec     [all_balls.dy_speeds + r9]
    dec     [all_balls.dy_speeds + r9]

    jmp     .check_max_life

    .inc_dy:
    inc     [all_balls.dy_speeds + r9]
    inc     [all_balls.dy_speeds + r9]
    inc     [all_balls.dy_speeds + r9]

    jmp     .check_max_life
    

.check_max_life:
    movsx   ax, [player_lives]
    cmp     ax, MAX_LIVES
    jle     .collision_done

    mov     byte [player_lives], MAX_LIVES

    jmp     .collision_done

.bottom_wall_check:
    mov     ax, word [all_balls.y_coords + r8 * 2] 
    mov     cx, word [paddle_y_internal]
    mov     dx, GAME_OVER_Y_LINE
    mov     si, INTERNAL_SCALE
    imul    dx, si
    add     cx, dx
    cmp     ax, cx 
    jl      .collision_done

    mov     al, byte [all_balls.bonus_types + r9]
    cmp     al, BONUS_EXTRA_DAMAGE
    jne     .skip_extra_damage
    dec     byte [player_lives]

.skip_extra_damage:
    dec     byte [player_lives]
    cmp     byte [player_lives], 0
    jg      .respawn_ball
    mov     byte [player_lives], 0
    mov     byte [game_over_flag], 1
    jmp     .collision_done

.respawn_ball:
    mov     rdi, r9 
    call    _reset_ball_at_index

.collision_done:

    pop     r9
    pop     r8
    popa_std
    ret




is_coord_visible_for_drawing:
    cmp     edi, 0
    jl      .not_visible

    movzx   eax, word [screen_height_symbols]
    cmp     edi, eax
    jge     .not_visible

    cmp     esi, 0
    jl      .not_visible

    movzx   eax, word [screen_width_symbols]
    cmp     esi, eax
    jge     .not_visible

    clc
    ret



.not_visible:
    stc
    ret




open_urandom_device:
    push    rax

    mov     rdi, f_urandom_path
    mov     rsi, 0
    mov     rax, SYS_OPEN
    syscall
    mov     [urandom_fd], eax

    pop     rax
    ret



read_one_random_byte:
    pusha_std

    mov     edi, [urandom_fd]
    mov     rsi, random_byte_storage
    mov     rdx, 1
    mov     rax, SYS_READ
    syscall
    cmp     rax, 1
    jne     .read_error
    clc
    jmp     .finish_reading
    
.read_error:
    stc
.finish_reading:
    popa_std
    ret



close_urandom_device:
    pusha_std
    mov     edi,[urandom_fd]
    cmp     edi,-1
    je      .s_c_c_cudo
    mov     rax,SYS_CLOSE
    syscall
.s_c_c_cudo:
    popa_std
    ret



map_byte_to_speed_component:
    push    rax
    push    rdx

    xor     ah, ah
    mov     dl, 14
    div     dl 
    movzx   ebx, ah
    mov     al, [speed_map_table + rbx]
    mov     bl, al

    pop     rdx
    pop     rax
    ret