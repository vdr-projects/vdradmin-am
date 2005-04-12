##
# French
#
# Authors: "Trois Six",  "map" and "lobotomise"
##

@I18N_Days = (
	"Dimanche",
	"Lundi",
	"Mardi",
	"Mercredi",
	"Jeudi",
	"Vendredi",
	"Samedi"
);

@I18N_Month = (
	"Janvier",
	"F&eacute;vrier",
	"Mars",
	"Avril",
	"Mai",
	"Juin",
	"Juillet",
	"Ao&ucirc;t",
	"Septembre",
	"Octobre",
	"Novembre",
	"D&eacute;cembre"
);

@LOGINPAGES_DESCRIPTION = (
	"Liste de Cha&icirc;nes",
	"Aujourd'hui ?",
	"En ce Moment ?",
	"Chronologie",
	"Programmations",
	"Enregistrements"
);

%MESSAGES = (
# common
	c_progname        => "VDRAdmin",
	c_monday          => $I18N_Days[1],
	c_tuesday         => $I18N_Days[2],
	c_wednesday       => $I18N_Days[3],
	c_thursday        => $I18N_Days[4],
	c_friday          => $I18N_Days[5],
	c_saturday        => $I18N_Days[6],
	c_sunday          => $I18N_Days[0],
	c_help            => "Aide",
	c_yes             => "Oui",
	c_no              => "Non",
	c_minutes         => "minutes",
	c_hours_short     => "h",
	c_sec             => "sec.",
	c_off             => "off",
	c_channel         => "Cha&icirc;ne :",
	c_time            => "horaires",
	c_clock           => "Heure",
	c_priority        => "Priorit&eacute; :",
	c_lifetime        => "Chronologie :",
	c_buffer_before   => "Marge avant :",
	c_buffer_after    => "Marge apr&egrave;s :",
	c_title           => "Titre",
	c_subtitle        => "Sous-titre",
	c_description     => "Description",
	c_summary         => "Sommaire:",
	c_save            => "Enregistrer",
	c_apply           => "Appliquer",
	c_cancel          => "Annuler",
	c_once            => "une fois",
	c_all             => "tout",
	c_directory       => "Chemin :",
	c_edit            => "Editer",
	c_delete          => "Supprimer",
	c_whatson         => "En ce moment :",
	c_now             => "maintenant",
	c_at              => "&agrave; :",
	c_go              => "Ok !",
	c_stream          => "Flux",
	c_select_all_none => "Select all/none", #TODO

# JavaScript
	js_del_timer          => "Supprimer Programmation ?",
	js_del_selected_timer => "Supprimer Programmations S&eacute;lectionn&eacute;es ?",
	js_change_timer       => "Changer Statut Programmation ?",
	js_del_rec            => "Supprimer l'Enregistrement ?",
	js_del_selected_rec   => "Supprimer Enregistrements S&eacute;lectionn&eacute;s ?",

# headings for listings
	c_list_active  => "Actif",
	c_list_channel => "Cha&icirc;ne",
	c_list_start   => "D&eacute;but",
	c_list_stop    => "Fin",
	c_list_name    => "Nom",
	c_list_date    => "Date",
	c_list_time    => "Dur&eacute;e",

# at_new.html
	an_new_timer    => "Ajouter Nouvelle Auto-Programmation",
	an_edit_timer   => "Editer Auto-Programmation",
	an_timer_active => "Auto-Programmation Active :",
	an_search_items => "Rechercher Mod&egrave;les :",
	an_search_in    => "Rechercher dans :",
	an_search_start => "D&eacute;but de recherche :",
	an_search_stop  => "Fin de recherche :",
	an_episode      => "Episode :",
	an_done_active  => "Actif Prêt :",

# at_timer_list.html
	al_autotimer     => "Auto-Programmation",
	al_new_autotimer => "Nouvelle Auto-Programmation",
	al_force_update  => "Forcer Mise &agrave; jour",
	al_del_selected  => "Supprimer Auto-Programmations S&eacute;lectionn&eacute;es",

# config.html
	co_config            => "Configuration",
	co_hl_general        => "Param&egrave;tres G&eacute;n&eacute;raux",
	co_g_language        => "Langue :",
	co_g_template        => "Gabarit :",
	co_g_loginpage       => "Page de D&eacute;marrage :",
	co_g_num_dvb         => "Nombre de Cartes DVB :",
	co_g_skin            => "Th&egrave;me :",
	co_hl_id             => "Identification",
	co_id_user           => "Identifiant :",
	co_id_password       => "Mot de Passe :",
	co_id_guest_account  => "Compte d'Invit&eacute; :",
	co_id_guest_user     => "Identifiant Invit&eacute; :",
	co_id_guest_password => "Mot de Passe Invit&eacute; :",
	co_hl_timeline       => "Chronologie",
	co_tl_hours          => "Heures :",
	co_tl_times          => "P&eacute;riodes :",
	co_hl_autotimer      => "Auto-Programmation",
	co_at_active         => "Active :",
	co_at_timeout        => "Timeout :",
	co_hl_timer          => "Programmation",
	co_hl_streaming      => "Emission de Flux",
	co_str_port          => "Port HTTP de Streamdev (aussi possible 3000/ts) :",
	co_str_bandwidth     => "Bande Passante Flux :",
	co_str_rec_path      => "Chemin des Enregistrements VDR :",
	co_str_do_live       => "Live Streaming?", # TODO
	co_str_do_rec        => "Stream recordings?", # TODO
	co_hl_channels       => "S&eacute;lections Cha&icirc;nes",
	co_ch_use_summary    => "Dans &quot;Cha&icirc;nes&quot;?",
	co_ch_use_whatsonnow => "Dans &quot;En ce Moment&quot;?",
	co_ch_use_autotimer  => "Dans &quot;Auto-Programmations&quot;?",

# index.html
	i_no_frames => "Votre Navigateur ne supporte pas les frames !",

# left.html
	menu_prog_summary  => "En ce Moment ?",
	menu_prog_list2    => "Aujourd'hui ?",
	menu_prog_timeline => "Chronologie",
	menu_prog_list     => "Cha&icirc;nes",
	menu_timer_list    => "Programmation",
	menu_at_timer_list => "Auto-Programmation",
	menu_rec_list      => "Enregistrements",
	menu_config        => "Configuration",
	menu_rc            => "T&eacute;l&eacute;commande",
	menu_tv            => "Regarder TV",
	menu_search        => "Rechercher",

# vdradmind.pl, noauth.html, error.html
	err_notfound       => "Non trouv&eacute;",
	err_notfound_long  => "L'URL demand&eacute;e n'a pas &eacute;t&eacute; trouv&eacute;e sur le serveur !",
	err_notfound_file  => "L'URL &quot;%s&quot; n'a pas &eacute;t&eacute; trouv&eacute;e sur le serveur !",
	err_forbidden      => "Interdit",
	err_forbidden_long => "Vous n'avez pas la permission d'acc&eacute;der &agrave; cette fonction !",
	err_forbidden_file => "Acc&egrave;s au fichier &quot;%s&quot; interdit !",
	err_cant_open      => "Ne peut pas ouvrir le fichier &quot;%s&quot; !",
	err_noauth         => "Autorisation Requise",
	err_cant_verify    => "Le serveur n'a pas pu v&eacute;rifier que vous &ecirc;tes autoris&eacute; &agrave; acc&eacute;der au document demand&eacute;. Ou vous avez fourni de mauvaises informations (par ex. mauvais mot de passe), ou votre navigateur n'a pu fournir les informations requises.",
	err_error          => "Erreur !",

# prog_detail.html
	pd_close  => "fermer",
	pd_view   => "vue",
	pd_record => "enregistrer",
	pd_search => "rechercher",
	pd_imdb   => "Lookup movie in the Internet-Movie-Database (IMDb)", # TODO

# prog_list2.html
	pl2_headline => "Jou&eacute; Aujourd'hui",

# prog_list.html
	pl_headline => "Cha&icirc;nes",

# prog_summary.html
	ps_headline  => "En ce Moment ?",
	ps_more      => "plus",
	ps_search    => "Rechercher d&acute;autres temps de diffusion",
	ps_more_info => "Plus d&acute;Information",
	ps_view      => "Zapper",
	ps_record    => "Enregistrer",

# prog_timeline.html
	pt_headline => "En ce Moment ?",
	pt_timeline => "Chronologie :",
	pt_to       => "&agrave;",

# rc.html
	rc_headline => "T&eacute;l&eacute;commande",

# rec_edit.html
	re_headline  => "Renommer l'Enregistrement",
	re_old_title => "Nom Original d'Enregistrement:",
	re_new_title => "Nouveau Nom d'Enregistrement:",
	re_rename    => "Renommer",

# rec_list.html
	rl_headline     => "Enregistrements",
	rl_hd_total     => "Total :",
	rl_hd_free      => "Libre :",
	rl_rec_total    => "Total",
	rl_rec_new      => "Nouveau",
	rl_rename       => "Renommer",
	rl_del_selected => "Supprimer Enregistrements S&eacute;lectionn&eacute;s",

# timer_list.html
	tl_headline     => "Programmation",
	tl_new_timer    => "Nouvelle Programmation",
	tl_inactive     => "Cette Programmation est inactive !",
	tl_impossible   => "Cette Programmation est impossible !",
	tl_nomore       => "Pas plus de Programmations possibles !",
	tl_possible     => "Programmation OK.",
	tl_vps          => "VPS",
	tl_auto         => "Auto",
	tl_del_selected => "Supprimer Programmations S&eacute;lectionn&eacute;es",

# timer_new.html
	tn_new_timer          => "Cr&eacute;er Nouvelle Programmation",
	tn_edit_timer         => "Editer Programmation", #ou "Modifier Programmation"
	tn_timer_active       => "Programmation Active :",
	tn_autotimer_checking => "V&eacute;rification Auto-Programmation :",
	tn_transmission_id    => "Identification Transmission",
	tn_day_of_rec         => "Jour d'Enregistrement :",
	tn_time_start         => "Heure De D&eacute;but :",
	tn_time_stop          => "Heure De Fin :",
	tn_rec_title          => "Titre d'Enregistrement :",

# tv.html
	tv_headline => "TV",
	tv_interval => "Intervalle :",
	tv_size     => "Taille :",
	tv_grab     => "Rafra&icirc;chir",
	tv_g        => "G"
);

