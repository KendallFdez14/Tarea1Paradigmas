.MODEL SMALL
.STACK 100h

; ------------------ Constantes ------------------------------
.DATA
estudiantesMax      EQU 15
NAME_LEN            EQU 30      ; sin '$'; se almacenará terminada en '$'
NOTE_LEN            EQU 10      ; sin '$'; se almacenará terminada en '$'
NULL_PTR            EQU 0FFFFh  

; ------------------ Buffers de entrada ----------------------
; Buffers 0Ah: [max][len][data...]
estudianteBuffer    DB NAME_LEN, 0, NAME_LEN+2 DUP(0)
notasBuffer         DB NOTE_LEN, 0, NOTE_LEN+2  DUP(0)
lineBuffer          DB 60,0, 62 DUP(0)     ; "Nombre Ap1 Ap2 Nota"

newline             DB 13,10,'$'
tab                 DB 09h,'$'

; ------------------ Mensajes -------------------------------
mensageMenu DB 13,10,'Bienvenidos a RegistroCE',13,10
           DB 'Digite:',13,10,13,10
           DB '1. Ingresar calificaciones (hasta 15 estudiantes -Nombre Apellido1 Apellido2 Nota-).',13,10
           DB '2. Mostrar estadisticas.',13,10
           DB '3. Buscar estudiante por posicion (indice).',13,10
           DB '4. Ordenar calificaciones (ascendente/descendente).',13,10
           DB '5. Salir.',13,10,13,10
           DB '$'

prompt_linea   DB 13,10,'Por favor ingrese su estudiante o digite 9 para salir al menu principal',13,10,'$'

mensaje_invalida            DB 13,10,'Opcion invalida!$'
mensaje_estudiantesmaximos  DB 13,10,'El limite de estudiantes ya fue alcanzado$'
msgPresioneTecla            DB 13,10,'Presione cualquier tecla$'
mensaje_posicion            DB 13,10,'Que estudiante desea mostrar?:  $'
mensaje_invalidaposicion    DB 13,10,'Posicion invalida. No hay estudiante en esa posicion.',13,10,'$'
mensaje_mostrar_dato        DB 13,10,'Datos del estudiante:',13,10,'$'
mensage_Lista               DB 13,10,'Lista de Estudiantes guardados:',13,10,'-------------------',13,10,'$'
titulos                     DB 'Numero  Nombres',9,9,'Notas$'

mensaje_ordenar             DB 13,10,'Como desea ordenar las calificaciones',13,10
                            DB '1. Ascendente (menor a mayor)',13,10
                            DB '2. Descendente (mayor a menor)',13,10,'$' 
orderMode DB 0              ; '1' asc, '2' des

; Mensajes adicionales para ordenamiento
mensaje_orden_asc    DB 13,10,'Lista ordenada de forma ASCENDENTE (menor a mayor):',13,10,'$'
mensaje_orden_desc   DB 13,10,'Lista ordenada de forma DESCENDENTE (mayor a menor):',13,10,'$'
mensaje_ordenando    DB 13,10,'Ordenando las calificaciones...',13,10,'$'

; ------------------ Mensajes de Validacion ------------------
; Validacion de nombres
mensaje_nombre_invalido     DB 13,10,'ERROR: Debe ingresar exactamente 3 palabras (Nombre Apellido1 Apellido2)$'
mensaje_palabra_invalida    DB 13,10,'ERROR: Solo se permiten letras en el nombre$'
mensaje_palabra_corta       DB 13,10,'ERROR: Cada palabra debe tener al menos 2 caracteres$'
mensaje_linea_vacia         DB 13,10,'ERROR: La linea no puede estar vacia$'
mensaje_formato_linea       DB 13,10,'ERROR: Formato incorrecto. Use: Nombre Apellido1 Apellido2 Nota$'

; Validacion de notas
mensaje_nota_invalida       DB 13,10,'ERROR: La nota debe estar entre 0 y 100$'
mensaje_decimales_invalidos DB 13,10,'ERROR: Maximo 5 decimales permitidos$'
mensaje_formato_invalido    DB 13,10,'ERROR: Formato invalido. Use solo numeros y punto decimal$'
mensaje_reintentar          DB 13,10,'Presione cualquier tecla para reintentar...$'

; ------------------ Mensajes de Estadisticas ----------------
mensaje_estadisticas        DB 13,10,'=== ESTADISTICAS ===',13,10,'$'
mensajes_aprobados         DB 'Porcentaje de aprobados: $'
mensajes_reprobados        DB 13,10,'Porcentaje de reprobados: $' 
mensaje_promedio           DB 13,10,'Promedio general: $'
mensaje_nota_maxima        DB 13,10,'Nota maxima: $'
mensaje_nota_minima        DB 13,10,'Nota minima: $'
mensaje_sin_estudiantes    DB 13,10,'No hay estudiantes registrados.',13,10,'$'

; ------------------ Variables de Estadisticas ---------------
aprobados           DB 0
desaprobados        DB 0
suma_total_lo       DW 0      ; Parte baja de la suma total
suma_total_hi       DW 0      ; Parte alta de la suma total
promedio_entero     DW 0      ; Parte entera del promedio
promedio_decimal    DW 0      ; Parte decimal del promedio
nota_max_int        DW 0      ; Parte entera de nota máxima
nota_max_dec_lo     DW 0      ; Decimal de nota máxima (low)
nota_max_dec_hi     DW 0      ; Decimal de nota máxima (high)
nota_min_int        DW 100    ; Parte entera de nota mínima
nota_min_dec_lo     DW 0FFFFh ; Decimal de nota mínima (low)
nota_min_dec_hi     DW 0FFFFh ; Decimal de nota mínima (high)

; ------------------ Lista enlazada --------------------------
; Nodo:
;  name[NAME_LEN+1 '$'], gradeStr[NOTE_LEN+1 '$'], gradeInt (word),
;  gradeDecLo (word), gradeDecHi (word), next (word)
; Tamaño por nodo: 31 + 11 + 2 + 2 + 2 + 2 = 50 bytes
NODE_SIZE           EQU 50

