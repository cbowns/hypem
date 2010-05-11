#!/usr/bin/perl

use DBI;
use Data::Dumper;
use Log::Log4perl(":easy");
use strict;
use warnings;
use Params::Validate;

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
if (0) {
	my @count = ( 1 .. 5 );
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
}

# ===========
# = twitter =
# ===========

my @count = ( 1 .. 5 );
foreach my $number (@count) {
	my $twitterFile = "feed.twitter.$number.html";

	# feeds are 1-5:
	my $twitterUrl = "http://hypem.com/twitter/popular/lastweek/$number/";

	if ( !-e $twitterFile ) {
		$logger->debug("curling the url: $twitterUrl");
`curl -A "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_4; en-us) AppleWebKit/533.8 (KHTML, like Gecko) Version/4.1 Safari/533.8" $twitterUrl -o $twitterFile`;

		# slurp up the file
		open FILE, "$twitterFile";
		my @lines = <FILE>;
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

			# $logger->debug($line);
			# $logger->debug("jsFlag: $jsFlag");

			# and shove them back into the file.
			print FILE $line if ($jsFlag);
		}
		close FILE;
		
		# Don't ask.
		my $jsonRegex = '\W+<script type="text/javascript">\W+trackList\[document\.location\.href\]\.push\(\{((.|\n)*)\}\);';
		
		# trackList[document.location.href].push({
		# 			type:'normal',
		# 			id:'1036102',
		# 			postid:'1073828',
		# 			time:'190',
		# 			ts: '1265848553',
		# 			fav:'0',
		# 			key: '4c5079a33013ce653d6100a40447423a',
		# 			imeem_id:'',
		# 			artist:'Light Alive',
		# 			song:'Trust Revenge',
		# 			amazon:'',
		# 			itunes:'',
		# 			emusic:'',
		# 			exact_track_avail:'0'
		#         });
		
	}
	else {
		$logger->debug(
			"file $twitterFile already exists, using filesystem cache");
	}

	# ==========================
	# = parse the twitter html =
	# ==========================

	# parse out the tree
	my $p1 = new XML::Parser( Style => 'Tree' );
	my $twitterTree = $p1->parsefile($twitterFile);

	# recurse down a bit to find the channel subtree:
	my @search = ( 'rss', 'channel' );
	my $findRoot = $twitterTree;
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
