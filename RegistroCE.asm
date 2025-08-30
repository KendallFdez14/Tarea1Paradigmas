.MODEL SMALL
.STACK 100H

.DATA ;Constantes principales
estudiante_tam     EQU 30 ;Tamano maximo para nombre
notas_tam     EQU 10 ;Tamano maximo para notas
estudiantesMax      EQU 15 ;Limite de 15 estudiantes

estudianteBuffer  DB estudiante_tam ;almacenar los nombres de los estudiantes
           DB ?
           DB estudiante_tam+2 DUP(0)
           
notasBuffer DB notas_tam  ;almacenar las notas
            DB ?
            DB notas_tam+2 DUP(0)

estudiantesList DB estudiantesMax * (estudiante_tam+1) DUP('$') ;Lista de nombres de estudiantes
notasList      DB estudiantesMax * (notas_tam+1) DUP('$') ;Listas de notas

cnt         DB 0

mensageMenu DB 13, 10, 'Bienvenidos/as a Registro CE', 13, 10
            DB      'Elegir:',  13, 10
            DB      '1. Ingresar calificaciones (hasta 15 estudiantes)', 13, 10
            DB      '2. Mostrar estadisticas', 13, 10
            DB      '3. Buscar estudiante por posicion (indice)', 13, 10 
            DB      '4. Ordenar calificaciones (ascendente/descendente)', 13, 10
            DB      '5. Listas de estudiantes guardados', 13, 10
            DB      '0. Salir', 13, 10
            DB      '                                                     ', 13, 10
            DB      'Digite: $'

mensaje_ingresoNombre DB 13, 10, 'Ingresar Nombre Apellido1 Apellido2: $'
mensage_ingresoNota   DB 13, 10, 'Ingresar nota: $'
mensage_Lista  DB 13, 10, 'Lista de Estudiantes guardados:', 13, 10, '-------------------', 13, 10, '$'
titulos DB 'Numero  Nombres', 9,9,'Notas$'
newline   DB 13, 10, '$'
tab       DB 09h, '$'

mensaje_invalida  DB 13, 10, 'Opcion invalida!'  ;cambiar
mensaje_estudiantesmaximos DB 13, 10, 'El limite de estudiantes ya fue alcanzado$'
msgPresioneTecla DB 13, 10, 'Presione cualquier tecla$'
mensaje_procesar db 13,10,"Procesado: $"  
mensajes_aprobados db 'Porcentaje de aprobados: $'
mensajes_reprobados db 13,10,'Porcentaje de reprobados: $' 
  
mensaje_posicion DB 13, 10, 'Que estudiante desea mostrar?:  $'
mensaje_invalidaposicion DB 13, 10, 'Posicion invalida. No hay estudiante en esa posicion.', 13, 10, '$'
mensaje_mostrar_dato DB 13, 10, 'Datos del estudiante:', 13, 10, '$'  
  
; Arreglos para almacenar los resultados
notasenteros_array    dw estudiantesMax dup(0)        ;Parte entera de las notas  (16 bits)
notasdecimales_array  dw estudiantesMax * 2 dup(0)    ;Parte decimal de las notas  (estudiantesMax * 32 bits)
; Variables temporales 
entero_temp dw 0
decimal_temp dw 2 dup(0)         ; 32 bits (2 words: parte baja + parte alta)
decimal_encontrado db 0
  
; Contadores de aprobaciones
aprobados db 0
desaprobados db 0                             
                              
                              
.CODE
START:
    MOV AX, @DATA
    MOV DS, AX
    MOV ES, AX

MainMenu:
    CALL ClrScreen
    CALL MostrarMenu
    JMP MainMenu

MostrarMenu PROC
    MOV AH, 09h
    LEA DX, mensageMenu
    INT 21h

    MOV AH, 01h
    INT 21h

    CMP AL, '1'
    JE Opcion1
    CMP AL, '2'
    JE Opcion2
    CMP AL, '3'
    JE Opcion3
    CMP AL, '4'
    JE Opcion4
    CMP AL, '5'
    JE Opcion5
    CMP AL, '0'
    JE SalirPrograma
    CMP AL, 1Bh
    JE SalirPrograma
    
    MOV AH, 09h
    LEA DX, mensaje_invalida 
    INT 21h
    MOV AH, 01h
    INT 21h
    RET
