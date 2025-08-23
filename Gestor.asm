.model small ;define el tipo de memoria que se va a utilizar 64KB
.stack ;define la plia de datos
.data ;aqui se definen las variables y mensajes
      mensaje_bienvenida db 13, 10, "Bienvenidos/as a Registro CE $" ;db=define byte: guarda cada letra como un byte ASCII 
      mensaje_digitar db 13, 10,"Digite: $" ;$ indica donde termina la linea importante para la funcion 09h  
      mensaje_menu1 db 13, 10,"1. Ingresar calificaciones (hasta 15 estudiantes -Nombre Apellido1 Apellido2 Nota-).$"
      mensaje_menu2 db 13, 10,"2. Mostrar esdisticas.$"
      mensaje_menu3 db 13, 10,"3. Buscar estudiante por posicion (indice).$"  
      mensaje_menu4 db 13, 10,"4. Ordenar calificaciones (ascendente/descendente).$"
      mensaje_menu5 db 13, 10,"5. Salir.$"
      opcion_escogida db 0 ;se guarda la opcion escogida
      
      
      
.code
    inicio:
        mov ax, @data ;es la direccion del segmento de datos, coloca la direccion del @data en ax
        mov ds, ax;carga el registro ds con la direccion, asi se pueden utilizar las variables declaradas en .data 
        
        lea dx, mensaje_bienvenida; carga en dx la direccion en memoria donde empieza la cadena de texto
        mov ah, 9h; imprime el mensaje
        int 21h;detiene el programa 
        
        lea dx, mensaje_digitar; carga en dx la direccion en memoria donde empieza la cadena de texto
        mov ah, 9h; imprime el mensaje
        int 21h;detiene el programa 
     
     menu:
        ; Muestra las 5 opciones del menu  
        
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
        

        
        
     end inicio 