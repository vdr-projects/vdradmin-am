#!/usr/bin/perl

#
# vdradmin.pl by Thomas Koch <tom@linvdr.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
# Or, point your browser to http://www.gnu.org/copyleft/gpl.html
#
# 08.10.2001
#


my $BASENAME;
BEGIN {
	$0 =~ /(^.*\/)/;
	$BASENAME = $1;
	unshift(@INC, "/usr/share/vdradmin/lib");
	unshift(@INC, $BASENAME . "lib/");
}

require File::Temp;

use CGI qw(:no_debug);
use IO::Socket;
use HTML::Template::Expr();
use Template;
use Time::Local qw(timelocal);
use POSIX ":sys_wait_h", qw(strftime mktime);
use MIME::Base64();
use File::Temp();

$SIG{CHLD} = sub { wait };

use strict;
#use warnings;

#my $SEARCH_FILES_IN_SYSTEM = (-d '/usr/share/vdradmin/lib' ? 1 : 0); # for distribution
my $SEARCH_FILES_IN_SYSTEM = 0;

sub true           () { 1 };
sub false          () { 0 };
sub CRLF           () { "\r\n" };
sub LOG_ACCESS     () { 1 };
sub LOG_SERVERCOM  () { 2 };
sub LOG_VDRCOM     () { 4 };
sub LOG_STATS      () { 8 };
sub LOG_AT         () { 16 };
sub LOG_CHECKTIMER () { 32 };
sub LOG_FATALERROR () { 64 };
sub LOG_DEBUG      () { 32768 };

my %CONFIG;
$CONFIG{VDR_HOST}         = "localhost";
$CONFIG{VDR_PORT}         = 2001;
$CONFIG{USERNAME}         = "linvdr";
$CONFIG{PASSWORD}         = "linvdr";
$CONFIG{GUEST_ACCOUNT}    = 0;
$CONFIG{LANGUAGE}         = "Deutsch";
$CONFIG{LOGLEVEL}         = 81; # 32799
$CONFIG{CACHE_TIMEOUT}    = 60;
$CONFIG{LOCAL_NET}        = "0.0.0.0/32";
$CONFIG{CACHE_LASTUPDATE} = 0;
$CONFIG{AT_FUNC}          = 1;
$CONFIG{AT_TIMEOUT}       = 120;
$CONFIG{AT_LIFETIME}      = 99;
$CONFIG{AT_PRIORITY}      = 99;
$CONFIG{TM_LIFETIME}      = 99;
$CONFIG{TM_PRIORITY}      = 99;
$CONFIG{TM_MARGIN_BEGIN}  = 10;
$CONFIG{TM_MARGIN_END}    = 10;
$CONFIG{ST_FUNC}          = 1;
$CONFIG{ST_URL}           = "";
$CONFIG{LOGINPAGE}        = 0;
$CONFIG{LOGGING}          = 0;
$CONFIG{MOD_GZIP}         = 0;
#
$CONFIG{LOGFILE}          = "vdradmind.log";
$CONFIG{SERVERPORT}       = 8001;
$CONFIG{RECORDINGS}       = 1;
$CONFIG{ZEITRAHMEN}       = 1;
$CONFIG{TIMES}       	    = '18:00, 20:00, 21:00, 22:00';
$CONFIG{EPG_DIRECT}       = 1;
$CONFIG{EPG_FILENAME}     = "/video/epg.data";
$CONFIG{SKIN}             = 'bilder';

my $VERSION               = "0.97-am2a";
my $SERVERVERSION         = "vdradmind/$VERSION";
my $VIDEODIR              = "/video";
my $DONE                  = &DONE_Read || {};

my($TEMPLATEDIR, $CONFFILE, $LOGFILE, $PIDFILE, $AT_FILENAME, $DONE_FILENAME, $BL_FILENAME);
if(!$SEARCH_FILES_IN_SYSTEM) {
	$TEMPLATEDIR           = "${BASENAME}template";
	$CONFFILE              = "${BASENAME}vdradmind.conf";
	$LOGFILE               = "${BASENAME}$CONFIG{LOGFILE}";
	$PIDFILE               = "${BASENAME}vdradmind.pid";
	$AT_FILENAME           = "${BASENAME}vdradmind.at";
	$DONE_FILENAME         = "${BASENAME}vdradmind.done";
	$BL_FILENAME         = "${BASENAME}vdradmind.bl";
} else {
	$TEMPLATEDIR           = "/usr/share/vdradmin/template";
	$CONFFILE              = "/etc/vdradmin/vdradmind.conf";
	$LOGFILE               = "/var/log/$CONFIG{LOGFILE}";
	$PIDFILE               = "/var/run/vdradmind.pid";
	$AT_FILENAME           = "/etc/vdradmin/vdradmind.at";
	$DONE_FILENAME         = "/etc/vdradmin/vdradmind.done";
	$BL_FILENAME         = "/etc/vdradmin/vdradmind.bl";
}

# IMHO a better Template Modul ;-)
# some useful options (see below for full list)
my $Xconfig = {
  START_TAG    => '\<\?\%',		 # Tagstyle
  END_TAG      => '\%\?\>',		 # Tagstyle
  INCLUDE_PATH => $TEMPLATEDIR,  	 # or list ref
  INTERPOLATE  => 1,               # expand "$var" in plain text
  PRE_CHOMP    => 1,               # cleanup whitespace
  POST_CHOMP   => 1,               # cleanup whitespace
  EVAL_PERL    => 1,               # evaluate Perl code blocks
  CACHE_SIZE   => 10000,           # Tuning for Templates
  COMPILE_EXT  => 'cache',         # Tuning for Templates 
  COMPILE_DIR  => '/tmp',          # Tuning for Templates

};

# create Template object
my $Xtemplate = Template->new($Xconfig);
# ---- End new template section ----

my $I18NFILE							= "i18n.pl";
my $USE_SHELL_GZIP        = false; # set on false to use the gzip library

if($CONFIG{MOD_GZIP}) {
  # lib gzipping
  use Compress::Zlib;
}

my($DEBUG) = 0;
my(%EPG, @CHAN, $q, $ACCEPT_GZIP, $SVDRP, $HOST);
my(%mimehash) = (
  html => "text/html",
  png  => "image/png",
  gif  => "image/gif",
  jpg  => "image/jpeg",
	css  => "text/css",
  ico  => "image/x-icon",
  js   => "application/x-javascript",
  swf  => "application/x-shockwave-flash"
);
my @LOGINPAGES = qw(prog_list prog_list2 prog_summary prog_timeline timer_list rec_list);


$SIG{INT} = \&Shutdown;
$SIG{TERM} = \&Shutdown;
$SIG{HUP} = \&HupSignal;
$SIG{PIPE} = 'IGNORE';

#
my $DAEMON = 1;
for(my $i = 0; $i < scalar(@ARGV); $i++) {
  $_ = $ARGV[$i];
  if(/-h|--help/) {
    print("Usage $0 [OPTION]...\n");
    print("A perl client for the Linux Video Disk Recorder.\n\n");
    print("  -nf  --nofork   don't fork\n");
    print("  -c   --config   run configuration dialog\n");
    print("  -k   --kill     kill a fork'ed vdradmin\n");
    print("  -h   --help     this here\n");
    print("\nReport bugs to <vdradmin\@linvdr.org>.\n");
    exit(0);
  }
  if(/--nofork|-nf/) { $DAEMON = 0; last; }
  if(/--config|-c/) {
    $CONFIG{VDR_HOST} = Question("What's your VDR hostname (e.g video.intra.net)?", "localhost");
    $CONFIG{VDR_PORT} = Question("What's the port VDR listen to SVDRP query's?", "2001");
    $CONFIG{SERVERHOST} = Question("On which address should vdradmin listen (0.0.0.0 for any)?", "0.0.0.0");
    $CONFIG{SERVERPORT} = Question("On which port should vdradmin answer?", "8001");
    $CONFIG{USERNAME} = Question("Username?", "linvdr");
    $CONFIG{PASSWORD} = Question("Password?", "linvdr");
    $CONFIG{EPG_FILENAME} = Question("Where is your epg.data?", "/video/epg.data");
    $CONFIG{EPG_DIRECT} = ($CONFIG{EPG_FILENAME} and -e $CONFIG{EPG_FILENAME} ? 1 : 0);

    open(CONF, ">$CONFFILE") || die "Cannot open $CONFFILE: $!\n";
    for(keys(%CONFIG)) {
      print(CONF "$_ = $CONFIG{$_}\n");
    }
    close(CONF);

    print("Config file sucessfull written.\n");
    exit(0);
  }
  if(/--kill|-k/) {
    kill(2, getPID($PIDFILE));
    unlink($PIDFILE);
    exit(0);
  }
  if(/--displaycall|-i/) {
    for(my $z = 0; $z < 5; $z++) {
      DisplayMessage($ARGV[$i+1]);
      sleep(3);
    }
    CloseSocket();
    exit(0);
  }
  if(/--message|-m/) {
    DisplayMessage($ARGV[$i+1]);
    CloseSocket();
    exit(0);
  }
}

ReadConfig();


if(-e "$PIDFILE") {
	print "There's already an copy of this program running! (pid: " . getPID($PIDFILE) . ")\n";
	print "If you feel this is a error, remove $PIDFILE!\n";
	exit(0);
}

if($DAEMON) {
  my($pid) = fork;
  if($pid != 0) {
    print("vdradmind.pl $VERSION started with pid $pid.\n");
    writePID($pid);
    exit(0);
  }
}


my($Socket) = IO::Socket::INET->new(
  Proto => 'tcp',
  LocalPort => $CONFIG{SERVERPORT},
  LocalAddr => $CONFIG{SERVERHOST},
  Listen => 10,
  Reuse => 1
);
die("can't start server: $!\n") if (!$Socket);
$Socket->timeout($CONFIG{AT_TIMEOUT} * 60) if($CONFIG{AT_FUNC});
$CONFIG{CACHE_LASTUPDATE} = 0;

#
my(@I18N_Days, @I18N_Month, %ERRORMESSAGE, %COMMONMESSAGE,
	@LOGINPAGES_DESCRIPTION, %HELP);
LoadTranslation();

UptoDate();

##
# Mainloop
##
my($Client, $MyURL, $Referer, $Request, $Query, $Guest);
my @GUEST_USER = qw(prog_detail prog_list prog_list2 prog_timeline timer_list at_timer_list
	prog_summary rec_list rec_detail show_top toolbar show_help);
my @TRUSTED_USER = (@GUEST_USER, qw(at_timer_edit at_timer_new at_timer_save
  at_timer_delete timer_new_form timer_add timer_delete timer_toggle rec_delete rec_rename rec_edit
  conf_list prog_switch rc_show rc_hitk grab_picture at_timer_toggle tv_show
	live_stream rec_stream force_update));

# Force Update at start
UptoDate(1);