nodes               DB estudiantesMax * NODE_SIZE DUP(?)

; Cabeceras y control
headPtr             DW NULL_PTR
tailPtr             DW NULL_PTR
cnt                 DB 0

; Array de punteros para ordenamiento
nodeArray           DW estudiantesMax DUP(?)

; Temporales para parseo y escala de decimales
entero_temp         DW 0
dec_temp_lo         DW 0
dec_temp_hi         DW 0
dec_count           DB 0
decimal_encontrado  DB 0

; Swap por bloque: NAME+NOTE+gInt+gDecLo+gDecHi = 48 bytes
TEMP_BLOCK_LEN      EQU (31+11+2+2+2)
swap_block          DB TEMP_BLOCK_LEN DUP(?)

; Offsets dentro del nodo
NAME_OFF  EQU 0
NOTE_OFF  EQU 31
GINT_OFF  EQU 42
GDLO_OFF  EQU 44
GDHI_OFF  EQU 46
NEXT_OFF  EQU 48

; ------------------------------------------------------------
.CODE
START:
    mov ax, @DATA
    mov ds, ax
    mov es, ax

MainMenu:
    CALL ClrScreen
    mov ah, 09h
    lea dx, mensageMenu
    int 21h

    mov ah, 01h
    int 21h

    cmp al, '1'
    je Opcion1
    cmp al, '2'
    je Opcion2
    cmp al, '3'
    je Opcion3
    cmp al, '4'
    je Opcion4
    cmp al, '5'
    je SalirPrograma

    mov ah, 09h
    lea dx, mensaje_invalida
    int 21h
    mov ah, 01h
    int 21h
    jmp MainMenu

; ============================================================
; Utilidades basicas
; ------------------------------------------------------------

; Limpiar pantalla
ClrScreen PROC
    mov ax, 0600h
    mov bh, 07h
    mov cx, 0000h
    mov dx, 184Fh
    int 10h
    mov ah, 02h
    mov bh, 00h
    mov dx, 0000h
    int 10h
    ret
ClrScreen ENDP

; Imprimir cadena SI -> '$'
ImprimirCadena PROC
    push ax
    push dx
    push si
ImprimirLoop:
    mov dl, [si]
    cmp dl, '$'
    je  ImprimirFin
    mov ah, 02h
    int 21h
    inc si
    jmp ImprimirLoop
ImprimirFin:
    pop si
    pop dx
    pop ax
    ret
ImprimirCadena ENDP

; Copiar cadena desde SI -> DI hasta '$'
CopiarCadena PROC
    push ax
CopiarLoop:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    cmp al, '$'
    jne CopiarLoop
    pop ax
    ret
CopiarCadena ENDP

; ENTRADA: DX -> buffer 0Ah ([max][len][data...]) ; termina con '$'
TerminarCadena0Ah PROC
    push ax
    push bx
    push si
    mov si, dx
    mov bl, [si+1]                 ; len
    xor bh, bh                     ; importante: BH=0
    mov byte ptr [si+2+bx], '$'    ; fin '$'
    pop si
    pop bx
    pop ax
    ret
TerminarCadena0Ah ENDP

; Obtener offset del nodo por indice (0..cnt-1)
;  ENTRADA: AL = indice
;  SALIDA:  DI = offset del nodo
GetNodeByIndex PROC
    push ax
    xor ah, ah
    mov di, offset nodes
    mov bl, NODE_SIZE
    mul bl            ; AX = index * NODE_SIZE
    add di, ax
    pop ax
    ret
GetNodeByIndex ENDP

; ============================================================
; VALIDACION DEL NOMBRE COMPLETO
; Valida que la cadena tenga exactamente 3 palabras válidas
; ENTRADA: SI apunta al string del nombre completo
; SALIDA: AL = 1 si válido, AL = 0 si inválido
; ============================================================    

ValidarNombreCompleto PROC
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Inicializar contador de palabras
    xor cx, cx          ; CX = contador de palabras
    mov bx, 0          ; BX = longitud de palabra actual
    
    ; Saltar espacios iniciales
VNC_SaltarEspacios:
    mov al, [si]
    cmp al, '$'
    je VNC_FinCadena
    cmp al, 13
    je VNC_FinCadena
    cmp al, 10
    je VNC_FinCadena
    cmp al, ' '
    jne VNC_IniciarPalabra
    inc si
    jmp VNC_SaltarEspacios

VNC_IniciarPalabra:
    ; Nueva palabra encontrada
    mov bx, 0          ; Reiniciar contador de caracteres

VNC_LeerPalabra:
    mov al, [si]
    cmp al, '$'
    je VNC_FinPalabra
    cmp al, 13
    je VNC_FinPalabra
    cmp al, 10
    je VNC_FinPalabra
    cmp al, ' '
    je VNC_FinPalabra
    
    ; Verificar que sea letra
    cmp al, 'A'
    jb VNC_CaracterInvalido
    cmp al, 'Z'
    jbe VNC_EsLetra
    cmp al, 'a'
    jb VNC_CaracterInvalido
    cmp al, 'z'
    ja VNC_CaracterInvalido

VNC_EsLetra:
    inc bx             ; Contar caracter
    inc si
    jmp VNC_LeerPalabra

VNC_FinPalabra:
    ; Verificar que la palabra tenga al menos 2 caracteres
    cmp bx, 2
    jb VNC_PalabraCorta
    
    ; Incrementar contador de palabras
    inc cx
    
    ; Si no hemos llegado al final, buscar siguiente palabra
    mov al, [si]
    cmp al, '$'
    je VNC_FinCadena
    cmp al, 13
    je VNC_FinCadena
    cmp al, 10
    je VNC_FinCadena
    
    ; Saltar espacios entre palabras
    jmp VNC_SaltarEspacios

VNC_FinCadena:
    ; Verificar que tengamos exactamente 3 palabras
    cmp cx, 3
    je VNC_NombreValido
    
    ; No son 3 palabras
    mov ah, 09h
    lea dx, mensaje_nombre_invalido
    int 21h
    mov al, 0
    jmp VNC_Fin

