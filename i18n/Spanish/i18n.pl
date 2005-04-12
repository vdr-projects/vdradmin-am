##
# Español
#
# Author: Rüdiger Jung
##

@I18N_Days = (
  "Domingo",
  "Lunes",
  "Martes",
  "Mi&eacute;rcoles",
  "Jueves",
  "Viernes",
  "Sabado"
);

@I18N_Month = (
  "Enero",
  "Febrero",
  "Marzo",
  "Abril",
  "Mayo",
  "Junio",
  "Julio",
	"Agosto",
	"Septiembre",
	"Octubre",
	"Noviembre",
	"Diciembre"
);

@LOGINPAGES_DESCRIPTION = (
	"Datos de EPG",
	"Estrenos ahora",
	"&iquest;Qu&eacute; puedes ver hoy?",
	"Tabla de tiempo",
	"Programaciones",
	"Grabaciones"
);

%MESSAGES = (
# common
	c_progname      => "VDRAdmin",
	c_monday        => $I18N_Days[1],
	c_tuesday       => $I18N_Days[2],
	c_wednesday     => $I18N_Days[3],
	c_thursday      => $I18N_Days[4],
	c_friday        => $I18N_Days[5],
	c_saturday      => $I18N_Days[6],
	c_sunday        => $I18N_Days[0],
	c_help          => "Ayuda",
	c_yes           => "S&iacute;",
	c_no            => "No",
	c_minutes       => "Minutos",
	c_hours_short   => "h.",
	c_sec           => "sec",
	c_off           => "apagado",
	c_channel       => "Emisoras",
	c_time		=> "Horario",
	c_clock         => "h.",
	c_priority      => "Prioridad:",
	c_lifetime      => "Durabilidad:",
	c_buffer_before => "M&aacute;s tiempo al principio:",
	c_buffer_after  => "M&aacute;s tiempo al final:",
	c_title         => "T&iacute;tulo",
	c_subtitle      => "Subt&iacute;tulo",
	c_description   => "Descripci&oacute;n",
	c_summary       => "Resumen:",
	c_save          => "Guardar",
	c_apply         => "Aplicar",
	c_cancel        => "Cancelar",
	c_once          => "una vez",
	c_all           => "todas",
	c_directory     => "Carpeta:",
	c_edit          => "Modificar",
	c_delete        => "Borrar",
	c_whatson       => "Se puede ver:",
	c_now           => "ahora",
	c_at            => "a la/s:",
	c_go            => "&iexcl;venga!",
	c_stream        => "Flujo",
	c_select_all_none => "Selececionar todos/ninguno",

# JavaScript
	js_del_timer          => "&iquest;Borrar programaci&oacute;n?",
	js_del_selected_timer => "&iquest;Borrar en serio las programaciones elegidas?",
	js_change_timer       => "&iquest;Cambiar estado de la programaci&oacute;n?",
	js_del_rec            => "&iquest;Borrar grabaci&oacute;n?",
	js_del_selected_rec   => "&iquest;Borrar en serio las grabaciones elegidas?",

# headings for listings
	c_list_active  => "Activada",
	c_list_channel => "Emisora",
	c_list_start   => "Comienzo",
	c_list_stop    => "Fin",
	c_list_name    => "T&iacute;tulo",
	c_list_date    => "Fecha",
	c_list_time    => "Horarios",

# at_new.html
	an_new_timer    => "Crear nueva autoprogramaci&oacute;n",
	an_edit_timer   => "Modificar autoprogramaci&oacute;n",
	an_timer_active => "Autoprogramaci&oacute;n activada:",
	an_search_items => "Palabras claves:",
	an_search_in    => "Buscar en:",
	an_search_start => "Buscar entre la/s:",
	an_search_stop  => "y la/s:",
	an_episode      => "Serie:",
	an_done_active  => "&quot;Hecho&quot; activado:",

# at_timer_list.html
	al_autotimer     => "Autoprogramaci&oacute;n",
	al_new_autotimer => "Nueva autoprogramaci&oacute;n",
	al_force_update  => "Actualizar ahora",
	al_del_selected  => "Borrar autoprogramaciones elegidas",

# config.html
	co_config            => "Configuraci&oacute;n",
	co_hl_general        => "Propiedades generales",
	co_g_language        => "Idioma:",
	co_g_template        => "Template:",
	co_g_loginpage       => "P&aacute;gina de inicio:",
	co_g_num_dvb         => "Cantidad tarjetas-DVB:",
	co_g_skin            => "Cara:",
	co_hl_id             => "Identificaciones",
	co_id_user           => "Nombre del usuario:",
	co_id_password       => "Contrase&ntilde;a:",
	co_id_guest_account  => "Acceso como invitado:",
	co_id_guest_user     => "Nombre como invitado:",
	co_id_guest_password => "Contrase&ntilde;a como invitado:",
	co_hl_timeline       => "Tabla de tiempo",
	co_tl_hours          => "Rango de hora/s:",
	co_tl_times          => "Horarios:",
	co_hl_autotimer      => "Autoprogramaciones",
	co_at_active         => "Activadas:",
	co_at_timeout        => "Actualizaci&oacute;n cada:",
	co_hl_timer          => "Programaciones",
	co_hl_streaming      => "Flujo",
	co_str_port          => "Puerto-HTTP para el flujo (3000/ts tambi&eacute;n posible):",
	co_str_bandwidth     => "Ancho de banda del flujo:",
	co_str_rec_path      => "Ruta de las grabaciones:",
	co_str_do_live       => "¿Flujo en vivo?",
	co_str_do_rec        => "¿Grabar flujo?",
	co_hl_channels       => "Emisoras preferidas",
	co_ch_use_summary    => "Usar en &quot;Datos de la gu&iacute;a electr&oacute;nica (EPG)&quot;?",
	co_ch_use_whatsonnow => "Usar en &quot;Estrenos ahora&quot;?",
	co_ch_use_autotimer  => "Usar en &quot;Autoprogramaciones&quot;?",

# index.html
	i_no_frames => "&iexcl;El navegador no soporta marcos!",

# left.html
	menu_prog_summary  => "Estrenos ahora",
	menu_prog_list2    => "&iquest;Qu&eacute; puedes ver hoy?",
	menu_prog_timeline => "Tabla de tiempo",
	menu_prog_list     => "Datos de EPG",
	menu_timer_list    => "Programaciones",
	menu_at_timer_list => "Autoprogramaciones",
	menu_rec_list      => "Grabaciones",
	menu_config        => "Configuraci&oacute;n",
	menu_rc            => "Mando de distancia",
	menu_tv            => "Televisi&oacute;n",
	menu_search        => "Buscar",

# vdradmind.pl, noauth.html, error.html
	err_notfound       => "Nada encontrado",
	err_notfound_long  => "&iexcl;La URL requerida, no se encontr&oacute; en el servidor!",
	err_notfound_file  => "&iexcl;La URL %s no se encontr&oacute; en el servidor!",
	err_forbidden      => "Prohibido",
	err_forbidden_long => "&iexcl;No tienes permiso para &eacute;sta funcci&oacute;n!",
	err_forbidden_file => "&iexcl;Acceso al archivo %s negado!",
	err_cant_open      => "&iexcl;No se pudo abrir el archivo %s!",
	err_noauth         => "Autorizaci&oacute;n obligatoria",
	err_cant_verify    => "Este servidor no pudo verificar, t&uacute; permiso de acceso al documento requerido.<br>Posiblemente por entregar datos incorrectos (Nombre del usuario o contrase&ntilde;a p.e.) o por que t&uacute; navegador no soporta la forma de acceso.",
	err_error          => "&iexcl;Error!",

# prog_detail.html
	pd_close  => "cerrar",
	pd_view   => "cambiar",
	pd_record => "grabar",
	pd_search => "repeticiones",
	pd_imdb   => "Buscar la pel&iacute;cula en la base de datos en Internet (IMDb)",

# prog_list2.html
	pl2_headline => "&iquest;Qu&eacute; puedes ver hoy?",

# prog_list.html
	pl_headline => "Datos de la gu&iacute;a electr&oacute;nica (EPG)",

# prog_summary.html
	ps_headline  => "Estrenos ahora",
	ps_more      => "m&aacute;s",
	ps_search    => "buscar repeticiones",
	ps_more_info => "m&aacute;s info",
	ps_view      => "cambiar TV",
	ps_record    => "Grabar estreno",

# prog_timeline.html
	pt_headline => "Estrenos ahora",
	pt_timeline => "Tabla de tiempo:",
	pt_to       => "hasta",

# rc.html
	rc_headline => "Mando de distancia",

# rec_edit.html
	re_headline  => "Renombrar grabaciones",
	re_old_title => "T&iacute;tulo actual de la grabaci&oacute;n:",
	re_new_title => "T&iacute;tulo nuevo de la grabaci&oacute;n:",
	re_rename    => "Renombrar",

# rec_list.html
	rl_headline     => "Grabaciones",
	rl_hd_total     => "Espacio en el disco:",
	rl_hd_free      => "Espacio disponible:",
	rl_rec_total    => "Todas",
	rl_rec_new      => "nueva",
	rl_rename       => "Renombrar",
	rl_del_selected => "Borrar grabaciones elegidas",

# timer_list.html
	tl_headline     => "Programaciones",
	tl_new_timer    => "Nueva programaci&oacute;n",
	tl_inactive     => "&iexcl;&Eacute;sta programaci&oacute;n est&aacute; desactivada!",
	tl_impossible   => "&iexcl;&Eacute;sta programaci&oacute;n es imposible!",
	tl_nomore       => "&iexcl;No se puede grabar m&aacute;s!",
	tl_possible     => "&Eacute;sta programaci&oacute;n es posible.",
	tl_vps          => "VPS",
	tl_auto         => "Auto",
	tl_del_selected => "Borrar programaciones elegidas",

# timer_new.html
	tn_new_timer          => "Crear nueva programaci&oacute;n",
	tn_edit_timer         => "Modificar programaci&oacute;n",
	tn_timer_active       => "Programaci&oacute;n activada:",
	tn_autotimer_checking => "Autovigilancia de las programaciones",
	tn_transmission_id    => "Identificador de la emisora",
	tn_day_of_rec         => "D&iacute;a de la grabaci&oacute;n:",
	tn_time_start         => "Comienzo:",
	tn_time_stop          => "Fin:",
	tn_rec_title          => "T&iacute;tulo de la grabaci&oacute;n:",

# tv.html
	tv_headline => "Televisi&oacute;n",
	tv_interval => "Intervalo:",
	tv_size     => "Dimensiones:",
	tv_grab     => "&iexcl;Captura la imagen!",
	tv_g        => "C"
);

