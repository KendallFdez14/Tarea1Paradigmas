.model small
.stack 100h

.data
mensaje_bienvenida     db 13,10,"Bienvenidos/as a Registro CE $"
mensaje_digitar        db 13,10,"Digite:$"
mensaje_menu1          db 13,10,"1. Ingresar calificaciones (hasta 15 estudiantes -Nombre Apellido1 Apellido2 Nota-).$"
mensaje_menu2          db 13,10,"2. Mostrar estadisticas.$"
mensaje_menu3          db 13,10,"3. Buscar estudiante por posicion (indice).$"
mensaje_menu4          db 13,10,"4. Ordenar calificaciones (ascendente/descendente).$"
mensaje_menu5          db 13,10,"5. Salir.$"
mensaje_opcion         db 13,10,"Opcion: $"
mensaje_ingresoDatos   db 13,10,"Ingrese estudiante o 9 para volver al menu:$"
mensaje_mostrar_dato   db 13,10,"Datos del estudiante:$"
mensaje_posicion       db 13,10,"Que estudiante desea mostrar? $"
mensaje_invalida       db 13,10,"Posicion invalida. No hay estudiante en esa posicion.$"
mensaje_despedida      db 13,10,"Gracias por usar Registro CE.$"

; Buffer DOS AH=0Ah: [max][len][datos...]
entrada_buffer         db 60,0,60 dup(?)

; Lista enlazada: 15 nodos * 63 bytes (60 texto, 1 '$', 2 'siguiente')
nodos_memoria          db 15 dup(63 dup(0))

head           dw 0     ; offset relativo al inicio de nodos_memoria
tail           dw 0
num_estudiantes db 0
opcion_usuario  db ?

.code
inicio:
    mov ax, @data
    mov ds, ax

menu:
    lea dx, mensaje_bienvenida  ; menú en renglones
    mov ah, 09h
    int 21h

    lea dx, mensaje_digitar
    mov ah, 09h
    int 21h

    lea dx, mensaje_menu1
    mov ah, 09h
    int 21h

    lea dx, mensaje_menu2
    mov ah, 09h
    int 21h

    lea dx, mensaje_menu3
    mov ah, 09h
    int 21h

    lea dx, mensaje_menu4
    mov ah, 09h
    int 21h

    lea dx, mensaje_menu5
    mov ah, 09h
    int 21h

    lea dx, mensaje_opcion
    mov ah, 09h
    int 21h

    mov ah, 01h              ; leer opción
    int 21h
    mov opcion_usuario, al

    cmp al, '1'
    je opcion1
    cmp al, '2'
    je menu
    cmp al, '3'
    je opcion3
    cmp al, '4'
    je menu
    cmp al, '5'
    je salir
    jmp menu

;------------------------------------------
; OPCION 1: Ingresar estudiantes
opcion1:
    mov al, num_estudiantes
    cmp al, 15
    jae menu

leer_estudiante:
    lea dx, mensaje_ingresoDatos
    mov ah, 09h
    int 21h

    lea dx, entrada_buffer
    mov ah, 0Ah
    int 21h

    ; salir si primer char es '9'
    mov al, entrada_buffer+2
    cmp al, '9'
    je menu

    ; off_nuevo = num_estudiantes * 63  (AX)
    mov al, num_estudiantes
    xor ah, ah
    mov bl, 63
    mul bl                       ; AX = off_nuevo
    mov dx, ax                   ; DX = off_nuevo (guardamos)

    ; DI = base física del nodo nuevo = nodos_memoria + off_nuevo
    lea di, nodos_memoria
    add di, ax
    mov bx, di                   ; BX = base nodo (guardamos base)

    ; copiar 'len' bytes reales desde buffer a nodo
    mov cl, entrada_buffer+1
    xor ch, ch
    lea si, entrada_buffer+2
copiar_texto:
    cmp cx, 0
    je poner_dolar
    mov al, [si]
    mov [di], al
    inc si
    inc di
    dec cx
    jmp copiar_texto

poner_dolar:
    mov byte ptr [di], '$'       ; terminador tras el último char
    ; asegurar '$' fijo en byte 60 del nodo (para robustez)
    mov byte ptr [bx+60], '$'
    ; siguiente = 0 en [base+61]
    mov word ptr [bx+61], 0

    ; enlazar con anterior si existe
    mov al, num_estudiantes
    cmp al, 0
    je es_primer_nodo

    ; SI = base del tail anterior = nodos_memoria + tail
    mov ax, tail                 ; AX = off_tail
    lea si, nodos_memoria
    add si, ax
    ; escribir off_nuevo en [SI+61]
    mov ax, dx                   ; AX = off_nuevo
    mov word ptr [si+61], ax
    jmp set_tail

es_primer_nodo:
    mov ax, dx
    mov head, ax

set_tail:
    mov ax, dx
    mov tail, ax

    inc num_estudiantes

    ; Mostrar confirmación + el texto del nodo recién guardado
    lea dx, mensaje_mostrar_dato
    mov ah, 09h
    int 21h

    lea dx, nodos_memoria
    mov ax, dx                   ; AX = base nodos_memoria (backup)
    mov dx, ax                   ; (ajuste no necesario, pero claro)
    ; DX = nodos_memoria; sumamos off_nuevo en AX
    ; mejor: recalcular limpio
    lea dx, nodos_memoria
    add dx, word ptr [tail]      ; tail = off_nuevo
    mov ah, 09h
    int 21h

    ; pedir otro hasta 15
    mov al, num_estudiantes
    cmp al, 15
    jb leer_estudiante
    jmp menu

;------------------------------------------
; OPCION 3: Buscar por indice (1..num_estudiantes)
opcion3:
    lea dx, mensaje_posicion
    mov ah, 09h
    int 21h

    mov ah, 01h
    int 21h
    sub al, '0'
    cmp al, 1
    jb mostrar_error
    dec al                       ; a 0-based
    mov cl, al

    mov al, num_estudiantes
    cmp cl, al
    jae mostrar_error

    ; recorrer lista: SI = off actual (relativo)
    mov si, head
    mov ch, 0
recorrer:
    cmp ch, cl
    je imprimir_nodo

    ; SI = siguiente = [ (nodos_memoria + SI) + 61 ]
    lea bx, nodos_memoria
    add bx, si
    mov si, word ptr [bx+61]
    inc ch
    jmp recorrer

imprimir_nodo:
    ; imprimir desde nodos_memoria + SI (cadena con '$')
    lea dx, nodos_memoria
    add dx, si
    mov ah, 09h
    int 21h
    jmp menu

mostrar_error:
    lea dx, mensaje_invalida
    mov ah, 09h
    int 21h
    jmp menu

;------------------------------------------
salir:
    lea dx, mensaje_despedida
    mov ah, 09h
    int 21h
    mov ax, 4C00h
    int 21h

end inicio

