VNC_CaracterInvalido:
    mov ah, 09h
    lea dx, mensaje_palabra_invalida
    int 21h
    mov al, 0
    jmp VNC_Fin

VNC_PalabraCorta:
    mov ah, 09h
    lea dx, mensaje_palabra_corta
    int 21h
    mov al, 0
    jmp VNC_Fin

VNC_NombreValido:
    mov al, 1

VNC_Fin:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
ValidarNombreCompleto ENDP

; ============================================================
; VALIDACIÓN DE NOTA
; Valida que la nota este en rango 0-100 y maximo 5 decimales
; ENTRADA: SI apunta al string de la nota
; SALIDA: AL = 1 si válida, AL = 0 si invalida
; ============================================================
ValidarNota PROC
    push bx
    push cx
    push dx
    push si
    
    ; Reiniciar variables
    mov entero_temp, 0
    mov dec_temp_lo, 0
    mov dec_temp_hi, 0
    mov decimal_encontrado, 0
    mov dec_count, 0
    
    ; Verificar si el string está vacío
    cmp BYTE PTR [si], '$'
    je VN_NotaInvalida
    cmp BYTE PTR [si], 13
    je VN_NotaInvalida
    
VN_ValidarEntero:
    mov al, [si]
    cmp al, '$'
    je VN_FinValidacion
    cmp al, 13
    je VN_FinValidacion
    cmp al, 10
    je VN_FinValidacion
    cmp al, '.'
    je VN_ValidarDecimal
    
    ; Verificar que sea dígito
    cmp al, '0'
    jb VN_FormatoInvalido
    cmp al, '9'
    ja VN_FormatoInvalido
    
    ; Convertir y acumular
    sub al, '0'
    mov ah, 0
    push ax
    
    ; entero_temp = entero_temp * 10
    mov ax, entero_temp
    mov dx, 10
    mul dx
    mov entero_temp, ax
    
    ; entero_temp = entero_temp + digito
    pop ax
    add entero_temp, ax
    
    ; Verificar que no exceda 100 en la parte entera
    cmp entero_temp, 100
    ja VN_NotaFueraRango
    
    inc si
    jmp VN_ValidarEntero

VN_ValidarDecimal:
    mov decimal_encontrado, 1
    inc si
    
VN_ValidarDecimales:
    mov al, [si]
    cmp al, '$'
    je VN_FinValidacion
    cmp al, 13
    je VN_FinValidacion
    cmp al, 10
    je VN_FinValidacion
    
    ; Verificar que sea dígito
    cmp al, '0'
    jb VN_FormatoInvalido
    cmp al, '9'
    ja VN_FormatoInvalido
    
    ; Incrementar contador de decimales
    mov al, dec_count
    inc al
    mov dec_count, al
    cmp al, 5
    ja VN_DemasiadosDecimales
    
    inc si
    jmp VN_ValidarDecimales

VN_FinValidacion:
    ; Verificar rango final (0-100)
    cmp entero_temp, 100
    ja VN_NotaFueraRango
    
    ; Si llega aqui, la nota es valida
    mov al, 1
    jmp VN_FinValidarNota

VN_NotaFueraRango:
    mov ah, 09h
    lea dx, mensaje_nota_invalida
    int 21h
    mov al, 0
    jmp VN_FinValidarNota

VN_DemasiadosDecimales:
    mov ah, 09h
    lea dx, mensaje_decimales_invalidos
    int 21h
    mov al, 0
    jmp VN_FinValidarNota

VN_FormatoInvalido:
    mov ah, 09h
    lea dx, mensaje_formato_invalido
    int 21h
    mov al, 0
    jmp VN_FinValidarNota

VN_NotaInvalida:
    mov ah, 09h
    lea dx, mensaje_formato_invalido
    int 21h
    mov al, 0

VN_FinValidarNota:
    pop si
    pop dx
    pop cx
    pop bx
    ret
ValidarNota ENDP

; ============================================================
; Recorrido de nota ASCII a (entero, decimales escalados a 5 digitos)
; ENTRADA: SI -> cadena de nota '$'-terminada
;          DI -> destino gInt
; ============================================================
ParseAsciiGradeToNode PROC
    push ax
    push bx
    push cx
    push dx

    mov word ptr entero_temp, 0
    mov word ptr dec_temp_lo, 0
    mov word ptr dec_temp_hi, 0
    mov dec_count, 0

; Parte entera
P_IntLoop:
    mov al, [si]
    cmp al, '$'
    je  P_Finish
    cmp al, '.'
    je  P_DecStart
    cmp al, 13
    je  P_Finish
    cmp al, 10
    je  P_Finish
    ; digito -> AX
    sub al, '0'
    mov ah, 0
    ; entero_temp = entero_temp*10 + al
    mov ax, entero_temp
    mov bx, 10
    mul bx           ; DX:AX = entero_temp*10
    ; sumar digito
    mov bl, [si]
    sub bl, '0'
    xor bh, bh
    add ax, bx
    mov entero_temp, ax
    inc si
    jmp P_IntLoop

; Parte decimal
P_DecStart:
    inc si
P_DecLoop:
    mov al, [si]
    cmp al, '$'
    je  P_Scale
    cmp al, 13
    je  P_Scale
    cmp al, 10
    je  P_Scale
    sub al, '0'
    mov ah, 0
    ; (dec_hi:dec_lo) = (dec_hi:dec_lo)*10 + al
    push ax
    ; low * 10
    mov ax, dec_temp_lo
    mov bx, 10
    mul bx          ; DX:AX
    mov dec_temp_lo, ax
    mov cx, dx      ; carry low
    ; hi * 10 + carry
    mov ax, dec_temp_hi
    mov bx, 10
    mul bx
    add ax, cx
    mov dec_temp_hi, ax
    ; + dígito
    pop ax
    add dec_temp_lo, ax
    adc dec_temp_hi, 0
    ; contar digitos (max 5)
    mov al, dec_count
    cmp al, 5
    jae P_SkipInc
    inc dec_count
P_SkipInc:
    inc si
    jmp P_DecLoop