MostrarMenu ENDP

Opcion1:
    CALL AgregarEstudiante
    RET

Opcion2:
    CALL separar_numeros_func
    CALL MostrarEstadisticas
    RET

Opcion3:
    CALL SearchInd
    RET

Opcion4:
    CALL separar_numeros_func
    CALL OrdenarNotas
    RET

Opcion5:
    CALL MostrarListaCompleta
    RET

SalirPrograma:
    MOV AH, 4Ch
    INT 21h


; AgregarEstudiante
AgregarEstudiante PROC
    PUSH AX
    
    MOV AL, cnt
    CMP AL, estudiantesMax
    JL  PuedeAgregar
    
    MOV AH, 09h
    LEA DX, mensaje_estudiantesmaximos
    INT 21h
    LEA DX, msgPresioneTecla
    INT 21h
    MOV AH, 01h
    INT 21h
    JMP FinAgregar
    
PuedeAgregar:
    CALL InputProc
    
FinAgregar:
    POP AX
    RET
AgregarEstudiante ENDP   

; InputProc 
InputProc PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    
    ; Pedir nombre
    MOV AH, 09h
    LEA DX, mensaje_ingresoNombre
    INT 21h
    
    ; Leer nombre con INT 21h/0Ah
    MOV estudianteBuffer, estudiante_tam  ; Maximo de caracteres a leer (indSize es una costante)
    LEA DX, estudianteBuffer       ; Carga la direccion del buffer donde se guardara el nombre
    MOV AH, 0Ah
    INT 21h
    
    ; Terminar cadena con '$'
    XOR BX, BX              ; Limpia el valor de BX
    MOV BL, estudianteBuffer[1]    ; Numero de caracteres leidos se guardan en BL, valor de indSize
    MOV estudianteBuffer[BX+2], '$'; Agregar indicador de finalizacion al final 
    
    ; Copiar nombre a la lista
    XOR AX, AX              ; Limpia el valor de AX
    MOV AL, cnt
    MOV BL, estudiante_tam+1
    MUL BL                  ; AX = AL * BL = cnt * (indSize+1) ---> Se almacena en AX
    LEA DI, estudiantesList ; DI (Destination Index) apunta al inicio de array indLst
    ADD DI, AX              ; Se adiciona para mover el cursos al guardar la data
    LEA SI, estudianteBuffer + 2   ; Saltar los primeros 2 bytes del buffer, se almacena el inicio de nombre en SI (source index)
    CALL CopiarCadena

    ; Pedir nota
    MOV AH, 09h
    LEA DX, mensage_ingresoNota
    INT 21h

    ; Leer nota
    MOV notasBuffer, notas_tam
    LEA DX, notasBuffer
    MOV AH, 0Ah
    INT 21h
    
    ; Terminar cadena con '$'
    XOR BX, BX
    MOV BL, notasBuffer[1]
    MOV notasBuffer[BX+2], '$'
    
    ; Copiar nota a la lista
    XOR AX, AX
    MOV AL, cnt
    MOV BL, notas_tam+1
    MUL BL
    LEA DI, notasList
    ADD DI, AX
    LEA SI, notasBuffer + 2
    CALL CopiarCadena

    ; Incrementar contador
    INC cnt
    
    MOV AH, 09h
    LEA DX, newline
    INT 21h
    
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
InputProc ENDP


; Buscar por ID
SearchInd PROC
    CALL ClrScreen
    
    ; Promt
    MOV AH, 09h
    LEA DX, mensaje_posicion
    INT 21h
    
    ; ID read
    MOV AH, 01h
    INT 21h
    
    ; Check 
    CMP AL, '1'
    JL IDInvalidoBusqueda
    CMP AL, '9'
    JG IDInvalidoBusqueda
    
    ; ASCII to num
    SUB AL, '1'
    
    CALL DisplayInd
    
    MOV AH, 09h
    LEA DX, msgPresioneTecla
    INT 21h
    MOV AH, 01h
    INT 21h
    RET
    
IDInvalidoBusqueda:
    MOV AH, 09h
    LEA DX, mensaje_invalidaposicion
    INT 21h
    MOV AH, 01h
    INT 21h
    RET
SearchInd ENDP


