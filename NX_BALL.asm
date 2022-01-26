.586
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc
extern printf: proc
extern fopen: proc
extern fclose: proc
extern fread: proc
extern fgets: proc
extern fscanf: proc
extern fopen: proc
extern freopen: proc
extern fseek: proc
extern srand: proc
extern rand: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "NX-BALL",0
area_width EQU 640
area_height EQU 480
draw_area DD 0
virtual_draw_area DD 0

counter DD 0 ; numara evenimentele de tip timer

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20
arg5 EQU 24
arg6 EQU 28
arg7 EQU 32
arg8 EQU 36
arg9 EQU 40
arg10 EQU 44

symbol_width EQU 10
symbol_height EQU 20

include picture.inc
include digits.inc
include letters.inc
include assets.inc

;colors
color_red EQU 0FF0000h  	;minge
color_green EQU 0FF00h  	;placi distructibile
color_blue EQU 0FFh			;placa de jos
color_purple EQU 0FF00FFh 	;play/pause
color_cyan EQU 0FFFFh		;retry
color_nqb EQU 10101h		;not quite black (invisible border)
color_yellow EQU 0FFFF00h	;just yellow
color_black EQU 0
color_white EQU 0FFFFFFh

minus DD -1

b_x DD 320
b_y DD 454
b_old_x DD 0
b_old_y DD 0
b_r DD 10
b_color EQU color_red
b_speed_x DD 5
b_speed_y DD -5
b_speed_x_store DD 0
b_speed_y_store DD 0
magnitudine_before_sq DD 50.0

p_x DD 320
p_y DD 475
p_old_x DD 0
p_old_y DD 0
p_w DD 100
p_old_w DD 100
p_h DD 10
p_color EQU color_blue
collided_plate DB 0
small_magic_number EQU 6
normal_magic_number EQU 9
large_magic_number EQU 16

seed DD 1
format_dd DB "%d", 0
format_db DB "%c", 0
format_s DB "%s", 0
newline DB 13, 10, 0
file_mode_rb DB "rb", 0
file_mode_r DB "r", 0
file_p DD 0
file_aux DD 0
file_aux_str DB 3 dup(0)
asset_w DD 0
asset_h DD 0
file_offset DD 0

state DB 1
death DB 0
destroy DB 0

mesaj_game_over DB "GAME OVER", 0
mesaj_retry DB "SPACE TO RETRY", 0
mesaj_scor DB "SCOR", 0
mesaj_win DB "YOU WIN", 0

ball_filename DB "ball.pbm", 0
block_filename DB "block.pbm", 0
upper_filename DB "upper_bar.pbm", 0
play_filename DB "play.pbm", 0
retry_filename DB "retry.pbm", 0

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
; arg5 - color
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_next
	push esi
	mov esi, [ebp + arg5]
	mov dword ptr [edi], esi
	pop esi
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp
; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, dArea, x, y, color
	push color
	push y
	push x
	push dArea
	push symbol
	call make_text
	add esp, 20
endm



;procedura care scrie pe ecran caracterele din string-ul selectat, la pozitia si cu culoarea data
;arg1 = x, arg2 = y, arg3 = offset(string), arg4 = dArea, arg5 = color
make_string proc 
	push ebp
	mov ebp, esp
	pusha
	
	mov esi, [ebp + arg3] ;textul de afisat
	mov eax, [ebp + arg1]
bucla_afisare_string:
	cmp byte ptr[esi], 0
	je final_afisare
	movzx ebx, byte ptr[esi]
	make_text_macro ebx, [ebp + arg4], eax, [ebp + arg2], [ebp + arg5]
	add esi, 1
	add eax, 10
	jmp bucla_afisare_string
final_afisare:	
	popa
	mov esp, ebp
	pop ebp
	ret 20
make_string endp

;wrapper pentru procedura de mai sus
m_make_string macro x, y, offset_str, dArea, color
	push color
	push dArea
	push offset_str
	push y
	push x
	call make_string
endm



