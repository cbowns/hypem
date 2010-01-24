#!/usr/bin/perl

use DBI;
use Data::Dumper;
use Log::Log4perl(":easy");
use strict;
use warnings;
use Params::Validate;

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

my $logger = Log::Log4perl::get_logger();

# =================================
# = database stuff: create the db =
# =================================
my $path        = "database.sqlite3";
my $createTable = ( !-e $path );

my $db = DBI->connect( "dbi:SQLite:$path", "", "" );
exit 1 if !defined($db);

if ($createTable) {
	DEBUG("creating a new table");

	my $firstTable = 'CREATE TABLE "song" (
		"ID" integer not null primary key autoincrement,
		"name" text,
"date added" text ); ';

	$db->do($firstTable) or die "$DBI::errstr\n";

	my $secondTable = 'create table "url" (
		"ID" integer not null primary key autoincrement,
		"url" text,
"songID" integer ); ';

	$db->do($secondTable) or die "$DBI::errstr\n";
}

# ==============================
# = pull down the popular feed =
# ==============================
my $popularFile = "feed.popular.xml";
my $popularUrl  = "http://hypem.com/feed/popular/lastweek/1/feed.xml";

if ( !-e $popularFile ) {
	DEBUG("curling the url: $popularUrl");

	# `curl http://cbowns.com/ -o $popularFile`;
`curl -A "Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0)" $popularUrl -o feed.popular.xml`;
}
else {
	DEBUG("file $popularFile already exists, using filesystem cache");
}

# ===================
# = start to parse! =
# ===================

use XML::Parser;

my $p1 = new XML::Parser( Style => 'Tree' );
my $popularTree = $p1->parsefile($popularFile);

my @search = ( 'rss', 'channel', 'item', 'link', 'http://hypem.com' );
my $currentLevel = $popularTree;
foreach my $currentSearch (@search) {
	$currentLevel =
	  findUntil( $currentLevel, $currentSearch,
		( $currentSearch =~ "http" ? 1 : 0 ) );
}
$logger->debug( "Currently found: " . Dumper($currentLevel) );

=head2 findUntil

Finds the array item that matches searchString (I'm doing a =~ with it), and returns $arrayRef->[position + 1].


Usage:

	my $foundVal = findUntil($arrayRef, "searchString");

If you want $arrayRef->[position], pass a 1 for literalMatch:

	my $foundVal = findUntil($arrayRef, "searchString", 1);

=cut

sub findUntil {
	my ( $itemRef, $searchString, $literalMatch ) =
	  validate_pos( @_, 1, 1, { default => 0 } );
	$logger->debug("looking for $searchString, literalMatch is $literalMatch");

	my $count = 0;
	foreach my $test ( @{$itemRef} ) {
		if ( defined( $itemRef->[$count] ) ) {
			return $itemRef->[ $count + ( $literalMatch ? 0 : 1 ) ]
			  if ( $itemRef->[$count] =~ $searchString );
			$count++;
		}
		else {
			$logger->error("never found $searchString, returning null");
			return;
		}
	}
}

# twitter will be harder.
# curl -A "Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0)"
# I want: http://hypem.com/twitter/popular/lastweek/1/ THROUGH http://hypem.com/#/twitter/popular/lastweek/5/
