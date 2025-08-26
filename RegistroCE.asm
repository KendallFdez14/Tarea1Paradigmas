.model small
.stack 100h

.data
mensaje_bienvenida           db 13,10,"Bienvenidos/as a Registro CE $"
mensaje_digitar              db 13,10,"Digite: $"
mensaje_menu1                db 13,10,"1. Ingresar calificaciones (hasta 15 estudiantes -Nombre Apellido(s) Nota-).$"
mensaje_menu2                db 13,10,"2. Mostrar estadisticas.$"
mensaje_menu3                db 13,10,"3. Buscar estudiante por posicion (indice).$"
mensaje_menu4                db 13,10,"4. Ordenar calificaciones (ascendente/descendente).$"
mensaje_menu5                db 13,10,"5. Salir.$"
mensaje_error                db 13,10,"Opcion invalida. Intenta con otra opcion$"
mensaje_ingreso_estudiante   db 13,10,"Ingrese estudiante o 9 para salir al menu principal:$"
mensaje_maximoIngreso        db 13,10,"Se alcanzo el maximo de 15 estudiantes$"
mensaje_despedidaPrograma    db 13,10,"Gracias por usar Registro CE$"

; Mensajes extra
mensaje_formato_invalido     db 13,10,"Formato invalido. Use: Nombre(s) Apellido(s) Nota$"
mensaje_guardado             db 13,10,"Estudiante guardado.$"

; Pto. 3 (buscar)
mensaje_ingrese_posicion     db 13,10,"Ingrese posicion (1..15): $"
mensaje_no_registros         db 13,10,"No hay estudiantes registrados.$"
mensaje_posicion_invalida    db 13,10,"Posicion invalida.$"
mensaje_salto_linea          db 13,10,"$"

opcion_escogida  db 0
num_estudiantes  db 0

entrada_buffer   db 60, ?, 60 dup(?)
nombres          db 15 dup(60 dup(?))      ; 15 nombres de hasta 59 chars + '$'
notas            dd 15 dup(0)              ; punto fijo x100000 (32 bits)

tabla_desplaz_60 dw 0,60,120,180,240,300,360,420,480,540,600,660,720,780,840
buffer_fraccion  db 5 dup(0)

.code
inicio:
    mov ax, @data
    mov ds, ax

mostrar_menu:
    lea dx, mensaje_bienvenida
    call imprimir_cadena_dos
    lea dx, mensaje_digitar
    call imprimir_cadena_dos

menu:
    mov ax, @data
    mov ds, ax
    call limpiar_buffer_teclado

    lea dx, mensaje_menu1
    call imprimir_cadena_dos
    lea dx, mensaje_menu2
    call imprimir_cadena_dos
    lea dx, mensaje_menu3
    call imprimir_cadena_dos
    lea dx, mensaje_menu4
    call imprimir_cadena_dos
    lea dx, mensaje_menu5
    call imprimir_cadena_dos

leer_opcion_menu:
    mov ah, 08h
    int 21h
    cmp al, 0
    je  leer_opcion_menu
    cmp al, 13
    je  leer_opcion_menu
    cmp al, 10
    je  leer_opcion_menu
    cmp al, '1'
    jb  opcion_fuera_de_rango
    cmp al, '5'
    ja  opcion_fuera_de_rango

    sub al, '0'
    mov opcion_escogida, al

    cmp al, 1
    je  opcion1
    cmp al, 2
    je  opcion2
    cmp al, 3
    je  opcion3
    cmp al, 4
    je  opcion4
    jmp salir

opcion_fuera_de_rango:
    lea dx, mensaje_error
    call imprimir_cadena_dos
    jmp menu

; ====== OPCION 1: Ingreso (corta por ULTIMO ESPACIO) ======
opcion1:
    mov al, num_estudiantes
    cmp al, 15
    jae ingreso_lleno