; Escalar a 5 digitos: multiplicar por 10^(5 - dec_count)
P_Scale:
    mov al, dec_count
    mov ah, 0
    mov bx, 5
    cmp ax, bx
    jae P_Save
    ; reps = 5 - dec_count
    mov bl, 5
    sub bl, al
    mov cl, bl
ScaleLoop:
    mov ax, dec_temp_lo
    mov bx, 10
    mul bx          ; DX:AX
    mov dec_temp_lo, ax
    mov si, dx
    mov ax, dec_temp_hi
    mov bx, 10
    mul bx
    add ax, si
    mov dec_temp_hi, ax
    dec cl
    jnz ScaleLoop

P_Save:
    mov ax, entero_temp
    mov [di], ax
    mov ax, dec_temp_lo
    mov [di+2], ax
    mov ax, dec_temp_hi
    mov [di+4], ax

P_Finish:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
ParseAsciiGradeToNode ENDP

; ============================================================
; RECORRIDO Y VALIDACION DE LINEA COMPLETA
; Separa nombre y nota Y valida ambos
; ENTRADA: SI apunta a la linea completa
; SALIDA: CF=0 si éxito, CF=1 si error
; ============================================================
ParseLineaNombreNota PROC
    push ax
    push bx
    push cx
    push dx
    push di
    push bp
    
    ; Guardar SI original en el stack para restaurarlo después
    mov bp, sp
    mov [bp-2], si
    push si
    
    ; Verificar que la linea no este vacia
    mov al, [si]
    cmp al, '$'
    je PL_LineaVacia
    cmp al, 13
    je PL_LineaVacia
    cmp al, 10
    je PL_LineaVacia
    
    ; Buscar el final de la linea
    mov di, si
PL_FindEnd:
    mov al, [di]
    cmp al, '$'
    je  PL_HaveEnd
    inc di
    jmp PL_FindEnd

PL_HaveEnd:
    dec di

    ; Recortar espacios al final
PL_TrimEnd:
    cmp di, si
    jb  PL_FormatoIncorrecto
    mov al, [di]
    cmp al, ' '
    jne PL_FindSplit
    dec di
    jmp PL_TrimEnd

    ; Buscar el último espacio (separador nombre-nota)
PL_FindSplit:
    mov bx, di
PL_FindSpaceBack:
    cmp bx, si
    jbe PL_FormatoIncorrecto
    mov al, [bx]
    cmp al, ' '
    je  PL_SplitFound
    dec bx
    jmp PL_FindSpaceBack

PL_SplitFound:
    mov dx, bx          ; DX apunta al espacio separador
    inc bx              ; BX apunta al inicio de la nota

    ; Saltar espacios antes de la nota
PL_TrimNoteStart:
    mov al, [bx]
    cmp al, ' '
    jne PL_NoteStartOK
    inc bx
    jmp PL_TrimNoteStart

PL_NoteStartOK:
    ; Copiar la nota al buffer
    lea di, notasBuffer+2
PL_CopyNote:
    mov al, [bx]
    cmp al, '$'
    je  PL_EndCopyNote
    mov [di], al
    inc di
    inc bx
    jmp PL_CopyNote
PL_EndCopyNote:
    mov byte ptr [di], '$'

    ; Validar la nota
    lea si, notasBuffer+2
    call ValidarNota
    cmp al, 1
    jne PL_NotaInvalida

    ; Restaurar SI original y preparar para copiar el nombre
    pop si
    push si
    mov bx, dx          ; BX apunta al espacio separador
    dec bx              ; BX apunta al último carácter del nombre

    ; Recortar espacios al final del nombre
PL_TrimNameEnd:
    cmp bx, si
    jb  PL_FormatoIncorrecto
    mov al, [bx]
    cmp al, ' '
    jne PL_NameEndOK
    dec bx
    jmp PL_TrimNameEnd

PL_NameEndOK:
    ; Copiar el nombre al buffer
    lea di, estudianteBuffer+2
PL_CopyName:
    mov al, [si]
    cmp si, bx
    ja  PL_EndCopyName
    mov [di], al
    inc di
    inc si
    jmp PL_CopyName
PL_EndCopyName:
    mov byte ptr [di], '$'

    ; Validar el nombre completo
    lea si, estudianteBuffer+2
    call ValidarNombreCompleto
    cmp al, 1
    jne PL_NombreInvalido

    ; Si llegamos aquí, tanto nombre como nota son válidos
    pop si
    clc                 ; CF = 0 (éxito)
    jmp PL_Fin

PL_LineaVacia:
    mov ah, 09h
    lea dx, mensaje_linea_vacia
    int 21h
    pop si
    stc                 ; CF = 1 (error)
    jmp PL_Fin

PL_FormatoIncorrecto:
    mov ah, 09h
    lea dx, mensaje_formato_linea
    int 21h
    pop si
    stc                 ; CF = 1 (error)
    jmp PL_Fin

PL_NotaInvalida:
    ; El mensaje de error ya se mostró en ValidarNota
    pop si
    stc                 ; CF = 1 (error)
    jmp PL_Fin

PL_NombreInvalido:
    ; El mensaje de error ya se mostró en ValidarNombreCompleto
    pop si
    stc                 ; CF = 1 (error)

PL_Fin:
    pop bp
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
ParseLineaNombreNota ENDP

; ============================================================
; Construir array de punteros desde la lista enlazada
; ============================================================
BuildNodeArray PROC
    push ax
    push bx
    push cx
    push di
    push si

    ; Verificar que hay nodos
    mov al, cnt
    cmp al, 0
    je BNA_End

    ; Inicializar
    mov di, headPtr
    lea si, nodeArray      ; Usar LEA para asegurar dirección correcta
    xor cx, cx             ; Contador

BNA_Loop:
    cmp di, NULL_PTR
    je BNA_End
    
    ; Verificar límite
    cmp cl, cnt
    jae BNA_End

    ; Guardar puntero en array
    mov [si], di
    
    ; Avanzar al siguiente elemento del array
    add si, 2
    
    ; Siguiente nodo de la lista
    mov di, [di+NEXT_OFF]
    inc cx
    jmp BNA_Loop

