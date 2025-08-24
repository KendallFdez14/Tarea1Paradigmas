.model small; le dice al ensamblador que se va a usar un programa pequeno (segmento de datos y codigo de 64KB)
.stack 100h; se va a usar una pila (stack) de 256 bytes para guardar cosas temporales

.data ; aqui se definen las variables y mensajes
    ;Textos
    mensaje_bienvenida db 13,10,"Bienvenidos/as a Registro CE $";db=define byte: guarda cada letra como un byte ASCII 
    mensaje_digitar db 13,10,"Digite: $"  ;$ indica donde termina la linea importante para la funcion 09h
    mensaje_menu1 db 13,10,"1. Ingresar calificaciones (hasta 15 estudiantes -Nombre Apellido1 Apellido2 Nota-)$"
    mensaje_menu2 db 13,10,"2. Mostrar estadisticas$"
    mensaje_menu3 db 13,10,"3. Buscar estudiante por posicion (indice)$"
    mensaje_menu4 db 13,10,"4. Ordenar calificaciones (ascendente/descendente) $"
    mensaje_menu5 db 13,10,"5. Salir.$"
    mensaje_error db 13,10,"Opcion invalida. Intenta con otra opcion$"
    mensaje_ingreso_estudiante db 13,10,"Por favor ingrese su estudiante o digite 9 para salir al menu principal: $"
    mensaje_maximoIngreso db 13,10,"Se alcanzo el maximo de 15 estudiantes$"
    mensaje_despedidaPrograma db 13,10,"Gracias por usar Registro CE$"

    ; Variables 
    opcion_escogida db 0            ;se guarda la opcion escogida
    num_estudiantes db 0           ; Cuántos estudiantes se han ingresado (hasta 15)

    ;Se utiliza el buffer para guardar los datos ingresados en memoria
    entrada_buffer db 60           ; es el maximo numero de caracteres que puede recibir
                     db ?          ; el sistema guarda la cantidad de datos que se guardaron
                     db 60 dup(?)  ; Se guarda lo que el usuario escribe (nombre y nota)

    ; guarda los datos que ingrese el usuario
    nombres db 15 dup(60 dup(?))   ; Esto crea espacio para 15 nombres, cada uno de 60 caracteres
    notas dw 15 dup(?)             ; Esto guarda 15 notas 

.code
inicio:
    mov ax, @data      ; se cargan todas las variables en los registros
    mov ds, ax         ; se coloca esa direccion en el registro DS (segmento de datos). Constantes definidas

; Muestra los mensajes de bienvenida y digitar
mostrar_menu:
    lea dx, mensaje_bienvenida
    mov ah, 9
    int 21h

    lea dx, mensaje_digitar
    mov ah, 9
    int 21h

; Menu principal
menu:
    ;Se muestran todas las opciones disponibles
    lea dx, mensaje_menu1
    mov ah, 9
    int 21h

    lea dx, mensaje_menu2
    mov ah, 9
    int 21h

    lea dx, mensaje_menu3
    mov ah, 9
    int 21h

    lea dx, mensaje_menu4
    mov ah, 9
    int 21h

    lea dx, mensaje_menu5
    mov ah, 9
    int 21h

    ;Se lee la variable escogida por el usuario
    mov ah, 1
    int 21h
    sub al, '0'                 ; se convierte el caracter "9" en un numero 9
    mov opcion_escogida, al     ; se sobreescribe el numero en esa direccion

    ;Dependiendo de la opcion escogida se realiza el salto a la direccion especificada dependiendo de cual cumple (escogida)
    cmp al, 1
    je opcion1

    cmp al, 2
    je opcion2

    cmp al, 3
    je opcion3

    cmp al, 4
    je opcion4

    cmp al, 5
    je salir

    ; Si no escoge una opcion valida o ya definida se muestra un mensaje de error
    lea dx, mensaje_error
    mov ah, 9
    int 21h
    jmp menu

;Ingresar calificaciones
opcion1:
    mov al, num_estudiantes ;carga en AL la cantidad actual de estudiantes registrados
    cmp al, 15            ;compara si ya hay 15 estudiantes
    jae maximoIngreso     ; Si AL es mayor o igual a 15, salta el mensaje del tope de estudiantes
    jmp ingreso_ciclo     ; Si no, salta al ciclo para continuar ingresando estudiantes

maximoIngreso:
    lea dx, mensaje_maximoIngreso; carga la direccion del mensaje de limite alcanzado en dx
    mov ah, 9                  ; funcion 09h de interrupcion para 21h para imprimir la cadena de texto
    int 21h                    ;muestra el mensaje en pantalla
    jmp menu                   ;salta al menu principal
                                                                     
