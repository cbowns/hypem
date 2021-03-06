#!/usr/bin/perl

use DBI;
use Data::Dumper;
use Log::Log4perl(":easy");
use strict;
use warnings;
use Params::Validate;
use Switch;

use XML::Parser;

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
use Hypem::Database;

my $dbPath = Hypem::Database::DEFAULT_DB_NAME();

my $createTable = ( !-e $dbPath );

my $db = Hypem::Database->new();

if ( !defined($db) ) {
	$logger->error("database came back undef; wtf?");
	exit 1;
}

if ($createTable) {
	$logger->debug("new DB file, creating the tables");
	$db->createTable();
}

# map of good ascii values for text filtering
my %good = map { $_ => 1 } ( 9, 10, 13, 32 .. 127 );

# ==============================
# = pull down the popular feed =
# ==============================
my @count;
# if (0) {
	@count = ( 1 .. 5 );
	foreach my $number (@count) {
		my $popularFile = "feed.popular.$number.xml";

		# feeds are 1-5:
		my $popularUrl =
		  "http://hypem.com/feed/popular/lastweek/$number/feed.xml";

		if ( !-e $popularFile ) {
			$logger->debug("curling the url: $popularUrl");
`curl -A "Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0)" $popularUrl -o $popularFile`;

			# slurp up the file
			open FILE, "$popularFile";
			my @lines = <FILE>;
			close FILE;

			# pull out non-ascii chars
			open FILE, ">$popularFile" or die $!;
			foreach my $line (@lines) {
				$line =~ s/(.)/$good{ord($1)} ? $1 : ' '/eg;

				# and shove them back into the file.
				print FILE $line;
			}
			close FILE;

		}
		else {
			$logger->debug(
				"file $popularFile already exists, using filesystem cache");
		}

		# ==========================
		# = parse the popular feed =
		# ==========================

		# parse out the tree
		my $p1 = new XML::Parser( Style => 'Tree' );
		my $popularTree = $p1->parsefile($popularFile);

		# recurse down a bit to find the channel subtree:
		my @search = ( 'rss', 'channel' );
		my $findRoot = $popularTree;
		foreach my $currentSearch (@search) {
			$findRoot = findUntil( $findRoot, $currentSearch );
		}

		# get a list of items
		my $items = treeToArray( $findRoot, 'item' );
		foreach my $item ( @{$items} ) {
			my $row = {};
			my $name = findUntil( $item, 'title' );
			$name = $name->[2];
			$row->{name} = trim($name);

			my $url = findUntil( $item, 'link' );
			$url = findUntil( $url, 'http://hypem.com', 1 );
			$row->{url} = $url;

			my $date = findUntil( $item, 'pubDate' );
			$date = $date->[2];
			$row->{'date added'} = $date;

			$db->insert($row);
			$logger->debug("Just inserted $row->{ID}");
		}
	}
# }

# ===========
# = twitter =
# ===========