;procedura primeste x, y si adresa de desenare si returneaza in eax adresa calculata
;arg1 = x, arg2 = y, arg3 = dArea
calculate_position proc 
	push ebp
	mov ebp, esp
	push ebx
	
	mov eax, [ebp + arg3]
	cmp eax, 0
	je skip
	
	mov eax, [ebp + arg1]
	cmp eax, area_width
	jge skip
	cmp eax, 0
	jl skip
	
	mov eax, [ebp + arg2]
	cmp eax, area_height
	jge skip
	cmp eax, 0
	jl skip
	
	mov eax, [ebp + arg2] ;(y * area_width + x) * 4
	mov ebx, area_width
	mul ebx
	add eax, [ebp + arg1]
	
	shl eax, 2
	add eax, [ebp + arg3]
	jmp finish

skip:
	mov eax, minus
finish:	
	pop ebx
	mov esp, ebp
	pop ebp
	ret 12
calculate_position endp

;wrapper pentru procedura de mai sus
m_calculate_position macro x, y, dArea
	push dArea
	push y
	push x
	call calculate_position
endm



;procedura make_pixel creeaza un pixel de o culoare data la o coordonata data, pe o fereastra data
;arg1 = x, arg2 = y, arg3 = dArea, arg4 = color
make_pixel proc
	push ebp
	mov ebp, esp
	pusha
	
	m_calculate_position [ebp + arg1], [ebp + arg2], [ebp + arg3]
	cmp eax, minus
	je skip
	mov ecx, [ebp + arg4]
	cmp ecx, color_white
	ja skip
	mov dword ptr[eax], ecx

skip:	
	popa
	mov esp, ebp
	pop ebp
	ret 16
make_pixel endp

;wrapper pentru procedura de mai sus
m_make_pixel macro x, y, dArea, color
	push color
	push dArea
	push y
	push x
	call make_pixel
endm



;procedura care incarca orice asset cu numele file_name in format ppm si-l afiseaza pe ecran 
;la o coordonata data (din coltul stanga-sus sau din centru, selectabil
;arg1 = x, arg2 = y, arg3 = offset(asset_name), arg4 = dArea, arg5 = mode (0 = stanga-sus, 1 = centru)
make_asset proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp + arg3]
	push offset file_mode_r
	push eax
	call fopen
	add esp, 8
	mov file_p, eax
	
	;citim P6 cu enter
	mov ebx, 3 ;cati bytes
	push file_p
	push ebx
	push offset file_aux_str
	call fgets
	add esp, 12
		
	push offset asset_w
	push offset format_dd
	push file_p
	call fscanf
	add esp, 12
	
	push offset asset_h
	push offset format_dd
	push file_p
	call fscanf
	add esp, 12
	
	mov eax, [ebp + arg3]
	push file_p
	push offset file_mode_rb
	push eax
	call freopen
	add esp, 12
	
	; push file_p
	; call rewind
	; add esp, 4
	
	cmp file_offset, 0
	ja seek_file
	
	mov ecx, 0
	mov edx, 0
bucla_citire_header:
	push ecx
	push edx
	mov eax, 1
	push file_p
	push eax
	push eax
	push offset file_aux
	call fread
	add esp, 16
	pop edx
	pop ecx
	cmp file_aux, 0Ah
	jne skip_increment_enters
	inc ecx
skip_increment_enters:
	inc edx
	cmp ecx, 4
	jb bucla_citire_header
	mov file_offset, edx
	jmp preset_bucla
seek_file:
	mov eax, 0
	push eax
	push file_offset
	push file_p
	call fseek
	add esp, 12
preset_bucla:
	mov esi, 0
bucla_asset_h:
	mov edi, 0
	bucla_asset_w:
		;rgb
		mov eax, 1 ;cate grupuri
		mov ebx, 3 ;cati bytes
		push file_p
		push eax
		push ebx
		push offset file_aux
		call fread
		add esp, 16
		mov ebx, file_aux
		xchg bh, bl
		mov eax, ebx
		shr eax, 16
		shl ebx, 16
		shr ebx, 8
		mov bl, al
		
		cmp ebx, 151515h
		je skip_asset_pixel
		push esi
		push edi
		add esi, [ebp + arg2]
		add edi, [ebp + arg1]
		cmp dword ptr[ebp + arg5], 0
		je make_asset_pixel
		mov eax, asset_h
		shr eax, 1
		mov ecx, asset_w
		shr ecx, 1
		sub esi, eax
		sub edi, ecx
	make_asset_pixel:
		m_make_pixel edi, esi, [ebp + arg4], ebx
		pop edi
		pop esi
	skip_asset_pixel:
		inc edi
		cmp edi, asset_w
		jb bucla_asset_w
	inc esi
	cmp esi, asset_h
	jb bucla_asset_h
	
	push file_p
	call fclose
	add esp, 4
	
	popa
	mov esp, ebp
	pop ebp
	ret 20
