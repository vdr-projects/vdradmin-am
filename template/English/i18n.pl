##
# English 
##
@I18N_Days = (
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday"
);

@I18N_Month = (
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
	"August",
	"September",
	"October",
	"November",
	"December"
);

@LOGINPAGES_DESCRIPTION = (
	"Channels",
	"Playing Today",
	"Whats On?",
	"Timeline",
	"Timers",
	"Recordings"
);

%ERRORMESSAGE = (
	CONNECT_FAILED => "Can't connect to %s!",
	SEND_COMMAND   => "Error while sending command to %s",
);

%COMMONMESSAGE = (
	OVERVIEW => "Schedule",
);

%HELP = (
  at_timer_list     =>
"<b>Auto Timer:</b><br>
<p>An overview of all Auto Timers</p>
<p>Click <i>Yes</i> or <i>No</i> in the <i>Active</i> column to (de-)activate that Auto Timer.</p>
<p>Use <img src=\"bilder/edit.gif\" alt=\"pen\" valign=\"center\"> for editing and <img src=\"bilder/delete.gif\" alt=\"Rubber\" valign=\"center\"> for deleting an Auto Timer. If you want to delete multiple Auto Timers all at once, you have to check the boxes (<input type=\"checkbox\" checked>) on the right and finally click <i>Delete selected Auto Timers</i>.</p>",

  at_timer_new     =>
"<b>Edit Auto Timer:</b><br>
<p>Auto Timer is a key feature of VDRAdmin. An Auto Timer consists of one or more search terms and some other settings, that are looked for regularly in the Electronic Program Guide (EPG). On match Auto Timer adds a timer in VDR automatically for that broadcast. That's very comfortable for irregular broadcasted series or movies you don't want to miss.</p>
<p>Here you can set an Auto Timer. It's required to specify at least one search item. Please have a look at <i>Search Items</i> if you need more information on how to find reasonable search items and how to avoid unwanted recordings.</p>
<b>Auto Timer Active:</b><br>
<p><i>Yes</i> activates and <i>No</i> deactivates this Auto Timer. Please note that VDR timers already added by VDRAdmin are not deleted if you deactivate this Auto Timer.</p>
<b>Search Items:</b><br>
<p>Chosing the right search items decides wether only the wanted broadcast or broadcast having similar names or nothing gets recorded.</p>
<p>Case doesn't matter, \"X-Files\" matches anything \"x-files\" will match. You can set multiple search items by separating them with spaces. Only broadcasts will match if they contain all items.</p>
<p>You'd better only use letters and numbers for search items, as EPGs often miss colons, brackets and other characters.</p>
<p>Experts can also use regular expressions, but you have get needed information from the VDRAdmin sources (undocumented feature).</p>",

  ENOHELPMSG        => "No help available yet. For adding or changing text please contact mail\@andreas.vdr-developer.org."
);
