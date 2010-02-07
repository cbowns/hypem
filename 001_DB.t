#!/usr/bin/perl

use strict;
use warnings;
use Log::Log4perl(":easy");

use Test::More;
plan tests => 3;

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

exit;

