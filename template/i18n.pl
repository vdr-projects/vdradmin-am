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
	notfound_file  => gettext("The URL \"%s\" was not found on this server!"),
	forbidden      => gettext("Forbidden"),
	forbidden_long => gettext("You don't have permission to access this function!"),
	forbidden_file => gettext("Access to file \"%s\" denied!"),
	cant_open      => gettext("Can't open file \"%s\"!"),
	connect_failed => gettext("Can't connect to VDR at %s!"),
	send_command   => gettext("Error while sending command to VDR at %s"),
);

%MESSAGE = (
	overview => gettext("Schedule"),
);

%HELP = (
  conf_list      =>
gettext("<b>Configuration:</b>
<p>Here you can change general settings and base settings for timers, autotimers, channel selection and streaming parameters.
</p>
<b>General Settings:</b>
<p>Here you can change the languge, the start page, the look, and the number of DVB cards. Besides this the base settings for timers, autotimers, the channel selection and streaming parameters can be configured here.
</p>
<b>Identification:</b>
<p>Clicking on |<input type=\"radio\"> <i>yes</i> | or |<input type=\"radio\" checked> <i>no</i> | activates or deactivates the <i>guest account</i>. The default passwords for both accounts should be changed when VDRAdmin is accessible over the Internet.
</p>
<b>Time Line:</b>
<p>Here you can see a time line of the channels, where you can select the displayed time span.<br>
The bars show the titles of each show. A time bar starts half an hour before now. A thin red line indicates the current position.<br>Programmed timers are shown in different colors.
</p>
<b>Settings for autotimers:</b>
<p>Clicking on |<input type=\"radio\"> <i>Yes</i> | or |<input type=\"radio\" checked> <i>No</i> | activates or deactivates the autotimer function. You can also specify the interval, the the epg data is checked for updating the autotimers.<br>
The life time of a recording can be set from 0 to 99 (99=live forever). This value relates to the day, the recording was made. After the given life time, a recording may be deleted to make room for new ones.<br>
The Priority indicates, what timer is prefered in case of a conflict.<br>
<b>Timer settings:</b>
<p>These are the same settings as for the autotimers, but apply to the manually created timers.
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
