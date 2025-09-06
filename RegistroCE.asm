.MODEL SMALL
.STACK 100h

; ------------------ Constantes ------------------------------
.DATA
estudiantesMax      EQU 15
NAME_LEN            EQU 30      ; sin '$'; se almacenará terminada en '$'
NOTE_LEN            EQU 10      ; sin '$'; se almacenará terminada en '$'
NULL_PTR            EQU 0FFFFh          
SCALE_FACTOR_LOW    EQU 34464    ; 100000 MOD 65536 (parte baja)
SCALE_FACTOR_HIGH   EQU 1        ; 100000 DIV 65536 (parte alta)

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
mensaje_nombre_invalido     DB 13,10,'ERROR: Debe ingresar exactamente 2 o 3 palabras (Nombre Apellido1 Apellido2)$'
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
mensajes_reprobados        DB 'Porcentaje de reprobados: $'
mensaje_promedio           DB 13,10,'Promedio general: $'
mensaje_nota_maxima        DB 13,10,'Nota maxima: $'
mensaje_nota_minima        DB 13,10,'Nota minima: $'
mensaje_sin_estudiantes    DB 13,10,'No hay estudiantes registrados.',13,10,'$'
mensaje_de                 DB ' de $'
mensaje_cant_aprobados     DB 13,10,'Cantidad de aprobados: $'
mensaje_cant_reprobados    DB 13,10,'Cantidad de reprobados: $'   


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

; Variables temporales para calculos decimales
suma_dec_lo         DW 0      ; Suma de decimales (parte baja)
suma_dec_hi         DW 0      ; Suma de decimales (parte alta)   
temp_calc_lo        DW 0      ; Para calculos temporales
temp_calc_hi        DW 0      ; Para calculos temporales

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
    mov ax, @DATA       ; Cargar direccion del segmento de datos
    mov ds, ax          ; Establecer DS (Data Segment)
    mov es, ax          ; Establecer ES (Extra Segment) para strings
    
    
    
;_________________________MENU PRINCIPAL__________________    
MainMenu:
    CALL ClrScreen      ; Limpiar pantalla
    mov ah, 09h         ; Funcion DOS: imprimir string
    lea dx, mensageMenu ; Cargar direccion del menu
    int 21h             ; Llamar a DOS

    mov ah, 01h         ; Funcion DOS: leer carácter
    int 21h             ; AL = caracter leido

    ; Evaluar opcion elegida
    cmp al, '1'
    je Opcion1          ; Saltar a ingresar calificaciones
    cmp al, '2'
    je Opcion2          ; Saltar a estadisticas
    cmp al, '3'
    je Opcion3          ; Saltar a buscar
    cmp al, '4'
    je Opcion4          ; Saltar a ordenar
    cmp al, '5'
    je SalirPrograma    ; Saltar a salir

    ; Si no es valida, mostrar error
    mov ah, 09h
    lea dx, mensaje_invalida
    int 21h
    mov ah, 01h         ; Esperar tecla
    int 21h
    jmp MainMenu        ; Volver al menu

; ============================================================
; Utilidades basicas
; ------------------------------------------------------------

; Limpiar pantalla

; No recibe parametros
; Limpia la pantalla y posiciona cursor en (0,0)
ClrScreen PROC
    mov ax, 0600h       ; AH=06h (scroll), AL=00h (toda la ventana)
    mov bh, 07h         ; Atributo: texto blanco, fondo negro
    mov cx, 0000h       ; Esquina superior izquierda (fila 0, col 0)
    mov dx, 184Fh       ; Esquina inferior derecha (fila 24, col 79)
    int 10h             
    mov ah, 02h         ; Funcion: posicionar cursor
    mov bh, 00h         ; Pagina 0
    mov dx, 0000h       ; Posicion (0,0)
    int 10h
    ret
ClrScreen ENDP
  
; ----------__Imprimir Cadena ----------
; SI = direccion de la cadena terminada en '$'
; Imprime caracter por caracter hasta encontrar '$'  
  
