##
# English 
#
# Author: Andreas Mair
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
	c_help            => "Help",
	c_yes             => "Yes",
	c_no              => "No",
	c_minutes         => "minutes",
	c_hours_short     => "h",
	c_sec             => "sec.",
	c_off             => "off",
	c_channel         => "Channel:",
	c_time		  			=> "Time",
	c_clock           => "o'clock",
	c_priority        => "Priority:",
	c_lifetime        => "Lifetime:",
	c_buffer_before   => "Time Margin at Start:",
	c_buffer_after    => "Time Margin at Stop:",
	c_title           => "Title",
	c_subtitle        => "Subtitle",
	c_description     => "Description",
	c_summary         => "Summary:",
	c_save            => "Save",
	c_apply           => "Apply",
	c_cancel          => "Cancel",
	c_once            => "oneshot",
	c_all             => "all",
	c_directory       => "Directory:",
	c_edit            => "Edit",
	c_delete          => "Delete",
	c_whatson         => "What's on:",
	c_now             => "now",
	c_at              => "at:",
	c_go              => "Go!",
	c_stream          => "Stream",
	c_select_all_none => "Select all/none",

# JavaScript
	js_del_timer          => "Delete timer?",
	js_del_selected_timer => "Delete all selected timers?",
	js_change_timer       => "Edit timer status?",
	js_del_rec            => "Delete recording?",
	js_del_selected_rec   => "Delete all selected recordings?",

# headings for listings
	c_list_active  => "Active",
	c_list_channel => "Channel",
	c_list_start   => "Start",
	c_list_stop    => "Stop",
	c_list_name    => "Name",
	c_list_date    => "Date",
	c_list_time    => "Time",

# at_new.html
	an_new_timer    => "Add New Auto Timer",
	an_edit_timer   => "Edit Auto Timer",
	an_timer_active => "Auto Timer Active:",
	an_search_items => "Search Patterns:",
	an_search_in    => "Search in:",
	an_search_start => "Starts Before:",
	an_search_stop  => "Ends Before:",
	an_episode      => "Episode:",
	an_done_active  => "Done Active:",

# at_timer_list.html
	al_autotimer     => "Auto Timer",
	al_new_autotimer => "New Auto Timer",
	al_force_update  => "Force Update",
	al_del_selected  => "Delete Selected Auto Timers",

# config.html
	co_config            => "Configuration",
	co_hl_general        => "General Settings",
	co_g_language        => "Language:",
	co_g_template        => "Template:",
	co_g_loginpage       => "Login Page:",
	co_g_num_dvb         => "Number of DVB Cards:",
	co_g_skin            => "Skin:",
	co_hl_id             => "Identification",
	co_id_user           => "Username:",
	co_id_password       => "Password:",
	co_id_guest_account  => "Guest Account:",
	co_id_guest_user     => "Guest Username:",
	co_id_guest_password => "Guest Password:",
	co_hl_timeline       => "Timeline",
	co_tl_hours          => "Hours:",
	co_tl_times          => "Times:",
	co_hl_autotimer      => "Auto Timer",
	co_at_active         => "Active:",
	co_at_timeout        => "Timeout:",
	co_hl_timer          => "Timer",
	co_hl_streaming      => "Streaming",
	co_str_port          => "HTTP Port of Streamdev (also possible 3000/ts):",
	co_str_bandwidth     => "Bandwidth of Streams:",
	co_str_rec_path      => "Path to VDR Recordings:",
	co_str_do_live       => "Live Streaming?",
	co_str_do_rec        => "Stream recordings?",
	co_hl_channels       => "Channel Selections",
	co_ch_use_summary    => "In &quot;Channels&quot;?",
	co_ch_use_whatsonnow => "In &quot;What's On Now&quot;?",
	co_ch_use_autotimer  => "In &quot;Auto Timer&quot;?",

# index.html
	i_no_frames => "Your Browser does not support frames!",

# left.html
	menu_prog_summary  => "What's On Now?",
	menu_prog_list2    => "Playing Today?",
	menu_prog_timeline => "Timeline",
	menu_prog_list     => "Channels",
	menu_timer_list    => "Timer",
	menu_at_timer_list => "Auto Timer",
	menu_rec_list      => "Recordings",
	menu_config        => "Configuration",
	menu_rc            => "Remote Control",
	menu_tv            => "Watch TV",
	menu_search        => "Search",

