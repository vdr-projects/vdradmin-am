#!/usr/bin/perl
# vim:et:sw=4:ts=4:
#
# VDRAdmin-AM 2005 - 2014 by Andreas Mair <amair.sob@googlemail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
# Or, point your browser to http://www.gnu.org/copyleft/gpl.html
#
# 08.10.2001
#
#

require 5.004;

use vars qw($PROCNAME);

use constant {
    EV_CHANNEL_NAME => 0,
    EV_START        => 1,
    EV_STOP         => 2,
    EV_DURATION     => 3,
    EV_TITLE        => 4,
    EV_SUBTITLE     => 5,
    EV_SUMMARY      => 6,
    EV_VPS          => 7,
    EV_ID           => 8,
    EV_VDR_ID       => 9,
    EV_EVENT_ID     => 10,
    EV_VIDEO        => 11,
    EV_AUDIO        => 12,
    EV_SUBS         => 13,
    EV_VIDEO_RAW    => 14,
    EV_AUDIO_RAW    => 15,
    EV_SUBS_RAW     => 16,
};

my $VERSION = "3.6.10";
my $BASENAME;
my $EXENAME;

BEGIN {
    $PROCNAME = "vdradmind";
    $0 =~ /(^.*\/)/;
    $EXENAME  = $0;
    $BASENAME = $1;
    $0 = $PROCNAME;
    unshift(@INC, "/usr/share/vdradmin/lib");
    unshift(@INC, $BASENAME . "lib/");
}

my $localemod;
if (eval { require Locale::gettext }) {
    $localemod = 'Locale::gettext';
} elsif (eval { require Locale::Messages }) {
    $localemod = 'Locale::Messages';
} else {
    die("Locale::gettext or Locale::Messages is required: $@");
}
my $can_use_bind_textdomain_codeset = 1;
eval {
    $localemod->import(qw(gettext bindtextdomain textdomain bind_textdomain_codeset));
};
if ($@) {
    $localemod->import(qw(gettext bindtextdomain textdomain));
    print("Not using bind_textdomain_codeset(). Please update your Locale::gettext perl module!\n");
    $can_use_bind_textdomain_codeset = undef;
}

require File::Temp;

use locale;
use CGI qw(:no_debug);
use HTTP::Date qw(time2str);
use IO::Socket;
use Template;
use Time::Local qw(timelocal);
use POSIX qw(:sys_wait_h strftime mktime locale_h);
use MIME::Base64 ();
use File::Temp ();
use File::Find ();
use URI ();
use URI::Escape qw(uri_escape);
use HTTP::Tiny;
use IO::Select;

my $can_use_encode = 1;
$can_use_encode = undef unless (eval { require Encode });

my $InetSocketModule = 'IO::Socket::INET';
my $VdrSocketModule = 'IO::Socket::INET';
my $can_use_net_smtp = 1;
$can_use_net_smtp = undef unless (eval { require Net::SMTP });
my $can_use_smtpauth = 1;
$can_use_smtpauth = undef unless (eval { require Authen::SASL });

#Authen::SASL->import(qw(Perl)) if($can_use_smtpauth);

# Some users have problems if the LANGUAGE env variable is set
# so it's cleared here.
$ENV{LANGUAGE} = "";

$SIG{CHLD} = sub { wait };

use strict;

#use warnings;

my $SEARCH_FILES_IN_SYSTEM    = 0;
my $VDR_MAX_SVDRP_LENGTH      = 10000;                        # validate this value
my $SUPPORTED_LOCALE_PREFIXES = "^(cs|de|en|es|fi|fr|hu|it|nl|ru)_";

my $TOOL_AUTOTIMER = 0;
my $TOOL_EPGSEARCH = 1;

my $AT_BY_EVENT_ID = 2;
my $AT_BY_TIME     = 1;
my $AT_OFF         = 0;

my $CHAN_FULL   = 0;
my $CHAN_WANTED = 1;
my $CHAN_TV     = 2;
my $CHAN_RADIO  = 3;
# Channel groups start with this number (to be sorted like strings)
my $CHAN_GROUPS = 40;

sub true ()           { 1 }
sub false ()          { 0 }
sub CRLF ()           { "\r\n" }
# [ internal log level, syslog priority ]
sub LOG_ALWAYS ()     { [ 0, "err"     ] }
sub LOG_FATALERROR () { [ 0, "err"     ] }
sub LOG_ERROR ()      { [ 3, "err"     ] }
sub LOG_WARNING ()    { [ 4, "warning" ] }
sub LOG_INFO ()       { [ 6, "info"    ] }
sub LOG_DEBUG ()      { [ 7, "debug"   ] }

my (%CONFIG, %CONFIG_TEMP);
$CONFIG{LOGLEVEL}             = 4; #LOG_WARNING
$CONFIG{LOGGING}              = 0;
$CONFIG{LOGFILE}              = "syslog";
$CONFIG{MOD_GZIP}             = 0;
$CONFIG{CACHE_BG_UPDATE}      = 1;
$CONFIG{CACHE_TIMEOUT}        = 60;
$CONFIG{CACHE_LASTUPDATE}     = 0;
$CONFIG{CACHE_REC_TIMEOUT}    = 60;
$CONFIG{CACHE_REC_LASTUPDATE} = 0;
$CONFIG{CACHE_REC_ENABLED}    = 0;
$CONFIG{AUTO_SAVE_CONFIG}     = 1;
$CONFIG{HTTP_KEEPALIVE_TIMEOUT} = 10;

#
$CONFIG{VDR_HOST}   = "localhost";
$CONFIG{VDR_PORT}   = 2001; # will be set to 6419 in initial --config if locally installed VDR is >= 1.7.15
$CONFIG{SERVERHOST} = "0.0.0.0";
$CONFIG{SERVERPORT} = 8001;
$CONFIG{LOCAL_NET}  = "0.0.0.0/32";
$CONFIG{VIDEODIR}   = "/video";
$CONFIG{VDRCONFDIR} = "$CONFIG{VIDEODIR}";
$CONFIG{EPGIMAGES}  = "$CONFIG{VIDEODIR}/epgimages";

#
$CONFIG{TEMPLATE}   = "default";
$CONFIG{SKIN}       = "default";
$CONFIG{LOGINPAGE}  = 0;
{ my @a = </dev/dvb/adapter[0-9]>; $CONFIG{RECORDINGS} = scalar(@a) || 1; }
$CONFIG{LANG}       = "";

#
$CONFIG{USERNAME}       = "linvdr";
$CONFIG{PASSWORD}       = "linvdr";
$CONFIG{GUEST_ACCOUNT}  = 0;
$CONFIG{USERNAME_GUEST} = "guest";
$CONFIG{PASSWORD_GUEST} = "guest";
$CONFIG{LOCAL_NET_ONLY}  = 0;

#
$CONFIG{ZEITRAHMEN} = 1;
$CONFIG{TIMES}      = "18:00, 20:00, 21:00, 22:00";
$CONFIG{TL_TOOLTIP} = 1;

#
$CONFIG{EPG_SUMMARY}      = 0;
$CONFIG{EPG_SUBTITLE}     = 1;
$CONFIG{EPG_START_TIME}   = "00:00";

#
$CONFIG{AT_OFFER}        = 0;
$CONFIG{AT_FUNC}         = 1;
$CONFIG{AT_LIFETIME}     = 99;
$CONFIG{AT_PRIORITY}     = 99;
$CONFIG{AT_MARGIN_BEGIN} = 10;
$CONFIG{AT_MARGIN_END}   = 10;
$CONFIG{AT_TOOLTIP}      = 1;
$CONFIG{AT_SORTBY}       = "pattern";
$CONFIG{AT_DESC}         = 0;

#
$CONFIG{ES_SORTBY}       = "pattern";
$CONFIG{ES_DESC}         = 0;

$CONFIG{TM_LIFETIME}     = 99;
$CONFIG{TM_PRIORITY}     = 99;
$CONFIG{TM_MARGIN_BEGIN} = 10;
$CONFIG{TM_MARGIN_END}   = 10;
$CONFIG{TM_TT_TIMELINE}  = 1;
$CONFIG{TM_TT_LIST}      = 1;
$CONFIG{TM_SORTBY}       = "day";
$CONFIG{TM_DESC}         = 0;

#
$CONFIG{ST_FUNC}           = 1;
$CONFIG{ST_REC_ON}         = 0;
$CONFIG{ST_LIVE_ON}        = 1;
$CONFIG{ST_URL}            = "";
$CONFIG{ST_STREAMDEV_HOST} = ""; # streamdev/xineliboutput host
$CONFIG{ST_STREAMDEV_PORT} = 3000;
$CONFIG{ST_XINELIB_PORT}   = 37890;
$CONFIG{ST_VIDEODIR}       = "";
$CONFIG{ST_DIRECT_LINKS_ON} = 0;
$CONFIG{ST_REC_STREAMDEV} = 1;

#
$CONFIG{EPG_PRUNE}     = 0;
$CONFIG{NO_EVENTID}    = 0;
$CONFIG{NO_EVENTID_ON} = "";

#
$CONFIG{AT_SENDMAIL}    = 0;                       # set to 1 and set all the "MAIL_" things if you want email notification on new autotimers.
chomp($CONFIG{MAIL_FROM} = 'autotimer@' . (`hostname -f 2>/dev/null` || "localhost.localdomain"));
$CONFIG{MAIL_TO}        = "you\@example.org";
$CONFIG{MAIL_SERVER}    = "localhost";
$CONFIG{MAIL_AUTH_USER} = "";
$CONFIG{MAIL_AUTH_PASS} = "";

#
$CONFIG{CHANNELS_WANTED}           = "";
$CONFIG{CHANNELS_WANTED_AUTOTIMER} = 0;
$CONFIG{CHANNELS_WANTED_PRG}       = 0;
$CONFIG{CHANNELS_WANTED_PRG2}      = 0;
$CONFIG{CHANNELS_WANTED_TIMELINE}  = 0;
$CONFIG{CHANNELS_WANTED_SUMMARY}   = 0;
$CONFIG{CHANNELS_WANTED_WATCHTV}   = 0;
$CONFIG{CHANNELS_WITHOUT_EPG}      = 0;

#
$CONFIG{PROG_SUMMARY_COLS} = 3;

#
$CONFIG{TV_MIMETYPE}  = "video/x-mpegurl";
$CONFIG{TV_EXT}       = "m3u";
$CONFIG{TV_INTERVAL}  = "5";
$CONFIG{TV_SIZE}      = "half";
$CONFIG{REC_MIMETYPE} = "video/x-mpegurl";
$CONFIG{REC_EXT}      = "m3u";
$CONFIG{REC_SORTBY}   = "name";
$CONFIG{REC_DESC}     = 0;

#
$CONFIG{PS_VIEW} = "ext";

#
$CONFIG{CMD_LINES} = 20;

#
$CONFIG{GUI_POPUP_WIDTH} = 500;
$CONFIG{GUI_POPUP_HEIGHT} = 250;

#
my %FEATURES;
$FEATURES{STREAMDEV}            = 0;  # streamdev plugin available?
$FEATURES{XINELIB}              = 0;  # xineliboutput plugin available?
$FEATURES{REC_RENAME}           = 0;  # RENR/MOVR patch available?
$FEATURES{AUTOTIMER}            = 0;  # use autotimer feature?
$FEATURES{MYVERSION_HR}         = "$VERSION";  # Human readable VDRAdmin-AM version, e.g. 3.6.5
$FEATURES{VDRVERSION}           = 0;  # Numeric VDR version, e.g. 10344
$FEATURES{VDRVERSION_HR}        = ''; # Human readable VDR version, e.g. 1.3.44
$FEATURES{EPGSEARCH_VERSION}    = 0;  # Numeric epgsearch plugin version, e.g. 924
$FEATURES{EPGSEARCH_VERSION_HR} = ''; # Human readable epgsearch plugin version, e.g. 0.9.24
my %EPGSEARCH_SETTINGS;

my $SERVERVERSION = "vdradmind/$VERSION";
my %ERROR_MESSAGE;
my $MY_ENCODING = '';

my ($TEMPLATEDIR, $TEMPLATECACHE, $CONFFILE, $LOGGING, $LOGDIR, $LOGFILE, $LOGLEVEL, $PIDFILE, $AT_FILENAME, $DONE_FILENAME, $BL_FILENAME, $ETCDIR, $CERTSDIR, $USER_CSS);
if (!$SEARCH_FILES_IN_SYSTEM) {
    $ETCDIR        = "${BASENAME}";
    $CERTSDIR      = "${ETCDIR}/certs";
    $TEMPLATEDIR   = "${BASENAME}template";
    $TEMPLATECACHE = "${BASENAME}cache";
    $CONFFILE      = "${BASENAME}vdradmind.conf";
    $LOGDIR        = "${BASENAME}";
    $PIDFILE       = "${BASENAME}vdradmind.pid";
    $AT_FILENAME   = "${BASENAME}vdradmind.at";
    $DONE_FILENAME = "${BASENAME}vdradmind.done";
    $BL_FILENAME   = "${BASENAME}vdradmind.bl";
    $USER_CSS      = "${BASENAME}user.css";
    bindtextdomain("vdradmin", "${BASENAME}locale");
} else {
    $ETCDIR        = "/etc/vdradmin";
    $CERTSDIR      = "${ETCDIR}/certs";
    $TEMPLATEDIR   = "/usr/share/vdradmin/template";
    $TEMPLATECACHE = "/var/cache/vdradmin";
    $LOGDIR        = "/var/log/vdradmin";
    $PIDFILE       = "/var/run/vdradmin/vdradmind.pid";
    $CONFFILE      = "${ETCDIR}/vdradmind.conf";
    $AT_FILENAME   = "${ETCDIR}/vdradmind.at";
    $DONE_FILENAME = "${ETCDIR}/vdradmind.done";
    $BL_FILENAME   = "${ETCDIR}/vdradmind.bl";
    $USER_CSS      = "${ETCDIR}/user.css";
    bindtextdomain("vdradmin", "/usr/share/locale");
}
my $DONE = &DONE_Read || {};

textdomain("vdradmin");

my $UserCSS;
$UserCSS = "user.css" if (-e "$USER_CSS");

my $USE_SHELL_GZIP = false;          # set on false to use the gzip library

my (%EPG, %CHAN, $q, $ACCEPT_GZIP, $SVDRP, $low_time, @RECORDINGS);
my (%mimehash) = (html => "text/html",
                  png  => "image/png",
                  gif  => "image/gif",
                  jpg  => "image/jpeg",
                  css  => "text/css",
                  ico  => "image/x-icon",
                  js   => "text/javascript",
                  swf  => "application/x-shockwave-flash"
);
my @LOGINPAGES = qw(prog_summary prog_list2 prog_timeline prog_list timer_list rec_list);

$SIG{INT}  = \&Shutdown;
$SIG{TERM} = \&Shutdown;
$SIG{HUP}  = \&HupSignal;
$SIG{PIPE} = 'IGNORE';

#
my ($UseSSL, $UseIPv6);
my $DAEMON = 1;
for (my $i = 0 ; $i < scalar(@ARGV) ; $i++) {
    $_ = $ARGV[$i];
    if (/^(-h|--help)$/) {
        $DAEMON = 0;
        print("Usage $EXENAME [OPTION]...\n");
        print("A perl client for the Linux Video Disk Recorder.\n\n");
        print("  -n         --nofork            don't fork\n");
        print("  -c         --config            run configuration dialog\n");
        print("  -d [dir]   --cfgdir [dir]      use [dir] for configuration files\n");
        print("  -k         --kill              kill a forked vdradmind[.pl]\n");
        print("  -p [name]  --pid [name]        name of pidfile (ignored with -n)\n");
        print("  -6         --ipv6              use IPv6\n");
        print("  -s         --ssl               only accept https:// connections\n");
        print("  -l [level] --log [level]       set log level for this session [0 - 7]\n");
        print("  -L [file]  --logfile [file]    set log file for this session\n");
        print("  -h         --help              this message\n");
        exit(0);
    }
    if (/^(--nofork|-n)$/) {
        $DAEMON = 0;
        next;
    }
    if (/^(--cfgdir|-d)$/) {
        $ETCDIR        = $ARGV[ ++$i ];
        $CONFFILE      = "${ETCDIR}/vdradmind.conf";
        $AT_FILENAME   = "${ETCDIR}/vdradmind.at";
        $DONE_FILENAME = "${ETCDIR}/vdradmind.done";
        $BL_FILENAME   = "${ETCDIR}/vdradmind.bl";
        $USER_CSS      = "${ETCDIR}/user.css";
        next;
    }
    if (/^(--config|-c)$/) {
        $DAEMON = 0;
        if (-e $CONFFILE) {
            ReadConfig();
        } elsif ($CONFIG{VDR_PORT} == 2001 &&
                 `vdr --version 2>/dev/null` =~ /^vdr\s+.*?(\d+)\.(\d+)\.(\d+)/mi) {
            my $vdrversion = $1 * 10000 + $2 * 100 + $3;
            $CONFIG{VDR_PORT} = 6419 if ($vdrversion >= 10715);
        }
        LoadTranslation();
        $CONFIG{VDR_HOST}   = Question(gettext("What's your VDR hostname (e.g video.intra.net)?"),               $CONFIG{VDR_HOST});
        $CONFIG{VDR_PORT}   = Question(gettext("On which port does VDR listen to SVDRP queries?"),               $CONFIG{VDR_PORT});
        $CONFIG{SERVERHOST} = Question(gettext("On which address should VDRAdmin-AM listen (0.0.0.0 for any)?"), $CONFIG{SERVERHOST});
        $CONFIG{SERVERPORT} = Question(gettext("On which port should VDRAdmin-AM listen?"),                      $CONFIG{SERVERPORT});
        $CONFIG{USERNAME}   = Question(gettext("Username?"),                                                     $CONFIG{USERNAME});
        $CONFIG{PASSWORD}   = Question(gettext("Password?"),                                                     $CONFIG{PASSWORD});
        $CONFIG{VIDEODIR}   = Question(gettext("Where are your recordings stored?"),                             $CONFIG{VIDEODIR});
        $CONFIG{VDRCONFDIR} = Question(gettext("Where are your VDR's configuration files located?"),             $CONFIG{VDRCONFDIR});

        (my $err = WriteConfig()) =~ s|<br\s*/?>$||gi;
        if ($err) {
            Log(LOG_ALWAYS, $err);
            exit(1);
        }

        print(gettext("Config file written successfully.") . "\n");
        exit(0);
    }
    if (/^(--kill|-k)$/) {
        $DAEMON = 0;
        exit(1) unless (-e $PIDFILE);
        my $pid = getPID($PIDFILE);
        my $killed = defined($pid) ? kill(2, $pid) : -1;
        if ($killed > 0 && -e $PIDFILE) { # Not deleted by kill/Shutdown()?
            unlink($PIDFILE) or Log(LOG_WARNING, "Can't delete pid file '$PIDFILE': $!");
        }
        exit($killed > 0 ? 0 : 1);
    }
    if (/^(--pid|-p)$/) {
        $PIDFILE = $ARGV[ ++$i ];
        next;
    }
    if (/^(--ipv6-all)$/) {
        $UseIPv6 = 2;
        next;
    }
    if (/^(--ipv6|-6)$/) {
        $UseIPv6 = 1;
        next;
    }
    if (/^(--ssl|-s)$/) {
        $UseSSL = 1;
        next;
    }
    if (/^(--log|-l)$/) {
        $LOGLEVEL = $ARGV[ ++$i ];
        $LOGGING = 1;
        next;
    }
    if (/^(--logfile|-L)$/) {
        $LOGFILE = $ARGV[ ++$i ];
        if ($LOGFILE =~ m|/|) {
            ($LOGDIR, $LOGFILE) = $LOGFILE =~ m|^(.+)/([^/]*)$|;
        } else {
            $LOGDIR = ".";
        }
        $LOGGING = 1;
        next;
    }
    if (/^(--displaycall|-i)$/) {
        $DAEMON = 0;
        for (my $z = 0 ; $z < 5 ; $z++) {
            DisplayMessage($ARGV[ $i + 1 ]);
            sleep(3);
        }
        CloseSocket();
        exit(0);
    }
    if (/^(--message|-m)$/) {
        $DAEMON = 0;
        DisplayMessage($ARGV[ $i + 1 ]);
        CloseSocket();
        exit(0);
    }
    if (/^-u$/) {

        # Don't use user.css
        $UserCSS = undef;
    }
}

check_permissions() or exit 1;

if ($UseIPv6) {
    if (eval { require IO::Socket::INET6 }) {
        $InetSocketModule = 'IO::Socket::INET6';
        $VdrSocketModule = 'IO::Socket::INET6' if ($UseIPv6 == 2);
    } else {
        die("ERROR: Can't load module IO::Socket::INET6: $@");
    }
}

ReadConfig();

$LOGGING ||= $CONFIG{LOGGING};
$LOGFILE ||= $CONFIG{LOGFILE};

LoadTranslation();