; Imprimir cadena SI -> '$'
ImprimirCadena PROC
    push ax  ;Guardar registros
    push dx
    push si
ImprimirLoop:
    mov dl, [si]        ; Cargar caracter actual
    cmp dl, '$'         ; Es fin de cadena?
    je  ImprimirFin     ; Si es '$', terminar
    mov ah, 02h         ; Funcion DOS: imprimir carácter
    int 21h
    inc si              ; Siguiente caracter
    jmp ImprimirLoop
ImprimirFin:
    pop si   ;Restaurar registros
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
; Valida que la cadena tenga exactamente 3 palabras validas
; ENTRADA: SI apunta al string del nombre completo
; SALIDA: AL = 1 si valido, AL = 0 si invalido
; ============================================================    

;Recorre la cadena en SI contando exactamente 3 palabras (nombre + dos apellidos), con mayor o igual 2 letras por palabra.
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
    ; Verificar que tengamos 2 o 3 palabras
    cmp cx, 2
    jb  VNC_NotValid       ; menos de 2 -> invalido
    cmp cx, 3
    jbe VNC_NombreValido   ; 2 o 3 -> valido

VNC_NotValid:
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
; VALIDACION DE NOTA
; Valida que la nota este en rango 0-100 y maximo 5 decimales
; ENTRADA: SI apunta al string de la nota
; SALIDA: AL = 1 si valida, AL = 0 si invalida
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
    
    ; Verificar si el string esta vacio
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
    
    ; Verificar que sea digito
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
    
    ; Verificar que sea digito
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
    push si

    mov word ptr entero_temp, 0
    mov word ptr dec_temp_lo, 0
    mov word ptr dec_temp_hi, 0
    mov dec_count, 0

; Parte entera
P_IntLoop:
    mov al, [si]
    cmp al, '$'
    je  P_Scale        
    cmp al, '.'
    je  P_DecStart
    cmp al, 13
    je  P_Scale        
    cmp al, 10
    je  P_Scale        
    
    ; digito -> AX
    sub al, '0'
    mov ah, 0
    push ax
    
    ; entero_temp = entero_temp*10 + al
    mov ax, entero_temp
    mov bx, 10
    mul bx           ; DX:AX = entero_temp*10
    pop bx
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
    
    ; Solo procesar hasta 5 decimales
    mov bl, dec_count
    cmp bl, 5
    jae P_Scale
    
    ; Multiplicar decimales actuales por 10 y sumar nuevo digito
    push ax             ; guardar nuevo digito
    
    ; dec_temp_lo = dec_temp_lo * 10
    mov ax, dec_temp_lo
    mov bx, 10
    mul bx
    mov dec_temp_lo, ax
    
    ; sumar el nuevo digito
    pop ax
    add dec_temp_lo, ax
    
    inc dec_count
    inc si
    jmp P_DecLoop

P_Scale:
    ; Escalar a exactamente 5 digitos multiplicando por 10^(5-dec_count)
    mov al, dec_count
    cmp al, 5
    jae P_Save          ; Si ya tenemos 5 decimales, guardar directamente
    
    ; Calcular cuantas veces multiplicar por 10
    mov cl, 5
    sub cl, al          ; CL = 5 - dec_count
    
ScaleLoop:
    cmp cl, 0
    je P_Save
    
    ; Multiplicar dec_temp_lo por 10
    mov ax, dec_temp_lo
    mov bx, 10
    mul bx              
    mov dec_temp_lo, ax
    
    dec cl
    jmp ScaleLoop

P_Save:
    ; Guardar valores en el nodo
    mov ax, entero_temp
    mov [di], ax        ; Guardar parte entera
    mov ax, dec_temp_lo
    mov [di+2], ax      ; Guardar parte baja decimal
    mov word ptr [di+4], 0    ; Parte alta decimal = 0 (simplificado)

P_Finish:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
ParseAsciiGradeToNode ENDP