%ERRORMESSAGE = (
	CONNECT_FAILED => "&iexcl;No se pudo estabilizar la conexci&oacute;n a %s!",
	SEND_COMMAND   => "Error mandando el comando  a %s ",
);

%COMMONMESSAGE = (
	OVERVIEW => "Vista general",
);

%HELP = (
  at_timer_list     =>
"<b>Autoprogramaci&oacute;n:</b><br>
<p>Vista general de todos los registros de Autoprogramaci&oacute;n.</p>
<p>H&aacute;z cl&iacute;c encima de |<img src=\"bilder/poempl_gruen.gif\" alt=\"encendido\" valign=\"center\"> <i>s&iacute;</i> | o |<img src=\"bilder/poempl_rot.gif\" alt=\"noencendido\" valign=\"center\"> <i>no</i> | en la columna <i>Activada</i>, para activar o desactivar un registro correspondiente.</br>
Para modificar un registro, h&aacute;z cl&iacute;c encima del s&iacute;mbolo <img src=\"bilder/edit.gif\" alt=\"Lap&iacute;z\" valign=\"center\">, para borrar encima de la <img src=\"bilder/delete.gif\" alt=\"Goma\" valign=\"center\">.<br>
Si quieres borrar varios registros de una vez, marca (<input type=\"checkbox\" checked>) el campo junto a los registros y h&aacute;z cl&iacute;c encima de <i>Borrar autoprogramaciones elegidas</i> al final de la lista.
</p>",

###autotimer hinzufuegen--
  at_timer_new     =>
"<b>Crear/modificar nueva autoprogramaci&oacute;n:</b>
<p>La autoprogramaci&oacute;n es una funci&oacute;n b&aacute;sica del VDR Admin. Una autoprogramaci&oacute;n se refiere a una o m&aacute;s <i>Palabras claves</i>, cuales usar&aacute; para analizar los datos de la gu&iacute;a electr&oacute;nica (EPG) con un rango de tiempo ajustable. Cuando encuentra las palabras elegidas teniendo en cuenta la hora y la emisora, crear&aacute; autom&aacute;ticamente una programaci&oacute;n para el estreno encontrado &#150; bastante &uacute;til para series (ir)regulares o igual para estrenos, que quieran grabar con seguridad.<br>
En esta pantalla se puede crear una nueva autoprogramaci&oacute;n. Una o m&aacute;s palabras son obligatorias, para que puede actuar. Detalles, por palabras &uacute;tiles y como evitar grabaciones in&uacute;tiles, se puede encontrar en la ayuda para <i>Palabras claves</i> m&aacute;s abajo.
</p>
<b>Auto programaci&oacute;n activo:</b>
<p>Marcando |<input type=\"radio\" checked> <i>s&iacute;</i> | activar&aacute; la autoprogramaci&oacute;n, y se va a buscar regularmente en la gu&iacute;a electr&oacute;nica (EPG) por las  <i>Palabras claves</i> y crear&aacute; una programaci&oacute;n, cuando cumple con las <i>Palabras claves</i> como con los par&aacute;metros dem&aacute;s.</br>
Con |<input type=\"radio\" checked> <i>no</i> |  se desactiva la autoprogramaci&oacute;n, sin borrarla. No afectar&aacute; a las programaciones ya creadas por esta autoprogramaci&oacute;n &#150; a lo mejor tienes que borrarla manualmente en el menu <i>Autoprogramaci&oacute;n</i>.<br>
Con |<input type=\"radio\" checked> <i>una vez</i> | la autoprogramaci&oacute;n acaba de vigilar desp&uacute;es de crear una programaci&oacute;n. A partir de entonces ser&aacute;n programaciones normales sin las ventajas de una autoprogramaci&oacute;n.
</p>
<b>Palabras claves:</b>
<p>Las palabras claves son importante, para lograr un buen resultado.<br>
No importa MAY&Uacute;SCULA o min&uacute;scula. Por eso las palabras claves \"X-Pasta\" lograr&aacute; los mismos resultados como \"x-pasta\". Todas palabras claves se separa con espacio y para cumplir el &oacute;rden, VDR-admin tiene que encontrar todas las palabras claves para un estreno.<br>
Las palabras claves \"Pasta X\" encontrar&aacute;n \"Pasta - La cocina extra&ntilde;a de mi mujer\" como \"No se sabe hacer extra pasta\" y \"Pasta extrema \", pero no \"La pasta increible\" (no se encuentra una \"X\"!).<br>
Se recomienda usar s&oacute;lo letras y cifras como palabras claves, por que la gu&iacute;a electr&oacute;nica (EPG) se l&iacute;mita bastante en el uso de todas caracteres posibles o los interpreta m&aacute;l.
<p>Tambi&eacute;n deberia ser posible usar expresiones regulares &#150; Expertos puedan extraer info del texto fuente (undocumented feature).
</p>",

###Liste der Timer
  timer_list     =>
"<b>Programaci&oacute;n:</b>
<p>Vista general de todas las programaciones.
<br>H&aacute;z cl&iacute;c encima de |<img src=\"bilder/poempl_gruen.gif\" alt=\"activado\" valign=\"center\"> <i>s&iacute;</i> | o |<img src=\"bilder/poempl_grau.gif\" alt=\"noencendido\" valign=\"center\"> <i>no</i> | en la columna <i>Activado</i>, para activar o desactivar un registro correspondiente.<br>
<img src=\"bilder/poempl_gelb.gif\" alt=\"conflicto\" valign=\"center\"> indica que haya conflictos. Esto no importa, si hay una tarjeta disponible para cada una de las programaciones o est&eacute;n en la misma frecuencia.<br>
Para modificar un registro, h&aacute;z cl&iacute;c encima del s&iacute;mbolo <img src=\"bilder/edit.gif\" alt=\"Lap&iacute;z\" valign=\"center\">, para borrar encima de la <img src=\"bilder/delete.gif\" alt=\"Goma\" valign=\"center\">. Si quieres borrar varios registros de una vez, marca (<input type=\"checkbox\" checked>) la casilla a lado de los registros y h&aacute;z cl&iacute;c encima <i>Borrar programaciones elegidas</i> al final de la lista.</p>",

###Konfigurationsseite
  conf_list      =>
"<b>Configuraci&oacute;n:</b>
<p>En &eacute;sta p&aacute;gina se ajusta las propiedades generales, las propiedades de la programaci&oacute;n y de la autoprogramaci&oacute;n, como las emisoras preferidas y por fin los ajustes del flujo.
</p>
<b>Propiedades generales:</b>
<p>Aqu&iacute; se ajusta el idioma, la p&aacute;gina principal, la cara y cuantas tarjetas de DVB hay.
</p>
<b>Identificaciones:</b>
<p>H&aacute;z cl&iacute;c encima de |<input type=\"radio\"> <i>s&iacute;</i> | o |<input type=\"radio\" checked> <i>no</i> | para activar una cuenta de un <i>invitado</i>. Las contrase&ntilde;as tienes que cambiar por algunas m&aacute;s seguras, si est&aacute;s conectado al &iacute;nternet.
</p>
<b>Tabla de tiempo:</b>
<p>&Eacute;sta p&aacute;gina te ofrece una vista de las canales como una tabla, en relacion al tiempo. Las horas introducidas, marcan el rango de las horas que vas a ver. Por defecto empiezara a la &uacute;ltima hora cumplida anterioramente.<br>
En el campo de los horarios puedes entregar las horarios fijas, donde la barra va a empezar. Se refiere al campo en la p&aacute;gina de tabla de tiempo, donde entonces puedes elegir entre esos valores predeterminados.
</p>
<b>Propiedades de las autoprogramaciones:</b>
<p>H&aacute;z cl&iacute;c encima de |<input type=\"radio\" checked> <i>s&iacute;</i> | o |<input type=\"radio\"> <i>no</i> | para activar las autoprogramaciones. Ajusta tambien con que frequencia se van a hacer las b&uacute;squedas en los datos de la gu&iacute;a electr&oacute;nica (EPG) por las <i>Palabras claves</i>.<br>
La durabilidad se puede ajustar entre 0 y 99 para dar a la grabaci&oacute;n creada de &eacute;sta autoprogramaci&oacute;n el valor deseado. El valor se refiere al d&iacute;a de la grabacion - m&aacute;s el rango que pones.<br>
Con el valor de la prioridad de la nueva grabacion tienes el segundo par&aacute;metro, para que VDR puede decidir, cu&aacute;l de las grabaciones hechas se puede borrar, cuando necesita espacio en el disco duro. Por los 2 valores sabr&aacute;, si una grabaci&oacute;n ha caducado y con una prioridad m&aacute;s alta de la grabaci&oacute;n deseada entonces borrar&iacute;a &eacute;sta antigua. As&iacute; te ofrece VDR ajustar prioridades m&aacute;s altas a aquellas grabaciones, que te importan de verdad.<br> Durabilidad=99 por ejemplo, crear&aacute; una grabaci&oacute;n que nunca caduca!
</p>
<b>Propiedades de las programaciones:</b>
<p>Pon la prioridad de las programaciones, que es ajustable entre 0 y 99 . <br>
La durabilidad se puede ajustar entre 0 y 99 para dar a la grabaci&oacute;n creada de &eacute;sta programaci&oacute;n el valor deseado. El valor se refiere al d&iacute;a de la grabacion - m&aacute;s el rango que pones.
</p>

<b>Propiedades del flujo</b>
<p>Si quieres usar la funci&oacute;n del flujo (streaming over net) ajuste aqu&iacute; las propiedades.
</p>

<b>Emisoras preferidas</b>
<p>Con las emisoras preferidas te permite activar las pantallas que quieres usar con una cantidad de canales reducida. As&iacute; se carga mas rapido la p&aacute;gina. Activa las p&aacute;ginas deseadas con los botones |<input type=\"radio\" checked> <i>s&iacute;</i> | o |<input type=\"radio\"> <i>no</i> | junto a los registros.
</p>",

  ENOHELPMSG        => "Para &eacute;sta funci&oacute;n no hay ayuda disponible hasta ahora. Para a&ntilde;adir o modificar un texto, por favor pon te en contacto con mail\@andreas.vdr-developer.org."
);
