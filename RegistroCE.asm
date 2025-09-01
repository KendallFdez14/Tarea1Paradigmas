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

cnt         DB 0  ; Contador de estudiantes registrados

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
mensage_ingresoNota   DB 13, 10, 'Ingresar nota (0-100, max 5 decimales): $'
mensage_Lista  DB 13, 10, 'Lista de Estudiantes guardados:', 13, 10, '-------------------', 13, 10, '$'
titulos DB 'Numero  Nombres', 9,9,'Notas$'
newline   DB 13, 10, '$'
tab       DB 09h, '$'

mensaje_invalida  DB 13, 10, 'Opcion invalida!'
mensaje_estudiantesmaximos DB 13, 10, 'El limite de estudiantes ya fue alcanzado$'
msgPresioneTecla DB 13, 10, 'Presione cualquier tecla$'
mensaje_procesar db 13,10,"Procesado: $"  
mensajes_aprobados db 'Porcentaje de aprobados: $'
mensajes_reprobados db 13,10,'Porcentaje de reprobados: $' 

; NUEVOS MENSAJES DE ERROR PARA VALIDACION DE NOTAS
mensaje_nota_invalida DB 13, 10, 'ERROR: La nota debe estar entre 0 y 100$'
mensaje_decimales_invalidos DB 13, 10, 'ERROR: Maximo 5 decimales permitidos$'
mensaje_formato_invalido DB 13, 10, 'ERROR: Formato invalido. Use solo numeros y punto decimal$'
mensaje_reintentar DB 13, 10, 'Presione cualquier tecla para reintentar...$'

mensaje_promedio db 13,10,'Promedio general: $'
mensaje_nota_maxima db 13,10,'Nota maxima: $'
mensaje_nota_minima db 13,10,'Nota minima: $'
  
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
contador_decimales db 0          ; NUEVA VARIABLE para contar decimales
  
; Contadores de aprobaciones
aprobados db 0
desaprobados db 0  

suma_total dw 0         ; Suma total de todas las notas
promedio_general dw 0   ; Promedio general calculado
nota_maxima dw 0        ; Nota más alta
nota_minima dw 100      ; Nota más baja (inicializada en 100)
                              
                              
.CODE
START:
    ; Inicializar segmentos de datos
    MOV AX, @DATA
    MOV DS, AX
    MOV ES, AX

MainMenu:
    CALL ClrScreen       ; Limpiar pantalla
    CALL MostrarMenu     ; Mostrar menu principal
    JMP MainMenu         ; Loop infinito del menu

MostrarMenu PROC
    ; Mostrar texto del menu
    MOV AH, 09h          ; Funcion para imprimir string
    LEA DX, mensageMenu  ; Cargar direccion del mensaje
    INT 21h              ; Llamar interrupcion DOS

    ; Leer opcion del usuario
    MOV AH, 01h          ; Funcion para leer un caracter
    INT 21h              ; Llamar interrupcion DOS

    ; Comparar y saltar a la opcion correspondiente
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
    CMP AL, 1Bh          ; Tecla ESC
    JE SalirPrograma
    
    ; Si no es valida, mostrar error
    MOV AH, 09h
    LEA DX, mensaje_invalida 
    INT 21h
    MOV AH, 01h          ; Esperar tecla
    INT 21h
    RET
MostrarMenu ENDP

Opcion1:
    CALL AgregarEstudiante
    RET

Opcion2:
    CALL separar_numeros_func    ; Convertir strings a numeros
    CALL MostrarEstadisticas     ; Mostrar todas las estadisticas
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
    MOV AH, 4Ch          ; Funcion para terminar programa
    INT 21h