BNA_End:
    pop si
    pop di
    pop cx
    pop bx
    pop ax
    ret
BuildNodeArray ENDP

; ============================================================
; Reconstruir lista enlazada desde array ordenado
; ============================================================
RebuildLinkedList PROC
    push ax
    push bx
    push di
    push si

    mov al, cnt
    cmp al, 0
    je RLL_END

    ; Primer nodo
    mov si, offset nodeArray
    mov di, [si]
    mov headPtr, di
    mov bx, di

    mov cl, 1
    add si, 2

RLL_Loop:
    cmp cl, cnt
    jae RLL_Last

    ; Siguiente nodo
    mov di, [si]
    mov [bx+NEXT_OFF], di
    mov bx, di
    inc cl
    add si, 2
    jmp RLL_Loop

RLL_Last:
    mov word ptr [bx+NEXT_OFF], NULL_PTR
    mov tailPtr, bx

RLL_END:
    pop si
    pop di
    pop bx
    pop ax
    ret
RebuildLinkedList ENDP

; ============================================================
; Calcular Estadisticas
; ============================================================
CalcularEstadisticas PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Verificar si hay estudiantes
    mov al, cnt
    cmp al, 0
    je CE_NoEstudiantes

    ; Inicializar variables
    mov aprobados, 0
    mov desaprobados, 0
    mov suma_total_lo, 0
    mov suma_total_hi, 0
    mov nota_max_int, 0
    mov nota_max_dec_lo, 0
    mov nota_max_dec_hi, 0
    mov nota_min_int, 100
    mov nota_min_dec_lo, 0FFFFh
    mov nota_min_dec_hi, 0FFFFh

    ; Recorrer lista enlazada
    mov di, headPtr
    xor cl, cl              ; contador

CE_Loop:
    cmp di, NULL_PTR
    je CE_FinLoop

    ; Obtener nota entera
    mov ax, [di+GINT_OFF]
    
    ; Verificar aprobado/reprobado (70 o más aprueba)
    cmp ax, 70
    jl CE_Reprobado
    inc aprobados
    jmp CE_ContinuarStats

CE_Reprobado:
    inc desaprobados

CE_ContinuarStats:
    ; Sumar al total (solo parte entera para simplificar)
    add suma_total_lo, ax
    adc suma_total_hi, 0

    ; Comparar con máxima
    mov bx, nota_max_int
    cmp ax, bx
    jl CE_NoEsMaxima
    jg CE_NuevaMaxima
    
    ; Si son iguales, comparar decimales
    mov bx, [di+GDHI_OFF]
    cmp bx, nota_max_dec_hi
    jl CE_NoEsMaxima
    jg CE_NuevaMaxima
    mov bx, [di+GDLO_OFF]
    cmp bx, nota_max_dec_lo
    jle CE_NoEsMaxima

CE_NuevaMaxima:
    mov nota_max_int, ax
    mov bx, [di+GDLO_OFF]
    mov nota_max_dec_lo, bx
    mov bx, [di+GDHI_OFF]
    mov nota_max_dec_hi, bx

CE_NoEsMaxima:
    ; Comparar con mínima
    mov bx, nota_min_int
    cmp ax, bx
    jg CE_NoEsMinima
    jl CE_NuevaMinima
    
    ; Si son iguales, comparar decimales
    mov bx, [di+GDHI_OFF]
    cmp bx, nota_min_dec_hi
    jg CE_NoEsMinima
    jl CE_NuevaMinima
    mov bx, [di+GDLO_OFF]
    cmp bx, nota_min_dec_lo
    jge CE_NoEsMinima

CE_NuevaMinima:
    mov nota_min_int, ax
    mov bx, [di+GDLO_OFF]
    mov nota_min_dec_lo, bx
    mov bx, [di+GDHI_OFF]
    mov nota_min_dec_hi, bx

CE_NoEsMinima:
    ; Siguiente nodo
    mov di, [di+NEXT_OFF]
    inc cl
    jmp CE_Loop

CE_FinLoop:
    ; Calcular promedio
    mov ax, suma_total_lo
    xor dx, dx
    xor bx, bx
    mov bl, cnt
    div bx
    mov promedio_entero, ax

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

CE_NoEstudiantes:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
CalcularEstadisticas ENDP

; ============================================================
; Imprimir numero de 2 digitos (0-99)
; Entrada: AL = numero
; ============================================================
PrintNum2Digitos PROC
    push ax
    push bx
    push dx

    xor ah, ah
    mov bl, 10
    div bl              ; AL = decenas, AH = unidades
    
    ; Imprimir decenas
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h
    
    ; Imprimir unidades
    mov al, ah
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h

    pop dx
    pop bx
    pop ax
    ret
PrintNum2Digitos ENDP

; ============================================================
; Imprimir número de 3 dígitos (0-100)
; Entrada: AX = número
; ============================================================
PrintNum3Digitos PROC
    push ax
    push bx
    push cx
    push dx

    ; Manejar caso especial de 0
    cmp ax, 0
    jne PN3_NotZero
    mov dl, '0'
    mov ah, 02h
    int 21h
    jmp PN3_Fin

PN3_NotZero:
    ; Para números 1-100, usar división por 10
    mov bx, ax          ; Guardar número original
    mov cx, 0           ; Contador de dígitos
    
    ; Convertir a dígitos (en orden inverso)
PN3_ConvLoop:
    xor dx, dx
    mov ax, bx
    mov bx, 10
    div bx              ; AX = cociente, DX = residuo
    push dx             ; Guardar dígito en stack
    inc cx              ; Contar dígito
    mov bx, ax          ; Preparar para siguiente iteración
    cmp ax, 0
    jne PN3_ConvLoop

    ; Imprimir dígitos (en orden correcto)
PN3_PrintLoop:
    pop dx
    add dl, '0'
    mov ah, 02h
    int 21h
    loop PN3_PrintLoop

PN3_Fin:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PrintNum3Digitos ENDP