# vdradmind.pl, noauth.html, error.html
	err_notfound       => "Not found",
	err_notfound_long  => "The requested URL was not found on this server!",
	err_notfound_file  => "The URL &quot;%s&quot; was not found on this server!",
	err_forbidden      => "Forbidden",
	err_forbidden_long => "You don't have permission to access this function!",
	err_forbidden_file => "Access to file &quot;%s&quot; denied!",
	err_cant_open      => "Can't open file &quot;%s&quot;!",
	err_noauth         => "Authorization Required",
	err_cant_verify    => "This server could not verify that you are authorized to access the document requested. Either you supplied the wrong credentials (e.g. bad password), or your browser doesn't understand how to supply the credentials required.",
	err_error          => "Error!",

# prog_detail.html
	pd_close  => "close",
	pd_view   => "view",
	pd_record => "record",
	pd_search => "search",
	pd_imdb   => "Lookup movie in the Internet-Movie-Database (IMDb)",

# prog_list2.html
	pl2_headline => "Playing Today",

# prog_list.html
	pl_headline => "Channels",

# prog_summary.html
	ps_headline  => "What's On Now?",
	ps_more      => "more",
	ps_search    => "Search for other show times",
	ps_more_info => "More Information",
	ps_view      => "TV select",
	ps_record    => "Record",

# prog_timeline.html
	pt_headline => "What's On Now?",
	pt_timeline => "Timeline:",
	pt_to       => "to",

# rc.html
	rc_headline => "Remote Control",

# rec_edit.html
	re_headline  => "Rename Recording",
	re_old_title => "Original Name of Recording:",
	re_new_title => "New Name of Recording:",
	re_rename    => "Rename",

# rec_list.html
	rl_headline     => "Recordings",
	rl_hd_total     => "Total:",
	rl_hd_free      => "Free:",
	rl_rec_total    => "Total",
	rl_rec_new      => "New",
	rl_rename       => "Rename",
	rl_del_selected => "Delete Selected Recordings",

# timer_list.html
	tl_headline     => "Timer",
	tl_new_timer    => "New Timer",
	tl_inactive     => "This timer is inactive!",
	tl_impossible   => "This timer is impossible!",
	tl_nomore       => "No more timers possible!",
	tl_possible     => "Timer OK.",
	tl_vps          => "VPS",
	tl_auto         => "Auto",
	tl_del_selected => "Delete Selected Timers",

# timer_new.html
	tn_new_timer          => "Create New Timer",
	tn_edit_timer         => "Edit Timer",
	tn_timer_active       => "Timer Active:",
	tn_autotimer_checking => "Auto Timer Checking:",
	tn_transmission_id    => "Transmission Identification",
	tn_day_of_rec         => "Day Of Recording:",
	tn_time_start         => "Start Time:",
	tn_time_stop          => "End Time:",
	tn_rec_title          => "Title of Recording:",

# tv.html
	tv_headline => "TV",
	tv_interval => "Interval:",
	tv_size     => "Size:",
	tv_grab     => "Grab the picture!",
	tv_g        => "G"
);

%ERRORMESSAGE = (
	CONNECT_FAILED => "Can't connect to VDR at %s!",
	SEND_COMMAND   => "Error while sending command to VDR at %s",
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
<p>Auto Timer is a key feature of VDRAdmin. An Auto Timer consists of one or more search terms and some other settings, that are looked for regularly in the Electronic Program Guide (EPG). On match Auto Timer adds a timer in VDR automatically for that broadcast. That's very comfortable for irregularly broadcasted series or movies you don't want to miss.</p>
<p>Here you can set an Auto Timer. It's required to specify at least one search item. Please have a look at <i>Search Items</i> if you need more information on how to find reasonable search items and how to avoid unwanted recordings.</p>
<b>Auto Timer Active:</b><br>
<p><i>Yes</i> activates and <i>No</i> deactivates this Auto Timer. Please note that VDR timers already added by VDRAdmin are not deleted if you deactivate this Auto Timer.</p>
<b>Search Items:</b><br>
<p>Choosing the right search items decides whether only the wanted broadcast or broadcast having similar names or nothing gets recorded.</p>
<p>Case doesn't matter, &quot;X-Files&quot; matches anything &quot;x-files&quot; will match. You can set multiple search items by separating them with spaces. Only broadcasts will match if they contain all items.</p>
<p>You'd better only use letters and numbers for search items, as EPGs often miss colons, brackets and other characters.</p>
<p>Experts can also use regular expressions, but you have get needed information from the VDRAdmin sources (undocumented feature).</p>",

  ENOHELPMSG        => "No help available yet. For adding or changing text please contact mail\@andreas.vdr-developer.org."
);