; AgregarEstudiante - Verifica si se puede agregar y llama a InputProc
AgregarEstudiante PROC
    PUSH AX
    
    MOV AL, cnt          ; Cargar contador actual
    CMP AL, estudiantesMax  ; Comparar con limite
    JL  PuedeAgregar     ; Si es menor, puede agregar
    
    ; Si llego al limite, mostrar mensaje
    MOV AH, 09h
    LEA DX, mensaje_estudiantesmaximos
    INT 21h
    LEA DX, msgPresioneTecla
    INT 21h
    MOV AH, 01h
    INT 21h
    JMP FinAgregar
    
PuedeAgregar:
    CALL InputProc       ; Llamar procedimiento de entrada
    
FinAgregar:
    POP AX
    RET
AgregarEstudiante ENDP   

; InputProc - Lee nombre y nota del estudiante CON VALIDACION
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
    
    ; Leer nombre con INT 21h/0Ah (entrada con buffer)
    MOV estudianteBuffer, estudiante_tam  ; Establecer maximo de caracteres
    LEA DX, estudianteBuffer       ; Direccion del buffer
    MOV AH, 0Ah                   ; Funcion de entrada con buffer
    INT 21h
    
    ; Terminar cadena con '$'
    XOR BX, BX                     ; Limpiar BX
    MOV BL, estudianteBuffer[1]    ; Obtener numero de caracteres leidos
    MOV estudianteBuffer[BX+2], '$'; Agregar terminador
    
    ; Copiar nombre a la lista
    XOR AX, AX                     ; Limpiar AX
    MOV AL, cnt                    ; Cargar contador
    MOV BL, estudiante_tam+1       ; Tamano de cada entrada
    MUL BL                         ; Calcular offset (AL * BL -> AX)
    LEA DI, estudiantesList        ; Destino: lista de estudiantes
    ADD DI, AX                     ; Ajustar posicion
    LEA SI, estudianteBuffer + 2   ; Fuente: buffer+2 (saltar cabecera)
    CALL CopiarCadena

PedirNota:
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
    
    ; VALIDAR LA NOTA INGRESADA
    LEA SI, notasBuffer + 2
    CALL ValidarNota
    CMP AL, 1               ; AL = 1 si la nota es valida
    JE NotaValida           ; Si es valida, continuar
    
    ; Si no es valida, mostrar mensaje de error y repetir
    MOV AH, 09h
    LEA DX, mensaje_reintentar
    INT 21h
    MOV AH, 01h
    INT 21h
    JMP PedirNota           ; Volver a pedir la nota

NotaValida:
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

; NUEVA FUNCION: ValidarNota - Valida que la nota este en rango 0-100 y max 5 decimales
; Entrada: SI apunta al string de la nota
; Salida: AL = 1 si valida, AL = 0 si invalida
ValidarNota PROC
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    
    ; Reiniciar variables
    MOV entero_temp, 0
    MOV decimal_temp, 0
    MOV decimal_temp + 2, 0
    MOV decimal_encontrado, 0
    MOV contador_decimales, 0
    
    ; Verificar si el string esta vacio
    CMP BYTE PTR [SI], '$'
    JE NotaInvalida
    CMP BYTE PTR [SI], 13
    JE NotaInvalida
    
ValidarEntero:
    MOV AL, [SI]
    CMP AL, '$'
    JE FinValidacion
    CMP AL, 13
    JE FinValidacion
    CMP AL, 10
    JE FinValidacion
    CMP AL, '.'
    JE ValidarDecimal
    
    ; Verificar que sea digito
    CMP AL, '0'
    JB FormatoInvalido
    CMP AL, '9'
    JA FormatoInvalido
    
    ; Convertir y acumular
    SUB AL, '0'
    MOV AH, 0
    PUSH AX
    
    ; entero_temp = entero_temp * 10
    MOV AX, entero_temp
    MOV DX, 10
    MUL DX
    MOV entero_temp, AX
    
    ; entero_temp = entero_temp + digito
    POP AX
    ADD entero_temp, AX
    
    ; Verificar que no exceda 100 en la parte entera
    CMP entero_temp, 100
    JA NotaFueraRango
    
    INC SI
    JMP ValidarEntero