; ============================================================
; RECORRIDO Y VALIDACION DE LINEA COMPLETA
; Separar la linea en nota y nombre, validar ambos y dejar nombre/nota en buffers para insercion.
; ENTRADA: SI apunta a la linea completa
; SALIDA: CF=0 si exito, CF=1 si error
; ============================================================
ParseLineaNombreNota PROC
    push ax
    push bx
    push cx
    push dx
    push di
    push bp
    
    ; Guardar SI original en el stack para restaurarlo despues
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

    ; Buscar el ultimo espacio (separador nombre-nota)
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
    dec bx              ; BX apunta al ultimo caracter del nombre

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

    ; Si llegamos aqui, tanto nombre como nota son validos
    pop si
    clc                 ; CF = 0 (exito)
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
    ; El mensaje de error ya se mostrara en ValidarNota
    pop si
    stc                 ; CF = 1 (error)
    jmp PL_Fin

PL_NombreInvalido:
    ; El mensaje de error ya se mostrara en ValidarNombreCompleto
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
    lea si, nodeArray      ; Usar LEA para asegurar direccion correcta
    xor cx, cx             ; Contador

BNA_Loop:
    cmp di, NULL_PTR
    je BNA_End
    
    ; Verificar limite
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
; Calcular Estadisticas con Decimales
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
    mov suma_dec_lo, 0
    mov suma_dec_hi, 0
    mov nota_max_int, 0
    mov nota_max_dec_lo, 0
    mov nota_max_dec_hi, 0
    mov nota_min_int, 101         
    mov nota_min_dec_lo, 0        
    mov nota_min_dec_hi, 0        

    ; Recorrer lista enlazada
    mov di, headPtr
    xor cl, cl              ; contador

CE_Loop:
    cmp di, NULL_PTR
    je CE_FinLoop

    ; Obtener nota entera
    mov ax, [di+GINT_OFF]
    
    ; Verificar aprobado/reprobado (70 o mas aprueba)
    cmp ax, 70
    jl CE_Reprobado
    inc aprobados
    jmp CE_ContinuarStats

CE_Reprobado:
    inc desaprobados

CE_ContinuarStats:
    ; Sumar parte entera al total
    add suma_total_lo, ax
    adc suma_total_hi, 0
    
    ; Sumar parte decimal
    mov ax, [di+GDLO_OFF]
    add suma_dec_lo, ax
    mov ax, [di+GDHI_OFF]
    adc suma_dec_hi, ax

    ; Comparar con maxima
    mov ax, [di+GINT_OFF]
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
    mov ax, [di+GINT_OFF]
    mov nota_max_int, ax
    mov bx, [di+GDLO_OFF]
    mov nota_max_dec_lo, bx
    mov bx, [di+GDHI_OFF]
    mov nota_max_dec_hi, bx

CE_NoEsMaxima:
    ; Comparar con minima
    mov ax, [di+GINT_OFF]
    mov bx, nota_min_int
    cmp bx, 101                   
    je CE_PrimeraMinima
    
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

CE_PrimeraMinima:
CE_NuevaMinima:
    mov ax, [di+GINT_OFF]
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
    ; Calcular promedio - CORREGIDO
    ; Promedio entero = suma_total_lo / cnt
    mov ax, suma_total_lo
    xor dx, dx
    xor bx, bx
    mov bl, cnt
    div bx                        ; AX = promedio_entero, DX = residuo
    mov promedio_entero, ax
    
    ; Para los decimales del promedio, usar una aproximacion mas simple
    ; residuo * 1000 / cnt para obtener 3 decimales escalados
    mov ax, dx                    ; residuo de la divisi?n anterior
    mov bx, 1000                  ; escalar a 1000 para 3 decimales
    mul bx                        ; DX:AX = residuo * 1000
    
    xor bx, bx
    mov bl, cnt
    div bx                        ; AX = decimales escalados a 3 digitos
    mov promedio_decimal, ax      ; guardar decimales escalados

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
; Imprimir numero de 3 digitos (0-100)
; Entrada: AX = numero
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
    ; Para numeros 1-100, usar division por 10
    mov bx, ax          ; Guardar numero original
    mov cx, 0           ; Contador de digitos
    
    ; Convertir a digitos (en orden inverso)