make_asset endp

;wrapper pentru functia de mai sus
m_make_asset macro x, y, offset_filename, dArea, mode
	push mode
	push dArea
	push offset_filename
	push y
	push x
	call make_asset
endm



;procedura make_rectangle creeaza un dreptunghi de o latime/lungime data, de o culoare data 
;care are coltul de stanga-sus la o coordonata data, pe o fereastra data
;arg1 = x, arg2 = y, arg3 = w, arg4 = h, arg5 = dArea, arg6 = color
make_rectangle proc 
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp + arg1]
	mov ebx, [ebp + arg2]
	mov ecx, [ebp + arg3]
	add ecx, eax
	mov edx, [ebp + arg4]
	add edx, ebx
	
	cmp eax, ecx
	jge skip
	cmp ebx, edx
	jge skip
	
height_loop:
	width_loop:
		m_make_pixel eax, ebx, [ebp + arg5], [ebp + arg6]
		inc eax
		cmp eax, ecx
		jne width_loop
	mov eax, [ebp + arg1]
	inc ebx
	cmp ebx, edx
	jne height_loop
	
skip:
	popa
	mov esp, ebp
	pop ebp
	ret 24
make_rectangle endp

;wrapper pentru procedura de mai sus
m_make_rectangle macro x, y, w, h, dArea, color
	push color
	push dArea
	push h
	push w
	push y
	push x
	call make_rectangle
endm

;wrapper pentru procedura de mai sus, care creeaza un dreptunghi cu centrul la coordonatele date
m_make_rectangle_center macro x, y, w, h, dArea, color
	pusha
	push color
	push dArea
	push h
	push w
	mov eax, y
	mov ebx, h
	shr ebx, 1
	sub eax, ebx
	push eax
	mov eax, x
	mov ebx, w
	shr ebx, 1
	sub eax, ebx
	push eax
	call make_rectangle
	popa
endm



;procedura care deseneaza mingea (desi e patrata) stergand mingea veche si desenand mingea noua
;arg1 = x, arg2 = y, arg3 = old_x, arg4 = old_y, arg5 = r, arg6 = dArea, arg7 = color, arg8 = vdArea
make_ball proc 
	push ebp
	mov ebp, esp
	pusha
	
	mov ecx, [ebp + arg5]
	shl ecx, 1
	inc ecx
	m_make_rectangle_center [ebp + arg3], [ebp + arg4], ecx, ecx, [ebp + arg8], color_black
	m_make_rectangle_center [ebp + arg1], [ebp + arg2], ecx, ecx, [ebp + arg8], [ebp + arg7]
	m_make_rectangle_center [ebp + arg3], [ebp + arg4], ecx, ecx, [ebp + arg6], color_black
	m_make_asset [ebp + arg1], [ebp + arg2], offset ball_filename, [ebp + arg6], 1
	popa
	mov esp, ebp
	pop ebp
	ret 32
make_ball endp

;wrapper pentru procedura de mai sus
m_make_ball macro x, y, old_x, old_y, r, dArea, color, vdArea
	push vdArea
	push color
	push dArea
	push r
	push old_y
	push old_x
	push y
	push x
	call make_ball
endm



;macro care deseneaza placa de jos, prin stergerea placii vechi si desenarea celei noi
m_make_plate macro x, y, old_x, old_y, w, h, old_w, dArea, color, vdArea
	m_make_rectangle_center old_x, old_y, old_w, h, dArea, color_black
	m_make_rectangle_center x, y, w, h, dArea, color
	m_make_rectangle_center old_x, old_y, old_w, h, vdArea, color_black
	m_make_rectangle_center x, y, w, h, vdArea, color
	push eax
	mov eax, x
	mov old_x, eax
	mov eax, y
	mov old_y, eax
	mov eax, w
	mov old_w, eax
	pop eax
endm