ingreso_siguiente:
    lea dx, mensaje_ingreso_estudiante
    call imprimir_cadena_dos

    lea dx, entrada_buffer
    mov ah, 0Ah
    int 21h

    ; terminar linea con 0
    mov bl, [entrada_buffer+1]
    mov byte ptr [entrada_buffer+2+bx], 0

    ; si escriben solo '9' -> menu
    cmp bl, 1
    jne ingreso_parsear
    mov al, [entrada_buffer+2]
    cmp al, '9'
    jne ingreso_parsear
    call limpiar_buffer_teclado
    jmp menu

ingreso_parsear:
    lea si, [entrada_buffer+2]
    mov bx, si                  ; BX = inicio_nombre
    xor di, di                  ; DI = ultimo_espacio

; buscar ULTIMO espacio
ingreso_buscar_ultimo_espacio:
    lodsb
    cmp al, 0
    je  ingreso_fin_escaneo
    cmp al, 13
    je  ingreso_fin_escaneo
    cmp al, ' '
    jne ingreso_buscar_ultimo_espacio
    mov di, si
    dec di
    jmp ingreso_buscar_ultimo_espacio

ingreso_fin_escaneo:
    cmp di, 0
    je  ingreso_invalido

    ; longitud del nombre
    mov ax, di
    sub ax, bx
    jbe ingreso_invalido

    ; inicio de la nota = despues del ultimo espacio, saltando multiples espacios
    lea si, [di+1]
saltar_espacios_en_nota:
    lodsb
    cmp al, ' '
    je  saltar_espacios_en_nota
    dec si                     ; dejar SI en el primer no-espacio
    mov dx, si                 ; DX = inicio real de la nota

    ; ---- copiar nombre ----
    mov bl, num_estudiantes
    xor bh, bh                 ; BX = indice 0..14

    mov bp, bx
    shl bp, 1
    push ds
    pop es

    lea si, tabla_desplaz_60
    add si, bp
    mov bp, [si]               ; BP = indice*60

    lea di, nombres
    add di, bp

    mov si, bx                 ; origen = inicio_nombre
    ; limitar a 59 chars y terminar en '$'
    mov cx, ax
    cmp cx, 59
    jbe copiar_nombre
    mov cx, 59
copiar_nombre:
    rep movsb
    mov byte ptr [di], '$'

    ; ---- parsear nota (DX:AX punto fijo x100000) ----
    mov si, dx
    call parsear_nota_5decimales
    jc  ingreso_invalido

    ; 0 <= nota <= 100.00000 (0x00989680)
    mov bx, 0098h
    mov cx, 9680h
    cmp dx, bx
    ja  ingreso_invalido
    jb  ingreso_guardar
    cmp ax, cx
    jbe ingreso_guardar
    jmp ingreso_invalido

ingreso_guardar:
    mov bl, num_estudiantes
    xor bh, bh
    mov bp, bx
    shl bp, 1
    shl bp, 1                  ; *4
    lea di, notas
    add di, bp
    mov [di], ax
    mov [di+2], dx

    inc num_estudiantes

    lea dx, mensaje_guardado
    call imprimir_cadena_dos

    ; ¿ya 15?
    mov al, num_estudiantes
    cmp al, 15
    jb  ingreso_siguiente

ingreso_lleno:
    lea dx, mensaje_maximoIngreso
    call imprimir_cadena_dos
    jmp menu

ingreso_invalido:
    lea dx, mensaje_formato_invalido
    call imprimir_cadena_dos
    jmp ingreso_siguiente

; ====== OPCION 2 (pendiente) ======
opcion2:
    jmp menu

