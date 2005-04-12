##
# Deutsch
#
# Author: Andreas Mair
##

@I18N_Days = (
  "Sonntag",
  "Montag",
  "Dienstag",
  "Mittwoch",
  "Donnerstag",
  "Freitag",
  "Samstag"
);

@I18N_Month = (
  "Januar",
  "Februar",
  "M&auml;rz",
  "April",
  "Mai",
  "Juni",
  "Juli",
	"August",
	"September",
	"Oktober",
	"November",
	"Dezember"
);

@LOGINPAGES_DESCRIPTION = (
	"Programm&uuml;bersicht",
	"Was l&auml;uft heute?",
	"Was l&auml;uft jetzt?",
	"Zeitleiste",
	"Timer",
	"Aufnahmen"
);

%MESSAGES = (
# common
	c_progname       => "VDRAdmin",
	c_monday         => $I18N_Days[1],
	c_tuesday        => $I18N_Days[2],
	c_wednesday      => $I18N_Days[3],
	c_thursday       => $I18N_Days[4],
	c_friday         => $I18N_Days[5],
	c_saturday       => $I18N_Days[6],
	c_sunday         => $I18N_Days[0],
	c_help           => "Hilfe",
	c_yes            => "Ja",
	c_no             => "Nein",
	c_minutes        => "Minuten",
	c_hours_short    => "h",
	c_sec            => "sek",
	c_off            => "aus",
	c_channel        => "Sender",
	c_time           => "Uhrzeit",
	c_clock          => "Uhr",
	c_priority       => "Priorit&auml;t:",
	c_lifetime       => "Lebenszeit:",
	c_buffer_before  => "Zeitpuffer Anfang:",
	c_buffer_after   => "Zeitpuffer Ende:",
	c_title          => "Titel",
	c_subtitle       => "Untertitel",
	c_description    => "Beschreibung",
	c_summary        => "Zusammenfassung:",
	c_save           => "Speichern",
	c_apply          => "Anwenden",
	c_cancel         => "Abbrechen",
	c_once           => "einmal",
	c_all            => "alle",
	c_directory      => "Ordner:",
	c_edit           => "Bearbeiten",
	c_delete         => "L&ouml;schen",
	c_whatson        => "Was l&auml;uft:",
	c_now            => "jetzt",
	c_at             => "um:",
	c_go             => "Go!",
	c_stream         => "Stream",
	c_select_allnone => "Alle/keine ausw&auml;hlen",

# JavaScript
	js_del_timer          => "Timer l&ouml;schen?",
	js_del_selected_timer => "Ausgew&auml;hlte Timer wirklich l&ouml;schen?",
	js_change_timer       => "Timerstatus &auml;ndern?",
	js_del_rec            => "Aufnahme l&ouml;schen?",
	js_del_selected_rec   => "Ausgew&auml;hlte Aufnahmen wirklich l&ouml;schen?",

# headings for listings
	c_list_active  => "Aktiv",
	c_list_channel => "Sender",
	c_list_start   => "Beginn",
	c_list_stop    => "Ende",
	c_list_name    => "Name",
	c_list_date    => "Datum",
	c_list_time    => "Uhrzeit",

# at_new.html
	an_new_timer    => "Neuen AutoTimer anlegen",
	an_edit_timer   => "AutoTimer editieren",
	an_timer_active => "AutoTimer aktiv:",
	an_search_items => "Suchbegriffe:",
	an_search_in    => "zu suchen in:",
	an_search_start => "Beginnt fr&uuml;hestens:",
	an_search_stop  => "Endet sp&auml;testens:",
	an_episode      => "Serie:",
	an_done_active  => "&quot;Done&quot; aktiv:",

# at_timer_list.html
	al_autotimer     => "AutoTimer",
	al_new_autotimer => "Neuer AutoTimer",
	al_force_update  => "Manuelles Update",
	al_del_selected  => "Ausgew&auml;hlte AutoTimer l&ouml;schen",

# config.html
	co_config            => "Konfiguration",
	co_hl_general        => "Allgemeine Einstellungen",
	co_g_language        => "Sprache:",
	co_g_template        => "Template:",
	co_g_loginpage       => "Startseite:",
	co_g_num_dvb         => "Anzahl der DVB-Karten:",
	co_g_skin            => "Skin:",
	co_hl_id             => "Identifikation",
	co_id_user           => "Benutzername:",
	co_id_password       => "Passwort:",
	co_id_guest_account  => "Gast-Zugang:",
	co_id_guest_user     => "Gast Benutzername:",
	co_id_guest_password => "Gast Passwort:",
	co_hl_timeline       => "Zeitleiste",
	co_tl_hours          => "Stunden:",
	co_tl_times          => "Zeiten:",
	co_hl_autotimer      => "AutoTimer",
	co_at_active         => "Aktiv:",
	co_at_timeout        => "Timeout:",
	co_hl_timer          => "Timer",
	co_hl_streaming      => "Streaming",
	co_str_port          => "HTTP-Port von Streamdev (auch m&ouml;glich 3000/ts):",
	co_str_bandwidth     => "Bandbreite des Streams:",
	co_str_rec_path      => "Pfad der Aufnahmen:",
	co_str_do_live       => "Live Streaming?",
	co_str_do_rec        => "Aufnahmen streamen?",
	co_hl_channels       => "Selektive Senderauswahl",
	co_ch_use_summary    => "Bei &quot;Programm&uuml;bersicht&quot;?",
	co_ch_use_whatsonnow => "Bei &quot;Was l&auml;uft jetzt&quot;?",
	co_ch_use_autotimer  => "Bei &quot;AutoTimer&quot;?",

# index.html
	i_no_frames => "Ihr Browser unterst&uuml;tzt keine Frames!",

# left.html
	menu_prog_summary  => "Was l&auml;uft jetzt?",
	menu_prog_list2    => "Was l&auml;uft heute?",
	menu_prog_timeline => "Zeitleiste",
	menu_prog_list     => "Programm&uuml;bersicht",
	menu_timer_list    => "Timer",
	menu_at_timer_list => "AutoTimer",
	menu_rec_list      => "Aufnahmen",
	menu_config        => "Konfiguration",
	menu_rc            => "Fernbedienung",
	menu_tv            => "Fernseher",
	menu_search        => "Suchen",

# vdradmind.pl, noauth.html, error.html
	err_notfound       => "Nicht gefunden",
	err_notfound_long  => "Die angeforderte URL konnte auf dem Server nicht gefunden werden!",
	err_notfound_file  => "Die URL &quot;%s&quot; wurde auf dem Server nicht gefunden!",
	err_forbidden      => "Verboten",
	err_forbidden_long => "Sie haben nicht die Erlaubnis diese Funktion aufzurufen!",
	err_forbidden_file => "Zugriff auf Datei &quot;%s&quot; verweigert!",
	err_cant_open      => "Kann Datei &quot;%s&quot; nicht &ouml;ffnen!",
	err_noauth         => "Autorisierung erforderlich",
	err_cant_verify    => "Dieser Server kann nicht best&auml;tigen, dass Sie berechtigt sind, auf das angeforderte Dokument zuzugreifen. Entweder haben Sie falsche Anmeldedaten angegeben (z.B. falsches Passwort) oder Ihr Browser kann die Anmeldedaten nicht &uuml;bermitteln.",
	err_error          => "Fehler!",

# prog_detail.html
	pd_close  => "schlie&szlig;en",
	pd_view   => "umschalten",
	pd_record => "aufnehmen",
	pd_search => "Wiederholungen",
	pd_imdb   => "Film in der Internet-Movie-Database (IMDb) suchen",

# prog_list2.html
	pl2_headline => "Was l&auml;uft heute?",

# prog_list.html
	pl_headline => "Programm&uuml;bersicht",

# prog_summary.html
	ps_headline  => "Was l&auml;uft jetzt?",
	ps_more      => "mehr",
	ps_search    => "Nach Wiederholungen suchen",
	ps_more_info => "mehr Infos",
	ps_view      => "TV umschalten",
	ps_record    => "Sendung aufnehmen",

# prog_timeline.html
	pt_headline => "Was l&auml;uft jetzt?",
	pt_timeline => "Zeitleiste:",
	pt_to       => "bis",

# rc.html
	rc_headline => "Fernbedienung",

# rec_edit.html
	re_headline  => "Aufnahme umbenennen",
	re_old_title => "Alter Titel der Aufnahme:",
	re_new_title => "Neuer Titel der Aufnahme:",
	re_rename    => "Umbenennen",

# rec_list.html
	rl_headline     => "Aufnahmen",
	rl_hd_total     => "Total:",
	rl_hd_free      => "Frei:",
	rl_rec_total    => "Gesamt",
	rl_rec_new      => "neu",
	rl_rename       => "Umbenennen",
	rl_del_selected => "Ausgew&auml;hlte Aufnahmen l&ouml;schen",

# timer_list.html
	tl_headline     => "Timer",
	tl_new_timer    => "Neuer Timer",
	tl_inactive     => "Diese Aufnahme ist deaktiviert!",
	tl_impossible   => "Diese Aufnahme ist nicht m&ouml;glich!",
	tl_nomore       => "Keine weiteren Aufnahmen mehr m&ouml;glich!",
	tl_possible     => "Diese Aufnahme ist m&ouml;glich.",
	tl_vps          => "VPS",
	tl_auto         => "Auto",
	tl_del_selected => "Ausgew&auml;hlte Timer l&ouml;schen",

# timer_new.html
	tn_new_timer          => "Neuen Timer anlegen",
	tn_edit_timer         => "Timer editieren",
	tn_timer_active       => "Timer aktiv:",
	tn_autotimer_checking => "Automatische Timer-&Uuml;berwachung:",
	tn_transmission_id    => "Sendungskennung",
	tn_day_of_rec         => "Tag der Aufnahme:",
	tn_time_start         => "Startzeit:",
	tn_time_stop          => "Endzeit:",
	tn_rec_title          => "Titel der Aufnahme:",

# tv.html
	tv_headline => "Fernseher",
	tv_interval => "Intervall:",
	tv_size     => "Gr&ouml;&szlig;e:",
	tv_grab     => "Hole das Bild!",
	tv_g        => "G"
);