;macro care deseneaza blocurile de distrus, dintr-o lista data in assets.inc
;arg1 = block_list, arg2 = dArea, arg3 = color, arg4 = vdArea
make_blocks proc 
	push ebp
	mov ebp, esp
	pusha
	
	mov ecx, 0
	mov esi, [ebp + arg1]
desenare_block:
	cmp dword ptr [esi], 0
	je delete
	m_make_rectangle dword ptr[esi + 4], dword ptr[esi + 8], dword ptr[esi + 12], dword ptr[esi + 16], [ebp + arg4], [ebp + arg3]
	m_make_asset dword ptr[esi + 4], dword ptr[esi + 8], offset block_filename, [ebp + arg2], 0
	jmp skip_delete
delete:
	m_make_rectangle dword ptr[esi + 4], dword ptr[esi + 8], dword ptr[esi + 12], dword ptr[esi + 16], [ebp + arg4], color_black
	m_make_rectangle dword ptr[esi + 4], dword ptr[esi + 8], dword ptr[esi + 12], dword ptr[esi + 16], [ebp + arg2], color_black
skip_Delete:
	add esi, 20
	inc ecx
	cmp ecx, n_blocks
	jl desenare_block
	
	popa
	mov esp, ebp
	pop ebp
	ret 16
make_blocks endp

;wrapper pentru procedura de mai sus
m_make_blocks macro block_list, dArea, color, vdArea
	push vdArea
	push color
	push dArea
	push block_list
	call make_blocks
endm 




;procedura care incrementeaza pozitia mingii la fiecare cadru, si care salveaza pozitia veche pentru stergere
increment_position proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, b_x ;x incrementat
	mov b_old_x, eax
	add eax, b_speed_x
	mov ebx, b_y ;y incrementat
	mov b_old_y, ebx
	add ebx, b_speed_y
	mov b_x, eax
	mov b_y ,ebx
	
	popa
	mov esp, ebp
	pop ebp
	ret
increment_position endp

;wrapper inutil pentru procedura de mai sus
m_increment_position macro 
	call increment_position
endm



;procedura prin care se verifica ciocnirea si se corecteaza pozitia mingii in cazul unei ciocniri 
;cu marginea ferestrei, pentru a obtine o ciocnire perfecta indiferent de vitezele pe x/y
check_edge proc 
	push ebp
	mov ebp, esp
	pusha

	mov eax, b_x
	mov ebx, b_y
	cmp	b_speed_x, 0
	jg verificare_dreapta
	sub eax, b_r
	cmp eax, 0
	jg verificare_y
	mov eax, b_r
	mov b_x, eax
	
	mov eax, b_speed_x
	mul minus
	mov b_speed_x, eax
	jmp verificare_y
	
verificare_dreapta:	
	add eax, b_r
	cmp eax, area_width
	jl verificare_y
	mov ecx, area_width
	sub ecx, b_r
	mov b_x, ecx
	mov eax, b_speed_x
	mul minus
	mov b_speed_x, eax

verificare_y:
	cmp b_speed_y, 0
	jg verificare_jos
	sub ebx, b_r
	cmp ebx, 0
	jg finish
	mov ebx, b_r
	mov b_y, ebx
	mov eax, b_speed_y
	mul minus
	mov b_speed_y, eax
	jmp finish
	
verificare_jos:
	add ebx, b_r
	cmp ebx, area_height
	jl finish
	; mov edx, area_height
	; sub edx, b_r
	; mov b_y, edx
	; mov eax, b_speed_y
	; mul minus
	; mov b_speed_y, eax
	mov state, 0
	mov death, 1
	
finish:
	popa
	mov esp, ebp
	pop ebp
	ret
check_edge endp

;wrapper inutil pentru functia de mai sus
m_check_edge macro
	call check_edge
endm



;procedura pentru obtinerea culorii unui pixel dat, de la coordonatele x/y date
;arg1 = x, arg2 = y, arg3 = dArea
check_pixel proc ;arg1 = x, arg2 = y, arg3 = dArea
	push ebp
	mov ebp, esp
	
	push ebx
	push ecx
	
	mov ebx, [ebp + arg1]
	mov ecx, [ebp + arg2]
	m_calculate_position ebx, ecx, [ebp + arg3]
	cmp eax, minus
	je skip
	mov eax, dword ptr[eax]