#use Template::Constants qw( :debug );
# IMHO a better Template Modul ;-)
# some useful options (see below for full list)
my $Xtemplate_vars = { usercss  => $UserCSS,
                       charset  => $MY_ENCODING,
                       gettext  => sub{ $_[0] =~ s/\n\s+//g; return gettext($_[0]); },
                       config   => \%CONFIG,
                       features => \%FEATURES
};

my $Xconfig = {
    START_TAG    => '\<\?\%',                   # tag style
    END_TAG      => '\%\?\>',                   # tag style
    INCLUDE_PATH => $TEMPLATEDIR,               # or list ref
    INTERPOLATE  => 0,                          # expand "$var" in plain text
    PRE_CHOMP    => 1,                          # cleanup whitespace
    POST_CHOMP   => 1,                          # cleanup whitespace
    EVAL_PERL    => 1,                          # evaluate Perl code blocks
    COMPILE_EXT  => 'cache',                    # tuning for templates
    COMPILE_DIR  => $TEMPLATECACHE,             # tuning for templates
    STAT_TTL     => 3600,                       # tuning for templates
    VARIABLES    => $Xtemplate_vars,

    # Developer options:
    #CACHE_SIZE   => 0,
    #STAT_TTL     => 1,
    #DEBUG        => DEBUG_ALL,
};

# create Template object
my $Xtemplate;
eval {
    $Xtemplate = Template->new($Xconfig);
};
if ($@) {
    # Perhaps a cache dir problem, try without it
    chomp(my $err = $@);
    delete @$Xconfig{qw(COMPILE_DIR COMPILE_EXT)};
    $Xtemplate = Template->new($Xconfig);
    Log(LOG_WARNING, "Problem setting up dir for compiled templates, expect degraded performance: $err");
}

# ---- End new template section ----

my $LOG_TO_SYSLOG = 0;
if ($LOGGING && $LOGFILE eq "syslog") {
    eval {
        require Sys::Syslog;
        Sys::Syslog->import(qw(:standard));
        openlog($PROCNAME, "cons,pid", "daemon");
    } and $LOG_TO_SYSLOG = 1;
    if ($@) {
        Log(LOG_WARNING,
            "Error setting up syslog logging, falling back to stderr: $@");
    }
}
if (!$LOG_TO_SYSLOG) {
    *closelog = sub {}; # for Shutdown()
}

if ($CONFIG{MOD_GZIP}) {

    # lib gzipping
    require Compress::Zlib;
}

if (-e "$PIDFILE") {
    my $pid = getPID($PIDFILE);
    if ($pid) {
        Log(LOG_ERROR, "There's already a copy of this program running! (pid: $pid)\n");
        chomp(my $pidproc = `ps -p $pid -o comm=` || "");
        if ($pidproc eq $PROCNAME) {
            Log(LOG_ERROR, "If you feel this is an error, remove $PIDFILE!\n");
            exit(1);
        }
        Log(LOG_ERROR, "The pid $pid is not a running $PROCNAME process, so I'll start anyway.\n");
    } else {
        Log(LOG_ERROR, "$PIDFILE exists, but is empty or contains bogus data, so I'll start anyway.\n");
    }
}

if ($DAEMON) {
    open(STDIN, "</dev/null");
    defined(my $pid = fork) or die "Cannot fork: $!\n";
    if ($pid) {
        Log(LOG_ALWAYS, sprintf(gettext("%s %s started with pid %d."), $EXENAME, $VERSION, $pid));
        writePID($PIDFILE, $pid);
        exit(0);
    }
} else {
    Log(LOG_ALWAYS, sprintf("%s %s started", $EXENAME, $VERSION));
}

my ($Daemon, $Client, $Request);

if ($UseSSL) {
    if (eval { require HTTP::Daemon::SSL; }) {
        my $CERT_FILE = "$CERTSDIR/server-cert.pem";
        die("ERROR: $CERT_FILE missing. Please create it!\n") unless (-e $CERT_FILE);

        my $KEY_FILE = "$CERTSDIR/server-key.pem";
        die("ERROR: $KEY_FILE missing. Please create it!\n") unless (-e $KEY_FILE);

        my $CA_PATH = "$CERTSDIR/ca";
        $CA_PATH = undef unless (-d $CA_PATH);

        my $CA_FILE = "$CERTSDIR/my-ca.pem";
        $CA_FILE = undef unless (-f $CA_FILE);

        $Daemon = HTTP::Daemon::SSL->new(
            LocalPort     => $CONFIG{SERVERPORT},
            LocalAddr     => $CONFIG{SERVERHOST},
            Listen        => 10,
            Reuse         => 1,
            SSL_cert_file => "$CERT_FILE",
            SSL_key_file  => "$KEY_FILE",
            SSL_ca_file   => "$CA_FILE",
            SSL_ca_path   => "$CA_PATH"
        );
        *{HTTP::Daemon::SSL::product_tokens} = sub {return $SERVERVERSION;};
    } else {
        die("ERROR: Can't load module HTTP::Daemon::SSL: $@");
    }
} else {
    if (eval { require HTTP::Daemon; }) {
        $Daemon = HTTP::Daemon->new(
            LocalPort => $CONFIG{SERVERPORT},
            LocalAddr => $CONFIG{SERVERHOST},
            Listen    => 10,
            Reuse     => 1
        );
        *{HTTP::Daemon::product_tokens} = sub {return $SERVERVERSION;};
    } else {
        die("ERROR: Can't load module HTTP::Daemon: $@");
    }
}

if (!$Daemon) {
    my $host = $CONFIG{SERVERHOST} || '(SERVERHOST missing)';
    my $port = $CONFIG{SERVERPORT} || '(SERVERPORT missing)';
    die("Can't start server at $host:$port: $@\n");
}

$SIG{__DIE__} = \&SigDieHandler;

my @reccmds = loadCommandsConf("$CONFIG{VDRCONFDIR}/reccmds.conf");
my @vdrcmds = loadCommandsConf("$CONFIG{VDRCONFDIR}/commands.conf");

##
# Mainloop
##
my ($MyURL, $Referer, $Query, $Guest);
my @GUEST_USER = qw(prog_detail prog_list prog_list2 prog_timeline timer_list at_timer_list epgsearch_list
  prog_summary rec_list rec_detail show_top toolbar show_help about);
my @TRUSTED_USER = (
    @GUEST_USER, qw(prog_detail_form prog_detail_aktion at_timer_edit at_timer_new at_timer_save at_timer_test at_timer_delete
      epgsearch_upds epgsearch_edit epgsearch_save epgsearch_save_template epgsearch_delete_template epgsearch_delete epgsearch_toggle timer_new_form timer_add timer_delete timer_toggle rec_delete rec_rename rec_edit
      config prog_switch rc_show rc_hitk grab_picture at_timer_toggle tv_show tv_switch
      live_stream rec_stream rec_stream_folder rec_play rec_cut force_update vdr_cmds export_channels_m3u epgsearch_config epgsearch_bl_edit epgsearch_bl_save epgsearch_bl_delete)
);
my $MyStreamBase = "./vdradmin.";

$MyURL = "./vdradmin.pl";

my @Connections = ();

$CONFIG{CACHE_LASTUPDATE} = 0;
$CONFIG{CACHE_REC_LASTUPDATE} = 0;

while (true) {

    @Connections = grep {$_->{socket}->connected} @Connections;
    my $fd_set = '';
    vec($fd_set, $Daemon->fileno, 1) = 1;
    foreach my $c (@Connections) {
        vec($fd_set, $c->{socket}->fileno, 1) = 1;
    }

    my $n_ready = select($fd_set, undef, undef, 2);
    Log(LOG_DEBUG, sprintf("[DAEMON] select() -> %s", printVec($fd_set))) if $n_ready > 0;

    my $now = time();

    # update EPG
    if ($n_ready == 0
            && ($CONFIG{CACHE_BG_UPDATE} == 1
                || $CONFIG{AT_FUNC} && $FEATURES{AUTOTIMER}
            )) {
        if (UptoDate() != 0) {
            Log(LOG_DEBUG, "[EPG] Updating EPG data in the background FAILED, trying again in 60secs.");
            $CONFIG{CACHE_LASTUPDATE} = $now + 60 - $CONFIG{CACHE_TIMEOUT} * 60;
        }
    }

    if (vec($fd_set, $Daemon->fileno, 1)) {
        my $con = $Daemon->accept();
        if ($con) {
            Log(LOG_DEBUG, sprintf("[DAEMON] accepted fd=%d, peer=%s", $con->fileno, $con->peerhost));
            push(@Connections, {socket => $con, ttl => undef});
        }
        next;
    }
    my @new = ();
    my $found = undef;
    foreach my $c (@Connections) {
        if (vec($fd_set, $c->{socket}->fileno, 1)) {
            $c->{ttl} = undef;
            if (!$found) {
                $found = $c;
                # don't copy
            } else {
                push(@new, $c);
            }
        } else {
            # no incoming data
            if ($c->{ttl} && $now >= $c->{ttl}) {
                Log(LOG_DEBUG, sprintf("[CLIENT(%d)] keep-alive timeout\n", $c->{socket}->fileno));
                close($c->{socket});
            } else {
                $c->{ttl} = $now + $CONFIG{HTTP_KEEPALIVE_TIMEOUT} unless $c->{ttl};
                push(@new, $c);
            }
        }
    }
    @Connections = @new;
    next unless $found;
    # move to the end
    push(@Connections, $found);
    $Client = $found->{socket};
    undef $found;

    if ($CONFIG{LOCAL_NET_ONLY} && !subnetcheck($Client->peerhost, $CONFIG{LOCAL_NET})) {
        closeClient();
        next;
    }

    $Client->timeout(2);
    my $req = $Client->get_request();
    if ($req) {
        processRequest($req);
    } else {
        Log(LOG_DEBUG, sprintf("[CLIENT(%d)] get_request() failed: %s", $Client->fileno, $Client->reason));
        closeClient();
    }

}

#############################################################################
#############################################################################

sub printVec {
    my $vec = shift;
    my @fdarr = ();
    for (my $i = 0; $i < length($vec) * 8; $i++) {
        push(@fdarr, $i) if (vec($vec, $i, 1));
    }
    return join(',', @fdarr);
}

sub closeClient {
    if ($Client) {
        Log(LOG_DEBUG, sprintf("CLIENT(%d)] close()", $Client->fileno));
        @Connections = grep {$_->{socket} != $Client} @Connections;
        close($Client);
        undef $Client;
    }
}

sub processRequest {
    my $req = shift;

    $ACCEPT_GZIP = 0;

    #print("REQUEST: $raw_request\n");
    my $raw_request = $1 if ($req->as_string =~ /^([^\r\n]++)\r*\n/);
    Log(LOG_DEBUG, sprintf("[CLIENT(%d)] $raw_request\n", $Client->fileno));
    if ($req->uri =~ /(\/[\w\.\/-\:]*)(?:\?([\w=&\.\+\%-\:\!\@\~\#]+))?$/) {
        ($Request, $Query) = ($1, $2);
    } else {
        Error("404", gettext("Not found"), gettext("The requested URL was not found on this server!"));
        return;
    }

    $Request =~ s|^/+|/|;
    local $ENV{HTTP_HOST};

    # parse header
    my ($username, $password, $http_useragent);
    $Referer = $req->header("Referer");
    $ENV{HTTP_HOST} = $req->header("Host");
    ($username, $password) = split(":", MIME::Base64::decode_base64($1), 2) if ($req->header("Authorization") =~ /basic (.*)/i);
    $http_useragent = $req->header("User-Agent");
    $ACCEPT_GZIP = 1 if ($req->header("Accept-Encoding") =~ /gzip/);

    my ($http_status, $bytes_transfered);

    # authenticate
    #print("Username: $username / Password: $password\n");
    my $checkpass = defined($username) && defined($password);
    if (($checkpass && $CONFIG{USERNAME} eq $username && $CONFIG{PASSWORD} eq $password)
            || subnetcheck($Client->peerhost, $CONFIG{LOCAL_NET})) {
        $Guest = 0;
    } elsif (($checkpass && $CONFIG{USERNAME_GUEST} eq $username && $CONFIG{PASSWORD_GUEST} eq $password) && $CONFIG{GUEST_ACCOUNT}) {
        $Guest = 1;
    } else {
        ($http_status, $bytes_transfered) = headerNoAuth();
        Log(LOG_INFO, "[ACCESS] " . access_log($Client->peerhost, $username, $raw_request, $http_status, $bytes_transfered, $Request, $http_useragent));
        return;
    }

    # serve request
    $SVDRP = SVDRP->new;
    $MyURL = "." . $Request;
    if ($Request eq "/vdradmin.pl" || $Request eq "/vdradmin." . $CONFIG{TV_EXT} || $Request eq "/vdradmin." . $CONFIG{REC_EXT}) {
        $q = CGI->new($Query);
        my $aktion;
        my ($real_aktion, $dummy) = split("#", $q->param("aktion"), 2);
        if ($real_aktion eq "at_timer_aktion") {
            $real_aktion = "at_timer_save";
            $real_aktion = "at_timer_delete" if ($q->param("at_delete"));
            $real_aktion = "force_update" if ($q->param("at_force"));
            $real_aktion = "at_timer_test" if ($q->param("test"));
        } elsif ($real_aktion eq "timer_aktion") {
            $real_aktion = "timer_delete" if ($q->param("timer_delete"));
            $real_aktion = "timer_toggle" if ($q->param("timer_active") || $q->param("timer_inactive"));
        } elsif ($real_aktion eq "epgsearch_aktion") {
            $real_aktion = "epgsearch_save";
            $real_aktion = "epgsearch_save_template" if ($q->param("save_template"));
            $real_aktion = "epgsearch_delete_template" if ($q->param("delete_template"));
            $real_aktion = "epgsearch_delete" if ($q->param("delete"));
            $real_aktion = "epgsearch_edit" if ($q->param("single_test"));
            $real_aktion = "epgsearch_list" if ($q->param("execute"));
            $real_aktion = "epgsearch_list" if ($q->param("favorites"));
            $real_aktion = "epgsearch_list" if ($q->param("exit"));
            $real_aktion = "epgsearch_upds" if ($q->param("upds"));
        } elsif ($real_aktion eq "epgsearch_config_aktion") {
            $real_aktion = "epgsearch_config";
            $real_aktion = "epgsearch_bl_delete" if ($q->param("delete"));
        } elsif ($real_aktion eq "epgsearch_bl_aktion") {
            $real_aktion = "epgsearch_bl_save";
            $real_aktion = "epgsearch_config" if ($q->param("exit"));
        }

        my @ALLOWED_FUNCTIONS;
        $Guest ? (@ALLOWED_FUNCTIONS = @GUEST_USER) : (@ALLOWED_FUNCTIONS = @TRUSTED_USER);

        for (@ALLOWED_FUNCTIONS) {
            ($aktion = $real_aktion) if ($real_aktion eq $_);
        }
        if ($aktion) {
            eval("(\$http_status, \$bytes_transfered) = $aktion();");
        } else {

            # XXX redirect to no access template
            Error("403", gettext("Forbidden"), gettext("You don't have permission to access this function!"));
            next;
        }
    } elsif ($Request eq "/") {
        $MyURL = "./vdradmin.pl";
        ($http_status, $bytes_transfered) = show_index();
    } elsif ($Request eq "/navigation.html") {
        ($http_status, $bytes_transfered) = show_navi();
    } else {
        ($http_status, $bytes_transfered) = SendFile($Request);
    }
    Log(LOG_INFO, "[ACCESS] " . access_log($Client->peerhost, $username, $raw_request, $http_status, $bytes_transfered, $Request, $http_useragent));
    $SVDRP->close;
}

sub check_permissions {
    my $rc = 1;
    check_rw_dir($ETCDIR) or $rc = 0;
    check_rw_dir($CERTSDIR) if ($UseSSL);
    check_rw_dir($TEMPLATECACHE) or $rc = 0;
    # Don't check permissions when logging to syslog or stderr
    !$LOGFILE
        or $LOGFILE eq "syslog" or $LOGFILE eq "stderr"
        or check_rw_dir($LOGDIR) or $rc = 0;
    check_rw_file($PIDFILE) or $rc = 0 if $DAEMON;
    check_rw_file($CONFFILE) or $rc = 0;

    if ($CONFIG{AT_FUNC} || $FEATURES{AUTOTIMER}) {
        check_rw_file($AT_FILENAME) or $rc = 0;
        check_rw_file($DONE_FILENAME) or $rc = 0;
        check_rw_file($BL_FILENAME) or $rc = 0;
    }

    return $rc;
}

sub check_rw_dir {
    my $dir = shift;

#    print "Checking directory '$dir':\n";
    if (-e "$dir") {
        if (! -d _) {
            print "ERROR: '$dir' is NOT a directory!\n";
            return 0;
        }
        if (-r _) {
#            print "directory '$dir' is readable!\n";
        } else {
            print "ERROR: directory '$dir' is NOT readable!\n";
            return 0;
        }
        if (-w _) {
#            print "directory '$dir' is writable!\n";
        } else {
            print "ERROR: directory '$dir' is NOT writable!\n";
            return 0;
        }
    } else {
        print "ERROR: directory '$dir' is missing!\n";
        return 0;
    }

    return 1;
}

sub check_rw_file {
    my $file = shift;

#    print "Checking file '$file':\n";
    if (-e "$file") {
        if (-d _) {
            print "ERROR: '$file' is a directory!\n";
            return 0;
        }
        if (-r _) {
#            print "file '$file' is readable!\n";
        } else {
            print "ERROR: file '$file' is NOT readable!\n";
            return 0;
        }
        if (-w _) {
#            print "file '$file' is writable!\n";
        } else {
            print "ERROR: file '$file' is NOT writable!\n";
            return 0;
        }
    } else {
        $file =~ /(^.*)\/[^\/]*$/;
        return check_rw_dir($1);
    }

    return 1;
}

sub GetChannelDesc {    #TODO: unused
    my (%hash);
    for (@{$CHAN{$CHAN_FULL}->{channels}}) {
        $hash{ $_->{id} } = $_->{name};
    }
    return (%hash);
}

sub GetChannelDescByNumber {
    my $vdr_id = shift;

    if ($vdr_id) {
        for (@{$CHAN{$CHAN_FULL}->{channels}}) {
            if ($_->{vdr_id} == $vdr_id) {
                return ($_->{name});
            }
        }
    } else {
        return (0);
    }
}

sub include {
    my $file = shift;
    if ($file) {
        eval(ReadFile($file));
    }
}

sub ReadFile {
    my $file = shift;
    return if (!$file);

    open(I18N, $file) || HTMLError(sprintf($ERROR_MESSAGE{cant_open}, $file));
    my $buf = join("", <I18N>);
    close(I18N);
    return ($buf);
}

sub GetChannelID {    #TODO: unused
    my ($sid) = $_[0];
    for (@{$CHAN{$CHAN_FULL}->{channels}}) {
        if ($_->{id} == $sid) {
            return ($_->{number});
        }
    }
}

sub EURL {            #TODO: unused
    my ($text) = @_;
    $text =~ s/([^0-9a-zA-Z])/sprintf("%%%2.2x", ord($1))/ge;
    return ($text);
}

sub HTMLError {
    my $error = join("", @_);
    $CONFIG{CACHE_LASTUPDATE} = 0;
    my $vars = { error => $error };
    return showTemplate("error.html", $vars);
}

sub FillInZero {    #TODO: unused
    my ($str, $length) = @_;
    while (length($str) < $length) {
        $str = "0$str";
    }
    return ($str);
}

sub MHz {
    my $frequency = shift;
    while ($frequency > 20000) {
        $frequency /= 1000;
    }
    return (int($frequency));
}

sub ChanTree { #TODO? save channel in each list as reference
    undef(%CHAN);
    my (@CHANNELS_FULL, @CHANNELS_WANTED, @CHANNELS_TV, @CHANNELS_RADIO);
    my $group_name = "";
    my $group_number = $CHAN_GROUPS - 1;
    if (!$FEATURES{VDRVERSION}) {
        # first connection - have to get version
        $SVDRP->command("help");
        $SVDRP->readresponse;
    }
    my $use_groups = ($FEATURES{VDRVERSION} >= 10600);
    if ($use_groups) {
        $SVDRP->command("lstc :groups");
    } else {
        $SVDRP->command("lstc");
    }
    my ($DATA) = $SVDRP->readresponse;
    while ($_ = shift @$DATA) {
        chomp;
        my ($vdr_id, $temp) = split(/ /, $_, 2);
        if ($use_groups && $temp =~ /^:(.*)/) {
            # :group_name
            $group_name = $1;
            $group_number += 1;
            $CHAN{$group_number}->{title}    = $group_name;
            $CHAN{$group_number}->{channels} = [];
            next;
        }
        my ($name, $frequency, $polarization, $source, $symbolrate, $vpid, $apid, $tpid, $ca, $service_id, $nid, $tid, $rid) = split(/\:/, $temp);
        $name =~ /(^[^,;]*).*/;    #TODO?
        $name = $1;
        my $uniq_id = $source . "-" . $nid . "-" . ($nid || $tid ? $tid : $frequency) . "-" . $service_id;
        $uniq_id .= "-" . $rid if ($rid != 0);
        push(@CHANNELS_FULL,
             {  vdr_id       => $vdr_id,
                name         => $name,
                frequency    => MHz($frequency),
                polarization => $polarization,
                source       => $source,
                symbolrate   => $symbolrate,
                vpid         => $vpid,
                apid         => $apid,
                tpid         => $tpid,
                ca           => $ca,
                service_id   => $service_id,
                nid          => $nid,
                tid          => $tid,
                rid          => $rid,
                uniq_id      => $uniq_id
             }
        );

        if ($CONFIG{CHANNELS_WANTED}) {
            for my $n (split(",", $CONFIG{CHANNELS_WANTED})) {
                if ($n eq $vdr_id) {
                    push(@CHANNELS_WANTED,
                        {  vdr_id       => $vdr_id,
                           name         => $name,
                           frequency    => MHz($frequency),
                           polarization => $polarization,
                           source       => $source,
                           symbolrate   => $symbolrate,
                           vpid         => $vpid,
                           apid         => $apid,
                           tpid         => $tpid,
                           ca           => $ca,
                           service_id   => $service_id,
                           nid          => $nid,
                           tid          => $tid,
                           rid          => $rid,
                           uniq_id      => $uniq_id
                        }
                    );
                    last;
                }
            }
        }

        if ($vpid) {
            push(@CHANNELS_TV,
                {  vdr_id       => $vdr_id,
                   name         => $name,
                   frequency    => MHz($frequency),
                   polarization => $polarization,
                   source       => $source,
                   symbolrate   => $symbolrate,
                   vpid         => $vpid,
                   apid         => $apid,
                   tpid         => $tpid,
                   ca           => $ca,
                   service_id   => $service_id,
                   nid          => $nid,
                   tid          => $tid,
                   rid          => $rid,
                   uniq_id      => $uniq_id
                 }
            );
        } elsif ($apid) {
            push(@CHANNELS_RADIO,
                {  vdr_id       => $vdr_id,
                   name         => $name,
                   frequency    => MHz($frequency),
                   polarization => $polarization,
                   source       => $source,
                   symbolrate   => $symbolrate,
                   vpid         => $vpid,
                   apid         => $apid,
                   tpid         => $tpid,
                   ca           => $ca,
                   service_id   => $service_id,
                   nid          => $nid,
                   tid          => $tid,
                   rid          => $rid,
                   uniq_id      => $uniq_id
                 }
            );
        }
        if ($use_groups && $group_name) {
            push(@{$CHAN{$group_number}->{channels}},
                 {  vdr_id       => $vdr_id,
                    name         => $name,
                    frequency    => MHz($frequency),
                    polarization => $polarization,
                    source       => $source,
                    symbolrate   => $symbolrate,
                    vpid         => $vpid,
                    apid         => $apid,
                    tpid         => $tpid,
                    ca           => $ca,
                    service_id   => $service_id,
                    nid          => $nid,
                    tid          => $tid,
                    rid          => $rid,
                    uniq_id      => $uniq_id
                 }
            );
        }
    }
    $CHAN{$CHAN_FULL}->{title}    = gettext('All channels');
    $CHAN{$CHAN_FULL}->{channels} = \@CHANNELS_FULL;
    if (@CHANNELS_WANTED) {
        $CHAN{$CHAN_WANTED}->{title}    = gettext('Selected channels');
        $CHAN{$CHAN_WANTED}->{channels} = \@CHANNELS_WANTED;
    }
    if (@CHANNELS_TV) {
        $CHAN{$CHAN_TV}->{title}    = gettext('TV channels');
        $CHAN{$CHAN_TV}->{channels} = \@CHANNELS_TV;
    }
    if (@CHANNELS_RADIO) {
        $CHAN{$CHAN_RADIO}->{title}    = gettext('Radio channels');
        $CHAN{$CHAN_RADIO}->{channels} = \@CHANNELS_RADIO;
    }

    # Sort channel lists by channel name
    foreach my $idx (keys(%CHAN)) {
        @{$CHAN{$idx}->{channels}} = sort {$a->{name} cmp $b->{name}} @{$CHAN{$idx}->{channels}}
    }
}

sub getChannelGroups {
    my $url = shift;
    my $cur = shift;
    my @ch_grps;
    foreach (sort(keys(%CHAN))) {
        push(@ch_grps,
            { id => $_,
              title => $CHAN{$_}->{title},
              url => $url . "&amp;wanted_channels=$_",
              selected => $_ eq $cur ? 1 : undef
            }
        );
    }
    return \@ch_grps;
}

sub get_vdrid_from_channelid {
    my $channel_id = shift;
    if ($channel_id =~ /^(\d*)$/) {    # vdr 1.0.x & >= vdr 1.1.15
        for my $channel (@{$CHAN{$CHAN_FULL}->{channels}}) {
            if ($channel->{service_id} == $1) {
                return ($channel->{vdr_id});
            }
        }
    } elsif ($channel_id =~ /^(.*)-(.*)-(.*)-(.*)-(.*)$/) {
        for my $channel (@{$CHAN{$CHAN_FULL}->{channels}}) {
            if (   $channel->{source} eq $1
                && $channel->{nid} == $2
                && ($channel->{nid} ? $channel->{tid} : $channel->{frequency}) == $3
                && $channel->{service_id} == $4
                && $channel->{rid} == $5)
            {
                return ($channel->{vdr_id});
            }
        }
    } elsif ($channel_id =~ /^(.*)-(.*)-(.*)-(.*)$/) {
        for my $channel (@{$CHAN{$CHAN_FULL}->{channels}}) {
            if (   $channel->{source} eq $1
                && $channel->{nid} == $2
                && ($channel->{nid} || $channel->{tid} ? $channel->{tid} : $channel->{frequency}) == $3
                && $channel->{service_id} == $4)
            {
                return ($channel->{vdr_id});
            }
        }
    } else {
        print "Can't find channel_id $channel_id\n";
    }
}

#
#  Used to store channelid (instead of channel number) into auto timer entries.
#  Allows channels to be moved around without auto timer channels being messed up.
#  Use at your own risk... tvr@iki.fi
#
sub get_channelid_from_vdrid {
    my $vdr_id = shift;
    if ($vdr_id) {
        my @C = grep($_->{vdr_id} == $vdr_id, @{$CHAN{$CHAN_FULL}->{channels}});
        if (scalar(@C) == 1) {
            my $ch = $C[0];
            return $ch->{source} . "-" . $ch->{nid} . "-" . ($ch->{nid} || $ch->{tid} ? $ch->{tid} : $ch->{frequency}) . "-" . $ch->{service_id};
        }
    }
}

sub get_name_from_uniqid {
    my $uniq_id = shift;
    if ($uniq_id) {

        # Kanalliste nach identischer vdr_id durchsuchen
        my @C = grep($_->{uniq_id} eq $uniq_id, @{$CHAN{$CHAN_FULL}->{channels}});
#        foreach (@{$CHAN{$CHAN_FULL}->{channels}}) {
#            printf("(%s) ($uniq_id)\n", $_->{uniq_id});
#            return $_->{name} if ($_->{uniq_id} eq $uniq_id);
#        }

        # Es darf nach Spec nur eine Übereinstimmung geben
        if (scalar(@C) == 1) {
            return $C[0]->{name};
        }
    }
}

sub get_name_from_vdrid {
    my $vdr_id = shift;
    if ($vdr_id) {

        # Kanalliste nach identischer vdr_id durchsuchen
        my @C = grep($_->{vdr_id} == $vdr_id, @{$CHAN{$CHAN_FULL}->{channels}});

        # Es darf nach Spec nur eine Übereinstimmung geben
        if (scalar(@C) == 1) {
            return $C[0]->{name};
        }
    }
}

sub get_channel_from_vdrid {
    my $vdr_id = shift;
    if ($vdr_id) {

        # Kanalliste nach identischer vdr_id durchsuchen
        my @C = grep($_->{vdr_id} == $vdr_id, @{$CHAN{$CHAN_FULL}->{channels}});

        # Es darf nach Spec nur eine Übereinstimmung geben
        if (scalar(@C) == 1) {
            return $C[0];
        }
    }
}

sub get_transponder_from_vdrid {
    my $vdr_id = shift;
    if ($vdr_id) {

        # Kanalliste nach identischer vdr_id durchsuchen
        my @C = grep($_->{vdr_id} == $vdr_id, @{$CHAN{$CHAN_FULL}->{channels}});

        # Es darf nach Spec nur eine Übereinstimmung geben
        if (scalar(@C) == 1) {
            return ("$C[0]->{source}-$C[0]->{frequency}-$C[0]->{polarization}");
        }
    }
}

sub get_ca_from_vdrid {
    my $vdr_id = shift;
    if ($vdr_id) {

        # Kanalliste nach identischer vdr_id durchsuchen
        my @C = grep($_->{vdr_id} == $vdr_id, @{$CHAN{$CHAN_FULL}->{channels}});

        # Es darf nach Spec nur eine Übereinstimmung geben
        if (scalar(@C) == 1) {
            return ($C[0]->{ca});
        }
    }
}

#############################################################################
# common helpers
#############################################################################

# remove spaces around string
sub trim($)
{
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

# remove leading whitespaces from string
sub ltrim($)
{
    my $string = shift;
    $string =~ s/^\s+//;
    return $string;
}

# remove trailing whitespaces from string
sub rtrim($)
{
    my $string = shift;
    $string =~ s/\s+$//;
    return $string;
}

# quotemeta() for $MY_ENCODING byte strings (with zero utf8 flag)
sub my_quotemeta
{
    my $str = shift;
    if ($can_use_encode) {
        $str = Encode::decode($MY_ENCODING, $str);
        return Encode::encode($MY_ENCODING, quotemeta($str));
    } else {
        return quotemeta($str);
    }
}

# case-insensitive compare on byte strings
sub ciCmp {
    my ($a, $b) = @_;
    if (utf8::is_utf8($a)) {
        $a = lc($a);
    } elsif ($can_use_encode) {
        $a = lc(Encode::decode($MY_ENCODING, $a));
    }
    if (utf8::is_utf8($b)) {
        $b = lc($b);
    } elsif ($can_use_encode) {
        $b = lc(Encode::decode($MY_ENCODING, $b));
    }
    return $a cmp $b;
}

sub my_truncate {
    my ($text, $len) = @_;
    my $decode = !utf8::is_utf8($text) && $can_use_encode;
    $text = Encode::decode($MY_ENCODING, $text) if ($decode);
    $text = substr($text, 0, $len - 3) . "..." if (length($text) >= $len);
    $text = Encode::encode($MY_ENCODING, $text) if ($decode);
    return $text;
}

#############################################################################
# EPG functions
#############################################################################

sub EPG_getEntry {
    my $vdr_id = shift;
    my $epg_id = shift;
    if ($vdr_id && $epg_id) {
        for (@{ $EPG{$vdr_id} }) {

            #if($_->{id} == $epg_id) {
            if ($_->[EV_EVENT_ID] == $epg_id) {
                return ($_);
            }
        }
    }
}

sub getNumberOfElements {    #TODO: unused
    my $ref = shift;
    if ($ref) {
        return (@{$ref});
    } else {
        return (0);
    }
}

sub getElement {
    my $ref   = shift;
    my $index = shift;
    if ($ref) {
        return ($ref->[$index]);
    } else {
        return;
    }
}

sub EPG_buildTree {
    $SVDRP->command("lste");
    my ($i, @events);
    my ($id, $bc) = (1, 0);
    $low_time = time;
    undef(%EPG);
    my $to_charset = $MY_ENCODING;
    my $from_charset = $SVDRP->encoding;
    my $recode = ($can_use_encode && $from_charset && $to_charset && ($from_charset ne $to_charset))? 1 : 0;
    my $SOCK = $SVDRP->socket;
    while($_ = <$SOCK>) {
        chomp;
        Encode::from_to($_, $from_charset, $to_charset) if ($recode);
        if (/^... /) {
            last;
        }
        if (/^...-C ([^ ]+) *(.*)/) {
            undef(@events);
            my ($channel_id, $channel_name) = ($1, $2);
            my $vdr_id = get_vdrid_from_channelid($channel_id);
            if ($CONFIG{EPG_PRUNE} > 0 && $vdr_id > $CONFIG{EPG_PRUNE}) {

                # diesen channel nicht einlesen
                while($_ = <$SOCK>) {
                    Encode::from_to($_, $from_charset, $to_charset) if ($recode);
                    last if (/^...-c/);
                    last if (/^... /);
                }
            } else {
                $bc++;
                while($_ = <$SOCK>) {
                    Encode::from_to($_, $from_charset, $to_charset) if ($recode);
                    my $tok = substr($_, 3, 2);
                    my $rest = substr($_, 6);
                    if ($tok eq "-E") {
                        # no need for chomp here - split() will take care
                        my ($event_id, $time, $duration) = split(/ /, $rest, 4);
                        my ($title, $subtitle, $summary, $vps, $video, $audio, $subs, @video_raw, @audio_raw, @subs_raw);
                        @video_raw = @audio_raw = @subs_raw = ();
                        while($_ = <$SOCK>) {
                            chomp;
                            Encode::from_to($_, $from_charset, $to_charset) if ($recode);
                            $tok = substr($_, 3, 2);
                            $rest = substr($_, 6);
                            if ($tok eq "-T") { $title    = $rest }
                            elsif ($tok eq "-S") { $subtitle = $rest; }
                            elsif ($tok eq "-D") { $summary  = $rest; }
                            elsif ($tok eq "-X") {
                                my ($what, $garbage, $lang, $descr) = split(/ /, $rest, 4);
                                if ($what eq "1") {
                                    push (@video_raw, join(" ", "X", $rest));
                                    $video .= ", " if($video);
                                    $video .= $descr;
                                    $video .= " (" . $lang . ")";
                                }
                                elsif ($what eq "2") {
                                    push (@audio_raw, join(" ", "X", $rest));
                                    $audio .= ", " if ($audio);
                                    $audio .= ($descr ? $descr . " (" . $lang . ")" : $lang);
                                }
                                elsif ($what eq "3") {
                                    push (@subs_raw, join(" ", "X", $rest));
                                    $subs .= ", " if ($subs);
                                    $subs .= ($descr ? $descr . " (" . $lang . ")" : $lang);
                                }
                            }
                            elsif ($tok eq "-V") { $vps  = $rest; }
                            elsif ($tok eq "-e") {

                                #
                                $low_time = $time if ($time < $low_time);
                                push(@events,
                                     [  $channel_name,      # EV_CHANNEL_NAME
                                        $time,              # EV_START
                                        $time + $duration,  # EV_STOP
                                        $duration,          # EV_DURATION
                                        $title,             # EV_TITLE
                                        $subtitle,          # EV_SUBTITLE
                                        $summary,           # EV_SUMMARY
                                        $vps,               # EV_VPS
                                        $id,                # EV_ID
                                        $vdr_id,            # EV_VDR_ID
                                        $event_id,          # EV_EVENT_ID
                                        $video,             # EV_VIDEO
                                        $audio,             # EV_AUDIO
                                        $subs,              # EV_SUBS
                                        \@video_raw,        # EV_VIDEO_RAW
                                        \@audio_raw,        # EV_AUDIO_RAW
                                        \@subs_raw,         # EV_SUBS_RAW
                                     ]
                                );
                                $id++;
                                last;
                            }
                            elsif ($tok =~ /^ /) {
                                last;
                            }
                        }
                    }
                    elsif ($tok eq "-c") {
                        if ($FEATURES{VDRVERSION} < 10305) { # EPG is sorted by date since VDR 1.3.5
                            my ($last) = 0;
                            my (@temp);
                            for (sort({ $a->[EV_START] <=> $b->[EV_START] } @events)) {
                                next if ($last == $_->[EV_START]);
                                push(@temp, $_);
                                $last = $_->[EV_START];
                            }
                            $EPG{$vdr_id} = [@temp];
                        } else {
                            $EPG{$vdr_id} = [@events];
                        }
                        last;
                    }
                    elsif ($tok =~ /^ /) {
                        last;
                    }
                }
            }
        }
    }
    Log(LOG_INFO, "[EPG] EPGTree: $id events, $bc broadcasters (lowtime $low_time)");
}

#############################################################################
# Socket functions
#############################################################################

sub PrintToClient {
    my $string = join("", @_);
    return if (!defined($string));
    print($Client $string) if ($Client && $Client->connected());
}

sub ParseRequest {
    my $Socket = shift;
    my (@Request, $Line);
    do {
        $Line = <$Socket>;
        $Line =~ s/\r\n//g;
        push(@Request, $Line);
    } while ($Line);
    return (@Request);
}

sub CloseSocket {
    $SVDRP->close() if (defined $SVDRP);
}

sub OpenSocket {
    $SVDRP = SVDRP->new;
}

sub SendCMD {
    my $cmd = join("", @_);

    if (($FEATURES{VDRVERSION} < 10336) && (length($cmd) > $VDR_MAX_SVDRP_LENGTH)) {
        Log(LOG_FATALERROR, "[INT] SendCMD(): command is too long(" . length($cmd) . "): " . substr($cmd, 0, 10));
        return;
    }

    OpenSocket() if (!$SVDRP);

    my @output;
    $SVDRP->command($cmd);
    while ($_ = $SVDRP->readoneline) {
        push(@output, $_);
    }
    return (@output);
}

sub GZip {
    my $content = shift;
    my $filename = new File::Temp("vdradmin-XXXXX", UNLINK => 1);
    open(PIPE, "| gzip -9 - > $filename") || die "Can't open pipe to gzip ($!)";
    print PIPE $$content;
    close(PIPE);

    open(FILE, $filename) || die "Can't open $filename ($!)";
    my $result = join("", <FILE>);
    close(FILE);

    unlink($filename);

    #my $pid = open2(*RDFH, *WTFH, "gzip -1 -c -");
    #print "Write\n";
    #print WTFH $$content;
    #print "Done\n";
    #close(WTFH);
    #my $result = join("", <RDFH>);
    #close(RDFH);
    #waitpid($pid, 0);

    return ($result);
}

sub LibGZip {
    my $content = shift;
    return (Compress::Zlib::memGzip($$content));
}

sub header {
    my ($status, $ContentType, $data, $filename, $caching, $lastmod) = @_;
    Log(LOG_FATALERROR, "[INT] Template Error: " . $Xtemplate->error())
      if ($status >= 500);
    if ($ACCEPT_GZIP && $CONFIG{MOD_GZIP}) {
        if ($USE_SHELL_GZIP) {
            $data = GZip(\$data);
        } else {
            $data = LibGZip(\$data);
        }
    }

    my $status_text = "OK" if ($status eq "200");
    my $now = time();
    my $resp = HTTP::Response->new($status, $status_text);

    $resp->header('Date' => time2str($now));
    if (!$caching || $ContentType =~ /text\/html/) {
        $resp->header('Cache-Control' => "max-age=0");
        $resp->header('Cache-Control' => "private");
        $resp->header('Pragma' => "no-cache");
        $resp->header('Expires' => "Thu, 01 Jan 1970 00:00:00 GMT");
    } else {
        $resp->header('Expires' => time2str($now + 3600));
        $resp->header('Cache-Control' => "public, max-age=3600");
    }
    if ($lastmod) {
        $lastmod = $now if ($lastmod > $now); # HTTP 1.1, 14.29
        $resp->header('Last-Modified' => time2str($lastmod));
    }
    $resp->header('Content-encoding' => "gzip") if ($CONFIG{MOD_GZIP} && $ACCEPT_GZIP);
    $resp->header('Content-type' => $ContentType) if ($ContentType);
    $resp->header('Content-Disposition' => "attachment; filename=$filename") if ($filename);
    $resp->content($data) if ($data);

    $Client->send_response($resp);
    return ($status, length($data));
}

sub headerForward {
    my $url = shift;
    Log(LOG_DEBUG, "[FORWARD] " . $url);
    my $resp = HTTP::Response->new(302, "Found");

    $resp->header('Date' => time2str());
    $resp->header('Location' => $url);
    $resp->header('Content-type' => 'text/plain');
    my $data = "302 Found";
    $resp->content($data);

    $Client->send_response($resp);
    return (302, length($data));
}

sub headerNoAuth {
    my $resp = HTTP::Response->new(401, "Authorization Required");
    $resp->header('Date' => time2str());
    $resp->header('WWW-Authenticate' => "Basic realm=\"vdradmind\"");
    $resp->header('Content-type' => "text/plain");
    my $data = "401 Authorization Required";
    $resp->content($data);

    $Client->send_response($resp);
    return (401, length($data));
}

sub Error {
    my $vars = { title => $_[0] . " - " . $_[1],
                 h1    => $_[1],
                 error => $_[2],
    };
    return showTemplate("noperm.html", $vars, $_[0], $_[1]);
}

sub SendFile {
    my ($File) = @_;
    my ($buf, $temp);
    $File =~ s/^\///;
    $File =~ s/^bilder/$CONFIG{SKIN}/i
      if (defined $CONFIG{SKIN});
    my $FileWithPath = sprintf(
        "%s/%s/%s",

        #my $FileWithPath = sprintf("%s/%s/%s/%s",
        #$BASENAME,
        $TEMPLATEDIR,
        $CONFIG{TEMPLATE},
        $File
    );

    # Skin css file
    if ($File eq "style.css" and -e sprintf('%s/%s/%s/%s', $TEMPLATEDIR, $CONFIG{TEMPLATE}, $CONFIG{SKIN}, $File)) {
        $FileWithPath = sprintf('%s/%s/%s/%s', $TEMPLATEDIR, $CONFIG{TEMPLATE}, $CONFIG{SKIN}, $File);
    } elsif ($File eq "user.css" and -e "$USER_CSS") {
        $FileWithPath = "$USER_CSS";
    } elsif ($File =~ "^epg/") {
        $File =~ s/^epg\///;
        $FileWithPath = $CONFIG{EPGIMAGES} . "/" . $File;
    }

    if (-e $FileWithPath) {
        if (-r _) {
            my $lastmod = (stat(_))[9];
            $buf  = ReadFile($FileWithPath);
            $temp = $File;
            $temp =~ /([A-Za-z0-9]+)\.([A-Za-z0-9]+)$/;
            if (!$mimehash{$2}) { die("can't find mime-type \'$2\'\n"); }
            return (header("200", $mimehash{$2}, $buf, undef, 1, $lastmod));
        } else {
            Log(LOG_FATALERROR, "[ACCESS] Access denied: $File");
            Error("403", gettext("Forbidden"), sprintf(gettext("Access to file \"%s\" denied!"), $File));
        }
    } else {
        Log(LOG_FATALERROR, "[ACCESS] File not found: $File");
        Error("404", gettext("Not found"), sprintf(gettext("The URL \"%s\" was not found on this server!"), $File));
    }
}

#############################################################################
# autotimer functions
#############################################################################
sub can_do_eventid_autotimer {

    # check if we may use Event-IDs in general or not
    return 0 if ($CONFIG{NO_EVENTID} == 1);

    my $vdr_id = shift;

    # check if the current channel is on the Event-ID-blacklist
    for my $n (split(",", $CONFIG{NO_EVENTID_ON})) {
        return 0 if ($n == $vdr_id);
    }

    return 1;
}

sub AT_Read {
    my (@at);
    if (-e $AT_FILENAME) {
        open(AT_FILE, $AT_FILENAME) || HTMLError(sprintf($ERROR_MESSAGE{cant_open}, $AT_FILENAME));
        while (<AT_FILE>) {
            chomp;
            next if ($_ eq "");
            my ($active, $pattern, $section, $start, $stop, $episode, $prio, $lft, $channel, $directory, $done, $weekday, $buffers, $bstart, $bstop) = split(/\:/, $_);
            $pattern   =~ s/\|/\:/g;
            $pattern   =~ s/\\:/\|/g;
            $directory =~ s/\|/\:/g;
            my ($usechannel) = ($channel =~ /^\d+$/) ? $channel : get_vdrid_from_channelid($channel);
            push(
                @at,
                {  active    => $active,
                   pattern   => $pattern,
                   section   => $section,
                   start     => $start,
                   stop      => $stop,
                   buffers   => $buffers,
                   bstart    => $bstart,
                   bstop     => $bstop,
                   episode   => $episode,
                   prio      => $prio,
                   lft       => $lft,
                   channel   => $usechannel,
                   directory => $directory,
                   done      => $done,

                   # Be compatible with older formats, so search on weekdays default to yes
                   (weekdays => { map { $_->[0] => defined $weekday ? substr($weekday, $_->[1], 1) : 1 } ([ 'wday_mon', 0 ], [ 'wday_tue', 1 ], [ 'wday_wed', 2 ], [ 'wday_thu', 3 ], [ 'wday_fri', 4 ], [ 'wday_sat', 5 ], [ 'wday_sun', 6 ]) })

                }
            );
        }
        close(AT_FILE);
    }
    return (@at);
}

sub AT_Write {
    my @at = @_;
    open(AT_FILE, ">" . $AT_FILENAME) || HTMLError(sprintf($ERROR_MESSAGE{cant_open}, $AT_FILENAME));
    foreach my $auto_timer (@at) {
        my $temp;
        for my $item (qw(active pattern section start stop episode prio lft channel directory done weekdays buffers bstart bstop)) {
            my $tempitem = $auto_timer->{$item};
            if ($item eq 'channel') {
                my $channelnumber = get_channelid_from_vdrid($tempitem);
                if ($channelnumber) {
                    $tempitem = $channelnumber;
                }
            } elsif ($item eq 'pattern') {
                $tempitem =~ s/\|/\\|/g;
                $tempitem =~ s/\:/\|/g;
            } elsif ($item eq 'weekdays') {
                # Create weekday string, starting with monday, 1=yes=search this day, e.g. 0011001
                my $search_weekday = '';
                map { $search_weekday .= $auto_timer->{$item}->{$_} } (qw (wday_mon wday_tue wday_wed wday_thu wday_fri wday_sat wday_sun));
                $tempitem = $search_weekday;
            } else {
                $auto_timer->{$item} =~ s/\:/\|/g;
            }
            if (length($temp) == 0) {
                $temp = $tempitem;
            } else {
                $temp .= ":" . $tempitem;
            }
        }

        # Finally write the auto timer entry
        print AT_FILE $temp, "\n";
    }
    close(AT_FILE);
}

sub DONE_Write {
    my $done = shift || return;
    open(DONE_FILE, ">" . $DONE_FILENAME) || HTMLError(sprintf($ERROR_MESSAGE{cant_open}, $DONE_FILENAME));
    foreach my $n (sort keys %$done) {
        printf DONE_FILE "%s::%d::%s\n", $n, $done->{$n}, scalar localtime($done->{$n});
    }
    close(DONE_FILE);
}

sub DONE_Read {
    my $done;
    if (-e $DONE_FILENAME) {
        open(DONE_FILE, $DONE_FILENAME) || HTMLError(sprintf($ERROR_MESSAGE{cant_open}, $DONE_FILENAME));
        while (<DONE_FILE>) {
            chomp;
            next if ($_ eq "");
            my @line = split('\:\:', $_);
            $done->{ $line[0] } = $line[1];
        }
        close(DONE_FILE);
    }
    return $done;
}

sub BlackList_Read {
    my %blacklist;
    if (-e $BL_FILENAME) {
        open(BL_FILE, $BL_FILENAME) || HTMLError(sprintf($ERROR_MESSAGE{cant_open}, $BL_FILENAME));
        while (<BL_FILE>) {
            chomp;
            next if ($_ eq "");
            $blacklist{$_} = 1;
        }
        close(BL_FILE);
    }
    return %blacklist;
}

sub AutoTimer {
    return if (!$CONFIG{AT_FUNC} || !$FEATURES{AUTOTIMER});
    Log(LOG_INFO, "[AUTOTIMER] Scanning for events...");
    my ($search, $start, $stop) = @_;
    my @at_matches;

    my @at;
    my $dry_run = shift;
    if ($dry_run) {
        @at = shift;
    } else {
        @at = AT_Read();
    }

    my $oneshots = 0;
    $DONE = &DONE_Read unless ($DONE);
    my %blacklist = &BlackList_Read;

    # Merken der wanted Channels (geht schneller
    # bevor das immer wieder in der unteren Schleife gemacht wird).
    my $wanted;
    for my $n (split(",", $CONFIG{CHANNELS_WANTED})) {
        $wanted->{$n} = 1;
    }

    # Die Timerliste holen
    #TODO: is this really needed? Timers will be checked in AT_ProgTimer...
#  my $timer;
#  foreach my $t (ParseTimer(0)){
##TODO: what's the 2nd "%s" for?
#    my $key = sprintf('%d:%s:%s',
#    $t->{vdr_id},
#    $t->{title},
#    ""
#    );
#    $timer->{$key} = $t;
#printf("Timer: %s / %s / %s\n", $key, $timer->{event_id}, $t);
#  }
#print("TIMER\n") if($timer);
#/TODO

    my $date_now = time();
    for my $sender (keys(%EPG)) {
        for my $event (@{ $EPG{$sender} }) {

            # Event in the past?
            next if ($event->[EV_STOP] < $date_now);

            # Ein Timer der schon programmmiert wurde kann
            # ignoriert werden
            #TODO: $timer not initialized
#        next if($event->[EV_EVENT_ID] == $timer->{event_id});

            # Wenn CHANNELS_WANTED_AUTOTIMER dann next wenn der Kanal
            # nicht in der WantedList steht
            if ($CONFIG{CHANNELS_WANTED_AUTOTIMER}) {
                next unless defined $wanted->{ $event->[EV_VDR_ID] };
            }

            # Hamwa schon gehabt?
            my $DoneStr;
            unless ($dry_run) {
                $DoneStr = sprintf('%s~%d~%s', $event->[EV_TITLE], $event->[EV_EVENT_ID], ($event->[EV_SUBTITLE] ? $event->[EV_SUBTITLE] : ''),);

                if (exists $DONE->{$DoneStr}) {
                    Log(LOG_DEBUG, sprintf("[AUTOTIMER] already done \"%s\"", $DoneStr));
                    next;
                }
            }

            if (%blacklist) {

                # Wollen wir nicht haben.
                my $BLStr = $event->[EV_TITLE];
                $BLStr .= "~" . $event->[EV_SUBTITLE] if $event->[EV_SUBTITLE];

                if ($blacklist{$BLStr} || $blacklist{ $event->[EV_TITLE] }) {
                    Log(LOG_DEBUG, sprintf("[AUTOTIMER] blacklisted \"%s\"", $event->[EV_TITLE]));
                    next;
                }
            }

            for my $at (@at) {
                next if (!$at->{active}   && !$dry_run);
                next if (($at->{channel}) && ($at->{channel} != $event->[EV_VDR_ID]));

                #print("AT: " . $at->{channel} . " - " . $at->{pattern} . " --- " . $event->[EV_VDR_ID] . " - " . $event->[EV_TITLE] . "\n");

                my $SearchStr;
                if ($at->{section} & 1) {
                    $SearchStr = $event->[EV_TITLE];
                }
                if (($at->{section} & 2) && defined($event->[EV_SUBTITLE])) {
                    $SearchStr .= "~" . $event->[EV_SUBTITLE];
                }
                if ($at->{section} & 4) {
                    $SearchStr .= "~" . $event->[EV_SUMMARY];
                }

                # Regular Expressions are surrounded by slashes -- everything else
                # are search patterns
                if ($at->{pattern} =~ /^\/(.*)\/(i?)$/) {

                    # We have a RegExp
                    Log(LOG_DEBUG, sprintf("[AUTOTIMER] Checking RegExp \"%s\"", $at->{pattern}));

                    if ((!length($SearchStr)) || (!length($1))) {
                        Log(LOG_DEBUG, "[AUTOTIMER] No search string or RegExp, skipping!");
                        next;
                    }

                    next if (!defined($1));

                    # Shall we search case insensitive?
                    if (($2 eq "i") && ($SearchStr !~ /$1/i)) {
                        next;
                    } elsif (($2 ne "i") && ($SearchStr !~ /$1/)) {
                        next;
                    } else {
                        Log(LOG_DEBUG, sprintf("[AUTOTIMER] RegExp \"%s\" matches \"%s\"", $at->{pattern}, $SearchStr));
                    }
                } else {

                    # We have a search pattern
                    Log(LOG_DEBUG, sprintf("[AUTOTIMER] Checking pattern \"%s\"", $at->{pattern}));

                    # Escape special characters within the search pattern
                    my $atpattern = $at->{pattern};
                    $atpattern =~ s/([\+\?\.\*\^\$\(\)\[\]\{\}\|\\])/\\$1/g;

                    Log(LOG_DEBUG, sprintf("[AUTOTIMER] Escaped pattern: \"%s\"", $atpattern));

                    if ((!length($SearchStr)) || (!length($atpattern))) {
                        Log(LOG_DEBUG, "[AUTOTIMER] No search string or pattern, skipping!");
                        next;
                    }

                    # split search pattern at spaces into single sub-patterns, and
                    # test for all of them (logical "and")
                    my $fp = 1;
                    for my $pattern (split(/ +/, $atpattern)) {

                        # search for each sub-pattern, case insensitive
                        if ($SearchStr !~ /$pattern/i) {
                            $fp = 0;
                        } else {
                            Log(LOG_DEBUG, sprintf("[AUTOTIMER] Found matching pattern: \"%s\"", $pattern));
                        }
                    }
                    next if (!$fp);
                }

                my $event_start = my_strftime("%H%M", $event->[EV_START]);
                my $event_stop  = my_strftime("%H%M", $event->[EV_STOP]);
                Log(LOG_DEBUG, sprintf("[AUTOTIMER] Comparing pattern \"%s\" (%s - %s) with event \"%s\" (%s - %s)", $at->{pattern}, $at->{start}, $at->{stop}, $event->[EV_TITLE], $event_start, $event_stop));

                # Do we have a time slot?
                if ($at->{start}) {    # We have a start time and possibly a stop time for the auto timer
                                       # Do we have midnight between AT start and stop time?
                    if (($at->{stop}) && ($at->{stop} < $at->{start})) {

                        # The AT includes midnight
                        Log(LOG_DEBUG, "[AUTOTIMER] AT includes midnight");

                        # Do we have midnight between event start and stop?
                        if ($event_stop < $event_start) {

                            # The event includes midnight
                            Log(LOG_DEBUG, "[AUTOTIMER] Event includes midnight");
                            if ($event_start < $at->{start}) {
                                Log(LOG_DEBUG, "[AUTOTIMER] Event starts before AT start");
                                next;
                            }
                            if ($event_stop > $at->{stop}) {
                                Log(LOG_DEBUG, "[AUTOTIMER] Event ends after AT stop");
                                next;
                            }
                        } else {

                            # Normal event not spreading over midnight
                            Log(LOG_DEBUG, "[AUTOTIMER] Event does not include midnight");
                            if ($event_start < $at->{start}) {
                                if ($event_start > $at->{stop}) {

                                    # The event starts before AT start and after AT stop
                                    Log(LOG_DEBUG, "[AUTOTIMER] Event starts before AT start and after AT stop");
                                    next;
                                }
                                if ($event_stop > $at->{stop}) {

                                    # The event ends after AT stop
                                    Log(LOG_DEBUG, "[AUTOTIMER] Event ends after AT stop");
                                    next;
                                }
                            }
                        }
                    } else {

                        # Normal auto timer, not spreading over midnight
                        Log(LOG_DEBUG, "[AUTOTIMER] AT does not include midnight");

                        # Is the event spreading over midnight?
                        if ($event_stop < $event_start) {

                            # Event spreads midnight
                            if ($at->{stop}) {

                                # We have a AT stop time defined before midnight -- no match
                                Log(LOG_DEBUG, "[AUTOTIMER] Event includes midnight, AT not");
                                next;
                            }
                        } else {

                            # We have a normal event, nothing special
                            # Event must not start before AT start
                            if ($event_start < $at->{start}) {
                                Log(LOG_DEBUG, "[AUTOTIMER] Event starts before AT start");
                                next;
                            }

                            # Event must not end after AT stop
                            if (($at->{stop}) && ($event_stop > $at->{stop})) {
                                Log(LOG_DEBUG, "[AUTOTIMER] Event ends after AT stop");
                                next;
                            }
                        }
                    }
                } else {

                    # We have no AT start time
                    if ($at->{stop}) {
                        if ($event_stop > $at->{stop}) {
                            Log(LOG_DEBUG, "[AUTOTIMER] Only AT stop time, event stops after AT stop");
                            next;
                        }
                    }
                }

                # Check if we should schedule any timers on this weekday
                my %weekdays_map = (1 => 'wday_mon', 2 => 'wday_tue', 3 => 'wday_wed', 4 => 'wday_thu', 5 => 'wday_fri', 6 => 'wday_sat', 7 => 'wday_sun');
                unless ($at->{weekdays}->{ $weekdays_map{ my_strftime("%u", $event->[EV_START]) } }) {
                    Log(LOG_DEBUG, "[AUTOTIMER] Event not valid for this weekday");
                    next;
                }

                Log(LOG_DEBUG, sprintf("[AUTOTIMER] Found \"%s\"", $at->{pattern}));

#########################################################################################
# 20050130: patch by macfly: parse extended EPG information provided by tvm2vdr.pl
#########################################################################################

                my $title;
                my $directory = $at->{directory};
                my %at_details;

                if ($directory) {
                    $directory =~ s#/#~#g;
                }

                if ($directory && $directory =~ /\%.*\%/) {
                    $title = $directory;
                    $at_details{'title'} = $event->[EV_TITLE];
                    $at_details{'subtitle'} = $event->[EV_SUBTITLE] ? $event->[EV_SUBTITLE] : my_strftime("%Y-%m-%d", $event->[EV_START]);
                    $at_details{'date'} = my_strftime("%Y-%m-%d", $event->[EV_START]);
                    $at_details{'regie'}         = $1 if $event->[EV_SUMMARY] =~ m/\|Director: (.*?)\|/;
                    $at_details{'category'}      = $1 if $event->[EV_SUMMARY] =~ m/\|Category: (.*?)\|/;
                    $at_details{'genre'}         = $1 if $event->[EV_SUMMARY] =~ m/\|Genre: (.*?)\|/;
                    $at_details{'year'}          = $1 if $event->[EV_SUMMARY] =~ m/\|Year: (.*?)\|/;
                    $at_details{'country'}       = $1 if $event->[EV_SUMMARY] =~ m/\|Country: (.*?)\|/;
                    $at_details{'originaltitle'} = $1 if $event->[EV_SUMMARY] =~ m/\|Originaltitle: (.*?)\|/;
                    $at_details{'fsk'}           = $1 if $event->[EV_SUMMARY] =~ m/\|FSK: (.*?)\|/;
                    $at_details{'episode'}       = $1 if $event->[EV_SUMMARY] =~ m/\|Episode: (.*?)\|/;
                    $at_details{'rating'}        = $1 if $event->[EV_SUMMARY] =~ m/\|Rating: (.*?)\|/;
                    $title =~ s/%([\w_-]+)%/$at_details{lc($1)}/sieg;

                    #$title .= "~" . $event->[EV_TITLE];
                } else {
                    $title = $event->[EV_TITLE];
                    if ($directory) {
                        $title = $directory . "~" . $title;
                    }
                    if ($at->{episode}) {
                        if ($event->[EV_SUBTITLE]) {
                            $title .= "~" . $event->[EV_SUBTITLE];
                        } else {
                            $title .= "~" . my_strftime("%Y-%m-%d", $event->[EV_START]);
                        }
                    }
                }

                # gemaess vdr.5 alle : durch | ersetzen.
                $title =~ s#:#|#g;

                # sind irgendwelche Tags verwendet worden, die leer waren und die doppelte Verzeichnisse erzeugten?
                $title =~ s#~+#~#g;
                $title =~ s#^~##;

#########################################################################################
# 20050130: patch by macfly: parse extended EPG information provided by tvm2vdr.pl
#########################################################################################

                if ($dry_run) {

                    #printf("AT found: (%s) (%s) (%s) (%s) (%s) (%s)\n", $event->[EV_TITLE], $title, $event->[EV_SUBTITLE], $directory, $event->[EV_START], $event->[EV_STOP]);
                    push(@at_matches, { otitle    => $event->[EV_TITLE],
                                        title     => $title,
                                        subtitle  => $event->[EV_SUBTITLE] ? $event->[EV_SUBTITLE] : "",
                                        directory => $directory,
                                        start     => my_strftime("%H:%M", $event->[EV_START]),
                                        stop      => my_strftime("%H:%M", $event->[EV_STOP]),
                                        date      => my_strftime("%A, %x", $event->[EV_START]),
                                        channel   => GetChannelDescByNumber($event->[EV_VDR_ID]) });
                } else {
                    Log(LOG_INFO, sprintf("[AUTOTIMER] Programming Timer \"%s\" (Event-ID %s, %s - %s)", $title, $event->[EV_EVENT_ID], strftime("%Y%m%d-%H%M", localtime($event->[EV_START])), strftime("%Y%m%d-%H%M", localtime($event->[EV_STOP]))));

                    AT_ProgTimer(1, $event->[EV_EVENT_ID], $event->[EV_VDR_ID], $event->[EV_START], $event->[EV_STOP], $title, $event->[EV_SUMMARY], $at);

                    if ($at->{active} == 2) {
                        Log(LOG_INFO, "[AUTOTIMER] Disabling one-shot Timer");
                        $at->{active} = 0;
                        $oneshots = 1;
                    }
                    $DONE->{$DoneStr} = $event->[EV_STOP] if ($at->{done});
                }
            }
        }
    }
    if ($oneshots) {
        Log(LOG_DEBUG, "[AUTOTIMER] Saving because of one-shots triggered");
        AT_Write(@at);
    }

    unless ($dry_run) {
        Log(LOG_DEBUG, "[AUTOTIMER] Purging done list... (lowtime $low_time)");
        for (keys %$DONE) { delete $DONE->{$_} if ($low_time > $DONE->{$_}) }
        Log(LOG_DEBUG, "[AUTOTIMER] Save done list...");
        &DONE_Write($DONE) if ($DONE);
    }
    Log(LOG_INFO, "[AUTOTIMER] Done.");

    if ($dry_run) {
        return @at_matches;
    }
}

sub AT_ProgTimer {
    my ($active, $event_id, $channel, $start, $stop, $title, $summary, $at) = @_;

    $start -= (($at->{buffers} ? ($at->{bstart} eq "" ? $CONFIG{AT_MARGIN_BEGIN} : $at->{bstart}) : $CONFIG{TM_MARGIN_BEGIN}) * 60);
    $stop += (($at->{buffers} ? ($at->{bstop} eq "" ? $CONFIG{AT_MARGIN_END} : $at->{bstop}) : $CONFIG{TM_MARGIN_END}) * 60);

    my $start_fmt = my_strftime("%H%M", $start);
    my $found = 0;
    for (ParseTimer(1)) {
        if ($_->{vdr_id} == $channel) {
            if ($_->{autotimer} == $AT_BY_EVENT_ID && $event_id && $_->{event_id}) {
                if ($_->{event_id} == $event_id) {
                    $found = 1;
                    last;
                }
            }

            # event_ids didn't match, try matching using starting time
            if ($_->{start} eq $start) {
                $found = 1;
                last;
            }
            if ($start_fmt eq my_strftime("%H%M", $_->{start})) {
                if ($FEATURES{VDRVERSION} < 10323) {
                    if ($_->{dor} == my_strftime("%d", $start)) {
                        $found = 1;
                        last;
                    }
                } else {
                    if ($_->{dor} eq my_strftime("%Y-%m-%d", $start)) {
                        $found = 1;
                        last;
                    }
                }
            }
        }
    }

    # we will only programm new timers, CheckTimers is responsible for
    # updating existing timers
    if (!$found) {
        $title =~ s/\|/\:/g;

        my $autotimer = $AT_BY_EVENT_ID;
        unless (can_do_eventid_autotimer($channel)) {
            $event_id  = 0;
            $autotimer = $AT_BY_TIME;
        }

        Log(LOG_DEBUG, sprintf("[AUTOTIMER] AT_ProgTimer: Programming Timer \"%s\" (Event-ID %s, %s - %s)", $title, $event_id, strftime("%Y%m%d-%H%M", localtime($start)), strftime("%Y%m%d-%H%M", localtime($stop))));
        ProgTimer(0,
            $active,
            $event_id,
            $channel,
            $start,
            $stop,
            $at->{prio} ne "" ? $at->{prio} : $CONFIG{AT_PRIORITY},
            $at->{lft} ne "" ? $at->{lft} : $CONFIG{AT_LIFETIME},
            $title,
            append_timer_metadata($FEATURES{VDRVERSION} < 10344 ? $summary : undef,
                $event_id,
                $autotimer,
                $at->{buffers} ? ($at->{bstart} eq "" ? $CONFIG{AT_MARGIN_BEGIN} : $at->{bstart}) : $CONFIG{TM_MARGIN_BEGIN},
                $at->{buffers} ? ($at->{bstop} eq "" ? $CONFIG{AT_MARGIN_END} : $at->{bstop}) : $CONFIG{TM_MARGIN_END},
                $at->{pattern},
                $TOOL_AUTOTIMER
            )
        );

        if ($CONFIG{AT_SENDMAIL} == 1 && $can_use_net_smtp && ($CONFIG{MAIL_AUTH_USER} eq "" || $can_use_smtpauth)) {
            my $sum = $summary;

            # remove all HTML-Tags from text
            $sum =~ s/\<[^\>]+\>/ /g;

            # linefeeds
            $sum =~ s/\|/\n/g;
            my $dat  = strftime("%A, %x", localtime($start));
            my $strt = strftime("%H:%M",  localtime($start));
            my $end  = strftime("%H:%M",  localtime($stop));

            eval {
                local $SIG{__DIE__};

                my $smtp = Net::SMTP->new($CONFIG{MAIL_SERVER}, Timeout => 30);
                if ($smtp) {
                    if ($CONFIG{MAIL_AUTH_USER} ne "") {
                        $smtp->auth($CONFIG{MAIL_AUTH_USER}, $CONFIG{MAIL_AUTH_PASS}) || return;
                    }
                    $smtp->mail("$CONFIG{MAIL_FROM}");
                    $smtp->to($CONFIG{MAIL_TO});
                    $smtp->data();
                    $smtp->datasend("To: $CONFIG{MAIL_TO}\n");
                    my $qptitle = my_encode_qp($title);
                    $smtp->datasend("Subject: AUTOTIMER: New timer created for $qptitle\n");
                    $smtp->datasend("From: VDRAdmin-AM AutoTimer <$CONFIG{MAIL_FROM}>\n");
                    $smtp->datasend("Auto-Submitted: auto-generated\n"); # RFC 3834
                    $smtp->datasend("MIME-Version: 1.0\n");
                    $smtp->datasend("Content-Type: text/plain; charset=iso-8859-1\n");
                    $smtp->datasend("Content-Transfer-Encoding: 8bit\n");
                    $smtp->datasend("\n");
                    $smtp->datasend("Created AUTOTIMER for $title\n");
                    $smtp->datasend("===========================================================================\n\n");
                    $smtp->datasend("Channel: $channel\n\n");
                    $smtp->datasend("$title\n");
                    $smtp->datasend("$dat, $strt - $end\n\n");
                    $smtp->datasend("Summary:\n");
                    $smtp->datasend("--------\n");
                    $smtp->datasend("$sum\n");
                    $smtp->dataend();
                    $smtp->quit();
                } else {
                    Log(LOG_FATALERROR, "[MAIL] SMTP failed! Please check your email settings.");
                }
            };
            if ($@) {
                Log(LOG_FATALERROR, "[MAIL] Failed to send email! Please contact the author.");
            }
        } elsif ($CONFIG{AT_SENDMAIL} == 1) {
            if (!$can_use_net_smtp) {
                Log(LOG_FATALERROR, "[MAIL] Missing Perl module Net::SMTP. AutoTimer email notification disabled.");
            }
            if ($CONFIG{MAIL_AUTH_USER} ne "" && !$can_use_smtpauth) {
                Log(LOG_FATALERROR, "[MAIL] Missing Perl module Authen::SASL and/or Digest::HMAC_MD5. AutoTimer email notification disabled.");
            }
        }
    }
}

sub my_encode_qp {
    my $title = shift;
    if ($title =~ /[\001-\037\200-\377]/) {
        my $qptitle = $title;
        $qptitle = "=?iso-8859-1?b?" . MIME::Base64::encode_base64($title, "") . "?=";
        $qptitle =~ s#(=\?iso-8859-1\?b\?[^\?]{56})(?!\?=)#$1?=\n =?iso-8859-1?b?#g while ($qptitle =~ /=\?iso-8859-1\?b\?[^\?]{57,}\?=/);
        return $qptitle;
    }
    return $title;
}

sub PackStatus {    #TODO: unused
                    # make a 32 bit signed int with high 16 Bit as event_id and low 16 Bit as
                    # active value
    my ($active, $event_id) = @_;

    # we must generate a 32 bit signed int, due perl knows no overflow at 32 bit,
    # we have to do the overflow manually:

    # is the 16th bit set? then the signed 32 bit int is negative!
    if ($event_id & 0x8000) {

        # strip the first bit (by & 0x7FFF) of the event_id, so a 15 bit
        # (positive) int will remain, then shift the int 16 bits to the left and
        # add active  -- result is a 31 bit (always positive) int.
        # The 32nd bit is the minus sign, and due the (binary) smallest value
        # is the (int) lowest possible number, we have to subtract the lowest
        # value + 1 from the 31 bit value -- result is the signed 32 bit int equal
        # to the (unsigned) 32 bit int.
        return ($active | (($event_id & 0x7FFF) << 16)) - 0x80000000;
    } else {
        return $active | ($event_id << 16);
    }
}

sub UnpackActive {    #TODO: unused
    my ($tmstatus) = @_;

    # strip the first 16 bit
    return ($tmstatus & 0xFFFF);
}

sub UnpackEvent_id {    #TODO: unused
    my ($tmstatus) = @_;

    # remove the lower 16 bit by shifting the value 16 bits to the right
    return $tmstatus >> 16;
}

sub CheckTimers {
    return if (!$CONFIG{AT_FUNC} || !$FEATURES{AUTOTIMER});
    my $event;

    for my $timer (ParseTimer(1)) {

        next unless $timer->{autotimer};

        # match by event_id
        if ($timer->{autotimer} == $AT_BY_EVENT_ID) {
            for $event (@{ $EPG{ $timer->{vdr_id} } }) {

                # look for matching event_id on the same channel -- it's unique
                if ($timer->{event_id} == $event->[EV_EVENT_ID]) {
                    Log(LOG_DEBUG, sprintf("[AUTOTIMER] CheckTimers: Checking timer \"%s\" (No. %s) for changes by Event-ID", $timer->{title}, $timer->{id}));

                    # update timer if the existing one differs from the EPG
                    # (don't check for changed title, as this will break autotimers' "directory" setting)
                    if (   ($timer->{start} != ($event->[EV_START] - $timer->{bstart} * 60))
                        || ($timer->{stop} != ($event->[EV_STOP] + $timer->{bstop} * 60)))
                    {
                        Log(LOG_INFO, sprintf("[AUTOTIMER] CheckTimers: Timer \"%s\" (No. %s, Event-ID %s, %s - %s) differs from EPG: \"%s\", Event-ID %s, %s - %s)", $timer->{title}, $timer->{id}, $timer->{event_id}, strftime("%Y%m%d-%H%M", localtime($timer->{start})), strftime("%Y%m%d-%H%M", localtime($timer->{stop})), $event->[EV_TITLE], $event->[EV_EVENT_ID], strftime("%Y%m%d-%H%M", localtime($event->[EV_START])), strftime("%Y%m%d-%H%M", localtime($event->[EV_STOP]))));
                        ProgTimer(
                            $timer->{id},
                            $timer->{active},
                            $timer->{event_id},
                            $timer->{vdr_id},
                            $event->[EV_START] - $timer->{bstart} * 60,
                            $event->[EV_STOP] + $timer->{bstop} * 60,
                            $timer->{prio},
                            $timer->{lft},

                            # don't update title as this may differ from what has been set by the user
                            $timer->{title},

                            # leave summary untouched.
                            $timer->{summary},
                        );
                    }
                }
            }
        }

        # match by channel number and start/stop time
        elsif ($timer->{autotimer} == $AT_BY_TIME) {

            # We're checking only timers which don't record
            if ($timer->{start} > time()) {
                Log(LOG_DEBUG, sprintf("[AUTOTIMER] CheckTimers: Checking timer \"%s\" (No. %s) for changes by recording time", $timer->{title}, $timer->{id}));
                my @eventlist;

                for my $event (@{ $EPG{ $timer->{vdr_id} } }) {

                    # look for events within the margins of the current timer
                    if (($event->[EV_START] < $timer->{stop}) && ($event->[EV_STOP] > $timer->{start})) {
                        push @eventlist, $event;
                    }
                }

                # now we have all events in eventlist that touch the old timer margins
                # check for each event how probable it is matching the old timer
                if (scalar(@eventlist) > 0) {
                    my $origlen = ($timer->{stop} - $timer->{bstop} * 60) - ($timer->{start} + $timer->{bstart} * 60);
                    next unless($origlen);
                    my $maxwight = 0;
                    $event = $eventlist[0];

                    for (my $i = 0 ; $i < scalar(@eventlist) ; $i++) {
                        my ($start, $stop);

                        if ($eventlist[$i]->[EV_START] < $timer->{start}) {
                            $start = $timer->{start};
                        } else {
                            $start = $eventlist[$i]->[EV_START];
                        }
                        if ($eventlist[$i]->[EV_STOP] > $timer->{stop}) {
                            $stop = $timer->{stop};
                        } else {
                            $stop = $eventlist[$i]->[EV_STOP];
                        }

                        my $wight = ($stop - $start) / ($eventlist[$i]->[EV_STOP] - $eventlist[$i]->[EV_START]);

                        if ($wight > $maxwight && (($eventlist[$i]->[EV_STOP] - $eventlist[$i]->[EV_START]) / $origlen) >= 0.9) {
                            $maxwight = $wight;
                            $event    = $eventlist[$i];
                        }
                    }

                    # update timer if the existing one differs from the EPG
                    if (   ($timer->{start} > ($event->[EV_START] - $timer->{bstart} * 60))
                        || ($timer->{stop} < ($event->[EV_STOP] + $timer->{bstop} * 60)))
                    {
                        Log(LOG_INFO, sprintf("[AUTOTIMER] CheckTimers: Timer \"%s\" (No. %s, Event-ID %s, %s - %s) differs from EPG: \"%s\", Event-ID %s, %s - %s)", $timer->{title}, $timer->{id}, $timer->{event_id}, strftime("%Y%m%d-%H%M", localtime($timer->{start})), strftime("%Y%m%d-%H%M", localtime($timer->{stop})), $event->[EV_TITLE], $event->[EV_EVENT_ID], strftime("%Y%m%d-%H%M", localtime($event->[EV_START])), strftime("%Y%m%d-%H%M", localtime($event->[EV_STOP]))));
                        ProgTimer(
                            $timer->{id},
                            $timer->{active},
                            0,
                            $timer->{vdr_id},
                            $timer->{start} > ($event->[EV_START] - $timer->{bstart} * 60) ? $event->[EV_START] - $timer->{bstart} * 60 : $timer->{start},
                            $timer->{stop} < ($event->[EV_STOP] + $timer->{bstop} * 60) ? $event->[EV_STOP] + $timer->{bstop} * 60 : $timer->{stop},
                            $timer->{prio},
                            $timer->{lft},

                            # don't touch the title since we're not too sure about the event
                            $timer->{title},

                            # leave summary untouched.
                            $timer->{summary},
                        );
                    }
                }
            } else {
                Log(LOG_DEBUG, sprintf("[AUTOTIMER] CheckTimers: Skipping Timer \"%s\" (No. %s, %s - %s)", $timer->{title}, $timer->{id}, strftime("%Y%m%d-%H%M", localtime($timer->{start})), strftime("%Y%m%d-%H%M", localtime($timer->{stop}))));
            }
        }
    }
}

#############################################################################
# epgsearch
#############################################################################
sub epgsearch_list {
    return if (UptoDate() != 0);

    if ($FEATURES{EPGSEARCH_VERSION} < 924) {
        HTMLError("Your version of epgsearch plugin is too old! You need at least v0.9.23!");
        return
    }

    $CONFIG{ES_DESC} = ($q->param("desc") ? 1 : 0) if (defined($q->param("desc")));
    $CONFIG{ES_SORTBY} = $q->param("sortby") if (defined($q->param("sortby")));
    $CONFIG{ES_SORTBY} = "pattern" if (!$CONFIG{ES_SORTBY});

    my @matches;
    my $do_test = $q->param("execute");

    if ($do_test) {
        my $id = $q->param("id");
        unless (defined $id) {
            for ($q->param) {
                if (/xxxx_(.*)/) {
                    $id .= "|" if (defined $id);
                    $id .= $1;
                }
            }
        }

        if (defined $id) {
            @matches = EpgSearchQuery("plug epgsearch qrys $id");
        }
    } else {
        $do_test = $q->param("favorites");
        @matches = EpgSearchQuery("plug epgsearch qryf") if ($do_test);
    }

    my @templates = GetEpgSearchTemplates();
    my @searches;
    for (ParseEpgSearch(undef)) {
        $_->{modurl}  = $MyURL . "?aktion=epgsearch_edit&amp;id=" . $_->{id};
        $_->{delurl}  = $MyURL . "?aktion=epgsearch_delete&amp;id=" . $_->{id};
        $_->{findurl} = $MyURL . "?aktion=epgsearch_aktion&amp;execute=1&amp;id=" . $_->{id};
        $_->{toggleurl}  = sprintf("%s?aktion=epgsearch_toggle&amp;active=%s&amp;id=%s", $MyURL, $_->{has_action}, $_->{id});
        push(@searches, $_);
    }

    if ($CONFIG{ES_SORTBY} eq "active") {
        if ($CONFIG{ES_DESC}) {
            @searches = sort({ $b->{has_action} <=> $a->{has_action} } @searches);
        } else {
            @searches = sort({ $a->{has_action} <=> $b->{has_action} } @searches);
        }
    } elsif ($CONFIG{ES_SORTBY} eq "action") {
        if ($CONFIG{ES_DESC}) {
            @searches = sort({ lc($b->{action_text}) cmp lc($a->{action_text}) } @searches);
        } else {
            @searches = sort({ lc($a->{action_text}) cmp lc($b->{action_text}) } @searches);
        }
    } elsif ($CONFIG{ES_SORTBY} eq "pattern") {
        if ($CONFIG{ES_DESC}) {
            @searches = sort({ lc($b->{pattern}) cmp lc($a->{pattern}) } @searches);
        } else {
            @searches = sort({ lc($a->{pattern}) cmp lc($b->{pattern}) } @searches);
        }
    }

    my $toggle_desc = ($CONFIG{ES_DESC} ? 0 : 1);

    my $vars = { usercss          => $UserCSS,
                 url              => $MyURL,
                 sortbypatternurl => "$MyURL?aktion=epgsearch_list&amp;sortby=pattern&amp;desc=" . (($CONFIG{ES_SORTBY} eq "pattern") ? $toggle_desc : $CONFIG{ES_DESC}),
                 sortbyactiveurl  => "$MyURL?aktion=epgsearch_list&amp;sortby=active&amp;desc=" . (($CONFIG{ES_SORTBY} eq "active") ? $toggle_desc : $CONFIG{ES_DESC}),
                 sortbyactionurl  => "$MyURL?aktion=epgsearch_list&amp;sortby=action&amp;desc=" . (($CONFIG{ES_SORTBY} eq "action") ? $toggle_desc : $CONFIG{ES_DESC}),
                 desc             => $CONFIG{ES_DESC} ? "desc" : "asc",
                 sortbypattern    => ($CONFIG{ES_SORTBY} eq "pattern") ? 1 : 0,
                 sortbyactive     => ($CONFIG{ES_SORTBY} eq "active")  ? 1 : 0,
                 sortbyaction     => ($CONFIG{ES_SORTBY} eq "action")  ? 1 : 0,
                 searches         => \@searches,
                 did_search       => $do_test,
                 title            => $do_test ? ($q->param("favorites") ? gettext("Your favorites") : gettext("Search results")) : undef,
                 matches          => (@matches ? \@matches : undef),
                 templates        => \@templates,
                 config_url       => "$MyURL?aktion=epgsearch_config"
    };
    return showTemplate("epgsearch_list.html", $vars);
}

sub epgsearch_edit {
    my $id = $q->param("id");
    my $do_test = $q->param("single_test");
    my $edit_template = $q->param("edit_template");
    my $template_id;
    $template_id = $q->param("template") if (defined $q->param("template"));
    $do_test = 0 if ($edit_template);

    my $search;
    my @blacklists;
    my @ch_groups;
    my @matches;
    my @sel_bl;

    if ($do_test) {
        # test search
        my $temp = epgsearch_Param2Line();
        $search = ExtractEpgSearchConf(($id ? $id : "0") . ":" . $temp);
        @sel_bl = $q->param("sel_blacklists");
        @matches = EpgSearchQuery("plug epgsearch qrys 0:" . $temp);
    } elsif (defined $id) {
        # edit search
        my @temp = ParseEpgSearch($id);
        $search = pop @temp;
        @sel_bl = split(/\|/, $search->{sel_blacklists});
    } else {
        # new search
        if (defined $template_id) {
            my @temp = GetEpgSearchTemplate($template_id);
            $search = pop @temp;
            $search->{pattern} = "" unless ($edit_template); # don't want the template's name as search pattern
            @sel_bl = split(/\|/, $search->{sel_blacklists});
        } else {
            #TODO: defaults for PRIO, LFT, BUFFER START/STOP
            $search->{use_title}    = 1;
            $search->{use_subtitle} = 1;
            $search->{use_descr}    = 1;
            $search->{comp_title}    = 1;
            $search->{comp_subtitle} = 1;
            $search->{comp_descr}    = 1;
        }
    }

    if (@sel_bl) {
        for my $bl (ParseEpgSearchBlacklists(undef)) {
            for (@sel_bl) {
                if ($bl->{id} == $_) {
                    $bl->{sel} = 1;
                    last;
                }
            }
            push(@blacklists, $bl);
        }
    } else {
        @blacklists = ParseEpgSearchBlacklists(undef);
    }

    if ($search->{use_channel} == 2) {
        for my $cg (ParseEpgSearchChanGroups(undef)) {
            $cg->{sel} = 1 if ($cg->{id} eq $search->{channels}) ;
            push(@ch_groups, $cg);
        }
    } else {
        @ch_groups = ParseEpgSearchChanGroups(undef);
    }

    my @extepg = ParseEpgSearchExtEpgInfos($search->{extepg_infos});
    if ($search->{comp_extepg_info}) {
        foreach (@extepg) {
            if ($search->{comp_extepg_info} & (1 << ($_->{id} - 1))) {
                $search->{"comp_extepg_" . $_->{id}} = 1;
            }
        }
    }

    epgsearch_getSettings();

    my $vars = { usercss       => $UserCSS,
                 url           => $MyURL,
                 epgsearch     => $search,
                 channels      => \@{$CHAN{$CHAN_FULL}->{channels}},
                 blacklists    => \@blacklists,
                 ch_groups     => \@ch_groups,
                 did_search    => $do_test,
                 matches       => (@matches ? \@matches : undef),
                 do_edit       => (defined $edit_template ? undef : (defined $id ? "1" : undef)),
                 mode_template => (defined $edit_template ? "1" : undef),
                 template_id   => $template_id,
                 extepg        => \@extepg,
                 epgs_settings => \%EPGSEARCH_SETTINGS
    };
    return showTemplate("epgsearch_new.html", $vars);
}

sub ParseEpgSearch {
    my $id = shift;

    my @temp;
    for (SendCMD("plug epgsearch lsts $id")) {
        chomp;
        next if (length($_) == 0);
        last if (/^no searches defined$/);

        push(@temp, ExtractEpgSearchConf($_));
    }

    return @temp;
}

sub ParseEpgSearchBlacklists {
    my $id = shift;

    my @temp;
    for (SendCMD("plug epgsearch lstb $id")) {
        chomp;
        next if (length($_) == 0);
        last if (/^no blacklists defined$/);

        push(@temp, ExtractEpgSearchBlacklistConf($_));
    }

    return @temp;
}

sub GetEpgSearchTemplates {
    my $def_template = 0;
    for (SendCMD("plug epgsearch deft")) {
        chomp;
        next if (length($_) == 0);
        last if (/^Command unrecognized/);
        $def_template = $_;
    }
    my @temp;
    for (SendCMD("plug epgsearch lstt")) {
        chomp;
        next if (length($_) == 0);
        last if (/^no search templates defined$|^Command unrecognized/);
        my $template = ExtractEpgSearchConf($_);
        if ($template->{id} == $def_template) {
           $template->{pattern} .= " (" . gettext("Default") . ")";
           $template->{sel} = 1;
        }
        push(@temp, $template);
    }

    return @temp;
}

sub GetEpgSearchTemplate {
    my $id = shift;
    my @temp;
    for (SendCMD("plug epgsearch lstt $id")) {
        chomp;
        next if (length($_) == 0);
        last if (/^search template id .* not defined$|^Command unrecognized/);
        push(@temp, ExtractEpgSearchConf($_));
    }

    return @temp;
}

sub ParseEpgSearchChanGroups {
    my $id = shift;

    my @temp;
    for (SendCMD("plug epgsearch lstc $id")) {
        chomp;
        next if (length($_) == 0);
        last if (/^no channel groups defined$/);

        my ($name, $channels) = split(/\|/, $_, 2);
        push(@temp, {
                     id       => $name,
                     name     => $name,
                     channels => $channels
                    }
        );
    }

    return @temp;
}

sub ParseEpgSearchExtEpgInfos {
    my @temp = split(/\|/, shift);
    my %sel;
    foreach (@temp) {
        my ($id, $val) = split(/#/);
        $val =~ s/\!\^colon\^\!/\:/g;
        $val =~ s/\!\^pipe\^\!/\|/g;
        $sel{$id} = $val;
    }

    my @return;
    for (SendCMD("plug epgsearch lste")) {
        chomp;
        next if (length($_) == 0);
        last if (/^no EPG categories defined$/);

        my ($id, $name, $title, $values, $searchmode) = split(/\|/, $_, 5);
        my @val;
        my $selected;
        foreach (split(/, /, $values)) {
            my $value = $_;
            my @res = grep(/^$value$/, split(/, /, $sel{$id}));
            $selected = 1 if (@res);
            push(@val, { name => $value,
                         sel  => (@res) ? 1 : undef
                       }
            );
        }
        push(@return, {
                        id         => $id,
                        name       => $name,
                        title      => $title,
                        data       => \@val,
                        searchmode => $searchmode,
                        data_text  => $selected ? undef : $sel{$id}
                      }
        );
    }

    return @return;
}

sub EpgSearchQuery {
    my $cmd = shift;
    my $ref = shift;
    return unless($cmd);

#print("EpgSearchQuery: $cmd\n");
    my @result;
    for (SendCMD($cmd)) {
        chomp;
        next if (length($_) == 0);
        last if(/^no results$/);
#        Suchtimer-ID : Event-ID : Title : Subtitle : Event-Begin : Event-Ende :
#        Kanalnummer : Timer-Start : Timer-Ende : Timer-File : hat/bekommt Timer
        my ($es_id, $event_id, $title, $subtitle, $estart, $estop, $chan, $tstart, $tstop, $tdir, $has_timer) = split(/:/);
        if ($title) {
            $title =~ s/\|/:/g;
            $title =~ s/\!\^pipe\^\!/\|/g;
        }
        if ($subtitle) {
            $subtitle =~ s/\|/:/g;
            $subtitle =~ s/\!\^pipe\^\!/\|/g;
        }
        if ($tdir) {
            $tdir =~ s/\|/:/g;
            $tdir =~ s/\!\^pipe\^\!/\|/g;
        }

        push(@result, { title    => $title,
                        subtitle => $subtitle,
                        date     => my_strftime("%A, %x", $estart),
                        start    => my_strftime("%H:%M", $estart),
                        stop     => my_strftime("%H:%M", $estop),
                        channel  => get_name_from_uniqid($chan),
                        folder   => $has_timer == 1 ? $tdir : gettext("--- no timer ---"),
                        recurl   => $has_timer == 1 ? undef : sprintf("%s?aktion=timer_new_form&amp;epg_id=%s&amp;channel_id=%s&amp;referer=%s", $MyURL, $event_id, $chan, Encode_Referer(getReferer())),
                        infurl   => $event_id ? sprintf("%s?aktion=prog_detail&amp;epg_id=%s&amp;channel_id=%s&amp;referer=%s", $MyURL, $event_id, $chan, $ref) : undef,
                        proglink => sprintf("%s?aktion=prog_list&amp;channel_id=%s", $MyURL, $chan)
                      }
        );
    }
    return @result;
}

sub ExtractEpgSearchConf {
    my $line = shift;

    my $timer;
        ($timer->{id},               # 1 - unique search timer id
         $timer->{pattern},          # 2 - the search term
         $timer->{use_time},         # 3 - use time? 0/1
         $timer->{time_start},       # 4 - start time in HHMM
         $timer->{time_stop},        # 5 - stop time in HHMM
         $timer->{use_channel},      # 6 - use channel? 0 = no,  1 = Intervall, 2 = Channel group, 3 = FTA only
         $timer->{channels},         # 7 - if 'use channel' = 1 then channel id[|channel id] in vdr format,
                                     #     one entry or min/max entry separated with |, if 'use channel' = 2
                                     #     then the channel group name
         $timer->{matchcase},        # 8 - match case? 0/1
         $timer->{mode},             # 9 - search mode:
                                     #      0 - the whole term must appear as substring
                                     #      1 - all single terms (delimiters are blank,',', ';', '|' or '~')
                                     #          must exist as substrings.
                                     #      2 - at least one term (delimiters are blank, ',', ';', '|' or '~')
                                     #          must exist as substring.
                                     #      3 - matches exactly
                                     #      4 - regular expression
         $timer->{use_title},        #10 - use title? 0/1
         $timer->{use_subtitle},     #11 - use subtitle? 0/1
         $timer->{use_descr},        #12 - use description? 0/1
         $timer->{use_duration},     #13 - use duration? 0/1
         $timer->{min_duration},     #14 - min duration in minutes
         $timer->{max_duration},     #15 - max duration in minutes
         $timer->{has_action},       #16 - use as search timer? 0/1
         $timer->{use_days},         #17 - use day of week? 0/1
         $timer->{which_days},       #18 - day of week (0 = sunday, 1 = monday...)
         $timer->{is_series},        #19 - use series recording? 0/1
         $timer->{directory},        #20 - directory for recording
         $timer->{prio},             #21 - priority of recording
         $timer->{lft},              #22 - lifetime of recording
         $timer->{bstart},           #23 - time margin for start in minutes
         $timer->{bstop},            #24 - time margin for stop in minutes
         $timer->{use_vps},          #25 - use VPS? 0/1
         $timer->{action},           #26 - action:
                                     #      0 = create a timer
                                     #      1 = announce only via OSD (no timer)
                                     #      2 = switch only (no timer)
         $timer->{use_extepg},       #27 - use extended EPG info? 0/1  #TODO
         $timer->{extepg_infos},     #28 - extended EPG info values. This entry has the following format #TODO
                                     #     (delimiter is '|' for each category, '#' separates id and value):
                                     #     1 - the id of the extended EPG info category as specified in
                                     #         epgsearchcats.conf
                                     #     2 - the value of the extended EPG info category
                                     #         (a ':' will be tranlated to "!^colon^!", e.g. in "16:9")
         $timer->{avoid_repeats},    #29 - avoid repeats? 0/1
         $timer->{allowed_repeats},  #30 - allowed repeats
         $timer->{comp_title},       #31 - compare title when testing for a repeat? 0/1
         $timer->{comp_subtitle},    #32 - compare subtitle when testing for a repeat? 0/1
         $timer->{comp_descr},       #33 - compare description when testing for a repeat? 0/1
         $timer->{comp_extepg_info}, #34 - compare extended EPG info when testing for a repeat? #TODO
                                     #     This entry is a bit field of the category ids.
         $timer->{repeats_in_days},  #35 - accepts repeats only within x days
         $timer->{delete_after},     #36 - delete a recording automatically after x days
         $timer->{keep_recordings},  #37 - but keep this number of recordings anyway
         $timer->{switch_before},    #38 - minutes before switch (if action = 2)
         $timer->{pause},            #39 - pause if x recordings already exist
         $timer->{use_blacklists},   #40 - blacklist usage mode (0 none, 1 selection, 2 all)
         $timer->{sel_blacklists},   #41 - selected blacklist IDs separated with '|'
         $timer->{fuzzy_tolerance},  #42 - fuzzy tolerance value for fuzzy searching
         $timer->{use_for_fav},      #43 - use this search in favorites menu (0 no, 1 yes)
         $timer->{results_menu},           #44 - menu to display results
         $timer->{autodelete},             #45 - delMode ( 0 = no autodelete, 1 = after x recordings, 2 = after y days after 1. recording)
         $timer->{del_after_recs},         #46 - delAfterCountRecs (x recordings)
         $timer->{del_after_days},         #47 - delAfterDaysOfFirstRec (y days)
         $timer->{searchtimer_from},       #48 - useAsSearchTimerFrom (if "use as search timer?" = 2)
         $timer->{searchtimer_until},      #49 - useAsSearchTimerTil (if "use as search timer?" = 2)
         $timer->{ignore_missing_epgcats}, #50 - ignoreMissingEPGCats
         $timer->{unmute},                 #51 - unmute sound if off when used as switch timer
         $timer->{min_match},              #52 - the minimum required match in percent when descriptions are compared to avoid repeats (-> 33)
         $timer->{unused}) = split(/:/, $line);

        #format selected fields
        $timer->{time_start} =~ s/(\d\d)(\d\d)/$1:$2/ if($timer->{time_start});
        $timer->{time_stop} =~ s/(\d\d)(\d\d)/$1:$2/ if($timer->{time_stop});
        $timer->{min_duration} =~ s/(\d\d)(\d\d)/$1:$2/ if($timer->{min_duration});
        $timer->{max_duration} =~ s/(\d\d)(\d\d)/$1:$2/ if($timer->{max_duration});

        if ($timer->{has_action}) {
            if ($timer->{action} == 0) {
                $timer->{action_text} = gettext("record");
            } elsif ($timer->{action} == 1) {
                $timer->{action_text} = gettext("announce by OSD");
            } elsif ($timer->{action} == 2) {
                $timer->{action_text} = gettext("switch only");
            } elsif ($timer->{action} == 3) {
                $timer->{action_text} = gettext("announce and switch");
            } elsif ($timer->{action} == 4) {
                $timer->{action_text} = gettext("announce by mail");
            } else {
                $timer->{action_text} = gettext("unknown");
            }
        } else {
            $timer->{action_text} = gettext("none");
        }

        if ($timer->{channels} && $timer->{use_channel} == 1) {
            ($timer->{channel_from}, $timer->{channel_to}) = split(/\|/, $timer->{channels}, 2);
            $timer->{channel_to} = $timer->{channel_from} unless ($timer->{channel_to});
            $timer->{channel_from_name} = get_name_from_uniqid($timer->{channel_from});
            $timer->{channel_to_name} = get_name_from_uniqid($timer->{channel_to});
            #TODO: links to channels
        }

        if ($timer->{use_days}) {
            if ($timer->{which_days} >= 0) {
                $timer->{sunday}    = 1 if ($timer->{which_days} == 0);
                $timer->{monday}    = 1 if ($timer->{which_days} == 1);
                $timer->{tuesday}   = 1 if ($timer->{which_days} == 2);
                $timer->{wednesday} = 1 if ($timer->{which_days} == 3);
                $timer->{thursday}  = 1 if ($timer->{which_days} == 4);
                $timer->{friday}    = 1 if ($timer->{which_days} == 5);
                $timer->{saturday}  = 1 if ($timer->{which_days} == 6);
            } else {
                my $which_days = -$timer->{which_days};
                $timer->{sunday}    = 1 if ($which_days &  1);
                $timer->{monday}    = 1 if ($which_days &  2);
                $timer->{tuesday}   = 1 if ($which_days &  4);
                $timer->{wednesday} = 1 if ($which_days &  8);
                $timer->{thursday}  = 1 if ($which_days & 16);
                $timer->{friday}    = 1 if ($which_days & 32);
                $timer->{saturday}  = 1 if ($which_days & 64);
            }
        }

        if ($timer->{pattern}) {
            $timer->{pattern} =~ s/\|/:/g;
            $timer->{pattern} =~ s/\!\^pipe\^\!/\|/g;
        }

        if ($timer->{directory}) {
            $timer->{directory} =~ s/\|/:/g;
            $timer->{directory} =~ s/\!\^pipe\^\!/\|/g;
        }

        if ($timer->{searchtimer_from}) {
            $timer->{searchtimer_from} = my_strftime("%Y-%m-%d", $timer->{searchtimer_from});
        }
        if ($timer->{searchtimer_until}) {
            $timer->{searchtimer_until} = my_strftime("%Y-%m-%d", $timer->{searchtimer_until});
        }
    return $timer;
}

sub validTime {
    my $t = shift;
    return unless ($t);
    my ($h, $m) = split(/:/, $t);
    $h = "0" . $h if (length($h) == 1);
    if (length($h) > 2) {  #TODO: $m defined?
        $m = substr($h, -2);
        $h = substr($h, 0, -2);
    }
    return sprintf("%02d%02d", $h, $m);
}

sub epgsearch_Param2Line {
    my $mode_blacklist = $q->param("mode_blacklist");
    my $weekdays_bits = 0;
    my $weekdays      = 0;
    my $had_weekday   = 0;

    if ($q->param("use_days")) {
        if ($q->param("sunday")) {
            $had_weekday++;
            $weekdays_bits |= 1;
            $weekdays = 0;
        }
        if ($q->param("monday")) {
            $had_weekday++;
            $weekdays_bits |= 2;
            $weekdays = 1;
        }
        if ($q->param("tuesday")) {
            $had_weekday++;
            $weekdays_bits |= 4;
            $weekdays = 2;
        }
        if ($q->param("wednesday")) {
            $had_weekday++;
            $weekdays_bits |= 8;
            $weekdays = 3;
        }
        if ($q->param("thursday")) {
            $had_weekday++;
            $weekdays_bits |= 16;
            $weekdays = 4;
        }
        if ($q->param("friday")) {
            $had_weekday++;
            $weekdays_bits |= 32;
            $weekdays = 5;
        }
        if ($q->param("saturday")) {
            $had_weekday++;
            $weekdays_bits |= 64;
            $weekdays = 6;
        }
        $weekdays_bits = - $weekdays_bits;
    }

    my $time_start = validTime($q->param("time_start"));
    my $time_stop  = validTime($q->param("time_stop"));
    my $min_duration = validTime($q->param("min_duration"));
    my $max_duration = validTime($q->param("max_duration"));

    my $use_channel = $q->param("use_channel");
    my $channels;
    if ($use_channel == 1) {
        $channels = $q->param("channel_from") . "|" . $q->param("channel_to");
    } elsif ($use_channel == 2) {
        $channels = $q->param("channel_group");
    }

    my $sel_blacklists;
    for ($q->param("sel_blacklists")) {
        $sel_blacklists .= "|" if (defined($sel_blacklists));
        $sel_blacklists .= $_;
    }

    my $pattern = $q->param("pattern");
    if ($pattern) {
        $pattern =~ s/\|/\!\^pipe\^\!/g;
        $pattern =~ s/:/\|/g;
    }

    my $directory = $q->param("directory");
    if ($directory) {
        $directory =~ s/\|/\!\^pipe\^\!/g;
        $directory =~ s/:/\|/g;
    }

    #TODO: $searchtimer_from & $searchtimer_until auf korrektes Format prüfen
    my $searchtimer_from = $q->param("searchtimer_from");
    if ($searchtimer_from) {
        $searchtimer_from = my_mktime("0", "0", substr($searchtimer_from, 8, 2), substr($searchtimer_from, 5, 2) - 1, substr($searchtimer_from, 0, 4));
    }
    my $searchtimer_until = $q->param("searchtimer_until");
    if ($searchtimer_until) {
        $searchtimer_until = my_mktime("0", "0", substr($searchtimer_until, 8, 2), substr($searchtimer_until, 5, 2) - 1, substr($searchtimer_until, 0, 4));
    }

    my $extepg_info;
    for ($q->param) {
        if (/extepg_([0-9]+)_data_text/) {
            my $e_id = $1;
            $extepg_info .= "|" if ($extepg_info);
            my $data = join(", ", $q->param("extepg_" . $e_id . "_data"));
            $data =~ s/:/\!\^colon\^\!/g;
            $data =~ s/\|/\!\^pipe\^\!/g;
            $extepg_info .= sprintf("%s#%s", $e_id, $data);
            my $data_text = $q->param("extepg_" . $e_id . "_data_text");
            if ($data_text) {
                $extepg_info .= ", " if ($data);
                $data_text =~ s/:/\!\^colon\^\!/g;
                $data_text =~ s/\|/\!\^pipe\^\!/g;
                $extepg_info .= $data_text;
            }
        }
    }

    my $cmd =  $pattern . ":"
               . ($q->param("use_time") ? "1" : "0") . ":"
               . $time_start . ":"
               . $time_stop . ":"
               . $use_channel . ":"
               . $channels . ":"
               . ($q->param("matchcase") ? "1" : "0") . ":"
               . $q->param("mode") . ":"
               . ($q->param("use_title") ? "1" : "0") . ":"
               . ($q->param("use_subtitle") ? "1" : "0") . ":"
               . ($q->param("use_descr") ? "1" : "0") . ":"
               . ($q->param("use_duration") ? "1" : "0") . ":"
               . $min_duration . ":"
               . $max_duration . ":";
    if ($mode_blacklist) {
        $cmd .= ($q->param("use_days") ? "1" : "0") . ":"
               . ($had_weekday > 1 ? $weekdays_bits : $weekdays) . ":"
               . ($q->param("use_extepg") ? "1" : "0") . ":"
               . $extepg_info . ":"
               . $q->param("fuzzy_tolerance") . ":"
               . $q->param("ignore_missing_epgcats");
    } else { # ! $mode_blacklist
        $cmd .= $q->param("has_action") . ":"
               . ($q->param("use_days") ? "1" : "0") . ":"
               . ($had_weekday > 1 ? $weekdays_bits : $weekdays) . ":"
               . ($q->param("is_series") ? "1" : "0") . ":"
               . $directory . ":"
               . $q->param("prio") . ":"
               . $q->param("lft") . ":"
               . $q->param("bstart") . ":"
               . $q->param("bstop") . ":"
               . ($q->param("use_vps") ? "1" : "0") . ":"
               . $q->param("action") . ":"
               . ($q->param("use_extepg") ? "1" : "0") . ":"
               . $extepg_info . ":"
               . ($q->param("avoid_repeats") ? "1" : "0") . ":"
               . $q->param("allowed_repeats") . ":"
               . ($q->param("comp_title") ? "1" : "0") . ":"
               . ($q->param("comp_subtitle") ? "1" : "0") . ":"
               . ($q->param("comp_descr") ? "1" : "0") . ":"
               . ($q->param("comp_extepg_info") ? "1" : "0") . ":"    #TODO
               . $q->param("repeats_in_days") . ":"
               . $q->param("delete_after") . ":"
               . $q->param("keep_recordings") . ":"
               . $q->param("switch_before") . ":"
               . $q->param("pause") . ":"
               . $q->param("use_blacklists") . ":"
               . $sel_blacklists . ":"
               . $q->param("fuzzy_tolerance") . ":"
               . ($q->param("use_for_fav") ? "1" : "0") . ":"
               .  $q->param("results_menu") . ":"
               .  $q->param("autodelete") . ":"
               .  $q->param("del_after_recs") . ":"
               .  $q->param("del_after_days") . ":"
               .  $searchtimer_from . ":"
               .  $searchtimer_until . ":"
               .  ($q->param("ignore_missing_epgcats") ? "1" : "0");

        if ($FEATURES{EPGSEARCH_VERSION} >= 925) {
            $cmd .= ":" . $q->param("unmute") . ":"
                    . $q->param("min_match");
        }
    }

    $cmd .= ":" . $q->param("unused") if ($q->param("unused"));
#print("CMD: $cmd\n");
    return $cmd;
}

sub epgsearch_save {
    my $cmd = (defined $q->param("id") ? "EDIS " . $q->param("id")
                                       : "NEWS 0")
               . ":" . epgsearch_Param2Line();
    SendCMD("plug epgsearch " . $cmd);
    return (headerForward("$MyURL?aktion=epgsearch_list"));
}

sub epgsearch_save_template {
    my $cmd = (defined $q->param("template_id") ? "EDIT " . $q->param("template_id")
                                                : "NEWT 0")
              . ":" . epgsearch_Param2Line();
    SendCMD("plug epgsearch " . $cmd);
    return (headerForward("$MyURL?aktion=epgsearch_list"));
}

sub epgsearch_delete_template {
    SendCMD("plug epgsearch DELT " . $q->param("template_id"));
    return (headerForward("$MyURL?aktion=epgsearch_list"));
}

sub epgsearch_delete {
    my $id = $q->param("id");
    if (defined $id) {
        SendCMD("plug epgsearch dels $id");
    } else {
        for ($q->param) {
            SendCMD("plug epgsearch dels $1") if (/xxxx_(.*)/);
        }
    }
    return (headerForward("$MyURL?aktion=epgsearch_list"));
}

sub epgsearch_toggle {
    my $id = $q->param("id");
    if (defined $id) {
        SendCMD(sprintf("plug epgsearch mods %s %s", $id, $q->param("active") ? "off" : "on"));
    }
    return (headerForward("$MyURL?aktion=epgsearch_list"));
}

sub epgsearch_getSettings {
    for (SendCMD("plug epgsearch setp")) {
        chomp;
        next if (length($_) == 0);
        $EPGSEARCH_SETTINGS{$1} = $2 if (/^([^:]*): (.*)/);
    }
}

sub epgsearch_upds {
    SendCMD("plug epgsearch upds osd");
    return (headerForward("$MyURL?aktion=epgsearch_list"));
}

sub epgsearch_getDefTimerCheckMethode {
    my $id = shift;
    return 0 unless($id);
    for (SendCMD(sprintf("plug epgsearch setp deftimercheckmethod %s", $id))) {
        chomp;
        next if (length($_) == 0);
        last if(/^invalid channel id$/);
        last if(/^unknown channel$/);
        my ($channel_id, $value) = split(/\: /, $_);
        return $value;
    }
    return 0;
}

sub epgsearch_config {
    my @list;
    for (ParseEpgSearchBlacklists(undef)) {
        $_->{modurl}  = $MyURL . "?aktion=epgsearch_bl_edit&amp;id=" . $_->{id};
        $_->{delurl}  = $MyURL . "?aktion=epgsearch_bl_delete&amp;id=" . $_->{id};
        push(@list, $_);
    }
    my $vars = { usercss          => $UserCSS,
                 url              => $MyURL,
                 list             => \@list
    };
    return showTemplate("epgsearch_config.html", $vars);
}

sub epgsearch_bl_edit {
    my $id = $q->param("id");

    my $blacklist;
    my @ch_groups;

    if (defined $id) {
        # edit blacklist
        my @temp = ParseEpgSearchBlacklists($id);
        $blacklist = pop @temp;
    } else {
        # new blacklist
        $blacklist->{use_title}    = 1;
        $blacklist->{use_subtitle} = 1;
        $blacklist->{use_descr}    = 1;
    }

    if ($blacklist->{use_channel} == 2) {
        for my $cg (ParseEpgSearchChanGroups(undef)) {
            $cg->{sel} = 1 if ($cg->{id} eq $blacklist->{channels}) ;
            push(@ch_groups, $cg);
        }
    } else {
        @ch_groups = ParseEpgSearchChanGroups(undef);
    }

    my @extepg = ParseEpgSearchExtEpgInfos($blacklist->{extepg_infos});
    if ($blacklist->{comp_extepg_info}) {
        foreach (@extepg) {
            if ($blacklist->{comp_extepg_info} & (1 << ($_->{id} - 1))) {
                $blacklist->{"comp_extepg_" . $_->{id}} = 1;
            }
        }
    }

    epgsearch_getSettings();

    my $vars = { usercss       => $UserCSS,
                 url           => $MyURL,
                 epgsearch     => $blacklist,
                 channels      => \@{$CHAN{$CHAN_FULL}->{channels}},
                 ch_groups     => \@ch_groups,
                 do_edit       => (defined $id ? "1" : undef),
                 extepg        => \@extepg,
                 mode_blacklist => 1
    };
    return showTemplate("epgsearch_new.html", $vars);
}

sub epgsearch_bl_save {
    my $cmd = (defined $q->param("id") ? "EDIB " . $q->param("id")
                                       : "NEWB 0")
               . ":" . epgsearch_Param2Line();
    SendCMD("plug epgsearch " . $cmd);
    return (headerForward("$MyURL?aktion=epgsearch_config"));
}

sub epgsearch_bl_delete {
    my $id = $q->param("id");
    if (defined $id) {
        SendCMD("plug epgsearch delb $id");
    } else {
        for ($q->param) {
            SendCMD("plug epgsearch delb $1") if (/xxxx_(.*)/);
        }
    }
    return (headerForward("$MyURL?aktion=epgsearch_config"));
}

sub ExtractEpgSearchBlacklistConf {
    my $line = shift;

    my $timer;
        ($timer->{id},               # 1 - unique search timer id
         $timer->{pattern},          # 2 - the search term
         $timer->{use_time},         # 3 - use time? 0/1
         $timer->{time_start},       # 4 - start time in HHMM
         $timer->{time_stop},        # 5 - stop time in HHMM
         $timer->{use_channel},      # 6 - use channel? 0 = no,  1 = Intervall, 2 = Channel group, 3 = FTA only
         $timer->{channels},         # 7 - if 'use channel' = 1 then channel id[|channel id] in vdr format,
                                     #     one entry or min/max entry separated with |, if 'use channel' = 2
                                     #     then the channel group name
         $timer->{matchcase},        # 8 - match case? 0/1
         $timer->{mode},             # 9 - search mode:
                                     #      0 - the whole term must appear as substring
                                     #      1 - all single terms (delimiters are blank,',', ';', '|' or '~')
                                     #          must exist as substrings.
                                     #      2 - at least one term (delimiters are blank, ',', ';', '|' or '~')
                                     #          must exist as substring.
                                     #      3 - matches exactly
                                     #      4 - regular expression
         $timer->{use_title},        #10 - use title? 0/1
         $timer->{use_subtitle},     #11 - use subtitle? 0/1
         $timer->{use_descr},        #12 - use description? 0/1
         $timer->{use_duration},     #13 - use duration? 0/1
         $timer->{min_duration},     #14 - min duration in minutes
         $timer->{max_duration},     #15 - max duration in minutes
         $timer->{use_days},         #16 - use day of week? 0/1
         $timer->{which_days},       #17 - day of week (0 = sunday, 1 = monday...)
         $timer->{use_extepg},       #18 - use extended EPG info? 0/1  #TODO
         $timer->{extepg_infos},     #19 - extended EPG info values. This entry has the following format #TODO
                                     #     (delimiter is '|' for each category, '#' separates id and value):
                                     #     1 - the id of the extended EPG info category as specified in
                                     #         epgsearchcats.conf
                                     #     2 - the value of the extended EPG info category
                                     #         (a ':' will be tranlated to "!^colon^!", e.g. in "16:9")
         $timer->{fuzzy_tolerance},  #20 - fuzzy tolerance value for fuzzy searching
         $timer->{ignore_missing_epgcats}, #21 - ignoreMissingEPGCats
         $timer->{unused}) = split(/:/, $line);

        #format selected fields
        $timer->{time_start} =~ s/(\d\d)(\d\d)/$1:$2/ if($timer->{time_start});
        $timer->{time_stop} =~ s/(\d\d)(\d\d)/$1:$2/ if($timer->{time_stop});
        $timer->{min_duration} =~ s/(\d\d)(\d\d)/$1:$2/ if($timer->{min_duration});
        $timer->{max_duration} =~ s/(\d\d)(\d\d)/$1:$2/ if($timer->{max_duration});

        if ($timer->{channels} && $timer->{use_channel} == 1) {
            ($timer->{channel_from}, $timer->{channel_to}) = split(/\|/, $timer->{channels}, 2);
            $timer->{channel_to} = $timer->{channel_from} unless ($timer->{channel_to});
            $timer->{channel_from_name} = get_name_from_uniqid($timer->{channel_from});
            $timer->{channel_to_name} = get_name_from_uniqid($timer->{channel_to});
            #TODO: links to channels
        }

        if ($timer->{use_days}) {
            if ($timer->{which_days} >= 0) {
                $timer->{sunday}    = 1 if ($timer->{which_days} == 0);
                $timer->{monday}    = 1 if ($timer->{which_days} == 1);
                $timer->{tuesday}   = 1 if ($timer->{which_days} == 2);
                $timer->{wednesday} = 1 if ($timer->{which_days} == 3);
                $timer->{thursday}  = 1 if ($timer->{which_days} == 4);
                $timer->{friday}    = 1 if ($timer->{which_days} == 5);
                $timer->{saturday}  = 1 if ($timer->{which_days} == 6);
            } else {
                my $which_days = -$timer->{which_days};
                $timer->{sunday}    = 1 if ($which_days &  1);
                $timer->{monday}    = 1 if ($which_days &  2);
                $timer->{tuesday}   = 1 if ($which_days &  4);
                $timer->{wednesday} = 1 if ($which_days &  8);
                $timer->{thursday}  = 1 if ($which_days & 16);
                $timer->{friday}    = 1 if ($which_days & 32);
                $timer->{saturday}  = 1 if ($which_days & 64);
            }
        }

        if ($timer->{pattern}) {
            $timer->{pattern} =~ s/\|/:/g;
            $timer->{pattern} =~ s/\!\^pipe\^\!/\|/g;
        }

    return $timer;
}

#############################################################################
# regulary timers
#############################################################################
sub my_mktime {
    my $sec  = 0;
    my $min  = shift;
    my $hour = shift;
    my $mday = shift;
    my $mon  = shift;
    my $year = shift() - 1900;

    #my $time = mktime($sec, $min, $hour, $mday, $mon, $year, 0, 0, (localtime(time))[8]);
    my $time = mktime($sec, $min, $hour, $mday, $mon, $year, 0, 0, -1);
}

sub ParseTimer {
    my $pc    = shift;    #TODO: what's this supposed to do?
    my $tid   = shift;
    my $entry = 1;

    my @temp;
    for (SendCMD("lstt")) {
        last if (/^No timers defined/);
        chomp;
        my ($id, $temp) = split(/ /, $_, 2);
        my ($active, $vdr_id, $dor, $start, $stop, $prio, $lft, $title, $summary) = split(/\:/, $temp, 9);

        my ($startsse, $stopsse, $weekday, $off, $perrec, $length, $first);

        my ($autotimer, $event_id, $bstart, $bstop, $pattern, $tool);
        ($autotimer, $event_id, $bstart, $bstop, $pattern, $tool) = extract_timer_metadata($summary);

        # VDR > 1.3.24 sets a bit if it's currently recording
        my $recording = 0;
        $recording = 1 if (($active & 8) == 8);
        $active    = 1 if ($active == 3 || $active == 9);

        #$active = 1 if(($active & 1) == 1); #TODO

        # replace "|" by ":" in timer's title (man vdr.5)
        $title =~ s/\|/\:/g;
        my $title_js = $title;
        $title_js =~ s/\'/\\\'/g;
        $title_js =~ s/\"/&quot;/g;

        if (length($dor) == 7) {    # repeating timer
            $startsse = my_mktime(substr($start, 2, 2), substr($start, 0, 2), my_strftime("%d"), (my_strftime("%m") - 1), my_strftime("%Y"));
            $stopsse  = my_mktime(substr($stop,  2, 2), substr($stop,  0, 2), my_strftime("%d"), (my_strftime("%m") - 1), my_strftime("%Y"));
            if ($stopsse < $startsse) {
                $stopsse += 86400;    # +1day
            }
            $weekday = ((localtime(time))[6] + 6) % 7;
            $perrec = join("", substr($dor, $weekday), substr($dor, 0, $weekday));
            $perrec =~ m/^-+/g;

            $off = (pos $perrec) * 86400;
            if ($off == 0 && $stopsse < time) {

                #$weekday = ($weekday + 1) % 7;
                $perrec = join("", substr($dor, ($weekday + 1) % 7), substr($dor, 0, ($weekday + 1) % 7));
                $perrec =~ m/^-+/g;
                $off = ((pos $perrec) + 1) * 86400;
            }
            $startsse += $off;
            $stopsse  += $off;
        } elsif (length($dor) == 18) {    # first-day timer
            $dor =~ /.{7}\@(\d\d\d\d)-(\d\d)-(\d\d)/;
            $startsse = my_mktime(substr($start, 2, 2), substr($start, 0, 2), $3, ($2 - 1), $1);

            # 31 + 1 = ??
            $stopsse = my_mktime(substr($stop, 2, 2), substr($stop, 0, 2), $stop > $start ? $3 : $3 + 1, ($2 - 1), $1);
        } else {                          # regular timer
            if ($dor =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) {    # vdr >= 1.3.23
                $startsse = my_mktime(substr($start, 2, 2), substr($start, 0, 2), $3, ($2 - 1), $1);
                $stopsse = my_mktime(substr($stop, 2, 2), substr($stop, 0, 2), $stop > $start ? $3 : $3 + 1, ($2 - 1), $1);
            } else {                                     # vdr < 1.3.23
                next unless($start || $stop);
                $startsse = my_mktime(substr($start, 2, 2), substr($start, 0, 2), $dor, (my_strftime("%m") - 1), my_strftime("%Y"));
                $stopsse = my_mktime(substr($stop, 2, 2), substr($stop, 0, 2), $stop > $start ? $dor : $dor + 1, (my_strftime("%m") - 1), my_strftime("%Y"));

                # move timers which have expired one month into the future
                if (length($dor) != 7 && $stopsse < time) {
                    $startsse = my_mktime(substr($start, 2, 2), substr($start, 0, 2), $dor, (my_strftime("%m") % 12), (my_strftime("%Y") + (my_strftime("%m") == 12 ? 1 : 0)));
                    $stopsse = my_mktime(substr($stop, 2, 2), substr($stop, 0, 2), $stop > $start ? $dor : $dor + 1, (my_strftime("%m") % 12), (my_strftime("%Y") + (my_strftime("%m") == 12 ? 1 : 0)));
                }
            }
        }

        if ($CONFIG{RECORDINGS} && length($dor) == 7) {    # repeating timer
                                                           # generate repeating timer entries for up to 28 days
            $first = 1;
            for ($weekday += $off / 86400, $off = 0 ; $off < 28 ; $off++) {
                $perrec = join("", substr($dor, ($weekday + $off) % 7), substr($dor, 0, ($weekday + $off) % 7));
                $perrec =~ m/^-+/g;
                next if ($perrec && ((pos $perrec) != 0));

                $length = push(
                    @temp,
                    { id          => $id,
                      vdr_id      => $vdr_id,
                      start       => $startsse,
                      stop        => $stopsse,
                      startsse    => $startsse + $off * 86400,
                      stopsse     => $stopsse + $off * 86400,
                      active      => $active,
                      recording   => $first ? $recording : 0,                                         # only the first might record
                      event_id    => $event_id,
                      cdesc       => get_name_from_vdrid($vdr_id),
                      transponder => get_transponder_from_vdrid($vdr_id),
                      ca          => get_ca_from_vdrid($vdr_id),
                      dor         => $dor,
                      prio        => $prio,
                      lft         => $lft,
                      title       => $title,
                      title_js    => $title_js,
                      summary     => $summary,
                      collision   => 0,
                      critical    => 0,
                      first       => $first,
                      proglink    => sprintf("%s?aktion=prog_list&amp;vdr_id=%s", $MyURL, $vdr_id),
                      autotimer   => $autotimer,
                      bstart      => $bstart,
                      bstop       => $bstop,
                      pattern     => $pattern,
                      tool        => $tool
                    }
                );
                $first = 0;
            }
        } else {
            $length = push(@temp,
                           {  id          => $id,
                              vdr_id      => $vdr_id,
                              start       => $startsse,
                              stop        => $stopsse,
                              startsse    => $startsse,
                              stopsse     => $stopsse,
                              active      => $active,
                              recording   => $recording,
                              event_id    => $event_id,
                              cdesc       => get_name_from_vdrid($vdr_id),
                              transponder => get_transponder_from_vdrid($vdr_id),
                              ca          => get_ca_from_vdrid($vdr_id),
                              dor         => $dor,
                              prio        => $prio,
                              lft         => $lft,
                              title       => $title,
                              title_js    => $title_js,
                              summary     => $summary,
                              collision   => 0,
                              critical    => 0,
                              first       => -1,
                              proglink    => sprintf("%s?aktion=prog_list&amp;vdr_id=%s", $MyURL, $vdr_id),
                              autotimer   => $autotimer,
                              bstart      => $bstart,
                              bstop       => $bstop,
                              pattern     => $pattern,
                              tool        => $tool
                           }
            );
        }

        # save index of entry with specific timer id for later use
        if ($tid && $tid == $id) {
            $entry = $length;
        }
    }

    if ($tid) {
        return ($temp[ $entry - 1 ]);
    } else {
        return (@temp);
    }
}

# extract our own metadata from a timer's aux field.
sub extract_timer_metadata {
    my $aux = shift;
    return unless ($aux =~ /<vdradmin-am>(.*)<\/vdradmin-am>|<epgsearch>(.*)<\/epgsearch>/i);
    if ($1) { # VDRAdmin-AM AutoTimer
        $aux = $1;
        my $epg_id    = $1 if ($aux =~ /<epgid>(.*)<\/epgid>/i);
        my $autotimer = $1 if ($aux =~ /<autotimer>(.*)<\/autotimer>/i);
        my $bstart    = $1 if ($aux =~ /<bstart>(.*)<\/bstart>/i);
        my $bstop     = $1 if ($aux =~ /<bstop>(.*)<\/bstop>/i);
        my $pattern   = $1 if ($aux =~ /<pattern>(.*)<\/pattern>/i);
        return ($autotimer, $epg_id, $bstart, $bstop, $pattern, $TOOL_AUTOTIMER);
    } elsif ($2) { # EPGSearch
        $aux = $2;
        my $epg_id    = $1 if ($aux =~ /<eventid>(.*)<\/eventid>/i);
        my $autotimer = $1 if ($aux =~ /<update>(.*)<\/update>/i);
        my $bstart    = $1 if ($aux =~ /<bstart>(.*)<\/bstart>/i);
        my $bstop     = $1 if ($aux =~ /<bstop>(.*)<\/bstop>/i);
        return ($autotimer, $epg_id, $bstart, $bstop, undef, $TOOL_EPGSEARCH);
    }
}

sub append_timer_metadata {
    my ($aux, $epg_id, $autotimer, $bstart, $bstop, $pattern, $tool) = @_;

    if ($tool == $TOOL_AUTOTIMER) {
        # remove old autotimer info
        $aux =~ s/\|?<vdradmin-am>.*<\/vdradmin-am>//i if ($aux);
        $aux = substr($aux, 0, 9000) if ($FEATURES{VDRVERSION} < 10336 and length($aux) > 9000);

        # add a new line if VDR<1.3.44 because then there might be a summary
        $aux .= "|" if ($FEATURES{VDRVERSION} < 10344 and length($aux));
        $aux .= "<vdradmin-am>";
        $aux .= "<epgid>$epg_id</epgid>" if ($epg_id);
        $aux .= "<autotimer>$autotimer</autotimer>" if ($autotimer);
        $aux .= "<bstart>$bstart</bstart>" if ($bstart);
        $aux .= "<bstop>$bstop</bstop>" if ($bstop);
        $aux .= "<pattern>$pattern</pattern>" if ($pattern);
        $aux .= "</vdradmin-am>";
    } elsif ($tool == $TOOL_EPGSEARCH) {
        # remove old epgsearch info
        $aux =~ s/\|?<epgsearch>.*<\/epgsearch>//i if ($aux);
        $aux = substr($aux, 0, 9000) if ($FEATURES{VDRVERSION} < 10336 and length($aux) > 9000);

        # add a new line if VDR<1.3.44 because then there might be a summary
        $aux .= "|" if ($FEATURES{VDRVERSION} < 10344 and length($aux));
        $aux .= "<epgsearch>";
        $aux .= "<eventid>$epg_id</eventid>" if ($epg_id);
        $aux .= "<update>$autotimer</update>" if (defined $autotimer);
        $aux .= "<bstart>" . ($bstart * 60) . "</bstart>" if ($bstart);
        $aux .= "<bstop>" . ($bstop * 60) . "</bstop>" if ($bstop);
        $aux .= "</epgsearch>";
    }
    return $aux;
}

#############################################################################
# Tools
#############################################################################
sub DisplayMessage {
    my $message = shift;
    SendCMD(sprintf("mesg %s", $message));
}

sub LoadTranslation {
    undef %ERROR_MESSAGE;

    %ERROR_MESSAGE = (not_found      => gettext("Not found"),
                      notfound_long  => gettext("The requested URL was not found on this server!"),
                      notfound_file  => gettext("The URL \"%s\" was not found on this server!"),
                      forbidden      => gettext("Forbidden"),
                      forbidden_long => gettext("You don't have permission to access this function!"),
                      forbidden_file => gettext("Access to file \"%s\" denied!"),
                      cant_open      => gettext("Can't open file \"%s\"!"),
                      connect_failed => gettext("Can't connect to VDR at %s:%s: %s<br /><br />Please check if VDR is running and if VDR's svdrphosts.conf is configured correctly."),
                      send_command   => gettext("Error while sending command to VDR at %s"),
    );

    setlocale(LC_ALL, $CONFIG{LANG});
    if (! $CONFIG{LANG} eq '') {
        setlocale(LC_ALL, $CONFIG{LANG});
        chomp($MY_ENCODING = `LC_ALL=$CONFIG{LANG} locale charmap`);
    }
    else {
        chomp($MY_ENCODING = `locale charmap`);
    }
    $MY_ENCODING = "UTF-8" unless ($MY_ENCODING);
    bind_textdomain_codeset("vdradmin", $MY_ENCODING) if($can_use_bind_textdomain_codeset);
    CGI::charset($MY_ENCODING);
}

sub HelpURL {
    my $area = shift;
    return (sprintf("%s?aktion=show_help&amp;area=%s", $MyURL, $area));
}

sub ProgTimer {

    # $start and $stop are expected as seconds since 00:00:00 1970-01-01 UTC.
    my ($timer_id, $active, $event_id, $channel, $start, $stop, $prio, $lft, $title, $summary, $dor) = @_;

    $title =~ s/\:/|/g;    # replace ":" by "|" in timer's title (man vdr.5)

    my $send_cmd = $timer_id ? "modt $timer_id" : "newt";
    my $send_dor = $dor ? $dor : RemoveLeadingZero(strftime("%d", localtime($start)));
    my $send_summary = ($FEATURES{VDRVERSION} >= 10336) ? $summary : substr($summary, 0, $VDR_MAX_SVDRP_LENGTH - 9 - length($send_cmd) - length($active) - length($channel) - length($send_dor) - 8 - length($prio) - length($lft) - length($title));

    Log(LOG_DEBUG, sprintf("[SVDRP] ProgTimer: Programming Timer \"%s\" (Channel %s, Event-ID %s, %s - %s, Active %s)", $title, $channel, $event_id, my_strftime("%Y%m%d-%H%M", $start), my_strftime("%Y%m%d-%H%M", $stop), $active));
    my $return = SendCMD(sprintf("%s %s:%s:%s:%s:%s:%s:%s:%s:%s", $send_cmd, $active, $channel, $send_dor, strftime("%H%M", localtime($start)), strftime("%H%M", localtime($stop)), $prio, $lft, trim($title), $send_summary));
    return $return;
}

sub RedirectToReferer {
    my $url = shift;
    if ($Referer =~ /vdradmin\.pl\?.*$/) {
        return (headerForward($Referer));
    } else {
        return (headerForward($url));
    }
}

sub salt {    #TODO: unused
    $_ = $_[0];
    my $string;
    my ($offset1, $offset2);
    if (length($_) > 8) {
        $offset1 = length($_) - 9;
        $offset2 = length($_) - 1;
    } else {
        $offset1 = 0;
        $offset2 = length($_) - 1;
    }
    $string = substr($_, $offset1, 1);
    $string .= substr($_, $offset2, 1);
    return ($string);
}

sub SigDieHandler {
    my $error = $_[0];
    CloseSocket();
    my $vars = { error   => gettext("Internal error:") . "<br />$error"
    };
    return showTemplate("error.html", $vars);
}

sub Shutdown {
    CloseSocket();
    if ($CONFIG{AUTO_SAVE_CONFIG}) {
        (my $err = WriteConfig()) =~ s|<br\s*/?>$||gi;
        Log(LOG_ERROR, $err) if $err;
    }
    closelog();
    if ($DAEMON) {
        unlink($PIDFILE) or Log(LOG_WARNING, "Can't delete pid file '$PIDFILE': $!");
    }
    exit(0);
}

sub getPID {
    my $pidfile = shift;
    if (!open(PID, $pidfile)) {
        Log(LOG_WARNING, "Can't open pid file '$pidfile' for reading: $!");
        return undef;
    }
    chomp(my $pid = <PID> || "");
    close(PID) or Log(LOG_WARNING, "Error closing pid file '$pidfile': $!");
    if ($pid !~ /^\d+$/) {
        Log(LOG_WARNING, "Ignoring bogus process id '$pid' in pid file '$pidfile'");
        $pid = undef;
    }
    return $pid;
}

sub writePID {
    my $pidfile = shift;
    if (!open(FILE, ">", $pidfile)) {
        Log(LOG_ERROR, "Can't open pid file '$pidfile' for writing: $!");
        return 0;
    }
    print FILE shift;
    close(FILE) or Log(LOG_WARNING, "Error closing pid file '$pidfile': $!");
    return 1;
}

sub HupSignal {
    UptoDate(1);
}

sub UptoDate {
    my $force = shift;
    my $rv = 0;
    if (((time() - $CONFIG{CACHE_LASTUPDATE}) >= ($CONFIG{CACHE_TIMEOUT} * 60)) || $force) {
        OpenSocket();
        Log(LOG_INFO, "[EPG] Building channel tree...");
        ChanTree();
        Log(LOG_INFO, "[EPG] Finished building channel tree.");
        if (@{$CHAN{$CHAN_FULL}->{channels}}) {
            Log(LOG_INFO, "[EPG] Building EPG tree...");
            EPG_buildTree();
            Log(LOG_INFO, "[EPG] Finished building EPG tree.");
            $CONFIG{CACHE_LASTUPDATE} = time();

            if ($CONFIG{AT_FUNC} && $FEATURES{AUTOTIMER}) {
                CheckTimers();
                AutoTimer();
            }
        } else {
            $rv = 1;
        }
        CloseSocket();
    }
    return ($rv);
}

sub Log {
    if ($#_ >= 1) {
        return 1 unless $LOGGING;

        my $level = shift;
        chomp(my $message = join("", @_));

        my $my_loglevel = $CONFIG{LOGLEVEL};
        $my_loglevel = $LOGLEVEL if defined $LOGLEVEL;
        if ($my_loglevel >= shift @$level) {

            if ($LOG_TO_SYSLOG) {
                syslog(shift @$level, '%s', $message);
            } elsif ($LOGFILE eq "stderr" || $LOGFILE eq "syslog") {
                printf STDERR "%s: %s\n", my_strftime("%x %X"), $message;
            } else {
                if (open(LOGFILE, ">>", "$LOGDIR/$LOGFILE")) {
                    printf LOGFILE "%s: %s\n", my_strftime("%x %X"), $message;
                    close(LOGFILE);
                } else {
                    printf STDERR "%s: %s\n", my_strftime("%x %X"), "Could not open log file '$LOGDIR/$LOGFILE' for writing: $!";
                }
            }
        }
    } else {
        Log(LOG_FATALERROR, "[INT] bogus Log() call");
    }
}

sub showTemplate {
    my $file   = shift;
    my $vars   = shift;
    my $status = shift;
    my $ctype  = shift;

    $status = "200" unless($status);
    $ctype  = "text/html" unless($ctype);

    my $output;
    $Xtemplate->process("$CONFIG{TEMPLATE}/$file", $vars, \$output) || return (header("500", "text/html", $Xtemplate->error()));
    return (header($status, $ctype, $output));
}

sub my_strftime {
    my $format = shift;
    my $time   = shift;
    return (strftime($format, $time ? localtime($time) : localtime(time)));
}

sub GetFirstChannel {    #TODO: unused
    return ($CHAN{$CHAN_FULL}->{channels}[0]->{service_id});
}

sub ChannelHasEPG {
    my $service_id = shift;
    for my $event (@{ $EPG{$service_id} }) {
        return (1);
    }
    return (0);
}

sub Encode_Referer {
    if ($_[0]) { $_ = $_[0]; }
    else { $_ = $Referer; }
    return (MIME::Base64::encode_base64(sprintf("%s", $_), ""));
}

sub Decode_Referer {
    my $text = shift;
    $text =~ s/ /+/g;
    my $ref = MIME::Base64::decode_base64($text);
    return ($ref);
}

sub encode_ref {    #TODO: unused
    my ($tmp) = $_[0]->url(-relative => 1, -query => 1);
    my (undef, $query) = split(/\?/, $tmp, 2);
    return (MIME::Base64::encode_base64($query, ""));
}

sub decode_ref {    #TODO: unused
    return (MIME::Base64::decode_base64($_[0]));
}

sub access_log {
    my $ip               = shift;
    my $username         = shift;
    my $rawrequest       = shift;
    my $http_status      = shift;
    my $bytes_transfered = shift;
    my $request          = shift;
    my $useragent        = shift;
    return sprintf("%s %s \"%s\" %s %s \"%s\" \"%s\"", $ip, defined($username) ? $username : "-", $rawrequest, $http_status ? $http_status : "-", $bytes_transfered ? $bytes_transfered : "-", $request, $useragent);
}

sub ValidConfig {
    $CONFIG{SKIN}     = "default" unless($CONFIG{SKIN});
    $CONFIG{TEMPLATE} = "default" unless($CONFIG{TEMPLATE});
    $CONFIG{TV_MIMETYPE}  = "video/x-mpegurl" if (!$CONFIG{TV_MIMETYPE});
    $CONFIG{TV_EXT}       = "m3u"             if (!$CONFIG{TV_EXT});
    $CONFIG{REC_MIMETYPE} = "video/x-mpegurl" if (!$CONFIG{REC_MIMETYPE});
    $CONFIG{REC_EXT}      = "m3u"             if (!$CONFIG{REC_EXT});
    $CONFIG{SRCH1_ACTIVE} = 1 unless (defined $CONFIG{SRCH1_ACTIVE});
    $CONFIG{SRCH1_URL}    = "http://akas.imdb.com/Tsearch?title=\%TITLE\%" unless (defined $CONFIG{SRCH1_URL});
    $CONFIG{SRCH1_TITLE}  = gettext("Lookup movie in the Internet-Movie-Database (IMDb)") unless (defined $CONFIG{SRCH1_TITLE});

    if ($CONFIG{AT_OFFER} == 2) {
        # User wants to use AutoTimer
        $FEATURES{AUTOTIMER} = 1;
    } elsif ($CONFIG{AT_OFFER} == 1) {
        # User doesn't want AutoTimer
        $FEATURES{AUTOTIMER} = 0;
    } else {
        # No decision made yet
        if (-s $AT_FILENAME && $CONFIG{AT_FUNC}) {
            $FEATURES{AUTOTIMER} = 1;
            $CONFIG{AT_OFFER} = 0;
        } else {
            $CONFIG{AT_FUNC} = 0;
            $FEATURES{AUTOTIMER} = 0;
            $CONFIG{AT_OFFER} = 1;
        }
    }

    $CONFIG{GUI_POPUP_WIDTH} = 500 unless ($CONFIG{GUI_POPUP_WIDTH} =~ /\d+/);
    $CONFIG{GUI_POPUP_HEIGHT} = 250 unless ($CONFIG{GUI_POPUP_HEIGHT} =~ /\d+/);
}

sub ReadConfig {
    if (-e $CONFFILE) {
        if (open(CONF, $CONFFILE)) {
            while (<CONF>) {
                chomp;
                my ($key, $value) = split(/ \= /, $_, 2);
                $CONFIG{$key} = $value;
            }
            close(CONF) or Log(LOG_WARNING, "Error closing conf file '$CONFFILE': $!");
        } else {
            Log(LOG_ERROR, "Can't open conf file '$CONFFILE' for reading: $!");
        }

        ValidConfig();

        #Migrate settings
        #v3.4.5
        $CONFIG{MAIL_FROM} = "autotimer@" . $CONFIG{MAIL_FROMDOMAIN} if ($CONFIG{MAIL_FROM} =~ /from\@address.tld/);
        #v3.4.6beta
        $CONFIG{SKIN} = "default" if(($CONFIG{SKIN} eq "bilder") || ($CONFIG{SKIN} eq "copper") || ($CONFIG{SKIN} eq "default.png"));
        #v3.5.3
        delete $CONFIG{EPG_DIRECT};
        delete $CONFIG{EPG_FILENAME};
        #v3.5.4rc
        if (defined $CONFIG{AT_TIMEOUT}) {
            $CONFIG{CACHE_TIMEOUT} = $CONFIG{AT_TIMEOUT} if ($CONFIG{AT_TIMEOUT} < $CONFIG{CACHE_TIMEOUT});
            delete $CONFIG{AT_TIMEOUT};
        }
        #v3.6.2
        delete $CONFIG{VDRVFAT};
        #v3.6.5
        $CONFIG{LOGLEVEL} = 4 if ($CONFIG{LOGLEVEL} == 81);

    } else {
        print "$CONFFILE doesn't exist. Please run \"$EXENAME --config\"\n";
        print "Exiting!\n";
        exit(1);

        #open(CONF, ">$CONFFILE");
        #for(keys(%CONFIG)) {
        #  print(CONF "$_ = $CONFIG{$_}\n");
        #}
        #close(CONF);
        #return(1);
    }
    return (0);
}

sub Question {
    my ($quest, $default) = @_;
    print("$quest [$default]: ");
    my ($answer);
    chomp($answer = <STDIN>);
    if ($answer eq "") {
        return ($default);
    } else {
        return ($answer);
    }
}

sub RemoveLeadingZero {
    my ($str) = @_;
    while (substr($str, 0, 1) == 0) {
        $str = substr($str, 1, (length($str) - 1));
    }
    return ($str);
}

sub csvAdd {
    my $csv = shift;
    my $add = shift;

    my $found = 0;
    for my $item (split(",", $csv)) {
        $found = 1 if ($item eq $add);
    }
    $csv = join(",", (split(",", $csv), $add)) if (!$found);
    return ($csv);
}

sub csvRemove {
    my $csv    = shift;
    my $remove = shift;

    my $newcsv = "";
    for my $item (split(",", $csv)) {
        if ($item ne $remove) {
            my $found = 0;
            if (defined($newcsv)) {
                for my $dup (split(",", $newcsv)) {
                    $found = 1 if ($dup eq $item);
                }
            }
            $newcsv = join(",", (split(",", $newcsv), $item)) if (!$found);
        }
    }
    return ($newcsv);
}

sub Einheit {
    my @einheiten = qw(MB GB TB);
    my $einheit   = 0;
    my $zahl      = shift;
    while ($zahl > 1024) {
        $zahl /= 1024;
        $einheit++;
    }
    return (sprintf("%1.*f", $einheit, $zahl) . $einheiten[$einheit]);
}

sub MBToMinutes {
    my $mb      = shift;
    my $minutes = $mb / 25.75;
    my $hours   = $minutes / 60;
    $minutes %= 60;
    return (sprintf("%2d:%02d", $hours, $minutes));
}

sub VideoDiskFree {
    $_ = join("", SendCMD("stat disk"));
    if (/^(\d+)MB (\d+)MB (\d+)%.*?$/) {
        return (Einheit($1), MBToMinutes($1), Einheit($2), MBToMinutes($2), $3);
    } elsif (/^Command unrecognized: "stat"$/) {

        #print "VDR doesnt know about this extension\n";
    } else {
        print "Unknown response $_\n";
    }
    return undef;
}

#############################################################################
# frontend
#############################################################################
sub show_index {
    return if (UptoDate() != 0);
    my $page;
    if (defined($CONFIG{LOGINPAGE})) {
        $page = $LOGINPAGES[ $CONFIG{LOGINPAGE} ];
    } else {
        $page = $LOGINPAGES[0];
    }
    my $vars = { loginpage => "$MyURL?aktion=$page",
                 version   => $VERSION,
                 host      => $CONFIG{VDR_HOST}
    };
    return showTemplate("index.html", $vars);
}

sub show_navi {
    my $vars = { };
    return showTemplate("navigation.html", $vars);
}

sub prog_switch {
    my $channel = $q->param("channel");
    if ($channel) {
        SendCMD("chan $channel");
    }
    SendFile("bilder/spacer.gif");
}

sub prog_detail {
    return if (UptoDate() != 0);
    my $vdr_id = $q->param("vdr_id");
    my $epg_id = $q->param("epg_id");

    my ($channel_name, $title, $subtitle, $vps, $video, $audio, $start, $stop, $text, @epgimages);

    my @timers = ParseTimer(0);

    if ($q->param("channel_id")) {
        $vdr_id = get_vdrid_from_channelid($q->param("channel_id"));
    }
    if ($vdr_id && $epg_id) {
        for (@{ $EPG{$vdr_id} }) {

            #if($_->[EV_ID] == $epg_id) { #XXX
            if ($_->[EV_EVENT_ID] == $epg_id) {
                $channel_name = $_->[EV_CHANNEL_NAME];
                $title        = $_->[EV_TITLE];
                $subtitle     = $_->[EV_SUBTITLE];
                $start        = $_->[EV_START];
                $stop         = $_->[EV_STOP];
                $text         = $_->[EV_SUMMARY];
                $vps          = $_->[EV_VPS];
                $video        = $_->[EV_VIDEO];
                $audio        = $_->[EV_AUDIO];

                # find epgimages
                if ($CONFIG{EPGIMAGES} && -d $CONFIG{EPGIMAGES}) {
                    for my $epgimage (<$CONFIG{EPGIMAGES}/$epg_id\[\._\]*>) {
                        $epgimage =~ s/.*\///g;
                        push(@epgimages, { image => "epg/" . $epgimage });
                    }
                }
                last;
            }
        }
    }

    my $displaytext     = CGI::escapeHTML($text);
    my $displaytitle    = CGI::escapeHTML($title);
    my $displaysubtitle = CGI::escapeHTML($subtitle);

    my $search_title = $title;
    $search_title =~ s/^.*\~\%*([^\~]*)$/$1/;
    $search_title =  uri_escape($search_title);

    my $imdb_url = undef;
    if ($search_title && $CONFIG{SRCH1_ACTIVE}) {
        $imdb_url =  $CONFIG{SRCH1_URL};
        $imdb_url =~ s/\%TITLE\%/$search_title/g;
    }

    my $srch2_url = undef;
    if ($search_title && $CONFIG{SRCH2_ACTIVE}) {
        $srch2_url =  $CONFIG{SRCH2_URL};
        $srch2_url =~ s/\%TITLE\%/$search_title/g;
    }

    if ($displaytext) {
        $displaytext  =~ s/\n/<br \/>\n/g;
        $displaytext  =~ s/\|/<br \/>\n/g;
    }
    if ($displaytitle) {
        $displaytitle =~ s/\n/<br \/>\n/g;
        $displaytitle =~ s/\|/<br \/>\n/g;
    }
    if ($displaysubtitle) {
        $displaysubtitle =~ s/\n/<br \/>\n/g;
        $displaysubtitle =~ s/\|/<br \/>\n/g;
    }

    # Do not use prog_detail as referer.
    # Use the referer we received.
    my $referer = getReferer();
    my ($recurl, $editurl);
    $recurl  = sprintf("%s?aktion=timer_new_form&amp;epg_id=%s&amp;vdr_id=%s&amp;referer=%s", $MyURL, $epg_id, $vdr_id, Encode_Referer($referer)) unless ($referer =~ "timer_list");
    $editurl = sprintf("%s?aktion=prog_detail_form&amp;epg_id=%s&amp;vdr_id=%s&amp;referer=%s", $MyURL, $epg_id, $vdr_id, Encode_Referer($referer));

    my $timerset = 0;
    foreach my $timer (@timers) {
      if (($timer->{vdr_id} == $vdr_id) && ($timer->{start} <= $start) && ($timer->{stop} >= $stop)) {
        $timerset = 1;
        last;
      }
    }

    my $now = time();
    my $vars = { title        => $displaytitle ? $displaytitle : gettext("Can't find EPG entry!"),
                 recurl       => $recurl,
                 editurl      => $editurl,
                 switchurl    => ($start && $stop && $start <= $now && $now <= $stop) ? sprintf("%s?aktion=prog_switch&amp;channel=%s", $MyURL, $vdr_id) : undef,
                 channel_name => CGI::escapeHTML($channel_name),
                 subtitle     => $displaysubtitle,
                 vps          => ($vps && $start && $start != $vps) ? my_strftime("%H:%M", $vps) : undef,
                 start        => my_strftime("%H:%M", $start),
                 stop         => my_strftime("%H:%M", $stop),
                 text         => $displaytext ? $displaytext : undef,
                 date         => $title ? my_strftime("%A, %x", $start) : undef,
                 find_title   => $title ? uri_escape("/^" . my_quotemeta($title . "~" . ($subtitle ? $subtitle : "") . "~") . "/") : undef,
                 srch1_url    => $imdb_url,
                 srch1_title  => $imdb_url ? gettext($CONFIG{SRCH1_TITLE}) : undef,
                 srch2_url    => $srch2_url,
                 srch2_title  => $srch2_url ? gettext($CONFIG{SRCH2_TITLE}) : undef,
                 epgimages    => \@epgimages,
                 audio        => $audio,
                 video        => $video,
                 vdr_id       => $vdr_id,
                 epg_id       => $epg_id,
                 timerset     => $timerset,
    };
    return showTemplate("prog_detail.html", $vars);
}


sub prog_detail_form {

    # determine referer (redirect to where we come from)
    my $ref = getReferer();

    my $vdr_id = $q->param("vdr_id");
    my $epg_id = $q->param("epg_id");

    my $vars;
    if ($epg_id) {
        my $event = EPG_getEntry($vdr_id, $epg_id);
        my $displaytitle       = CGI::escapeHTML($event->[EV_TITLE]);
        my $displaysubtitle    = CGI::escapeHTML($event->[EV_SUBTITLE]);
        my $displaydescription = CGI::escapeHTML($event->[EV_SUMMARY]);
        if ($displaydescription) {
            $displaydescription =~ s/\|/\n/g;
        }

        $vars = { url          => $MyURL,
                  vdr_id       => $event->[EV_VDR_ID],
                  epg_id       => $event->[EV_EVENT_ID],
                  channel_name => $event->[EV_CHANNEL_NAME],
                  start_hr     => sprintf("%s - %s", my_strftime("%A, %x %H:%M", $event->[EV_START]), my_strftime("%H:%M", $event->[EV_STOP])),
                  start        => $event->[EV_START],
                  duration     => $event->[EV_DURATION],
                  #table_id     => $event->{table_id},
                  #version      => $event->{version},
                  title        => $displaytitle,
                  subtitle     => $displaysubtitle,
                  description  => $displaydescription,
                  vps          => $event->[EV_VPS] ? my_strftime("%A, %x %H:%M", $event->[EV_VPS]) : undef,
                  video        => $event->[EV_VIDEO],
                  audio        => $event->[EV_AUDIO],
                  referer      => $ref ? Encode_Referer($ref) : undef,
                  help_url     => HelpURL("edit_epg")
        }
    }

    return showTemplate("prog_detail_form.html", $vars);
}

sub prog_detail_aktion {
    if ($q->param("save")) {
        my $vdr_id      = $q->param("vdr_id");
        my $event_id    = $q->param("epg_id");
        my $channel_id  = get_channelid_from_vdrid($vdr_id);
        my $start       = $q->param("start");
        my $duration    = $q->param("duration");
        my $title       = CGI::unescapeHTML(scalar $q->param("title"));
        my $subtitle    = CGI::unescapeHTML(scalar $q->param("subtitle"));
        my $description = CGI::unescapeHTML(scalar $q->param("description"));
        my $vps         = $q->param("vps");
        my $table_id    = 0;    # must be zero for external epg data

        my ($new_subtitle, $new_description, $new_video, $new_audio, $new_vps) = ("","","","","");
        my $event = EPG_getEntry($vdr_id, $event_id);

        if ($title) {
            $title =~ s/\r\n//g;
            $title =~ s/\n//g;
        } else {
            $title = $event->[EV_TITLE];
        }

        if ($subtitle) {
            $subtitle =~ s/\r\n//g;
            $subtitle =~ s/\n//g;
            $new_subtitle = sprintf ("S %s\n", $subtitle);
        }

        if ($description) {
            $description =~ s/\r\n/|/g;
            $description =~ s/\n/|/g;
            $new_description = sprintf ("D %s\n", $description);
        }

        $new_video = join ("\n", @{$event->[EV_VIDEO_RAW]});
        $new_video .= "\n" if ($new_video);
        $new_audio = join ("\n", @{$event->[EV_AUDIO_RAW]});
        $new_audio .= "\n" if ($new_audio);
        $new_vps = sprintf ("V %s\n", $event->[EV_VPS]) if ($event->[EV_VPS]);

        my ($result) = SendCMD("pute");
        if ($result !~ /Enter EPG data/i) {
            #printf "something went wrong during EPG update: $result\n";
            main::HTMLError(sprintf($ERROR_MESSAGE{send_command}, $CONFIG{VDR_HOST}));
        } else {
            ($result) = SendCMD(sprintf ("C %s\nE %u %ld %d %X\nT %s\n%s%s%s%s%se\nc\n.\n",
                $channel_id,
                $event_id, $start, $duration, $table_id,
                $title,
                $new_subtitle,
                $new_description,
                $new_video,
                $new_audio,
                $new_vps));
            if ($result !~ /EPG data processed/i) {
                #printf "something went wrong during EPG update: %s\n", $result;
                main::HTMLError(sprintf($ERROR_MESSAGE{send_command}, $CONFIG{VDR_HOST}));
            } else {
                # don't reread complete epg, just change the cache
                $event->[EV_TITLE] = $title;
                $event->[EV_SUBTITLE] = $subtitle;
                $event->[EV_SUMMARY] = $description;
            }
        }
    }

    my $ref = getReferer();
    if ($ref) {
        return (headerForward($ref));
    } else {
        return (headerForward("$MyURL?aktion=prog_summary"));
    }
}
#############################################################################
# program listing
#############################################################################
sub prog_list {
    return if (UptoDate() != 0);
    $CONFIG{CHANNELS_WANTED_PRG} = $q->param("wanted_channels") if (defined $q->param("wanted_channels"));
    my ($vdr_id, $dummy);
    ($vdr_id, $dummy) = split("#", $q->param("vdr_id"), 2) if ($q->param("vdr_id"));

    if ($q->param("channel_id")) {
        $vdr_id = get_vdrid_from_channelid($q->param("channel_id"));
    }

    my $myself = Encode_Referer($MyURL . "?" . $Query);
    my @timers = ParseTimer(0);

    #
    my (@channel, $current);
    for my $channel (@{$CHAN{$CONFIG{CHANNELS_WANTED_PRG}}->{channels}}) {

        # skip channels without EPG data
        if ($CONFIG{CHANNELS_WITHOUT_EPG} || ChannelHasEPG($channel->{vdr_id})) {
            # called without vdr_id, redirect to the first available channel
            $vdr_id = $channel->{vdr_id} if(!$vdr_id);
            $current = 1 if ($vdr_id == $channel->{vdr_id});
            push(@channel,
                 {  name    => $channel->{name} . (!$CONFIG{CHANNELS_WITHOUT_EPG} || ChannelHasEPG($channel->{vdr_id}) ? '' : ' (' . gettext("No EPG information available") . ')'),
                    vdr_id  => $channel->{vdr_id},
                    current => ($vdr_id == $channel->{vdr_id}) ? 1 : 0,
                 }
            );
        }
    }

    unless ($current) {
        my $channel = get_channel_from_vdrid($vdr_id);
        if ($channel) {
            unshift(@channel,
                    {   name    => '[' . $channel->{name} .']' . (!$CONFIG{CHANNELS_WITHOUT_EPG} || ChannelHasEPG($channel->{vdr_id}) ? '' : ' (' . gettext("No EPG information available") . ')'),
                        vdr_id  => $channel->{vdr_id},
                        current => 1
                    }
            );
        } else {
            $vdr_id = $channel[0]->{vdr_id};
        }
    }

    # find the next/prev channel
    my $ci = 0;
    for (my $i = 0 ; $i <= $#channel ; $i++) {
        ($ci = $i) if ($vdr_id == $channel[$i]->{vdr_id});
    }
    my ($next_channel, $prev_channel, $next_channel_name, $prev_channel_name);
    if ($ci > 0) {
        $prev_channel = $channel[ $ci - 1 ]->{vdr_id};
        $prev_channel_name = $channel[ $ci - 1 ]->{name};
    }
    if ($ci < $#channel) {
        $next_channel = $channel[ $ci + 1 ]->{vdr_id};
        $next_channel_name = $channel[ $ci + 1 ]->{name};
    }

    #
    my (@show);
    my $day = 0;
    for my $event (@{ $EPG{$vdr_id} }) {
        if (my_strftime("%d", $event->[EV_START]) != $day) {

            # new day
            push(@show,
                 {  endd => 1,
                    next_channel => $next_channel ? "$MyURL?aktion=prog_list&amp;vdr_id=$next_channel" : undef,
                    prev_channel => $prev_channel ? "$MyURL?aktion=prog_list&amp;vdr_id=$prev_channel" : undef,
                    next_channel_name => $next_channel_name,
                    prev_channel_name => $prev_channel_name,
                 }
            ) if (scalar(@show) > 0);
            push(@show,
                 {  progname => $event->[EV_CHANNEL_NAME],
                    longdate => my_strftime("%A, %x", $event->[EV_START]),
                    newd  => 1,
                    next_channel => $next_channel ? "$MyURL?aktion=prog_list&amp;vdr_id=$next_channel" : undef,
                    prev_channel => $prev_channel ? "$MyURL?aktion=prog_list&amp;vdr_id=$prev_channel" : undef,
                    next_channel_name => $next_channel_name,
                    prev_channel_name => $prev_channel_name,
                 }
            );
            $day = strftime("%d", localtime($event->[EV_START]));
        }

        my $search_title = $event->[EV_TITLE];
        $search_title =~ s/^.*\~\%*([^\~]*)$/$1/;
        $search_title =  uri_escape($search_title);

        my $imdb_url = undef;
        if ($search_title && $CONFIG{SRCH1_ACTIVE}) {
            $imdb_url =  $CONFIG{SRCH1_URL};
            $imdb_url =~ s/\%TITLE\%/$search_title/g;
        }

        my $srch2_url = undef;
        if ($search_title && $CONFIG{SRCH2_ACTIVE}) {
            $srch2_url =  $CONFIG{SRCH2_URL};
            $srch2_url =~ s/\%TITLE\%/$search_title/g;
        }

        my $subtitle = "";
        if ($CONFIG{EPG_SUBTITLE}) {
            $subtitle = CGI::escapeHTML($event->[EV_SUBTITLE]);
        }
        if ($CONFIG{EPG_SUMMARY}) {
            if (length($subtitle)) {
                $subtitle .= "<BR />";
            }
            $subtitle .= CGI::escapeHTML($event->[EV_SUMMARY]);
            $subtitle =~ s/\|/<BR \/>/g;
        }

        my $timerset = 0;
        foreach my $timer (@timers) {
            if (($timer->{vdr_id} == $vdr_id) && ($timer->{start} <= $event->[EV_START]) && ($timer->{stop} >= $event->[EV_STOP])) {
                $timerset = 1;
                last;
            }
        }

        push(@show,
             {  ssse     => $event->[EV_START],
                emit     => my_strftime("%H:%M", $event->[EV_START]),
                duration => my_strftime("%H:%M", $event->[EV_STOP]),
                title    => CGI::escapeHTML($event->[EV_TITLE]),
                subtitle => $subtitle,
                recurl   => sprintf("%s?aktion=timer_new_form&amp;epg_id=%s&amp;vdr_id=%s&amp;referer=%s", $MyURL, $event->[EV_EVENT_ID], $event->[EV_VDR_ID], $myself),
                infurl   => $event->[EV_SUMMARY] ? sprintf("%s?aktion=prog_detail&amp;epg_id=%s&amp;vdr_id=%s&amp;referer=%s", $MyURL, $event->[EV_EVENT_ID], $event->[EV_VDR_ID], $myself) : undef,
                editurl  => sprintf("%s?aktion=prog_detail_form&amp;epg_id=%s&amp;vdr_id=%s&amp;referer=%s", $MyURL, $event->[EV_EVENT_ID], $event->[EV_VDR_ID], $myself),
                find_title => uri_escape("/^" . my_quotemeta($event->[EV_TITLE] . "~" . ($event->[EV_SUBTITLE] ? $event->[EV_SUBTITLE] : "") . "~") . "/"),
                srch1_url    => $imdb_url,
                srch1_title  => $imdb_url ? gettext($CONFIG{SRCH1_TITLE}) : undef,
                srch2_url    => $srch2_url,
                srch2_title  => $srch2_url ? gettext($CONFIG{SRCH2_TITLE}) : undef,
                newd     => 0,
                anchor   => "id" . $event->[EV_EVENT_ID],
                timerset => $timerset
             }
        );
    }
    if (scalar(@show)) {
        push(@show, { endd => 1 });
    }

    #
    my $channel_name = GetChannelDescByNumber($vdr_id);
    my $now = time();
    my $vars = { url            => $MyURL,
                 loop           => \@show,
                 chanloop       => \@channel,
                 progname       => $channel_name,
                 switchurl      => "$MyURL?aktion=prog_switch&amp;channel=$vdr_id",
                 streamurl      => $FEATURES{LIVESTREAM} ? sprintf("%s%s?aktion=live_stream&amp;channel=%s&amp;progname=%s", $MyStreamBase, $CONFIG{TV_EXT}, $vdr_id, uri_escape($channel_name)) : undef,
                 stream_live_on => $FEATURES{LIVESTREAM} && $CONFIG{ST_FUNC} && $CONFIG{ST_LIVE_ON},
                 toolbarurl     => "$MyURL?aktion=toolbar",
                 ch_groups      => getChannelGroups($MyURL . "?aktion=prog_list&amp;vdr_id=$vdr_id", $CONFIG{CHANNELS_WANTED_PRG})
    };
    return showTemplate("prog_list.html", $vars);
}

#############################################################################
# program listing 2
# "What's up today" extension.
#
# Contributed by Thomas Blon, 6. Mar 2004
#############################################################################
sub prog_list2 {
    return if (UptoDate() != 0);

    my $current_day = my_strftime("%Y%m%d");
    my $last_day    = 0;
    my $day         = $current_day;
    $day = $q->param("day") if ($q->param("day"));
    my $param_time  = $q->param("time");
    $CONFIG{CHANNELS_WANTED_PRG2} = $q->param("wanted_channels") if (defined $q->param("wanted_channels"));
    my ($start_hour, $start_min)  = getSplittedTime($CONFIG{EPG_START_TIME});
    my $day_start   = (($start_hour * 60) + $start_min) * 60;

    #
    my $vdr_id;
    my @channel;
    my $myself = Encode_Referer($MyURL . "?" . $Query);
    my @timers = ParseTimer(0);

    for my $channel (@{$CHAN{$CONFIG{CHANNELS_WANTED_PRG2}}->{channels}}) {

        # skip channels without EPG data
        if ($CONFIG{CHANNELS_WITHOUT_EPG} || ChannelHasEPG($channel->{vdr_id})) {
            push(@channel,
                 {  name   => $channel->{name},
                    vdr_id => $channel->{vdr_id}
                 }
            );
        }
    }

    my (@show, %hash_days);

    my ($hour, $minute) = getSplittedTime($param_time);
    my $border;
    $border = timelocal(0, $minute, $hour, substr($day, 6, 2), substr($day, 4, 2) - 1, substr($day, 0, 4)) if($day);
    my $time = getStartTime($param_time ? $param_time : undef, undef, $border);
    foreach (@channel) {    # loop through all channels
        $vdr_id = $_->{vdr_id};

        # find the next/prev channel
        my $ci = 0;
        for (my $i = 0 ; $i <= $#channel ; $i++) {
            ($ci = $i) if ($vdr_id == $channel[$i]->{vdr_id});
        }
        my ($next_channel, $prev_channel);
        ($prev_channel = $channel[ $ci - 1 ]->{vdr_id}) if ($ci > 0);
        ($next_channel = $channel[ $ci + 1 ]->{vdr_id}) if ($ci < $#channel);

        if (ChannelHasEPG($_->{vdr_id})) {
            my $dayflag = 0;

            for my $event (@{ $EPG{$vdr_id} }) {
                my $event_day      = my_strftime("%d.%m.", $event->[EV_START]-$day_start);
                my $event_day_long = my_strftime("%Y%m%d", $event->[EV_START]-$day_start);

                $hash_days{$event_day_long} = $event_day unless(exists $hash_days{$event_day_long});

                # print("EVENT: " . $event->[EV_TITLE] . " - "  . $event_day . "\n");
                if ($event_day_long == $day) {
                    $dayflag = 1 if ($dayflag == 0);
                } else {
                    $last_day = $event_day_long if ($event_day_long > $last_day);
                    $dayflag = 0;
                }

                if ($dayflag == 1 && $time < $event->[EV_STOP]) {
                    push(@show,
                         {  channel_name => $event->[EV_CHANNEL_NAME],
                            longdate  => my_strftime("%A, %x", $event->[EV_START]),
                            newd      => 1,
                            streamurl => $FEATURES{LIVESTREAM} ? sprintf("%s%s?aktion=live_stream&amp;channel=%s&amp;progname=%s", $MyStreamBase, $CONFIG{TV_EXT}, $event->[EV_VDR_ID], uri_escape($event->[EV_CHANNEL_NAME])) : undef,
                            switchurl => "$MyURL?aktion=prog_switch&amp;channel=" . $event->[EV_VDR_ID],
                            proglink  => "$MyURL?aktion=prog_list&amp;vdr_id=" . $event->[EV_VDR_ID]
                         }
                    );

                    $dayflag++;
                }

                if ($dayflag == 2) {
                    my $search_title = $event->[EV_TITLE];
                    $search_title =~ s/^.*\~\%*([^\~]*)$/$1/;
                    $search_title =  uri_escape($search_title);

                    my $imdb_url = undef;
                    if ($search_title && $CONFIG{SRCH1_ACTIVE}) {
                        $imdb_url =  $CONFIG{SRCH1_URL};
                        $imdb_url =~ s/\%TITLE\%/$search_title/g;
                    }

                    my $srch2_url = undef;
                    if ($search_title && $CONFIG{SRCH2_ACTIVE}) {
                        $srch2_url =  $CONFIG{SRCH2_URL};
                        $srch2_url =~ s/\%TITLE\%/$search_title/g;
                    }

                    my $subtitle = "";
                    if ($CONFIG{EPG_SUBTITLE}) {
                        $subtitle = CGI::escapeHTML($event->[EV_SUBTITLE]);
                    }
                    if ($CONFIG{EPG_SUMMARY}) {
                        if (length($subtitle)) {
                            $subtitle .= "<BR />";
                        }
                        $subtitle .= CGI::escapeHTML($event->[EV_SUMMARY]);
                        $subtitle =~ s/\|/<BR \/>/g;
                    }

                    my $timerset = 0;
                    foreach my $timer (@timers) {
                        if (($timer->{vdr_id} == $vdr_id) && ($timer->{start} <= $event->[EV_START]) && ($timer->{stop} >= $event->[EV_STOP])) {
                            $timerset = 1;
                            last;
                        }
                    }

                    push(@show,
                         {  ssse     => $event->[EV_START],
                            emit     => my_strftime("%H:%M", $event->[EV_START]),
                            duration => my_strftime("%H:%M", $event->[EV_STOP]),
                            title    => CGI::escapeHTML($event->[EV_TITLE]),
                            subtitle => $subtitle,
                            recurl   => sprintf("%s?aktion=timer_new_form&amp;epg_id=%s&amp;vdr_id=%s&amp;referer=%s", $MyURL, $event->[EV_EVENT_ID], $event->[EV_VDR_ID], $myself),
                            infurl   => $event->[EV_SUMMARY] ? sprintf("%s?aktion=prog_detail&amp;epg_id=%s&amp;vdr_id=%s&amp;referer=%s", $MyURL, $event->[EV_EVENT_ID], $event->[EV_VDR_ID], $myself) : undef,
                            editurl  => sprintf("%s?aktion=prog_detail_form&amp;epg_id=%s&amp;vdr_id=%s&amp;referer=%s", $MyURL, $event->[EV_EVENT_ID], $event->[EV_VDR_ID], $myself),
                            find_title => uri_escape("/^" . my_quotemeta($event->[EV_TITLE] . "~" . ($event->[EV_SUBTITLE] ? $event->[EV_SUBTITLE] : "") . "~") . "/"),
                            srch1_url    => $imdb_url,
                            srch1_title  => $imdb_url ? gettext($CONFIG{SRCH1_TITLE}) : undef,
                            srch2_url    => $srch2_url,
                            srch2_title  => $srch2_url ? gettext($CONFIG{SRCH2_TITLE}) : undef,
                            newd     => 0,
                            anchor   => "id" . $event->[EV_EVENT_ID],
                            timerset => $timerset
                         }
                    );
                }
            }
            push(@show, { endd => 1 });
        } elsif ($CONFIG{CHANNELS_WITHOUT_EPG}) {
            push(@show,
                {  channel_name => $_->{name},
                   longdate  => '',
                   newd      => 1,
                   streamurl => $FEATURES{LIVESTREAM} ? sprintf("%s%s?aktion=live_stream&amp;channel=%s&amp;progname=%s", $MyStreamBase, $CONFIG{TV_EXT}, $vdr_id, uri_escape($_->{name})) : undef,
                   switchurl => "$MyURL?aktion=prog_switch&amp;channel=" . $vdr_id,
                   proglink  => "$MyURL?aktion=prog_list&amp;vdr_id=" . $vdr_id
                }
            );
            push(@show,
                {  title    => gettext("No EPG information available"),
                   newd     => 0,
                }
            );
            push(@show, { endd => 1 });
        }
    }    # end: for $vdr_id

    my @days;
    foreach (keys %hash_days) {
        push(@days,
             {  name => $hash_days{$_},
                id   => "$MyURL?aktion=prog_list2&amp;day=" . $_,
                sort => $_,
                sel  => $_ == $day ? "1" : undef
             }
        );
    }
    @days = sort({ $a->{sort} <=> $b->{sort} } @days);
    my $prev_day;
    my $prev_day_name;
    my $cur_day;
    my $next_day;
    my $next_day_name;
    foreach (@days) {
        if($_->{sort} == $day) {
            $cur_day = $_->{sort};
            next;
        } elsif($cur_day) {
            $next_day = $_->{sort};
            $next_day_name = $_->{name};
            last;
        }
        unless($cur_day) {
            $prev_day = $_->{sort};
            $prev_day_name = $_->{name};
        }
    }

    #
    my $vars = {
        title => $day == $current_day ? gettext("Playing Today") : ($day == $current_day + 1 ? gettext("Playing Tomorrow") : sprintf(gettext("Playing on the %s"), $hash_days{$day})),
        now            => my_strftime("%H:%M", $time),
        day            => $day,
        days           => \@days,
        url            => $MyURL,
        loop           => \@show,
        chanloop       => \@channel,
        progname       => GetChannelDescByNumber($vdr_id),
        switchurl      => "$MyURL?aktion=prog_switch&amp;channel=" . $vdr_id,
        stream_live_on => $FEATURES{LIVESTREAM} && $CONFIG{ST_FUNC} && $CONFIG{ST_LIVE_ON},
        prevdayurl     => $prev_day ? "$MyURL?aktion=prog_list2&amp;day=" . $prev_day . ($param_time ? "&amp;time=$param_time" : "") : undef,
        nextdayurl     => $next_day ? "$MyURL?aktion=prog_list2&amp;day=" . $next_day . ($param_time ? "&amp;time=$param_time" : "") : undef,
        prevdaytext    => $prev_day_name,
        nextdaytext    => $next_day_name,
        toolbarurl     => "$MyURL?aktion=toolbar",
        ch_groups      => getChannelGroups("$MyURL?aktion=prog_list2&amp;day=" . $cur_day . ($param_time ? "&amp;time=$param_time" : ""), $CONFIG{CHANNELS_WANTED_PRG2})
    };
    return showTemplate("prog_list2.html", $vars);
}

#############################################################################
# regular timers
#############################################################################
sub timer_list {
    return if (UptoDate() != 0);

    $CONFIG{TM_DESC} = ($q->param("desc") ? 1 : 0) if (defined($q->param("desc")));
    $CONFIG{TM_SORTBY} = $q->param("sortby") if (defined($q->param("sortby")));
    $CONFIG{TM_SORTBY} = "day" if (!$CONFIG{TM_SORTBY});

    #
    my @timer;
    my @timer2;
    my @days;
    my $myself = Encode_Referer($MyURL . "?" . $Query);

    my ($TagAnfang, $TagEnde);
    for my $timer (ParseTimer(0)) {

        # VDR >= 1.3.24 reports if it's recording, so don't overwrite it here
        if ($FEATURES{VDRVERSION} < 10324 && $timer->{recording} == 0 && $timer->{startsse} < time() && $timer->{stopsse} > time() && ($timer->{active} & 1)) {
            $timer->{recording} = 1;
        }
        $timer->{active} = 0 unless ($timer->{active} & 1);

        $timer->{delurl}    = $MyURL . "?aktion=timer_delete&amp;timer_id=" . $timer->{id},
        $timer->{modurl}    = $MyURL . "?aktion=timer_new_form&amp;timer_id=" . $timer->{id},
        $timer->{toggleurl} = sprintf("%s?aktion=timer_toggle&amp;active=%s&amp;id=%s", $MyURL, ($timer->{active} & 1) ? 0 : 1, $timer->{id}), #TODO: nur id?
        $timer->{dor}       = my_strftime("%a %d.%m", $timer->{startsse});    #TODO: localize date

        $timer->{title} = CGI::escapeHTML($timer->{title});
        $TagAnfang      = my_mktime(0, 0, my_strftime("%d", $timer->{start}), my_strftime("%m", $timer->{start}), my_strftime("%Y", $timer->{start}));
        $TagEnde        = my_mktime(0, 0, my_strftime("%d", $timer->{stop}),  my_strftime("%m", $timer->{stop}),  my_strftime("%Y", $timer->{stop}));

        $timer->{duration}  = ($timer->{stop} - $timer->{start}) / 60;
        $timer->{startlong} = ((my_mktime(my_strftime("%M", $timer->{start}), my_strftime("%H", $timer->{start}), my_strftime("%d", $timer->{start}), my_strftime("%m", $timer->{start}), my_strftime("%Y", $timer->{start}))) - $TagAnfang) / 60;
        $timer->{stoplong}  = ((my_mktime(my_strftime("%M", $timer->{stop}), my_strftime("%H", $timer->{stop}), my_strftime("%d", $timer->{stop}), my_strftime("%m", $timer->{stop}), my_strftime("%Y", $timer->{stop}))) - $TagEnde) / 60;
        $timer->{starttime} = my_strftime("%y%m%d", $timer->{startsse});
        $timer->{stoptime}  = my_strftime("%y%m%d", $timer->{stopsse});
        $timer->{sortfield} = $timer->{cdesc} . $timer->{startsse};
        $timer->{infurl}    = $timer->{event_id} ? sprintf("%s?aktion=prog_detail&amp;epg_id=%s&amp;vdr_id=%s&amp;referer=%s", $MyURL, $timer->{event_id}, $timer->{vdr_id}, $myself) : undef,

        $timer->{start}   = my_strftime("%H:%M", $timer->{start});
        $timer->{stop}      = my_strftime("%H:%M", $timer->{stop});
        $timer->{sortbyactive}  = 1 if ($CONFIG{TM_SORTBY} eq "active");
        $timer->{sortbychannel} = 1 if ($CONFIG{TM_SORTBY} eq "channel");
        $timer->{sortbyname}    = 1 if ($CONFIG{TM_SORTBY} eq "name");
        $timer->{sortbystart}   = 1 if ($CONFIG{TM_SORTBY} eq "start");
        $timer->{sortbystop}    = 1 if ($CONFIG{TM_SORTBY} eq "stop");
        $timer->{sortbyday}     = 1 if ($CONFIG{TM_SORTBY} eq "day");

        $timer->{transponder} = get_transponder_from_vdrid($timer->{vdr_id});
        $timer->{ca}          = get_ca_from_vdrid($timer->{vdr_id});
        push(@timer, $timer);
    }
    @timer = sort({ $a->{startsse} <=> $b->{startsse} } @timer);

    #
    if ($CONFIG{RECORDINGS}) {
        my ($ii, $jj, $timer, $last);
        for ($ii = 0 ; $ii < @timer ; $ii++) {
            if ($timer[$ii]->{first} == -1 || $timer[$ii]->{first} == 1) {
                $last = $ii;
            }

            # Liste der benutzten Transponder
            my @Transponder = $timer[$ii]->{transponder};
            $timer[$ii]->{collision} = 0;

            for ($jj = 0 ; $jj < $ii ; $jj++) {
                if (   $timer[$ii]->{startsse} >= $timer[$jj]->{startsse}
                    && $timer[$ii]->{startsse} < $timer[$jj]->{stopsse})
                {
                    if ($timer[$ii]->{active} && $timer[$jj]->{active}) {

                        # Timer kollidieren zeitlich. Pruefen, ob die Timer evtl. auf
                        # gleichem Transponder oder CAM liegen und daher ohne Probleme
                        # aufgenommen werden koennen
                        Log(LOG_DEBUG, sprintf("[TIMER] Collision: %s (%s, %s) -- %s (%s, %s)\n", substr($timer[$ii]->{title}, 0, 15), $timer[$ii]->{vdr_id}, $timer[$ii]->{transponder}, $timer[$ii]->{ca}, substr($timer[$jj]->{title}, 0, 15), $timer[$jj]->{vdr_id}, $timer[$jj]->{transponder}, $timer[$jj]->{ca}));

                        if (   $timer[$ii]->{vdr_id} != $timer[$jj]->{vdr_id}
                            && $timer[$ii]->{ca} == $timer[$jj]->{ca}
                            && $timer[$ii]->{ca} >= 100)
                        {

                            # Beide Timer laufen auf dem gleichen CAM auf verschiedenen
                            # Kanaelen, davon kann nur einer aufgenommen werden
                            Log(LOG_DEBUG, "[TIMER] Both channels use same CAM");
                            #($timer[$ii]->{collision}) = $CONFIG{RECORDINGS}; #OLDIMPL
                            ($timer[$ii]->{collision})++; #NEWIMPL

                            # Nur Kosmetik: Transponderliste vervollstaendigen
                            push(@Transponder, $timer[$jj]->{transponder});
                        } else {

                            # "grep" prueft die Bedingung fuer jedes Element, daher den
                            # Transponder vorher zwischenspeichern -- ist effizienter
                            my $t = $timer[$jj]->{transponder};
                            if (scalar(grep($_ eq $t, @Transponder)) == 0) {
                                ($timer[$ii]->{collision})++;
                                push(@Transponder, $timer[$jj]->{transponder});
                            }
                        }
                    }
                }
            }
        }
        splice(@timer, $last + 1);
        for ($ii = 0 ; $ii < @timer ; $ii++) {
            $timer[$ii]->{critical} = $timer[$ii]->{collision} >= $CONFIG{RECORDINGS};
            if ($timer[$ii]->{critical} > 0) {
                for ($jj = $ii - 1 ; $jj >= 0 ; $jj--) {
                    if ($timer[$jj]->{stopsse} > $timer[$ii]->{startsse}) {
                        $timer[$jj]->{critical} = 1;
                    } else {
                        last;
                    }
                }
            }
            $timer[$ii]->{collision} = $timer[$ii]->{collision} >= ($CONFIG{RECORDINGS} - 1);
            if ($timer[$ii]->{collision} > 0) {
                for ($jj = $ii - 1 ; $jj >= 0 ; $jj--) {
                    if ($timer[$jj]->{stopsse} > $timer[$ii]->{startsse}) {
                        $timer[$jj]->{collision} = 1;
                    } else {
                        last;
                    }
                }
            }
            #$timer[$ii]->{collision} |= ($timer[$ii]->{ca} >= 100); #OLDIMPL
        }
    }

    #
    my ($ii, $jj, $kk, $current, $title);

    for ($ii = 0 ; $ii < @timer ; $ii++) {
        if ($ii == 0) {
            if (!defined($q->param("timer"))) {
                $current = my_strftime("%y%m%d", $timer[$ii]->{startsse});
                my $current_day = my_strftime("%y%m%d", time());
                $current = $current_day if ($current < $current_day);
                $title = my_strftime("%A, %x", $timer[$ii]->{startsse});
            } else {
                $current = $q->param("timer");
                $kk      = my_mktime(0, 0, substr($current, 4, 2), substr($current, 2, 2) - 1, "20" . substr($current, 0, 2));
                $title   = my_strftime("%A, %x", $kk);
            }
        }

        $jj = 0;
        for ($kk = 0 ; $kk < @days ; $kk++) {
            if ($days[$kk]->{day} == my_strftime("%d.%m", $timer[$ii]->{startsse})) {
                $jj = 1;
                last;
            }
        }
        if ($jj == 0) {
            push(@days,
                 {  day       => my_strftime("%d.%m",  $timer[$ii]->{startsse}),
                    sortfield => my_strftime("%y%m%d", $timer[$ii]->{startsse}),
                    current => ($current == my_strftime("%y%m%d", $timer[$ii]->{startsse})) ? 1 : 0,
                 }
            );
        }

        $jj = 0;
        for ($kk = 0 ; $kk < @days ; $kk++) {
            if ($days[$kk]->{day} == my_strftime("%d.%m", $timer[$ii]->{stopsse})) {
                $jj = 1;
                last;
            }
        }
        if ($jj == 0) {
            push(@days,
                 {  day       => my_strftime("%d.%m",  $timer[$ii]->{stopsse}),
                    sortfield => my_strftime("%y%m%d", $timer[$ii]->{stopsse}),
                    current => ($current == my_strftime("%y%m%d", $timer[$ii]->{stopsse})) ? 1 : 0,
                 }
            );
        }
    }

    @days = sort({ $a->{sortfield} <=> $b->{sortfield} } @days);
    my $prev_day;
    my $prev_day_name;
    my $next_day;
    my $next_day_name;
    my $cur_day;
    foreach (@days) {
        if ($_->{current}) {
            $cur_day = $_->{sortfield};
            next;
        }
        if ($cur_day) {
            $next_day = $_->{sortfield};
            $next_day_name = $_->{day};
            last;
        } else {
            $prev_day = $_->{sortfield};
            $prev_day_name = $_->{day};
        }
    }

    #
    if ($CONFIG{TM_SORTBY} eq "active") {
        if ($CONFIG{TM_DESC}) {
            @timer = sort({ $b->{active} <=> $a->{active} } @timer);
        } else {
            @timer = sort({ $a->{active} <=> $b->{active} } @timer);
        }
    } elsif ($CONFIG{TM_SORTBY} eq "channel") {
        if ($CONFIG{TM_DESC}) {
            @timer = sort({ ciCmp($b->{cdesc}, $a->{cdesc}) } @timer);
        } else {
            @timer = sort({ ciCmp($a->{cdesc}, $b->{cdesc}) } @timer);
        }
    } elsif ($CONFIG{TM_SORTBY} eq "name") {
        if ($CONFIG{TM_DESC}) {
            @timer = sort({ ciCmp($b->{title}, $a->{title}) } @timer);
        } else {
            @timer = sort({ ciCmp($a->{title}, $b->{title}) } @timer);
        }
    } elsif ($CONFIG{TM_SORTBY} eq "start") {
        if ($CONFIG{TM_DESC}) {
            @timer = sort({ $b->{start} <=> $a->{start} } @timer);
        } else {
            @timer = sort({ $a->{start} <=> $b->{start} } @timer);
        }
    } elsif ($CONFIG{TM_SORTBY} eq "stop") {
        if ($CONFIG{TM_DESC}) {
            @timer = sort({ $b->{stop} <=> $a->{stop} } @timer);
        } else {
            @timer = sort({ $a->{stop} <=> $b->{stop} } @timer);
        }
    } elsif ($CONFIG{TM_SORTBY} eq "day") {
        if ($CONFIG{TM_DESC}) {
            @timer = sort({ $b->{startsse} <=> $a->{startsse} } @timer);
        } else {
            @timer = sort({ $a->{startsse} <=> $b->{startsse} } @timer);
        }
    }
    my $toggle_desc = ($CONFIG{TM_DESC} ? 0 : 1);
    @timer2 = @timer;
    @timer2 = sort({ ciCmp($a->{sortfield}, $b->{sortfield}) } @timer2);

    my $vars = { sortbydayurl     => "$MyURL?aktion=timer_list&amp;sortby=day&amp;desc=" .     (($CONFIG{TM_SORTBY} eq "day")     ? $toggle_desc : $CONFIG{TM_DESC}),
                 sortbychannelurl => "$MyURL?aktion=timer_list&amp;sortby=channel&amp;desc=" . (($CONFIG{TM_SORTBY} eq "channel") ? $toggle_desc : $CONFIG{TM_DESC}),
                 sortbynameurl    => "$MyURL?aktion=timer_list&amp;sortby=name&amp;desc=" .    (($CONFIG{TM_SORTBY} eq "name")    ? $toggle_desc : $CONFIG{TM_DESC}),
                 sortbyactiveurl  => "$MyURL?aktion=timer_list&amp;sortby=active&amp;desc=" .  (($CONFIG{TM_SORTBY} eq "active")  ? $toggle_desc : $CONFIG{TM_DESC}),
                 sortbystarturl   => "$MyURL?aktion=timer_list&amp;sortby=start&amp;desc=" .   (($CONFIG{TM_SORTBY} eq "start")   ? $toggle_desc : $CONFIG{TM_DESC}),
                 sortbystopurl    => "$MyURL?aktion=timer_list&amp;sortby=stop&amp;desc=" .    (($CONFIG{TM_SORTBY} eq "stop")    ? $toggle_desc : $CONFIG{TM_DESC}),
                 sortbyday     => ($CONFIG{TM_SORTBY} eq "day")     ? 1 : 0,
                 sortbychannel => ($CONFIG{TM_SORTBY} eq "channel") ? 1 : 0,
                 sortbyname    => ($CONFIG{TM_SORTBY} eq "name")    ? 1 : 0,
                 sortbyactive  => ($CONFIG{TM_SORTBY} eq "active")  ? 1 : 0,
                 sortbystart   => ($CONFIG{TM_SORTBY} eq "start")   ? 1 : 0,
                 sortbystop    => ($CONFIG{TM_SORTBY} eq "stop")    ? 1 : 0,
                 sortby        => $CONFIG{TM_SORTBY},
                 desc          => $CONFIG{TM_DESC} ? "desc" : "asc",
                 timer_loop    => \@timer,
                 timers        => \@timer2,
                 timers2       => \@timer2,
                 day_loop      => \@days,
                 url           => $MyURL,
                 help_url      => HelpURL("timer_list"),
                 current       => $current,
                 title         => $title,
                 activateurl   => sprintf("%s?aktion=timer_toggle&amp;active=1", $MyURL),
                 inactivateurl => sprintf("%s?aktion=timer_toggle&amp;active=0", $MyURL),
                 prevdayurl    => $prev_day ? sprintf("%s?aktion=timer_list&amp;active=0&amp;timer=%s", $MyURL, $prev_day) : undef,
                 nextdayurl    => $next_day ? sprintf("%s?aktion=timer_list&amp;active=0&amp;timer=%s", $MyURL, $next_day) : undef,
                 prevdaytext   => $prev_day_name,
                 nextdaytext   => $next_day_name,
                 my_truncate   => \&my_truncate
    };
    return showTemplate("timer_list.html", $vars);
}

sub timer_toggle {
    UptoDate();
    my $id     = $q->param("id");
    if ($id) {
        my $active = $q->param("active");
        SendCMD(sprintf("modt %s %s", $id, $active ? "on" : "off"));

        # XXX check return
    } else {
        my $active;
        $active = "on"  if ($q->param("timer_active"));
        $active = "off" if ($q->param("timer_inactive"));
        if ($active) {
            my @sorted;
            for ($q->param) {
                if (/xxxx_(.*)/) {
                    push(@sorted, $1);
                }
            }
            @sorted = sort({ $b <=> $a } @sorted);
            for my $t (@sorted) {
                SendCMD(sprintf("modt %s %s", $t, $active));

                # XXX check return
            }
            CloseSocket();
        }
    }
    return RedirectToReferer("$MyURL?aktion=timer_list");
}

sub timer_new_form {
    UptoDate();

    my $epg_id   = $q->param("epg_id");
    my $vdr_id   = $q->param("vdr_id");
    my $timer_id = $q->param("timer_id");

    if ($q->param("channel_id")) {
        $vdr_id = get_vdrid_from_channelid($q->param("channel_id"));
    }

    my $this_event;
    if ($epg_id) {    # new timer
        my $this = EPG_getEntry($vdr_id, $epg_id);
        $this_event->{active}   = 1;
        $this_event->{event_id} = $this->[EV_EVENT_ID];
        $this_event->{start}    = $this->[EV_START] - ($CONFIG{TM_MARGIN_BEGIN} * 60);
        $this_event->{stop}     = $this->[EV_STOP] + ($CONFIG{TM_MARGIN_END} * 60);
        #$this_event->{dor}      = $this->{dor};
        $this_event->{title}    = $this->[EV_TITLE];
        # Do NOT append EPG summary if VDR >= 10344 as this will be done by VDR itself
        $this_event->{summary} = $this->[EV_SUMMARY] if ($FEATURES{VDRVERSION} < 10344);
        $this_event->{vdr_id} = $this->[EV_VDR_ID];

        if ($FEATURES{EPGSEARCH}) {
            $this_event->{tool}      = $TOOL_EPGSEARCH;
            $this_event->{at_epg}    = 1;
            $this_event->{autotimer} = epgsearch_getDefTimerCheckMethode($q->param("channel_id") ? $q->param("channel_id") : get_channelid_from_vdrid($vdr_id));
        } elsif ($FEATURES{AUTOTIMER}) {
            $this_event->{tool}      = $TOOL_AUTOTIMER;
            $this_event->{at_epg}    = $this_event->{event_id} ? can_do_eventid_autotimer($this_event->{vdr_id}) : 0;
            $this_event->{autotimer} = $this_event->{at_epg} ? $AT_BY_EVENT_ID : $AT_BY_TIME;
        }

    } elsif ($timer_id) {    # edit existing timer
        $this_event = ParseTimer(0, $timer_id);
        if (($this_event->{tool} == $TOOL_EPGSEARCH) && $this_event->{pattern}) {
            $this_event->{hide_at_check} = 1;
        }
        $this_event->{at_epg}    = $this_event->{event_id} ? 1 : 0;
        $this_event->{autotimer} = 0 unless($this_event->{autotimer});
    } else {                 # none of the above
        $this_event->{start}  = time();
        $this_event->{stop}   = 0;
        $this_event->{active} = 1;
        $this_event->{vdr_id} = 1;
    }

    my @channels;
    for my $channel (@{$CHAN{$CHAN_FULL}->{channels}}) {
        ($channel->{vdr_id} == $this_event->{vdr_id}) ? ($channel->{current} = 1) : ($channel->{current} = 0);
        push(@channels, $channel);
    }

    # determine referer (redirect to where we come from)
    my $ref = getReferer();

    my $displaysummary = $this_event->{summary};
    $displaysummary =~ s/\|/\n/g if ($displaysummary);

    my $vars = { url      => $MyURL,
                 active   => $this_event->{active} & 1,
                 event_id => $this_event->{event_id},
                 starth   => my_strftime("%H", $this_event->{start}),
                 startm   => my_strftime("%M", $this_event->{start}),
                 bstart   => ($this_event->{tool} == $TOOL_EPGSEARCH ? $this_event->{bstart} / 60 :$this_event->{bstart}),
                 stoph    => $this_event->{stop} ? my_strftime("%H", $this_event->{stop}) : "00",
                 stopm    => $this_event->{stop} ? my_strftime("%M", $this_event->{stop}) : "00",
                 bstop    => ($this_event->{tool} == $TOOL_EPGSEARCH ? $this_event->{bstop} / 60 : $this_event->{bstop}),
                 vps      => $this_event->{active} & 4,
                 dor      => ($this_event->{dor} && (length($this_event->{dor}) == 7 || length($this_event->{dor}) == 10 || length($this_event->{dor}) == 18)) ? $this_event->{dor} : my_strftime("%d", $this_event->{start}),
                 prio => $this_event->{prio} ne "" ? $this_event->{prio} : $CONFIG{TM_PRIORITY},
                 lft  => $this_event->{lft}  ne "" ? $this_event->{lft}  : $CONFIG{TM_LIFETIME},
                 title     => $this_event->{title},
                 summary   => $displaysummary,
                 pattern   => $this_event->{pattern},
                 timer_id  => $timer_id ? $timer_id : 0,
                 channels  => \@channels,
                 newtimer  => $timer_id ? 0 : 1,
                 autotimer => $this_event->{autotimer},
                 at_epg    => $this_event->{at_epg},
                 hide_at_check => $this_event->{hide_at_check},
                 referer   => $ref ? Encode_Referer($ref) : undef,
                 tool      => $this_event->{tool},
                 help_url  => HelpURL("timer_new")
    };
    return showTemplate("timer_new.html", $vars);
}

sub timer_add {
    my $timer_id = $q->param("timer_id");

    my $data;

    if ($q->param("save")) {
        my $value = $q->param("starth");
        if ($value =~ /\d+/ && $value < 24 && $value >= 0) {
            $data->{start} = sprintf("%02d", $value);
        } else {
            print "Help!\n";
            $data->{start} = "00";
        }
        $value = $q->param("startm");
        if ($value =~ /\d+/ && $value < 60 && $value >= 0) {
            $data->{start} .= sprintf("%02d", $value);
        } else {
            print "Help!\n";
            $data->{start} .= "00";
        }

        $value = $q->param("stoph");
        if ($value =~ /\d+/ && $value < 24 && $value >= 0) {
            $data->{stop} = sprintf("%02d", $value);
        } else {
            print "Help!\n";
            $data->{stop} = "00";
        }
        $value = $q->param("stopm");
        if ($value =~ /\d+/ && $value < 60 && $value >= 0) {
            $data->{stop} .= sprintf("%02d", $value);
        } else {
            print "Help!\n";
            $data->{stop} .= "00";
        }

        $data->{active}    = $q->param("active");
        $data->{autotimer} = $q->param("autotimer");
        $data->{event_id}  = $q->param("event_id");

        $data->{prio}    = $1 if ($q->param("prio")    =~ /(\d+)/);
        $data->{lft}     = $1 if ($q->param("lft")     =~ /(\d+)/);
        $data->{dor}     = $1 if ($q->param("dor")     =~ /([0-9MTWTFSS@\-]+)/);
        $data->{channel} = $1 if ($q->param("channel") =~ /(\d+)/);

        $data->{active} |= 4 if ($q->param("vps") && $q->param("vps") == 1);

        if (length($q->param("title")) > 0) {
            $data->{title} = $q->param("title");
        } else {
            $data->{title} = GetChannelDescByNumber($data->{channel}) if ($data->{channel});
        }

        if (length($q->param("summary")) > 0) {
            $data->{summary} = $q->param("summary");

            #$data->{summary} =~ s/\://g;    # summary may have colons (man vdr.5)
            $data->{summary} =~ s/\r//g;
            $data->{summary} =~ s/\n/|/g;
        }

        my $dor = $data->{dor};
        if (length($data->{dor}) == 7 || length($data->{dor}) == 10 || length($data->{dor}) == 18) {

            # dummy
            $dor = 1;
        }
        $data->{startsse} = my_mktime(substr($data->{start}, 2, 2), substr($data->{start}, 0, 2), $dor, (my_strftime("%m") - 1), my_strftime("%Y"));

        $data->{stopsse} = my_mktime(substr($data->{stop}, 2, 2), substr($data->{stop}, 0, 2), $data->{stop} > $data->{start} ? $dor : $dor + 1, (my_strftime("%m") - 1), my_strftime("%Y"));

        $data->{event_id} = 0 unless (can_do_eventid_autotimer($data->{channel}));
        $data->{tool} = $q->param("tool");

        my $return = ProgTimer(
            $timer_id,
            $data->{active},
            $data->{event_id},
            $data->{channel},
            $data->{startsse},
            $data->{stopsse},
            $data->{prio} ne "" ? $data->{prio} : $CONFIG{TM_PRIORITY},
            $data->{lft} ne "" ? $data->{lft} : $CONFIG{TM_LIFETIME},
            $data->{title},
            append_timer_metadata(
                $data->{summary},
                $data->{event_id},
                $data->{autotimer},
                $CONFIG{TM_MARGIN_BEGIN},
                $CONFIG{TM_MARGIN_END},
                undef,
                $data->{tool}),
            ($dor == 1) ? $data->{dor} : undef);

    }

    my $ref = getReferer();
    if ($ref) {
        return (headerForward($ref));
    } else {
        return (headerForward("$MyURL?aktion=timer_list"));
    }
}

sub timer_delete {
    my $timer_id = $q->param('timer_id');
    if ($timer_id) {
        my ($result) = SendCMD("delt $timer_id");
        if ($result =~ /Timer "$timer_id" is recording/i) {
            SendCMD("modt $timer_id off");
            sleep(1);
            SendCMD("delt $timer_id");
        }
    } else {
        my @sorted;
        for ($q->param) {
            if (/xxxx_(.*)/) {
                push(@sorted, $1);
            }
        }
        @sorted = sort({ $b <=> $a } @sorted);
        for my $t (@sorted) {
            my ($result) = SendCMD("delt $t");
            if ($result =~ /Timer "$t" is recording/i) {
                SendCMD("modt $t off");
                sleep(1);
                SendCMD("delt $t");
            }
        }
        CloseSocket();
    }
    return RedirectToReferer("$MyURL?aktion=timer_list");
}

sub getRecordingsPlaylist {
    my @playlist = ();

    my $response = HTTP::Tiny->new()->get(streamdevURI()->as_string() . "/recordings.m3u");

    if ($response->{success}) {
        my $content_charset = "UTF-8";
        # Content-Type: audio/x-mpegurl; charset=UTF-8
        if ($response->{headers}->{'content-type'}
                && $response->{headers}->{'content-type'} =~ /[ ;]+charset=([^ ;]+)/) {
            $content_charset = $1;
        }
        Encode::from_to($response->{content}, $content_charset, $MY_ENCODING);
        my $extinf = 1;
        my $rec;
        foreach my $line (split(/[ \r]*\n/, $response->{content})) {
            if ($extinf && $line =~ /^#EXTINF:-1,(\d+)\s+(\d\d\.\d\d\.\d\d)\s+(\d\d:\d\d)\s+(.*)$/) {
                $extinf = 0;
                $rec = {id => $1, date => $2, time => $3, title => $4, url => undef};
            }
            if (!$extinf && $line =~ /^http/) {
                $extinf = 1;
                $rec->{url} = $line;
                push(@playlist, $rec);
                $rec = undef;
            }
        }
    }
    return @playlist;
}

sub rec_stream {
    my $id = $q->param('id');
    my ($i, $title, $newtitle);
    my $data;
    my ($date, $time);

    for (SendCMD("lstr")) {
        if ($FEATURES{VDRVERSION} < 10721) {
            ($i, $date, $time, $title) = split(/ +/, $_, 4);
        } else {
            ($i, $date, $time, undef, $title) = split(/ +/, $_, 5);
        }
        last if ($id == $i);
    }
    $time = substr($time, 0, 5);    # needed for wareagel-patch
    if ($id == $i) {
        my @urls = ();
        $title =~ s/[ ~]+$//;
        if ($CONFIG{ST_REC_STREAMDEV} && $FEATURES{STREAMDEV}) {
            foreach my $r (getRecordingsPlaylist()) {
                if ($date eq $r->{date} && $time eq $r->{time} && $title eq $r->{title}) {
                    push (@urls, $r->{url});
                }
            }
            if ($CONFIG{ST_DIRECT_LINKS_ON} && @urls) {
                return headerForward($urls[0]->{url});
            }
        } else {
            # VFAT off
            @urls = findVideoFiles($date, $time, encode_RecTitle($title, 0));
            # VFAT on
            @urls = findVideoFiles($date, $time, encode_RecTitle($title, 1)) unless (@urls);
        }
        if (@urls) {
            $data = "#EXTM3U\n";
            foreach my $url (@urls) {
                $data .= sprintf("#EXTINF:-1,%s %s  %s\n%s\n",
                                $date, $time, $title, $url);
            }
        }
    }
    return (header("200", $CONFIG{REC_MIMETYPE}, $data));
}


sub rec_stream_folder {

    # return prog_summary();

    my $parent = $q->param("parent");
    if (!$parent) {
        $parent = 0;
    } else {
        $parent = uri_escape($parent);
    }

    ParseRecordings($parent);
    my @recordings = @RECORDINGS;

    # sort by date
    @recordings = sort({ $b->{isfolder} <=> $a->{isfolder} ||
                         ciCmp($b->{isfolder} ? $a->{name} : "", $a->{isfolder} ? $b->{name} : "") ||
                         $a->{sse} <=> $b->{sse} } @recordings);

    my $folder_data;
    my @streamdev_recordings;

    if ($CONFIG{ST_REC_STREAMDEV} && $FEATURES{STREAMDEV}) {
        @streamdev_recordings = getRecordingsPlaylist();
    }

    for my $recording (@recordings) {

        if (!$recording->{isfolder}  &&
             $recording->{parent} eq $parent) {

            # inplace playlist
            my ($id) = $recording->{recording_id};
            my ($i, $title, $newtitle);
            my ($date, $time);

            $date = $recording->{date};
            $time = $recording->{time};
            $title = $recording->{name};

            my @urls = ();
            $title = CGI::unescape($parent) . "~" . $title if ($parent);
            $title =~ s/[ ~]+$//;
            if ($CONFIG{ST_REC_STREAMDEV} && $FEATURES{STREAMDEV}) {
                #$title = $parent_orig if ($parent_orig && !$title);
                foreach my $r (@streamdev_recordings) {
                    if ($date eq $r->{date} && $time eq $r->{time} && $title eq $r->{title}) {
                        push (@urls, $r->{url});
                    }
                }
            } else {
                # VFAT off
                @urls = findVideoFiles($date, $time, encode_RecTitle($title, 0));
                # VFAT on
                @urls = findVideoFiles($date, $time, encode_RecTitle($title, 1)) unless (@urls);
            }
            if (@urls) {
                $folder_data = "#EXTM3U\n" unless ($folder_data);
                foreach my $url (@urls) {
                    $folder_data .= sprintf("#EXTINF:-1,%s %s  %s\n%s\n",
                                    $date, $time, $title, $url);
                }
            }
        }
    }

    return (header("200", $CONFIG{TV_MIMETYPE}, $folder_data, sprintf("vdradmin.%s", $CONFIG{TV_EXT}) ));
}

sub encode_RecTitle {
    my ($title, $use_vfat) = @_;
    my ($c, $i, $newtitle);

    if ($use_vfat) {
        # VFAT on
        for ($i = 0 ; $i < length($title) ; $i++) {
            $c = substr($title, $i, 1);
            unless ($c =~ /[öäüßÖÄÜA-Za-z0123456789_!@\$%&()+,.\-;=~ ]/) {
                $newtitle .= sprintf("#%02X", ord($c));
            } else {
                $newtitle .= $c;
            }
        }
    } else {
        # VFAT off
        for ($i = 0 ; $i < length($title) ; $i++) {
            $c = substr($title, $i, 1);
            if ($c eq "/") {
                $newtitle .= "\x02";
            } elsif ($c eq "\\") {
                $newtitle .= "\x01";
            } else {
                $newtitle .= $c;
            }
        }
    }

    return $newtitle;
}

sub findVideoFiles {
    # VDR < v1.7.2:  YYYY-MM-DD-hh[.:]mm.pr.lt.rec (pr=priority, lt=lifetime)
    # VDR >= v1.7.2: YYYY-MM-DD-hh.mm.ch-ri.rec    (ch=channel, ri=resumeId)

    my ($date, $time, $title) = @_;  # DD.MM.YY and hh:mm

    my ($year, $month, $day, $hour, $minute);
    ($day, $month, $year) = ($1, $2, $3) if ($date =~ /(\d\d).(\d\d).(\d\d)/);
    ($hour, $minute) = ($1, $2) if ($time =~ /(\d\d):(\d\d)/);
    return () unless (defined($day) && defined($hour));

    $title =~ s/ /_/g;
    $title =~ s/~/\//g;
    $title = quotemeta $title;

    my $re_compiled = qr"$CONFIG{VIDEODIR}/$title\_*/(_/)?\d{2}$year-$month-$day\.$hour[.:]$minute\.\d+[-.]\d+\.rec/\d{3}(\.vdr|\d{2}\.ts)";

    sub find_files {
        my ($dir, $regex) = @_;
        my @arr = ();
        File::Find::find({ wanted => sub {push(@arr, $File::Find::name) if $File::Find::name =~ $regex}, follow => 1, no_chdir => 1}, $dir);
        return @arr;
    }

    my @ret = ();
    foreach my $path (sort(find_files($CONFIG{VIDEODIR}, $re_compiled))) {
        chomp;
        Log(LOG_DEBUG, "[REC] findVideoFiles: found ($path)\n");
        $path =~ s/$CONFIG{VIDEODIR}/$CONFIG{ST_VIDEODIR}/;
        $path =~ s/\n//g;
        $path = $CONFIG{ST_URL} . $path;
        $path =~ s/#/%23/g if ($path =~ /^http/);
        push(@ret, $path)
    }
    return @ret;
}

sub getReferer {
    my $epg_id = $q->param("epg_id");
    my $ref    = $q->param("referer");
    if ($ref) {
        $ref = Decode_Referer($ref);
        if ($ref =~ /#/) {
            return $ref;
        } else {
            return sprintf("%s%s", $ref, $epg_id ? "#id$epg_id" : "");
        }
    } else {
        return undef;
    }
}

#############################################################################
# live streaming
#############################################################################
sub streamdevURI {
    my $url;

    if ($CONFIG{ST_STREAMDEV_HOST}) {
        $url = URI->new("http://$CONFIG{ST_STREAMDEV_HOST}");
    } elsif ($CONFIG{VDR_HOST} =~ /^localhost(\.localdomain)?|127\.0\.0\.1$/i) {
        $url = URI->new($q->url(-base => 1));
        $url->scheme("http");
    } else {
        $url = URI->new("http://$CONFIG{VDR_HOST}");
    }
    if ($FEATURES{STREAMDEV}) {
        my ($port, $rest) = split(/\//, $CONFIG{ST_STREAMDEV_PORT}, 2);
        $url->port($port);
        $url->path($rest);
    } elsif ($FEATURES{XINELIB}) {
        $url->port($CONFIG{ST_XINELIB_PORT});
    }
    return $url;
}

sub live_stream {
    my $channel = $q->param("channel");
    my $progname = $q->param("progname");

    my $url = streamdevURI();
    if ($FEATURES{STREAMDEV}) {
        $url->path($url->path() . "/" . $channel);
    } elsif ($FEATURES{XINELIB}) {
        $url->port($CONFIG{ST_XINELIB_PORT});
        # No channel support in xineliboutput URLs, need to switch here
        SendCMD("chan $channel") if $channel;
    }

    if ($CONFIG{ST_DIRECT_LINKS_ON} && $FEATURES{STREAMDEV}) {
        return headerForward($url);
    } else {
        my $data = "";
        $data .= "#EXTINF:0,$progname\n" if ($progname);
        $data .= "$url\n";
        return (header("200", $CONFIG{TV_MIMETYPE}, $data));
    }
}

#############################################################################
# automatic timers
#############################################################################
sub at_timer_list {
    return if (UptoDate() != 0);

    $CONFIG{AT_DESC} = ($q->param("desc") ? 1 : 0) if (defined($q->param("desc")));
    $CONFIG{AT_SORTBY} = $q->param("sortby") if (defined($q->param("sortby")));
    $CONFIG{AT_SORTBY} = "pattern" if (!$CONFIG{AT_SORTBY});

    #
    my @at;
    my $id = 0;
    for (AT_Read()) {
        $id++;
        if ($_->{start}) {
            $_->{start} = substr($_->{start}, 0, 2) . ":" . substr($_->{start}, 2, 5);
        }
        if ($_->{stop}) {
            $_->{stop} = substr($_->{stop}, 0, 2) . ":" . substr($_->{stop}, 2, 5);
        }
        $_->{pattern_js} = $_->{pattern};
        $_->{pattern}    = CGI::escapeHTML($_->{pattern});
        $_->{pattern_js} =~ s/\'/\\\'/g;
        $_->{pattern_js} =~ s/\"/&quot;/g;
        $_->{modurl}        = $MyURL . "?aktion=at_timer_edit&amp;id=$id";
        $_->{delurl}        = $MyURL . "?aktion=at_timer_delete&amp;id=$id";
        $_->{prio}          = $_->{prio};
        $_->{lft}           = $_->{lft};
        $_->{id}            = $id;
        $_->{proglink}      = sprintf("%s?aktion=prog_list&amp;vdr_id=%s", $MyURL, $_->{channel});
        $_->{channel}       = GetChannelDescByNumber($_->{channel});
        $_->{sortbyactive}  = 1 if ($CONFIG{AT_SORTBY} eq "active");
        $_->{sortbychannel} = 1 if ($CONFIG{AT_SORTBY} eq "channel");
        $_->{sortbypattern} = 1 if ($CONFIG{AT_SORTBY} eq "pattern");
        $_->{sortbystart}   = 1 if ($CONFIG{AT_SORTBY} eq "start");
        $_->{sortbystop}    = 1 if ($CONFIG{AT_SORTBY} eq "stop");
        $_->{toggleurl}     = sprintf("%s?aktion=at_timer_toggle&amp;active=%s&amp;id=%s", $MyURL, ($_->{active} & 1) ? 0 : 1, $_->{id}), push(@at, $_);
    }
    my @timer = sort({ lc($a->{pattern}) cmp lc($b->{pattern}) } @at);

    #
    if ($CONFIG{AT_SORTBY} eq "active") {
        if ($CONFIG{AT_DESC}) {
            @timer = sort({ $b->{active} <=> $a->{active} } @timer);
        } else {
            @timer = sort({ $a->{active} <=> $b->{active} } @timer);
        }
    } elsif ($CONFIG{AT_SORTBY} eq "channel") {
        if ($CONFIG{AT_DESC}) {
            @timer = sort({ lc($b->{channel}) cmp lc($a->{channel}) } @timer);
        } else {
            @timer = sort({ lc($a->{channel}) cmp lc($b->{channel}) } @timer);
        }
    } elsif ($CONFIG{AT_SORTBY} eq "pattern") {
        if ($CONFIG{AT_DESC}) {
            @timer = sort({ lc($b->{pattern}) cmp lc($a->{pattern}) } @timer);
        } else {
            @timer = sort({ lc($a->{pattern}) cmp lc($b->{pattern}) } @timer);
        }
    } elsif ($CONFIG{AT_SORTBY} eq "start") {
        if ($CONFIG{AT_DESC}) {
            @timer = sort({ $b->{start} <=> $a->{start} } @timer);
        } else {
            @timer = sort({ $a->{start} <=> $b->{start} } @timer);
        }
    } elsif ($CONFIG{AT_SORTBY} eq "stop") {
        if ($CONFIG{AT_DESC}) {
            @timer = sort({ $b->{stop} <=> $a->{stop} } @timer);
        } else {
            @timer = sort({ $a->{stop} <=> $b->{stop} } @timer);
        }
    }
    my $toggle_desc = ($CONFIG{AT_DESC} ? 0 : 1);

    my $vars = { sortbychannelurl => "$MyURL?aktion=at_timer_list&amp;sortby=channel&amp;desc=" . (($CONFIG{AT_SORTBY} eq "channel") ? $toggle_desc : $CONFIG{AT_DESC}),
                 sortbypatternurl => "$MyURL?aktion=at_timer_list&amp;sortby=pattern&amp;desc=" . (($CONFIG{AT_SORTBY} eq "pattern") ? $toggle_desc : $CONFIG{AT_DESC}),
                 sortbyactiveurl  => "$MyURL?aktion=at_timer_list&amp;sortby=active&amp;desc=" . (($CONFIG{AT_SORTBY} eq "active") ? $toggle_desc : $CONFIG{AT_DESC}),
                 sortbystarturl   => "$MyURL?aktion=at_timer_list&amp;sortby=start&amp;desc=" . (($CONFIG{AT_SORTBY} eq "start") ? $toggle_desc : $CONFIG{AT_DESC}),
                 sortbystopurl    => "$MyURL?aktion=at_timer_list&amp;sortby=stop&amp;desc=" . (($CONFIG{AT_SORTBY} eq "stop") ? $toggle_desc : $CONFIG{AT_DESC}),
                 sortbychannel => ($CONFIG{AT_SORTBY} eq "channel") ? 1 : 0,
                 sortbypattern => ($CONFIG{AT_SORTBY} eq "pattern") ? 1 : 0,
                 sortbyactive  => ($CONFIG{AT_SORTBY} eq "active")  ? 1 : 0,
                 sortbystart   => ($CONFIG{AT_SORTBY} eq "start")   ? 1 : 0,
                 sortbystop    => ($CONFIG{AT_SORTBY} eq "stop")    ? 1 : 0,
                 desc          => $CONFIG{AT_DESC} ? "desc" : "asc",
                 at_timer_loop => \@timer,
                 at_timer_loop2 => \@timer,
                 url            => $MyURL,
                 help_url       => HelpURL("at_timer_list")
    };
    return showTemplate("at_timer_list.html", $vars);
}

sub at_timer_toggle {
    UptoDate();
    my $active = $q->param("active");
    my $id     = $q->param("id");

    my (@at, $z);

    for (AT_Read()) {
        $z++;
        if ($z == $id) {
            $_->{active} = $active;
        }
        push(@at, $_);
    }
    AT_Write(@at);

    return RedirectToReferer("$MyURL?aktion=at_timer_list");
}

sub at_timer_edit {
    my $id = $q->param("id");

    my @at = AT_Read();

    #
    my @chans;
    for my $chan (@{$CHAN{$CONFIG{CHANNELS_WANTED_AUTOTIMER}}->{channels}}) {
        if ($chan->{vdr_id}) {
            $chan->{cur} = ($chan->{vdr_id} == $at[ $id - 1 ]->{channel}) ? 1 : 0;
        }
        push(@chans, $chan);
    }

    my $pattern = $at[ $id - 1 ]->{pattern};
    $pattern =~ s/"/\&quot;/g;
    my $vars = { channels => \@chans,
                 id       => $id,
                 url      => $MyURL,
                 prio     => $at[ $id - 1 ]->{prio},
                 lft      => $at[ $id - 1 ]->{lft},
                 active   => $at[ $id - 1 ]->{active},
                 done     => $at[ $id - 1 ]->{done},
                 episode  => $at[ $id - 1 ]->{episode},
                 pattern  => $pattern,
                 starth   => (length($at[ $id - 1 ]->{start}) >= 4) ? substr($at[ $id - 1 ]->{start}, 0, 2) : undef,
                 startm   => (length($at[ $id - 1 ]->{start}) >= 4) ? substr($at[ $id - 1 ]->{start}, 2, 5) : undef,
                 stoph    => (length($at[ $id - 1 ]->{stop}) >= 4) ? substr($at[ $id - 1 ]->{stop}, 0, 2) : undef,
                 stopm    => (length($at[ $id - 1 ]->{stop}) >= 4) ? substr($at[ $id - 1 ]->{stop}, 2, 5) : undef,
                 buffers  => $at[ $id - 1 ]->{buffers},
                 bstart   => $at[ $id - 1 ]->{buffers} ? $at[ $id - 1 ]->{bstart} : "",
                 bstop    => $at[ $id - 1 ]->{buffers} ? $at[ $id - 1 ]->{bstop} : "",
                 title       => ($at[ $id - 1 ]->{section} & 1) ? 1 : 0,
                 subtitle    => ($at[ $id - 1 ]->{section} & 2) ? 1 : 0,
                 description => ($at[ $id - 1 ]->{section} & 4) ? 1 : 0,
                 directory   => $at[ $id - 1 ]->{directory},
                 newtimer    => 0,
                 (map { $_ => $at[ $id - 1 ]->{weekdays}->{$_} } qw (wday_mon wday_tue wday_wed wday_thu wday_fri wday_sat wday_sun)),
                 help_url => HelpURL("at_timer_new")
    };
    return showTemplate("at_timer_new.html", $vars);
}

sub at_timer_new {
    my $vars = { url      => $MyURL,
                 active   => $q->param("active"),
                 done     => $q->param("done"),
                 title    => 1,
                 wday_mon => 1,
                 wday_tue => 1,
                 wday_wed => 1,
                 wday_thu => 1,
                 wday_fri => 1,
                 wday_sat => 1,
                 wday_sun => 1,
                 channels => \@{$CHAN{$CONFIG{CHANNELS_WANTED_AUTOTIMER}}->{channels}},
                 buffers  => 0,
                 bstart   => "",
                 bstop    => "",
                 prio     => "",
                 lft      => "",
                 newtimer => 1,
                 help_url => HelpURL("at_timer_new")
    };
    return showTemplate("at_timer_new.html", $vars);
}

sub at_timer_save {
    my $id = $q->param("id");

    my $start;
    my $stop;
    if (length($q->param("starth")) > 0 || length($q->param("startm")) > 0) {
        $start = sprintf("%02s%02s", $q->param("starth"), $q->param("startm"));
    }
    if (length($q->param("stoph")) > 0 || length($q->param("stopm")) > 0) {
        $stop = sprintf("%02s%02s", $q->param("stoph"), $q->param("stopm"));
    }

    if ($q->param("save")) {
        if (!$id) {
            my @at      = AT_Read();
            my $section = 0;
            ($section += 1) if ($q->param("title"));
            ($section += 2) if ($q->param("subtitle"));
            ($section += 4) if ($q->param("description"));
            push(@at,
                 {  episode => $q->param("episode") ? $q->param("episode") : 0,
                    active  => $q->param("active"),
                    done    => $q->param("done"),
                    pattern => $q->param("pattern"),
                    section => $section,
                    start   => $start,
                    stop    => $stop,
                    buffers => $q->param("buffers"),
                    bstart  => $q->param("buffers") ? $q->param("bstart") : "",
                    bstop   => $q->param("buffers") ? $q->param("bstop") : "",
                    prio    => $q->param("prio"),
                    lft     => $q->param("lft"),
                    channel => $q->param("channel"),
                    directory => $q->param("directory"),
                    weekdays  => { map { $_ => $q->param($_) ? $q->param($_) : 0 } (qw (wday_mon wday_tue wday_wed wday_thu wday_fri wday_sat wday_sun)) }
                 }
            );
            AT_Write(@at);
        } else {
            my $z = 0;
            my @at;
            for (AT_Read()) {
                $z++;
                if ($z != $id) {
                    push(@at, $_);
                } else {
                    my $section = 0;
                    ($section += 1) if ($q->param("title"));
                    ($section += 2) if ($q->param("subtitle"));
                    ($section += 4) if ($q->param("description"));
                    push(@at,
                         {  episode => $q->param("episode") ? $q->param("episode") : 0,
                            active  => $q->param("active"),
                            done    => $q->param("done"),
                            pattern => $q->param("pattern"),
                            section => $section,
                            start   => $start,
                            stop    => $stop,
                            buffers => $q->param("buffers"),
                            bstart  => $q->param("buffers") ? $q->param("bstart") : "",
                            bstop   => $q->param("buffers") ? $q->param("bstop") : "",
                            prio    => $q->param("prio"),
                            lft     => $q->param("lft"),
                            channel => $q->param("channel"),
                            directory => $q->param("directory"),
                            weekdays  => { map { $_ => $q->param($_) ? $q->param($_) : 0 } (qw (wday_mon wday_tue wday_wed wday_thu wday_fri wday_sat wday_sun)) }
                         }
                    );
                }
            }
            AT_Write(@at);
        }

        $CONFIG{CACHE_LASTUPDATE} = 0;
        UptoDate();
    }
    headerForward("$MyURL?aktion=at_timer_list");
}

sub at_timer_delete {
    my $id = $q->param("id");
    my $z  = 0;

    my @at = AT_Read();
    my @new;
    if ($id) {
        for (@at) {
            $z++;
            push(@new, $_) if ($id != $z);
        }
        AT_Write(@new);
    } else {
        my @sorted;
        for ($q->param) {
            if (/xxxx_(.*)/) {
                push(@sorted, $1);
            }
        }
        @sorted = sort({ $b <=> $a } @sorted);
        my $z = 0;
        for my $at (@at) {
            $z++;
            my $push = 1;
            for my $sorted (@sorted) {
                ($push = 0) if ($z == $sorted);
            }
            push(@new, $at) if ($push);
        }
        AT_Write(@new);
    }
    headerForward("$MyURL?aktion=at_timer_list");
}

sub at_timer_test {
    my $id = $q->param("id");
    my @chans;
    for my $chan (@{$CHAN{$CONFIG{CHANNELS_WANTED_AUTOTIMER}}->{channels}}) {
        if ($chan->{vdr_id}) {
            $chan->{cur} = ($chan->{vdr_id} == $q->param("channel")) ? 1 : 0;
        }
        push(@chans, $chan);
    }

    my $section = 0;
    ($section += 1) if ($q->param("title"));
    ($section += 2) if ($q->param("subtitle"));
    ($section += 4) if ($q->param("description"));

    my @at = { episode => $q->param("episode") ? $q->param("episode") : 0,
               active  => $q->param("active"),
               pattern => $q->param("pattern"),
               channel => $q->param("channel"),
               section => $section,
               start => length($q->param("starth")) > 0 || length($q->param("startm")) > 0 ? sprintf("%02s%02s", $q->param("starth"), $q->param("startm")) : undef,
               stop  => length($q->param("stoph")) > 0  || length($q->param("stopm")) > 0  ? sprintf("%02s%02s", $q->param("stoph"),  $q->param("stopm"))  : undef,
               directory => $q->param("directory"),
               weekdays  => { map { $_ => $q->param($_) ? $q->param($_) : 0 } (qw (wday_mon wday_tue wday_wed wday_thu wday_fri wday_sat wday_sun)) }
    };

    my @at_matches = AutoTimer(1, @at);
    my $pattern    = $q->param("pattern");
    $pattern =~ s/"/\&quot;/g;
    my $directory = $q->param("directory");
    $directory =~ s/"/\&quot;/g;
    my $vars = {
        id       => $id,
        url      => $MyURL,
        channels => \@chans,

        #TODO    $q->Vars,
        active      => $q->param("active"),
        pattern     => $pattern,
        title       => $q->param("title") ? $q->param("title") : 0,
        subtitle    => $q->param("subtitle") ? $q->param("subtitle") : 0,
        description => $q->param("description") ? $q->param("description") : 0,
        wday_mon    => $q->param("wday_mon") ? $q->param("wday_mon") : 0,
        wday_tue    => $q->param("wday_tue") ? $q->param("wday_tue") : 0,
        wday_wed    => $q->param("wday_wed") ? $q->param("wday_wed") : 0,
        wday_thu    => $q->param("wday_thu") ? $q->param("wday_thu") : 0,
        wday_fri    => $q->param("wday_fri") ? $q->param("wday_fri") : 0,
        wday_sat    => $q->param("wday_sat") ? $q->param("wday_sat") : 0,
        wday_sun    => $q->param("wday_sun") ? $q->param("wday_sun") : 0,
        channel     => $q->param("channel"),
        starth      => $q->param("starth"),
        startm      => $q->param("startm"),
        stoph       => $q->param("stoph"),
        stopm       => $q->param("stopm"),
        prio        => $q->param("prio"),
        lft         => $q->param("lft"),
        episode     => $q->param("episode") ? $q->param("episode") : 0,
        done        => $q->param("done"),
        directory   => $directory,
        at_test     => 1,
        matches     => \@at_matches
    };
    return showTemplate("at_timer_new.html", $vars);
}

sub getSplittedTime {
    my $time   = shift;
    if ($time) {
        my ($hour, $minute);
        if ($time =~ /(\d{1,2})(\D?)(\d{1,2})/) {
            if (length($1) == 1 && length($3) == 1 && !$2) {
                $hour = $1 . $3;
            } else {
                ($hour, $minute) = ($1, $3);
            }
        } elsif ($time =~ /\d/) {
            $hour = $time;
        }
        return ($hour, $minute);
    } else {
        return (my_strftime("%H"), my_strftime("%M"));
    }
}

sub getStartTime {
    my $time   = shift;
    my $day    = shift;
    my $border = shift;
    if ($time) {
        my ($hour, $minute) = getSplittedTime($time);
        $border = time() if (!$border);
        $time = timelocal(0, 0, 0, my_strftime("%d", $border), (my_strftime("%m", $border) - 1), my_strftime("%Y", $border)) + $hour * 3600 + $minute * 60;
        $time += 86400 if ($time < $border);
        return $time;
    } else {
        return time();
    }
}

#############################################################################
# timeline
#############################################################################
sub prog_timeline {
    return if (UptoDate() != 0);

    my $myself = Encode_Referer($MyURL . "?" . $Query);
    $CONFIG{CHANNELS_WANTED_TIMELINE} = $q->param("wanted_channels") if (defined $q->param("wanted_channels"));

    # zeitpunkt bestimmen
    my $border;
    if ($q->param("time")) {
        if ($q->param("frame")) {
            $border = $q->param("frame");
        } else {
            $border = time + 1799 - $CONFIG{ZEITRAHMEN} * 3600;
            $border -= $border % 1800;
        }
    }
    my $event_time = getStartTime(scalar $q->param("time"), undef, $border);
    my $event_time_to;

    # calculate start time of the 30 min interval to avoid gaps at the beginning
    my $start_time = $event_time - $event_time % 1800;

    $event_time_to = $start_time + ($CONFIG{ZEITRAHMEN} * 3600);

    # Timer parsen, und erstmal alle rausschmeissen die nicht in der Zeitzone liegen
    my $TIM;
    for my $timer (ParseTimer(0)) {
        next if ($timer->{stopsse} <= $start_time or $timer->{startsse} >= $event_time_to);
        my $title = (split(/\~/, $timer->{title}))[-1];
        $TIM->{$title} = $timer;
    }

    my (@show, @temp);
    my $shows;

    foreach (@{$CHAN{$CONFIG{CHANNELS_WANTED_TIMELINE}}->{channels}}) {
        if (ChannelHasEPG($_->{vdr_id})) {
            foreach my $event (sort { $a->[EV_START] <=> $b->[EV_START] } @{ $EPG{$_->{vdr_id}} }) {    # Events durchgehen
                next if ($event->[EV_STOP] <= $start_time or $event->[EV_START] >= $event_time_to);

                my $progname = $event->[EV_CHANNEL_NAME];
                $progname =~ s/\"/\&quot;/g;
                push(@show,
                     {  start    => $event->[EV_START],
                        stop     => $event->[EV_STOP],
                        title    => $event->[EV_TITLE],
#                        subtitle => (($event->[EV_SUBTITLE] && length($event->[EV_SUBTITLE]) > 30) ? substr($event->[EV_SUBTITLE], 0, 30) . "..." : $event->[EV_SUBTITLE]),
                        progname => $progname,
                        summary  => $event->[EV_SUMMARY],
                        vdr_id   => $event->[EV_VDR_ID],
                        proglink  => sprintf("%s?aktion=prog_list&amp;vdr_id=%s",    $MyURL, $event->[EV_VDR_ID]),
#                        switchurl => sprintf("%s?aktion=prog_switch&amp;channel=%s", $MyURL, $event->[EV_VDR_ID]),
#                        infurl => ($event->[EV_SUMMARY] ? sprintf("%s?aktion=prog_detail&amp;epg_id=%s&amp;vdr_id=%s&amp;referer=%s", $MyURL, $event->[EV_EVENT_ID], $event->[EV_VDR_ID], $myself) : undef),
#                        recurl => sprintf("%s?aktion=timer_new_form&amp;epg_id=%s&amp;vdr_id=%s&amp;referer=%s", $MyURL, $event->[EV_EVENT_ID], $event->[EV_VDR_ID], $myself),
                        anchor => $event->[EV_EVENT_ID],
                        timer => (defined $TIM->{ $event->[EV_TITLE] } && $TIM->{ $event->[EV_TITLE] }->{vdr_id} == $event->[EV_VDR_ID] && $TIM->{ $event->[EV_TITLE] }->{active} ? 1 : 0), #TODO
                     }
                );
            }
        } elsif ($CONFIG{CHANNELS_WITHOUT_EPG}) {
            my $progname = $_->{name};
            $progname =~ s/\"/\&quot;/g;
            push(@show,
                {   progname => $progname,
                    title    => gettext("No EPG information available"),
                    start    => 0,
                    stop     => 0,
                    vdr_id   => 0,
                    timer     => 0
                }
            );
        }

        # needed for vdr 1.0.x, dunno why
#        @show = sort({ $a->{vdr_id} <=> $b->{vdr_id} } @show);
        push(@{ $shows->{ $_->{vdr_id} } }, @show) if @show;
        undef @show;
    }

    my $vars = { shows   => $shows,
                 shows2  => $shows,
                 now_sec => $event_time,
                 now     => strftime("%H:%M", localtime($event_time)),
                 datum   => my_strftime("%A, %x", time),
                 nowurl  => $MyURL . "?aktion=prog_timeline",
                 url     => $MyURL,
                 ch_groups => getChannelGroups($MyURL . "?aktion=prog_timeline&amp;time=" . $q->param("time"), $CONFIG{CHANNELS_WANTED_TIMELINE})
    };
    return showTemplate("prog_timeline.html", $vars);
}

#############################################################################
# summary
#############################################################################
sub prog_summary {
    return if (UptoDate() != 0);
    my $time = $q->param("time");
    my $search = $q->param("search");
    my $next = $q->param("next");
    my $view = $CONFIG{PS_VIEW};
    $view = $q->param("view") if($q->param("view"));
    $CONFIG{PS_VIEW} = $view;
    $CONFIG{CHANNELS_WANTED_SUMMARY} = $q->param("wanted_channels") if (defined $q->param("wanted_channels"));

    my @timers = ParseTimer(0);

    # zeitpunkt bestimmen
    my $event_time = getStartTime($time);

    my $pattern;
    my $is_regex = 0;
    my $ignore_case = 0;
    my @search_words = ();
    if ($search) {
        $pattern = $search;
        if ($pattern =~ /^\/(.*)\/(i?)$/) {
            $pattern = $1;
            my $mode = $2;
            $is_regex = 1;
            if ($mode eq "i") {
                $pattern = Encode::decode($MY_ENCODING, $pattern) if $can_use_encode;
                $pattern = qr/$pattern/i;
                Log(LOG_DEBUG, "[SEARCH] REGEX:" . Encode::encode($MY_ENCODING, $pattern) . "\n");
                $ignore_case = 1;
            } else {
                $pattern = qr/$pattern/;
                Log(LOG_DEBUG, "[SEARCH] REGEX:" . $pattern . "\n");
            }
        } else {
            $pattern = Encode::decode($MY_ENCODING, $pattern) if $can_use_encode;
            for my $word (split(/ +/, $pattern)) {
                if ($word) {
                    if ($can_use_encode) {
                        # case-insensitive search for 'abc' from fastest to slowest:
                        # (?>a|A)(?>b|B)(?>c|C) on byte strings
                        # [aA][bB][cC] on unicode strings
                        # substr() + uc()/lc() on unicode strings
                        # /abc/i on unicode strings
                        my @pat = ();
                        my $prefix;
                        for my $ch (split(//, quotemeta($word))) {
                            if (uc($ch) ne lc($ch)) {
                                if (!@pat && !defined($prefix)) {
                                    # first character
                                    $prefix = $ch;
                                } else {
                                    push(@pat, "(?>");
                                    push(@pat, lc($ch));
                                    push(@pat, "|");
                                    push(@pat, uc($ch));
                                    push(@pat, ")");
                                }
                            } else {
                                push(@pat, $ch);
                            }
                        }
                        if (defined($prefix)) {
                            my $word_pat1 = Encode::encode($MY_ENCODING, join("", uc($prefix), @pat));
                            my $word_pat2 = Encode::encode($MY_ENCODING, join("", lc($prefix), @pat));
                            push(@search_words, [qr/$word_pat1/, qr/$word_pat2/]);
                        } else {
                            my $word_pat = Encode::encode($MY_ENCODING, join("", @pat));
                            push(@search_words, [qr/$word_pat/, undef]);
                        }

                    } else {
                        my $word_pat = quotemeta($word);
                        push(@search_words, [qr/$word_pat/, undef]);
                    }
                }
            }
            Log(LOG_DEBUG, "[SEARCH] PATTERNS:" . join("&&", map {$_->[0] . "||" . ($_->[1] || "NULL")} @search_words) . "\n");
        }
    }

    my $now = time();
    my (@show, @temp);
    for my $channel ($search ? @{$CHAN{$CHAN_FULL}->{channels}} : @{$CHAN{$CONFIG{CHANNELS_WANTED_SUMMARY}}->{channels}}) {
        if (ChannelHasEPG($channel->{vdr_id})) {
            for my $event (@{ $EPG{$channel->{vdr_id}} }) {
                next if ($event->[EV_STOP] <= $now);
                if (!$search) {
                    next if(!$next && $event_time >= $event->[EV_STOP]);
                    next if($next && $event_time >= $event->[EV_START]);
                } else {
                    my ($found);
                    if ($is_regex) {
                        # We have a RegExp
                        next if (!defined($pattern));
                        my $SearchStr = join("~", $event->[EV_TITLE], ($event->[EV_SUBTITLE] || ""), ($event->[EV_SUMMARY] || ""));
                        if ($ignore_case) {
                            $SearchStr = Encode::decode($MY_ENCODING, $SearchStr) if $can_use_encode;
                        }
                        $found = ($SearchStr =~ /$pattern/);

                    } else {
                        $found = 1;
                        my $SearchStr = join(" ", $event->[EV_TITLE], ($event->[EV_SUBTITLE] || ""), ($event->[EV_SUMMARY] || ""));
                        for my $pat (@search_words) {
                            if ($SearchStr !~ /$pat->[0]/ && (!defined($pat->[1]) || $SearchStr !~ /$pat->[1]/)) {
                                $found = 0;
                                last;
                            }
                        }
                    }
                    next unless ($found);
                }

                my $displaytext     = CGI::escapeHTML($event->[EV_SUMMARY]) || "";
                my $displaytitle    = CGI::escapeHTML($event->[EV_TITLE]);
                my $displaysubtitle = CGI::escapeHTML($event->[EV_SUBTITLE]);

                my $search_title = $event->[EV_TITLE];
                $search_title =~ s/^.*\~\%*([^\~]*)$/$1/;
                $search_title =  uri_escape($search_title);

                my $imdb_url = undef;
                if ($search_title && $CONFIG{SRCH1_ACTIVE}) {
                    $imdb_url =  $CONFIG{SRCH1_URL};
                    $imdb_url =~ s/\%TITLE\%/$search_title/g;
                }

                my $srch2_url = undef;
                if ($search_title && $CONFIG{SRCH2_ACTIVE}) {
                    $srch2_url =  $CONFIG{SRCH2_URL};
                    $srch2_url =~ s/\%TITLE\%/$search_title/g;
                }

                $displaytext  =~ s/\n/<br \/>\n/g;
                $displaytext  =~ s/\|/<br \/>\n/g;
                $displaytitle =~ s/\n/<br \/>\n/g;
                $displaytitle =~ s/\|/<br \/>\n/g;
                if ($displaysubtitle) {
                    $displaysubtitle =~ s/\n/<br \/>\n/g;
                    $displaysubtitle =~ s/\|/<br \/>\n/g;
                }
                my $myself = Encode_Referer($MyURL . "?" . $Query);
                my $running = $event->[EV_START] <= $now && $now <= $event->[EV_STOP];

                my $timerset = 0;
                foreach my $timer (@timers) {
                  if (($timer->{vdr_id} == $event->[EV_VDR_ID]) && ($timer->{start} <= $event->[EV_START]) && ($timer->{stop} >= $event->[EV_STOP])) {
                    $timerset = 1;
                    last;
                  }
                }

                push(@show,
                    {  date        => my_strftime("%x",     $event->[EV_START]),
                       longdate    => my_strftime("%A, %x", $event->[EV_START]),
                       start       => my_strftime("%H:%M",  $event->[EV_START]),
                       stop        => my_strftime("%H:%M",  $event->[EV_STOP]),
                       event_start => $event->[EV_START],
                       show_percent => $event->[EV_START] <= $now && $now <= $event->[EV_STOP] ? "1" : undef,
                       percent     => $event->[EV_STOP] > $event->[EV_START] ? int(($now - $event->[EV_START]) / ($event->[EV_STOP] - $event->[EV_START]) * 100) : 0,
                       elapsed_min => int(($now - $event->[EV_START]) / 60),
                       length_min  => int(($event->[EV_STOP] - $event->[EV_START]) / 60),
                       title       => $displaytitle,
                       subtitle    => $displaysubtitle,
                       progname    => CGI::escapeHTML($event->[EV_CHANNEL_NAME]),
                       summary     => $displaytext,
                       vdr_id      => $event->[EV_VDR_ID],
                       proglink  => sprintf("%s?aktion=prog_list&amp;vdr_id=%s",      $MyURL,        $event->[EV_VDR_ID]),
                       switchurl => $running ? sprintf("%s?aktion=prog_switch&amp;channel=%s",   $MyURL,        $event->[EV_VDR_ID]) : undef,
                       streamurl => $FEATURES{LIVESTREAM} ? sprintf("%s%s?aktion=live_stream&amp;channel=%s&amp;progname=%s", $MyStreamBase, $CONFIG{TV_EXT}, $event->[EV_VDR_ID], uri_escape($event->[EV_CHANNEL_NAME])) : undef,
                       stream_live_on => $FEATURES{LIVESTREAM} && $running ? $CONFIG{ST_FUNC} && $CONFIG{ST_LIVE_ON} : undef,
                       infurl => $event->[EV_SUMMARY] ? sprintf("%s?aktion=prog_detail&amp;epg_id=%s&amp;vdr_id=%s&amp;referer=%s", $MyURL, $event->[EV_EVENT_ID], $event->[EV_VDR_ID], $myself) : undef,
                       editurl    => sprintf("%s?aktion=prog_detail_form&amp;epg_id=%s&amp;vdr_id=%s&amp;referer=%s", $MyURL, $event->[EV_EVENT_ID], $event->[EV_VDR_ID], $myself),
                       recurl     => sprintf("%s?aktion=timer_new_form&amp;epg_id=%s&amp;vdr_id=%s&amp;referer=%s", $MyURL, $event->[EV_EVENT_ID], $event->[EV_VDR_ID], $myself),
                       find_title => uri_escape("/^" . my_quotemeta($event->[EV_TITLE] . "~" . ($event->[EV_SUBTITLE] ? $event->[EV_SUBTITLE] : "") . "~") . "/"),
                       srch1_url   => $imdb_url,
                       srch1_title => $imdb_url ? gettext($CONFIG{SRCH1_TITLE}) : undef,
                       srch2_url   => $srch2_url,
                       srch2_title => $srch2_url ? gettext($CONFIG{SRCH2_TITLE}) : undef,
                       anchor     => "id" . $event->[EV_EVENT_ID],
                       timerset   =>  $timerset
                    }
                );
                last if (!$search);
            }
        } elsif (!$search && $CONFIG{CHANNELS_WITHOUT_EPG}) { # no EPG
            push(@show,
                {  date        => my_strftime("%x",     $event_time),
                   longdate    => my_strftime("%A, %x", $event_time),
                   start       => undef,
                   show_percent => undef,
                   title       => gettext("No EPG information available"),
                   progname    => CGI::escapeHTML($channel->{name}),
                   vdr_id      => $channel->{vdr_id},
                   proglink    => sprintf("%s?aktion=prog_list&amp;vdr_id=%s", $MyURL, $channel->{vdr_id}),
                   switchurl   => sprintf("%s?aktion=prog_switch&amp;channel=%s", $MyURL, $channel->{vdr_id}),
                   streamurl   => $FEATURES{LIVESTREAM} ? sprintf("%s%s?aktion=live_stream&amp;channel=%s&amp;progname=%s", $MyStreamBase, $CONFIG{TV_EXT}, $channel->{vdr_id}, uri_escape($channel->{name})) : undef,
                   stream_live_on => $FEATURES{LIVESTREAM} ? $CONFIG{ST_FUNC} && $CONFIG{ST_LIVE_ON} : undef,
                   anchor     => "id" . $channel->{vdr_id}
                }
            );
        }
    }

    if ($search) {
        # sort by event's start time and with equal start time sort by channel id
        @show = sort({ $a->{event_start} <=> $b->{event_start} || $a->{vdr_id} <=> $b->{vdr_id} } @show);
    } else {
        # sort by channel id
        @show = sort({ $a->{vdr_id} <=> $b->{vdr_id} } @show);
    }

    my $displayed_time = strftime("%H:%M", localtime($event_time));
    my @times;
    unless ($search) {
        push(@times,
             {  name => gettext("now"),
                id   => "$MyURL?aktion=prog_summary&amp;view=$view",
             }
        );
        push(@times,
             {  name => gettext("next"),
                id   => "$MyURL?aktion=prog_summary&amp;next=1&amp;view=$view",
                sel  => $next ? "1" : undef
             }
        );
        for (split(/,\s*/, $CONFIG{TIMES})) {
            s/\s//g;
            my $id = $_;
            $id =~ s/://;
            push(@times,
                 {  name => gettext("at") . " $_ " . gettext("o'clock"),
                    id   => "$MyURL?aktion=prog_summary&amp;time=$id",
                    sel  => $displayed_time eq $_ ? "1" : undef
                 }
            );
        }
    }

    #
    my $label = $next ? gettext("What's on after") : gettext("What's on at");
    my $vars = { rows    => \@show,
                 now     => $displayed_time,
                 title   => ($search ? gettext("Suitable matches for:") . " <i>" . CGI::escapeHTML($search) . "</i>"
                                     : $label . " " . strftime("%H:%M", localtime($event_time)) . " " . gettext("o'clock")),
                 switchview_url  => $MyURL . "?aktion=prog_summary&amp;view=" . ($view eq "ext" ? "sml" : "ext") . ($next ? "&amp;next=1" : "") . ($search ? "&amp;search=" . uri_escape($search) : "") . ($time ? "&amp;time=$time" : ""),
                 switchview_text => ($view eq "ext" ? gettext("short view") : gettext("long view")),
                 times           => \@times,
                 url             => $MyURL,
                 searchresults   => $search,
                 ch_groups       => getChannelGroups($MyURL . "?aktion=prog_summary&amp;view=" . $view . ($next ? "&amp;next=1" : "") . ($search ? "&amp;search=" . uri_escape($search) : "") . ($time ? "&amp;time=$time" : ""), $CONFIG{CHANNELS_WANTED_SUMMARY})
    };
    return showTemplate($view eq "ext" ? "prog_summary.html" : "prog_summary2.html", $vars);
}

#############################################################################
# recordings
#############################################################################
sub rec_list {
    my @recordings;

    $CONFIG{REC_DESC} = ($q->param("desc") ? 1 : 0) if (defined($q->param("desc")));
    $CONFIG{REC_SORTBY} = $q->param("sortby") if (defined($q->param("sortby")));
    $CONFIG{REC_SORTBY} = "name" if (!$CONFIG{REC_SORTBY});

    my $parent = $q->param("parent");
    if (!$parent) {
        $parent = 0;
    } else {
        $parent = uri_escape($parent);
    }

    ParseRecordings($parent);

    # create path array
    my @path;
    my $fuse    = 0;
    my $rparent = $parent;

    # printf("PATH: (%s)\n", $parent);
    while ($rparent) {
        for my $recording (@RECORDINGS) {
            if ($recording->{recording_id} eq $rparent) {
                push(@path,
                     {  name => $recording->{name},
                        url  => ($recording->{recording_id} ne $parent) ? sprintf("%s?aktion=rec_list&amp;parent=%s", $MyURL, $recording->{recording_id}) : ""
                     }
                );
                $rparent = $recording->{parent};
                last;
            }
        }
        $fuse++;
        last if ($fuse > 100);
    }
    push(@path,
         {  name => gettext("Schedule"),
            url  => ($parent ne 0) ? sprintf("%s?aktion=rec_list&amp;parent=%s", $MyURL, 0) : ""
         }
    );
    @path = reverse(@path);

    # filter
    if (defined($parent)) {
        for my $recording (@RECORDINGS) {
            if ($recording->{parent} eq $parent) {
                push(@recordings, $recording);
            }
        }
    } else {
        @recordings = @RECORDINGS;
    }

    #
    if ($CONFIG{REC_SORTBY} eq "time") {
        if ($CONFIG{REC_DESC}) {
            @recordings = sort({ $b->{isfolder} <=> $a->{isfolder} ||
                                 ciCmp($b->{isfolder} ? $a->{name} : "", $a->{isfolder} ? $b->{name} : "") ||
                                 $b->{time} <=> $a->{time} } @recordings);
        } else {
            @recordings = sort({ $b->{isfolder} <=> $a->{isfolder} ||
                                 ciCmp($b->{isfolder} ? $a->{name} : "", $a->{isfolder} ? $b->{name} : "") ||
                                 $a->{time} <=> $b->{time} } @recordings);
        }
    } elsif ($CONFIG{REC_SORTBY} eq "name") {
        if ($CONFIG{REC_DESC}) {
            @recordings = sort({ $b->{isfolder} <=> $a->{isfolder} ||
                                 ciCmp($b->{isfolder} ? $b->{name} : "", $a->{isfolder} ? $a->{name} : "") ||
                                 ciCmp($b->{name}, $a->{name}) ||
                                 $b->{sse} <=> $a->{sse} } @recordings);
        } else {
            @recordings = sort({ $b->{isfolder} <=> $a->{isfolder} ||
                                 ciCmp($b->{isfolder} ? $a->{name} : "", $a->{isfolder} ? $b->{name} : "") ||
                                 ciCmp($a->{name}, $b->{name}) ||
                                 $a->{sse} <=> $b->{sse} } @recordings);
        }
    } elsif ($CONFIG{REC_SORTBY} eq "date") {
        if ($CONFIG{REC_DESC}) {
            @recordings = sort({ $b->{isfolder} <=> $a->{isfolder} ||
                                 ciCmp($b->{isfolder} ? $a->{name} : "", $a->{isfolder} ? $b->{name} : "") ||
                                 $b->{sse} <=> $a->{sse} } @recordings);
        } else {
            @recordings = sort({ $b->{isfolder} <=> $a->{isfolder} ||
                                 ciCmp($b->{isfolder} ? $a->{name} : "", $a->{isfolder} ? $b->{name} : "") ||
                                 $a->{sse} <=> $b->{sse} } @recordings);
        }
    } elsif ($CONFIG{REC_SORTBY} eq "length") {
        if ($CONFIG{REC_DESC}) {
            @recordings = sort({ $b->{isfolder} <=> $a->{isfolder} ||
                                 $b->{lengthmin} <=> $a->{lengthmin} ||
                                 ciCmp($b->{isfolder} ? $a->{name} : "", $a->{isfolder} ? $b->{name} : "")
                               } @recordings);
        } else {
            @recordings = sort({ $b->{isfolder} <=> $a->{isfolder} ||
                                 $a->{lengthmin} <=> $b->{lengthmin} ||
                                 ciCmp($b->{isfolder} ? $a->{name} : "", $a->{isfolder} ? $b->{name} : "")
                               } @recordings);
        }
    }
    my $toggle_desc = ($CONFIG{REC_DESC} ? 0 : 1);

    #
    my ($total, $minutes_total, $free, $minutes_free, $percent) = VideoDiskFree();

    my $referer = Encode_Referer($MyURL . "?" . $Query);
    chomp($referer);
    my $vars = { recloop       => \@recordings,
                 sortbydateurl => "$MyURL?aktion=rec_list&amp;parent=$parent&amp;sortby=date&amp;parent=$parent&amp;desc=" . (($CONFIG{REC_SORTBY} eq "date") ? $toggle_desc : $CONFIG{REC_DESC}),
                 sortbytimeurl => "$MyURL?aktion=rec_list&amp;parent=$parent&amp;sortby=time&amp;parent=$parent&amp;desc=" . (($CONFIG{REC_SORTBY} eq "time") ? $toggle_desc : $CONFIG{REC_DESC}),
                 sortbylengthurl => "$MyURL?aktion=rec_list&amp;parent=$parent&amp;sortby=length&amp;parent=$parent&amp;desc=" . (($CONFIG{REC_SORTBY} eq "length") ? $toggle_desc : $CONFIG{REC_DESC}),
                 sortbynameurl => "$MyURL?aktion=rec_list&amp;parent=$parent&amp;sortby=name&amp;parent=$parent&amp;desc=" . (($CONFIG{REC_SORTBY} eq "name") ? $toggle_desc : $CONFIG{REC_DESC}),
                 sortbydate => ($CONFIG{REC_SORTBY} eq "date") ? 1 : 0,
                 sortbytime => ($CONFIG{REC_SORTBY} eq "time") ? 1 : 0,
                 sortbylength => ($CONFIG{REC_SORTBY} eq "length") ? 1 : 0,
                 sortbyname => ($CONFIG{REC_SORTBY} eq "name") ? 1 : 0,
                 desc       => $CONFIG{REC_DESC} ? "desc" : "asc",
                 disk_total    => $total,
                 disk_free     => $free,
                 disk_percent  => $percent,
                 minutes_free  => $minutes_free,
                 minutes_total => $minutes_total,
                 path          => \@path,
                 url           => $MyURL,
                 help_url      => HelpURL("rec_list"),
                 reccmds       => \@reccmds,
                 stream_rec_on => $CONFIG{ST_FUNC} && $CONFIG{ST_REC_ON},
                 streamfolderurl => ($CONFIG{ST_FUNC} && $CONFIG{ST_REC_ON}) ? "$MyURL?aktion=rec_stream_folder&amp;parent=$parent" : undef,
                 referer       => "&amp;referer=$referer"
    };
    return showTemplate("rec_list.html", $vars);
}

sub ParseRecordings {
    my $parent = shift;

    if ($CONFIG{CACHE_REC_ENABLED} != 0) {
        if (-e "$CONFIG{VIDEODIR}/.update") {
            my $mtime = (stat(_))[9];
            return if ($mtime < $CONFIG{CACHE_REC_LASTUPDATE});
        } else {
            return if ((time() - $CONFIG{CACHE_REC_LASTUPDATE}) < ($CONFIG{CACHE_REC_TIMEOUT} * 60));
        }
    }

    undef @RECORDINGS;
    for my $recording (SendCMD("lstr")) {
        chomp($recording);
        next if (length($recording) == 0);
        last if ($recording =~ /^No recordings available/);

        my ($id, $date, $time, $length, $name, $new);
        if ($FEATURES{VDRVERSION} < 10721) {
            # id date time* name
            ($id, $date, $time, $name) = split(/ +/, $recording, 4);
            if (length($time) > 5) {
                $new = 1;
                $time = substr($time, 0, 5);
            }
        } else {
            # id date time length* name
            ($id, $date, $time, $length, $name) = split(/ +/, $recording, 5);
            if ($length =~ /^(\d+:\d+)\D/) {
                $new = 1;
                $length = $1;
            }
        }

        #
        my (@tmp, @tmp2, $serie, $episode, $parent);
        @tmp  = split("~", $name);
        @tmp2 = @tmp;

#    if($name =~ /~/) {
#        @tmp2 = split(" ", $name, 2);
#        if(scalar(@tmp2) > 1) {
#            if(ord(substr($tmp2[0], length($tmp2[0])-1, 1)) == 180) {
#                @tmp = split("~", $tmp2[1]);
#                $name = "$tmp2[0] $tmp[scalar(@tmp) - 1]";
#            } else {
#                @tmp = split("~", $name);
#                $name = $tmp[scalar(@tmp) - 1];
#            }
#        } else {
#            @tmp = split("~", $name);
#            $name = $tmp[scalar(@tmp) - 1];
#        }
#        $parent  = uri_escape(join("~",@tmp[0, scalar(@tmp) - 2]));
#    }
        $name = pop(@tmp);
        if (@tmp) {
            $parent = uri_escape(join("~", @tmp));
        } else {
            $parent = 0;
        }

        # printf("PARENT: (%s) (%s) (%s)\n", scalar(@tmp), $parent, $name);

        # create subfolders
        pop(@tmp2);    # don't want the recording's name
        while (@tmp2) {
            my $recording_id = uri_escape(join("~", @tmp2));
            my $recording_name = pop(@tmp2);
            my $parent;
            if (@tmp2) {
                $parent = uri_escape(join("~", @tmp2));
            } else {
                $parent = 0;
            }

#        printf("SUB: (%s) (%s) (%s)\n", $recording_name, $recording_id, $parent);
#    }
#    for(my $i = 0; $i < scalar(@tmp) - 1; $i++) {
#    my $recording_id;
#    my $recording_name = $tmp[$i];
#    my $parent;
#    printf("REC: (%s) (%s) (%s)\n", $i, join("~",@tmp[0, $i]), join("~",@tmp[0, $i - 1]));
#    $recording_id = uri_escape(join("~",@tmp[0, $i]));
#    $parent;
#    if($i != 0) {
#        $parent = uri_escape(join("~",@tmp[0, $i - 1]));
#    } else {
#        $parent = 0;
#    }

            my $found = 0;
            for my $recording (@RECORDINGS) {
                next if (!$recording->{isfolder});
                if ($recording->{recording_id} eq $recording_id && $recording->{parent} eq $parent) {
                    $found = 1;
                }
            }
            if (!$found) {

                # printf("RECLIST %s: (%s) (%s)\n",$recording_name, $recording_id, $parent);
                push(@RECORDINGS,
                     {  name         => CGI::escapeHTML($recording_name),
                        recording_id => $recording_id,
                        parent       => $parent,
                        isfolder     => 1,
                        date         => 0,
                        time         => 0,
                        lengthmin    => 0,
                        infurl       => sprintf("%s?aktion=rec_list&amp;parent=%s", $MyURL, $recording_id),
                        streamurl    => "$MyURL?aktion=rec_stream_folder&amp;parent=$recording_id"
                     }
                );
            }
        }

        #
        my $yearofrecording;
        if ($FEATURES{VDRVERSION} >= 10326) {

            # let localtime() decide about the century
            $yearofrecording = substr($date, 6, 2);

            # alternatively decide about the century ourself
            #    my $shortyear = substr($date,6,2);
            #    if ($shortyear > 70) {
            #        $yearofrecording = "19" . $shortyear;
            #    } else {
            #        $yearofrecording = "20" . $shortyear;
            #    }
        } else {

            # old way of vdradmin to handle the date while vdr did not report the year
            # current year was assumed.
            if ($date eq "29.02") {
                $yearofrecording = "2004";
            } else {
                $yearofrecording = my_strftime("%Y");
            }
        }    # endif

        my $lengthmin = 0;
        if ($length =~ /^(\d+):(\d{1,2})$/) {
            $lengthmin = $1 * 60 + $2;
        } elsif ($length =~ /^\d+/) {
            $lengthmin = $length;
        }

        my $name_js = $name;
        $name_js =~ s/\'/\\\'/g;
        $name_js =~ s/\"/\&quot;/g;
        push(@RECORDINGS,
             {  sse => timelocal(undef, substr($time, 3, 2), substr($time, 0, 2), substr($date, 0, 2), (substr($date, 3, 2) - 1), $yearofrecording),
                date          => $date,
                time          => $time,
                length        => $length,
                lengthmin     => $lengthmin,
                name          => CGI::escapeHTML($name),
                name_js       => $name_js,
                serie         => $serie,
                episode       => $episode,
                parent        => $parent,
                new           => $new,
                id            => $id,
                isfolder      => 0,
                delurl        => $MyURL . "?aktion=rec_delete&amp;rec_delete=y&amp;id=$id",
                editurl       => $FEATURES{REC_RENAME} ? $MyURL . "?aktion=rec_edit&amp;id=$id" : undef,
                infurl        => $MyURL . "?aktion=rec_detail&amp;id=$id",
                playurl       => $FEATURES{VDRVERSION} >= 10331 ? $MyURL . "?aktion=rec_play&amp;id=$id" : undef, #TODO
                cuturl        => $FEATURES{VDRVERSION} >= 10331 ? $MyURL . "?aktion=rec_cut&amp;id=$id" : undef, #TODO
                streamurl     => ($CONFIG{ST_FUNC} && $CONFIG{ST_REC_ON}) ? $MyStreamBase . $CONFIG{REC_EXT} . "?aktion=rec_stream&amp;id=$id" : undef
             }
        );
    }

    countRecordings(0);
    for (@RECORDINGS) {
        $_->{length} ||=
            sprintf("%d:%02d", $_->{lengthmin} / 60, $_->{lengthmin} % 60);
    }

    $CONFIG{CACHE_REC_LASTUPDATE} = time();
}

sub countRecordings {
    my $parent = shift;
    my $folder = shift;

    for (@RECORDINGS) {
        if ($_->{parent} eq $parent) {
            if ($_->{isfolder}) {
                countRecordings($_->{recording_id}, $_);
                if ($folder) {
                    $folder->{date} += $_->{date};
                    $folder->{time} += $_->{time} if ($_->{time});
                    $folder->{lengthmin} += $_->{lengthmin};
                }
            } elsif ($folder) {
                $folder->{date}++;
                $folder->{time}++ if ($_->{new});
                $folder->{lengthmin} += $_->{lengthmin};
            }
        }
    }
}

sub getRecInfo {
    my $id  = shift;
    my $ref = shift;
    my $rename = shift;

    my ($i, $length, $title);
    for (SendCMD("lstr")) {
        if ($FEATURES{VDRVERSION} < 10721) {
            ($i, undef, undef, $title) = split(/ +/, $_, 4);
        } else {
            ($i, undef, undef, $length, $title) = split(/ +/, $_, 5);
        }
        last if ($id == $i);
    }
    chomp($title);
    $length =~ s/\*+$//;

    my $vars;
    if ($FEATURES{VDRVERSION} >= 10325) {
        $SVDRP->command("lstr $id");
        my ($channel_name, $subtitle, $text, $video, $audio, $subs);
        while ($_ = $SVDRP->readoneline) {
            if (/^C (.*)/) { $channel_name = get_name_from_uniqid($1); }
            #elsif (/^E (.*)/) { $epg = $1; }
            elsif (/^T (.*)/) { $title    = $1; }
            elsif (/^S (.*)/) { $subtitle = $1; }
            elsif (/^D (.*)/) { $text     = $1; }
            elsif (/^X 1 [^ ]* (.*)/) {
                my ($lang, $format) = split(" ", $1, 2);
                $video .= ", " if($video);
                $video .= $format;
                $video .= " (" . $lang . ")";
            }
            elsif (/^X 2 [^ ]* (.*)/) {
                my ($lang, $descr) = split(" ", $1, 2);
                $audio .= ", " if ($audio);
                $audio .= ($descr ? $descr. " (" . $lang . ")"  : $lang);
            }
            elsif(/^X 3 [^ ]* (.*)/) {
                my ($lang, $descr) = split(" ", $1, 2);
                $subs .= ", " if ($subs);
                $subs .= ($descr ? $descr. " (" . $lang . ")"  : $lang);
            }
            #elsif (/^V (.*)/) { $vps = $1; }
        }

        my $displaytext     = CGI::escapeHTML($text) || "";
        my $displaytitle    = CGI::escapeHTML($title);
        my $displaysubtitle = CGI::escapeHTML($subtitle);

        my $search_title = $title;
        $search_title =~ s/^.*\~\%*([^\~]*)$/$1/;
        $search_title =  uri_escape($search_title);

        my $imdb_url = undef;
        if ($search_title && $CONFIG{SRCH1_ACTIVE}) {
            $imdb_url =  $CONFIG{SRCH1_URL};
            $imdb_url =~ s/\%TITLE\%/$search_title/g;
        }

        my $srch2_url = undef;
        if ($search_title && $CONFIG{SRCH2_ACTIVE}) {
            $srch2_url =  $CONFIG{SRCH2_URL};
            $srch2_url =~ s/\%TITLE\%/$search_title/g;
        }

        $displaytext     =~ s/\n/<br \/>\n/g;
        $displaytext     =~ s/\|/<br \/>\n/g;
        unless ($rename) {
            $displaytitle    =~ s/\~/ - /g;
            $displaytitle    =~ s/\n/<br \/>\n/g;
            $displaytitle    =~ s/\|/<br \/>\n/g;
        }
        $displaysubtitle =~ s/\n/<br \/>\n/g;
        $displaysubtitle =~ s/\|/<br \/>\n/g;

        $vars = { url      => $MyURL,
                  text     => $displaytext || undef,
                  title    => $displaytitle || undef,
                  subtitle => $displaysubtitle || undef,
                  channel_name => $channel_name || undef,
                  srch1_url   => $imdb_url,
                  srch1_title => $imdb_url ? gettext($CONFIG{SRCH1_TITLE}) : undef,
                  srch2_url   => $srch2_url,
                  srch2_title => $srch2_url ? gettext($CONFIG{SRCH2_TITLE}) : undef,
                  id       => $id,
                  video    => $video,
                  audio    => $audio,
                  subs     => $subs,
                  length   => $length,
                  referer  => $ref || undef
        };
    } else {
        my ($text);
        my ($first)  = 1;
        my ($result) = SendCMD("lstr $id");
        if ($result !~ /No summary availab/i) {
            for (split(/\|/, $result)) {
                if ($_ ne (split(/\~/, $title))[1] && "%" . $_ ne (split(/\~/, $title))[1] && "@" . $_ ne (split(/\~/, $title))[1]) {
                    if ($first && $title !~ /\~/ && length($title) < 20) {
                        $title .= "~" . $_;
                        $first = 0;
                    } else {
                        if ($text) {
                            $text .= "<br \/>";
                        }
                        $text .= CGI::escapeHTML("$_ ");
                    }
                }
            }
        }

        my $search_title = $title;
        $search_title =~ s/^.*\~\%*([^\~]*)$/$1/;
        $search_title =  uri_escape($search_title);
        # TODO? $search_title =~ s/^.*\~//;

        my $imdb_url = undef;
        if ($search_title && $CONFIG{SRCH1_ACTIVE}) {
            $imdb_url =  $CONFIG{SRCH1_URL};
            $imdb_url =~ s/\%TITLE\%/$search_title/g;
        }

        my $srch2_url = undef;
        if ($search_title && $CONFIG{SRCH2_ACTIVE}) {
            $srch2_url =  $CONFIG{SRCH2_URL};
            $srch2_url =~ s/\%TITLE\%/$search_title/g;
        }

        $title      =~ s/\~/ - /g unless($rename);
        $vars = { url     => $MyURL,
                  text    => $text ? $text : "",
                  srch1_url   => $imdb_url,
                  srch1_title => $imdb_url ? gettext($CONFIG{SRCH1_TITLE}) : undef,
                  srch2_url   => $srch2_url,
                  srch2_title => $srch2_url ? gettext($CONFIG{SRCH2_TITLE}) : undef,
                  title   => CGI::escapeHTML($title),
                  id      => $id
        };
    }

    return $vars;
}

sub rec_detail {
    my $vars = getRecInfo(scalar $q->param('id'));

    return showTemplate("prog_detail.html", $vars);
}

sub rec_delete {
    my $id = $q->param('id');

    if ($q->param("rec_delete")) {
        if ($id) {
            SendCMD("delr $id");
        } else {
            my @id_arr = ();
            for ($q->param) {
                if (/xxxx_(.*)/) {
                    push (@id_arr, $1);
                }
            }
            # VDR 2.3.x workaround:
            # delete starting with the largest id and proceed to the smallest.
            # In this case, ids won't change while removing items from the list.
            @id_arr = sort {$b <=> $a} @id_arr;
            for my $del_id (@id_arr) {
                SendCMD("delr $del_id");
            }
        }
        CloseSocket();

        # Re-read recording's list
        $CONFIG{CACHE_REC_LASTUPDATE} = 0;
    } elsif ($q->param("rec_runcmd")) {
        if ($id) {
            recRunCmd($q->param("rec_cmd"), $id);
        } else {
            for ($q->param) {
                if (/xxxx_(.*)/) {
                    recRunCmd($q->param("rec_cmd"), $1);
                }
            }
        }
    } elsif ($q->param("rec_update")) {

        # Re-read recording's list
        $CONFIG{CACHE_REC_LASTUPDATE} = 0;
    }
    return RedirectToReferer("$MyURL?aktion=rec_list&sortby=" . $q->param("sortby") . "&desc=" . $q->param("desc"));
}

sub recRunCmd {
    my ($cmdID, $id) = @_;
    my $cmd = ${reccmds}[$cmdID]{cmd};
    my ($rec_id, $date,  $time, $title);
    my ($day,    $month, $hour, $minute, $newtitle, $c, $folder);

    for (SendCMD("lstr")) {
        if ($FEATURES{VDRVERSION} < 10721) {
            ($rec_id, $date, $time, $title) = split(/ +/, $_, 4);
        } else {
            ($rec_id, $date, $time, undef, $title) = split(/ +/, $_, 5);
        }
        last if ($rec_id == $id);
    }

    $time = substr($time, 0, 5);    # needed for wareagel-patch
    if ($rec_id == $id) {
        chomp($title);
        ($day,  $month)  = split(/\./, $date);
        ($hour, $minute) = split(/:/,  $time);

        # VFAT off
        my $folder = findVideoFolder($minute, $hour, $day, $month, encode_RecTitle($title, 0));
        unless ($folder) {
            # VFAT on
            $folder = findVideoFolder($minute, $hour, $day, $month, encode_RecTitle($title, 1));
        }
        if ($folder) {
            Log(LOG_DEBUG, "[REC] recRunCmd: executing ($cmd \"$folder\")");
            `$cmd "$folder"`;
        }
    }
}

sub findVideoFolder {
    # VDR < v1.7.2:  YYYY-MM-DD-hh[.:]mm.pr.lt.rec (pr=priority, lt=lifetime)
    # VDR >= v1.7.2: YYYY-MM-DD-hh.mm.ch-ri.rec    (ch=channel, ri=resumeId)

    my ($minute, $hour, $day, $month, $title) = @_;
    my $folder;

    $title =~ s/ /_/g;
    $title =~ s/~/\//g;
    $folder = `find $CONFIG{VIDEODIR}/ -follow -regex "$CONFIG{VIDEODIR}/$title\_*/\\(\_/\\)?....-$month-$day\\.$hour.$minute\\.\[0-9\]+\[.-\]\[0-9\]+\\.rec"`;
    Log(LOG_DEBUG, "[REC] findVideoFolder: find $CONFIG{VIDEODIR}/ -follow -regex \"$CONFIG{VIDEODIR}/$title\_*/\\(\_/\\)?....-$month-$day\\.$hour.$minute\\.\[0-9\]+\[.-\]\[0-9\]+\\.rec\"");
    chomp($folder) if ($folder);

    return $folder;
}

sub rec_edit {

    # determine referer (redirect to where we come from)
    my $ref = getReferer();

    my $vars = getRecInfo(scalar $q->param("id"), $ref ? Encode_Referer($ref) : undef, "renr");
    return showTemplate("rec_edit.html", $vars);
}

sub rec_rename {
    my $id = $q->param('id');
    my $nn = $q->param('nn');
    if ($id && $q->param("save")) {
        SendCMD("$FEATURES{REC_RENAME} $id $nn");
        CloseSocket();

        # Re-read recording's list
        $CONFIG{CACHE_REC_LASTUPDATE} = 0;
    }

    my $ref = getReferer();
    if ($ref) {
        return headerForward($ref);
    } else {
        return headerForward("$MyURL?aktion=rec_list&sortby=" . $q->param("sortby") . "&desc=" . $q->param("desc"));
    }
}

sub rec_play {
    my $id = $q->param('id');
    if ($id) {
        SendCMD("PLAY $id");
        CloseSocket();
    }
}

sub rec_cut {
    my $id = $q->param('id');
    if ($id) {
        SendCMD("EDIT $id");
        CloseSocket();
    }
}

#############################################################################
# configuration
#############################################################################
sub config {
    my $error_msg;

    unless ($q->param("save") || $q->param("apply") || $q->param("submit")) {
        undef %CONFIG_TEMP;
        for my $key (keys(%CONFIG)) {
            $CONFIG_TEMP{$key} = $CONFIG{$key};
        }
    }

    sub ApplyConfig {
        for ($q->param) {
            if (/[A-Z]+/) {
                $CONFIG_TEMP{$_} = $q->param($_);
            }
        }

        my $need_trans_reload = 1 if ($CONFIG_TEMP{LANG} ne $CONFIG{LANG});
        my $need_vdrconf_reload = 1 if ($CONFIG_TEMP{VDRCONFDIR} ne $CONFIG{VDRCONFDIR});
        my $need_update = 1 if ($CONFIG_TEMP{EPG_PRUNE} != $CONFIG{EPG_PRUNE}
                             || $CONFIG_TEMP{CHANNELS_WANTED} ne $CONFIG{CHANNELS_WANTED});
        for my $key (keys(%CONFIG_TEMP)) {
            $CONFIG{$key} = $CONFIG_TEMP{$key};
        }

        ValidConfig();

        LoadTranslation() if ($need_trans_reload);
        UptoDate(1) if ($need_update);
        if ($need_vdrconf_reload) {
            @reccmds = loadCommandsConf("$CONFIG{VDRCONFDIR}/reccmds.conf");
            @vdrcmds = loadCommandsConf("$CONFIG{VDRCONFDIR}/commands.conf");
        }
    }

    sub WriteConfig {
        open(CONF, ">$CONFFILE") || return sprintf(gettext("Can't write configuration file %s! Reason: %s") . "<br />", $CONFFILE, "$!");
        my $old_collate = setlocale(LC_COLLATE);
        setlocale(LC_COLLATE, "C");
        for my $key (sort(keys(%CONFIG))) {
            print CONF "$key = $CONFIG{$key}\n";
        }
        setlocale(LC_COLLATE, $old_collate);
        close(CONF);
        return "";
    }

    if ($q->param("submit")) {
        if ($q->param("submit") eq ">>>>>") {
            for my $vdr_id ($q->param("all_channels")) {
                $CONFIG_TEMP{CHANNELS_WANTED} = csvAdd($CONFIG_TEMP{CHANNELS_WANTED}, $vdr_id);
            }
        } elsif ($q->param("submit") eq "<<<<<") {
            for my $vdr_id ($q->param("selected_channels")) {
                $CONFIG_TEMP{CHANNELS_WANTED} = csvRemove($CONFIG_TEMP{CHANNELS_WANTED}, $vdr_id);
            }
        }
    } elsif ($q->param("save")) {
        ApplyConfig();
        $error_msg .= WriteConfig();
    } elsif ($q->param("apply")) {
        ApplyConfig();
    }

    # vdradmind.conf writable?
    $error_msg .= sprintf(gettext("Configuration file %s not writable! Configuration won't be saved!") . "<br />", $CONFFILE) unless (-w $CONFFILE);

    #
    my @LOGINPAGES_DESCRIPTION = (gettext("What's On Now?"), gettext("Playing Today?"), gettext("Timeline"), gettext("Channels"), gettext("Timers"), gettext("Recordings"));
    my (@loginpages);
    my $i = 0;
    for my $loginpage (@LOGINPAGES) {
        push(@loginpages,
             {  id      => $i,
                name    => $LOGINPAGES_DESCRIPTION[$i],
                current => ($CONFIG_TEMP{LOGINPAGE} == $i) ? 1 : 0
             }
        );
        $i++;
    }

    #
    my @template;
    for my $dir (<$TEMPLATEDIR/*>) {
        next if (!-d $dir);
        $dir =~ s/.*\///g;
        my $found = 0;
        for (@template) { ($found = 1) if ($1 && ($_->{name} eq $1)); }
        if (!$found) {
            push(@template,
                 {  name       => $dir,
                    aktemplate => ($CONFIG_TEMP{TEMPLATE} eq $dir) ? 1 : 0,
                 }
            );
        }
    }

    my @selected_channels;
    for my $channel (@{$CHAN{$CHAN_FULL}->{channels}}) {
        my $found = 0;
        for (split(",", $CONFIG_TEMP{CHANNELS_WANTED})) {
            if ($_ eq $channel->{vdr_id}) {
                $found = 1;
            }
        }
        next unless $found;
        push(@selected_channels,
                {   name   => $channel->{name},
                    vdr_id => $channel->{vdr_id}
                }
        );
    }

    my @skinlist;
    foreach my $file (glob(sprintf("%s/%s/*", $TEMPLATEDIR, $CONFIG_TEMP{TEMPLATE}))) {
        my $name = (split('\/', $file))[-1];
        next if ($name eq 'js');
        push(@skinlist,
             {  name => $name,
                sel  => ($CONFIG_TEMP{SKIN} eq $name ? 1 : 0)
             }
          )
          if (-d $file);
    }

    my @my_locales;
    if (-f "/usr/bin/locale" && -x _) {
        push(@my_locales, { id => "", name => gettext("System default"), cur => 0 });
        foreach my $loc (`locale -a`) {
            chomp $loc;
            push(@my_locales,
                 {  id   => $loc,
                    name => $loc,
                    cur  => ($loc eq $CONFIG_TEMP{LANG} ? 1 : 0)
                 }
              )
              if ($loc =~ $SUPPORTED_LOCALE_PREFIXES);
        }
    }

    my $vars = { TEMPLATELIST      => \@template,
                 ALL_CHANNELS      => \@{$CHAN{$CHAN_FULL}->{channels}},
                 SELECTED_CHANNELS => \@selected_channels,
                 LOGINPAGES        => \@loginpages,
                 SKINLIST          => \@skinlist,
                 MY_LOCALES        => \@my_locales,
                 url               => $MyURL,
                 help_url          => HelpURL("config"),
                 config            => \%CONFIG_TEMP,
                 error_msg         => $error_msg
    };
    return showTemplate("config.html", $vars);
}

#############################################################################
# remote control
#############################################################################
sub rc_show {
    $CONFIG{CHANNELS_WANTED_WATCHTV} = $q->param("wanted_channels") if (defined $q->param("wanted_channels"));
    my ($cur_channel_id, $cur_channel_name);
    for (SendCMD("chan")) {
        ($cur_channel_id, $cur_channel_name) = split(" ", $_, 2);
    }

    my @chans;
    for my $chan (@{$CHAN{$CONFIG{CHANNELS_WANTED_WATCHTV}}->{channels}}) {
        if ($chan->{vdr_id}) {
            $chan->{cur} = ($chan->{vdr_id} == $cur_channel_id) ? 1 : 0;
        }
        push(@chans, $chan);
    }

    my $vars = { url       => sprintf("%s?aktion=grab_picture", $MyURL),
                 host      => $CONFIG{VDR_HOST},
                 channels  => \@chans,
                 ch_groups => getChannelGroups($MyURL . "?aktion=rc_show&amp;full_rc=1", $CONFIG{CHANNELS_WANTED_WATCHTV}),
                 full_rc   => $q->param('full_rc') ? 1 : 0
    };
    return showTemplate("rc.html", $vars);
}

sub rc_hitk {
    my $key = $q->param("key");
    if ($key eq "VolumePlus") {
        $key = "Volume+";
    }
    if ($key eq "VolumeMinus") {
        $key = "Volume-";
    }
    SendCMD("hitk $key");

    #XXX
    SendFile("bilder/spacer.gif");
}

sub tv_show {
    $CONFIG{TV_INTERVAL} = $q->param("interval") if($q->param("interval"));
    $CONFIG{TV_INTERVAL} = "5" unless($CONFIG{TV_INTERVAL});
    $CONFIG{TV_SIZE}     = $q->param("size")     if($q->param("size"));
    $CONFIG{TV_SIZE}     = "half" unless($CONFIG{TV_SIZE});
    $CONFIG{CHANNELS_WANTED_WATCHTV} = $q->param("wanted_channels") if (defined $q->param("wanted_channels"));

    my ($cur_channel_id, $cur_channel_name);
    for (SendCMD("chan")) {
        ($cur_channel_id, $cur_channel_name) = split(" ", $_, 2);
    }

    my @chans;
    for my $chan (@{$CHAN{$CONFIG{CHANNELS_WANTED_WATCHTV}}->{channels}}) {
        if ($chan->{vdr_id}) {
            $chan->{cur} = ($chan->{vdr_id} == $cur_channel_id) ? 1 : 0;
        }
        push(@chans, $chan);
    }

    my $vars = { full_tv  => $q->param("full_tv")  ? 1 : undef,
                 interval => $CONFIG{TV_INTERVAL},
                 size     => $CONFIG{TV_SIZE},
                 new_win  => ($q->param("new_win") && $q->param("new_win") eq "1") ? "1" : undef,
                 url      => sprintf("%s?aktion=grab_picture", $MyURL),
                 channels => \@chans,
                 ch_groups => getChannelGroups($MyURL . "?aktion=tv_show&amp;full_tv=1", $CONFIG{CHANNELS_WANTED_WATCHTV}),
                 host     => $CONFIG{VDR_HOST}
    };
    return showTemplate("tv.html", $vars);
}

sub tv_switch {
    my $channel = $q->param("channel");
    if ($channel) {
        SendCMD("chan $channel");
    }
}

sub show_help {
    my $area     = $q->param("area");
    my $filename = "help_" . $area . ".html";
    if (!-e "$TEMPLATEDIR/$CONFIG{TEMPLATE}/$filename") {
        $filename = "help_no.html";
    }
    my $vars = { area    => $area
    };
    return showTemplate($filename, $vars);
}

#############################################################################
# information
#############################################################################
sub about {
    my $vars = {
    };
    return showTemplate("about.html", $vars);
}

#############################################################################
# experimental
#############################################################################
sub grab_picture {
    $CONFIG{TV_INTERVAL} = $q->param("interval") if($q->param("interval"));
    $CONFIG{TV_INTERVAL} = "5" unless($CONFIG{TV_INTERVAL});
    $CONFIG{TV_SIZE}     = $q->param("size")     if($q->param("size"));
    $CONFIG{TV_SIZE}     = "half" unless($CONFIG{TV_SIZE});

    my $maxwidth  = 768;
    my $maxheight = 576;
    my ($width, $height);
    if ($CONFIG{TV_SIZE} eq "full") {
        ($width, $height) = ($maxwidth, $maxheight);
    } elsif ($CONFIG{TV_SIZE} eq "half") {
        ($width, $height) = ($maxwidth / 2, $maxheight / 2);
    } elsif ($CONFIG{TV_SIZE} eq "quarter") {
        ($width, $height) = ($maxwidth / 4, $maxheight / 4);
    } else {
        ($width, $height) = ($maxwidth / 4, $maxheight / 4);
    }

    if ($FEATURES{VDRVERSION} < 10338) {

        # Grab using temporary file
        my $file = new File::Temp(TEMPLATE => "vdr-XXXXX", DIR => File::Spec->tmpdir(), UNLINK => 1, SUFFIX => ".jpg");
        chmod 0666, $file if (-e $file);
        SendCMD("grab $file jpeg 70 $width $height");
        if (-e $file && -r _) {
            return (header("200", "image/jpeg", ReadFile($file)));
        } else {
            print "Expected $file does not exist.\n";
            print "Obviously VDR Admin could not find the screenshot file. Ensure that:\n";
            print " - VDR has the rights to write $file\n";
            print " - VDR and VDR Admin run on the same machine\n";
            print " - VDR Admin may read $file\n";
            print " - VDR has access to /dev/video* files\n";
            print " - you have a full featured card\n";
            return SendFile("bilder/spacer.gif");
        }
    } else {
        my $image;
        for (SendCMD("grab .jpg 70 $width $height")) {
            $image .= $_ unless (/Grabbed image/);
        }
        return SendFile("bilder/noise.gif") if ($image =~ /Grab image failed/);
        return (header("200", "image/jpeg", MIME::Base64::decode_base64($image)));
    }
}

sub force_update {
    UptoDate(1);
    RedirectToReferer("$MyURL?aktion=prog_summary");
}

sub loadCommandsConf {
    my $conf_file = shift;
    my @commands;
    my $id = 0;
    if (-e $conf_file and my $text = open(FH, $conf_file)) {
        while (<FH>) {
            chomp;
            s/#.*//;
            s/^\s+//;
            s/\s+$//;
            next unless length;
            next if (/{$/);
            next if (/^}$/);
            my ($title, $cmd) = split(":", $_);
            push(@commands, { title => $title, cmd => $cmd, id => $id });
            $id = $id + 1;
        }
        close(FH);
    }
    return @commands;
}

sub vdr_cmds {
    my @show_output;
    @show_output = run_vdrcmd()   if ($q->param("run_vdrcmd"));
    @show_output = run_svdrpcmd() if ($q->param("run_svdrpcmd"));
    my $svdrp_cmd = "help";
    $svdrp_cmd = $q->param("svdrp_cmd") if ($q->param("svdrp_cmd"));
    $CONFIG{CMD_LINES} = $q->param("max_lines") if ($q->param("max_lines"));
    my @export_cmds = ( { url => sprintf("%s%s?aktion=export_channels_m3u&amp;wanted=%d", $MyStreamBase, $CONFIG{TV_EXT}, $CHAN_FULL), text => gettext('All channels') },
                        { url => sprintf("%s%s?aktion=export_channels_m3u&amp;wanted=%d", $MyStreamBase, $CONFIG{TV_EXT}, $CHAN_WANTED), text => gettext('Selected channels') },
                        { url => sprintf("%s%s?aktion=export_channels_m3u&amp;wanted=%d", $MyStreamBase, $CONFIG{TV_EXT}, $CHAN_TV), text => gettext('TV channels') },
                        { url => sprintf("%s%s?aktion=export_channels_m3u&amp;wanted=%d", $MyStreamBase, $CONFIG{TV_EXT}, $CHAN_RADIO), text => gettext('Radio channels') }
                      );

    my $vars = {
        url         => sprintf("%s?aktion=vdr_cmds", $MyURL),
        commands    => \@vdrcmds,
        show_output => \@show_output,
        max_lines => $CONFIG{CMD_LINES},
        svdrp_cmd => $svdrp_cmd,
        vdr_cmd   => $q->param("vdr_cmd")   ? $q->param("vdr_cmd")   : undef,
        export_cmds => \@export_cmds
    };
    return showTemplate("vdr_cmds.html", $vars);
}

sub run_vdrcmd {
    my $id        = $q->param("vdr_cmd");
    my $max_lines = $q->param("max_lines");
    return unless (defined($id) && $id =~ /^\d+$/);
    my $counter = 1;
    my $cmd     = ${vdrcmds}[$id]{cmd};
    my @output;
    open(FH, "$cmd |") or return;
    while (<FH>) {
        chomp;
        push(@output, { line => $_ });
        last if ($max_lines > 0 && $counter >= $max_lines);
        $counter++;
    }
    close(FH);
    return @output;
}

sub run_svdrpcmd {
    my $id        = $q->param("svdrp_cmd");
    my $max_lines = $q->param("max_lines");
    return unless ($id);
    my $counter = 1;
    my @output;
    for (SendCMD(scalar $q->param("svdrp_cmd"))) {
        push(@output, { line => $_ });
        last if ($max_lines > 0 && $counter >= $max_lines);
        $counter++;
    }
    return @output;
}

sub export_channels_m3u {
    my $wanted = $q->param("wanted");
    my @filenames = ( 'vdr_full_channels', 'vdr_selected_channels', 'vdr_tv_channels', 'vdr_radio_channels' );

    my $url = streamdevURI();

    my $data = "";
    foreach (sort({ $a->{vdr_id} <=> $b->{vdr_id} } (@{$CHAN{$wanted}->{channels}}))) {
        $url->path($_->{uniq_id});
        $data .= sprintf("#EXTINF:0,%s\n%s\n", $_->{name}, $url);
    }
    return (header("200", $CONFIG{TV_MIMETYPE}, $data, sprintf("%s.%s", $filenames[$wanted], $CONFIG{TV_EXT}) ));
}

#############################################################################
# Authentication
#############################################################################

sub subnetcheck { #TODO: IPv6 support
    my $ip   = $_[0];
    my $nets = $_[1];
    my ($ip1, $ip2, $ip3, $ip4, $net_base, $net_range, $net_base1, $net_base2, $net_base3, $net_base4, $bin_ip, $bin_net);

    ($ip1, $ip2, $ip3, $ip4) = split(/\./, $ip);
    $bin_ip  = unpack("B*", pack("C", $ip1));
    $bin_ip .= unpack("B*", pack("C", $ip2));
    $bin_ip .= unpack("B*", pack("C", $ip3));
    $bin_ip .= unpack("B*", pack("C", $ip4));

    for my $net (split(/[\s,]+/, $nets)) {
        ($net_base, $net_range) = split(/\//, $net);
        ($net_base1, $net_base2, $net_base3, $net_base4) = split(/\./, $net_base);

        $bin_net  = unpack("B*", pack("C", $net_base1));
        $bin_net .= unpack("B*", pack("C", $net_base2));
        $bin_net .= unpack("B*", pack("C", $net_base3));
        $bin_net .= unpack("B*", pack("C", $net_base4));

        return 1 if substr($bin_ip, 0, $net_range) eq substr($bin_net, 0, $net_range);
    }
    return 0;
}

#############################################################################
# communication with vdr
#############################################################################
package SVDRP;

sub true ()       { main::true(); }
sub false ()      { main::false(); }
sub LOG_DEBUG ()  { main::LOG_DEBUG(); }
sub CRLF ()       { main::CRLF(); }

my ($SOCKET, $query, $connected, $VDR_ENCODING, $need_recode);

sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = {};
    bless($self, $class);
    $connected = false;
    $query     = false;
    $VDR_ENCODING = '';
    $need_recode = 0;
    return $self;
}

sub myconnect {
    my $this = shift;
    main::Log(LOG_DEBUG, "[SVDRP] Connecting to $CONFIG{VDR_HOST}:$CONFIG{VDR_PORT}");

    my $connect_error = undef;
    $SOCKET =
      $VdrSocketModule->new(PeerAddr => $CONFIG{VDR_HOST},
                             PeerPort => $CONFIG{VDR_PORT},
                             Proto    => 'tcp'
      );
    my $line;
    if ($SOCKET) {
        chomp($line = <$SOCKET>);
        main::Log(LOG_DEBUG, sprintf("[SVDRP] Read \"%s\"", $line));
        if ($line =~ /access\s+denied/i) {
            # Blocked by svdrphosts.conf - VDR will close the connection
            $this->close();
            $connect_error = $line;
        }
    }
    else {
        $connect_error = "$@";
    }

    if (defined($connect_error)) {
        main::Log(main::LOG_WARNING, sprintf("Connection to %s:%s failed: %s",
                                             $CONFIG{VDR_HOST},
                                             $CONFIG{VDR_PORT},
                                             $connect_error));
        main::HTMLError(sprintf($ERROR_MESSAGE{connect_failed},
                                $CONFIG{VDR_HOST}, $CONFIG{VDR_PORT},
                                CGI::escapeHTML($connect_error)))
                        if $Client && $Client->connected;
        return 0;
    }

    $connected = true;

    if (!$FEATURES{VDRVERSION}) {
        $line =~ /^220.*VideoDiskRecorder (\d+)\.(\d+)\.(\d+)([^;]*);/;
        $FEATURES{VDRVERSION_HR} = "$1.$2.$3$4";
        $FEATURES{VDRVERSION}    = ($1 * 10000 + $2 * 100 + $3);
        getSupportedFeatures($this);
    }
    $line =~ /^220.*VideoDiskRecorder (\d+)\.(\d+)\.(\d+).*; .*; (.*)\r|$/;
    $VDR_ENCODING = $4;
    $need_recode = ($can_use_encode and $VDR_ENCODING and $VDR_ENCODING ne $MY_ENCODING) ? 1 : 0;

    return 1;
}

sub getSupportedFeatures {
    my $this = shift;
    if ($FEATURES{VDRVERSION} >= 10331) {
        command($this, "plug");
        while ($_ = readoneline($this)) {
            if (/^epgsearch v(\d+)\.(\d+)\.(\d+)([^ ]*)/) {
                $FEATURES{EPGSEARCH} = 1;
                $FEATURES{EPGSEARCH_VERSION}    = ($1 * 10000 + $2 * 100 + $3);
                $FEATURES{EPGSEARCH_VERSION_HR} = "$1.$2.$3$4";
            }
            elsif (/^streamdev-server(?:\s+v(\S+))?/) {
                $FEATURES{STREAMDEV} = 1;
                $FEATURES{STREAMDEV_VERSION_HR} = $1;
            }
            elsif (/^xineliboutput(?:\s+v(\S+))?/) {
                $FEATURES{XINELIB} = 1;
                $FEATURES{XINELIB_VERSION_HR} = $1;
            }
        }
    }
    $FEATURES{LIVESTREAM} = $FEATURES{STREAMDEV} || $FEATURES{XINELIB};
    command($this, "help");
    while ($_ = readoneline($this)) {
        if ($_ =~ /\s(RENR|MOVR)\s/) {
            $FEATURES{REC_RENAME} = $1;
        }
    }
}

sub close {
    my $this = shift;
    if ($connected) {
        main::Log(LOG_DEBUG, "[SVDRP] Closing connection");
        command($this, "quit");
        readoneline($this);
        close $SOCKET if $SOCKET;
        $connected = false;
    }
}

sub command {
    my $this = shift;
    my $cmd  = join("", @_);

    if (!$connected) {
        myconnect($this) or return;
    }

    main::Log(LOG_DEBUG, sprintf("[SVDRP] Sending \"%s\"", $cmd));
    $cmd = $cmd . CRLF;
    if ($SOCKET && $SOCKET->connected()) {
        Encode::from_to($cmd, $MY_ENCODING, $VDR_ENCODING) if ($need_recode);
        my $result = send($SOCKET, $cmd, 0);
        if ($result != length($cmd)) {
            main::HTMLError(sprintf($ERROR_MESSAGE{send_command}, $CONFIG{VDR_HOST}));
        } else {
            $query = true;
        }
    }
}

sub readoneline {
    my $this = shift;
    my $line;

    if ($SOCKET && $SOCKET->connected() && $query) {
        $line = <$SOCKET>;
        $line =~ s/\r\n$//;
        if (substr($line, 3, 1) ne "-") {
            $query = 0;
        }
        $line = substr($line, 4, length($line));
        Encode::from_to($line, $VDR_ENCODING, $MY_ENCODING) if ($need_recode);
        main::Log(LOG_DEBUG, sprintf("[SVDRP] Read \"%s\"", $line));
        return ($line);
    } else {
        return undef;
    }
}

sub readresponse {
    my $this = shift;
    my @a = ();
    if($connected) {
        while (<$SOCKET>) {
            chomp;
            my $end = substr($_, 3, 1) ne "-";
            $_ = substr($_, 4, length($_));
            Encode::from_to($_, $VDR_ENCODING, $MY_ENCODING) if ($need_recode);
            push(@a, $_);
            last if ($end);
        }
    }
    return \@a;
}

sub socket {
    return $SOCKET;
}

sub encoding {
    return $VDR_ENCODING;
}

#
#############################################################################

# Local variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# perl-indent-level: 4
# tab-width: 4
# End:

# EOF