; ============================================================
; Mostrar Estadisticas
; ============================================================
MostrarEstadisticas PROC
    push ax
    push bx
    push cx
    push dx

    CALL ClrScreen
    
    ; Verificar si hay estudiantes
    mov al, cnt
    cmp al, 0
    jne ME_HayEstudiantes
    
    ; No hay estudiantes
    mov ah, 09h
    lea dx, mensaje_sin_estudiantes
    int 21h
    jmp ME_FinMostrar

ME_HayEstudiantes:
    ; Calcular estadisticas
    CALL CalcularEstadisticas

    ; Título
    mov ah, 09h
    lea dx, mensaje_estadisticas
    int 21h

    ; Mostrar porcentaje de aprobados
    mov ah, 09h
    lea dx, mensajes_aprobados
    int 21h
    
    ; Calcular porcentaje aprobados = (aprobados * 100) / cnt
    xor ax, ax
    mov al, aprobados
    mov bl, 100
    mul bl              ; AX = aprobados * 100
    xor dx, dx          ; Limpiar DX para división
    xor bx, bx
    mov bl, cnt
    div bx              ; AX = resultado, DX = residuo
    call PrintNum3Digitos
    mov dl, '%'
    mov ah, 02h
    int 21h

    ; Mostrar porcentaje de reprobados
    mov ah, 09h
    lea dx, mensajes_reprobados
    int 21h
    
    ; Calcular porcentaje reprobados = (desaprobados * 100) / cnt
    xor ax, ax
    mov al, desaprobados
    mov bl, 100
    mul bl              ; AX = reprobados * 100
    xor dx, dx          ; Limpiar DX para división
    xor bx, bx
    mov bl, cnt
    div bx              ; AX = resultado
    call PrintNum3Digitos
    mov dl, '%'
    mov ah, 02h
    int 21h

    ; Mostrar promedio general
    mov ah, 09h
    lea dx, mensaje_promedio
    int 21h
    mov ax, promedio_entero
    call PrintNum3Digitos

    ; Mostrar nota máxima
    mov ah, 09h
    lea dx, mensaje_nota_maxima
    int 21h
    mov ax, nota_max_int
    call PrintNum3Digitos

    ; Mostrar nota mínima
    mov ah, 09h
    lea dx, mensaje_nota_minima
    int 21h
    mov ax, nota_min_int
    call PrintNum3Digitos

ME_FinMostrar:
    mov ah, 09h
    lea dx, msgPresioneTecla
    int 21h
    mov ah, 01h
    int 21h

    pop dx
    pop cx
    pop bx
    pop ax
    ret
MostrarEstadisticas ENDP

; ============================================================
; Buscar por posicion (1..cnt)
; ============================================================
SearchInd PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    CALL ClrScreen
    mov ah, 09h
    lea dx, mensaje_posicion
    int 21h

        ; Leer primer carácter
    mov ah, 01h
    int 21h
    cmp al, 13              ; ENTER?
    je  Inval               ; vacío -> inválido
    cmp al, '0'
    jb  Inval
    cmp al, '9'
    ja  Inval
    mov bl, al              ; BL = primer dígito (ASCII)

    ; Leer segundo carácter
    mov ah, 01h
    int 21h
    cmp al, 13              ; ENTER después de 1 dígito -> número de 1 dígito
    je  SI_OneDigit

    ; Si no fue ENTER, debe ser segundo dígito
    cmp al, '0'
    jb  Inval
    cmp al, '9'
    ja  Inval
    mov bh, al              ; BH = segundo dígito (ASCII)

    ; Consumir ENTER obligatorio tras el segundo dígito
    mov ah, 01h
    int 21h
    cmp al, 13
    jne Inval

    ; Convertir 2 dígitos: (BL*10 + BH)
    mov al, bl
    sub al, '0'
    mov ah, 0
    mov cl, 10
    mul cl                  ; AX = (primer)*10
    mov dl, bh
    sub dl, '0'
    add al, dl              ; AL = valor 10..15
    jmp SI_NumberReady

SI_OneDigit:
    ; Convertir 1 dígito: BL
    mov al, bl
    sub al, '0'             ; AL = 0..9

SI_NumberReady:
    ; Rango permitido 1..15
    cmp al, 1
    jb  Inval
    cmp al, 15
    ja  Inval

    ; Validar contra cantidad existente cnt
    mov bl, cnt
    cmp al, bl
    ja  Inval


    dec al

    mov di, headPtr
    cmp di, NULL_PTR
    je Inval

    mov cl, al
    jcxz Found
NextHop:
    mov di, [di+NEXT_OFF]
    cmp di, NULL_PTR
    je Inval
    dec cl
    jnz NextHop

Found:
    mov ah, 09h
    lea dx, mensaje_mostrar_dato
    int 21h

        ; AL contiene el índice 0-based. Imprimir (AL+1)
    inc al                   ; 1..15
    cmp al, 10
    jb  SI_PrintOne

    ; 10..15
    call PrintNum2Digitos
    jmp SI_AfterNum

SI_PrintOne:
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h

SI_AfterNum:
    mov dl, '.'
    mov ah, 02h
    int 21h
    mov dl, ' '
    int 21h


    mov si, di
    add si, NAME_OFF
    call ImprimirCadena

    mov ah, 09h
    lea dx, tab
    int 21h

    mov si, di
    add si, NOTE_OFF
    call ImprimirCadena

    mov ah, 09h
    lea dx, newline
    int 21h

    jmp PauseExit

Inval:
    mov ah, 09h
    lea dx, mensaje_invalidaposicion
    int 21h

PauseExit:
    mov ah, 09h
    lea dx, msgPresioneTecla
    int 21h
    mov ah, 01h
    int 21h

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
SearchInd ENDP