PN3_ConvLoop:
    xor dx, dx
    mov ax, bx
    mov bx, 10
    div bx              ; AX = cociente, DX = residuo
    push dx             ; Guardar digito en stack
    inc cx              ; Contar digito
    mov bx, ax          ; Preparar para siguiente iteracion
    cmp ax, 0
    jne PN3_ConvLoop

    ; Imprimir digitos (en orden correcto)
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
; Imprimir Decimales de Nota
; Entrada: BX = dec_lo, CX = dec_hi (escalado a 100000)
; ============================================================
PrintDecimalesNota PROC
    push ax
    push bx
    push cx
    push dx
    push si
    
    ; Si ambos son 0, no imprimir decimales
    mov ax, bx
    or ax, cx
    jz PDN_Fin
    
    ; Imprimir punto decimal
    mov dl, '.'
    mov ah, 02h
    int 21h
    
    ; Para simplificar, trabajaremos solo con la parte baja (BX)
    ; y mostraremos hasta 3 decimales significativos
    mov ax, bx
    
    ; Si el n?mero es mayor a 99999, usar solo los ?ltimos 5 digitos
    cmp ax, 9999
    jbe PDN_StartConvert
    
    ; Reducir el n?mero dividiendo por 10 hasta que sea manejable
PDN_Reduce:
    cmp ax, 9999
    jbe PDN_StartConvert
    push dx
    xor dx, dx
    mov si, 10
    div si
    pop dx
    jmp PDN_Reduce

PDN_StartConvert:
    ; Convertir hasta 4 decimales
    mov si, 0           ; contador de decimales impresos
    mov cx, ax          ; guardar n?mero para trabajar
    
    ; Primer decimal: dividir por 1000
    mov ax, cx
    cmp ax, 1000
    jb PDN_Decimal2
    xor dx, dx
    mov bx, 1000
    div bx              ; AX = primer decimal, DX = residuo
    add al, '0'
    push dx
    push cx
    mov dl, al
    mov ah, 02h
    int 21h
    pop cx
    pop dx
    mov cx, dx          ; actualizar n?mero de trabajo
    inc si
    
PDN_Decimal2:
    ; Segundo decimal: dividir por 100
    mov ax, cx
    cmp ax, 100
    jb PDN_Decimal3
    xor dx, dx
    mov bx, 100
    div bx
    add al, '0'
    push dx
    push cx
    mov dl, al
    mov ah, 02h
    int 21h
    pop cx
    pop dx
    mov cx, dx
    inc si
    
PDN_Decimal3:
    ; Tercer decimal: dividir por 10
    mov ax, cx
    cmp ax, 10
    jb PDN_Decimal4
    xor dx, dx
    mov bx, 10
    div bx
    add al, '0'
    push dx
    push cx
    mov dl, al
    mov ah, 02h
    int 21h
    pop cx
    pop dx
    mov cx, dx
    inc si
    
PDN_Decimal4:
    ; Cuarto decimal: el residuo
    mov ax, cx
    cmp ax, 0
    je PDN_CheckEmpty
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h
    inc si
    jmp PDN_Fin
    
PDN_CheckEmpty:
    ; Si no hemos impreso nada, imprimir al menos un 0
    cmp si, 0
    jne PDN_Fin
    mov dl, '0'
    mov ah, 02h
    int 21h

PDN_Fin:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PrintDecimalesNota ENDP

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

    ; Titulo
    mov ah, 09h
    lea dx, mensaje_estadisticas
    int 21h

    ; ===== Mostrar porcentaje de aprobados =====
    mov ah, 09h
    lea dx, mensajes_aprobados
    int 21h
    
    ; Preparar BX con cnt y asegurar BH=0
    xor bx, bx
    mov bl, cnt
    cmp bl, 0
    je ME_FinMostrar
    
    ; Calcular porcentaje aprobados = (aprobados * 100) / cnt
    xor ax, ax
    mov al, aprobados
    
    ; Verificar si aprobados es 0
    cmp al, 0
    je ME_CeroAprobados
    
    ; CORRECCIÓN: Usar multiplicación correcta
    mov cx, 100
    mul cx              ; AX = aprobados * 100
    
    ; División con BX que ya contiene cnt
    xor dx, dx          ; Limpiar DX para la división
    div bx              ; AX = porcentaje, DX = residuo
    jmp ME_MostrarPorcentajeAprob