skip:
	pop ecx
	pop ebx	
	mov esp, ebp
	pop ebp
	ret 12
check_pixel endp

;wrapper pentru procedura de mai sus
m_check_pixel macro x, y, dArea
	push dArea
	push y
	push x
	call check_pixel
endm



;procedura care numara cati pixeli colorati sunt pe o linie cu un x y dat, 
;excluzand o culoare data (culoarea mingii), returnand numarul prin eax
;arg1 = start_x, arg2 = start_y, arg3 = end_x, arg4 = end_y, arg5 = inc_x, 
;arg6 = inc_y, arg7 = dArea, arg8 = ex_color, arg9 = block_list
check_line proc 
	push ebp
	mov ebp, esp
	push ebx
	push ecx
	push edx
	push esi
	
	mov ebx, [ebp + arg1]
	mov ecx, [ebp + arg2]
	mov esi, 0
	
bucla_citire:
	m_calculate_position ebx, ecx, [ebp + arg7]
	cmp eax, minus
	je skip
	mov edx, dword ptr [eax]
	cmp edx, 0
	je skip
	cmp edx, [ebp + arg8]
	je skip
	push [ebp + arg9]
	push [ebp + arg7]
	push ecx
	push ebx
	call check_block
	
	;m_check_block ebx, ecx, [ebp + arg7], [ebp + arg9]
	inc esi
skip:
	;m_make_pixel ebx, ecx, [ebp + arg7], color_blue
	push ebx
	push ecx
	;push edx
	;push offset format
	;call printf
	;add esp, 8
	pop ecx
	pop ebx
	add ebx, [ebp + arg5]
	add ecx, [ebp + arg6]
	
	cmp dword ptr[ebp + arg5], 0
	jg bigger_x
	cmp ebx, [ebp + arg3]
	jl finish
	jmp verif_y
bigger_x:
	cmp ebx, [ebp + arg3]
	jg finish
verif_y:
	cmp dword ptr[ebp + arg6], 0
	jg bigger_y
	cmp ecx, [ebp + arg4]
	jl finish
	jmp next
bigger_y:
	cmp ecx, [ebp + arg4]
	jg finish
next:
	jmp bucla_citire 
finish:
	push offset newline
	call printf
	add esp, 4
	push esi
	push offset format_dd 
	call printf
	add esp, 8
	push offset newline
	call printf
	add esp, 4
	
	mov eax, esi
	pop esi
	pop edx
	pop ecx
	pop ebx
	
	mov esp, ebp
	pop ebp
	ret 36
check_line endp

;wrapper pentru procedura de mai sus
m_check_line macro start_x, start_y, end_x, end_y, inc_x, inc_y, dArea, ex_color, block_list
	push block_list
	push ex_color
	push dArea
	push inc_y
	push inc_x
	push end_y
	push end_x
	push start_y
	push start_x
	call check_line
endm



;procedura care verifica daca o coordonata este intr-o zona desemnata, cum ar fi in interiorul unui bloc
;de distrus sau in interiorul unui buton, returnand raspunsul prin eax
check_inside proc ;arg1 = x, arg2 = y, arg3 = minX, arg4 = minY, arg5 = maxX, arg6 = maxY
	push ebp
	mov ebp, esp
	push ebx
	mov eax, 0
	mov ebx, [ebp + arg1]
	cmp ebx, dword ptr[ebp + arg3]
	jb outside
	cmp ebx, dword ptr[ebp + arg5]
	ja outside
	mov ebx, [ebp + arg2]
	cmp ebx, dword ptr[ebp + arg4]
	jb outside
	cmp ebx, dword ptr[ebp + arg6]
	ja outside
	mov eax, 1
outside:
	pop ebx
	mov esp, ebp
	pop ebp
	ret 24
check_inside endp

;wrapper pentru functia de mai sus
m_check_inside macro x, y, minX, minY, maxX, maxY
	push maxY
	push maxX
	push minY
	push minX
	push y
	push x
	call check_inside
endm



