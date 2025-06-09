format elf64
public _start

section '.text' executable

_start:
    call clear_screen

    call check_registration
    call init_db_file

    main_loop:
        call show_menu
        call read_input
        call process_input
        jmp main_loop

    exit_program:
        call clear_screen
        mov rax, SYS_EXIT
        xor rdi, rdi
        syscall

;=======================================
; Инициализация файла 
;=======================================

check_registration:
    ; Открываем settings.txt для чтения
    mov rax, SYS_OPEN
    lea rdi, [settings_file]
    mov rsi, O_RDONLY
    xor rdx, rdx
    syscall

    cmp rax, 0
    jl .register  ; Если файл не существует

    mov [fd], rax ; Сохраняем дескриптор

    ; Читаем первую строку
    lea rsi, [reg_buffer]
    mov rdx, 256
    mov rax, SYS_READ
    mov rdi, [fd]
    syscall

    ; Закрываем файл
    mov rax, SYS_CLOSE
    mov rdi, [fd]
    syscall

    test rax, rax
    js .register  ; Если ошибка чтения

    cmp byte [reg_buffer], 0
    je .register  ; Если строка пустая

    ; Выводим приветствие
    lea rsi, [hello_msg]
    mov rdx, hello_len
    call print
    lea rsi, [reg_buffer]
    call print_str
    ret

.register:
    ; Предлагаем регистрацию
    lea rsi, [reg_msg]
    mov rdx, reg_len
    call print

    ; Читаем имя пользователя
    mov rax, SYS_READ
    mov rdi, STDIN
    lea rsi, [reg_buffer]
    mov rdx, 256
    syscall

    ; Записываем имя в файл
    mov rax, SYS_OPEN
    lea rdi, [settings_file]
    mov rsi, O_WRONLY or O_CREAT or O_TRUNC
    mov rdx, 0644o
    syscall
    mov [fd], rax

    lea rax, [reg_buffer]
    call len_str
    sub rax, 1
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, [fd]
    lea rsi, [reg_buffer]
    syscall

    mov rax, SYS_CLOSE
    mov rdi, [fd]
    syscall
    
    jmp check_registration

; ========== Вспомогательные функции ==========
print:
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    syscall
    ret

print_str:
    mov rdx, 0
.count:
    cmp byte [rsi + rdx], 0
    je .done
    inc rdx
    jmp .count
.done:
    call print
    ret

init_db_file:
    mov rdi, db_filename
    mov rsi, O_RDONLY
    call open_file
    cmp rax, 0
    jge .file_exists
    
    mov rdi, db_filename
    mov rsi, O_CREAT or O_WRONLY
    mov rdx, S_IRUSR or S_IWUSR
    call open_file
    mov [db_fd], rax
    mov rdi, rax
    call close_file
    ret
    
    .file_exists:
        mov [db_fd], rax
        mov rdi, rax
        call close_file
        ret

;=======================================
; Показать меню
;=======================================
show_menu:
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov rsi, menu_text
    mov rdx, menu_len
    syscall
    mov rbx, 1
    ret

;=======================================
; Прочитать ввод пользователя
;=======================================
read_input:
    mov rax, SYS_READ
    mov rdi, STDIN
    mov rsi, input_buffer
    mov rdx, 2
    syscall
    ret

;=======================================
; Обработка ввода
;=======================================
process_input:
    mov al, [input_buffer]
    cmp al, '1'
    je add_event
    cmp al, '2'
    je edit_event
    cmp al, '3'
    je delete_event
    cmp al, '4'
    je show_events
    cmp al, '5'
    je export_events
    cmp al, '6'
    je exit_program

    
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov rsi, error_msg
    mov rdx, error_len
    syscall
    ret