while(true) {
  $Client = $Socket->accept();
	
	#
	if(!$Client) {
		UptoDate(1);
		next;
	}
	
	my $peer = $Client->peerhost;	
	my @Request = ParseRequest($Client);
	my $raw_request = $Request[0];	
	
	$ACCEPT_GZIP = 0;
	
  if($raw_request =~ /^GET (\/[\w\.\/-\:]*)([\?[\w=&\.\+\%-\:\!]*]*)[\#\d ]+HTTP\/1.\d$/) {
		($Request, $Query) = ($1, $2 ? substr($2, 1, length($2)) : undef);
	} else {
    Error("404", "Not Found", "The requested URL /bad_request was not found on this server.");
    close($Client);
		next;
	}
	
	# parse header
	my($username, $password, $http_useragent);
	for my $line (@Request) {
		if($line =~ /Referer: (.*)/) {
			$Referer = $1;
		}
		if($line =~ /Host: (.*)/) {
			$HOST = $1;
		}
		if($line =~ /Authorization: basic (.*)/i) {
			($username, $password) = split(":", MIME::Base64::decode_base64($1), 2);
		}
		if($line =~ /User-Agent: (.*)/i) {
			$http_useragent = $1;
		}
		if($line =~ /Accept-Encoding: (.*)/i) {
			if($1 =~ /gzip/) {
				$ACCEPT_GZIP = 1;
			}
		}
	}
				
	# authenticate
	if(($CONFIG{USERNAME} eq $username && $CONFIG{PASSWORD} eq $password) || subnetcheck($peer,$CONFIG{LOCAL_NET}) ) {
		$Guest = 0;
	} elsif(($CONFIG{USERNAME_GUEST} eq $username && $CONFIG{PASSWORD_GUEST} eq $password) && $CONFIG{GUEST_ACCOUNT}) {
		$Guest = 1;
	} else {
		headerNoAuth();
    close($Client);
		next;
	}
		
	
	# serve request
	$SVDRP = SVDRP->new;
	my ($http_status, $bytes_transfered);
	$MyURL = "." . $Request;
	if($Request eq "/vdradmin.pl") { 
		$q = CGI->new($Query);
		my $aktion;
		
		my @ALLOWED_FUNCTIONS;
		$Guest ? (@ALLOWED_FUNCTIONS = @GUEST_USER) : (@ALLOWED_FUNCTIONS = @TRUSTED_USER);

		for(@ALLOWED_FUNCTIONS) {
			($aktion = $q->param("aktion")) if($q->param("aktion") eq $_);
		}
		if($aktion) {
			eval("(\$http_status, \$bytes_transfered) = $aktion();");
		} else {
			# XXX redirect to no access template 
      Error("403", "Forbidden", "You don't have permission to access this function.");
			next;
		}
	} elsif($Request eq "/") {
		$MyURL = "./vdradmin.pl";
		($http_status, $bytes_transfered) = show_index();
	} else {
    ($http_status, $bytes_transfered) = SendFile($Request);
	}
  Log(LOG_ACCESS, access_log($Client->peerhost, $username, time(), $raw_request, 
    $http_status, $bytes_transfered, $Request, $http_useragent));
  close($Client);
  $SVDRP->close;
}

#############################################################################
#############################################################################
sub GetChannelDesc {
  my(%hash);
  for(@CHAN) {
    $hash{$_->{id}} = $_->{name};
  }
  return(%hash);
}

sub GetChannelDescByNumber {
  my $vdr_id = shift;

  if($vdr_id) {
    for(@CHAN) {
      if($_->{vdr_id} == $vdr_id) {
				return($_->{name});
      }
    }
  } else { return(0); }
}

sub include {
	my $file = shift;
	if($file) {
		eval(ReadFile($file));
	}
}

sub ReadFile {
  my $file = shift;
  return if(!$file);

  open(I18N, $file) || HTMLError("Cannot open $file!");
	my $buf = join("", <I18N>);
	close(I18N);
  return($buf);
}

sub FullDay {
  return($I18N_Days[shift]);
}

sub FullMonth {
  return($I18N_Month[shift()-1]);
}

sub GetChannelID {
  my($sid) = $_[0];
  for(@CHAN) {
    if($_->{id} == $sid) {
      return($_->{number});
    }
  }
}

sub EURL {
  my($text) = @_;
  $text =~ s/([^0-9a-zA-Z])/sprintf("%%%2.2x", ord($1))/ge;
  return($text);
}

sub HTMLError {
  my $error = join("", @_);
  my $template = HTML::Template->new(
    filename => "$TEMPLATEDIR/$CONFIG{LANGUAGE}/error.html");
  $template->param(error => $error);
	$CONFIG{CACHE_LASTUPDATE} = 0;
  return(header("200", "text/html", $template->output));
}


sub FillInZero {
  my($str, $length) = @_;
  while(length($str) < $length) {
    $str = "0$str";
  }
  return($str);
}

sub MHz {
	my $frequency = shift;
	while($frequency > 20000) {
		$frequency /= 1000;
	}
	return(int($frequency));
}

sub ChanTree {
  undef(@CHAN);
	$SVDRP->command("lstc");
  while($_ = $SVDRP->readoneline) {
    chomp;
    my($vdr_id, $temp) = split(/ /, $_, 2);
    my($name, $frequency, $polarization, $source, $symbolrate, $vpid, $apid,
      $tpid, $ca, $service_id, $nid, $tid, $rid) = split(/\:/, $temp);
    $name =~ /(^[^,;]*).*/;	#TODO?
    $name = $1;
    push(@CHAN, {
      vdr_id       => $vdr_id,
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
		  rid          => $rid
    });
  }
}

sub get_vdrid_from_channelid {
	my $channel_id = shift;
	if($channel_id =~ /^(\d*)$/) { # vdr 1.0.x & >= vdr 1.1.15
		for my $channel (@CHAN) {
			if($channel->{service_id} == $1) {
				return($channel->{vdr_id});
			}
		}
	} elsif($channel_id =~ /^(.*)-(.*)-(.*)-(.*)-(.*)$/) {
		for my $channel (@CHAN) {
			if($channel->{source} eq $1 &&
			   $channel->{nid} == $2 &&
			   ($channel->{nid} ? $channel->{tid} : $channel->{frequency}) == $3 &&
			   $channel->{service_id} == $4 &&
			   $channel->{rid} == $5) {
				return($channel->{vdr_id});
			}
		}
	} elsif($channel_id =~ /^(.*)-(.*)-(.*)-(.*)$/) {
		for my $channel (@CHAN) {
			if($channel->{source} eq $1 &&
			   $channel->{nid} == $2 &&
			   ($channel->{nid} ? $channel->{tid} : $channel->{frequency}) == $3 &&
			   $channel->{service_id} == $4) {
				return($channel->{vdr_id});
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
  if($vdr_id) {
    my @C = grep($_->{vdr_id} == $vdr_id, @CHAN);
    if(scalar(@C) == 1) {
      my $ch = $C[0];
      return $ch->{source} . "-" . $ch->{nid} . "-" . ($ch->{nid}||$ch->{tid}?$ch->{tid}:$ch->{frequency}) . "-" . $ch->{service_id};
    }
  }
}

sub get_name_from_vdrid {
  my $vdr_id = shift;
  if($vdr_id) {
    # Kanalliste nach identischer vdr_id durchsuchen
    my @C = grep($_->{vdr_id} == $vdr_id, @CHAN);
    # Es darf nach Spec nur eine ‹bereinstimmung geben
    if(scalar(@C) == 1) {
      return $C[0]->{name};
    }
  }
}

sub get_transponder_from_vdrid {
  my $vdr_id = shift;
  if($vdr_id) {
    # Kanalliste nach identischer vdr_id durchsuchen
    my @C = grep($_->{vdr_id} == $vdr_id, @CHAN);
    # Es darf nach Spec nur eine ‹bereinstimmung geben
    if(scalar(@C) == 1) {
      return("$C[0]->{source}-$C[0]->{frequency}-$C[0]->{polarization}");
    }
  }
}

sub get_ca_from_vdrid {
  my $vdr_id = shift;
  if($vdr_id) {
    # Kanalliste nach identischer vdr_id durchsuchen
    my @C = grep($_->{vdr_id} == $vdr_id, @CHAN);
    # Es darf nach Spec nur eine ‹bereinstimmung geben
    if(scalar(@C) == 1) {
      return($C[0]->{ca});
    }
  }
}

#############################################################################
# EPG functions
#############################################################################

sub EPG_getEntry {
	my $vdr_id = shift;
	my $epg_id = shift;
	if($vdr_id && $epg_id) {
		for(@{$EPG{$vdr_id}}) {
			#if($_->{id} == $epg_id) {
      if($_->{event_id} == $epg_id) {
				return($_);
			}
		}
	}
}

sub getNumberOfElements {
	my $ref = shift;
	if($ref) {
		return(@{$ref});
	} else {
		return(0);
	}
}

sub getElement {
	my $ref = shift;
	my $index = shift;
	if($ref) {
		return($ref->[$index]);
	} else {
		return;
	}
}

sub EPG_buildTree {
	$SVDRP->command("lste");
  my($i, @events);
	my($id, $bc) = (1, 0);
  undef(%EPG);
	while($_ = $SVDRP->readoneline) {
    chomp;
    if(/^C ([^ ]+) *(.*)/) {
      $bc++;
      undef(@events);
      my($channel_id, $channel_name) = ($1, $2);
			my $vdr_id = get_vdrid_from_channelid($channel_id);
			while($_ = $SVDRP->readoneline) {
				if(/^E (.*) (.*) (.*) (.*)/ || /^E (.*) (.*) (.*)/) {
					my($event_id, $time, $duration) = ($1, $2, $3);
					my($title, $subtitle, $summary);
					while($_ = $SVDRP->readoneline) {
#            if(/^T (.*)/) { $title = $1;    $title =~ s/\|/<br>/sig }
#            if(/^S (.*)/) { $subtitle = $1; $subtitle =~ s/\|/<br>/sig }
#            if(/^D (.*)/) { $summary = $1;  $summary =~ s/\|/<br>/sig }
            if(/^T (.*)/) { $title = $1; }
            if(/^S (.*)/) { $subtitle = $1; }
            if(/^D (.*)/) { $summary = $1; }
						if(/^e/) {
							#
							push(@events, {
								channel_name => $channel_name,
								start        => $time,
								stop         => $time + $duration,
								duration     => $duration,
								title        => $title,
								subtitle     => $subtitle,
								summary      => $summary,
								id           => $id,
								vdr_id       => $vdr_id,
								event_id     => $event_id
							});
							$id++;
							last;
						}
					}
				} elsif(/^c/) {
					my($last) = 0;
					my(@temp);
					for(sort({ $a->{start} <=> $b->{start} } @events)) {
						next if($last == $_->{start});
						push(@temp, $_);
						$last = $_->{start};
					}
					$EPG{$vdr_id} = [ @temp ];
					last;
				}
			}
    }
  }
  Log(LOG_STATS, "EPGTree: $id events, $bc broadcasters");
}


#############################################################################
# Socket functions
#############################################################################

sub PrintToClient {
  my $string = join("", @_);
  return if(!defined($string));
  print($Client $string) if($Client);
}

sub ParseRequest {
	my $Socket = shift;
	my (@Request, $Line);
	do {
		$Line = <$Socket>;
		$Line =~ s/\r\n//g;
		push(@Request, $Line);
	} while($Line);
	return(@Request);
}

sub CloseSocket {
	$SVDRP->close();
}

sub OpenSocket {
	$SVDRP = SVDRP->new;
}

sub SendCMD {
  my $cmd = join("", @_);

  OpenSocket() if(!$SVDRP);

	my @output;
	$SVDRP->command($cmd);
	while($_ = $SVDRP->readoneline) {
		push(@output, $_);
	}
  return(@output);
}

sub mygmtime() {
	gmtime;
}

sub headerTime {
	my $time = shift;
	$time = time() if(!$time);
  my @weekdays = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun");
  my @months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");	     
	
  return(
		sprintf("%s, %s %s %s %02d:%02d:%02d GMT",
			$weekdays[my_strfgmtime("%w", $time)],
			my_strfgmtime("%d", $time),
			$months[my_strfgmtime("%m", $time) - 1],
			my_strfgmtime("%Y", $time),
			my_strfgmtime("%H", $time),
			my_strfgmtime("%M", $time),
			my_strfgmtime("%S", $time)
		)
	);
}

sub GZip {
	my $content = shift;
  my $filename = new File::Temp("vdradmin-XXXXX", UNLINK => 1);
  open(PIPE, "| gzip -9 - > $filename") || die "cant open pipe to gzip ($!)";
  print PIPE $$content;
  close(PIPE);

  open(FILE, $filename) || die "cant open $filename ($1)";
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
  
	return($result);
}

sub LibGZip {
	my $content = shift;
	return(Compress::Zlib::memGzip($$content));
}

sub header {
	my($status, $ContentType, $data, $caching) = @_;
  Log(LOG_STATS, "Template Error: ".$Xtemplate->error())
    if($status >= 500);
	if($ACCEPT_GZIP && $CONFIG{MOD_GZIP}) {
		if($USE_SHELL_GZIP) {
			$data = GZip(\$data);
		} else {
			$data = LibGZip(\$data);
		}
	}

	my $status_text = " OK" if($status eq "200");

  PrintToClient("HTTP/1.0 $status$status_text", CRLF);
  PrintToClient("Date: ", headerTime(), CRLF);
	if(!$caching) {
		PrintToClient("Expires: Mon, 26 Jul 1997 05:00:00 GMT", CRLF);
		PrintToClient("Cache-Control: max-age=0", CRLF);
	} else {
		PrintToClient("Expires: ", headerTime(time() + 3600), CRLF);
		PrintToClient("Cache-Control: max-age=3600", CRLF);
	}
  PrintToClient("Server: $SERVERVERSION", CRLF);
  PrintToClient("Content-Length: ", length($data), CRLF) if($data);
  PrintToClient("Connection: close", CRLF);
	PrintToClient("Content-encoding: gzip", CRLF) if($CONFIG{MOD_GZIP} && $ACCEPT_GZIP);
  PrintToClient("Content-type: $ContentType", CRLF, CRLF) if($ContentType);
  PrintToClient($data) if($data);
	return($status, length($data));
}

sub headerForward {
  my $url = shift;
  PrintToClient("HTTP/1.0 302 Found", CRLF);
  PrintToClient("Date: ", headerTime(), CRLF);
  PrintToClient("Server: $SERVERVERSION", CRLF);
  PrintToClient("Connection: close", CRLF);
  PrintToClient("Location: $url", CRLF);
  PrintToClient("Content-type: text/html", CRLF, CRLF);
	return(302, 0);
}

sub headerNoAuth {
  my $template = TemplateNew("noauth.html");
	my $data = $template->output;
  PrintToClient("HTTP/1.0 401 Authorization Required", CRLF);
  PrintToClient("Date: ", headerTime(), CRLF);
  PrintToClient("Server: $SERVERVERSION", CRLF);
  PrintToClient("WWW-Authenticate: Basic realm=\"vdradmind\"", CRLF);
  PrintToClient("Content-Length: ", length($data), CRLF) if($data);
  PrintToClient("Connection: close", CRLF);
  PrintToClient("Content-type: text/html", CRLF, CRLF);
  PrintToClient($data);
  return(401, length($data));
}

sub Error {
	my $template = HTML::Template->new(
		filename => "$TEMPLATEDIR/$CONFIG{LANGUAGE}/noperm.html");
	$template->param(
		title => $_[0],
		h1    => $_[1],
		error => $_[2],
	);
	return(header("$_[0] $_[1]", "text/html", $template->output));
}

sub SendFile {
  my($File) = @_;
  my($buf, $temp);
  $File =~ s/^\///;
  $File =~ s/^bilder/$CONFIG{SKIN}/i
    if(defined $CONFIG{SKIN});
	my $FileWithPath = sprintf("%s/%s/%s",
#	my $FileWithPath = sprintf("%s/%s/%s/%s",
#		$BASENAME,
		$TEMPLATEDIR,
		$CONFIG{LANGUAGE},
		$File);

  # Skin css file
  $FileWithPath = sprintf('%s/%s/%s/%s', $TEMPLATEDIR, $CONFIG{LANGUAGE}, $CONFIG{SKIN}, $File)
    if((split('[/\.]',$File))[-1] eq 'css' and -e sprintf('%s/%s/%s/%s', $TEMPLATEDIR, $CONFIG{LANGUAGE}, $CONFIG{SKIN}, $File));

  if(-e $FileWithPath) {
    if(-r $FileWithPath) {
      $buf = ReadFile($FileWithPath);
			$temp = $File;
      $temp =~ /([A-Za-z0-9]+)\.([A-Za-z0-9]+)/;
      if(!$mimehash{$2}) { die("can't find mime-type \'$2\'\n"); }
      return(header("200", $mimehash{$2}, $buf, 1));
    } else {
      Error("403", "Forbidden", "You don't have permission to access /$File on this server.");
    }
  } else {
    Error("404", "Not Found", "The requested URL /$File was not found on this server.");
  }
}

#############################################################################
# autotimer functions
#############################################################################
sub AT_Read {
  my(@at);
  if(-e $AT_FILENAME) {
    open(AT_FILE, $AT_FILENAME) ||
      HTMLError("Cant open $AT_FILENAME!");
    while(<AT_FILE>) {
      chomp;
      next if($_ eq "");
      my($active, $pattern, $section, $start, $stop, $episode, $prio, $lft, $channel, $directory, $done) = split(/\:/, $_);
      my($usechannel) = ($channel =~ /^\d+$/) ? $channel : get_vdrid_from_channelid($channel);
      push(@at, {
        active    => $active,
        pattern   => $pattern,
        section   => $section,
        start     => $start,
        stop      => $stop,
        episode   => $episode,
        prio      => $prio,
        lft       => $lft,
        channel   => $usechannel,
        directory => $directory,
        done      => $done
      });
    }
    close(AT_FILE);
  }
  return(@at);
}

sub AT_Write {
  my @at = @_;
  open(AT_FILE, ">" . $AT_FILENAME) ||
    HTMLError("Cant open $AT_FILENAME!");
  for(@at) {
    my $temp;
    for my $item (qw(active pattern section start stop episode prio lft channel directory done)) {
      $_->{$item} =~ s/\:/_/g;
      my $tempitem = $_->{$item};
      if ($item eq 'channel') {
	my $channelnumber = get_channelid_from_vdrid($tempitem);
	if ($channelnumber) {
	  $tempitem = $channelnumber;
	}
      }
      if(length($temp) == 0) {
        $temp = $tempitem;
      } else {
        $temp .= ":" . $tempitem;
      }
    }
    print AT_FILE $temp, "\n";
  }
  close(AT_FILE);
}

sub DONE_Write {
    my $done = shift || return;
    open(DONE_FILE, ">" . $DONE_FILENAME) || HTMLError("Cant open $DONE_FILENAME!");
    foreach my $n (sort keys %$done) { 
        printf DONE_FILE "%s::%d::%s\n", $n, $done->{$n}, scalar localtime($done->{$n}); 
    };
    close(DONE_FILE);
}

sub DONE_Read {
    my $done;
    if(-e $DONE_FILENAME) {
        open(DONE_FILE, $DONE_FILENAME) || HTMLError("Cant open $AT_FILENAME!");
        while(<DONE_FILE>) {
            chomp;
            next if($_ eq "");
            my @line = split('\:\:', $_);
            $done->{$line[0]} = $line[1];
        }
        close(DONE_FILE);
    }
    return $done;
}

sub BlackList_Read {
    my %blacklist;
    if(-e $BL_FILENAME) {
        open(BL_FILE, $BL_FILENAME) || HTMLError("Cant open $BL_FILENAME!");
        while(<BL_FILE>) {
            chomp;
            next if($_ eq "");
            $blacklist{$_} = 1;
        }
        close(BL_FILE);
    }
    return %blacklist;
}


sub AutoTimer {
  return if(!$CONFIG{AT_FUNC});
  Log(LOG_AT, "Auto Timer: Scanning for events...");
  my($search, $start, $stop) = @_;

  my @at = AT_Read();

  my $oneshots = 0;
  $DONE  = &DONE_Read unless($DONE);
  my %blacklist = &BlackList_Read;

  # Merken der wanted Channels (geht schneller
  # bevor das immer wieder in der unteren Schleife gemacht wird).
  my $wanted;
  for my $n ( split( ",", $CONFIG{CHANNELS_WANTED} ) ) {
    $wanted->{$n} = 1;
  }

  # Die Timerliste holen
  my $timer;
  foreach my $t (ParseTimer(0)){
    my $key = sprintf('%d:%s:%s',
    $t->{vdr_id},
    $t->{title}
    );
    $timer->{$key} = $t;
  }

  for my $sender (keys(%EPG)) {
    for my $event (@{$EPG{$sender}}) {
      for my $at (@at) {
        if(!$at->{active}) {
          next;
        }

        # Ein Timer der schon programmmiert wurde kann
        # ignoriert werden
        next if($event->{event_id} == $timer->{event_id});

        # Wenn CHANNELS_WANTED_AUTOTIMER dann next wenn der Kanal
        # nicht in der WantedList steht
        if($CONFIG{CHANNELS_WANTED_AUTOTIMER}) {
          next unless defined $wanted->{ $event->{vdr_id} };
        }

        if($at->{channel}) {
          if($at->{channel} != $event->{vdr_id}) {
            next;
          }
        }

        # Hamwa schon gehabt?
        my $DoneStr = sprintf('%s~%s', 
          $event->{title}, 
          ($event->{subtitle} ? $event->{subtitle} : ''),
          );
	
        if(exists $DONE->{$DoneStr}) {
          Log(LOG_DEBUG, sprintf("Auto Timer: already done \"%s\"", $DoneStr));
		next;
		}

	# Wollen wir nicht haben.
	my $BLStr = $event->{title};
	$BLStr .= "~" . $event->{subtitle} if $event->{subtitle};
	
        if($blacklist{$BLStr} eq 1 ||  $blacklist{$event->{title}} eq 1) {
          Log(LOG_DEBUG, sprintf("Auto Timer: blacklisted \"%s\"", $event->{title}));
		next;
		}



        my $SearchStr;
        if($at->{section} & 1) {
          $SearchStr = $event->{title};
        }
        if(($at->{section} & 2) && defined($event->{subtitle})) {
          $SearchStr .= "~" . $event->{subtitle};
        }
        if($at->{section} & 4) {
          $SearchStr .= "~" . $event->{summary};
        }

        # Regular Expressions are surrounded by slashes -- everything else
        # are search patterns
        if($at->{pattern} =~ /^\/(.*)\/(i?)$/) {
          # We have a RegExp
          Log(LOG_DEBUG, sprintf("Auto Timer: Checking RegExp \"%s\"", $at->{pattern}));

          if((! length($SearchStr)) || (! length($1))) {
            Log(LOG_DEBUG, "No search string or regexp, skipping!");
            next;
          }

          next if(!defined($1));
          # Shall we search case insensitive?
          if(($2 eq "i") && ($SearchStr !~ /$1/i)) {
            next;
          } elsif(($2 ne "i") && ($SearchStr !~ /$1/)) {
              next;
          } else {
            Log(LOG_AT, sprintf("Auto Timer: RegExp \"%s\" matches \"%s\"", $at->{pattern}, $SearchStr));
          }
        } else {
          # We have a search pattern
          Log(LOG_DEBUG, sprintf("Auto Timer: Checking pattern \"%s\"", $at->{pattern}));

          # Escape special characters within the search pattern
          my $atpattern = $at->{pattern};
          #$atpattern =~ s/([\+\?\.\*\^\$\(\)\[\]\{\}\|\\])/\\\1/g;
          $atpattern =~ s/([\+\?\.\*\^\$\(\)\[\]\{\}\|\\])/\\$1/g;

          Log(LOG_DEBUG, sprintf("Auto Timer: Escaped pattern: \"%s\"", $atpattern));

          if((! length($SearchStr)) || (! length($atpattern))) {
            Log(LOG_DEBUG, "No search string or pattern, skipping!");
            next;
          }
          # split search pattern at spaces into single sub-patterns, and
          # test for all of them (logical "and")
          my $fp = 1;
          for my $pattern (split(/ +/, $atpattern)) {
            # search for each sub-pattern, case insensitive
            if($SearchStr !~ /$pattern/i) {
              $fp = 0;
            } else {
              Log(LOG_DEBUG, sprintf("Auto Timer: Found matching pattern: \"%s\"", $pattern));
            }
          }
          next if(!$fp);
        }

        Log(LOG_DEBUG, sprintf("Auto Timer: Comparing pattern \"%s\" (%s - %s) with event \"%s\" (%s - %s)",
	    $at->{pattern}, $at->{start}, $at->{stop},
	    $event->{title}, my_strftime("%H%M", $event->{start}), my_strftime("%H%M", $event->{stop})));
        # Do we have a time slot?
        if($at->{start}) {
	  # We have a start time and possibly a stop time for the auto timer
          # Do we have Midnight between AT start and stop time?
          if(($at->{stop}) && ($at->{stop} < $at->{start})) {
            # The AT includes Midnight
	    Log(LOG_DEBUG, "922: AT includes Midnight");
            # Do we have Midnight between Event start and stop?
	    if(my_strftime("%H%M", $event->{stop}) < my_strftime("%H%M", $event->{start})) {
	      # The event includes Midnight
	      Log(LOG_DEBUG, "926: Event includes Midnight");
              if(my_strftime("%H%M", $event->{start}) < $at->{start}) {
	        Log(LOG_DEBUG, "924: Event starts before AT start");
                next;
              }
              if(my_strftime("%H%M", $event->{stop}) > $at->{stop}) {
	        Log(LOG_DEBUG, "932: Event ends after AT stop");
                next;
              }
	    } else {
	      # Normal event not spreading over Midnight
	      Log(LOG_DEBUG, "937: Event does not includes Midnight");
              if(my_strftime("%H%M", $event->{start}) < $at->{start}) {
                if(my_strftime("%H%M", $event->{start}) > $at->{stop}) {
		  # The event starts before AT start and after AT stop
	          Log(LOG_DEBUG, "941: Event starts before AT start and after AT stop");
                  next;
		}
                if(my_strftime("%H%M", $event->{stop}) > $at->{stop}) {
		  # The event ends after AT stop
	          Log(LOG_DEBUG, "946: Event ends after AT stop");
                  next;
		}
              }
	    }
          } else {
            # Normal auto timer, not spreading over midnight
	    Log(LOG_DEBUG, "953: AT does not include Midnight");
	    # Is the event spreading over midnight?
	    if(my_strftime("%H%M", $event->{stop}) < my_strftime("%H%M", $event->{start})) {
	      # Event spreads midnight
              if($at->{stop}) {
	        # We have a AT stop time defined before midnight -- no match
	        Log(LOG_DEBUG, "959: Event includes Midnight, Autotimer not");
                next;
              }
	    } else {
	      # We have a normal event, nothing special
              # Event must not start before AT start
              if(my_strftime("%H%M", $event->{start}) < $at->{start}) {
	        Log(LOG_DEBUG, "963: Event starts before AT start");
                next;
	      }
              # Event must not end after AT stop
              if(($at->{stop}) && (my_strftime("%H%M", $event->{stop}) > $at->{stop})) {
	        Log(LOG_DEBUG, "968: Event ends after AT stop");
                next;
	      }
            }
          }
        } else {
          # We have no AT start time
          if($at->{stop}) {
            if(my_strftime("%H%M", $event->{stop}) > $at->{stop}) {
	      Log(LOG_DEBUG, "977: Only AT stop time, Event stops after AT stop");
              next;
            }
	  }
        }

        Log(LOG_AT, sprintf("Auto Timer: Found \"%s\"", $at->{pattern}));

#########################################################################################		
# 20050130: patch by macfly: parse extended EPG information provided by tvm2vdr.pl
#########################################################################################		

	my $title = $event->{title};
	my %at_details;

	if($at->{directory}) {
		$title = $at->{directory};
		$at_details{'title'}		= $event->{title};
		$at_details{'subtitle'}		= $event->{subtitle} ? $event->{subtitle} : my_strftime("%Y-%m-%d", $event->{start});
		$at_details{'date'}		= my_strftime("%Y-%m-%d", $event->{start});
		$at_details{'regie'}		= $1 if $event->{summary} =~ m/\|Director: (.*?)\|/;
		$at_details{'category'}		= $1 if $event->{summary} =~ m/\|Category: (.*?)\|/;
		$at_details{'genre'}		= $1 if $event->{summary} =~ m/\|Genre: (.*?)\|/;
		$at_details{'year'}		= $1 if $event->{summary} =~ m/\|Year: (.*?)\|/;
		$at_details{'country'}		= $1 if $event->{summary} =~ m/\|Country: (.*?)\|/;
		$at_details{'originaltitle'}	= $1 if $event->{summary} =~ m/\|Originaltitle: (.*?)\|/;
		$at_details{'fsk'}		= $1 if $event->{summary} =~ m/\|FSK: (.*?)\|/;
		$at_details{'episode'}		= $1 if $event->{summary} =~ m/\|Episode: (.*?)\|/;
		$at_details{'rating'}		= $1 if $event->{summary} =~ m/\|Rating: (.*?)\|/;
		$title =~ s/%([\w_-]+)%/$at_details{lc($1)}/sieg;
	} else {
		$title = $event->{title};
		if(($at->{episode}) && ($event->{subtitle})) {
			$title .= "~" . $event->{subtitle};
		}
	}


	# gemaess vdr.5 alle : durch | ersetzen.
	$title =~s#:#|#g;

	# sind irgendweche Tags verwendet worden, die leer waren und die doppelte Verzeichnisse erzeugten?
	$title =~s#~+#~#g;

#########################################################################################		
# 20050130: patch by macfly: parse extended EPG information provided by tvm2vdr.pl
#########################################################################################		

        Log(LOG_AT, sprintf("AutoTimer: Programming Timer \"%s\" (Event-ID %s, %s - %s)", $title, $event->{event_id}, strftime("%Y%m%d-%H%M", localtime($event->{start})), strftime("%Y%m%d-%H%M", localtime($event->{stop}))));

        AT_ProgTimer(0x0001, $event->{event_id}, $event->{vdr_id}, $event->{start}, $event->{stop},
          $title, $event->{summary}, $at->{prio}, $at->{lft});

	if ($at->{active} == 2) {
	  Log(LOG_AT, sprintf("AutoTimer: Disabling one-shot Timer"));
	  $at->{active} = 0;
	  $oneshots = 1;
	}
        $DONE->{$DoneStr} = $event->{stop}
          if($at->{done});
      }
    }
  }
  if ($oneshots) {
    Log(LOG_AT, sprintf("AutoTimer: saving because of one-shots triggered"));
    AT_Write(@at);
  }

  Log(LOG_AT, "Auto Timer: Done.");
  Log(LOG_AT, "Auto Timer: Search for old Done Entrys...");
  for(keys %$DONE) { delete $DONE->{$_} if(time > $DONE->{$_}) }
  Log(LOG_AT, "Auto Timer: Save done list...");
  &DONE_Write($DONE) if($DONE);
  Log(LOG_AT, "Auto Timer: Done.");
}


sub AT_ProgTimer {
  my($active, $event_id, $channel, $start, $stop, $title, $summary, $prio, $lft) = @_;

  $title =~ s/\:/ /g;

  $start -= ($CONFIG{TM_MARGIN_BEGIN} * 60);
  $stop += ($CONFIG{TM_MARGIN_END} * 60);

  ($prio = $CONFIG{AT_PRIORITY}) if(!$prio);
  ($lft  = $CONFIG{AT_LIFETIME}) if(!$lft);

  my $found = 0;
  my $Update = 0;
  for(ParseTimer(1)) {
    if(($event_id) && ($_->{event_id} == $event_id) && ($_->{vdr_id} == $channel)) {
      $found = 1;
    }
    if((!$found) && ($_->{vdr_id} == $channel) && ($_->{dor} == my_strftime("%d", $start)) && ($_->{start} eq $start)) {
        $found = 1;
    }
  }

  # we will only programm new timers, CheckTimers is responsible for
  # updating existing timers
  if (!$found) {
    Log(LOG_AT, sprintf("AT_ProgTimer: Programming Timer \"%s\" (Event-ID %s, %s - %s)", $title, $event_id, strftime("%Y%m%d-%H%M", localtime($start)), strftime("%Y%m%d-%H%M", localtime($stop))));
    ProgTimer(
      0,
      $active,
      $event_id,
      $channel,
      $start,
      $stop,
      $prio,
      $lft,
      $title,
      $summary
    );
  }
}

sub PackStatus {
  # make a 32 bit signed int with high 16 Bit as event_id and low 16 Bit as
  # active value
  my($active, $event_id) = @_;

  # we must generate a 32 bit signed int, due perl knows no overflow at 32 bit,
  # we have to do the overflow manually:

  # is the 16th bit set? then the signed 32 bit int is negative!
  if ($event_id & 0x8000) {
    # strip the first bit (by & 0x7FFF) of the event_id, so a 15 bit
    # (positive) int will remain, then shift the int 16 bits to the left and
    # add active  -- result is a 31 bit (always positive) int.
    # The 32nd bit is the minus sign, and due the (binary) smallest value
    # is the (int) lowest possible number, we have to substract the lowest
    # value + 1 from the 31 bit value -- result is the signed 32 bit int equal
    # to the (unsigned) 32 bit int.
    return ($active | (($event_id & 0x7FFF) << 16)) - 0x80000000;
  }
  else {
    return $active | ($event_id << 16);
  }
}

sub UnpackActive {
  my($tmstatus) = @_;
  # strip the first 16 bit
  return ($tmstatus & 0xFFFF);
}

sub UnpackEvent_id {
  my($tmstatus) = @_;
  # remove the lower 16 bit by shifting the value 16 bits to the right
  return $tmstatus >> 16;
}

sub CheckTimers {
  my $event;

  for my $timer (ParseTimer(1)) {
    # only check autotimers (16th bit set) with event_id
    if( ($timer->{active} & 0x8000) && ($timer->{event_id})) {
      for $event (@{$EPG{$timer->{vdr_id}}}) {
        # look for matching event_id on the same channel -- it's unique
        if($timer->{event_id} == $event->{event_id}) {
          Log(LOG_CHECKTIMER, sprintf("CheckTimers: Checking timer \"%s\" (No. %s) for changes by Event-ID", $timer->{title}, $timer->{id}));
          # update timer if the existing one differs from the EPG
          #if(($timer->{title} ne ($event->{subtitle} ? ($event->{title} . "~" . $event->{subtitle}) : $event->{title})) ||
          #  (($event->{summary}) && (!$timer->{summary})) ||
          if((($event->{summary}) && (!$timer->{summary})) ||
            ($timer->{start} ne ($event->{start} - $CONFIG{TM_MARGIN_BEGIN} * 60)) ||
            ($timer->{stop} ne ($event->{stop} + $CONFIG{TM_MARGIN_END} * 60))) {
              Log(LOG_CHECKTIMER, sprintf("CheckTimers: Timer \"%s\" (No. %s, Event-ID %s, %s - %s) differs from EPG: \"%s\", Event-ID %s, %s - %s)", $timer->{title}, $timer->{id}, $timer->{event_id}, strftime("%Y%m%d-%H%M", localtime($timer->{start})), strftime("%Y%m%d-%H%M", localtime($timer->{stop})), $event->{title}, $event->{event_id}, strftime("%Y%m%d-%H%M", localtime($event->{start})), strftime("%Y%m%d-%H%M", localtime($event->{stop}))));
              ProgTimer(
                $timer->{id},
                $timer->{active},
                $timer->{event_id},
                $timer->{vdr_id},
                $event->{start} - $CONFIG{TM_MARGIN_BEGIN} * 60,
                $event->{stop} + $CONFIG{TM_MARGIN_END} * 60,
                $timer->{prio},
                $timer->{lft},
                # always add subtitle if there is one
                #$event->{subtitle} ? ($event->{title} . "~" . $event->{subtitle}) : $event->{title},
                $timer->{title},
                # If there already is a summary, the user might have changed it -- leave it untouched.
                $timer->{summary} ? $timer->{summary} : $event->{summary},
              );
              Log(LOG_CHECKTIMER, sprintf("CheckTimers: Timer %s updated.", $timer->{id}));
          }
        }
      }
    }
    # all autotimers without event_id will be updated by channel number and start/stop time
    elsif( ($timer->{active} & 0x8000) && (!$timer->{event_id})) {
      # We're checking only timers which doesn't record
      if ($timer->{start} > time()) {
        Log(LOG_CHECKTIMER, sprintf("CheckTimers: Checking timer \"%s\" (No. %s) for changes by recording time", $timer->{title}, $timer->{id}));
        my @eventlist;

        for my $event (@{$EPG{$timer->{vdr_id}}}) {
          # look for events within the margins of the current timer
          if(($event->{start} < $timer->{stop}) && ($event->{stop} > $timer->{start})) {
            push @eventlist, $event;
          }
        }
        # now we have all events in eventlist that touch the old timer margins
        # check for each event how probable it is matching the old timer
        if(scalar(@eventlist) > 0) {
          my $maxwight = 0;
          $event = $eventlist[0];

          for (my $i=0; $i < scalar(@eventlist); $i++) {
            my($start, $stop);

            if($eventlist[$i]->{start} < $timer->{start}) {
              $start = $timer->{start};
            } else {
              $start = $eventlist[$i]->{start};
            }
            if($eventlist[$i]->{stop} > $timer->{stop}) {
              $stop = $timer->{stop};
            } else {
              $stop = $eventlist[$i]->{stop};
            }

            my $wight = ($stop - $start) / ($eventlist[$i]->{stop} - $eventlist[$i]->{start});

            if($wight > $maxwight) {
              $maxwight = $wight;
              $event = $eventlist[$i];
            }
          }
          # update timer if the existing one differs from the EPG
          if((($event->{summary}) && (!$timer->{summary})) ||
            ($timer->{start} > ($event->{start} - $CONFIG{TM_MARGIN_BEGIN} * 60)) ||
            ($timer->{stop} < ($event->{stop} + $CONFIG{TM_MARGIN_END} * 60))) {
            Log(LOG_CHECKTIMER, sprintf("CheckTimers: Timer \"%s\" (No. %s, Event-ID %s, %s - %s) differs from EPG: \"%s\", Event-ID %s, %s - %s)", $timer->{title}, $timer->{id}, $timer->{event_id}, strftime("%Y%m%d-%H%M", localtime($timer->{start})), strftime("%Y%m%d-%H%M", localtime($timer->{stop})), $event->{title}, $event->{event_id}, strftime("%Y%m%d-%H%M", localtime($event->{start})), strftime("%Y%m%d-%H%M", localtime($event->{stop}))));
            ProgTimer(
              $timer->{id},
              $timer->{active},
              0,
              $timer->{vdr_id},
              $timer->{start} > ($event->{start} - $CONFIG{TM_MARGIN_BEGIN} * 60) ? $event->{start} - $CONFIG{TM_MARGIN_BEGIN} * 60 : $timer->{start},
              $timer->{stop} < ($event->{stop} + $CONFIG{TM_MARGIN_END} * 60) ? $event->{stop} + $CONFIG{TM_MARGIN_END} * 60 : $timer->{stop},
              $timer->{prio},
              $timer->{lft},
              # don't touch the title since we're not too sure about the event
              $timer->{title},
              # If there already is a summary, the user might have changed it -- leave it untouched.
              $timer->{summary} ? $timer->{summary} : $event->{summary},
            );
            Log(LOG_CHECKTIMER, sprintf("CheckTimers: Timer %s updated.", $timer->{id}));
          }
        }
      } else {
        Log(LOG_CHECKTIMER, sprintf("CheckTimers: Skipping Timer \"%s\" (No. %s, %s - %s)", $timer->{title}, $timer->{id}, strftime("%Y%m%d-%H%M", localtime($timer->{start})), strftime("%Y%m%d-%H%M", localtime($timer->{stop}))));
      }
    }
  }
}

#############################################################################
# regulary timers
#############################################################################
sub my_mktime {
	my $sec  = 0;
	my $min = shift;
	my $hour = shift;
	my $mday = shift;
	my $mon  = shift;
	my $year = shift() - 1900;

	#my $time = mktime($sec, $min, $hour, $mday, $mon, $year, 0, 0, (localtime(time))[8]);
	my $time = mktime($sec, $min, $hour, $mday, $mon, $year, 0, 0, -1);
}

sub ParseTimer {
  my $pc = shift;
  my $tid = shift;
  my $entry = 1;

  my @temp;
  for(SendCMD("lstt")) {
    last if(/^No timers defined/);
    chomp;
    my($id, $temp) = split(/ /, $_, 2);
    my($tmstatus, $vdr_id, $dor, $start, $stop, $prio, $lft, $title, $summary) = split(/\:/, $temp, 9);

    my($startsse, $stopsse, $weekday, $off, $perrec, $length, $first);

    my($active, $event_id);
    $active = UnpackActive($tmstatus);
    $event_id = UnpackEvent_id($tmstatus);

    # direct recording (menu, red)
    $active = 1 if($active == 3);

    if(length($dor) == 7) { # repeating timer
      $startsse = my_mktime(substr($start, 2, 2), substr($start, 0, 2),
				my_strftime("%d"), (my_strftime("%m") - 1), my_strftime("%Y"));
      $stopsse  = my_mktime(substr($stop, 2, 2), substr($stop, 0, 2),
				my_strftime("%d"), (my_strftime("%m") - 1), my_strftime("%Y"));
      if($stopsse < $startsse)  {
        $stopsse += 86400;
      }
      $weekday = ((localtime(time))[6] + 6) % 7;
      $perrec = join("", substr($dor, $weekday), substr($dor, 0, $weekday));
      $perrec =~ m/^-+/g;

      $off = (pos $perrec) * 86400;
      if($off == 0 && $stopsse < time) {
        #$weekday = ($weekday + 1) % 7;
        $perrec = join("", substr($dor, ($weekday + 1) % 7), substr($dor, 0, ($weekday + 1) % 7));
        $perrec =~ m/^-+/g;
        $off = ((pos $perrec) + 1) * 86400;
      }
      $startsse += $off;
      $stopsse += $off;
    } elsif(length($dor) == 18) { # first-day timer
      $dor =~ /.{7}\@(\d\d\d\d)-(\d\d)-(\d\d)/;
      $startsse = my_mktime(substr($start, 2, 2),
				substr($start, 0, 2), $3, ($2 - 1), $1);
			# 31 + 1 = ??
      $stopsse = my_mktime(substr($stop, 2, 2),
        substr($stop, 0, 2), $stop > $start ? $3 : $3 + 1,
        ($2 - 1), $1);
    } else { # regular timer
      if ($dor =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) { # vdr >= 1.3.23
        $startsse = my_mktime(substr($start, 2, 2), substr($start, 0, 2), $3, ($2 - 1), $1);
        $stopsse = my_mktime(substr($stop, 2, 2), substr($stop, 0, 2), $stop > $start ? $3 : $3 + 1, ($2 - 1), $1);
      }
      else { # vdr < 1.3.23
        $startsse = my_mktime(substr($start, 2, 2), substr($start, 0, 2), $dor, (my_strftime("%m") - 1), my_strftime("%Y"));
        $stopsse = my_mktime(substr($stop, 2, 2), substr($stop, 0, 2), $stop > $start ? $dor : $dor + 1, (my_strftime("%m") - 1), my_strftime("%Y"));

        # move timers which have expired one month into the future
        if(length($dor) != 7 && $stopsse < time) {
          $startsse = my_mktime(substr($start, 2, 2), substr($start, 0, 2), $dor, (my_strftime("%m") % 12), (my_strftime("%Y") + (my_strftime("%m") == 12 ? 1 : 0)));
          $stopsse = my_mktime(substr($stop, 2, 2), substr($stop, 0, 2), $stop > $start ? $dor : $dor + 1, (my_strftime("%m") % 12), (my_strftime("%Y") + (my_strftime("%m") == 12 ? 1 : 0)));
        }
      }
    }

    if($CONFIG{RECORDINGS} && length($dor) == 7)  { # repeating timer
      # generate repeating timer entries for up to 28 days
      $first = 1;
      for($weekday += $off / 86400, $off = 0; $off < 28; $off++)  {
        $perrec = join("", substr($dor, ($weekday + $off) % 7), substr($dor, 0, ($weekday + $off) % 7));
        $perrec =~ m/^-+/g;
        if ((pos $perrec) != 0) {
          next;
        }

        $length = push(@temp, {
          id        => $id,
          vdr_id    => $vdr_id,
          start     => $startsse,
          stop      => $stopsse,
          startsse  => $startsse + $off * 86400,
          stopsse   => $stopsse + $off * 86400,
          active    => $active,
          event_id  => $event_id,
          cdesc     => get_name_from_vdrid($vdr_id),
          transponder => get_transponder_from_vdrid($vdr_id),
          ca        => get_ca_from_vdrid($vdr_id),
          dor       => $dor,
          prio      => $prio,
          lft       => $lft,
          title     => $title,
          summary   => $summary,
          collision => 0,
          critical  => 0,
          first     => $first
        });
        $first = 0;
      }
    } else {
      $length = push(@temp, {
        id        => $id,
        vdr_id    => $vdr_id,
        start     => $startsse,
        stop      => $stopsse,
        startsse  => $startsse,
        stopsse   => $stopsse,
        active    => $active,
        event_id  => $event_id,
        cdesc     => get_name_from_vdrid($vdr_id),
        transponder => get_transponder_from_vdrid($vdr_id),
        ca        => get_ca_from_vdrid($vdr_id),
        dor       => $dor,
        prio      => $prio,
        lft       => $lft,
        title     => $title,
        summary   => $summary,
        collision => 0,
        critical  => 0,
        first     => -1
      });
    }

    # save index of entry with specific timer id for later use
    if($tid && $tid == $id) {
      $entry = $length;
    }
  }

  if($tid) {
    return($temp[$entry - 1]);
  } else {
    return(@temp);
  }
}

#############################################################################
# Tools
#############################################################################
sub DisplayMessage {
  my $message = shift;
  SendCMD(sprintf("mesg %s", $message));
}

sub LoadTranslation {
  undef @I18N_Days;
  undef @I18N_Month;
  undef %ERRORMESSAGE;
  undef %COMMONMESSAGE;
  undef %HELP;
  undef @LOGINPAGES_DESCRIPTION;
  include("$TEMPLATEDIR/$CONFIG{LANGUAGE}/$I18NFILE");
}

sub HelpURL {
  my $area = shift;
  return(sprintf("%s?aktion=show_help&area=%s", $MyURL, $area));
}

sub ProgTimer {
  # $start and $stop are expected as seconds since 00:00:00 1970-01-01 UTC.
  my($timer_id, $active, $event_id, $channel, $start, $stop, $prio, $lft, $title, $summary, $dor) = @_;

  $title =~ s/\://g;

  if(($CONFIG{NO_EVENTID} == 1) && ($event_id > 0)) {
    $event_id = 0;
    Log(LOG_CHECKTIMER, sprintf("ProgTimer: Event-ID removed for recording \"%s\"", $title));
  } else {
    for my $n (split(",", $CONFIG{NO_EVENTID_ON})) {
      if(($n == $channel) && ($event_id > 0)) {
        $event_id = 0;
        Log(LOG_CHECKTIMER, sprintf("ProgTimer: Event-ID removed for recording \"%s\" on channel %s", $title, $channel));
      }
    }
  }

  Log(LOG_AT, sprintf("ProgTimer: Programming Timer \"%s\" (Channel %s, Event-ID %s, %s - %s)", $title, $channel, $event_id, my_strftime("%Y%m%d-%H%M", $start), my_strftime("%Y%m%d-%H%M", $stop)));

  my $return = SendCMD(
    sprintf("%s %s:%s:%s:%s:%s:%s:%s:%s:%s",
      $timer_id ? "modt $timer_id" : "newt",
      # only autotimers with 16th bit set will be extended by the event_id
      $active & 0x8000 ? PackStatus($active, $event_id) : $active,
      $channel,
      $dor ? $dor : RemoveLeadingZero(strftime("%d", localtime($start))),
      strftime("%H%M", localtime($start)),
      strftime("%H%M", localtime($stop)),
      $prio,
      $lft,
      $title,
      $summary
    )
  );

  return $return;
}

sub RedirectToReferer {
	my $url = shift;
  if($Referer =~ /vdradmin\.pl\?.*$/) {
    return(headerForward($Referer));
  } else {
    return(headerForward($url));
  }
}

sub salt {
	$_ = $_[0];
	my $string;
	my($offset1, $offset2);
	if(length($_) > 8) {
		$offset1 = length($_) - 9;
		$offset2 = length($_) - 1;
	} else {
		$offset1 = 0;
		$offset2 = length($_) - 1;
	}
	$string = substr($_, $offset1, 1);
	$string .= substr($_, $offset2, 1);
	return($string);
}

sub Shutdown {
	unlink($PIDFILE);
	exit(0)
};

sub getPID {
	open(PID, shift);
	$_ = <PID>;
	close(PID);
	return($_);
}

sub writePID {
	open(FILE, ">$PIDFILE");
	print FILE shift;
	close(FILE);
}

sub HupSignal {
  UptoDate(1);
}

sub UptoDate {
	my $force = shift;
  if(((time() - $CONFIG{CACHE_LASTUPDATE}) >= ($CONFIG{CACHE_TIMEOUT} * 60)) || $force) {
		OpenSocket();
    ChanTree();
    EPG_buildTree();
    CheckTimers();
    AutoTimer();
    CloseSocket();
    $CONFIG{CACHE_LASTUPDATE} = time();
  }
  return(0);
}

sub Log {
  if($#_ >= 1) {
		my $level = shift;
		my $message = join("", @_);
		print $message . "\n" if $DEBUG;
		if($CONFIG{LOGGING}) {
			if($CONFIG{LOGLEVEL} & $level) {
				open(LOGFILE, ">>" . $LOGFILE);
				print LOGFILE sprintf("%s: %s\n", my_strftime("%d.%m.%Y %H:%M:%S"), $message);
				close(LOGFILE);
			}
		}
  } else {
    Log(LOG_FATALERROR, "bogus Log() call");
  }
}

sub TemplateNew {
  my $file = shift;
  $CONFIG{LANGUAGE} = "English" if(!$CONFIG{LANGUAGE});
  $file = "$TEMPLATEDIR/$CONFIG{LANGUAGE}/$file";
  if(!-e $file) {
    Log(LOG_FATALERROR, "Fatal! Can't find $file!");
  }
  my $template = HTML::Template::Expr->new(
    die_on_bad_params => 0,
    loop_context_vars => 1,
    filename => $file);
  return $template;
}

sub my_strftime {
  my $format = shift;
  my $time = shift;
  return(strftime($format, $time ? localtime($time) : localtime(time)));
}

sub my_strfgmtime {
  my $format = shift;
  my $time = shift;
  return(strftime($format, $time ? gmtime($time) : gmtime(time)));
}

sub GetFirstChannel {
	return($CHAN[0]->{service_id});
}

sub ChannelHasEPG {
	my $service_id = shift;
	for my $event (@{$EPG{$service_id}}) {
		return(1);
	}
	return(0);
}

sub Encode_Referer {
  if($_[0]) { $_ = $_[0]; } else { $_ = $Referer; }
  return(MIME::Base64::encode_base64($_));
}

sub Decode_Referer {
  return(MIME::Base64::decode_base64(shift));
}

sub encode_ref {
  my($tmp) = $_[0]->url(-relative=>1,-query=>1);
  my(undef, $query) = split(/\?/, $tmp, 2);
  return(MIME::Base64::encode_base64($query));
}

sub decode_ref {
  return(MIME::Base64::decode_base64($_[0]));
}

sub access_log {
	my $ip               = shift;
	my $username         = shift;
	my $time             = shift;
	my $rawrequest       = shift;
	my $http_status      = shift;
	my $bytes_transfered = shift;
	my $request          = shift;
	my $useragent        = shift;
	return sprintf("%s - %s [%s +0100] \"%s\" %s %s \"%s\" \"%s\"",
		$ip,
		$username,
		my_strftime("%d/%b/%Y:%H:%M:%S", $time),
		$rawrequest,
		$http_status,
		$bytes_transfered,
		$request,
		$useragent
	);
}

sub ReadConfig {
  if(-e $CONFFILE) {
    open(CONF, $CONFFILE);
    while(<CONF>) {
      chomp;
      my($key, $value) = split(/ \= /, $_, 2);
      $CONFIG{$key} = $value;
    }
    close(CONF);
  } else {
    print "$CONFFILE doesn't exist. Please run \"$0 --config\"\n";
    print "Exitting!\n";
    exit(1);
    #open(CONF, ">$CONFFILE");
    #for(keys(%CONFIG)) {
    #  print(CONF "$_ = $CONFIG{$_}\n");
    #}
    #close(CONF);
    #return(1);
  }
  return(0);
}

sub Question {
  my($quest, $default) = @_;
  print("$quest [$default]: ");
  my($answer);
  $answer = <STDIN>;
  if($answer eq "\n") {
    return($default);
  } else {
    return($answer);
  }
}

sub RemoveLeadingZero {
  my($str) = @_;
  while(substr($str, 0, 1) == 0) {
    $str = substr($str, 1, (length($str) - 1));
  }
  return($str);
}

sub csvAdd {
  my $csv = shift;
  my $add = shift;

  my $found = 0;
  for my $item (split(",", $csv)) {
		$found = 1 if($item eq $add);
  }
	$csv = join(",", (split(",", $csv), $add)) if(!$found);
  return($csv);
}

sub csvRemove {
  my $csv = shift;
  my $remove = shift;

  my $newcsv;
  for my $item (split(",", $csv)) {
    if($item ne $remove) {
      my $found = 0;
      if(defined($newcsv)) {
        for my $dup (split(",", $newcsv)) {
          $found = 1 if($dup eq $item);
        }
      }
			$newcsv = join(",", (split(",", $newcsv), $item)) if(!$found);
    }
  }
  return($newcsv);
}

sub Einheit {
	my @einheiten = qw(MB GB TB);
	my $einheit = 0;
	my $zahl = shift;
	while($zahl > 1024) {
		$zahl /= 1024;
		$einheit++;
	}
	return(int($zahl) . $einheiten[$einheit]);
}

sub MBToMinutes {
	my $mb = shift;
	my $minutes = $mb / 25.75;
	my $hours = $minutes / 60;
	$minutes %= 60;
	return(sprintf("%2d:%02d", $hours, $minutes));
}

sub VideoDiskFree {
	$_ = join("", SendCMD("stat disk"));
	if(/^(\d+)MB (\d+)MB (\d+)%$/) {
		return(Einheit($1), MBToMinutes($1), Einheit($2), MBToMinutes($2), $3);
	} elsif(/^Command unrecognized: "stat"$/) {
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
	my $template = TemplateNew("index.html");
	my $page;
	if(defined($CONFIG{LOGINPAGE})) {
		$page = $LOGINPAGES[$CONFIG{LOGINPAGE}];
	} else {
		$page = $LOGINPAGES[0];
	}
	$template->param(
    loginpage => "$MyURL?aktion=$page",
    version   => $VERSION,
    host      => $CONFIG{VDR_HOST},
  );
	return(header("200", "text/html", $template->output));
}

sub toolbar {
	my $template = TemplateNew("toolbar.html");

	my @channel;
	for my $channel (@CHAN) {
    # if its wished, display only wanted channels
    if($CONFIG{CHANNELS_WANTED_PRG}) {
      my $found = 0;
      for my $n (split(",", $CONFIG{CHANNELS_WANTED})) {
				($found = 1) if($n eq $channel->{vdr_id});
      }
      next if(!$found);
    }

    # skip channels without EPG data
		if(ChannelHasEPG($channel->{vdr_id})) {
			push(@channel, {
				name       => $channel->{name},
				vdr_id     => $channel->{vdr_id},
				#current    => ($vdr_id == $channel->{vdr_id}) ? 1 : 0,
      });
    }
  }

	$template->param(
		url => $MyURL,
		chanloop => \@channel
	);
	return(header("200", "text/html", $template->output));
}

# obsolete?
sub show_top {
	my $template = TemplateNew("top.html");
  return(header("200", "text/html", $template->output));
}

sub prog_switch {
  my $channel = $q->param("channel");
  if($channel) {
    SendCMD("chan $channel");
  }
  SendFile($BASENAME . "/images/switch_channel.gif");
}

sub prog_detail {
  return if(UptoDate());
	my $vdr_id = $q->param("vdr_id");
	my $epg_id = $q->param("epg_id");
	
  my($channel_name, $title, $subtitle, $start, $stop, $date, $text);
	
	if($vdr_id && $epg_id) {
		for(@{$EPG{$vdr_id}}) {
			#if($_->{id} == $epg_id) { #XXX
      if($_->{event_id} == $epg_id) {
				$channel_name = $_->{channel_name};
				$title        = $_->{title};
				$subtitle     = $_->{subtitle};
				$start        = my_strftime("%H:%M", $_->{start});
				$stop         = my_strftime("%H:%M", $_->{stop});
				$text         = $_->{summary};
				$date         = sprintf("%s., %s. %s %s",
					substr(FullDay(my_strftime("%w", $_->{start})), 0, 2),
					my_strftime("%d", $_->{start}),
					FullMonth(my_strftime("%m", $_->{start})),
					my_strftime("%Y", $_->{start}));
				last;
			}
		}
	}

  my $displaytext = $text;
  my $displaytitle = $title;
  my $displaysubtitle = $subtitle;
  
  $displaytext =~ s/\n/<br>\n/g;
  $displaytext =~ s/\|/<br>\n/g;
  $displaytitle =~ s/\n/<br>\n/g;
  $displaytitle =~ s/\|/<br>\n/g;
  $displaysubtitle =~ s/\n/<br>\n/g;
  $displaysubtitle =~ s/\|/<br>\n/g;

	my $template = TemplateNew("prog_detail.html");
  $template->param(
    title        => $displaytitle ? $displaytitle : undef,
    recurl       => sprintf("%s?aktion=timer_new_form&epg_id=%s&vdr_id=%s", $MyURL, $epg_id, $vdr_id),
    switchurl    => sprintf("%s?aktion=prog_switch&channel=%s", $MyURL, $vdr_id),
		channel_name => $channel_name,
		subtitle     => $displaysubtitle,
		start        => $start,
		stop         => $stop,
    text         => $displaytext ? $displaytext : undef,
		date         => $date
  );
  return(header("200", "text/html", $template->output));
}


#############################################################################
# program listing
#############################################################################
sub prog_list {
  return if(UptoDate());
	my $vdr_id = $q->param("vdr_id");
  
	# called without vdr_id, redirect to the first known channel
  if(!$vdr_id) {
    return(headerForward("$MyURL?aktion=prog_list&vdr_id=1"));
  }

	#
  my @channel;
	for my $channel (@CHAN) {
    # if its wished, display only wanted channels
    if($CONFIG{CHANNELS_WANTED_PRG}) {
      my $found = 0;
      for my $n (split(",", $CONFIG{CHANNELS_WANTED})) {
				($found = 1) if($n eq $channel->{vdr_id});
      }
      next if(!$found);
    }

    # skip channels without EPG data
		if(ChannelHasEPG($channel->{vdr_id})) {
			push(@channel, {
				name       => $channel->{name},
				vdr_id     => $channel->{vdr_id},
				current    => ($vdr_id == $channel->{vdr_id}) ? 1 : 0,
      });
    }
  }

  # find the next/prev channel
  my $ci = 0;
  for(my $i = 0; $i <= $#channel; $i++) {
    ($ci = $i) if($vdr_id == $channel[$i]->{vdr_id});
  }
  my ($next_channel, $prev_channel);
  ($prev_channel = $channel[$ci - 1]->{vdr_id}) if($ci > 0);
  ($next_channel = $channel[$ci + 1]->{vdr_id}) if($ci < $#channel);

	#
  my(@show, $progname, $cnumber);
  my $day = 0;
  for my $event (@{$EPG{$vdr_id}}) {
    if(my_strftime("%d", $event->{start}) != $day) {
      # new day
			push(@show, { endd => 1 }) if(scalar(@show) > 0);
      push(@show, {
				title  => $event->{channel_name} . " | " .
					FullDay(my_strftime("%w", $event->{start})) . ", " .
					my_strftime("%d.%m.%Y", $event->{start}),
				newd   => 1,
				next_channel => $next_channel ? "$MyURL?aktion=prog_list&vdr_id=$next_channel" : undef,
				prev_channel => $prev_channel ? "$MyURL?aktion=prog_list&vdr_id=$prev_channel" : undef,
      });
      $day = strftime("%d", localtime($event->{start}));
    }
    push(@show, {
      ssse        => $event->{start},
      emit        => my_strftime("%H:%M", $event->{start}),
      duration    => my_strftime("%H:%M", $event->{stop}),
      title       => $event->{title},
      subtitle    => $event->{subtitle},
      recurl      => sprintf("%s?aktion=timer_new_form&epg_id=%s&vdr_id=%s", $MyURL, $event->{event_id}, $event->{vdr_id}),
      infurl      => $event->{summary} ? sprintf("%s?aktion=prog_detail&epg_id=%s&vdr_id=%s", $MyURL, $event->{event_id}, $event->{vdr_id}) : undef,
      newd        => 0,
      anchor      => $event->{event_id}
    });
    $progname = $event->{progname};
    $cnumber = $event->{cnumber};
  }
  if(scalar(@show)) {
    push(@show, { endd => 1 });
  }
	
	
  # 
  my($template) = TemplateNew("prog_list.html");
  $template->param(
    url        => $MyURL,
    loop       => \@show,
    chanloop   => \@channel,
    progname   => GetChannelDescByNumber($vdr_id),
		switchurl  => "$MyURL?aktion=prog_switch&channel=" . $vdr_id,
		streamurl  => "$MyURL?aktion=live_stream&channel=" . $vdr_id,
		toolbarurl => "$MyURL?aktion=toolbar"
  );
  return(header("200", "text/html", $template->output));
}




#############################################################################
# program listing 2
# "What's up today" extension.
# 
# Contributed by Thomas Blon, 6. Mar 2004
#############################################################################
sub prog_list2 {
  return if(UptoDate());
  
	#
  my $vdr_id;
  my @channel;

  for my $channel (@CHAN) { 
    # if its wished, display only wanted channels
    if($CONFIG{CHANNELS_WANTED_PRG}) {
      my $found = 0;
      for my $n (split(",", $CONFIG{CHANNELS_WANTED})) {
				($found = 1) if($n eq $channel->{vdr_id});
      }
      next if(!$found);
    } 
    
    # skip channels without EPG data
		if(ChannelHasEPG($channel->{vdr_id})) {
			push(@channel, {
				name       => $channel->{name},
				vdr_id     => $channel->{vdr_id},
				current    => ($vdr_id == $channel->{vdr_id}) ? 1 : 0,
      }); 
    }
  }

  my(@show, $progname, $cnumber); 

  foreach (@channel) {  # loop through all channels
     $vdr_id = $_->{vdr_id};
     
     # find the next/prev channel
     my $ci = 0;
     for(my $i = 0; $i <= $#channel; $i++) {
       ($ci = $i) if($vdr_id == $channel[$i]->{vdr_id});
     }
     my ($next_channel, $prev_channel);
     ($prev_channel = $channel[$ci - 1]->{vdr_id}) if($ci > 0);
     ($next_channel = $channel[$ci + 1]->{vdr_id}) if($ci < $#channel); 
	   

     my $day     = 0;
     my $dayflag = 0;


     for my $event (@{$EPG{$vdr_id}}) {
       if(my_strftime("%d", $event->{start}) != $day) {   # new day
	       $day = strftime("%d", localtime($event->{start}));
	       $dayflag++;
       }

       if($dayflag == 1) {
	       push(@show, {
				   title  => $event->{channel_name} . " | " . 
					   FullDay(my_strftime("%w", $event->{start})) . ", " . 
					   my_strftime("%d.%m.%Y", $event->{start}),
				   newd   => 1,
				   undef,
				   undef,
	       });

	       $dayflag++; 
       }

       if($dayflag == 2) {
	       push(@show, {
          ssse        => $event->{start},
          emit        => my_strftime("%H:%M", $event->{start}),
          duration    => my_strftime("%H:%M", $event->{stop}),
          title       => $event->{title},
          subtitle    => $event->{subtitle},
          recurl      => sprintf("%s?aktion=timer_new_form&epg_id=%s&vdr_id=%s", $MyURL, $event->{event_id}, $event->{vdr_id}),
          infurl      => $event->{summary} ? sprintf("%s?aktion=prog_detail&epg_id=%s&vdr_id=%s", $MyURL, $event->{event_id}, $event->{vdr_id}) : undef,
          newd        => 0,
          anchor      => $event->{event_id}
        });
        $progname = $event->{progname};
        $cnumber = $event->{cnumber};
       }
     }
     push(@show, { endd => 1 }); 
  } # end: for $vdr_id

	
  # 
  my($template) = TemplateNew("prog_list2.html");
  $template->param(
    url      => $MyURL,
    loop     => \@show,
    chanloop => \@channel,
    progname => GetChannelDescByNumber($vdr_id),
		switchurl=> "$MyURL?aktion=prog_switch&channel=" . $vdr_id,
		toolbarurl => "$MyURL?aktion=toolbar"
  );
  return(header("200", "text/html", $template->output));
}


#############################################################################
# regular timers
#############################################################################
sub timer_list {
  return if(UptoDate());
  
	#
	my $desc;
	if(!defined($q->param("desc"))) {
		$desc = 1;
	} else {
		$q->param("desc") ? ($desc = 1) : ($desc = 0);
	}
	my $sortby = $q->param("sortby");
	($sortby = "day") if(!$sortby);

	#
  my @timer;
  my @timer2;
  my @days;

  my ($TagAnfang, $TagEnde);
  for my $timer (ParseTimer(0)) {
		if($timer->{startsse} < time() && $timer->{stopsse} > time() && ($timer->{active} & 1)) {
			$timer->{recording} = 1;
		}
		if($timer->{active} & 1) {
		  if($timer->{active} & 0x8000) {
		    $timer->{active} = 0x8001;
		  } else {
		    $timer->{active} = 1;
		  }
		} else {
		  $timer->{active} = 0;
		}
    $timer->{delurl} = $MyURL . "?aktion=timer_delete&timer_id=" . $timer->{id},
    $timer->{modurl} = $MyURL . "?aktion=timer_new_form&timer_id=" . $timer->{id},
		$timer->{toggleurl} = sprintf("%s?aktion=timer_toggle&active=%s&id=%s", $MyURL, ($timer->{active} & 1) ? 0 : 1, $timer->{id}),
		$timer->{dor} = my_strftime("%d.%m", $timer->{startsse});

    $TagAnfang=my_mktime(0,0,my_strftime("%d", $timer->{start}),my_strftime("%m", $timer->{start}),my_strftime("%Y", $timer->{start}));
    $TagEnde=my_mktime(0,0,my_strftime("%d", $timer->{stop}),my_strftime("%m", $timer->{stop}),my_strftime("%Y", $timer->{stop}));

    $timer->{startlong} = ((my_mktime(my_strftime("%M", $timer->{start}),my_strftime("%H", $timer->{start}),my_strftime("%d", $timer->{start}),my_strftime("%m", $timer->{start}),my_strftime("%Y", $timer->{start})))-$TagAnfang)/60;
    $timer->{stoplong}  = ((my_mktime(my_strftime("%M", $timer->{stop}),my_strftime("%H", $timer->{stop}),my_strftime("%d", $timer->{stop}),my_strftime("%m", $timer->{stop}),my_strftime("%Y", $timer->{stop})))-$TagEnde)/60;
    $timer->{starttime} = my_strftime("%y%m%d", $timer->{startsse});
    $timer->{stoptime}  = my_strftime("%y%m%d", $timer->{stopsse});
    $timer->{sortfield} = $timer->{cdesc} . $timer->{startsse};
    $timer->{infurl}    = $timer->{event_id} ? sprintf("%s?aktion=prog_detail&epg_id=%s&vdr_id=%s", $MyURL, $timer->{event_id}, $timer->{vdr_id}) : undef,

    $timer->{start} = my_strftime("%H:%M", $timer->{start});
    $timer->{stop} = my_strftime("%H:%M", $timer->{stop});
		$timer->{sortbyactive} = 1 if($sortby eq "active");
		$timer->{sortbychannel} = 1 if($sortby eq "channel");
		$timer->{sortbyname} = 1 if($sortby eq "name");
		$timer->{sortbystart} = 1 if($sortby eq "start");
		$timer->{sortbystop} = 1 if($sortby eq "stop");
		$timer->{sortbyday} = 1 if($sortby eq "day");
    push(@timer, $timer);
  }
	@timer = sort({ $a->{startsse} <=> $b->{startsse} } @timer);
  
	#
  if($CONFIG{RECORDINGS})  {
    my($ii, $jj, $timer, $last);
    for($ii = 0; $ii < @timer; $ii++)  {
      if($timer[$ii]->{first} == -1 || $timer[$ii]->{first} == 1)  {
        $last = $ii;
      }

      # Liste der benutzten Transponder
      my @Transponder = (get_transponder_from_vdrid($timer[$ii]->{vdr_id}));
      $timer[$ii]->{collision} = 0;
      
      for($jj = 0; $jj < $ii; $jj++)  {
        if($timer[$ii]->{startsse} >= $timer[$jj]->{startsse} &&
            $timer[$ii]->{startsse} < $timer[$jj]->{stopsse}) {
          if($timer[$ii]->{active} && $timer[$jj]->{active}) { 
            # Timer kollidieren zeitlich. Pruefen, ob die Timer evtl. auf
            # gleichem Transponder oder CAM liegen und daher ohne Probleme
            # aufgenommen werden koennen
            Log(LOG_DEBUG, sprintf("Kollission: %s (%s, %s) -- %s (%s, %s)\n",
              substr($timer[$ii]->{title},0,15), $timer[$ii]->{vdr_id},
              get_transponder_from_vdrid($timer[$ii]->{vdr_id}),
              get_ca_from_vdrid($timer[$ii]->{vdr_id}),
              substr($timer[$jj]->{title},0,15), $timer[$jj]->{vdr_id},
              get_transponder_from_vdrid($timer[$jj]->{vdr_id}),
              get_ca_from_vdrid($timer[$jj]->{vdr_id})));

            if($timer[$ii]->{vdr_id} != $timer[$jj]->{vdr_id} &&
              get_ca_from_vdrid($timer[$ii]->{vdr_id}) ==   
              get_ca_from_vdrid($timer[$jj]->{vdr_id}) &&
              get_ca_from_vdrid($timer[$ii]->{vdr_id}) >= 100) {
              # Beide Timer laufen auf dem gleichen CAM auf verschiedenen
              # Kanaelen, davon kann nur einer aufgenommen werden
              Log(LOG_DEBUG, "Beide Kanaele gleiches CAM");
              ($timer[$ii]->{collision}) = $CONFIG{RECORDINGS};
              # Nur Kosmetik: Transponderliste vervollstaendigen
              push(@Transponder, get_transponder_from_vdrid($timer[$jj]->{vdr_id}));
            } else {
              # "grep" prueft die Bedingung fuer jedes Element, daher den
              # Transponder vorher zwischenspeichern -- ist effizienter
              my $t = get_transponder_from_vdrid($timer[$jj]->{vdr_id});
              if(scalar(grep($_ eq $t, @Transponder)) == 0) {
                ($timer[$ii]->{collision})++;
                push(@Transponder, get_transponder_from_vdrid($timer[$jj]->{vdr_id}));
              } 
            }
          }
        }
      }
    }
    splice(@timer, $last + 1);
    for ($ii = 0; $ii < @timer; $ii++)  {
      $timer[$ii]->{critical} = $timer[$ii]->{collision} >= $CONFIG{RECORDINGS};
      if ($timer[$ii]->{critical} > 0)  {
        for ($jj = $ii - 1; $jj >= 0; $jj--)  {
          if ($timer[$jj]->{stopsse} > $timer[$ii]->{startsse})  {
            $timer[$jj]->{critical} = 1;
          }
          else  {
            last;
          }
        }
      }
      $timer[$ii]->{collision} = $timer[$ii]->{collision} >= ($CONFIG{RECORDINGS} - 1);
      if ($timer[$ii]->{collision} > 0)  {
        for ($jj = $ii - 1; $jj >= 0; $jj--)  {
          if ($timer[$jj]->{stopsse} > $timer[$ii]->{startsse})  {
            $timer[$jj]->{collision} = 1;
          }
          else  {
            last;
          }
        }
      }
      $timer[$ii]->{collision} |= ($timer[$ii]->{ca} >= 100);
    }
  }

  #
  my($ii, $jj, $kk, $current, $title);

  for ($ii = 0; $ii < @timer; $ii++)
  {
    if($ii==0)
    {
      if(!defined($q->param("timer")))
      {
        $current=my_strftime("%y%m%d", $timer[$ii]->{startsse});
        $title=FullDay(my_strftime("%w", $timer[$ii]->{startsse})) . ", " .	my_strftime("%d.%m.%Y", $timer[$ii]->{startsse});
      }
      else
      {
        $current=$q->param("timer");
        $kk = my_mktime(0,0,substr($current, 4, 2),substr($current, 2, 2)-1,"20".substr($current, 0, 2));
        $title=FullDay(my_strftime("%w", $kk)) . ", " .	my_strftime("%d.%m.%Y", $kk);
      }
    }

    $jj=0;
    for ($kk = 0; $kk < @days; $kk++)
    {
      if($days[$kk]->{day} == my_strftime("%d.%m", $timer[$ii]->{startsse}))
      {
        $jj=1;
        last;
      }
    }
    if($jj==0) {
      push(@days, {
        day       => my_strftime("%d.%m", $timer[$ii]->{startsse}),
        sortfield => my_strftime("%y%m%d", $timer[$ii]->{startsse}),
        current   => ($current == my_strftime("%y%m%d", $timer[$ii]->{startsse})) ? 1 : 0,
      });
    }

    $jj=0;
    for ($kk = 0; $kk < @days; $kk++)
    {
      if($days[$kk]->{day} == my_strftime("%d.%m", $timer[$ii]->{stopsse}))
      {
        $jj=1;
        last;
      }
    }
    if($jj==0) {
      push(@days, {
        day => my_strftime("%d.%m", $timer[$ii]->{stopsse}),
        sortfield => my_strftime("%y%m%d", $timer[$ii]->{stopsse}),
        current   => ($current == my_strftime("%y%m%d", $timer[$ii]->{stopsse})) ? 1 : 0,
      });
    }
  }

  @days  = sort({ $a->{sortfield} <=> $b->{sortfield} } @days);


	#
	if($sortby eq "active") {
		if(!$desc) {
			@timer = sort({ $b->{active} <=> $a->{active} } @timer);
		} else {
			@timer = sort({ $a->{active} <=> $b->{active} } @timer);
		}
	} elsif($sortby eq "channel") {
		if(!$desc) {
			@timer = sort({ lc($b->{cdesc}) cmp lc($a->{cdesc}) } @timer);
		} else {
			@timer = sort({ lc($a->{cdesc}) cmp lc($b->{cdesc}) } @timer);
		}
	} elsif($sortby eq "name") {
		if(!$desc) {
			@timer = sort({ lc($b->{title}) cmp lc($a->{title}) } @timer);
		} else {
			@timer = sort({ lc($a->{title}) cmp lc($b->{title}) } @timer);
		}
	} elsif($sortby eq "start") {
		if(!$desc) {
			@timer = sort({ $b->{start} <=> $a->{start} } @timer);
		} else {
			@timer = sort({ $a->{start} <=> $b->{start} } @timer);
		}
	} elsif($sortby eq "stop") {
		if(!$desc) {
			@timer = sort({ $b->{stop} <=> $a->{stop} } @timer);
		} else {
			@timer = sort({ $a->{stop} <=> $b->{stop} } @timer);
		}
  } elsif($sortby eq "day") {
		if(!$desc) {
			@timer = sort({ $b->{startsse} <=> $a->{startsse} } @timer);
		} else {
			@timer = sort({ $a->{startsse} <=> $b->{startsse} } @timer);
		}
  }
	$desc ? ($desc = 0) : ($desc = 1);
  @timer2=@timer;
  @timer2=sort({ lc($a->{sortfield}) cmp lc($b->{sortfield}) } @timer2);

	my $template = TemplateNew("timer_list.html");
  my $vars = {
    sortbydayurl       => "$MyURL?aktion=timer_list&sortby=day&desc=$desc",
    sortbychannelurl   => "$MyURL?aktion=timer_list&sortby=channel&desc=$desc",
    sortbynameurl      => "$MyURL?aktion=timer_list&sortby=name&desc=$desc",
    sortbyactiveurl    => "$MyURL?aktion=timer_list&sortby=active&desc=$desc",
    sortbystarturl     => "$MyURL?aktion=timer_list&sortby=start&desc=$desc",
    sortbystopurl      => "$MyURL?aktion=timer_list&sortby=stop&desc=$desc",
		sortbyday          => ($sortby eq "day") ? 1 : 0,
		sortbychannel      => ($sortby eq "channel") ? 1 : 0,
		sortbyname         => ($sortby eq "name") ? 1 : 0,
		sortbyactive       => ($sortby eq "active") ? 1 : 0,
		sortbystart        => ($sortby eq "start") ? 1 : 0,
		sortbystop         => ($sortby eq "stop") ? 1 : 0,
		desc               => $desc,
    timer_loop			   => \@timer,
    timers  	         => \@timer2,
    day_loop           => \@days,
    nturl				  	   => $MyURL . "?aktion=timer_new_form",
    url			    			 => $MyURL,
    help_url           => HelpURL("timer_list"),
    current            => $current,
    title              => $title,
  };

  $template->param( $vars  );
  # New Template
  my $output;
  my $out = $template->output;
  $Xtemplate->process(\$out, $vars, \$output)
  || return(header("200", "text/html", $Xtemplate->error()));

  return(header("200", "text/html", $output));
}

sub timer_toggle {
	UptoDate();
	my $active = $q->param("active");
	my $id     = $q->param("id");
	# XXX check return 
	SendCMD(sprintf("modt %s %s", $id, $active ? "on" : "off"));
	return(headerForward(RedirectToReferer("$MyURL?aktion=timer_list")));
}

sub timer_new_form {
  UptoDate();
  
  my $epg_id   = $q->param("epg_id");
  my $vdr_id   = $q->param("vdr_id");
  my $timer_id = $q->param("timer_id");
  
  my $this_event;
  if($epg_id) { # new timer
    my $this = EPG_getEntry($vdr_id, $epg_id);
    $this_event->{active} = 0x0001;
    $this_event->{event_id} = $this->{event_id};
    $this_event->{start}  = $this->{start} - ($CONFIG{TM_MARGIN_BEGIN} * 60);
    $this_event->{stop}   = $this->{stop}  + ($CONFIG{TM_MARGIN_END}  * 60);
		$this_event->{dor}    = $this->{dor};
		$this_event->{title}  = $this->{title};
		$this_event->{summary}= $this->{summary};
		$this_event->{vdr_id} = $this->{vdr_id};
  } elsif($timer_id) { # edit existing timer
    $this_event = ParseTimer(0, $timer_id);
  } else { # none of the above
    $this_event->{start}   = time();
    $this_event->{stop}    = 0;
    $this_event->{active}  = 1;
    $this_event->{vdr_id}  = 1;
  }
  
  my @channels;
	for my $channel (@CHAN) {
    ($channel->{vdr_id} == $this_event->{vdr_id}) ? ($channel->{current} = 1) : ($channel->{current} = 0);
    push(@channels, $channel);
  }
  
  # determine referer (redirect to where we come from)
  my $ref;
  if(defined($epg_id)) {
    if($Referer =~ /(.*)\#\d+$/) {
      $ref = sprintf("%s#%s", $1, $epg_id);
    } else {
      $ref = sprintf("%s#%s", $Referer, $epg_id);
    }
  }
  
  # check if we may use Event-IDs in general or not
  if($CONFIG{NO_EVENTID} == 1) {
    # OK, remove Event-ID
    $this_event->{event_id} = 0;
  } else {
    # check if the current channel is on the Event-ID-blacklist
    for my $n (split(",", $CONFIG{NO_EVENTID_ON})) {
      if($n == $this_event->{vdr_id}) {
        # OK, remove Event-ID, on this channel no recording may have one.
        $this_event->{event_id} = 0;
      }
    }
  }
  
  my $displaysummary = $this_event->{summary};
  $displaysummary =~ s/\|/\n/g;

  my $template = TemplateNew("timer_new.html");
  $template->param(
    url      => $MyURL,
    active   => $this_event->{active} & 1,
    event_id => ($this_event->{event_id} << 1) + (($this_event->{active} & 0x8000) >> 15),
    starth   => my_strftime("%H", $this_event->{start}),
    startm   => my_strftime("%M", $this_event->{start}),
    stoph    => $this_event->{stop} ? my_strftime("%H", $this_event->{stop}) : "00",
    stopm    => $this_event->{stop} ? my_strftime("%M", $this_event->{stop}) : "00",
    dor      => (length($this_event->{dor}) == 7) ? $this_event->{dor} : my_strftime("%d", $this_event->{start}),
    prio     => $this_event->{prio} ? $this_event->{prio} : $CONFIG{TM_PRIORITY},
    lft      => $this_event->{lft}  ? $this_event->{lft}  : $CONFIG{TM_LIFETIME},
    title    => $this_event->{title},
    summary  => $displaysummary,
    timer_id => $timer_id ? $timer_id : 0,
    channels => \@channels,
    newtimer => $timer_id ? 0 : 1,
    referer  => Encode_Referer($ref),
    help_url => HelpURL("timer_new"),
  );
  return(header("200", "text/html", $template->output));
}

sub timer_add {
  my $timer_id  = $q->param("timer_id");
  
	my $data;
  
	if($q->param("save")) {
  
		if($q->param("starth") =~ /\d+/ && $q->param("starth") < 24 && $q->param("starth") >= 0) {
			$data->{start} = $q->param("starth");
		} else { print "Help!\n"; }
		if($q->param("startm") =~ /\d+/ && $q->param("startm") < 60 && $q->param("startm") >= 0) {
			$data->{start} .= $q->param("startm");
		} else { print "Help!\n"; }

		if($q->param("stoph") =~ /\d+/ && $q->param("stoph") < 24 && $q->param("stoph") >= 0) {
			$data->{stop} = $q->param("stoph");
		} else { print "Help!\n"; }
		if($q->param("stopm") =~ /\d+/ && $q->param("stopm") < 60 && $q->param("stopm") >= 0) {
			$data->{stop} .= $q->param("stopm");
		} else { print "Help!\n"; }
	 
		if($q->param("prio") =~ /\d+/) {
			$data->{prio} = $q->param("prio");
		}

		if($q->param("lft") =~ /\d+/) {
			$data->{lft} = $q->param("lft");
		}
		
		if($q->param("active") == 0 || $q->param("active") == 1) {
			$data->{active} = $q->param("active");
		}
		
		if($q->param("event_id") == 0) {
			$data->{event_id} = 0;
		}

		# if($q->param("event_id") == 1 && $data->{active} == 1) {
		if($q->param("event_id") == 1) {
			$data->{event_id} = 0;
			$data->{active} |= 0x8000;
		}

		# if($q->param("event_id") > 1 && $data->{active} == 1) {
		if($q->param("event_id") > 1) {
			$data->{event_id} = ($q->param("event_id") >> 1);
			$data->{active} |= 0x8000;
		}

		if($q->param("dor") =~ /[0-9MTWTWFSS-]+/) {
			$data->{dor} = $q->param("dor");
		}
		
		if($q->param("channel") =~ /\d+/) {
			$data->{channel} = $q->param("channel");
		}

		if(length($q->param("title")) > 0) {
			$data->{title} = $q->param("title");
		}

		if(length($q->param("summary")) > 0) {
			$data->{summary} = $q->param("summary");
			$data->{summary} =~ s/\://g;
			$data->{summary} =~ s/\r//g;
			$data->{summary} =~ s/\n/|/g;
		}

    my $dor = $data->{dor};
    if(length($data->{dor}) == 7) {
      # dummy
      $dor = 1;
    }
    $data->{startsse} = my_mktime(substr($data->{start}, 2, 2), 
      substr($data->{start}, 0, 2), $dor,
      (my_strftime("%m") - 1), my_strftime("%Y"));
    
    $data->{stopsse} = my_mktime(substr($data->{stop}, 2, 2), 
      substr($data->{stop}, 0, 2),
      $data->{stop} > $data->{start} ? $dor : $dor + 1, 
      (my_strftime("%m") - 1), my_strftime("%Y"));
		
		my $return = ProgTimer(
		  $timer_id,
		  $data->{active},
		  $data->{event_id},
		  $data->{channel},
		  $data->{startsse},
		  $data->{stopsse},
		  $data->{prio},
		  $data->{lft},
		  $data->{title},
		  $data->{summary},
      ($dor == 1) ? $data->{dor} : undef
		);

	}
 
  #XXX
  if($q->param("referer")) {
    return(headerForward(Decode_Referer($q->param("referer"))));
  } else {
    return(headerForward("$MyURL?aktion=timer_list"));
  }
}

sub timer_delete {
  my($timer_id) = $q->param('timer_id');
  if($timer_id) {
    my($result) = SendCMD("delt $timer_id");
    if($result =~ /Timer "$timer_id" is recording/i) {
      SendCMD("modt $timer_id off");
      sleep(1);
      SendCMD("delt $timer_id");
    }
  } else {
    my @sorted;
    for($q->param) {
      if(/xxxx_(.*)/) {
				push(@sorted, $1);
      }
    }
    @sorted = sort({ $b <=> $a } @sorted);
    for my $t (@sorted) {
      my($result) = SendCMD("delt $t");
      if($result =~ /Timer "$t" is recording/i) {
				SendCMD("modt $t off");
        sleep(1);
        SendCMD("delt $t");
      }
    }
    CloseSocket();
  }
  return(headerForward(RedirectToReferer("$MyURL?aktion=timer_list")));
}

sub rec_stream {
  my($id) = $q->param('id');
  my($i, $title, $newtitle);
  my $data;
  my $f;
  my(@tmp, $dirname, $name, $parent, @files);
  my( $date, $time, $day, $month, $hour, $minute);
  my $c;

  for(SendCMD("lstr")) {
    ($i, $date, $time, $title) = split(/ +/, $_, 4);
    last if($id == $i);
  }
  $time = substr($time, 0, 5); # needed for wareagel-patch  
  if ( $id == $i) {
      chomp($title);
      ($day, $month)= split( /\./, $date);
      ($hour, $minute)= split( /:/, $time);
      # escape characters
      $title =~ s/~/\//g;
      $title =~ s/\ /\_/g;
      for ( $i=0 ;$ i < length($title); $i++) {
          $c = substr($title,$i,1);
	  unless ($c =~ /[�������A-Za-z0123456789_!@\$%&\(\)\+,.\-;=~]/) {
	      $newtitle.= sprintf( "#%02X", ord( $c ));
	  } else {
	      $newtitle.= $c;
	  }
      }
      $title=$newtitle;
      $title =~ s/~/\//g;
      @files= `find $VIDEODIR/ -regex "$VIDEODIR/$title\_*/....-$month-$day\\.$hour.$minute\\...\\...\\.rec/...\\.vdr" | sort -r`;
      foreach (@files) {
          $_ =~ s/$VIDEODIR//;
          $data= $CONFIG{ST_URL}."$_\n$data";
      }
  }
  return(header("200", "audio/x-mpegurl", $data));
}

#############################################################################
# live streaming
#############################################################################
sub live_stream {
  my $channel = $q->param("channel");
  my ($data, $ifconfig, $ip);

  if ( $CONFIG{VDR_HOST} eq "localhost") {
      $ifconfig=`/sbin/ifconfig eth0`;
      if ( $ifconfig =~ /inet.+:(\d+\.\d+\.\d+\.\d+)\s+Bcast/) {
          $ip=$1;
      }
  } else {
      $ip= $CONFIG{VDR_HOST};
  }
  $data="http://$ip:3000/$channel";
  return(header("200", "audio/x-mpegurl", $data));
}

#############################################################################
# automatic timers
#############################################################################
sub at_timer_list {
  return if(UptoDate()); 
	
	#
	my $desc;
	if(!defined($q->param("desc"))) {
		$desc = 1;
	} else {
		$q->param("desc") ? ($desc = 1) : ($desc = 0);
	}
	my $sortby = $q->param("sortby");
	($sortby = "pattern") if(!$sortby);
	
  #
  my @at;
  my $id = 0;
  for(AT_Read()) {
    $id++;
    if($_->{start}) {
      $_->{start} = substr($_->{start}, 0, 2) . ":" . substr($_->{start}, 2, 5);
    }
    if($_->{stop}) {
      $_->{stop} = substr($_->{stop}, 0, 2) . ":" . substr($_->{stop}, 2, 5);
    }
    $_->{modurl} = $MyURL . "?aktion=at_timer_edit&id=$id";
    $_->{delurl} = $MyURL . "?aktion=at_timer_delete&id=$id";
    $_->{prio} = $_->{prio} ? $_->{prio} : $CONFIG{AT_PRIORITY};
    $_->{lft} = $_->{lft} ? $_->{lft} : $CONFIG{AT_LIFETIME};
    $_->{id} = $id;
    $_->{channel} = GetChannelDescByNumber($_->{channel}); 
		$_->{sortbyactive} = 1 if($sortby eq "active");
		$_->{sortbychannel} = 1 if($sortby eq "channel");
		$_->{sortbypattern} = 1 if($sortby eq "pattern");
		$_->{sortbystart} = 1 if($sortby eq "start");
		$_->{sortbystop} = 1 if($sortby eq "stop");
		$_->{toggleurl} = sprintf("%s?aktion=at_timer_toggle&active=%s&id=%s", $MyURL, ($_->{active} & 1) ? 0 : 1, $_->{id}),
    push(@at, $_);
  }
  my @timer = sort({ lc($a->{pattern}) cmp lc($b->{pattern}) } @at);
  
	#
	if($sortby eq "active") {
		if(!$desc) {
			@timer = sort({ $b->{active} <=> $a->{active} } @timer);
		} else {
			@timer = sort({ $a->{active} <=> $b->{active} } @timer);
		}
	} elsif($sortby eq "channel") {
		if(!$desc) {
			@timer = sort({ lc($b->{channel}) cmp lc($a->{channel}) } @timer);
		} else {
			@timer = sort({ lc($a->{channel}) cmp lc($b->{channel}) } @timer);
		}
	} elsif($sortby eq "pattern") {
		if(!$desc) {
			@timer = sort({ lc($b->{pattern}) cmp lc($a->{pattern}) } @timer);
		} else {
			@timer = sort({ lc($a->{pattern}) cmp lc($b->{pattern}) } @timer);
		}
	} elsif($sortby eq "start") {
		if(!$desc) {
			@timer = sort({ $b->{start} <=> $a->{start} } @timer);
		} else {
			@timer = sort({ $a->{start} <=> $b->{start} } @timer);
		}
	} elsif($sortby eq "stop") {
		if(!$desc) {
			@timer = sort({ $b->{stop} <=> $a->{stop} } @timer);
		} else {
			@timer = sort({ $a->{stop} <=> $b->{stop} } @timer);
		}
	}
	$desc ? ($desc = 0) : ($desc = 1);

	#
	my $template = TemplateNew("at_timer_list.html");
  $template->param(
    sortbychannelurl   => "$MyURL?aktion=at_timer_list&sortby=channel&desc=$desc",
    sortbypatternurl   => "$MyURL?aktion=at_timer_list&sortby=pattern&desc=$desc",
    sortbyactiveurl    => "$MyURL?aktion=at_timer_list&sortby=active&desc=$desc",
    sortbystarturl     => "$MyURL?aktion=at_timer_list&sortby=start&desc=$desc",
    sortbystopurl      => "$MyURL?aktion=at_timer_list&sortby=stop&desc=$desc",
		sortbychannel      => ($sortby eq "channel") ? 1 : 0,
		sortbypattern      => ($sortby eq "pattern") ? 1 : 0,
		sortbyactive       => ($sortby eq "active") ? 1 : 0,
		sortbystart        => ($sortby eq "start") ? 1 : 0,
		sortbystop         => ($sortby eq "stop") ? 1 : 0,
		desc               => $desc,
    at_timer_loop      => \@timer,
    naturl	    			 => $MyURL . "?aktion=at_timer_new",
    #naturl	    			 => $MyURL . "?aktion=at_timer_new&active=1",
    url			    			 => $MyURL,
		force_update_url   => "$MyURL?aktion=force_update",
    help_url           => HelpURL("at_timer_list"), 
  );
  return(header("200", "text/html", $template->output));
}

sub at_timer_toggle {
	UptoDate();
	my $active = $q->param("active");
	my $id     = $q->param("id");

	my(@at, $z);

	for(AT_Read()) {
		$z++;
		if($z == $id) {
			$_->{active} = $active;
		}
		push(@at, $_);
	}
	AT_Write(@at);

	return(headerForward(RedirectToReferer("$MyURL?aktion=at_timer_list")));
}

sub at_timer_edit {
  my $id = $q->param("id");

  my @at = AT_Read();
  
  #
  my @chans;
  for my $chan (@CHAN) {
    if($chan->{vdr_id}) {
      $chan->{cur} = ($chan->{vdr_id} == $at[$id-1]->{channel}) ? 1 : 0;
      push(@chans, $chan);
    }
  }
  
  my $template = TemplateNew("at_new.html");
  $template->param(
    channels    => \@chans,
    id          => $id,
    url         => $MyURL,
    prio        => $at[$id-1]->{prio} ? $at[$id-1]->{prio} : $CONFIG{AT_PRIORITY},
    lft         => $at[$id-1]->{lft} ? $at[$id-1]->{lft} : $CONFIG{AT_LIFETIME},
    oneshot     => $at[$id-1]->{active} == 2,
    active      => $at[$id-1]->{active},
    done        => $at[$id-1]->{done},
    episode     => $at[$id-1]->{episode},
    pattern     => $at[$id-1]->{pattern},
    starth      => (length($at[$id-1]->{start}) >= 4) ? substr($at[$id-1]->{start}, 0, 2) : undef,
    startm      => (length($at[$id-1]->{start}) >= 4) ? substr($at[$id-1]->{start}, 2, 5) : undef,
    stoph       => (length($at[$id-1]->{stop}) >= 4) ? substr($at[$id-1]->{stop}, 0, 2) : undef,
    stopm       => (length($at[$id-1]->{stop}) >= 4) ? substr($at[$id-1]->{stop}, 2, 5) : undef,
    title       => ($at[$id-1]->{section} & 1) ? 1 : 0,
    subtitle    => ($at[$id-1]->{section} & 2) ? 1 : 0,
    description => ($at[$id-1]->{section} & 4) ? 1 : 0,
    directory   => $at[$id-1]->{directory},
		newtimer    => 0,
    help_url    => HelpURL("at_timer_new")
  );
  return(header("200", "text/html", $template->output));
}

sub at_timer_new {
	my $template = TemplateNew("at_new.html");
  $template->param(
    url      => $MyURL,
    active   => $q->param("active"),
    done     => $q->param("done"),
    title    => 1,
    channels => \@CHAN,
    prio     => $CONFIG{AT_PRIORITY},
    lft      => $CONFIG{AT_LIFETIME},
		newtimer => 1,
    help_url => HelpURL("at_timer_new"),
  );
  return(header("200", "text/html", $template->output));
}

sub at_timer_save {
  my $id = $q->param("id");

  if($q->param("save")) {
    if(!$id) {
      my @at = AT_Read();
      my $section = 0;
      ($section += 1) if($q->param("title"));
      ($section += 2) if($q->param("subtitle"));
      ($section += 4) if($q->param("description"));
      push(@at, {
				episode   => $q->param("episode") ? $q->param("episode") : 0,
				active    => $q->param("active"),
        done      => $q->param("done"),
				pattern   => $q->param("pattern"),
				section   => $section,
				start     => $q->param("starth") . $q->param("startm"),
				stop      => $q->param("stoph") . $q->param("stopm"),
				prio      => $q->param("prio"),
				lft       => $q->param("lft"),
				channel   => $q->param("channel"),
        directory => $q->param("directory")
      });
      AT_Write(@at);
    } else {
      my $z = 0;
      my @at;
      for(AT_Read()) {
				$z++;
				if($z != $id) {
					push(@at, $_);
				} else { 
					my $section = 0;
					($section += 1) if($q->param("title"));
					($section += 2) if($q->param("subtitle"));
					($section += 4) if($q->param("description"));
					push(@at, {
						episode   => $q->param("episode") ? $q->param("episode") : 0,
						active    => $q->param("active"),
            done      => $q->param("done"),
						pattern   => $q->param("pattern"),
						section   => $section,
						start     => $q->param("starth") . $q->param("startm"),
						stop      => $q->param("stoph") . $q->param("stopm"),
						prio      => $q->param("prio"),
						lft       => $q->param("lft"),
						channel   => $q->param("channel"),
            directory => $q->param("directory")
					});
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
  my $z = 0;

  my @at = AT_Read();
  my @new;
  if($id) {
    for(@at) {
      $z++;
      push(@new, $_) if($id != $z);
    }
    AT_Write(@new);
  } else {
    my @sorted;
    for($q->param) {
      if(/xxxx_(.*)/) {
				push(@sorted, $1);
      }
    }
   @sorted = sort({ $b <=> $a } @sorted);
    my $z = 0;
    for my $at (@at) {
      $z++;
      my $push = 1;
      for my $sorted (@sorted) {
				($push = 0) if($z == $sorted);
      }
      push(@new, $at) if($push);
    }
    AT_Write(@new);
  }
  headerForward("$MyURL?aktion=at_timer_list");
}


#############################################################################
# timeline
#############################################################################
sub prog_timeline {
  return if(UptoDate());
  my $time = $q->param("time");

  # zeitpunkt bestimmen
  my $event_time;
  my $event_time_to;

  if($time ne "") {
    my ($hour, $minute);
    if($time =~ /(\d{1,2})(\D?)(\d{1,2})/) {
      if(length($1) == 1 && length($3) == 1 && !$2) {
        $hour = $1 . $3;
      } else {
        ($hour, $minute) = ($1, $3);
      }
    } elsif($time =~ /\d/) {
      $hour = $time;
    }

    if($hour <= my_strftime("%H") && $minute < my_strftime("%M")) {
      $event_time = timelocal(
      0,
      $minute,
      $hour,
      my_strftime("%d", time + 86400),
      (my_strftime("%m", time + 86400) - 1),
      my_strftime("%Y")
      ) + 1;
    } else {
      $event_time = timelocal(
      0,
      $minute,
      $hour,
      my_strftime("%d"),
      (my_strftime("%m") - 1),
      my_strftime("%Y")
      ) + 1;
    }
  } else {
    $event_time = time();
  }

  $event_time_to = $event_time + ($CONFIG{ZEITRAHMEN} * 3600);

  # Timer parsen, und erstmal alle rausschmeissen die nicht in der Zeitzone liegen
  my $TIM;
  for my $timer (ParseTimer(0)) {
    next if($timer->{stopsse} < $event_time or $timer->{startsse} > $event_time_to);    
    my $title = (split(/\~/, $timer->{title}))[-1];
    $TIM->{$title} = $timer;
  }

  my(@show, @shows, @temp);
  my $shows;

  my @epgChannels = split(/\,/, $CONFIG{CHANNELS_WANTED});
  @epgChannels = keys(%EPG) 
    unless scalar @epgChannels;

  foreach(@epgChannels) {	# Sender durchgehen
    next unless(ChannelHasEPG($_));
    foreach my $event (sort {$a->{start} <=> $b->{start} } @{$EPG{$_}}) { # Events durchgehen
      next if($event->{stop} < $event_time or $event->{start} > $event_time_to );

      push(@show,  {
        date     => my_strftime("%d.%m.%y", $event->{start}),
        longdate => sprintf("%s., %s. %s %s",
        substr(FullDay(my_strftime("%w", $event->{start}), $event->{start}), 0, 2),
        my_strftime("%d", $event->{start}),
        FullMonth(my_strftime("%m", $event->{start})),
        my_strftime("%Y", $event->{start})),
        start    => $event->{start},
        stop     => $event->{stop},
        title    => $event->{title},
        subtitle => (length($event->{subtitle}) > 30 ? substr($event->{subtitle}, 0, 30) . "..." : $event->{subtitle}),
        progname => $event->{channel_name},
        summary  => $event->{summary},
        vdr_id   => $event->{vdr_id},
        proglink => sprintf("%s?aktion=prog_list&vdr_id=%s", $MyURL, $event->{vdr_id}),
        switchurl=> sprintf("%s?aktion=prog_switch&channel=%s", $MyURL, $event->{vdr_id}),
        infurl   => ($event->{summary} ? sprintf("%s?aktion=prog_detail&epg_id=%s&vdr_id=%s", $MyURL, $event->{event_id}, $event->{vdr_id}) : undef),
        recurl   => sprintf("%s?aktion=timer_new_form&epg_id=%s&vdr_id=%s", $MyURL, $event->{event_id}, $event->{vdr_id}),
        anchor   => $event->{event_id},
        timer    => ( defined $TIM->{ $event->{title} } && $TIM->{ $event->{title} }->{vdr_id} == $event->{vdr_id} ? 1 : 0 ),
      });
    }
    # needed for vdr 1.0.x, dunno why
    @show = sort({ $a->{vdr_id} <=> $b->{vdr_id} } @show);
    push(@{ $shows->{ $EPG{$_}->[0]->{vdr_id} } }, @show)
      if @show;
    undef @show;
  }

  my $vars = {
    shows  	=> $shows,
    now_sec	=> $event_time,
    now    	=> strftime("%H:%M", localtime($event_time)),
    datum	=> sprintf("%s., %s. %s %s",
    substr(FullDay(my_strftime("%w", time), time), 0, 2),
    my_strftime("%d", time),
    FullMonth(my_strftime("%m", time)),
    my_strftime("%Y", time)),
    nowurl 	=> $MyURL . "?aktion=prog_timeline",
    url    	=> $MyURL,
    config 	=> \%CONFIG,
  };

  my $template = TemplateNew("prog_timeline.html");
  $template->param( $vars  );

  # New Template
  my $output;
  my $out = $template->output;
  $Xtemplate->process(\$out, $vars, \$output)
    || return(header("500", "text/html", $Xtemplate->error()));

  return(header("200", "text/html", $output));
}


#############################################################################
# summary
#############################################################################
sub prog_summary {
  return if(UptoDate());
  my $time = $q->param("time");
  my $search = $q->param("search");

  # zeitpunkt bestimmen
  my $event_time;
  if($time ne "") {
    my ($hour, $minute);
    if($time =~ /(\d{1,2})(\D?)(\d{1,2})/) {
      if(length($1) == 1 && length($3) == 1 && !$2) {
				$hour = $1 . $3;
      } else {
				($hour, $minute) = ($1, $3);
      }
    } elsif($time =~ /\d/) {
      $hour = $time;
    }

    if($hour <= my_strftime("%H") && $minute < my_strftime("%M")) {
      $event_time = timelocal(
				0,
				$minute,
				$hour,
				my_strftime("%d", time + 86400),
				(my_strftime("%m", time + 86400) - 1),
				my_strftime("%Y")
			) + 1;
    } else {
      $event_time = timelocal(
				0,
				$minute,
				$hour,
				my_strftime("%d"),
				(my_strftime("%m") - 1),
				my_strftime("%Y")
			) + 1;
    }
  } else {
    $event_time = time();
  }

  my(@show, @shows, @temp);
  for(keys(%EPG)) {
    for my $event (@{$EPG{$_}}) {
      if(!$search) {
				if($CONFIG{CHANNELS_WANTED_SUMMARY}) {
					my $f = 0;
					for my $n (split(/\,/, $CONFIG{CHANNELS_WANTED})) {
						($f = 1) if($n eq $event->{vdr_id});
					}
				 next if(!$f);
				}
				next if($event_time > $event->{stop});
			} else {
				my($found);
				for my $word (split(/ +/, $search)) {
					$found = 0;
					for my $section (qw(title subtitle summary)) {
						if($event->{$section} =~ /$word/i) {
							$found = 1;
						}
					}
					if(!$found) {
						last;
					}
				}
				next if(!$found);
			}

			my $displaytext = $event->{summary};
			my $displaytitle = $event->{title};
			my $displaysubtitle = $event->{subtitle};

			$displaytext =~ s/\n/<br>\n/g;
			$displaytext =~ s/\|/<br>\n/g;
			$displaytitle =~ s/\n/<br>\n/g;
			$displaytitle =~ s/\|/<br>\n/g;
			$displaysubtitle =~ s/\n/<br>\n/g;
			$displaysubtitle =~ s/\|/<br>\n/g;

      push(@show,  {
				date     => my_strftime("%d.%m.%y", $event->{start}),
				longdate => sprintf("%s., %s. %s %s",
					substr(FullDay(my_strftime("%w", $event->{start}), $event->{start}), 0, 2),
					my_strftime("%d", $event->{start}),
					FullMonth(my_strftime("%m", $event->{start})),
					my_strftime("%Y", $event->{start})),
				start    => my_strftime("%H:%M", $event->{start}),
				stop     => my_strftime("%H:%M", $event->{stop}),
				title    => $displaytitle,
				subtitle => length($displaysubtitle) > 30 ? substr($displaysubtitle, 0, 30) . "..." : $displaysubtitle,
				progname => $event->{channel_name},
				summary  => length($displaytext) > 120 ? substr($displaytext, 0, 120) . "..." : $displaytext,
				vdr_id   => $event->{vdr_id},
				proglink => sprintf("%s?aktion=prog_list&vdr_id=%s", $MyURL, $event->{vdr_id}),
				switchurl=> sprintf("%s?aktion=prog_switch&channel=%s", $MyURL, $event->{vdr_id}),
				streamurl=> sprintf("%s?aktion=live_stream&channel=%s", $MyURL, $event->{vdr_id}),
				infurl   => $event->{summary} ? sprintf("%s?aktion=prog_detail&epg_id=%s&vdr_id=%s", $MyURL, $event->{event_id}, $event->{vdr_id}) : undef,
				recurl   => sprintf("%s?aktion=timer_new_form&epg_id=%s&vdr_id=%s", $MyURL, $event->{event_id}, $event->{vdr_id}),
        anchor   => $event->{event_id}
      });
      last if(!$search);
    }
  }

	# needed for vdr 1.0.x, dunno why
  @show = sort({ $a->{vdr_id} <=> $b->{vdr_id} } @show);

	#
	my @status;
	my $spalten = 3;
  for(my $i = 0; $i <= $#show; $i++) {
    undef(@temp);
		undef(@status);
    for(my $z = 0; $z < $spalten; $i++, $z++) {
      push(@temp, $show[$i]);
      push(@status, $show[$i]);
    }
    $i--;
    push(@shows, { day => [ @temp ], status => [ @status ] });
  }

  #
	my $template = TemplateNew("prog_summary.html");
  $template->param(
    rows   => \@shows,
    now    => strftime("%H:%M", localtime($event_time)),
    nowurl => $MyURL . "?aktion=prog_summary",
    url    => $MyURL
  );
  return(header("200", "text/html", $template->output));
}


#############################################################################
# recordings
#############################################################################
sub rec_list {
  my(@all_recordings, @recordings);

	#
  my $ffserver = `ps -ef | grep ffserver | wc -l`; 
	my $desc;
	if(!defined($q->param("desc"))) {
		$desc = 1;
	} else {
		$q->param("desc") ? ($desc = 1) : ($desc = 0);
	}
	my $sortby = $q->param("sortby");
	($sortby = "name") if(!$sortby);
	my $parent = $q->param("parent");
	if(!$parent) {
		$parent = 0;
	}

  my(@response) = SendCMD("lstr");
  for my $recording (@response) {
    chomp($recording);
    next if(length($recording) == 0);
    if($recording =~ /^No recordings available/) {
      last;
    }
    my($new);
    my($id, $date, $time, $name) = split(/ +/, $recording, 4);

    #
    if(substr($time, 5, 1) eq "*") {
      $new = 1;
      $time =~ s/\*//;
    }

	  #
		my(@tmp, @tmp2, $serie, $episode, $parent, $dirname, $dirname1);
		if($name =~ /~/) {
		    @tmp2 = split(" ", $name, 2);
		    if(scalar(@tmp2) > 1) {
			if(ord(substr($tmp2[0], length($tmp2[0])-1, 1)) == 180) {
			    @tmp = split("~", $tmp2[1]);
			    $name = "$tmp2[0] $tmp[scalar(@tmp) - 1]";
			} else {
			    @tmp = split("~", $name);
			    $name = $tmp[scalar(@tmp) - 1];
			}
		    } else {
			@tmp = split("~", $name);
			$name = $tmp[scalar(@tmp) - 1];
		}
		$dirname = $tmp[scalar(@tmp) - 2];
			$parent  = crypt($dirname, salt($dirname));
		}
	  $parent = 0 if(!$parent);

		# create subfolders
		for(my $i = 0; $i < scalar(@tmp) - 1; $i++) {
			my $recording_id = crypt($tmp[$i], salt($tmp[$i]));
			my $parent;
			if($i != 0) {
				$parent = crypt($tmp[$i - 1], salt($tmp[$i - 1]));
			} else {
				$parent = 0;
			}

			my $found = 0;
			for my $recording (@all_recordings) {
				next if(!$recording->{isfolder});
				if($recording->{recording_id} eq $recording_id && $recording->{parent} eq $parent) {
					$found = 1;
				}
			}
			if(!$found) {
				push(@all_recordings, {
					name         => $tmp[$i],
					recording_id => $recording_id,
					parent       => $parent,
					isfolder     => 1,
					date         => 0,
					time         => 0,
					sortbydate   => ($sortby eq "date") ? 1 : 0,
					sortbytime   => ($sortby eq "time") ? 1 : 0,
					sortbyname   => ($sortby eq "name") ? 1 : 0,
				  infurl       => sprintf("%s?aktion=rec_list&parent=%s", $MyURL, $recording_id)
				});
			}
		}

		#
    push(@all_recordings, {
      sse        => timelocal(undef, substr($time, 3, 2),
				substr($time, 0, 2), substr($date, 0, 2),
				(substr($date, 3, 2) - 1),
				my_strftime("%Y")),
      date       => $date,
      time       => $time,
			name       => $name,
			serie      => $serie,
			episode    => $episode,
			parent     => $parent,
      new        => $new,
      id         => $id,
			sortbydate => ($sortby eq "date") ? 1 : 0,
			sortbytime => ($sortby eq "time") ? 1 : 0,
			sortbyname => ($sortby eq "name") ? 1 : 0,
      delurl     => $MyURL . "?aktion=rec_delete&id=$id",
      editurl    => $MyURL . "?aktion=rec_edit&id=$id",
      infurl     => $MyURL . "?aktion=rec_detail&id=$id",
      streamurl  => $MyURL . "?aktion=rec_stream&id=$id"
    });
  }

	# XXX doesn't count subsub-folders
	for(@all_recordings) {
		if($_->{parent} eq $parent && $_->{isfolder}) {
			for my $recording (@all_recordings) {
				if($recording->{parent} eq $_->{recording_id}) {
					$_->{date}++;
					$_->{time}++ if($recording->{new});
				}
			}
		}
	}

	# create path array
	my @path; my $fuse = 0;
	my $rparent = $parent;
	while($rparent) {
		for my $recording (@all_recordings) {
			if($recording->{recording_id} eq $rparent) {
				push(@path, {
					name => $recording->{name},
					url  => ($recording->{recording_id} ne $parent) ?
						sprintf("%s?aktion=rec_list&parent=%s",
							$MyURL, $recording->{recording_id}) : "" });
				$rparent = $recording->{parent};
				last;
			}
		}
		$fuse++;
		last if($fuse > 100);
	}
	push(@path, {
		name => $COMMONMESSAGE{OVERVIEW},
		url  => ($parent ne 0) ?
			sprintf("%s?aktion=rec_list&parent=%s", $MyURL, 0) : "" });
	@path = reverse(@path);

	# filter
	if(defined($parent)) {
		for my $recording (@all_recordings) {
			if($recording->{parent} eq $parent) {
				push(@recordings, $recording);
			}
		}
	} else {
		@recordings = @all_recordings;
	}
  

  #
	if($sortby eq "time") {
		if(!$desc) {
			@recordings = sort({ $b->{time} <=> $a->{time} } @recordings);
		} else {
			@recordings = sort({ $a->{time} <=> $b->{time} } @recordings);
		}
  } elsif($sortby eq "name") {
		if(!$desc) {
			@recordings = sort({ lc($b->{name}) cmp lc($a->{name}) } @recordings);
		} else {
			@recordings = sort({ lc($a->{name}) cmp lc($b->{name}) } @recordings);
		}
  } elsif($sortby eq "date") {
		if(!$desc) {
			@recordings = sort({ $a->{sse} <=> $b->{sse} } @recordings);
		} else {
			@recordings = sort({ $b->{sse} <=> $a->{sse} } @recordings);
		}
  }
	$desc ? ($desc = 0) : ($desc = 1);

	#
	my($total, $minutes_total, $free, $minutes_free, $percent) = VideoDiskFree();


	my $template = TemplateNew("rec_list.html");
  $template->param(
    recloop         => \@recordings,
    sortbydateurl   => "$MyURL?aktion=rec_list&parent=$parent&sortby=date&desc=$desc&parent=$parent",
    sortbytimeurl   => "$MyURL?aktion=rec_list&parent=$parent&sortby=time&desc=$desc&parent=$parent",
    sortbynameurl   => "$MyURL?aktion=rec_list&parent=$parent&sortby=name&desc=$desc&parent=$parent",
		sortbydate      => ($sortby eq "date") ? 1 : 0,
		sortbytime      => ($sortby eq "time") ? 1 : 0,
		sortbyname      => ($sortby eq "name") ? 1 : 0,
		desc            => $desc,
		disk_total      => $total,
		disk_free       => $free,
		disk_percent    => $percent,
		minutes_free    => $minutes_free,
		minutes_total   => $minutes_total,
		path            => \@path,
		url             => $MyURL,
    help_url        => HelpURL("rec_list"),
  );
  return(header("200", "text/html", $template->output));
}

sub rec_detail {
  my($id) = $q->param('id');

  #
  my($i, $title);
  for(SendCMD("lstr")) {
    ($i, undef, undef, $title) = split(/ +/, $_, 4);
    last if($id == $i);
  }
  chomp($title);

  #
  my($text); my($first) = 1;
  my($result) = SendCMD("lstr $id");
  if($result !~ /No summary availab/i) {
    for(split(/\|/, $result)) {
      if($_ ne (split(/\~/, $title))[1] && "%" . $_ ne (split(/\~/, $title))[1] && "@" . $_ ne (split(/\~/, $title))[1]) {
        if($first && $title !~ /\~/ && length($title) < 20) {
          $title .= "~" . $_;
          $first = 0;
        } else {
        	if($text) {
        		$text .= "<br>";
        	}
          $text .= "$_ ";
        }
      }
    }
  }

  #
  $title =~ s/\~/ - /;

	my $template = TemplateNew("prog_detail.html");
  $template->param(
    text  => $text ? $text : "",
    title => $title
  );
  return(header("200", "text/html", $template->output));	
}

sub rec_delete {
  my($id) = $q->param('id');
  if($id) {
    SendCMD("delr $id");
  } else {
    for($q->param) {
      if(/xxxx_(.*)/) {
				SendCMD("delr $1");
      }
    }
  }
  CloseSocket();
  return(headerForward(RedirectToReferer("$MyURL?aktion=rec_list")));
}

sub rec_edit {

  my $id   = $q->param("id");
  my($i, $title);

  for(SendCMD("lstr")) {
    ($i, undef, undef, $title) = split(/ +/, $_, 4);
    last if($id == $i);
  }
  chomp($title);
  
  my $template = TemplateNew("rec_edit.html");
  $template->param(
    url      => $MyURL,
    title    => $title,
    id       => $id,
  );
  return(header("200", "text/html", $template->output));
}

sub rec_rename {
  my($id) = $q->param('id');
  my($nn) = $q->param('nn');
  if($id) {
    SendCMD("RENR $id $nn");
# } else {
#   for($q->param) {
#     if(/xxxx_(.*)/) {
#			SendCMD("renr $1 $_[0]");
#     }
#   }
  }
  CloseSocket();
  headerForward("$MyURL?aktion=rec_list");
}

#############################################################################
# configuration
#############################################################################
sub conf_list {
  return if(UptoDate());

	sub ApplyConfig {
    for($q->param) {
      if(/[A-Z]+/) {
				$CONFIG{$_} = $q->param($_);
      }
    }
    #
    LoadTranslation();
  }

	sub WriteConfig {
		open(CONF, ">$CONFFILE") || print "Can't open $CONFFILE! ($!)\n";
		for my $key (sort(keys(%CONFIG))) {
			print CONF "$key = $CONFIG{$key}\n";
		}
		close(CONF);
	}
  
  if($q->param("submit") eq ">>>>>") {
    for my $vdr_id ($q->param("all_channels")) {
      $CONFIG{CHANNELS_WANTED} = csvAdd($CONFIG{CHANNELS_WANTED}, $vdr_id); 
    }
    ApplyConfig(); WriteConfig();
  } elsif($q->param("submit") eq "<<<<<") {
    for my $vdr_id ($q->param("selected_channels")) {
      $CONFIG{CHANNELS_WANTED} = csvRemove($CONFIG{CHANNELS_WANTED}, $vdr_id); 
    }
    ApplyConfig(); WriteConfig();
  } elsif($q->param("save")) {
    ApplyConfig(); WriteConfig();
  } elsif($q->param("apply")) {
    ApplyConfig();
  }

	#
	my(@loginpages);
  my $i = 0;
	for my $loginpage (@LOGINPAGES) {
		push(@loginpages, {
			id   => $i,
			name => $LOGINPAGES_DESCRIPTION[$i],
			current => ($CONFIG{LOGINPAGE} == $i) ? 1 : 0
		});
		$i++;
	}

  #
  my @lang;
  for my $dir (<$TEMPLATEDIR/*>) {
    next if(!-d $dir);
    $dir =~ s/.*\///g;
    my $found = 0;
    for(@lang) { ($found = 1) if($1 && ($_->{name} eq $1)); }
    if(!$found) {
      push(@lang, {
				name   => $dir,
				aklang => ($CONFIG{LANGUAGE} eq $dir) ? 1 : 0,
      });
    }
  }

  #
  my (@all_channels, @selected_channels);
  for my $channel (@CHAN) {
    #
    push(@all_channels, {
      name   => $channel->{name},
      vdr_id => $channel->{vdr_id}
    });

    #
    my $found = 0;
    for(split(",", $CONFIG{CHANNELS_WANTED})) {
      if($_ eq $channel->{vdr_id}) {
				$found = 1;
      }
    }
    next if !$found;
    push(@selected_channels, {
      name   => $channel->{name},
      vdr_id => $channel->{vdr_id}
    });
  }

  my @skinlist;
  foreach my $file (glob(sprintf("%s/%s/*",$TEMPLATEDIR, $CONFIG{LANGUAGE}))) {
    my $name = (split('\/', $file))[-1];
    push(@skinlist,{
      name => $name,
      sel => ($CONFIG{SKIN} eq $name ? 1 : 0)
    }) if(-d $file);
  }

  my $template = TemplateNew("config.html");
  $template->param(
    %CONFIG,
    LANGLIST          => \@lang,
    ALL_CHANNELS      => \@all_channels,
    SELECTED_CHANNELS => \@selected_channels,
		LOGINPAGES        => \@loginpages,
    SKINLIST          => \@skinlist,
    url               => $MyURL,
    help_url          => HelpURL("help_url"),
  );
  return(header("200", "text/html", $template->output));
}

#############################################################################
# remote control
#############################################################################
sub rc_show {
	my $template = TemplateNew("rc.html");
  $template->param(
    surl_0         => $MyURL . "?aktion=rc_hitk&key=0",
    surl_1         => $MyURL . "?aktion=rc_hitk&key=1",
    surl_2         => $MyURL . "?aktion=rc_hitk&key=2",
    surl_3         => $MyURL . "?aktion=rc_hitk&key=3",
    surl_4         => $MyURL . "?aktion=rc_hitk&key=4",
    surl_5         => $MyURL . "?aktion=rc_hitk&key=5",
    surl_6         => $MyURL . "?aktion=rc_hitk&key=6",
    surl_7         => $MyURL . "?aktion=rc_hitk&key=7",
    surl_8         => $MyURL . "?aktion=rc_hitk&key=8",
    surl_9         => $MyURL . "?aktion=rc_hitk&key=9",

    surl_power     => $MyURL . "?aktion=rc_hitk&key=Power",

    surl_ok        => $MyURL . "?aktion=rc_hitk&key=Ok",

    surl_menu      => $MyURL . "?aktion=rc_hitk&key=Menu",
    surl_back      => $MyURL . "?aktion=rc_hitk&key=Back",

    surl_up        => $MyURL . "?aktion=rc_hitk&key=Up",
    surl_down      => $MyURL . "?aktion=rc_hitk&key=Down",
    surl_left      => $MyURL . "?aktion=rc_hitk&key=Left",
    surl_right     => $MyURL . "?aktion=rc_hitk&key=Right",

    surl_red       => $MyURL . "?aktion=rc_hitk&key=Red",
    surl_green     => $MyURL . "?aktion=rc_hitk&key=Green",
    surl_blue      => $MyURL . "?aktion=rc_hitk&key=Blue",
    surl_yellow    => $MyURL . "?aktion=rc_hitk&key=Yellow",

    surl_volplus   => $MyURL . "?aktion=rc_hitk&key=VolumePlus",
    surl_volminus  => $MyURL . "?aktion=rc_hitk&key=VolumeMinus",
		url            => sprintf("%s?aktion=grab_picture", $MyURL),
    host           => $CONFIG{VDR_HOST}
  );
  return(header("200", "text/html", $template->output));
}

sub rc_hitk {
  my $key = $q->param("key");
	if($key eq "VolumePlus") {
		$key = "Volume+";
	}
	if($key eq "VolumeMinus") {
		$key = "Volume-";
	}
  SendCMD("hitk $key");
  #XXX
	SendFile("bilder/spacer.gif");
}

sub tv_show {
	my $template = TemplateNew("tv.html");
  $template->param(
		url => sprintf("%s?aktion=grab_picture", $MyURL),
    host => $CONFIG{VDR_HOST}
  );
  return(header("200", "text/html", $template->output));
}

sub show_help {
  my $area = $q->param("area");
  my $text;
  if(length($HELP{$area}) == 0) {
    $text = $HELP{ENOHELPMSG};
  } else {
    $text = $HELP{$area};
  }
  my $template = TemplateNew("prog_detail.html"); # XXX eigenes Template?
  $template->param(text => $text);
  return(header("200", "text/html", $template->output));
}

#############################################################################
# experimental
#############################################################################
sub grab_picture {
	my $size = $q->param("size");
	my $file = new File::Temp("vdr-XXXXX", UNLINK => 1, SUFFIX => ".jpg");
	my $maxwidth = 768;
	my $maxheight = 576;
	my($width, $height);
	if($size eq "full") {
		($width, $height) = ($maxwidth, $maxheight);
	} elsif($size eq "half") {
		($width, $height) = ($maxwidth / 2, $maxheight / 2);
	} elsif($size eq "quarter") {
		($width, $height) = ($maxwidth / 4, $maxheight / 4);
	} else {
		($width, $height) = ($maxwidth / 4, $maxheight / 4);
	}
		
	SendCMD("grab $file jpeg 70 $width $height");
	#SendCMD("grab $file jpeg");
	if(-e $file && -r $file) {
		return(header("200", "image/jpeg", ReadFile($file)));
	} else {
		print "Expected $file does not exist.\n";
    print "Obviously VDR Admin could not find the screenshot file. Ensure that:\n";
    print " - VDR has the rights to write $file\n";
    print " - VDR and VDR Admin run on the same machine\n";
    print " - VDR Admin may read $file\n";
    print " - VDR has access to /dev/video* files\n";
    print " - you have a full featured card\n";
	}
}

sub force_update {
	UptoDate(1);
	RedirectToReferer("$MyURL?aktion=prog_summary");
}

#############################################################################
# Authentication
#############################################################################

sub subnetcheck {
    my $ip=$_[0];
    my $net=$_[1];
    my ($ip1,$ip2,$ip3,$ip4,$net_base,$net_range,$net_base1,$net_base2,
        $net_base3,$net_base4,$bin_ip,$bin_net);

    ($ip1,$ip2,$ip3,$ip4) = split(/\./,$ip);
    ($net_base,$net_range) = split(/\//,$net);
    ($net_base1,$net_base2,$net_base3,$net_base4) = split(/\./,$net_base);

    $bin_ip  = unpack("B*", pack("C", $ip1));
    $bin_ip .= unpack("B*", pack("C", $ip2));
    $bin_ip .= unpack("B*", pack("C", $ip3));
    $bin_ip .= unpack("B*", pack("C", $ip4));

    $bin_net  = unpack("B*", pack("C", $net_base1));
    $bin_net .= unpack("B*", pack("C", $net_base2));
    $bin_net .= unpack("B*", pack("C", $net_base3));
    $bin_net .= unpack("B*", pack("C", $net_base4));

    if (substr($bin_ip,0,$net_range) eq substr($bin_net,0,$net_range)) {
        return 1;
    } else {
        return 0;
    }
}

#############################################################################
# communikation with vdr
#############################################################################
package SVDRP;

sub true       () { main::true(); }
sub false      () { main::false(); };
sub LOG_VDRCOM () { main::LOG_VDRCOM(); };
sub CRLF       () { main::CRLF(); };

my($SOCKET, $EPGSOCKET, $query, $connected, $epg);

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $self = { };
	bless($self, $class);
	$connected = false;
	$query = false;
	$epg = false;
	return $self;
}

sub myconnect {
	my $this = shift;
	if ( $epg && $CONFIG{EPG_DIRECT}) {
	  main::Log(LOG_VDRCOM, "LOG_VDRCOM: open EPG $CONFIG{EPG_FILENAME}");
	  open($EPGSOCKET,$CONFIG{EPG_FILENAME}) || main::HTMLError(sprintf("Failed to open %s", $CONFIG{EPG_FILENAME}));
	  return;
	}
	main::Log(LOG_VDRCOM, "LOG_VDRCOM: connect to $CONFIG{VDR_HOST}:$CONFIG{VDR_PORT}");
	
	$SOCKET = IO::Socket::INET->new(
		PeerAddr => $CONFIG{VDR_HOST}, 
		PeerPort => $CONFIG{VDR_PORT}, 
		Proto => 'tcp'
	) || main::HTMLError(sprintf($ERRORMESSAGE{CONNECT_FAILED}, $CONFIG{VDR_HOST}));

	my $line;
	$line = <$SOCKET>;
	$connected = true;
}

sub close {
	my $this = shift;
  if( $epg && $CONFIG{EPG_DIRECT} ) {
    main::Log(LOG_VDRCOM, "LOG_VDRCOM: closing EPG");
    close $EPGSOCKET;
    $epg=false;
    return;
  }
	if($connected) {
		main::Log(LOG_VDRCOM, "LOG_VDRCOM: closing connection");
		command($this, "quit");
		readoneline($this);
		close $SOCKET if $SOCKET;
		$connected = false;
	}
}

sub command {
	my $this = shift;
	my $cmd = join("", @_);
	
  if ( $cmd =~ /lste/ && $CONFIG{EPG_DIRECT} )	{
    $epg=true;
    main::Log(LOG_VDRCOM, sprintf("LOG_VDRCOM: special epg "));
  } else {
    $epg=false;
  }
	if(!$connected || $epg) {
		myconnect($this);
	}
  if ( $epg ) {
    $query = true;
    return;
  }
	
	main::Log(LOG_VDRCOM, sprintf("LOG_VDRCOM: send \"%s\"", $cmd));
	$cmd = $cmd . CRLF;
	if($SOCKET) {
		my $result = send($SOCKET, $cmd, 0);
		if($result != length($cmd)) {
			main::HTMLError($ERRORMESSAGE{SEND_COMMAND}, $CONFIG{VDR_HOST});
		} else {
			$query = true;
		}
	}
}

sub readoneline {
	my $this = shift;
	my $line;

  if ( $epg && $CONFIG{EPG_DIRECT} ) {
    $line = <$EPGSOCKET>;
    $line =~ s/\n$//;
    main::Log(LOG_VDRCOM, sprintf("LOG_VDRCOM: EPGread \"%s\"", $line));
    $query=true;
    return($line);
  }

	if($connected && $query) {
		$line = <$SOCKET>;
		$line =~ s/\r\n$//;
		if(substr($line, 3, 1) ne "-") {
			$query = 0;
		}
		$line = substr($line, 4, length($line));
		main::Log(LOG_VDRCOM, sprintf("LOG_VDRCOM: read \"%s\"", $line));
		return($line);
	} else {
		return undef;
	}
}
#
#############################################################################

# EOF
