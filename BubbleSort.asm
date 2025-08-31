;-----Referencia del codigo-----
;https://www.youtube.com/playlist?list=PLSmWs9lvUXbB0swTEot_VNq1P_BNhmqhh
;
;-------------------------------
TITLE ORDENAMIENTO_BURBUJA

DATOS SEGMENT
;Declarar variables aqui---------------------------------

 ARRAY_BURBUJA DB 15, 12, 8, 5, 37, 255, 2, 0
 
;--------------------------------------------------------

DATOS ENDS

PILA SEGMENT
    DB 64 DUP(0)

PILA ENDS

CODIGO SEGMENT
    
INICIO PROC FAR


ASSUME DS: DATOS, CS: CODIGO, SS: PILA

PUSH DS

MOV AX, 0

PUSH AX

MOV AX, DATOS
MOV DS, AX
MOV ES, AX

;Codigo del programa---------------------------------------

MOV CX, 7
MOV SI, 0
MOV DI, 0

Ciclo1:
PUSH CX  ;poner en la pila el valor de cx
LEA SI, ARRAY_BURBUJA  ;pasar la direccion efectiva del arreglo a SI
MOV DI, SI   ;y luego pasarla a di

Ciclo2:
INC DI   ;incrementar di para poder comparar con la siguiente posicion
MOV AL, [SI]      ;pasar el valor que se encuentra en al direccion de SI a al
CMP AL, [DI]      ;comparar con el valor que se encuentra en al direccion de di
JA Intercambio    ;salta a la etiqueta si es mayor
JB menor          ; salta a la etiqueta si es menor


Intercambio:
MOV AH, [DI]     ; mueve el valor que se encuentra en di a ah
MOV [DI], AL     ; mueve el valor de al a la posicion de di
MOV [SI], AH     ; pasa e; valor de ah a la posicion de SI



Menor:
INC SI
LOOP Ciclo2
POP CX
LOOP Ciclo1


;----------------------------------------------------------       

EXIT:
RET
INICIO ENDP
CODIGO ENDS

 END INICIO