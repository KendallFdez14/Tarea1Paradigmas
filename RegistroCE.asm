.model small
.stack 100h ;define la pila de datos

.data ;reserva el espacio de memoria para las variables
mensaje_bienvenida db 13,10, "Bienvenidos/as a Registro CE $" ;db es el tipo de variable, define bit
mensaje_digitar    db 13,10, "Digite: $"  ;$ termina la oracion
mensaje_menu1      db 13,10, "1. Ingresar calificaciones (hasta 15 estudiantes -Nombre Apellido1 Apellido2 Nota-).$"
mensaje_menu2      db 13,10, "2. Mostrar estadisticas.$"
mensaje_menu3      db 13,10, "3. Buscar estudiante por posicion (indice).$"
mensaje_menu4      db 13,10, "4. Ordenar calificaciones (ascendente/descendente).$"
mensaje_menu5      db 13,10, "5. Salir.$"
mensaje_opcion     db 13,10, "Opcion: $"
mensaje_ingresoDatos db 13,10, "Por favor ingrese su estudiante o digite 9 para salir al menu principal$"
mensaje_preguntaEstudianteInteresado db 13, 10, "Que estudiante desea mostrar?$"
mensaje_invalida   db 13,10, "Opcion invalida. Intente de nuevo.$"
mensaje_despedida  db 13,10, "Gracias por usar Registro CE.$"       

opcion_usuario db ? ;guarda la opcion elegida por el usuario

.code
inicio:
    mov ax, @data;regresa la informacion a pantalla o para entrar o salir
    mov ds, ax  ; son las variables registradas en Ensamblador, segmento a una constante x

ciclo_principal:
    ; Mostrar menu
    lea dx, mensaje_bienvenida; ubica la direccion del dato*
    mov ah, 09h             ;lo que hace 9h es imprimir el dato
    int 21h                 ;interrumpe el programa

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
                    
    ;lee la opcion del usuario                
    ;Lee una tecla (con eco). Devuelve ASCII en AL
    mov ah, 01h
    int 21h
            
    mov opcion_usuario, al
    
    ;Compara directamente contra ASCII, se podria cambiar a numero, pero compara caracter contra caracter
    cmp al, '1'
    je  opcion1
    cmp al, '2'
    je  opcion2
    cmp al, '3'
    je  opcion3
    cmp al, '4'
    je  opcion4
    cmp al, '5'
    je  salir

    ;Cualquier otra tecla => invalida y volver al menu
    lea dx, mensaje_invalida
    mov ah, 09h
    int 21h
    jmp ciclo_principal

opcion1:
    lea dx, mensaje_ingresoDatos
    mov ah, 09h
    int 21h
    
    jmp ciclo_principal

opcion2:
    
    jmp ciclo_principal

opcion3:
    lea dx, mensaje_preguntaEstudianteInteresado
    mov ah, 09h
    int 21h
    jmp ciclo_principal

opcion4:
    
    jmp ciclo_principal

salir:
    lea dx, mensaje_despedida
    mov ah, 09h
    int 21h
    mov ax, 4C00h
    int 21h

end inicio

