;=======================================
; Добавление события
;=======================================
add_event:

    call clear_buffers

    ; Запрос даты
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov rsi, date_prompt
    mov rdx, date_prompt_len
    syscall
    
    ; Чтение даты
    mov rax, SYS_READ
    mov rdi, STDIN
    mov rsi, date_buffer
    mov rdx, 11
    syscall
    
    ; Запрос времени
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov rsi, time_prompt
    mov rdx, time_prompt_len
    syscall
    
    ; Чтение времени
    mov rax, SYS_READ
    mov rdi, STDIN
    mov rsi, time_buffer
    mov rdx, 6
    syscall
    
    ; Запрос описания
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov rsi, desc_prompt
    mov rdx, desc_prompt_len
    syscall
    
    ; Чтение описания
    mov rax, SYS_READ
    mov rdi, STDIN
    mov rsi, desc_buffer
    mov rdx, 100
    syscall
    
    
    call clean_inputs
    
    ; Открываем файл
    mov rdi, db_filename
    mov rsi, O_WRONLY or O_APPEND
    call open_file
    mov [db_fd], rax

    ; Формируем запись
    ; 1. [дата
    mov rdi, open_br
    mov rsi, date_buffer
    call concat_strings

    mov rdi, rax
    mov rsi, space
    call concat_strings
    
    ; 2. [дата время
    mov rdi, rax
    mov rsi, time_buffer
    call concat_strings
    
    ; 3. [дата время] 
    mov rdi, rax
    mov rsi, close_br
    call concat_strings

    mov rdi, rax
    mov rsi, space
    call concat_strings
    
    ; 4. [дата время] описание
    mov rdi, rax
    mov rsi, desc_buffer
    call concat_strings

    ; Копируем результат в event_record
    mov rsi, rax
    mov rdi, event_record
    mov rcx, rdx
    rep movsb

    ; Добавляем перевод строки в конце
    mov byte [rdi], 0xA
    
    ; Записываем в файл
    mov rax, [db_fd]
    mov rsi, event_record
    lea rdx, [rcx+1]     ; Длина + перевод строки
    call write_file

    ; Закрываем файл
    mov rdi, [db_fd]
    call close_file

    call clear_screen
    ret

clear_buffers:
    ; Очистка date_buffer
    mov rdi, date_buffer
    mov rcx, 11
    call clear_buffer

    ; Очистка time_buffer
    mov rdi, time_buffer
    mov rcx, 6
    call clear_buffer

    ; Очистка desc_buffer
    mov rdi, desc_buffer
    mov rcx, 100
    call clear_buffer

    mov rdi, event_record
    mov rcx, 100
    call clear_buffer
    
    mov rdi, concat_buffer
    mov rcx, 100
    call clear_buffer
    ret

clear_buffer:
    ; Вход: RDI - адрес буфера, RCX - размер
    xor al, al
    rep stosb
    ret

clean_inputs:
    ; Удаляем \n из date_buffer
    mov rdi, date_buffer
    call trim_newline
    
    ; Удаляем \n из time_buffer
    mov rdi, time_buffer
    call trim_newline
    
    ; Удаляем \n из desc_buffer
    mov rdi, desc_buffer
    call trim_newline
    ret

trim_newline:
    ; Ищем \n в строке и заменяем на 0
    mov rcx, 100
    .loop:
        cmp byte [rdi], 0xA
        jne .next
        mov byte [rdi], 0
        ret
    .next:
        inc rdi
        loop .loop
        ret

;=======================================
; Редактирование события
;=======================================
edit_event:
    call delete_event
    cmp rbx, 0             ; Проверяем флаг успешного удаления
    je .skip_add           ; Если удаление не удалось (rbx=0), пропускаем добавление
    call add_event         ; Добавляем новое событие
.skip_add:
    ret

;=======================================
; Удаление события
;=======================================
delete_event:
    push r12
    push r13
    push r14
    push r15
    

    ; Получение ввода
    call clear_buffers
    call get_delete_input
    call clean_inputs

    ; Формирование паттерна поиска
    mov rdi, open_br
    mov rsi, date_buffer
    call concat_strings        ; [дата
    mov rdi, rax
    mov rsi, space
    call concat_strings        ; [дата 
    mov rdi, rax
    mov rsi, time_buffer
    call concat_strings        ; [дата время
    mov rdi, rax
    mov rsi, close_br_space    ; "] "
    call concat_strings        ; [дата время] 
    mov r12, rax              ; Сохраняем паттерн
    mov r13, rdx              ; Длина паттерна

    ; Чтение файла
    mov rdi, db_filename
    mov rsi, O_RDONLY
    call open_file
    cmp rax, -1
    je .error
    mov r14, rax              ; File descriptor

    mov rdi, rax
    mov rsi, buffer
    mov rdx, 4096
    call read_file
    mov r15, rax              ; Размер файла
    call close_file

    ; Поиск и удаление
    mov rdi, buffer
    mov rsi, r12
    mov rdx, r13
    mov rcx, r15
    call remove_matching_lines
    test rax, rax
    jz .not_found

    ; Запись обновленного файла
    mov rdi, db_filename
    mov rsi, O_WRONLY or O_TRUNC
    call open_file
    cmp rax, -1
    je .error
    mov r14, rax

    mov rdi, rax
    mov rsi, buffer
    mov rdx, r8               ; Новая длина
    call write_file
    call close_file

    jmp .cleanup

.not_found:
    mov rsi, not_found_msg
    mov rdx, not_found_len
    call print_message
    xor rbx, rbx
    jmp .cleanup

.error:
    mov rsi, open_error_msg
    mov rdx, open_error_len
    call print_message

.cleanup:
    
    pop r15
    pop r14
    pop r13
    pop r12
    call clear_screen
    ret


; ============================================
; Очистка консоли
; ============================================
clear_screen:
    mov rax, 1           ; sys_write
    mov rdi, 1           ; stdout
    lea rsi, [clear_seq]
    mov rdx, clear_len
    syscall
    ret
;=======================================
; Вспомогательные функции
;=======================================

get_delete_input:
    ; Запрос даты
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    lea rsi, [date_prompt]
    mov rdx, date_prompt_len
    syscall
    
    mov rax, SYS_READ
    mov rdi, STDIN
    lea rsi, [date_buffer]
    mov rdx, 11
    syscall
    call trim_input
    
    ; Запрос времени
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    lea rsi, [time_prompt]
    mov rdx, time_prompt_len
    syscall
    
    mov rax, SYS_READ
    mov rdi, STDIN
    lea rsi, [time_buffer]
    mov rdx, 6
    syscall
    call trim_input
    ret

trim_input:
    dec rax
    mov byte [rsi + rax], 0
    ret

open_read_file:
    mov rax, SYS_OPEN
    lea rdi, [db_filename]
    mov rsi, O_RDONLY
    syscall
    ret

read_entire_file:
    mov rdi, r14
    mov rax, SYS_READ
    lea rsi, [buffer]
    mov rdx, 4096
    syscall
    ret

;=======================================
; Удаление совпадающих строк
; Вход: RDI=буфер, RSI=паттерн, RDX=длина паттерна, RCX=размер файла
; Выход: RAX=1 (найдено), 0 (не найдено), R8=новая длина
;=======================================
remove_matching_lines:
    xor r8, r8        ; Новый индекс
    xor r9, r9        ; Текущий индекс
    xor r10, r10      ; Флаг найденных совпадений
    mov r11, rcx      ; Сохраняем исходный размер

.loop:
    cmp r9, r11
    jge .done

    ; Проверка на совпадение
    mov rax, r9
    add rax, rdx
    cmp rax, r11
    jg .copy_rest

    push rdi
    push rsi
    push rcx
    add rdi, r9
    mov rcx, rdx
    repe cmpsb
    pop rcx
    pop rsi
    pop rdi
    jne .copy_byte

    ; Найдено совпадение
    mov r10, 1
    add r9, rdx

    ; Ищем конец строки
.find_eol:
    cmp r9, r11
    jge .adjust_size
    cmp byte [rdi + r9], 0xA
    je .found_eol
    inc r9
    jmp .find_eol

.found_eol:
    inc r9            ; Пропускаем \n
    jmp .loop

.copy_byte:
    mov al, [rdi + r9]
    mov [rdi + r8], al
    inc r9
    inc r8
    jmp .loop

.copy_rest:
    cmp r9, r11
    jge .done
    mov al, [rdi + r9]
    mov [rdi + r8], al
    inc r9
    inc r8
    jmp .copy_rest

.adjust_size:
    mov r8, r9        ; Корректируем размер

.done:
    ; Очищаем оставшуюся часть буфера
    mov rcx, 4096
    sub rcx, r8
    add rdi, r8
    xor al, al
    rep stosb

    mov rax, r10
    ret

write_updated_file:
    ; Открываем файл для записи
    mov rax, SYS_OPEN
    lea rdi, [db_filename]
    mov rsi, O_WRONLY or O_TRUNC
    mov rdx, 0644o
    syscall
    
    ; Запись нового содержимого
    mov rdi, rax
    mov rax, SYS_WRITE
    lea rsi, [buffer]
    mov rdx, r8
    syscall
    
    ; Закрываем файл
    mov rax, SYS_CLOSE
    syscall
    ret

print_message:
    xor rdx, rdx
.loop:
    cmp byte [rsi + rdx], 0
    je .done
    inc rdx
    jmp .loop
.done:
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    syscall
    ret
;=======================================
; Показ всех событий
;=======================================
show_events:
    call clear_screen
    push rdi
    push rsi
    push rbx

    ; Открываем файл events.txt для чтения
    lea rdi, [db_filename]  ; Указатель на имя файла
    mov rsi, O_RDONLY       ; Режим чтения
    call open_file
    cmp rax, 0              ; Проверка на ошибку
    jl .error

    ; Сохраняем дескриптор файла
    mov rbx, rax

    ; Читаем содержимое файла
    mov rdi, rax
    call read_file

    ; Закрываем файл
    mov rdi, rbx
    call close_file

    ; Выводим содержимое буфера в консоль
    call output_buffer_in_console

    jmp .exit

.error:
    ; Дополнительная обработка ошибок при необходимости

.exit:
    pop rbx
    pop rsi
    pop rdi
    ret

export_events:
    ; Открытие файлов
    mov  rax, SYS_OPEN
    lea  rdi, [event_filename]
    mov  rsi, O_RDONLY
    xor  rdx, rdx
    syscall
    cmp  rax, 0
    jl   exp_exit_error
    mov  [event_fd], rax

    mov  rax, SYS_OPEN
    lea  rdi, [export_filename]
    mov  rsi, O_WRONLY or O_CREAT or O_TRUNC
    mov  rdx, 0644o
    syscall
    cmp  rax, 0
    jl   exp_exit_error
    mov  [export_fd], rax

    mov  rax, SYS_WRITE
    mov  rdi, [export_fd]
    lea  rsi, [head]
    mov  rdx, 38
    syscall

.read_loop:
    ; Чтение символа
    mov  rax, SYS_READ
    mov  rdi, [event_fd]
    lea  rsi, [exp_buffer]
    mov  rdx, 1
    syscall

    cmp  rax, 1
    jne  .close_files

    ; Проверка специальных символов
    cmp  byte [exp_buffer], 0x0A  ; '\n'
    je   .print_1
    cmp  byte [exp_buffer], 0x5D  ; ']'
    je   .print_2
    cmp  byte [exp_buffer], 0x5B  ; '['
    je   .print_3

.write_char:
    ; Запись символа в файл
    mov  rax, SYS_WRITE
    mov  rdi, [export_fd]
    lea  rsi, [exp_buffer]
    mov  rdx, 1
    syscall
    jmp  .read_loop

.print_1:
    ; Запись символа в файл
    mov  rax, SYS_WRITE
    mov  rdi, [export_fd]
    lea  rsi, [exp_buffer]
    mov  rdx, 1
    syscall

    mov  rax, SYS_WRITE
    mov  rdi, [export_fd]
    lea  rsi, [l_line]
    mov  rdx, 43
    syscall
    
    jmp  .read_loop

.print_2:
    ; Запись символа в файл
    mov  rax, SYS_WRITE
    mov  rdi, [export_fd]
    lea  rsi, [exp_buffer]
    mov  rdx, 1
    syscall

    mov  rax, SYS_WRITE
    mov  rdi, [export_fd]
    lea  rsi, [n_line]
    mov  rdx, 3
    syscall
    
    jmp  .read_loop

.print_3:

    mov  rax, SYS_WRITE
    mov  rdi, [export_fd]
    lea  rsi, [h_line]
    mov  rdx, 44
    syscall

    ; Запись символа в файл
    mov  rax, SYS_WRITE
    mov  rdi, [export_fd]
    lea  rsi, [exp_buffer]
    mov  rdx, 1
    syscall



    jmp  .read_loop

.close_files:
    ; Закрытие файлов
    mov  rax, SYS_CLOSE
    mov  rdi, [event_fd]
    syscall
    mov  rax, SYS_CLOSE
    mov  rdi, [export_fd]
    syscall
    call clear_screen
    ret
    
exp_exit_error:
    mov  rax, SYS_EXIT
    mov  rdi, 1
    syscall
;=======================================
; Вывод буфера в консоль
; Вход: RSI = буфер, RDX = размер
;=======================================
print_buffer:
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    syscall
    ret
;=======================================
; Длина строки
; Вход: RAX = адрес строки
; Выход: RAX = длина строки
;=======================================
len_str:
    push rdi
    mov rdi, rax
    xor rax, rax
.count_loop:
    cmp byte [rdi], 0
    je .done
    inc rax
    inc rdi
    jmp .count_loop
.done:
    pop rdi
    ret

; Аргументы:
; rdi - указатель на первую строку (нуль-терминированную)
; rsi - указатель на вторую строку (нуль-терминированную)

; Возвращает:
; rax - указатель на результат (buffer)
; rdx - общая длина строки (без нуль-терминатора)
concat_strings:
    push rbx
    push r12
    push rdi
    push rsi

    ; Сохраняем исходные указатели
    mov rbx, rdi      ; Первая строка
    mov r12, rsi      ; Вторая строка

    ; Вычисляем длину первой строки
    call strlen
    mov r8, rax       ; r8 = длина первой строки

    ; Вычисляем длину второй строки
    mov rdi, r12
    call strlen
    mov r9, rax       ; r9 = длина второй строки

    ; Проверка переполнения буфера
    mov rcx, r8
    add rcx, r9
    cmp rcx, 255
    jbe .copy_data

    ; Если переполнение - обрезаем до максимального размера
    mov r8, 255
    sub r8, r9
    jns .copy_data
    xor r8, r8        ; Если даже одна строка длиннее 255

.copy_data:
    lea rdi, [concat_buffer] ; Начало буфера
    mov rsi, rbx      ; Копируем первую строку
    mov rcx, r8
    rep movsb

    mov rsi, r12      ; Копируем вторую строку
    mov rcx, r9
    rep movsb

    ; Устанавливаем возвращаемые значения
    lea rax, [concat_buffer]
    mov rdx, r8
    add rdx, r9

    pop rsi
    pop rdi
    pop r12
    pop rbx
    ret

strlen:
    xor rcx, rcx
    not rcx
    xor al, al
    repne scasb
    not rcx
    dec rcx
    mov rax, rcx
    ret

; input		rdi - file name
;			rsi - mode
; output	rax - file descriptor
open_file:
	mov rax, SYS_OPEN 
  	mov rdx, 777o	; Права доступа (rwx для всех)
  	syscall 
	ret

; input		rdi - file descriptor
close_file:
	mov rax, SYS_CLOSE
	syscall
	ret

; input		rax - file descriptor
;			rsi - string
write_file:

	mov r8, rax 	; Сохраняем файловый дескриптор
	
	mov r9, rsi		; Сохраняем сторку для записи в файл
	
	mov rax, r9
	call len_str	; Получаем длинну строки и сохраняем в rax

	mov rdx, rax
	mov rax, SYS_WRITE
	mov rdi, r8
	mov rsi, r9
	syscall
	ret

; input		rdi - file descriptor
; output	buffer - text
read_file:
	mov rax, SYS_READ
    mov rsi, buffer		; Буфер
    mov rdx, 4096      	; Размер буфера
    syscall
	ret

; input		buffer - text
output_buffer_in_console:
	mov rdx, 4096        ; Количество байт
    mov rax, SYS_WRITE
    mov rdi, STDOUT		; Вывод в консоль
    mov rsi, buffer		; Данные
    syscall
	ret

;=======================================
; Данные программы
;=======================================
section '.data' writable
    ; Основные сообщения меню
    menu_text db 10, '=== Daily Planner ===', 10
              db '1. Add new event', 10
              db '2. Edit event', 10
              db '3. Delete event', 10
              db '4. View all events', 10
              db '5. Export events', 10
              db '6. Exit', 10
              db 'Your choice: ', 0
    menu_len = $ - menu_text
    
    ; Сообщения об ошибках
    error_msg db 10, 'Error: Invalid input!', 10, 10, 0
    error_len = $ - error_msg
    
    open_error_msg db 'Error opening file!', 0xA, 0
    open_error_len = $ - open_error_msg
    
    read_error_msg db 'Error reading file!', 0xA, 0
    read_error_len = $ - read_error_msg
    
    write_error_msg db 'Error writing to file!', 0xA, 0
    write_error_len = $ - write_error_msg

    buffer_overflow_msg db 'Error: Buffer overflow!', 0xA, 0
    buffer_overflow_len = $ - buffer_overflow_msg

    ; Сообщения для функций
    add_msg db 10, '=== Add New Event ===', 10, 0
    add_msg_len = $ - add_msg
    
    edit_msg db 10, '=== Edit Event ===', 10, 'Enter event number to edit: ', 0
    edit_msg_len = $ - edit_msg
    
    delete_msg db 10, '=== Delete Event ===', 10, 'Enter event number to delete: ', 0
    delete_msg_len = $ - delete_msg
    
    view_msg db 10, '=== All Events ===', 10, 0
    view_msg_len = $ - view_msg
    
    ; Подсказки для ввода
    date_prompt db 'Enter date (YYYY-MM-DD): ', 0
    date_prompt_len = $ - date_prompt
    
    time_prompt db 'Enter time (HH:MM): ', 0
    time_prompt_len = $ - time_prompt
    
    desc_prompt db 'Enter description: ', 0
    desc_prompt_len = $ - desc_prompt

    edit_date_prompt db 'Enter date to edit (YYYY-MM-DD): ',0
    edit_date_prompt_len = $ - edit_date_prompt
    
    edit_time_prompt db 'Enter time to edit (HH:MM): ',0
    edit_time_prompt_len = $ - edit_time_prompt
    
    new_date_prompt db 'Enter new date (YYYY-MM-DD): ',0
    new_date_prompt_len = $ - new_date_prompt
    
    new_time_prompt db 'Enter new time (HH:MM): ',0
    new_time_prompt_len = $ - new_time_prompt
    
    new_desc_prompt db 'Enter new description: ',0
    new_desc_prompt_len = $ - new_desc_prompt

    
    ; Сообщения об успехе
    success_add db 10, 'Event added successfully!', 10, 10, 0
    success_add_len = $ - success_add
    
    success_edit db 10, 'Event edited successfully!', 10, 10, 0
    success_edit_len = $ - success_edit
    
    success_delete db 10, 'Event deleted successfully!', 10, 10, 0
    success_delete_len = $ - success_delete
    not_found_msg db 10,'Event not found!',10,10,0
    not_found_len = $ - not_found_msg
    
    ; Буферы для создания события
    input_buffer rb 3       ; Для выбора меню (2 цифры + enter)
    num_buffer rb 5         ; Для ввода номеров событий
    date_buffer rb 11       ; YYYY-MM-DD + null
    time_buffer rb 6        ; HH:MM + null
    desc_buffer rb 100      ; Описание события
    event_record rb 150    ; Полная запись события
    open_br  db '[', 0
    close_br db ']', 0
    space db ' ', 0
    temp_str db '', 0

    close_br_space db '] ',0

    new_date_buffer rb 11
    new_time_buffer rb 6
    new_desc_buffer rb 100
    new_file_size rq 1
    file_size dq 0

    debug_pos_msg db 'DEBUG: Position=',0
    debug_pos_len = $ - debug_pos_msg
    debug_size_msg db ' DEBUG: Size=',0
    debug_size_len = $ - debug_size_msg
    new_line db 0xA,0

    ; Технические переменные
    db_filename db "events.txt", 0
    db_fd dq 0              ; File descriptor
    event_counter dd 0      ; Счетчик событий
    concat_buffer rb 256          ; Внутренний буфер для конкатенации строк



    settings_file db "settings.txt",0
    fd dq 0
    hello_msg db 0xE2, 0x98, 0x95, " Hello, "
    hello_len = $ - hello_msg

    reg_msg db "Please register. Enter your name: ",0
    reg_len = $ - reg_msg

    reg_buffer rb 256

    clear_seq db 0x1B, '[2J', 0x1B, '[H'  ; Escape-последовательность
    clear_len = $ - clear_seq              ; Длина последовательности

    event_filename db "events.txt",0
    export_filename db "export.txt",0
    smile db 0xF0,0x9F,0x98,0x8A
    head db "======Your Events", 0xF0,0x9F,0x98,0x8A, "======         ", 0x0A, 0x0A
    l_line            db "-----------------------------------------", 0x0A, 0x0A
    n_line           db 0x0A, "|", 0x09
    h_line         db "-----------------------------------------", 0x0A, "|", 0x09
    event_fd       dq 0
    export_fd      dq 0
    exp_buffer         db 0

    ; Системные вызовы Linux x86_64
    SYS_READ      = 0
    SYS_WRITE     = 1
    SYS_OPEN      = 2
    SYS_CLOSE     = 3
    SYS_EXIT      = 60
    SYS_FORK      = 57
    SYS_WAIT4     = 61
    SYS_LSEEK     = 8
    SYS_FTRUNCATE = 77
    SYS_UNLINK = 87

    ; Флаги для open()
    O_RDONLY      = 0      ; Только чтение
    O_WRONLY      = 1      ; Только запись
    O_RDWR        = 2      ; Чтение и запись
    O_CREAT       = 64     ; Создать если не существует
    O_APPEND      = 1024   ; Добавление в конец файла
    O_TRUNC       = 512    ; Очистить файл при открытии

    ; Стандартные файловые дескрипторы
    STDIN         = 0      ; Стандартный ввод
    STDOUT        = 1      ; Стандартный вывод
    STDERR        = 2      ; Стандартный вывод ошибок

    ; Права доступа к файлу (mode)
    S_IRWXU       = 0700o  ; rwx для владельца
    S_IRUSR       = 0400o  ; read для владельца
    S_IWUSR       = 0200o  ; write для владельца
    S_IXUSR       = 0100o  ; execute для владельца
    S_IRWXG       = 0070o  ; rwx для группы
    S_IRGRP       = 0040o  ; read для группы
    S_IWGRP       = 0020o  ; write для группы
    S_IXGRP       = 0010o  ; execute для группы
    S_IRWXO       = 0007o  ; rwx для других
    S_IROTH       = 0004o  ; read для других
    S_IWOTH       = 0002o  ; write для других
    S_IXOTH       = 0001o  ; execute для других

section '.bss' writable
    buffer rb 4096
    temp_buffer rb 8192       ; Увеличенный буфер
    position_buffer rb 16     ; Для отладочного вывода
    temp_buffer_size equ 16384  ; 16KB буфер