; ============================================================
; CompareGrades MEJORADA: Compara dos notas completas
; ENTRADA: SI = nodo A, DI = nodo B  
; SALIDA:  AL = 0 si A == B, AL = 1 si A > B, AL = 2 si A < B
; ============================================================
CompareGrades PROC
    push bx
    push cx
    push dx
    
    ; Comparar parte entera
    mov ax, [si+GINT_OFF]      ; entero A
    mov bx, [di+GINT_OFF]      ; entero B
    cmp ax, bx
    ja  CG_A_GREATER           ; A > B
    jb  CG_A_LESS              ; A < B
    
    ; Enteros iguales, comparar parte alta decimal
    mov ax, [si+GDHI_OFF]     
    mov bx, [di+GDHI_OFF]
    cmp ax, bx
    ja  CG_A_GREATER
    jb  CG_A_LESS
    
    ; Parte alta igual, comparar parte baja decimal
    mov ax, [si+GDLO_OFF]
    mov bx, [di+GDLO_OFF]
    cmp ax, bx
    ja  CG_A_GREATER
    jb  CG_A_LESS
    
    ; Completamente iguales
    mov al, 0                  ; A == B
    jmp CG_END

CG_A_GREATER:
    mov al, 1                  ; A > B
    jmp CG_END
    
CG_A_LESS:
    mov al, 2                  ; A < B
    
CG_END:
    pop dx
    pop cx
    pop bx
    ret
CompareGrades ENDP

; ============================================================
; Ordenar (Bubble Sort) - VERSIÓN SIMPLE Y DIRECTA
; ============================================================
OrdenarNotas PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    CALL ClrScreen
    
    ; Verificar si hay estudiantes
    mov al, cnt
    cmp al, 0
    jne ON_HayEstudiantes
    
    mov ah, 09h
    lea dx, mensaje_sin_estudiantes
    int 21h
    mov ah, 01h
    int 21h
    jmp OR_FIN
    
ON_HayEstudiantes:
    ; Preguntar orden
    mov ah, 09h
    lea dx, mensaje_ordenar
    int 21h

    mov ah, 01h
    int 21h
    mov orderMode, al

    ; Validar opción
    cmp orderMode, '1'
    je  OR_VALIDO
    cmp orderMode, '2'
    je  OR_VALIDO
    
    mov ah, 09h
    lea dx, mensaje_invalida
    int 21h
    mov ah, 01h
    int 21h
    jmp OR_FIN

OR_VALIDO:
    ; Verificar si hay al menos 2 estudiantes
    mov al, cnt
    cmp al, 2
    jb  OR_MOSTRAR_ORDENADO
    
    ; Construir array de punteros
    call BuildNodeArray

    ; BUBBLE SORT - Implementación directa
    ; Usaremos dos contadores: CH para pasadas externas, CL para internas
    
    xor ch, ch
    mov cl, cnt
    dec cl                      ; CL = número de pasadas (cnt-1)
    mov ch, cl                  ; CH = guardar número de pasadas

OR_PASADA_PRINCIPAL:
    push cx                     ; Guardar contador de pasadas
    
    ; Preparar para comparaciones internas
    xor ch, ch
    mov cl, cnt
    dec cl                      ; CL = número de comparaciones (cnt-1)
    
    lea si, nodeArray           ; SI apunta al inicio del array

OR_COMPARAR_PAR:
    push cx                     ; Guardar contador interno
    push si                     ; Guardar posición actual del array
    
    ; Cargar los dos punteros a comparar
    mov di, [si]                ; DI = primer nodo
    mov bx, [si+2]              ; BX = segundo nodo
    
    ; Comparar las notas enteras
    mov ax, [di+GINT_OFF]       ; AX = nota entera del primer nodo
    mov dx, [bx+GINT_OFF]       ; DX = nota entera del segundo nodo
    
    ; Decidir si intercambiar basado en el modo
    cmp orderMode, '1'
    je  OR_MODO_ASC
    
    ; MODO DESCENDENTE: queremos de mayor a menor
    cmp ax, dx
    jl  OR_NECESITA_SWAP        ; Si primero < segundo, intercambiar
    jg  OR_NO_SWAP              ; Si primero > segundo, no intercambiar
    jmp OR_COMPARAR_DECIMALES   ; Si son iguales, ver decimales
    
OR_MODO_ASC:
    ; MODO ASCENDENTE: queremos de menor a mayor
    cmp ax, dx
    jg  OR_NECESITA_SWAP        ; Si primero > segundo, intercambiar
    jl  OR_NO_SWAP              ; Si primero < segundo, no intercambiar
    ; Si son iguales, comparar decimales

OR_COMPARAR_DECIMALES:
    ; Las partes enteras son iguales, comparar decimales
    ; Primero comparar parte alta de decimales
    mov ax, [di+GDHI_OFF]
    mov dx, [bx+GDHI_OFF]
    
    cmp orderMode, '1'
    je  OR_DEC_ASC
    
    ; Decimales en modo descendente
    cmp ax, dx
    jl  OR_NECESITA_SWAP
    jg  OR_NO_SWAP
    ; Si son iguales, comparar parte baja
    mov ax, [di+GDLO_OFF]
    mov dx, [bx+GDLO_OFF]
    cmp ax, dx
    jl  OR_NECESITA_SWAP
    jmp OR_NO_SWAP
    
OR_DEC_ASC:
    ; Decimales en modo ascendente
    cmp ax, dx
    jg  OR_NECESITA_SWAP
    jl  OR_NO_SWAP
    ; Si son iguales, comparar parte baja
    mov ax, [di+GDLO_OFF]
    mov dx, [bx+GDLO_OFF]
    cmp ax, dx
    jg  OR_NECESITA_SWAP
    jmp OR_NO_SWAP

OR_NECESITA_SWAP:
    ; Intercambiar los punteros en el array
    pop si                      ; Recuperar posición del array
    push si                     ; Guardarla de nuevo
    
    mov ax, [si]                ; AX = primer puntero
    mov dx, [si+2]              ; DX = segundo puntero
    mov [si], dx                ; Primer slot = segundo puntero
    mov [si+2], ax              ; Segundo slot = primer puntero

OR_NO_SWAP:
    pop si                      ; Recuperar posición del array
    add si, 2                   ; Avanzar al siguiente par
    pop cx                      ; Recuperar contador interno
    loop OR_COMPARAR_PAR
    
    pop cx                      ; Recuperar contador de pasadas
    dec ch
    jnz OR_PASADA_PRINCIPAL

    ; Reconstruir la lista enlazada con el nuevo orden
    call RebuildLinkedList

