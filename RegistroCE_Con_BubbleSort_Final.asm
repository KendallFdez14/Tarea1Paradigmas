; ============================================================
; Registro CE - Lista Enlazada + Bubble Sort (ASC/DESC)
; Flujo según .txt: ingreso en bucle y '9' para volver
; SIN ESTADÍSTICAS (opción 2 -> Mostrar lista)
; EMU8086 / 8086/88
; CORREGIDO: Lista enlazada con reconstrucción de punteros
; ============================================================

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
                            DB '1. Asc',13,10,'2. Des',13,10,'$' 
orderMode DB 0              ; '1' asc, '2' des

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
    xor bh, bh                     ; *** importante: BH=0 para usar BX como desplazamiento
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
; Parseo de nota ASCII a (entero, decimos escalados a 5 digitos)
; Guarda en nodo: [DI]=gInt, [DI+2]=gDecLo, [DI+4]=gDecHi
; ENTRADA: SI -> cadena de nota '$'-terminada
;          DI -> destino gInt
; ------------------------------------------------------------
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
    ; sumar digito (en BL) asegurando BH=0
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
; Construir array de punteros desde la lista enlazada
; ============================================================
BuildNodeArray PROC
    push ax
    push bx
    push di
    push si

    mov di, headPtr
    mov si, offset nodeArray
    xor bl, bl

BNA_Loop:
    cmp di, NULL_PTR
    je BNA_End
    cmp bl, cnt
    jae BNA_End

    ; Guardar puntero en array
    mov [si], di
    add si, 2
    
    ; Siguiente nodo
    mov di, [di+NEXT_OFF]
    inc bl
    jmp BNA_Loop

BNA_End:
    pop si
    pop di
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
; Mostrar lista completa
; ------------------------------------------------------------
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

; ============================================================
; Buscar por posicion (1..cnt)  (entrada de un solo digito)
; ------------------------------------------------------------
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

    mov ah, 01h
    int 21h
    cmp al, '1'
    jb Inval
    sub al, '0'
    mov bl, cnt
    cmp al, bl
    ja Inval

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

    mov ah, 02h
    mov dl, al
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

; ------------------------------------------------------------
; Opcion 1: ingreso por línea completa o '9' para volver
; ------------------------------------------------------------
Opcion1:
    CALL ClrScreen
IngresarLoop:
    mov ah, 09h
    lea dx, prompt_linea
    int 21h

    mov ah, 0Ah
    lea dx, lineBuffer
    int 21h

    lea dx, lineBuffer
    call TerminarCadena0Ah

    mov si, offset lineBuffer
    mov bl, [si+1]
    cmp bl, 1
    jne NoSalir9
    mov al, [si+2]
    cmp al, '9'
    je  FinOpcion1
NoSalir9:

    lea si, [si+2]
    call ParseLineaNombreNota
    jc  IngresarLoop

    call AgregarDesdeBuffers
    jmp IngresarLoop

FinOpcion1:
    jmp MainMenu

; ------------------------------------------------------------
; ParseLineaNombreNota (separa nombre y nota)
; ------------------------------------------------------------
ParseLineaNombreNota PROC
    push ax
    push bx
    push cx
    push dx
    push di

    mov di, si
PL_FindEnd:
    mov al, [di]
    cmp al, '$'
    je  PL_HaveEnd
    inc di
    jmp PL_FindEnd

PL_HaveEnd:
    dec di

PL_TrimEnd:
    cmp di, si
    jb  PL_Fail
    mov al, [di]
    cmp al, ' '
    jne PL_FindSplit
    dec di
    jmp PL_TrimEnd

PL_FindSplit:
    mov bx, di
PL_FindSpaceBack:
    cmp bx, si
    jbe PL_Fail
    mov al, [bx]
    cmp al, ' '
    je  PL_SplitFound
    dec bx
    jmp PL_FindSpaceBack

PL_SplitFound:
    mov dx, bx
    inc bx

PL_TrimNoteStart:
    mov al, [bx]
    cmp al, ' '
    jne PL_NoteStartOK
    inc bx
    jmp PL_TrimNoteStart

PL_NoteStartOK:
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

    mov bx, dx
    dec bx

PL_TrimNameEnd:
    cmp bx, si
    jb  PL_Fail
    mov al, [bx]
    cmp al, ' '
    jne PL_NameEndOK
    dec bx
    jmp PL_TrimNameEnd

PL_NameEndOK:
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

    clc
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

PL_Fail:
    stc
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
ParseLineaNombreNota ENDP

