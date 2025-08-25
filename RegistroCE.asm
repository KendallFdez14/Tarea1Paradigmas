.model small  ; Programa pequeño: 64KB código, 64KB datos
.stack 100h   ; Pila de 256 bytes

.data
mensaje_bienvenida db 13, 10, "Bienvenidos/as a Registro CE $"
mensaje_digitar db 13, 10, "Digite: $"
mensaje_menu1 db 13, 10, "1. Ingresar calificaciones (hasta 15 estudiantes -Nombre Apellido1 Apellido2 Nota-).$"
mensaje_menu2 db 13, 10, "2. Mostrar estadisticas.$"
mensaje_menu3 db 13, 10, "3. Buscar estudiante por posicion (indice).$"
mensaje_menu4 db 13, 10, "4. Ordenar calificaciones (ascendente/descendente).$"
mensaje_menu5 db 13, 10, "5. Salir.$"
mensaje_error db 13, 10, "Opcion invalida. Intenta con otra opcion$"
mensaje_ingreso_estudiante db 13, 10, "Ingrese estudiante o 9 para salir al menu principal:$"
mensaje_maximoIngreso db 13, 10, "Se alcanzo el maximo de 15 estudiantes$"
mensaje_despedidaPrograma db 13, 10, "Gracias por usar Registro CE$"

opcion_escogida db 0
num_estudiantes db 0

entrada_buffer db 60
               db ?
               db 60 dup(?)        ; CORREGIDO: uso de dup(?) en lugar de "$"

nombres db 15 dup(60 dup(?))       ; CORREGIDO
notas dw 15 dup(?)                 ; CORREGIDO

.code
inicio:
    mov ax, @data
    mov ds, ax

mostrar_menu:
    lea dx, mensaje_bienvenida
    mov ah, 9
    int 21h

    lea dx, mensaje_digitar
    mov ah, 9
    int 21h

menu:
    lea dx, mensaje_menu1
    mov ah, 9
    int 21h

    lea dx, mensaje_menu2
    mov ah, 9
    int 21h

    lea dx, mensaje_menu3
    mov ah, 9
    int 21h

    lea dx, mensaje_menu4
    mov ah, 9
    int 21h

    lea dx, mensaje_menu5
    mov ah, 9
    int 21h

    mov ah, 01h
    int 21h
    sub al, '0'
    mov opcion_escogida, al

    cmp al, 1
    je opcion1
    cmp al, 2
    je opcion2
    cmp al, 3
    je opcion3
    cmp al, 4
    je opcion4
    cmp al, 5
    je salir

    lea dx, mensaje_error
    mov ah, 9
    int 21h
    jmp menu

opcion1:
    mov al, num_estudiantes
    cmp al, 15
    jae maximoIngreso
    jmp ingreso_ciclo

maximoIngreso:
    lea dx, mensaje_maximoIngreso
    mov ah, 9
    int 21h
    jmp menu

ingreso_ciclo:
    lea dx, mensaje_ingreso_estudiante
    mov ah, 9
    int 21h

    lea dx, entrada_buffer
    mov ah, 0Ah
    int 21h

    ; verificar si primer caracter es '9'
    mov al, entrada_buffer + 2
    cmp al, '9'
    je volverMenu

    ; copiar nombre
    mov bl, num_estudiantes
    xor bh, bh
    mov ax, bx
    mov bx, 60
    mul bx
    mov si, offset entrada_buffer + 2
    mov di, offset nombres
    add di, ax
    ;mov cx, 60 provoca error al copiar los nombres porque si son menos de 60 caracteres y por lo tanto lee bytes que no son del dato ingresado
    mov cl, entrada_buffer + 1  ; cuantos caracteres fueron realmente ingresados
    mov ch, 0                   ; limpiar parte alta
    cmp cx, 59
    jbe copiar_nombre
    mov cx, 59

    mov ax, ds
    mov es, ax

copiar_nombre:
    lodsb
    cmp al, ' '
    je fin_copia
    cmp al, 13
    je fin_copia
    stosb
    loop copiar_nombre
fin_copia:

    call parsear_nota

    inc num_estudiantes
    mov al, num_estudiantes
    cmp al, 15
    jb ingreso_ciclo

    jmp maximo_alcanzado

volverMenu:
    jmp menu

maximo_alcanzado:
    lea dx, mensaje_maximoIngreso
    mov ah, 9
    int 21h
    jmp menu

; =============================
; PARSEAR NOTA
; =============================
parsear_nota:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov cl, entrada_buffer+1
    xor ch, ch
    mov si, cx
    add si, 1

buscar_espacio:
    dec si
    cmp entrada_buffer+2[si], ' '
    jne buscar_espacio
    inc si

    xor bx, bx
    xor dx, dx
    xor di, di
    mov bp, 0

parsear_nota_loop:
    mov al, entrada_buffer+2[si]
    cmp al, 13
    je combinar_partes
    cmp al, 0
    je combinar_partes
    cmp al, '.'
    je activar_decimales

    cmp al, '0'
    jb combinar_partes
    cmp al, '9'
    ja combinar_partes

    sub al, '0'
    mov ah, 0

    cmp bp, 0
    je parte_entera

    ; decimal
    cmp di, 5          ; máximo 5 decimales
    jae siguiente
    mov cx, 10
    mul cx
    add dx, ax
    inc di
    jmp siguiente

parte_entera:
    mov cx, 10
    mul cx
    add bx, ax

siguiente:
    inc si
    jmp parsear_nota_loop

activar_decimales:
    mov bp, 1
    inc si
    jmp parsear_nota_loop

combinar_partes:
    mov cx, di
    mov di, 5
    sub di, cx

agregar_ceros:
    cmp di, 0
    je multiplicar
    mov cx, 10
    mul cx
    dec di
    jmp agregar_ceros

multiplicar:
    mov ax, bx
    mov cx, 10000
    mul cx
    mov cx, 10
    mul cx
    add ax, dx

    ; CORREGIDO: evitar sobreescribir ax para índice
    mov bl, num_estudiantes
    dec bl
    xor bh, bh
    mov cx, bx
    shl cx, 1                 ; índice * 2 porque cada nota es WORD

    mov si, offset notas
    add si, cx
    mov [si], ax             ; guardar nota

    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; =============================

opcion2:
    jmp menu

opcion3:
    jmp menu

opcion4:
    jmp menu

salir:
    lea dx, mensaje_despedidaPrograma
    mov ah, 09h
    int 21h
    mov ah, 4Ch
    int 21h

end inicio






