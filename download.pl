#!/usr/bin/perl

use DBI;
use Data::Dumper;
use File::Basename;
use FindBin;
use Log::Log4perl(":easy");
use Params::Validate;
use Scalar::Util;
use Sys::Hostname;
use strict;
use warnings;

my $path = "database.sqlite3";

my $db = DBI->connect( "dbi:SQLite:$path", "", "" );
if ( !defined($db) ) {
    exit 1;
}

my $longLine = 'CREATE TABLE "song" ( 
    "type" TEXT); ';

$db->do($longLine) or die "$DBI::errstr\n";
