##
# Deutsch
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
<p>Eine Übersicht aller Auto-Timer-Einträge.</p>
<p>Klicken Sie auf <i>Ja</i> oder <i>Nein</i> in der Spalte <i>Aktiv</i>, um den jeweiligen Eintrag an oder aus zu schalten.</p>
<p>Um einen Eintrag zu bearbeiten, klicken Sie auf das Symbol <img src=\"bilder/edit.gif\" alt=\"Stift\" valign=\"center\">, zum Löschen auf <img src=\"bilder/delete.gif\" alt=\"Radiergummi\" valign=\"center\">. Wenn Sie mehrere Auto-Timer-Einträge auf einmal löschen möchten, Aktivieren Sie die Kästchen (<input type=\"checkbox\" checked>) rechts neben den gewünschten Einträgen und klicken Sie abschließend auf <i>Ausgewählte Auto Timer löschen</i> am Ende der Liste.</p>",
  at_timer_new     =>
"<b>Neuen Auto Timer anlegen/bearbeiten:</b><br>
<p>Der Auto Timer ist eine der zentralen Funktionen VDR Admins. Ein Auto-Timer-Eintrag besteht hauptsächlich aus einem oder mehreren Suchbegriffen, nach denen in regelmäßigen Abständen der elektronische Programmführer (EPG) durchsucht wird. Bei Übereinstimmung der Suchbegriffe (und übrigen Parameter wie Uhrzeit und Kanal) programmiert Auto Timer selbständig eine Aufnahme (Timer) für die gefundene Sendung &#150; das ist besonders für (un)regelmäßig gesendete Serien interessant, oder aber für Filme, die Sie keinesfalls verpassen wollen.</p>
<p>In dieser Maske können Sie einen neuen Auto-Timer-Eintrag anlegen. Sie müssen in jedem Fall einen oder mehrere Suchbegriffe angeben, damit es überhaupt zu Übereinstimmungen kommen kann. Details, welche Suchbegriffe Sie wählen sollten und wie Sie unsinnige Aufnahmen vermeiden, finden Sie in der Hilfe zu <i>Suchbegriffe</i>.</p>
<b>Auto Timer Aktiv:</b><br>
<p>Mit <i>ja</i> schalten Sie den Auto Timer scharf, der elektronische Programmführer (EPG) wird dann regelmäßig nach <i>Suchbegriffe</i> durchsucht und ein neuer Timer-Eintrag programmiert, wenn es eine Übereinstimmung mit <i>Suchbegriffe</i> sowie den übrigen Parametern gibt.</p>
<p>Mit <i>nein</i> schalten Sie den Auto-Timer-Eintrag ab, ohne ihn zu löschen. Dies lässt bereits automatisch programmierte Aufnahmen (Timer) jedoch unangetastet &#150; sie müssen gegebenenfalls von Hand im <i>Timer</i>-Menü gelöscht werden.</p>
<b>Suchbegriffe:</b><br>
<p>Die Wahl der Suchbegriffe hat entscheidenden Einfluss darauf, ob nur die gewünschte Sendung, alle mit ähnlichem Namen oder gar nichts programmiert wird.</p>
<p>Zunächst einmal spielt Groß-Kleinschreibung keine Rolle, die Suchbegriffe \"Akte X\" liefern genau die selben Treffer wie \"akte x\". Mehrere Suchbegriffe werden mit Leerzeichen getrennt, und es müssen stets alle angegebenen Suchbegriffe bei der gleichen Sendung gefunden werden.</p>
<p>So finden die Suchbegriffe \"Akte X\" die Sendungen \"Akte X - Die unheimlichen Fälle des FBI\" genauso wie \"Aktenzeichen XY ungelöst\" und \"Extrem Aktiv\", jedoch nicht die Sendung \"Die Akte Jane\" (dort ist kein \"X\" enthalten).</p>
<p>Sie sollten möglichst nur Buchstaben und Zahlen als Suchbegriffe verwenden, erfahrungsgemäß fehlen im elektronischen Programmführer (EPG) gerne mal ein Punkt, Klammern oder sonstige Zeichen.</p>
<p>Es ist auch möglich, reguläre Ausdrücke zu verwenden &#150; Experten mögen doch bitte die nötigen Infos dem Quelltext entnehmen (undocumented feature).</p>",
  ENOHELPMSG        => "Bisher keine Hilfe vorhanden. Zum Hinzuf&uuml;gen oder &Auml;ndern eines Textes bitte an linvdr\@linvdr.org wenden."
);