ValidarDecimal:
    MOV decimal_encontrado, 1
    INC SI
    
ValidarDecimales:
    MOV AL, [SI]
    CMP AL, '$'
    JE FinValidacion
    CMP AL, 13
    JE FinValidacion
    CMP AL, 10
    JE FinValidacion
    
    ; Verificar que sea digito
    CMP AL, '0'
    JB FormatoInvalido
    CMP AL, '9'
    JA FormatoInvalido
    
    ; Incrementar contador de decimales
    INC contador_decimales
    CMP contador_decimales, 5
    JA DemasiadosDecimales
    
    INC SI
    JMP ValidarDecimales

FinValidacion:
    ; Verificar rango final (0-100)
    CMP entero_temp, 100
    JA NotaFueraRango
    
    ; Si llego aqui, la nota es valida
    MOV AL, 1
    JMP FinValidarNota

NotaFueraRango:
    MOV AH, 09h
    LEA DX, mensaje_nota_invalida
    INT 21h
    MOV AL, 0
    JMP FinValidarNota

DemasiadosDecimales:
    MOV AH, 09h
    LEA DX, mensaje_decimales_invalidos
    INT 21h
    MOV AL, 0
    JMP FinValidarNota

FormatoInvalido:
    MOV AH, 09h
    LEA DX, mensaje_formato_invalido
    INT 21h
    MOV AL, 0
    JMP FinValidarNota

NotaInvalida:
    MOV AH, 09h
    LEA DX, mensaje_formato_invalido
    INT 21h
    MOV AL, 0

FinValidarNota:
    POP SI
    POP DX
    POP CX
    POP BX
    RET
ValidarNota ENDP

; SearchInd - Buscar estudiante por indice
SearchInd PROC
    CALL ClrScreen
    
    ; Pedir indice
    MOV AH, 09h
    LEA DX, mensaje_posicion
    INT 21h
    
    ; Leer digito
    MOV AH, 01h
    INT 21h
    
    ; Verificar rango valido (1-9)
    CMP AL, '1'
    JL IDInvalidoBusqueda
    CMP AL, '9'
    JG IDInvalidoBusqueda
    
    ; Convertir ASCII a numero
    SUB AL, '1'
    
    CALL DisplayInd      ; Mostrar datos del estudiante
    
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


; DisplayInd - Muestra datos de un estudiante (AL = indice)
DisplayInd PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    
    ; Verificar con contador
    CMP AL, cnt
    JGE IDInvalido
    
    ; Guardar indice en BX
    XOR BX, BX
    MOV BL, AL
    
    ; Mostrar numero
    MOV AH, 02h          ; Funcion imprimir caracter
    MOV DL, BL
    ADD DL, '1'          ; Convertir a ASCII
    INT 21h
    MOV DL, '.'
    INT 21h
    MOV DL, ' '
    INT 21h
    
    ; Mostrar nombre
    MOV AL, BL
    MOV CL, estudiante_tam+1
    MUL CL               ; Calcular offset
    LEA SI, estudiantesList
    ADD SI, AX
    CALL ImprimirCadena
    
    ; Tab
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
    
    MOV AH, 09h
    LEA DX, newline
    INT 21h

    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
    
IDInvalido:
    MOV AH, 09h
    LEA DX, mensaje_invalidaposicion
    INT 21h
    RET
DisplayInd ENDP


; CopiarCadena - Copia string de SI a DI
CopiarCadena PROC
    PUSH AX
    PUSH CX
    PUSH SI
    PUSH DI
    
CopiarLoop:
    MOV AL, [SI]         ; Cargar caracter de fuente
    CMP AL, 0Dh          ; Es carriage return?
    JE  FinCopia
    CMP AL, 0Ah          ; Es line feed?
    JE  SaltarChar      
    MOV [DI], AL         ; Copiar caracter a destino
    INC DI               ; Avanzar destino
SaltarChar:            
    INC SI               ; Avanzar fuente
    CMP BYTE PTR [SI], '$' ; Fin de cadena?
    JNE CopiarLoop
    
