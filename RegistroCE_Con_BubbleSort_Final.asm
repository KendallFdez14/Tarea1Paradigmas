; -------------------------------
; ORDENAMIENTO DE NOTAS (COPIA TEMPORAL + BUBBLE SORT)
; + REGISTRO DE ESTUDIANTES (compatible EMU8086)
; -------------------------------

.MODEL SMALL
.STACK 100H

.DATA
; Constantes y buffers
estudiante_tam     EQU 30
notas_tam          EQU 10
estudiantesMax     EQU 15

estudianteBuffer  DB estudiante_tam
                  DB ?
                  DB estudiante_tam+2 DUP(0)
notasBuffer       DB notas_tam
                  DB ?
                  DB notas_tam+2 DUP(0)

estudiantesList    DB estudiantesMax * (estudiante_tam+1) DUP('$')
notasList          DB estudiantesMax * (notas_tam+1) DUP('$')

cnt                DB 0

notasenteros_array   DW estudiantesMax DUP(0)
notasdecimales_array DW estudiantesMax * 2 DUP(0)

entero_temp         DW 0
decimal_temp        DW 2 DUP(0)
decimal_encontrado  DB 0

aprobados           DB 0
desaprobados        DB 0

; Buffers temporales (no destructivo)
temp_notasenteros_array    DW estudiantesMax DUP(0)
temp_estudiantesList       DB estudiantesMax * (estudiante_tam+1) DUP('$')
temp_notasList             DB estudiantesMax * (notas_tam+1) DUP('$')

msg_submenu_orden DB 13,10,'Como desea ordenar las calificaciones',13,10
                  DB '1. Asc',13,10,'2. Des',13,10,'$'
msgPresioneTecla  DB 13,10,'Presione cualquier tecla$'
tab               DB 09h, '$'
newline           DB 13,10,'$'

.CODE

; ------- OrdenarNotas --------
OrdenarNotas PROC
    CALL ClrScreen
    ; Mostrar submenú
    MOV AH, 09h
    LEA DX, msg_submenu_orden
    INT 21h
    MOV AH, 01h
    INT 21h
    CMP AL, '1'
    JE Ascendente
    CMP AL, '2'
    JE Descendente
    RET

Ascendente:
    MOV BL, 0
    JMP PrepararOrden
Descendente:
    MOV BL, 1

PrepararOrden:
    ; Copiar datos a buffers temporales
    XOR SI, SI
CopiaNotas:
    MOV AX, [notasenteros_array + SI]
    MOV [temp_notasenteros_array + SI], AX
    ADD SI, 2
    MOV AL, cnt
    CBW
    SHL AX, 1
    CMP SI, AX
    JB CopiaNotas

    ; Copiar nombres
    XOR BX, BX
CopiarNombres:
    MOV AL, cnt
    CBW
    CMP BL, AL
    JGE CopiarNotasTextuales
    PUSH BX
    MOV AX, BX
    MOV CL, estudiante_tam+1
    MUL CL
    MOV SI, AX
    LEA SI, estudiantesList[SI]
    LEA DI, temp_estudiantesList[AX]
    MOV CX, estudiante_tam+1
RepNombre:
    LODSB
    STOSB
    LOOP RepNombre
    POP BX
    INC BX
    JMP CopiarNombres

CopiarNotasTextuales:
    XOR BX, BX
CopiarNotasText:
    MOV AL, cnt
    CBW
    CMP BL, AL
    JGE OrdenarTemp
    PUSH BX
    MOV AX, BX
    MOV CL, notas_tam+1
    MUL CL
    MOV SI, AX
    LEA SI, notasList[SI]
    LEA DI, temp_notasList[AX]
    MOV CX, notas_tam+1
RepNota:
    LODSB
    STOSB
    LOOP RepNota
    POP BX
    INC BX
    JMP CopiarNotasText

; ========== BubbleSort compatible 8086 ============
OrdenarTemp:
    XOR CH, CH
    MOV CL, cnt
    DEC CL
Outer:
    PUSH CX
    XOR SI, SI
Inner:
    MOV AX, [temp_notasenteros_array + SI]
    MOV BX, [temp_notasenteros_array + SI + 2]
    CMP BL, 0
    JE AscCmp
    CMP AX, BX
    JL NoSwap
    JMP DoSwap
AscCmp:
    CMP AX, BX
    JG DoSwap
    JMP NoSwap
DoSwap:
    ; Swap notas
    MOV [temp_notasenteros_array + SI], BX
    MOV [temp_notasenteros_array + SI + 2], AX
    ; Aquí iría el intercambio de nombres y notas si fuera necesario
NoSwap:
    ADD SI, 2
    LOOP Inner
    POP CX
    LOOP Outer

    ; Mostrar ordenado
    CALL ClrScreen
    XOR BX, BX
PrintLoop:
    MOV AL, cnt
    CBW
    CMP BL, AL
    JGE FinOrdenar
    ; Mostrar nombre
    MOV AX, BX
    MOV CX, estudiante_tam+1
    MUL CX
    LEA SI, temp_estudiantesList[AX]
    CALL ImprimirCadena
    ; Tab
    MOV AH, 09h
    LEA DX, tab
    INT 21h
    ; Mostrar nota
    MOV AX, BX
    MOV CX, notas_tam+1
    MUL CX
    LEA SI, temp_notasList[AX]
    CALL ImprimirCadena
    ; Salto
    MOV AH, 09h
    LEA DX, newline
    INT 21h
    INC BX
    JMP PrintLoop

FinOrdenar:
    MOV AH, 09h
    LEA DX, msgPresioneTecla
    INT 21h
    MOV AH, 01h
    INT 21h
    RET
OrdenarNotas ENDP

END