;procedura care verifica cu ce s-a ciocnit bila, si reactioneaza in concordanta
;(distruge blocul de distrus, face un bounce variabil cu placa de jos)
;arg1 = x, arg2 = y, arg3 = dArea, arg4 = block_list
check_block proc 
	push ebp
	mov ebp, esp
	
	push ebx
	push ecx
	push edx
	push esi
	push edi
	
	m_check_pixel [ebp + arg1], [ebp + arg2], [ebp + arg3]
	cmp eax, color_green
	je green
	cmp eax, color_blue
	je blue
	jmp no_block
green:
	mov esi, [ebp + arg4]
	mov ecx, 0
	mov edi, -1
bucla_blocuri:
	push ecx
	mov ebx, [esi + 4]
	mov edx, [esi + 8]
	add ebx, [esi + 12]
	add edx, [esi + 16]
	m_check_inside [ebp + arg1], [ebp + arg2], [esi + 4], [esi + 8], ebx, edx
	cmp eax, 0
	je skip
	mov edi, ecx
skip:
	pop ecx
	inc ecx
	add esi, 20
	cmp ecx, n_blocks
	jb bucla_blocuri
	mov eax, edi
	jmp finish
blue:
	mov eax, b_x
	sub eax, p_x
	cmp p_x, 100
	ja big_plate
	jb small_plate
	mov ebx, normal_magic_number
	jmp blue_collision
big_plate:
	mov ebx, large_magic_number
	jmp blue_collision
small_plate:
	mov ebx, small_magic_number
blue_collision:
	cmp eax, 0
	jg skip_edx_preset
	mov edx, -1
skip_edx_preset:
	idiv ebx
	mov b_speed_x, eax	
	mov collided_plate, 1
	finit
	fld magnitudine_before_sq
	fild b_speed_x
	fld st(0)
	fmul
	fsub
	fsqrt
	fist b_speed_y
	jmp no_destroy
no_block:
	mov eax, -1
finish:
	cmp eax, -1
	je no_destroy
	push eax
	mov ecx, 20
	mul ecx
	add eax, [ebp + arg4]
	mov dword ptr[eax], 0
	pop eax
	mov destroy, al
no_destroy:
	pop edi
	pop esi
	pop edx
	pop ecx
	pop ebx
	mov esp, ebp
	pop ebp
	ret 16
check_block endp

;wrapper pentru procedura de mai sus
m_check_block macro x, y, dArea, block_list
	push block_list
	push dArea
	push y
	push x
	call check_block
endm



;procedura care verifica zona de jur imprejurul mingii, pentru a determina daca isi da bounce
;si a face un bounce perfect indiferent de vitezele pe x/y
;arg1 = dArea, arg2 = block_list
check_around proc 
	push ebp
	mov ebp, esp
	pusha
	
	mov esi, b_r
	mov eax, b_x
	sub eax, esi
	dec eax
	push eax ;x0
	
	mov eax, b_y
	sub eax, esi
	dec eax
	push eax ;y0
	
	mov eax, b_x
	add eax, esi
	inc eax
	push eax ;xmax
	
	mov eax, b_y
	add eax, esi
	inc eax
	push eax ;ymax
	
	shl esi, 1
	add esi, 2
	
	pop edx;ymax
	pop ecx;xmax
	pop ebx;y0
	pop esi;x0
	
	m_check_line esi, ebx, ecx, ebx, 1, 0, [ebp + arg1], color_red, [ebp + arg2] ;orizontal la y0
	push eax ;pixeli sus
	m_check_line esi, edx, ecx, edx, 1, 0, [ebp + arg1], color_red, [ebp + arg2] ;orizontal la ymax
	push eax ;pixeli jos
	m_check_line esi, ebx, esi, edx, 0, 1, [ebp + arg1], color_red, [ebp + arg2] ;vertical la x0
	push eax ;pixeli stanga
	m_check_line ecx, ebx, ecx, edx, 0, 1, [ebp + arg1], color_red, [ebp + arg2] ;vertical la xmax
	push eax ;pixeli dreapta
	mov collided_plate, 0
	
	pop eax ;pixeli dreapta
	pop ebx ;pixeli stanga
	pop ecx ;pixeli jos
	pop edx ;pixeli sus
	
	cmp b_speed_x, 0
	je viteza_x_0
	jg viteza_x_pozitiva
	mov esi, ebx
	jmp viteza_x_final
viteza_x_0:
	mov esi, 0
	jmp viteza_x_final
viteza_x_pozitiva:
	mov esi, eax