FinCopia:
    MOV BYTE PTR [DI], '$'  ; Agregar terminador
    POP DI
    POP SI
    POP CX
    POP AX
    RET
CopiarCadena ENDP


; MostrarListaCompleta - Muestra todos los estudiantes
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
    MOV CL, cnt          ; Usar contador como limite del loop
    XOR BX, BX           ; Indice actual = 0
    
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
    MUL CL
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
    INC BX               ; Siguiente estudiante
    LOOP MostrarEstudiante
    
FinMostrar:
    MOV AH, 09h
    LEA DX, msgPresioneTecla
    INT 21h
    MOV AH, 01h
    INT 21h
    RET
MostrarListaCompleta ENDP

; ImprimirCadena - Imprime string apuntado por SI
ImprimirCadena PROC
    PUSH AX
    PUSH DX
    PUSH SI
    
ImprimirLoop:
    MOV DL, [SI]         ; Cargar caracter
    CMP DL, '$'          ; Es fin de cadena?
    JE FinImprimir
    MOV AH, 02h          ; Funcion imprimir caracter
    INT 21h
    INC SI               ; Siguiente caracter
    JMP ImprimirLoop
    
FinImprimir:
    POP SI
    POP DX
    POP AX
    RET
ImprimirCadena ENDP

; MostrarEstadisticas - Muestra todas las estadisticas
MostrarEstadisticas PROC
    CALL ClrScreen 
    CALL calcular_todas_estadisticas  ; NUEVA FUNCION
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

; ClrScreen - Limpiar pantalla MEJORADO para proteger mensajes
ClrScreen:
    ; Desactivar el cursor (opcional, para evitar parpadeo)
    MOV AH, 01h          ; Funcion de cursor
    MOV CX, 2607h        ; Cursor invisible (bit 5 = 1)
    INT 10h
    
    MOV AX, 0600h        ; AH=06h (scroll), AL=00h (clear)
    MOV BH, 07h          ; Atributo (gris sobre negro)
    MOV CX, 0000h        ; Esquina superior izquierda
    MOV DX, 184Fh        ; Esquina inferior derecha (25x80)
    INT 10h              ; Interrupcion de video
    
    ; Posicionar cursor en 0,0
    MOV AH, 02h          ; Funcion posicionar cursor
    MOV BH, 00h          ; Pagina 0
    MOV DX, 0000h        ; Fila 0, Columna 0
    INT 10h
    
    ; Reactivar el cursor
    MOV AH, 01h          ; Funcion de cursor
    MOV CX, 0607h        ; Cursor normal
    INT 10h
    RET 

; separar_numeros_func - Convierte strings de notas a valores numericos
separar_numeros_func proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Inicializar indices
    mov si, offset notasList          ; Fuente: lista de notas (strings)
    mov di, offset notasenteros_array ; Destino: array de enteros
    mov bx, offset notasdecimales_array ; Destino: array de decimales
    mov cx, 0                         ; Contador de numeros procesados
    
procesar_numero:
    ; Reiniciar valores temporales
    mov word ptr entero_temp, 0
    mov word ptr decimal_temp, 0      ; Parte baja
    mov word ptr decimal_temp + 2, 0  ; Parte alta (32 bits total)
    mov decimal_encontrado, 0
    
leer_entero:
    mov al, [si]         ; Leer caracter
    cmp al, '$'          ; Fin del string?
    je fin_numero
    cmp al, '.'          ; Es punto decimal?
    je encontro_decimal
    cmp al, 13           ; Es carriage return?
    je fin_numero
    cmp al, 10           ; Es new line?
    je fin_numero
    
    ; Convertir ASCII a numero
    sub al, '0'          ; ASCII -> digito
    mov ah, 0
    push ax              ; Guardar digito
    
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
    inc si               ; Saltar el punto
    
