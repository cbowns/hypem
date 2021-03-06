#!/usr/bin/perl

use strict;
use warnings;
use Log::Log4perl(":easy");

use Test::More;
plan tests => 10;

# let us look up our plib path and whatnot.
use File::Basename;
use FindBin;
use Data::Dumper;

sub nukeDB {
	my $salt = int( rand(100000) );
	my $path = "/tmp/db.$salt.sqlite3";
	`rm -f $path`;
	print "$path\n";
	return $path;
}

# Remove previous test file if it exists
print "database for this test: ";
my $path = nukeDB();
my $db;    # global to this test.

# ==========================
# = Let the testing begin! =
# ==========================
useAndInstantiate();
createTable();
insertItems();

# cleanup
print "cleaning up. new database: ";
$path = nukeDB();

sub useAndInstantiate {

	# Can we use the necessary classes?
	use_ok('Hypem::Database');

	# Instantiate a DB object:
	$db = Hypem::Database->new($path);
	isa_ok( $db, 'Hypem::Database' );

}

sub createTable {
	ok( $db->createTable(), "table created successfully" );
}

sub insertItems {
	my $item = { name => 'Test Song', url => 'http://cbowns.com/testsong' };
	is( $db->IDForName( $item->{name} ),
		undef, "there's no ID in the database for this name." );
	ok( $db->insert($item) > 0, "inserted an item" );
	is( $db->IDForName( $item->{name} ),
		1, "and the ID returned by the DB is valid" );
	my $itemTwo = { name => 'Test Song', url => 'http://cbowns.com/testsong2' };
	ok( $db->insert($itemTwo) > 0, "inserted a second item" );
	is( $db->numberOfItems(),        1, "There's one item in the DB" );
	is( scalar( $db->URLsForID(1) ), 2, "and there's two URLs for the item" );
	is( $db->IDForName( $itemTwo->{name} ),
		1, "and the ID returned by the DB is the same as the first item" );
}

# is( $returnID, 1, "first inserted row has ID 1" );
# isnt( $wr1->ID(), defined $wr1->ID(), "and the row has no ID defined yet" );

