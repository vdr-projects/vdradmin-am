@I18N_Days = (
  gettext("Sunday"),
  gettext("Monday"),
  gettext("Tuesday"),
  gettext("Wednesday"),
  gettext("Thursday"),
  gettext("Friday"),
  gettext("Saturday")
);

@I18N_Month = (
  gettext("January"),
  gettext("February"),
  gettext("March"),
  gettext("April"),
  gettext("May"),
  gettext("June"),
  gettext("July"),
  gettext("August"),
  gettext("September"),
  gettext("October"),
  gettext("November"),
  gettext("December")
);

@LOGINPAGES_DESCRIPTION = (
	gettext("What's On Now?"),
	gettext("Playing Today?"),
	gettext("Timeline"),
	gettext("Channels"),
	gettext("Timers"),
	gettext("Recordings")
);

%ERROR_MESSAGE = (
	not_found      => gettext("Not found"),
	notfound_long  => gettext("The requested URL was not found on this server!"),
	notfound_file  => gettext("The URL &quot;%s&quot; was not found on this server!"),
	forbidden      => gettext("Forbidden"),
	forbidden_long => gettext("You don't have permission to access this function!"),
	forbidden_file => gettext("Access to file &quot;%s&quot; denied!"),
	cant_open      => gettext("Can't open file &quot;%s&quot;!"),
	connect_failed => gettext("Can't connect to VDR at %s!"),
	send_command   => gettext("Error while sending command to VDR at %s"),
);

%MESSAGE = (
	overview => gettext("Schedule"),
);

%HELP = (
  timer_list     =>
gettext("<b>Timer</b>
<p>VDR timer overview.</p>
<p>Clicking on |<img src=\"bilder/poempl_gruen.gif\" alt=\"on\" valign=\"center\"> <i>Yes</i> | or |<img src=\"bilder/poempl_grau.gif\" alt=\"off\" valign=\"center\"> <i>No</i> | in the column <i>Active</i>, switches the timer on or off.<br>
<img src=\"bilder/poempl_gelb.gif\" alt=\"problem\" valign=\"center\"> indicates overlapping timers. That's uncritical, as long as you have enough DVB cards for the parallel recordings.<br>
To edit an entry, click on <img src=\"bilder/edit.gif\" alt=\"Stift\" valign=\"center\">, to delete a timer use <img src=\"bilder/delete.gif\" alt=\"Radiergummi\" valign=\"center\">. To delete more than one timer at once, select them using the checkboxes (<input type=\"checkbox\" checked>) and click on <i>Delete selected timers</i> at the end of the list.
</p>"),

  timer_new	=>
gettext("<p>No help available for <b>Add Timer:</b> yet. For adding text please contact mail\@andreas.vdr-developer.org.	
</p>"),

  at_timer_list     =>
gettext("<b>Auto Timer:</b><br>
<p>An overview of all Auto Timers</p>
<p>Click <i>Yes</i> or <i>No</i> in the <i>Active</i> column to (de-)activate that Auto Timer.</p>
<p>Use <img src=\"bilder/edit.gif\" alt=\"pen\" valign=\"center\"> for editing and <img src=\"bilder/delete.gif\" alt=\"Rubber\" valign=\"center\"> for deleting an Auto Timer. If you want to delete multiple Auto Timers all at once, you have to check the boxes (<input type=\"checkbox\" checked>) on the right and finally click <i>Delete selected Auto Timers</i>.</p>"),

  at_timer_new     =>
gettext("<b>Edit Auto Timer:</b><br>
<p>Auto Timer is a key feature of VDRAdmin. An Auto Timer consists of one or more search terms and some other settings, that are looked for regularly in the Electronic Program Guide (EPG). On match Auto Timer adds a timer in VDR automatically for that broadcast. That's very comfortable for irregularly broadcasted series or movies you don't want to miss.</p>
<p>Here you can set an Auto Timer. It's required to specify at least one search item. Please have a look at <i>Search Items</i> if you need more information on how to find reasonable search items and how to avoid unwanted recordings.</p>
<b>Auto Timer Active:</b><br>
<p><i>Yes</i> activates and <i>No</i> deactivates this Auto Timer. Please note that VDR timers already added by VDRAdmin are not deleted if you deactivate this Auto Timer.</p>
<b>Search Items:</b><br>
<p>Choosing the right search items decides whether only the wanted broadcast or broadcast having similar names or nothing gets recorded.</p>
<p>Case doesn't matter, &quot;X-Files&quot; matches anything &quot;x-files&quot; will match. You can set multiple search items by separating them with spaces. Only broadcasts will match if they contain all items.</p>
<p>You'd better only use letters and numbers for search items, as EPGs often miss colons, brackets and other characters.</p>
<p>Experts can also use regular expressions, but you have get needed information from the VDRAdmin sources (undocumented feature).</p>"),

  rec_list	=>
gettext("<p>No help available for <b>Recordings:</b>. For adding text please contact mail\@andreas.vdr-developer.org.	
</p>"),

  conf_list      =>
gettext("<b>Configuration:</b>
<p>Here you can change general settings and base settings for timers, auto timers, channel selection and streaming parameters.
</p>
<b>General Settings:</b>
<p>Here you can change the languge, the start page, the look, and the number of DVB cards. Besides this the base settings for timers, auto timers, the channel selection and streaming parameters can be configured here.
</p>
<b>Identification:</b>
<p>Clicking on |<input type=\"radio\"> <i>yes</i> | or |<input type=\"radio\" checked> <i>no</i> | activates or deactivates the <i>guest account</i>. The default passwords for both accounts should be changed when VDRAdmin is accessible over the Internet.
</p>
<b>Time Line:</b>
<p>Here you can see a time line of the channels, where you can select the displayed time span.<br>
The bars show the titles of each show. A time bar starts half an hour before now. A thin red line indicates the current position.<br>Programmed timers are shown in different colors.
</p>
<b>Settings for auto timers:</b>
<p>Clicking on |<input type=\"radio\"> <i>Yes</i> | or |<input type=\"radio\" checked> <i>No</i> | activates or deactivates the auto timer function. You can also specify the interval, the the epg data is checked for updating the auto timers.<br>
The life time of a recording can be set from 0 to 99 (99=live forever). This value relates to the day, the recording was made. After the given life time, a recording may be deleted to make room for new ones.<br>
The Priority indicates, what timer is prefered in case of a conflict.<br>
<b>Timer settings:</b>
<p>These are the same settings as for the auto timers, but apply to the manually created timers.
</p>

<b>Streaming settings:</b>
<p>Specify port, bandwith and VDR's recording directory here.
</p>

<b>Channel Selection:</b>
<p>Clicking on |<input type=\"radio\"> <i>Yes</i> | or |<input type=\"radio\" checked> <i>No</i> | activates or deactivates the channel selection for a specific view.<br>
</p>
"),

  ENOHELPMSG        => gettext("No help available yet. For adding or changing text please contact mail\@andreas.vdr-developer.org.")
);