%ERRORMESSAGE = (
	CONNECT_FAILED => "Ne peut se connecter &agrave; %s !",
	SEND_COMMAND   => "Erreur en envoyant la commande &agrave; %s",
);

%COMMONMESSAGE = (
	OVERVIEW => "Programmateur",
);

%HELP = (
	at_timer_list =>
"<b>Pro Auto-Programmation :</b><br>
<p>Aper&ccedil;u g&eacute;n&eacute;ral des Auto-Programmations</p>
<p>Cliquer sur <i>Oui</i> ou <i>Non</i> dans la colonne <i>Active</i> pour activer/d&eacute;sactiver cette Auto-Programmation.</p>
<p>Utiliser <img src=\"bilder/edit.gif\" alt=\"pen\" valign=\"center\"> pour &eacute;diter et <img src=\"bilder/delete.gif\" alt=\"Rubber\" valign=\"center\"> pour supprimer une Auto-Programmation. Si vous voulez supprimer des Auto-Programmations multiples d'un seul coup, vous devez cocher les cases (<input type=\"checkbox\" checked>) a droite et finalement cliquer sur <i>Supprimer Auto-Programmations S&eacute;lectionn&eacute;es</i>.</p>",

	at_timer_new =>
"<b>Editer une Programmation:</b><br>
<p>L'Auto-Programmation est une caract&eacute;ristique cl&eacute; de VDRAdmin. Une Auto-Programmation consiste en un ou plusieurs articles de recherche et de quelques autres param&egrave;tres, ceci est recherch&eacute; r&eacute;guli&egrave;rement dans le Guide de Programme Electronique (EPG). Sur combinaison l'Auto-Programmation ajoute une programmation automatiquement dans VDR pour cette &eacute;mission. Ceci est tr&egrave;s appr&eacute;ciable pour les feuilletons ou les films diffus&eacute;s irr&eacute;guli&egrave;rement et que vous ne voulez pas manquer.</p>
<p>Ici vous pouvez r&eacute;gler une Auto-Programmation. Il est exig&eacute; de sp&eacute;cifier au moins un article de recherche. Veuillez aller voir &agrave; <i>Rechercher Articles</i> si vous avez besoin de plus d'information sur la façon dont trouver les articles de recherche et comment &eacute;viter des enregistrements superflus.</p>
<b>Auto-Programmation Active :</b><br>
<p><i>Oui</i> active et <i>Non</i> d&eacute;sactive l'Auto-Programmation.  Veuillez noter que les programmations de VDR d&eacute;j&agrave; ajout&eacute;es par VDRAdmin ne sont pas supprim&eacute;es si vous d&eacute;sactivez l'Auto-Programmation.</p>
<b>Rechercher Articles :</b><br>
<p>Le choix des &eacute;l&eacute;ments de recherche conditionne l'enregistrement de la diffusion, d'une diffusion avec un nom similaire, ou aucun enregistrement</p>
<p>La casse n'a pas d'importance,si &quot;X-files&quot; s&eacute;lectionne tout &quot;x-files&quot; aussi.Vous pouvez choisir plusieurs &eacute;l&eacute;ments de recherche s&eacute;par&eacute;s par des espaces.Seul les diffusions contenant tous les &eacute;l&eacute;ments seront s&eacute;lectionn&eacute;es.</p>
<p>Il est pr&eacute;f&eacute;rable d'utiliser uniquement des lettres et des nombres pour les &eacute;l&eacute;ments de recherche,les EPG n'ont pas souvent d'autres caract&egrave;res tels les deux points ou parenth&egrave;ses.</p>
<p>Les experts peuvent utiliser aussi des expressions courantes, mais pour plus d'informations, regardez les sources de VDRAdmin (fonctions non document&eacute;es).</p>",

	ENOHELPMSG => "Aucune aide disponible. Pour ajouter ou changer du texte contactez mail\@andreas.vdr-developer.org."
);