; ------------------------------------------------------------
; AgregarDesdeBuffers: usa estudianteBuffer/notasBuffer
; ------------------------------------------------------------
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

    ; === CORRECCIÓN: Pasar parámetros correctos a ParseAsciiGradeToNode ===
    lea si, notasBuffer+2      ; SI apunta a la cadena de la nota
    mov di, bx
    add di, GINT_OFF           ; DI apunta a donde guardar el valor numérico
    call ParseAsciiGradeToNode
    ; =====================================================================

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
; SwapNodeData: intercambio en bloque (48 bytes) sin tocar NEXT
; ENTRADA: DI = base nodo A, SI = base nodo B
; ============================================================
SwapNodeData PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov bx, di         ; BX = A
    mov dx, si         ; DX = B

    ; A -> swap_block
    mov si, bx
    add si, NAME_OFF
    mov di, offset swap_block
    mov cx, TEMP_BLOCK_LEN
    cld
    rep movsb

    ; B -> A
    mov si, dx
    add si, NAME_OFF
    mov di, bx
    add di, NAME_OFF
    mov cx, TEMP_BLOCK_LEN
    cld
    rep movsb

    ; swap_block -> B
    mov si, offset swap_block
    mov di, dx
    add di, NAME_OFF
    mov cx, TEMP_BLOCK_LEN
    cld
    rep movsb

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
SwapNodeData ENDP

; ============================================================
; CompareGrades: Compara dos notas completas (valores numéricos)
; ENTRADA: SI = nodo A, DI = nodo B  
; SALIDA:  CF = 1 si A < B, CF = 0 si A >= B
; ============================================================
CompareGrades PROC
    push ax
    push bx
    push dx
    
    ; Comparar parte entera
    mov ax, [si + GINT_OFF]   ; entero del nodo A
    mov bx, [di + GINT_OFF]   ; entero del nodo B
    cmp ax, bx
    ja  CG_A_GREATER          ; A > B
    jb  CG_A_LESS             ; A < B
    
    ; Si son iguales, comparar parte decimal (alta)
    mov ax, [si + GDHI_OFF]   ; decimal alto de A
    mov bx, [di + GDHI_OFF]   ; decimal alto de B
    cmp ax, bx
    ja  CG_A_GREATER
    jb  CG_A_LESS
    
    ; Si aún son iguales, comparar parte decimal (baja)
    mov ax, [si + GDLO_OFF]   ; decimal bajo de A
    mov bx, [di + GDLO_OFF]   ; decimal bajo de B
    cmp ax, bx
    ja  CG_A_GREATER
    jb  CG_A_LESS
    
    ; Son iguales
    clc                       ; CF = 0 (A >= B)
    jmp CG_END

CG_A_LESS:
    stc                       ; CF = 1 (A < B)
    jmp CG_END
    
CG_A_GREATER:
    clc                       ; CF = 0 (A >= B)
    
CG_END:
    pop dx
    pop bx
    pop ax
    ret
CompareGrades ENDP

; ============================================================
; Ordenar (Bubble Sort) ASC/DESC - CORREGIDO: Comparación simplificada
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
    mov ah, 09h
    lea dx, mensaje_ordenar
    int 21h

    mov ah, 01h
    int 21h
    mov orderMode, al          ; '1' = ASC, '2' = DES

    cmp orderMode, '1'
    je  OR_OK
    cmp orderMode, '2'
    je  OR_OK
    jmp OR_DONE

OR_OK:
    mov al, cnt
    cmp al, 2
    jb  OR_SHOW

    ; Construir array de punteros
    call BuildNodeArray

    mov ch, cnt
    dec ch                     ; pasadas = cnt-1

OR_PASS:
    cmp ch, 0
    je  OR_REBUILD

    mov cl, cnt
    dec cl                     ; pares = cnt-1

    mov bp, offset nodeArray   ; BP = inicio del array

OR_INNER:
    cmp cl, 0
    je  OR_NEXT_PASS

    mov si, [bp]               ; nodo A
    mov di, [bp+2]             ; nodo B

    ; Comparación completa de notas (entero.decimal)
    call CompareGrades         ; CF=1 si A < B

    cmp orderMode, '1'         ; '1' = ASC
    je  OR_ASC_LOGIC

    ; DESC: Intercambiar si A < B (CF = 1)
    jc OR_SWAP
    jmp OR_ADV

OR_ASC_LOGIC:
    ; ASC: Intercambiar si A > B (CF = 0)
    jnc OR_SWAP
    jmp OR_ADV

OR_SWAP:
    ; Intercambiar punteros en el array
    mov ax, [bp]
    mov bx, [bp+2]
    mov [bp], bx
    mov [bp+2], ax

OR_ADV:
    add bp, 2
    dec cl
    jmp OR_INNER

OR_NEXT_PASS:
    dec ch
    jmp OR_PASS

OR_REBUILD:
    ; Reconstruir lista enlazada con el nuevo orden
    call RebuildLinkedList

OR_SHOW:
    call MostrarListaCompleta

OR_DONE:
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
; Opcion2/3/4/5
; ------------------------------------------------------------
Opcion2:                    ; Mostrar lista completa
    CALL MostrarListaCompleta
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

; ============================================================
; FIN
; ============================================================
END START