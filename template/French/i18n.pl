##
# French
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
	"Programmes Cha&icirc;ne",
	"Aujourd\"hui ?",
	"Maintenant ?",
	"Echelle de Temps",
	"Programmation",
	"Enregistrements"
);

%ERRORMESSAGE = (
	CONNECT_FAILED => "Impossible de se connecter à %s!",
	SEND_COMMAND   => "Erreur lors de l'envoi de la commande à %s"
);

%COMMONMESSAGE = (
	OVERVIEW => "Vue d'ensemble"
);

%HELP = (
  at_timer_list     =>
"<b>Programme Automatique :</b><br>
<p>Une point sur tous les Programmes Automatiques</p>
<p>Cliquez <i>Oui</i> ou <i>Non</i> dans la colonne <i>Active</i> pour (d&eacute;s)activater ce Programme Automatique.</p>
<p>Utilisez <img src=\"bilder/edit.gif\" alt=\"pen\" valign=\"center\"> pour &eacute;diter et <img src=\"bilder/delete.gif\" alt=\"Rubber\" valign=\"center\"> pour supprimer un Programme Automatique. Si vous voulez supprimer plusieurs Programmes Automatiques en m&ecirc;me temps, vous devez cocher les bo&icirc;tes (<input type=\"checkbox\" checked>) &agrave; droite et finalement cliquer sur <i>Supprimer la S&eacute;lection</i>.</p>",

  at_timer_new     =>
"<b>Editer un Programme Automatique :</b><br>
<p>Les Programmes Automatiques sont une des spécificit&eacute;s de VDRAdmin. Un Programme Automatique consiste en un ou plusieurs crit&egrave;res de recherche et d'autres param&egrave;tres, qui sont regard&eacute;s r&eacute;guli&egrave;rement dans le Guide Electronique des Programmes (EPG). Quand la recherche est fructueuse, la fonction \"Programme Automatique" ajoute automatiquement dans VDR un programme pour enregistrer. Cette solution est tr&egrave;s agr&eacute;able pour la programmation de s&eacute;ries ou de films qui sont retransmis irr&eacute;guli&egrave;rement et que vous ne voulez pas manquer.</p>
<p>Ici vous pouvez d&eacute;finir un Programme Automatique. Vous devez au minimum renseigner un crit&egrave;re de recherche. Regarder <i>Objets de Recherche</i> si vous avez besoin de plus d'informations sur les crit&egrave;res de recherche et comment &eacute;viter d'enregistrer des programmes que l'on ne veut pas.</p>
<b>Programme Automatique Actif :</b><br>
<p><i>Oui</i> active et <i>Non</i> d&eacute;sactive ce Programme Automatique. Notez que si vous d&eacute;sactivez ce Programme Automatique, les Programmes d&eacute;j&agrave; ajout&eacute;s selon ses crit&egrave;res par VDRAdmin ne sont pas supprim&eacute;s.</p>
<b>Objets de Recherche :</b><br>
<p>Choisir le bon motif de recherche permet de n'enregistrer que ce que l'on a envie d'enregistrer.</p>
<p>La casse n'est pas importante, \"X-Files\" et \"x-files\" donneront les m&ecirc;mes r&eacute;sultats. Vous pouvez utiliser plusieurs crit&egrave;res de recherche s&eacute;par&eacute;s par des espaces. Les flux qui correspondront seront uniquement ceux qui contiennent tous les crit&egrave;res.</p>
<p>Vous ne devriez utiliser que des caract&egrave;res alphanum&eacute;riques pour les crit&egrave;res de recherche, comme les EPGs manquent souvent de colonnes, parenth&egrave;ses et autres caract&egrave;res.</p>
<p>Les experts peuvent aussi utiliser des expressions r&eacute;guli&egrave;res, mais regarder dans les sources pour avoir plus d'informations (non document&eacute;).</p>",

  ENOHELPMSG        => "Aucune aide n'est disponible pour l'instant. Pour ajouter ou changer du texte, veuillez vous adresser &agrave; mail\@andreas.vdr-developer.org."
);