leer_decimal:
    mov al, [si]
    cmp al, '$'
    je fin_numero
    cmp al, 13
    je fin_numero
    cmp al, 10
    je fin_numero
    
    ; Convertir ASCII a numero
    sub al, '0'
    mov ah, 0
    push ax
    
    ; decimal_temp = decimal_temp * 10 (32 bits)
    push bx
    push cx
    push dx
    
    ; Multiplicar parte baja por 10
    mov ax, word ptr decimal_temp
    mov dx, 10
    mul dx
    mov word ptr decimal_temp, ax
    mov cx, dx           ; Guardar carry
    
    ; Multiplicar parte alta por 10 y sumar carry
    mov ax, word ptr decimal_temp + 2
    mov dx, 10
    mul dx
    add ax, cx
    mov word ptr decimal_temp + 2, ax
    
    pop dx
    pop cx
    pop bx
    
    ; Sumar nuevo digito
    pop ax
    add word ptr decimal_temp, ax
    adc word ptr decimal_temp + 2, 0
    
    inc si
    jmp leer_decimal

fin_numero:
    ; Guardar entero en array
    mov ax, entero_temp
    mov [di], ax
    add di, 2            ; Avanzar 2 bytes (word)
    
    ; Guardar decimal en array
    mov ax, word ptr decimal_temp
    mov [bx], ax
    mov ax, word ptr decimal_temp + 2
    mov [bx + 2], ax
    add bx, 4            ; Avanzar 4 bytes (32 bits)
    
    ; Siguiente numero?
    inc cx
    mov al, cnt
    cbw                  ; Extender AL a AX
    cmp cx, ax
    jge terminar_proceso
    
    ; Calcular posicion del siguiente string
    push ax
    push dx
    mov ax, cx
    mov dx, notas_tam
    inc dx               ; DX = 11 (notas_tam + 1)
    mul dx               ; AX = cx * 11
    mov si, offset notasList
    add si, ax
    pop dx
    pop ax
    
    jmp procesar_numero
    
terminar_proceso:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
separar_numeros_func endp


calcular_todas_estadisticas proc
    ; Primero calcular porcentajes de aprobados/reprobados
    call calcular_porcentajes
    
    ; Luego calcular promedio, maxima y minima
    call calcular_promedio_max_min
    
    ret
calcular_todas_estadisticas endp

; calcular_porcentajes - Calcula porcentajes de aprobados y reprobados
calcular_porcentajes proc
    mov cl, cnt          ; Cargar contador de estudiantes
    xor si, si           ; Reiniciar indice
    mov aprobados, 0     ; Reiniciar contadores
    mov desaprobados, 0

ciclo_notas:
    cmp cl, 0
    je fin_ciclo

    mov ax, notasenteros_array[si] ; Cargar nota
    cmp ax, 70           ; Comparar con 70
    jl es_reprobado

es_aprobado:
    inc aprobados
    jmp siguiente

es_reprobado:
    inc desaprobados

siguiente:
    add si, 2            ; Siguiente word
    dec cl
    jmp ciclo_notas

fin_ciclo:
    ; Calcular porcentaje aprobados = (aprobados * 100) / cnt
    xor ax, ax
    mov al, aprobados
    mov bl, 100
    mul bl               ; AX = aprobados * 100
    mov bl, cnt
    div bl               ; AL = cociente (porcentaje)
    xor ah, ah           ; Limpiar residuo
    push ax

    ; Imprimir mensaje de aprobados
    mov ah, 9
    lea dx, mensajes_aprobados
    int 21h
    pop ax
    call print_num
 
    ; Calcular porcentaje reprobados
    xor ax, ax
    mov al, desaprobados
    mov bl, 100
    mul bl
    mov bl, cnt
    div bl
    xor ah, ah

    ; Imprimir mensaje de reprobados
    push ax
    mov ah, 9
    lea dx, mensajes_reprobados
    int 21h
    pop ax
    call print_num

    ret
calcular_porcentajes endp