ingreso_ciclo:
    ;Mensaje para que escriban el estudiante
    lea dx, mensaje_ingreso_estudiante
    mov ah, 9                          ;funcion 09h para mostrar la cadena
    int 21h                            ; muestra el mensaje

    ; Se obtiene lo que escribe el usuario
    lea dx, entrada_buffer             ;carga la direccion del buffer de entrada
    mov ah, 0Ah                        ;funcion 0Ah para leer una cadena con buffer***
    int 21h                            ;espera a que el usuario escriba y presione la tecla enter

    ;Se verifica si quiere volver al menu principal
    mov al, entrada_buffer+2       ;carga el primer caracter del texto ingresado
    cmp al, '9'                    ;compara si fue un 9 para salir
    je volverMenu                  ;si lo anterior era true entonces regresa al menu

    ; Guarda el nombre en memoria
    ; Calculamos el lugar donde guardar el nombre
    mov bl, num_estudiantes     ;bl: indice del estudiante actual
    xor bh, bh                  ;limpia bh para usar bx correctamente de 16bits
    mov ax, bx                   ;ax: numero de estudiantes
    mov bx, 60                    ;cada nombre ocupa 60bytes
    mul bx                      ; ax=ax*60, es un offset dentro del arreglo nombres[]
    mov si, offset entrada_buffer + 2; SI apunta al inicio del nombre ingresado
    mov di, offset nombres      ;di apunta a la posicion del estudiante actual
    add di, ax                  ; DI ahora apunta a la posición correcta del estudiante

    mov ax, ds                  ; ax tiene el segmento de datos
    mov es, ax                  ; Copia ds a es, se debe usar STOSB con es:di***

    mov cx, 60                  ; se copian maximo 60 caracteres del nombre
copiar_nombre:
    lodsb                       ;carga el byte de ds:si en AL aumenta SI
    cmp al, ' '                 ;si encuentra espacio, se asume que encuentra una nota***
    je fin_copia                ;fin de la copia del nombre***
    cmp al, 13                  ;si presiona enter fin de la instruccion
    je fin_copia                
    stosb                       ;guarda AL en es:di y aumenta di
    loop copiar_nombre          ;repite cx hasta que llegue a 0 o haya un espacio o enter***
fin_copia:

    ;Guarda la nota 
    call parsear_nota ;convierte la nota a un numero entero

   
    inc num_estudiantes  ;aumenta el contador de estudiantes

    ; Si no se ha llegado al tope, seguir ingresando
    mov al, num_estudiantes;carga la cantidad en AL
    cmp al, 15            ;verifica si ya hay 15 estudiantes o no
    jb ingreso_ciclo      ;muestra un mensaje de tope

    ; Si llegamos al tope, mostramos mensaje
    jmp maximoIngreso
 ;Guarda todos los registros que se van a usar
parsear_nota:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Buscamos la parte final del texto para encontrar la nota
    mov cl, entrada_buffer + 1  ;cl: longitud del texto ingresado
    xor ch, ch               ;borra la parte alta del registro*** 
    mov si, cx               ; SI es la longitud
    add si, 1                ;SI ahora apunta al final del texto

buscar_espacio:
    dec si                        ;retrocede un caracter
    cmp entrada_buffer+2[si], ' ' ;pregunta si es un espacio
    jne buscar_espacio            ;si no sigue retrocediendo
    inc si                        ;apunta al primer digito de la nota

    ; Inicializamos los contadores
    xor bx, bx                    ;bx guarda la parte entera
    xor dx, dx                    ;dx guarda la parte decimal
    xor di, di                    ;di es el contador de decimales

parsear_entero:
    mov al, entrada_buffer+2[si]  ;al es el caracter actual
    cmp al, '.'                   ;si es un punto see pasa a los decimales
    je convertir_decimales
    cmp al, 13                    ;verifica el enter
    je combinar_partes
    cmp al, '0'                   ;convierte el ASCII a un numero
    jb combinar_partes
    cmp al, '9'
    ja combinar_partes
    sub al, '0'
    mov ah, 0
    mov cx, 10
    mul cx                        ;al=al*10
    add bx, ax                    ;acumular en bx
    inc si                        ;continua al siguiente caracter
    jmp parsear_entero

convertir_decimales:
    inc si
    xor cx, cx
    mov dx, 0

convertir_decimal_loop:
    cmp cx, 5                 ;Maximo 5 decimales
    je combinar_partes
    mov al, entrada_buffer+2[si]
    cmp al, 13
    je combinar_partes
    cmp al, '0'
    jb combinar_partes
    cmp al, '9'
    ja combinar_partes
    sub al, '0'
    mov ah, 0
    mov di, 10
    mul di
    add dx, ax
    inc si
    inc cx
    jmp convertir_decimal_loop

combinar_partes:
    ; Si faltan decimales, se agregan ceros***
    mov di, 5
    sub di, cx    ;cantidad de ceros que faltan

agregar_ceros:
    cmp di, 0
    je multiplicar
    mov cx, 10
    mul cx
    dec di
    jmp agregar_ceros

multiplicar:
    mov ax, bx
    mov cx, 10000
    mul cx               ; ax = parte_entera * 10000
    mov cx, 10           ; ax = parte_entera * 100000
    mul cx
    add ax, dx            ; Sumarle la parte decimal

    ; Se guardan en un arreglo las notas[]
    mov bl, num_estudiantes
    dec bl
    xor bh, bh
    mov cx, 2
    mul cx              ;ax=indice*2, cada nota necesita 2 bytes   
    mov si, offset notas
    add si, ax
    mov [si], ax       ;guarda la nota en memoria

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret               ;retorna la funcion

volverMenu:
    jmp menu


opcion2:
    jmp menu

opcion3:
    jmp menu

opcion4:
    jmp menu

; --- Salida del programa ---
salir:
    lea dx, mensaje_despedidaPrograma
    mov ah, 9
    int 21h
    mov ah, 4Ch
    int 21h

end inicio