OR_MOSTRAR_ORDENADO:
    ; Mostrar la lista ordenada
    CALL ClrScreen
    
    ; Mostrar mensaje según el orden
    cmp orderMode, '1'
    je  OR_MSG_ASC
    
    mov ah, 09h
    lea dx, mensaje_orden_desc
    int 21h
    jmp OR_MOSTRAR_LISTA
    
OR_MSG_ASC:
    mov ah, 09h
    lea dx, mensaje_orden_asc
    int 21h

OR_MOSTRAR_LISTA:
    ; Mostrar títulos
    mov ah, 09h
    lea dx, titulos
    int 21h
    lea dx, newline
    int 21h

    ; Mostrar la lista desde el head actualizado
    mov di, headPtr
    mov bl, 1                   ; Contador para numeración

OR_LOOP_MOSTRAR:
    cmp di, NULL_PTR
    je OR_FIN_MOSTRAR
    
    ; Mostrar número
    mov ah, 02h
    mov dl, bl
    add dl, '0'
    int 21h
    mov dl, '.'
    int 21h
    mov dl, ' '
    int 21h

    ; Mostrar nombre
    push di
    add di, NAME_OFF
    mov si, di
    call ImprimirCadena
    pop di

    ; Tab
    mov ah, 09h
    lea dx, tab
    int 21h

    ; Mostrar nota
    push di
    add di, NOTE_OFF
    mov si, di
    call ImprimirCadena
    pop di

    ; Nueva línea
    mov ah, 09h
    lea dx, newline
    int 21h

    ; Siguiente nodo
    mov di, [di+NEXT_OFF]
    inc bl
    jmp OR_LOOP_MOSTRAR

OR_FIN_MOSTRAR:
    mov ah, 09h
    lea dx, msgPresioneTecla
    int 21h
    mov ah, 01h
    int 21h

OR_FIN:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
OrdenarNotas ENDP

; ============================================================
; Mostrar lista completa
; ============================================================
MostrarListaCompleta PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    CALL ClrScreen
    mov ah, 09h
    lea dx, mensage_Lista
    int 21h
    lea dx, titulos
    int 21h
    lea dx, newline
    int 21h

    mov al, cnt
    cmp al, 0
    je FinMostrar

    mov di, headPtr
    xor bl, bl

ListaLoop:
    mov ah, 02h
    mov dl, bl
    add dl, '1'
    int 21h
    mov dl, '.'
    int 21h
    mov dl, ' '
    int 21h

    mov si, di
    add si, NAME_OFF
    call ImprimirCadena

    mov ah, 09h
    lea dx, tab
    int 21h

    mov si, di
    add si, NOTE_OFF
    call ImprimirCadena

    mov ah, 09h
    lea dx, newline
    int 21h

    mov di, [di+NEXT_OFF]
    inc bl
    cmp di, NULL_PTR
    jne ListaLoop

FinMostrar:
    mov ah, 09h
    lea dx, msgPresioneTecla
    int 21h
    mov ah, 01h
    int 21h

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
MostrarListaCompleta ENDP

; ===========================================================
; Opcion 1: ingreso por linea completa CON VALIDACIONES
; ============================================================
Opcion1:
    CALL ClrScreen
IngresarLoop:
    mov ah, 09h
    lea dx, prompt_linea
    int 21h

    ; Leer linea completa
    mov ah, 0Ah
    lea dx, lineBuffer
    int 21h

    ; Terminar cadena con '
    lea dx, lineBuffer
    call TerminarCadena0Ah

    ; Verificar si quiere salir ('9')
    mov si, offset lineBuffer
    mov bl, [si+1]      ; longitud
    cmp bl, 1
    jne NoSalir9
    mov al, [si+2]      ; primer caracter
    cmp al, '9'
    je  FinOpcion1
NoSalir9:

    ; Recorrer y validar linea
    lea si, [si+2]      ; apuntar a los datos
    call ParseLineaNombreNota
    jc  MostrarErrorYReintentar    ; Si hay error, reintentar

    ; Si es valida, agregar el estudiante
    call AgregarDesdeBuffers
    jmp IngresarLoop

MostrarErrorYReintentar:
    mov ah, 09h
    lea dx, mensaje_reintentar
    int 21h
    mov ah, 01h
    int 21h
    jmp IngresarLoop

FinOpcion1:
    jmp MainMenu

; ============================================================
; AgregarDesdeBuffers: usa estudianteBuffer/notasBuffer
; ============================================================
AgregarDesdeBuffers PROC
    push ax
    push bx
    push si
    push di

    mov al, cnt
    cmp al, estudiantesMax
    jb  ADB_okAdd
    mov ah, 09h
    lea dx, mensaje_estudiantesmaximos
    int 21h
    jmp ADB_endAdd

ADB_okAdd:
    mov al, cnt
    call GetNodeByIndex
    mov bx, di

    lea si, estudianteBuffer+2
    mov di, bx
    add di, NAME_OFF
    call CopiarCadena

    lea si, notasBuffer+2
    mov di, bx
    add di, NOTE_OFF
    call CopiarCadena

    mov si, bx
    add si, NOTE_OFF
    mov di, bx
    add di, GINT_OFF
    call ParseAsciiGradeToNode

    mov word ptr [bx+NEXT_OFF], NULL_PTR
    mov ax, headPtr
    cmp ax, NULL_PTR
    jne ADB_hasHead
    mov headPtr, bx
    mov tailPtr, bx
    jmp ADB_incCnt

ADB_hasHead:
    mov di, tailPtr
    mov word ptr [di+NEXT_OFF], bx
    mov tailPtr, bx

ADB_incCnt:
    inc cnt

ADB_endAdd:
    pop di
    pop si
    pop bx
    pop ax
    ret
AgregarDesdeBuffers ENDP

; ============================================================
; Opcion2/3/4/5
; ============================================================
Opcion2:                    ; Mostrar estadisticas
    CALL MostrarEstadisticas
    jmp MainMenu

Opcion3:
    CALL SearchInd
    jmp MainMenu

Opcion4:
    CALL OrdenarNotas
    jmp MainMenu

SalirPrograma:
    mov ah, 4Ch
    int 21h

END START

