; ====== OPCION 3: Buscar por posicion (imprime: "Nombre Nota") ======
opcion3:
    mov al, num_estudiantes
    cmp al, 0
    je  buscar_no_registros

    call limpiar_buffer_teclado
    lea dx, mensaje_ingrese_posicion
    call imprimir_cadena_dos

    lea dx, entrada_buffer
    mov ah, 0Ah
    int 21h

    mov bl, [entrada_buffer+1]
    mov byte ptr [entrada_buffer+2+bx], 0

    lea si, [entrada_buffer+2]
    call parsear_entero_decimal_en_ax
    jc  buscar_posicion_invalida

    cmp ax, 1
    jb  buscar_posicion_invalida
    mov bl, num_estudiantes
    xor bh, bh
    cmp ax, bx
    ja  buscar_posicion_invalida

    dec ax
    mov bx, ax              ; BX = indice 0..14

    ; --- imprimir: NOMBRE?NOTA ---
    ; nombre
    mov bp, bx
    shl bp, 1
    lea si, tabla_desplaz_60
    add si, bp
    mov bp, [si]            ; BP = indice*60
    lea di, nombres
    add di, bp
    mov dx, di
    call imprimir_cadena_dos

    ; espacio
    mov dl, ' '
    call imprimir_caracter

    ; nota con decimales variables (0..5 sin ceros de cola)
    mov bp, bx
    shl bp, 1
    shl bp, 1               ; *4
    lea di, notas
    add di, bp
    mov ax, [di]
    mov dx, [di+2]
    call imprimir_nota_decimales_variable

    ; salto de linea
    lea dx, mensaje_salto_linea
    call imprimir_cadena_dos
    jmp menu

buscar_posicion_invalida:
    lea dx, mensaje_posicion_invalida
    call imprimir_cadena_dos
    jmp menu

buscar_no_registros:
    lea dx, mensaje_no_registros
    call imprimir_cadena_dos
    jmp menu

opcion4:
    jmp menu

; ====== SUBRUTINAS ======

; Imprime cadena DOS terminada en '$' (usa DS:DX)
imprimir_cadena_dos:
    mov ah, 9
    int 21h
    ret

; Vaciar el buffer de teclado (descarta teclas pendientes)
limpiar_buffer_teclado:
    push ax
    push dx
lt_revisar:
    mov ah, 0Bh
    int 21h
    cmp al, 0
    je  lt_listo
    mov ah, 08h
    int 21h
    jmp lt_revisar
lt_listo:
    pop dx
    pop ax
    ret

; AH=02h imprime DL
imprimir_caracter:
    mov ah, 02h
    int 21h
    ret

; Imprime AX (0..65535) en decimal sin ceros a la izquierda
imprimir_entero16_decimal:
    push ax
    push bx
    push cx
    push dx
    mov cx, 0
    cmp ax, 0
    jne ied_div
    mov dl, '0'
    call imprimir_caracter
    jmp ied_fin
ied_div:
    xor dx, dx
    mov bx, 10
ied_bucle:
    div bx
    push dx
    inc cx
    cmp ax, 0
    jne ied_bucle
ied_out:
    pop dx
    add dl, '0'
    call imprimir_caracter
    loop ied_out
ied_fin:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Divide 32-bit DX:AX entre 10  -> cociente DX:AX, resto en BL
dividir32_entre_10_dxax:
    push ax
    push dx
    push cx
    push si
    push di
    mov si, ax
    mov cx, 10
    mov ax, dx
    xor dx, dx
    div cx                 ; AX = q_alto, DX = r_alto
    mov di, ax
    mov ax, si
    div cx                 ; AX = q_bajo, DX = resto
    mov bl, dl
    mov dx, di
    pop di
    pop si
    pop cx
    pop dx
    pop ax
    ret

; Imprime nota en DX:AX (punto fijo ×100000) con decimales variables (0..5) sin ceros de cola
imprimir_nota_decimales_variable:
    push ax
    push bx
    push cx
    push dx
    push si
    ; Extraer 5 dígitos fraccionarios (restos de /10) en buffer_fraccion[0..4]
    mov si, 0
    mov cx, 5