@count = ( 1 .. 5 );
foreach my $number (@count) {
	my $twitterFile = "feed.twitter.$number.html";

	# feeds are 1-5:
	my $twitterUrl = "http://hypem.com/twitter/popular/lastweek/$number/";

	my @lines;
	if ( !-e $twitterFile ) {
		$logger->debug("curling the url: $twitterUrl");
`curl -A "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_4; en-us) AppleWebKit/533.8 (KHTML, like Gecko) Version/4.1 Safari/533.8" $twitterUrl -o $twitterFile`;

		# slurp up the file
		open FILE, "$twitterFile";
		@lines = <FILE>;
		close FILE;

		# pull out non-ascii chars
		open FILE, ">$twitterFile" or die $!;
		foreach my $line (@lines) {
			$line =~ s/(.)/$good{ord($1)} ? $1 : ' '/eg;

			# and shove them back into the file.
			print FILE $line;
		}
		close FILE;

		# pull out javascript snippets
		open FILE, ">$twitterFile" or die $!;
		my $jsFlag = 0;
		foreach my $line (@lines) {
			$jsFlag = 1 if ( $line =~ m/<script type="text\/javascript">/ );
			$jsFlag = 0 if ( $line =~ m/<\/script>/ );

			# and shove them back into the file.
			print FILE $line if ($jsFlag);
		}
		close FILE;

		open FILE, ">$twitterFile" or die $!;
		my $keepFlag = my $leadingKeepFlag = 0;
		foreach my $line (@lines) {
			$keepFlag = 1 if ($leadingKeepFlag);
			# pull out a subset of the JS and put it back into the file.
			$leadingKeepFlag = 1 if ( $line =~ m/trackList\[document\.location\.href\]\.push\(/ );
			if ( $line =~ m/}\);/ ) {
				print FILE "\n" if ($keepFlag == 1); # only print this at the end of our records.
				$keepFlag = $leadingKeepFlag = 0;
			}

			print FILE $line if ($keepFlag);
		}
		close FILE;
		open FILE, "$twitterFile";
		@lines = <FILE>;
		close FILE;
	}
	else {
		$logger->debug(
			"file $twitterFile already exists, using filesystem cache");
		# slurp up the file
		open FILE, "$twitterFile";
		@lines = <FILE>;
		close FILE;
	}

	my ($id, $artist, $song, $ts);
	# Read all lines until $line is just a newline.
	# Then parse out id, ts, artist, song.
	my $record;
	foreach my $line (@lines) {
		chomp($line);
		$line = nomWhiteSpace($line);

		$record .= $line . "\n";

		# run until we hit a newline; that's our record delimiter.
		if ($line eq '' ) {
			if ( !( $id and $ts and $song) ) {
				$logger->error("I'm under the impression that I reached the end of a record, but I couldn't find the fields I wanted.");
				$logger->error($record);
			}
			else {
				my $row = {};

				$row->{name} = trim("$artist - $song");

				# strip backslashes out, now that we've got our final string.
				$row->{name} =~ s/\\//g;
				$row->{url} = "http://hypem.com/track/$id";
				$row->{'date added'} = $ts;

				$db->insert($row);
				$logger->debug("Just inserted $row->{ID} for artist [$artist], song [$song], url [$row->{url}]");

				undef ($id); undef ($ts); undef ($song); undef ($artist); undef ($record);
			}
		}
		
		# whatever I match here needs to slurp up newlines and/or convert them to plain ol' whitespace.

		if ( $line =~ /^\W*(song|ts|id|artist):\W*'(.*)',\W*$/ ) {
			switch ($1) {
				case "song"   { $song   = $2 }
				case "ts"     { $ts     = $2 }
				case "id"     { $id     = $2 }
				case "artist" { $artist = $2 }
				else          { $logger->warn("Fell through switch statement!"); }
			}
		}
	}
}

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

	# 	$logger->debug(
	# "sub findUntil: looking for $searchString, literalMatch is $literalMatch"
	# 	);

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

# Removes leading and trailing whitespace
sub trim {
	my $string = shift(@_);

	$string =~ s/^\s+//;
	$string =~ s/\s+$//;

	return $string;
}

=head2 treeToArray

Convert a tree structure to an array of its first-level hashes.
Give it a tree root a key that signifies your item (a la findUntil), and it'll push them into an array for you.

Usage:

	my @items = treeToArray($treeRoot, 'item');

=cut

sub treeToArray {
	my ( $treeRoot, $searchString ) = validate_pos( @_, 1, 1 );

	$logger->debug("sub treeToArray: looking for items matching $searchString");

	my @return;

	my $count = 0;
	foreach my $test ( @{$treeRoot} ) {
		if ( defined( $treeRoot->[$count] ) ) {
			push( @return, $treeRoot->[ $count + 1 ] )
			  if ( $treeRoot->[$count] =~ $searchString );
			$count++;
		}
	}

	return \@return;
}

# ----------------------------------------
# remove white space from ends of a string
# example from the Perl Cookbook, page 30.
# ----------------------------------------
sub nomWhiteSpace {
	my ( $line ) = validate_pos( @_, 1 );
	
	my @toRet = @_;
    for (@toRet) {
        s/^\s+//;
        s/\s+$//;
    }
    return wantarray ? @toRet : $toRet[0];
}
