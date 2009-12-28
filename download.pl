#!/usr/bin/perl

use DBI;
use Data::Dumper;
use Log::Log4perl(":easy");
use strict;
use warnings;

unless ( Log::Log4perl->initialized() ) {
    my $config = '
        log4perl.rootLogger                                 = DEBUG, Screen
        log4perl.oneMessagePerAppender                      = 1
        log4perl.appender.Screen                            = Log::Log4perl::Appender::Screen 
        log4perl.appender.Screen.layout                     = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Screen.layout.ConversionPattern   = %d %p: %m%n
        ';
    Log::Log4perl->init( \$config );
}

my $path = "database.sqlite3";

my $db = DBI->connect( "dbi:SQLite:$path", "", "" );
if ( !defined($db) ) {
    exit 1;
}

# my $longLine = 'CREATE TABLE "song" (
#     "type" TEXT); ';
#
# $db->do($longLine) or die "$DBI::errstr\n";

my $popularFile = "feed.popular.xml";
my $popularUrl  = "http://hypem.com/feed/popular/lastweek/1/feed.xml";

if ( !-e $popularFile ) {
    DEBUG("curling the url: $popularUrl");

    # `curl http://cbowns.com/ -o $popularFile`;
    `curl -A "Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0)" $popularUrl -o feed.popular.xml`;
}
else {
    DEBUG("file $popularFile already exists");
}

use XML::Parser;

my $p1 = new XML::Parser( Style => 'Tree' );
$p1->parsefile($popularFile);