ME_CeroAprobados:
    mov ax, 0           ; 0% aprobados
    mov dx, 0           ; Sin residuo

ME_MostrarPorcentajeAprob:
    ; Mostrar el porcentaje
    push dx             ; Guardar residuo
    call PrintNum3Digitos
    pop dx              ; Recuperar residuo
    
    ; Mostrar un decimal del porcentaje si no es exacto
    cmp dx, 0
    je ME_NoDecAprobados
    
    push ax             ; Guardar porcentaje entero
    push dx             ; Guardar residuo
    mov dl, '.'
    mov ah, 02h
    int 21h
    pop ax              ; Recuperar residuo en AX
    
    ; Calcular 1 decimal del porcentaje
    mov cx, 10
    mul cx              ; amplificar residuo para 1 decimal
    
    xor dx, dx
    xor bx, bx
    mov bl, cnt
    div bx              ; AX = decimal
    
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h
    pop ax              ; Recuperar porcentaje entero

ME_NoDecAprobados:
    mov dl, '%'
    mov ah, 02h
    int 21h
    
    ; ===== Mostrar (aprobados de total) =====
    mov dl, ' '
    mov ah, 02h
    int 21h
    mov dl, '('
    int 21h
    
    ; Mostrar cantidad de aprobados
    xor ax, ax
    mov al, aprobados
    cmp al, 10
    jb ME_Aprob_UnDigito
    
    xor ah, ah
    mov cl, 10
    div cl              ; AL = decenas, AH = unidades
    add al, '0'
    mov dl, al
    push ax
    mov ah, 02h
    int 21h
    pop ax
    mov al, ah
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h
    jmp ME_Aprob_Continuar

ME_Aprob_UnDigito:
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h

ME_Aprob_Continuar:
    ; Mostrar " de "
    mov ah, 09h
    lea dx, mensaje_de
    int 21h
    
    ; Mostrar total
    xor ax, ax
    mov al, cnt
    cmp al, 10
    jb ME_Total1_UnDigito
    
    xor ah, ah
    mov cl, 10
    div cl
    add al, '0'
    mov dl, al
    push ax
    mov ah, 02h
    int 21h
    pop ax
    mov al, ah
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h
    jmp ME_Total1_Continuar

ME_Total1_UnDigito:
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h

ME_Total1_Continuar:
    mov dl, ')'
    mov ah, 02h
    int 21h

    ; ===== Mostrar porcentaje de reprobados =====  
    mov ah, 09h
    lea dx, newline
    int 21h
    mov ah, 09h
    lea dx, mensajes_reprobados
    int 21h
    
    ; Preparar BX con cnt
    xor bx, bx
    mov bl, cnt
    
    ; Calcular porcentaje reprobados
    xor ax, ax
    mov al, desaprobados
    cmp al, 0
    je ME_CeroReprobados
    
    ; CORRECCIÓN: Usar multiplicación correcta
    mov cx, 100
    mul cx              ; AX = desaprobados * 100
    
    xor dx, dx
    div bx              ; AX = porcentaje, DX = residuo
    jmp ME_MostrarPorcentajeReprob

ME_CeroReprobados:
    mov ax, 0
    mov dx, 0

ME_MostrarPorcentajeReprob:
    push dx             ; Guardar residuo
    call PrintNum3Digitos
    pop dx              ; Recuperar residuo
    
    cmp dx, 0
    je ME_NoDecReprobados
    
    push ax
    push dx
    mov dl, '.'
    mov ah, 02h
    int 21h
    pop ax              ; residuo en AX
    
    mov cx, 10
    mul cx
    xor dx, dx
    xor bx, bx
    mov bl, cnt
    div bx
    
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h
    pop ax