inv_extr:
    call dividir32_entre_10_dxax
    mov [buffer_fraccion+si], bl
    inc si
    loop inv_extr
    ; Parte entera:
    call imprimir_entero16_decimal
    ; Contar ceros de cola en fracción (desde [0] hacia arriba)
    mov si, 0
    mov bx, 0
    mov cx, 5
inv_ctz:
    cmp byte ptr [buffer_fraccion+si], 0
    jne inv_tiene_dec
    inc bx
    inc si
    loop inv_ctz
    jmp inv_fin                 ; todos 0 -> sin parte decimal
inv_tiene_dec:
    mov cx, 5
    sub cx, bx                  ; decimales a imprimir
    mov dl, '.'
    call imprimir_caracter
    mov si, cx
inv_print:
    dec si
    mov dl, [buffer_fraccion+si]
    add dl, '0'
    call imprimir_caracter
    cmp si, 0
    jne inv_print
inv_fin:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Multiplica DX:AX por 10 (resultado en DX:AX)
multiplicar32_por10_dxax:
    push bx
    push cx
    mov bx, dx
    mov cx, ax
    ; *8
    add ax, ax
    adc dx, dx
    add ax, ax
    adc dx, dx
    add ax, ax
    adc dx, dx
    ; + *2
    add cx, cx
    adc bx, bx
    add ax, cx
    adc dx, bx
    pop cx
    pop bx
    ret

; Cadena en SI -> DX:AX *100000 (0..5 decimales), CF=1 error
parsear_nota_5decimales:
    push bx
    push cx
    push bp
    xor dx, dx
    xor ax, ax
    xor bp, bp
    xor bl, bl
pn_bucle:
    lodsb
    cmp al, 0
    je  pn_fin
    cmp al, 13
    je  pn_fin
    cmp al, ' '
    je  pn_fin
    cmp al, '.'
    jne pn_dig
    mov bl, 1
    jmp pn_bucle
pn_dig:
    cmp al, '0'
    jb  pn_err
    cmp al, '9'
    ja  pn_err
    cmp bl, 1
    jne pn_tomar
    cmp bp, 5
    jae pn_bucle
pn_tomar:
    sub al, '0'
    call multiplicar32_por10_dxax
    xor ah, ah
    mov cl, al
    xor ch, ch
    add ax, cx
    adc dx, 0
    cmp bl, 1
    jne pn_bucle
    inc bp
    jmp pn_bucle
pn_fin:
    mov cx, 5
    cmp bp, cx
    ja  pn_ok
    je  pn_ok
    sub cx, bp
pn_pad:
    call multiplicar32_por10_dxax
    loop pn_pad
pn_ok:
    clc
    jmp pn_out
pn_err:
    stc
pn_out:
    pop bp
    pop cx
    pop bx
    ret

; Cadena decimal en SI -> AX, CF=1 si error/sin dígitos
parsear_entero_decimal_en_ax:
    push bx
    push cx
    push dx
    xor ax, ax
    xor cx, cx
ped_skip:
    lodsb
    cmp al, ' '
    je  ped_skip
    cmp al, 9
    je  ped_skip
    cmp al, 0
    je  ped_err
    cmp al, 13
    je  ped_err
ped_loop:
    cmp al, '0'
    jb  ped_err
    cmp al, '9'
    ja  ped_err
    sub al, '0'
    mov dl, al
    mov bx, ax
    shl ax, 1
    shl bx, 3
    add ax, bx
    xor dh, dh
    add ax, dx
    inc cx
    lodsb
    cmp al, 0
    je  ped_fin
    cmp al, 13
    je  ped_fin
    cmp al, ' '
    je  ped_fin
    jmp ped_loop
ped_fin:
    jcxz ped_err
    clc
    pop dx
    pop cx
    pop bx
    ret
ped_err:
    stc
    pop dx
    pop cx
    pop bx
    ret

; ====== SALIR ======
salir:
    lea dx, mensaje_despedidaPrograma
    call imprimir_cadena_dos
    mov ax, 4C00h
    int 21h

end inicio


