viteza_x_final:

	cmp b_speed_y, 0
	je viteza_y_0
	jg viteza_y_pozitiva
	mov edi, edx
	jmp viteza_y_final
viteza_y_0:
	mov edi, 0
	jmp viteza_y_final
viteza_y_pozitiva:
	mov edi, ecx
viteza_y_final:

	cmp ebx, eax
	jae maxim_vertical_done
	mov ebx, eax
maxim_vertical_done:

	cmp edx, ecx
	jae maxim_orizontal_done
	mov edx, ecx
maxim_orizontal_done:

	cmp esi, 0
	jne calcul_ciocnire
	cmp edi, 0
	jne calcul_ciocnire
	jmp final_ciocnire
	
calcul_ciocnire:
	cmp destroy, -1
	je skip_increment
	push esi
	movzx esi, destroy
	cmp bonuses[esi*4], 1
	je marire_placa
	cmp bonuses[esi*4], 2
	je micsorare_placa
	cmp bonuses[esi*4], 3
	je normalizare_placa
	jmp final_mods
marire_placa:
	mov p_w, 150
	jmp final_mods
micsorare_placa:
	mov p_w, 50
	jmp final_mods
normalizare_placa:
	mov p_w, 100
	jmp final_mods
final_mods:
	pop esi
	mov destroy, -1
	inc counter
skip_increment:
	cmp esi, edi
	ja ciocnire_laterala
	;bounce orizontal
	cmp b_speed_y, 0
	jg bounce_jos
	;bounce sus
	mov eax, b_y
	add eax, ebx
	dec eax
	mov b_y, eax
	jmp inversare_y
bounce_jos:
	mov eax, b_y
	sub eax, ebx
	inc eax
	mov b_y, eax
inversare_y:
	push edx
	mov eax, b_speed_y
	mul minus
	mov b_speed_y, eax
	pop edx
	
ciocnire_laterala:
	cmp esi, edi
	jb final_ciocnire
	cmp b_speed_x, 0
	jg bounce_dreapta
	;bounce stanga
	mov eax, b_x
	add eax, edx
	dec eax
	mov b_x, eax
	jmp inversare_x
bounce_dreapta:
	mov eax, b_x
	sub eax, edx
	inc eax
	mov b_x, eax
inversare_x:
	push edx
	mov eax, b_speed_x
	mul minus
	mov b_speed_x, eax
	pop edx
	
final_ciocnire:
	;m_make_rectangle dword ptr[esi + 4], dword ptr[esi + 8], dword ptr[esi + 12], dword ptr[esi + 16], [ebp + arg2], [ebp + arg3]
	popa
	mov esp, ebp
	pop ebp
	ret 8
check_around endp

;wrapper pentru procedura de mai sus
m_check_around macro dArea, block_list
	push block_list
	push dArea
	call check_around
endm
	
; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click, 3 - s-a apasat o tasta)
; arg2 - x (in cazul apasarii unei taste, x contine codul ascii al tastei care a fost apasata)
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	cmp eax, 3
	jz evt_key
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 0
	push draw_area
	call memset
	add esp, 12
	
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 0
	push virtual_draw_area
	call memset
	add esp, 12
	
	jmp afisare_litere
	
evt_key:
	cmp death, 0
	je skip_ressurection
	mov death, 0
	m_make_rectangle 250, 220, 140, 40, draw_area, color_black
	m_make_rectangle 250, 220, 140, 40, virtual_draw_area, color_black
	jmp retry
skip_ressurection:
	jmp evt_timer
	
evt_click:
	m_check_pixel [ebp + arg2], [ebp + arg3], virtual_draw_area
	cmp eax, color_purple
	je play_pause
	cmp eax, color_cyan
	je retry
	cmp state, 0
	je final_click
	mov eax, [ebp + arg2]
	mov p_x, eax
	jmp final_click
play_pause:
	cmp state, 0
	je play
	;pause
	mov eax, b_speed_x
	mov b_speed_x_store, eax
	mov eax, b_speed_y
	mov b_speed_y_store, eax
	mov b_speed_x, 0
	mov b_speed_y, 0
	mov state, 0
	jmp final_click
play:
	mov eax, b_speed_x_store
	mov b_speed_x, eax
	mov eax, b_speed_y_store
	mov b_speed_y, eax
	mov state, 1
	jmp final_click