; AL = ID
DisplayInd PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    
    ; Verify with cnt
    CMP AL, cnt
    JGE IDInvalido
    
    ; Save  ID in  BX
    XOR BX, BX
    MOV BL, AL
    
    ; Display IDdo
    MOV AH, 02h
    MOV DL, BL
    ADD DL, '1'
    INT 21h
    MOV DL, '.'
    INT 21h
    MOV DL, ' '
    INT 21h
    
    ; Display name
    MOV AL, BL
    MOV CL, estudiante_tam+1
    MUL CL           ; AX = AL * CL
    LEA SI, estudiantesList
    ADD SI, AX
    CALL ImprimirCadena
    
    ; Tab
    MOV AH, 09h
    LEA DX, tab
    INT 21h
    
    ; Display grade
    MOV AL, BL
    MOV AH, notas_tam+1
    MUL AH           ; AX = AL * AH
    LEA SI, notasList
    ADD SI, AX
    CALL ImprimirCadena
    
    MOV AH, 09h
    LEA DX, newline
    INT 21h

    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
DisplayInd ENDP
    
IDInvalido:
    MOV AH, 09h
    LEA DX, mensaje_invalidaposicion
    INT 21h


; CopiarCadena 
CopiarCadena PROC
    PUSH AX
    PUSH CX
    PUSH SI
    PUSH DI
    
CopiarLoop:
    MOV AL, [SI]       ; Esto es guardar en AL la posicion del primer caracter de la data de buffer
                       ; la primera vez que se llama al PROC, luego almacenara el siguiente caracter
    CMP AL, 0Dh        ; Saltar carriage return, final de la linea
    JE  FinCopia
    CMP AL, 0Ah        ; Saltar line feed, que es avance de linea o de fila
    JE  SaltarChar      
    MOV [DI], AL
    INC DI             ; Se incrementa DI para apuntar al siguiente lugar del buffer destino.
SaltarChar:            
    INC SI             ; Avanza al siguiente caracter de buffer
    CMP BYTE PTR [SI], '$' ; Verifica si ya termina la cadena
    JNE CopiarLoop
    
FinCopia:
    MOV BYTE PTR [DI], '$'
    POP DI
    POP SI
    POP CX
    POP AX
    RET
CopiarCadena ENDP


; MostrarListaCompleta 
MostrarListaCompleta PROC
    CALL ClrScreen
    
    MOV AH, 09h
    LEA DX, mensage_Lista
    INT 21h
    LEA DX, titulos
    INT 21h
    LEA DX, newline
    INT 21h
    
    ; Verificar si hay estudiantes
    MOV AL, cnt
    CMP AL, 0
    JE FinMostrar
    
    XOR CX, CX
    MOV CL, cnt
    XOR BX, BX
    
MostrarEstudiante:    
    PUSH BX
    PUSH CX
    
    ; Mostrar numero
    MOV AH, 02h
    MOV DL, BL
    ADD DL, '1'
    INT 21h
    MOV DL, '.'
    INT 21h
    MOV DL, ' '
    INT 21h
    
    ; Mostrar nombre
    MOV AL, BL
    MOV CL, estudiante_tam+1
    MUL CL  ; AX = AL * CL
    LEA SI, estudiantesList
    ADD SI, AX
    CALL ImprimirCadena
    
    ; Tabulacion
    MOV AH, 09h
    LEA DX, tab
    INT 21h
    
    ; Mostrar nota
    MOV AL, BL
    MOV AH, notas_tam+1
    MUL AH
    LEA SI, notasList
    ADD SI, AX
    CALL ImprimirCadena
    
    ; Nueva linea
    MOV AH, 09h
    LEA DX, newline
    INT 21h
    
    POP CX
    POP BX
    INC BX
    LOOP MostrarEstudiante
    
FinMostrar:
    MOV AH, 09h
    LEA DX, msgPresioneTecla
    INT 21h
    MOV AH, 01h
    INT 21h
    RET
MostrarListaCompleta ENDP

; ImprimirCadena
ImprimirCadena PROC
    PUSH AX
    PUSH DX
    PUSH SI
    
ImprimirLoop:
    MOV DL, [SI]
    CMP DL, '$'
    JE FinImprimir
    MOV AH, 02h
    INT 21h
    INC SI
    JMP ImprimirLoop
    