%ERRORMESSAGE = (
	CONNECT_FAILED => "Konnte Verbindung zu %s nicht aufbauen!",
	SEND_COMMAND   => "Fehler beim Senden eines Kommandos zu %s",
);

%COMMONMESSAGE = (
	OVERVIEW => "&Uuml;bersicht",
);

%HELP = (
  at_timer_list     =>
"<b>Auto Timer:</b><br>
<p>Eine &Uuml;bersicht aller Auto-Timer-Eintr&auml;ge.</p>
<p>Ein Mausklick auf  |<img src=\"bilder/poempl_gruen.gif\" alt=\"on\" valign=\"center\"> <i>Ja</i> | oder |<img src=\"bilder/poempl_rot.gif\" alt=\"off\" valign=\"center\"> <i>Nein</i> | in der Spalte <i>Aktiv</i>, schaltet den jeweiligen Eintrag an oder aus.</p>
<p>Um einen Eintrag zu bearbeiten, klicken Sie auf das Symbol <img src=\"bilder/edit.gif\" alt=\"Stift\" valign=\"center\">, zum L&ouml;schen auf <img src=\"bilder/delete.gif\" alt=\"Radiergummi\" valign=\"center\">. Wenn Sie mehrere Auto-Timer-Eintr&auml;ge auf einmal l&ouml;schen m&ouml;chten, Aktivieren Sie die K&auml;stchen (<input type=\"checkbox\" checked>) rechts neben den gew&uuml;nschten Eintr&auml;gen und klicken Sie abschlie&szlig;end auf <i>Ausgew&auml;hlte Auto Timer l&ouml;schen</i> am Ende der Liste.</p>",

  at_timer_new     =>
"<b>Neuen Auto Timer anlegen/bearbeiten:</b><br>
<p>Der Auto Timer ist eine der zentralen Funktionen VDR Admins. Ein Auto-Timer-Eintrag besteht haupts&auml;chlich aus einem oder mehreren Suchbegriffen, nach denen in regelm&auml;&szlig;igen Abst&auml;nden der elektronische Programmf&uuml;hrer (EPG) durchsucht wird. Bei &Uuml;bereinstimmung der Suchbegriffe (und &uuml;brigen Parameter wie Uhrzeit und Kanal) programmiert Auto Timer selbst&auml;ndig eine Aufnahme (Timer) f&uuml;r die gefundene Sendung &#150; das ist besonders f&uuml;r (un)regelm&auml;&szlig;ig gesendete Serien interessant, oder aber f&uuml;r Filme, die Sie keinesfalls verpassen wollen.</p>
<p>In dieser Maske k&ouml;nnen Sie einen neuen Auto-Timer-Eintrag anlegen. Sie m&uuml;ssen in jedem Fall einen oder mehrere Suchbegriffe angeben, damit es &uuml;berhaupt zu &Uuml;bereinstimmungen kommen kann. Details, welche Suchbegriffe Sie w&auml;hlen sollten und wie Sie unsinnige Aufnahmen vermeiden, finden Sie in der Hilfe zu <i>Suchbegriffe</i>.</p>
<b>Auto Timer Aktiv:</b><br>
<p>Mit <i>ja</i> schalten Sie den Auto Timer scharf, der elektronische Programmf&uuml;hrer (EPG) wird dann regelm&auml;&szlig;ig nach <i>Suchbegriffe</i> durchsucht und ein neuer Timer-Eintrag programmiert, wenn es eine &Uuml;bereinstimmung mit <i>Suchbegriffe</i> sowie den &uuml;brigen Parametern gibt.</p>
<p>Mit <i>nein</i> schalten Sie den Auto-Timer-Eintrag ab, ohne ihn zu l&ouml;schen. Dies l&auml;sst bereits automatisch programmierte Aufnahmen (Timer) jedoch unangetastet &#150; sie m&uuml;ssen gegebenenfalls von Hand im <i>Timer</i>-Men&uuml; gel&ouml;scht werden.</p>
<b>Suchbegriffe:</b><br>
<p>Die Wahl der Suchbegriffe hat entscheidenden Einfluss darauf, ob nur die gew&uuml;nschte Sendung, alle mit &auml;hnlichem Namen oder gar nichts programmiert wird.</p>
<p>Zun&auml;chst einmal spielt Gro&szlig;-Kleinschreibung keine Rolle, die Suchbegriffe \"Akte X\" liefern genau die selben Treffer wie \"akte x\". Mehrere Suchbegriffe werden mit Leerzeichen getrennt, und es m&uuml;ssen stets alle angegebenen Suchbegriffe bei der gleichen Sendung gefunden werden.</p>
<p>So finden die Suchbegriffe \"Akte X\" die Sendungen \"Akte X - Die unheimlichen F&auml;lle des FBI\" genauso wie \"Aktenzeichen XY ungel&ouml;st\" und \"Extrem Aktiv\", jedoch nicht die Sendung \"Die Akte Jane\" (dort ist kein \"X\" enthalten).</p>
<p>Sie sollten m&ouml;glichst nur Buchstaben und Zahlen als Suchbegriffe verwenden, erfahrungsgem&auml;&szlig; fehlen im elektronischen Programmf&uuml;hrer (EPG) gerne mal ein Punkt, Klammern oder sonstige Zeichen.</p>
<p>Es ist auch m&ouml;glich, regul&auml;re Ausdr&uuml;cke zu verwenden &#150; Experten m&ouml;gen doch bitte die n&ouml;tigen Infos dem Quelltext entnehmen (undocumented feature).
</p>",

  timer_list     =>
"<b>Timer</b>
<p>&Uuml;bersicht &uuml;ber alle Timer im VDR.</p>
<p>Ein Mausklick auf  |<img src=\"bilder/poempl_gruen.gif\" alt=\"on\" valign=\"center\"> <i>Ja</i> | oder |<img src=\"bilder/poempl_grau.gif\" alt=\"off\" valign=\"center\"> <i>Nein</i> | in der Spalte <i>Aktiv</i>, schaltet den jeweiligen Timer an oder aus.<br>
<img src=\"bilder/poempl_gelb.gif\" alt=\"problem\" valign=\"center\"> zeigt an, da&szlig; es eine &Uuml;berschneidung gibt. Das ist unkritisch, solange es f&uuml;r jeden Timer eine Karte gibt, um die Aufnahme durchzuf&uuml;hren.<br>
Um einen Eintrag zu bearbeiten, klicken Sie auf das Symbol <img src=\"bilder/edit.gif\" alt=\"Stift\" valign=\"center\">, zum L&ouml;schen auf <img src=\"bilder/delete.gif\" alt=\"Radiergummi\" valign=\"center\">. Wenn Sie mehrere Auto-Timer-Eintr&auml;ge auf einmal l&ouml;schen m&ouml;chten, Aktivieren Sie die K&auml;stchen (<input type=\"checkbox\" checked>) rechts neben den gew&uuml;nschten Eintr&auml;gen und klicken Sie abschlie&szlig;end auf <i>Ausgew&auml;hlte Timer l&ouml;schen</i> am Ende der Liste.
</p>",

  conf_list      =>
"<b>Allgemeine Einstellungen:</b>
<p>Hier kann man die allgemeinen Einstellungen vornehmen. Au&szlig;erdem die Grundeinstellungen f&uuml;r Timer, AutoTimer, Kanalselektionen und Streaming Parameter
</p>
<b>Allgemeine Einstellungen:</b>
<p>Hier kann man die Sprache, die Startseite, das Aussehen, sowie die Anzahl der DVB-Karten einstellen. Au&szlig;erdem die Grundeinstellungen f&uuml;r Timer, AutoTimer, Kanalselektionen und Streaming Parameter
</p>
<b>Identifikationen:</b>
<p>Ein Mausklick auf  |<input type=\"radio\"> <i>ja</i> | oder |<input type=\"radio\" checked> <i>Nein</i> | aktiviert oder deaktiviert den <i>Gast-Zugang</i>. Die Passw&ouml;rter sollten f&uuml;r beide Konten ge&auml;ndert werden, wenn eine Verbindung zum Internet besteht
</p>
<b>Zeitleiste:</b>
<p>Hier bekommt man eine Balkenansicht der Sender pr&auml;sentiert, wobei man den sichtbaren Zeitumfang einstellen kann.<br>
In den Balken sieht man die Titel der jeweiligen Sendung. Der Zeitbalken beginnt in der vollen halben Stunde vor &quot;Jetzt&quot;. Ein feiner roter Strich zeigt die aktuelle Zeitposition an.<br>Programmierte Sendungen werden au&szlig;erdem farblich hervorgehoben.
</p>
<b>Einstellungen f&uuml;r AutoTimer:</b>
<p>Ein Mausklick auf  |<input type=\"radio\"> <i>Ja</i> | oder |<input type=\"radio\" checked> <i>Nein</i> | aktiviert oder deaktiviert die AutoTimer-Funktion. Hier bestimmt man auch wie oft der AutorTimer in den EPG-Daten nach den <i>Suchbegriffen</i> Ausschau halten soll.<br>
Die Lebenszeit einer Aufnahme bestimmt man indem ein Wert zwischen 0 und 99 eingetr&auml;gt (99 verf&auml;llt nie). Der Wert bezieht sich dann auf den Tag, an dem die Aufnahme gemacht wurde. Sind die angegebenen Tage bereits verfallen, wenn beim VDR eine Aufnahme ansteht, so kann im Falle von Speicherknappheit die betreffende Aufnahme vom VDR gel&ouml;scht werden. Die am l&auml;ngsten abgelaufene Aufnahme wird zuerst gel&ouml;scht. Man bestimmt hier also, mit welcher Lebenszeitangabe der AutoTimer sp&auml;ter eine Aufnahme macht.<br>
Die Priorit&auml;t bestimmt, wer im Falle eines Zeitkonfliktes den Vorrang bekommt. Die h&ouml;here Priorit&auml;t kommt dann zur Ausf&uuml;hrung. <br>
Ein AutoTimer sollte also einen h&ouml;heren Wert zugewiesen bekommen, als die normalen Aufnahmen. Schlie&szlig;lich sucht der AutoTimer in der Regel nach Sendungen, die einem wichtig sind.</p>
<b>Einstellungen f&uuml;r Timer:</b>
<p>Priorit&auml;t und Lebenszeit haben die gleiche Bedeutung, wie vorher bei den AutoTimern beschrieben, gelten aber eben f&uuml;r die von Hand erstellten Timer.
</p>

<b>Einstellungen f&uuml;r das Streamdevice:</b>
<p>Neben Port und Bandbreite, mu&szlig; hier auch das Videoverzeichnis von VDR eingetragen werden.
</p>

<b>Die selektive Kanalwahl:</b>
<p>Ein Mausklick auf  |<input type=\"radio\"> <i>Ja</i> | oder |<input type=\"radio\" checked> <i>Nein</i> | rechts neben den gew&uuml;nschten Eintr&auml;gen, aktiviert oder deaktiviert die &quot;selektiven&quot; Kan&auml;le f&uuml;r das jeweilige Hauptfenster.<br>
So kann man die genannten Einzelansichten auf die gew&auml;hlten Kan&auml;le beschr&auml;nken, was &Uuml;bersichtlichkeit und Seitenaufbau g&uuml;nstig beeinflu&szlig;t.<br>
Die Auswahl der Kan&auml;le erfolgt nach Auswahl eines oder mehrerer Kan&auml;le im linken Fenster (STRG-Taste gedr&uuml;ckt halten und alle Kan&auml;le die man hinzuf&uuml;gen will anklicken), durch &Uuml;bertragung in das rechte Fenster. <br>Mit den Kn&ouml;pfen sind beide Richtungen m&ouml;glich.
</p>
",

  ENOHELPMSG        => "Bisher keine Hilfe vorhanden. Zum Hinzuf&uuml;gen oder &Auml;ndern eines Textes bitte an mail\@andreas.vdr-developer.org wenden."
);