retry:
	;ball
	mov b_x, 320
	mov b_y, 454
	mov b_speed_x, 5
	mov b_speed_y, -5
	
	finit
	fild b_speed_x
	fild b_speed_x
	fmul
	fild b_speed_y
	fild b_speed_y
	fmul
	fadd
	fst magnitudine_before_sq
	
	;plate
	mov p_x, 320
	mov p_y, 475
	mov p_w, 100
	
	;blocks
	mov ecx, 0
	mov esi, 0
bucla_reinitializare_blocuri:
	mov blocks[esi], 1
	add esi, 20
	inc ecx
	cmp ecx, n_blocks
	jb bucla_reinitializare_blocuri
	
	mov state, 1
	mov counter, 0
	;jmp final_draw
final_click:
	
	;m_make_rectangle_center [ebp + arg2], [ebp + arg3], 50, 50, draw_area, color_green
evt_timer:
	cmp state, 0
	je afisare_litere
	lea eax, blocks
	m_make_blocks eax, draw_area, color_green, virtual_draw_area
	m_check_edge
	lea eax, blocks
	m_check_around virtual_draw_area, eax
	;m_make_rectangle_center 370, 342, 50, 50, draw_area, color_green
	;m_make_rectangle_center 400, 375, 50, 50, draw_area, color_green
	m_make_ball b_x, b_y, b_old_x, b_old_y, b_r, draw_area, b_color, virtual_draw_area
	;m_make_plate p_x, p_y, p_old_x, p_old_y, p_w, p_h, p_old_w, draw_area, p_color
	m_make_plate p_x, p_y, p_old_x, p_old_y, p_w, p_h, p_old_w, draw_area, p_color, virtual_draw_area
	;m_make_rectangle 0, 0, 640, 50, draw_area, color_nqb
	m_make_rectangle 0, 0, 640, 50, virtual_draw_area, color_nqb
	m_make_asset 0, 0, offset upper_filename, draw_area, 0
	;m_make_rectangle 600, 0, 40, 40, draw_area, color_purple
	m_make_rectangle 590, 5, 40, 40, virtual_draw_area, color_purple
	m_make_asset 590, 5, offset play_filename, draw_area, 0
	m_make_rectangle 550, 5, 40, 40, virtual_draw_area, color_cyan
	m_make_asset 550, 5, offset retry_filename, draw_area, 0
	m_increment_position
	
afisare_litere:
	cmp death, 0
	je skip_death
	m_make_string 275, 220, offset mesaj_game_over, draw_area, color_red
	m_make_string 275, 220, offset mesaj_game_over, virtual_draw_area, color_red
	m_make_string 250, 240, offset mesaj_retry, draw_area, color_green
	m_make_string 250, 240, offset mesaj_retry, virtual_draw_area, color_green
	jmp skip_message
	
skip_death:
	cmp counter, 16
	jne skip_message
	m_make_string 295, 230, offset mesaj_win, draw_area, color_yellow
	m_make_string 295, 230, offset mesaj_win, virtual_draw_area, color_yellow
	
skip_message:
	m_make_string 0, 10, offset mesaj_scor, draw_area, color_white
	m_make_string 0, 10, offset mesaj_scor, virtual_draw_area, color_white
	;afisam valoarea counter-ului curent (sute, zeci si unitati)
	mov ebx, 10
	mov eax, counter
	;cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, draw_area, 60, 10, color_white
	;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, draw_area, 50, 10, color_white
	
	mov ebx, 10
	mov eax, counter
	;cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, virtual_draw_area, 60, 10, color_white
	;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, virtual_draw_area, 50, 10, color_white


final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
	;alocam memorie pentru zona de desenat
	push seed
	call srand
	add esp, 4
	mov ecx, 0
bucla_bonusuri:
	push ecx
	call rand
	pop ecx
	mov edx, 0
	shl eax, 24
	shr eax, 24
	mov ebx, 4
	div ebx
	mov bonuses[ecx*4], edx
	inc ecx
	cmp ecx, n_blocks
	jb bucla_bonusuri
	
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov draw_area, eax
	
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov virtual_draw_area, eax
	
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push draw_area
	;push virtual_draw_area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start
