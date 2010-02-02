package Hypem::Database;

# perltidy -npro -pbp -l=100

use strict;
use warnings;
use Params::Validate;
use Data::Dumper;
use Log::Log4perl(":easy");
use DBI;

use constant DEFAULT_DB_NAME => "database.sqlite3";

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

# returns 1 on success, 0 on failure.

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

sub close {
	my ($self) = validate_pos( @_, 1 );

	$self->{db}->disconnect();
	$self->{db} = undef;
	return undef;
}

sub insert {
	my ( $self, $item ) = validate_pos( @_, 1, 0 );

	# $item is a hashref with some stuff inside it.

	my $sql = "insert into <> values ( NULL , "
	  . join( ", ", map { $self->{db}->quote($_) } ( $item->{blah} ) ) . ")";

	if ( !$self->{db}->do($sql) ) {
		return -1;
	}

	my $workRowID =
	  $self->{db}->last_insert_id( undef, undef, '<table>', 'ID' );

	return $workRowID;
}

sub removeRowForID {
	my ( $self, $id ) = validate_pos( @_, 1, 1 );

	if ( $id !~ /^[0-9]+$/ || $id < 1 ) {
		return 0;
	}

	my $sql = "delete from <> where <>=" . $self->{db}->quote(<>);
	return $self->{db}->do($sql);
}

sub markItemAsRunning {
	my ( $self, $id ) = validate_pos( @_, 1, 1 );

	if ( $id !~ /^[0-9]+$/ || $id < 1 ) {
		return 0;
	}

	my $sql =
	    "update <> set <>="
	  . $self->{db}->quote(<>)
	  . " where <>="
	  . $self->{db}->quote(<>);

	return $self->{db}->do($sql);
}

1;