ME_NoDecReprobados: 
    mov dl, '%'
    mov ah, 02h
    int 21h
    
    ; ===== Mostrar (reprobados de total) =====
    mov dl, ' '
    mov ah, 02h
    int 21h
    mov dl, '('
    int 21h
    
    ; Mostrar cantidad de reprobados
    xor ax, ax
    mov al, desaprobados
    cmp al, 10
    jb ME_Reprob_UnDigito
    
    xor ah, ah
    mov cl, 10
    div cl
    add al, '0'
    mov dl, al
    push ax
    mov ah, 02h
    int 21h
    pop ax
    mov al, ah
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h
    jmp ME_Reprob_Continuar

ME_Reprob_UnDigito:
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h

ME_Reprob_Continuar:
    mov ah, 09h
    lea dx, mensaje_de
    int 21h
    
    xor ax, ax
    mov al, cnt
    cmp al, 10
    jb ME_Total2_UnDigito
    
    xor ah, ah
    mov cl, 10
    div cl
    add al, '0'
    mov dl, al
    push ax
    mov ah, 02h
    int 21h
    pop ax
    mov al, ah
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h
    jmp ME_Total2_Continuar

ME_Total2_UnDigito:
    add al, '0'
    mov dl, al
    mov ah, 02h
    int 21h

ME_Total2_Continuar:
    mov dl, ')'
    mov ah, 02h
    int 21h

    ; ===== Resto de estadísticas =====
    ; Mostrar promedio general
    mov ah, 09h
    lea dx, mensaje_promedio
    int 21h
    
    mov ax, promedio_entero
    call PrintNum3Digitos
    
    ; Decimales del promedio
    mov bx, promedio_decimal
    mov cx, 0
    cmp bx, 0
    je ME_NoDecPromedio
    call PrintDecimalesNota

ME_NoDecPromedio:

    ; Mostrar nota maxima
    mov ah, 09h
    lea dx, mensaje_nota_maxima
    int 21h
    
    mov ax, nota_max_int
    call PrintNum3Digitos
    
    mov bx, nota_max_dec_lo
    mov cx, nota_max_dec_hi
    call PrintDecimalesNota

    ; Mostrar nota minima
    mov ah, 09h
    lea dx, mensaje_nota_minima
    int 21h
    
    mov ax, nota_min_int
    call PrintNum3Digitos
    
    mov bx, nota_min_dec_lo
    mov cx, nota_min_dec_hi
    call PrintDecimalesNota

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

        ; Leer primer caracter
    mov ah, 01h
    int 21h
    cmp al, 13              ; ENTER
    je  Inval               ; vacio -> invalido
    cmp al, '0'
    jb  Inval
    cmp al, '9'
    ja  Inval
    mov bl, al              ; BL = primer digito (ASCII)

    ; Leer segundo caracter
    mov ah, 01h
    int 21h
    cmp al, 13              ; ENTER despues de 1 digito -> número de 1 digito
    je  SI_OneDigit

    ; Si no fue ENTER, debe ser segundo digito
    cmp al, '0'
    jb  Inval
    cmp al, '9'
    ja  Inval
    mov bh, al              ; BH = segundo digito (ASCII)

    ; Consumir ENTER obligatorio tras el segundo digito
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
    ; Convertir 1 digito: BL
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
    ; Mostrar cabecera
    mov ah, 09h
    lea dx, mensaje_mostrar_dato
    int 21h

    ; >>> Sin numeración: imprimir solo nombre y nota <<<
    ; Nombre
    mov si, di
    add si, NAME_OFF
    call ImprimirCadena

    ; Tab
    mov ah, 09h
    lea dx, tab
    int 21h

    ; Nota
    mov si, di
    add si, NOTE_OFF
    call ImprimirCadena

    ; Nueva línea y salir
    mov ah, 09h
    lea dx, newline
    int 21h

    jmp PauseExit


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
; CompareGrades: Compara dos notas completas
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

