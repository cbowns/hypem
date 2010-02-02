package Hypem::Database;

=head1 NAME

Hypem::Database

=cut

=head1 SYNOPSIS

    Some info on this should go here.

=cut

use strict;
use warnings;
use Params::Validate;
use Data::Dumper;
use Log::Log4perl(":easy");
use DBI;

use constant DEFAULT_DB_NAME => "database.sqlite3";

=head2 new

Create a new database file. A path argument is optional.

=cut

sub new {
	my ( $class, $path ) =
	  validate_pos( @_, 1, { default => DEFAULT_DB_NAME } );

	my $db = DBI->connect( "dbi:SQLite:$path", "", "" );
	if ( !defined($db) ) {
		return undef;
	}
	my $self = bless { db => $db }, $class;
	return $self;
}

=head2 createTable

Creates the tables necessary to use this database.
Returns 1 on success, 0 on failure.

	if ( $db->createTable() ) {
		# rock and roll time
	} else {
		# you should probably kill yourself. Er, I mean, kill your program.
	}

=cut

sub createTable {
	my ($self) = validate_pos( @_, 1 );

	my $status = 0;

	my $firstTable = 'CREATE TABLE "song" (
		"ID" integer not null primary key autoincrement,
		"name" text,
		"date added" text ); ';

	if ( !$self->{db}->do($firstTable) ) {
		ERROR("TriggerDB ERROR: $DBI::errstr");
		return 0;
	}

	my $secondTable = 'create table "url" (
		"ID" integer not null primary key autoincrement,
		"url" text,
		"songID" integer ); ';

	if ( !$self->{db}->do($secondTable) ) {
		ERROR("TriggerDB ERROR: $DBI::errstr");
		return 0;
	}

	return 1;
}

=head2 parseArgs

Close out a database file by disconnecting from it and nulling out the pointer.

	$db = $db->close();
	# $db is now undef. best practice, yo.

=cut

sub close {
	my ($self) = validate_pos( @_, 1 );

	$self->{db}->disconnect();
	$self->{db} = undef;
	return undef;
}

=head2 insert

Insert stuff into the DB.

=cut

# TODO actually implement and test!

sub insert {
	my ( $self, $item ) = validate_pos( @_, 1, 0 );

	# $item is a hashref with some stuff inside it.

	# TODO fill in table name
	my $sql = "insert into <> values ( NULL , "

	  # TODO fill in item's key
	  . join( ", ", map { $self->{db}->quote($_) } ( $item->{blah} ) ) . ")";

	if ( !$self->{db}->do($sql) ) {
		return -1;
	}

	# TODO fill in table name
	my $workRowID =
	  $self->{db}->last_insert_id( undef, undef, '<table>', 'ID' );

	return $workRowID;
}

# TODO this doesn't really make sense, I have two tables

=head2 removeRowForID

Remove an item with id or somethin

=cut

sub removeRowForID {
	my ( $self, $id ) = validate_pos( @_, 1, 1 );

	if ( $id !~ /^[0-9]+$/ || $id < 1 ) {
		return 0;
	}

	# TODO fill in table name
	my $sql = "delete from <> where <>=" . $self->{db}->quote(<>);
	return $self->{db}->do($sql);
}

=head2 thingy

do stuff to things

=cut

sub thingy {
	my ( $self, $id ) = validate_pos( @_, 1, 1 );

	if ( $id !~ /^[0-9]+$/ || $id < 1 ) {
		return 0;
	}

	# TODO fill in table names, params to quote()
	my $sql =
	    "update <> set <>="
	  . $self->{db}->quote(<>)
	  . " where <>="
	  . $self->{db}->quote(<>);

	return $self->{db}->do($sql);
}

1;