FinImprimir:
    POP SI
    POP DX
    POP AX
    RET
ImprimirCadena ENDP

; Funciones
MostrarEstadisticas PROC
    CALL ClrScreen 
    CALL calcular_porcentajes
    MOV AH, 09h
    LEA DX, msgPresioneTecla
    INT 21h
    MOV AH, 01h
    INT 21h 
    RET
MostrarEstadisticas ENDP  

BuscarEstudiante PROC
    CALL ClrScreen
    MOV AH, 09h
    LEA DX, msgPresioneTecla
    INT 21h
    MOV AH, 01h
    INT 21h
    RET
BuscarEstudiante ENDP

OrdenarNotas PROC
    CALL ClrScreen
    MOV AH, 09h
    LEA DX, msgPresioneTecla
    INT 21h
    MOV AH, 01h
    INT 21h
    RET
OrdenarNotas ENDP

; Limpiar pantalla
ClrScreen:
    MOV AX, 0600h   ; AH=06h (scroll), AL=00h (clear)
    MOV BH, 07h     ; Atributo (gris sobre negro)
    MOV CX, 0000h   ; Esquina superior izquierda
    MOV DX, 184Fh   ; Esquina inferior derecha
    INT 10h
    
    ; Posicionar cursor en 0,0
    MOV AH, 02h
    MOV BH, 00h
    MOV DX, 0000h
    INT 10h
    RET 

; Separa lista de strings a listas numericas
separar_numeros_func proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Inicializar indices
    mov si, offset notasList
    mov di, offset notasenteros_array
    mov bx, offset notasdecimales_array
    mov cx, 0                      ; Contador de numeros
    
procesar_numero:
    ; Reiniciar valores temporales (32 bits para decimal)
    mov word ptr entero_temp, 0
    mov word ptr decimal_temp, 0     ; Parte baja
    mov word ptr decimal_temp + 2, 0 ; Parte alta (32 bits total)
    mov decimal_encontrado, 0
    
leer_entero:
    mov al, [si]
    cmp al, '$'              ; Fin del string?
    je fin_numero
    cmp al, '.'              ; Es punto decimal?
    je encontro_decimal
    cmp al, 13               ; Es carriage return?
    je fin_numero
    cmp al, 10               ; Es new line?
    je fin_numero
    
    ; Convertir ASCII a numero
    sub al, '0'
    mov ah, 0
    push ax                  ; Guardar nuevo digito
    
    ; entero_temp = entero_temp * 10
    mov ax, entero_temp
    mov dx, 10
    mul dx
    mov entero_temp, ax
    
    ; entero_temp = entero_temp + nuevo_digito
    pop ax
    add entero_temp, ax
    
    inc si
    jmp leer_entero

encontro_decimal:
    mov decimal_encontrado, 1
    inc si                   ; Saltar el punto
    
leer_decimal:
    mov al, [si]
    cmp al, '$'              ; ¿Fin del string?
    je fin_numero
    cmp al, 13               ; ¿Es carriage return?
    je fin_numero
    cmp al, 10               ; ¿Es new line?
    je fin_numero
    
    ; Convertir ASCII a número
    sub al, '0'
    mov ah, 0
    push ax                  ; Guardar nuevo dígito
    
    ; decimal_temp = decimal_temp * 10 (32 bits)
    push bx
    push cx
    push dx
    
    ; Multiplicar parte baja (decimal_temp) por 10
    mov ax, word ptr decimal_temp
    mov dx, 10
    mul dx
    mov word ptr decimal_temp, ax
    mov cx, dx              ; Guardar carry
    
    ; Multiplicar parte alta (decimal_temp + 2) por 10 y sumar carry
    mov ax, word ptr decimal_temp + 2
    mov dx, 10
    mul dx
    add ax, cx              ; Sumar el carry de la parte baja
    mov word ptr decimal_temp + 2, ax
    
    pop dx
    pop cx
    pop bx
    
    ; decimal_temp = decimal_temp + nuevo_dígito
    pop ax
    add word ptr decimal_temp, ax
    adc word ptr decimal_temp + 2, 0  ; Sumar carry si hay
    
    inc si
    jmp leer_decimal

