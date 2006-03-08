#!/usr/bin/perl

##
# Simple UDP Server/Client to display messages in VDR
#
# 22.02.2004 by Thomas Koch <tom at linvdr dot org>
##

use IO::Socket;
use IO::Socket::INET 1.26;
use strict;

my $myself = join("", $0 =~ /^.*\/(.*)/);

# Server
if($myself eq "udpd.pl") {
  my $pid = fork();
  if($pid != 0) {
    exit(0);
  }
  my($Socket) = IO::Socket::INET->new( 
    Proto => 'udp',
    LocalPort => 4711,
    Reuse => 1
  ) || die;				     
  my $message;
  while($Socket->recv($message, 1024)) {
    my($port, $ipaddr) = sockaddr_in($Socket->peername);
    my $hishost = gethostbyaddr($ipaddr, AF_INET);
    system("logger udpd: client $hishost with message \\'$message\\'");
    for(my $z = 0; $z < 3; $z++) {
      for(my $i = 0; $i < 3; $i++) {
        system("svdrpsend.pl mesg $message 2>/dev/null >/dev/null");
      }
      sleep(3);
    }
  }
  exit(0);
}

# Client
if($myself eq "udpc.pl") {
  my $message = join(" ", @ARGV);
  my $Socket = IO::Socket::INET->new(
    PeerAddr => inet_ntoa(INADDR_BROADCAST),
    PeerPort => 4711, 
    Proto => 'udp',
    Broadcast => 1
  ) || die;
  my $result = $Socket->send($message);
}

