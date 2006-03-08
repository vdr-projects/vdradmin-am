#!/usr/bin/perl

use strict;

if(scalar(@ARGV) != 3) {
	print("Usage: convert.pl <vdradmin-am config> <timers in> <timers out>\n");
	print("\t<vdradmin-am config> VDRAdmin-AM's vdradmind.conf\n");
	print("\t<timers in>          Source timers.conf\n");
	print("\t<timers out>         Destination timers.conf\n");
	exit 1;
}

my %CONFIG;
my $CONFFILE = @ARGV[0];
my $timers_in = @ARGV[1];
my $timers_out = @ARGV[2];

ReadConfig();

print("Converting $timers_in to $timers_out\n");
my $in = open(FH_IN, "<$timers_in") if(-e "$timers_in");
my $out = open(FH_OUT, ">$timers_out");
if($in and $out) {
	while(<FH_IN>) {
		chomp;
		s/#.*//;
		s/^\s+//;
		s/\s+$//;
		next unless length;
		my ($status, $channel, $day, $start, $stop, $priority, $lifetime, $file, $aux) = split(":", $_);
		my $autotimer = 1 if($status & 0x8000);
		my $active = $status & 0x7FFF;
		my $event_id = $status >> 16;
		if($autotimer) {
			$autotimer = 2 if($event_id);
			$aux .= "|" if($aux);
			$aux .= "<vdradmin-am><epgid>$event_id</epg_id><autotimer>$autotimer</autotimer><bstart>$CONFIG{TM_MARGIN_BEGIN}</bstart><bstop>$CONFIG{TM_MARGIN_END}</bstop></vdradmin-am>";
		}
		print(FH_OUT "$active:$channel:$day:$start:$stop:$priority:$lifetime:$file:$aux\n");
	}
	close(FH_IN);
	close(FH_OUT);
	print("\nNOTE:\n");
	print("Please check the new timers.conf for errors before replacing the old timers.conf!\n");
} else {
	print("Failed to open files!\n");
	exit 1;
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
		print "$CONFFILE doesn't exist. Exiting\n";
		exit(1);
	}
	return(0);
}