calcular_promedio_max_min proc
    push ax
    push bx
    push cx
    push dx
    push si
    
    ; Inicializar variables
    mov suma_total, 0
    mov nota_maxima, 0     ; Inicializar en 0 (minimo posible)
    mov nota_minima, 100   ; Inicializar en 100 (maximo posible)
    
    mov cl, cnt            ; Contador de estudiantes
    xor si, si             ; Indice para recorrer array
    
    cmp cl, 0              ; Si no hay estudiantes
    je fin_calc_stats      ; Salir
    
ciclo_estadisticas:
    cmp cl, 0
    je calcular_promedio_final
    
    ; Cargar nota actual
    mov ax, notasenteros_array[si]
    
    ; Sumar al total
    add suma_total, ax
    
    ; Comparar con maxima
    cmp ax, nota_maxima
    jle no_es_maxima       ; Si AX <= nota_maxima, no actualizar
    mov nota_maxima, ax    ; Nueva maxima
    
no_es_maxima:
    ; Comparar con minima
    cmp ax, nota_minima
    jge no_es_minima       ; Si AX >= nota_minima, no actualizar
    mov nota_minima, ax    ; Nueva minima
    
no_es_minima:
    add si, 2              ; Siguiente nota (word)
    dec cl
    jmp ciclo_estadisticas
    
calcular_promedio_final:
    ; Calcular promedio = suma_total / cnt
    mov ax, suma_total
    xor dx, dx             ; Limpiar DX para division
    xor bx, bx
    mov bl, cnt
    div bx                 ; AX = suma_total / cnt
    mov promedio_general, ax
    
    ; Mostrar promedio
    mov ah, 9
    lea dx, mensaje_promedio
    int 21h
    mov ax, promedio_general
    call print_num_sin_porcentaje
    
    ; Mostrar nota maxima
    mov ah, 9
    lea dx, mensaje_nota_maxima
    int 21h
    mov ax, nota_maxima
    call print_num_sin_porcentaje
    
    ; Mostrar nota minima
    mov ah, 9
    lea dx, mensaje_nota_minima
    int 21h
    mov ax, nota_minima
    call print_num_sin_porcentaje
    
fin_calc_stats:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
calcular_promedio_max_min endp

; print_num - Imprime numero en AX con simbolo %
print_num proc
    push ax
    push bx
    push cx
    push dx

    mov cx, 0            ; Contador de digitos
    mov bx, 10           ; Divisor para decimal

    cmp ax, 0
    jne conv_loop
    ; Si AX=0, imprimir '0'
    mov dl, '0'
    mov ah, 2
    int 21h
    jmp print_symbol

conv_loop:
    xor dx, dx
    div bx               ; Dividir AX/10
    push dx              ; Guardar residuo (digito)
    inc cx               ; Incrementar contador
    cmp ax, 0
    jne conv_loop

print_digits:
    pop dx               ; Recuperar digito
    add dl, '0'          ; Convertir a ASCII
    mov ah, 2
    int 21h
    loop print_digits

print_symbol:
    ; Imprimir simbolo de porcentaje
    mov dl, '%'
    mov ah, 2
    int 21h

    pop dx
    pop cx
    pop bx
    pop ax
    ret
print_num endp

print_num_sin_porcentaje proc
    push ax
    push bx
    push cx
    push dx

    mov cx, 0            ; Contador de digitos
    mov bx, 10           ; Divisor

    cmp ax, 0
    jne conv_loop2
    ; Si AX=0, imprimir '0'
    mov dl, '0'
    mov ah, 2
    int 21h
    jmp fin_print2

conv_loop2:
    xor dx, dx
    div bx               ; AX/10
    push dx              ; Guardar digito
    inc cx
    cmp ax, 0
    jne conv_loop2

print_digits2:
    pop dx
    add dl, '0'          ; Convertir a ASCII
    mov ah, 2
    int 21h
    loop print_digits2

fin_print2:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
print_num_sin_porcentaje endp


END START