; =====================
; Ordenar (Bubble Sort)
; =====================
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

    ; Validar opcion
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

    ; BUBBLE SORT (solo en el array, no en la lista)
    xor ch, ch
    mov cl, cnt
    dec cl                      
    mov ch, cl                  

OR_PASADA_PRINCIPAL:
    push cx                     
    
    xor ch, ch
    mov cl, cnt
    dec cl                      
    
    lea si, nodeArray           

OR_COMPARAR_PAR:
    push cx                     
    push si                     
    
    mov di, [si]                
    mov bx, [si+2]              
    
    mov ax, [di+GINT_OFF]       
    mov dx, [bx+GINT_OFF]       
    
    cmp orderMode, '1'
    je  OR_MODO_ASC
    
    ; MODO DESCENDENTE
    cmp ax, dx
    jl  OR_NECESITA_SWAP        
    jg  OR_NO_SWAP              
    jmp OR_COMPARAR_DECIMALES   
    
OR_MODO_ASC:
    ; MODO ASCENDENTE
    cmp ax, dx
    jg  OR_NECESITA_SWAP        
    jl  OR_NO_SWAP              

OR_COMPARAR_DECIMALES:
    mov ax, [di+GDHI_OFF]
    mov dx, [bx+GDHI_OFF]
    
    cmp orderMode, '1'
    je  OR_DEC_ASC
    
    cmp ax, dx
    jl  OR_NECESITA_SWAP
    jg  OR_NO_SWAP
    mov ax, [di+GDLO_OFF]
    mov dx, [bx+GDLO_OFF]
    cmp ax, dx
    jl  OR_NECESITA_SWAP
    jmp OR_NO_SWAP
    
OR_DEC_ASC:
    cmp ax, dx
    jg  OR_NECESITA_SWAP
    jl  OR_NO_SWAP
    mov ax, [di+GDLO_OFF]
    mov dx, [bx+GDLO_OFF]
    cmp ax, dx
    jg  OR_NECESITA_SWAP
    jmp OR_NO_SWAP

OR_NECESITA_SWAP:
    pop si                      
    push si                     
    
    mov ax, [si]                
    mov dx, [si+2]              
    mov [si], dx                
    mov [si+2], ax              

OR_NO_SWAP:
    pop si                      
    add si, 2                   
    pop cx                      
    loop OR_COMPARAR_PAR
    
    pop cx                      
    dec ch
    jnz OR_PASADA_PRINCIPAL

    ; NO LLAMAR A RebuildLinkedList - mantener orden original
    ; call RebuildLinkedList    ; <-- COMENTAR O ELIMINAR ESTA LÍNEA

OR_MOSTRAR_ORDENADO:
    ; Mostrar la lista ordenada desde el array (no desde la lista enlazada)
    CALL ClrScreen
    
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
    ; Mostrar titulos
    mov ah, 09h
    lea dx, titulos
    int 21h
    lea dx, newline
    int 21h

    ; Mostrar desde el ARRAY ordenado, no desde headPtr
    lea si, nodeArray           ; Usar el array ordenado
    mov bl, 1                   ; Contador para numeracion
    xor cx, cx                  ; Contador de elementos
    mov cl, cnt

OR_LOOP_MOSTRAR:
    cmp cl, 0
    je OR_FIN_MOSTRAR
    
    mov di, [si]                ; Obtener nodo del array
    
    ; Mostrar numero
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
    push si
    push cx
    add di, NAME_OFF
    mov si, di
    call ImprimirCadena
    pop cx
    pop si
    pop di

    ; Tab
    mov ah, 09h
    lea dx, tab
    int 21h

    ; Mostrar nota
    push di
    push si
    push cx
    add di, NOTE_OFF
    mov si, di
    call ImprimirCadena
    pop cx
    pop si
    pop di

    ; Nueva linea
    mov ah, 09h
    lea dx, newline
    int 21h

    ; Siguiente elemento del array
    add si, 2
    inc bl
    dec cl
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
; Opcion 1: ingreso por linea completa con validaciones
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