fin_numero:
    ; Guardar entero en array (16 bits)
    mov ax, entero_temp
    mov [di], ax
    add di, 2
    
    ; Guardar decimal en array (32 bits - 2 palabras)
    mov ax, word ptr decimal_temp      ; Parte baja
    mov [bx], ax
    mov ax, word ptr decimal_temp + 2  ; Parte alta
    mov [bx + 2], ax
    add bx, 4                         ; Avanzar 4 bytes (32 bits)
    
    ; Avanzar al siguiente string en grdLst
    inc cx
    mov al, cnt
    cbw
    cmp cx, ax               ; Comparar con cnt (convertido a word)
    jge terminar_proceso     ; Si ya procesamos todos, terminar
    
    ; Avanzar SI al inicio del siguiente string (11 bytes por elemento)
    ; Calcular: SI = offset grdLst + (cx * 11)
    push ax
    push dx
    mov ax, cx               ; AX = numero actual (1, 2, 3...)
    mov dx, notas_tam
    inc dx                   ; DX = 11 (grdSize + 1)
    mul dx                   ; AX = cx * 11
    mov si, offset notasList
    add si, ax               ; SI apunta al inicio del siguiente string
    pop dx
    pop ax
    
    jmp procesar_numero      ; Procesar el siguiente número
    
terminar_proceso:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
separar_numeros_func endp

; Calcular Porcentajes de Estudiantes
calcular_porcentajes proc
    mov cl, cnt        ; cnt es 8 bits, usamos CL como contador
    xor si, si         ; Reinicio source index
    mov aprobados,0
    mov desaprobados,0

ciclo_notas:
    cmp cl,0
    je fin_ciclo

    mov ax, notasenteros_array[si] ; cargar nota
    cmp ax,70
    jl es_reprobado

es_aprobado:
    inc aprobados
    jmp siguiente

es_reprobado:
    inc desaprobados

siguiente:
    add si,2       ; siguiente palabra
    dec cl
    jmp ciclo_notas

fin_ciclo:


; porcentaje aprobados = (aprobados * 100) / cnt

    xor ax, ax        ; LIMPIAR AX COMPLETAMENTE
    mov al, aprobados ; cargar aprobados (8 bits)
    mov bl, 100
    mul bl            ; AX = aprobados * 100
    mov bl, cnt       ; divisor
    div bl            ; AL = cociente, AH = residuo
    xor ah, ah        ; descartar residuo, AX = porcentaje
    push ax           ; guardar porcentaje

    ; imprimir mensaje de aprobados
    mov ah, 9
    lea dx, mensajes_aprobados
    int 21h
    pop ax
    call print_num    ; imprimir porcentaje

 
; porcentaje reprobados = (desaprobados * 100) / cnt

    xor ax, ax        ; LIMPIAR AX COMPLETAMENTE - ESTO ES LO QUE FALTABA
    mov al, desaprobados ; cargar desaprobados (8 bits)
    mov bl, 100
    mul bl            ; AX = desaprobados * 100
    mov bl, cnt       ; divisor
    div bl            ; AL = cociente, AH = residuo
    xor ah, ah        ; descartar residuo, AX = porcentaje

    ; imprimir mensaje de reprobados
    push ax           ; guardar porcentaje temporalmente
    mov ah, 9
    lea dx, mensajes_reprobados
    int 21h
    pop ax
    call print_num

    ret
calcular_porcentajes endp

; Imprimir Numero contenido en AX
print_num proc
    push ax
    push bx
    push cx
    push dx

    mov cx, 0          ; contador de digitos
    mov bx, 10         ; divisor para decimal

    cmp ax, 0
    jne conv_loop
    ; si AX=0, imprimir '0' directamente
    mov dl, '0'
    mov ah, 2
    int 21h
    jmp print_symbol

conv_loop:
    xor dx, dx
    div bx            ; AX / 10 -> cociente en AX, residuo en DX
    push dx           ; guardar residuo (digito)
    inc cx
    cmp ax, 0
    jne conv_loop

print_digits:
    pop dx
    add dl, '0'
    mov ah, 2
    int 21h
    loop print_digits

print_symbol:
    ; imprimir simbolo de porcentaje
    mov dl, '%'
    mov ah, 2
    int 21h

    pop dx
    pop cx
    pop bx
    pop ax
    ret
print_num endp


END START
