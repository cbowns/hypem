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

	my $firstTable = 'create table "song" (
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

Inserts an item into the DB.

preconditions: $item->{} has the keys: 'name', 'date added', and 'url'.
postcondition: $item->{ID} will contain the ID of a row in song.

Returns -1 on failure from either insert. You should probably die immediately before the database becomes inconsistent if this returns -1.

=cut

sub insert {
	my ( $self, $item ) = validate_pos( @_, 1, 1 );

	# see if the item's name is already in the DB.
	$item->{ID} = $self->IDForName( $item->{name} );
	if ( $item->{ID} ) {

		# TODO see if the URL already exists too!
		return $self->_addURLForItem($item);
	}
	else {

		# if no:
		return $self->_insertItem($item);
	}

}

=head2 _insertItem

Private method for insert. Used when a full item insert is needed.

=cut

sub _insertItem {
	my ( $self, $item ) = validate_pos( @_, 1, 1 );

	my $sql =
	    "insert into song values ( NULL , "
	  . join( ", ", map { $self->{db}->quote($_) } ( $item->{'name'}, time ) )
	  . ")";

	if ( !$self->{db}->do($sql) ) {
		return -1;
	}

	$item->{ID} = $self->{db}->last_insert_id( undef, undef, 'song', 'ID' );

	$sql = "insert into url values ( NULL , "
	  . join( ", ",
		map { $self->{db}->quote($_) } ( $item->{'url'}, $item->{'ID'} ) )
	  . ")";

	if ( !$self->{db}->do($sql) ) {
		return -1;
	}

	return $item->{ID};
}

=head2 _addURLForItem

Private method for insert. Used when only a URL insert is needed.

=cut

sub _addURLForItem {
	my ( $self, $item ) = validate_pos( @_, 1, 1 );

	my $sql = "insert into url values ( NULL , "
	  . join( ", ",
		map { $self->{db}->quote($_) } ( $item->{'url'}, $item->{'ID'} ) )
	  . ")";

	if ( !$self->{db}->do($sql) ) {
		return -1;
	}

	return $item->{ID};
}

=head2 numberOfItems

Get the number of items in the DB.

=cut

sub numberOfItems {
	my ($self) = validate_pos( @_, 1 );

	my $sql = "select count(id) from song";

	return @{ $self->{db}->selectcol_arrayref($sql) }[0];
}

=head2 IDForName

Returns the ID for an entry with this name.

	if (IDForName("string") > 0) {
		# we have it in the DB already
	}

=cut

sub IDForName {
	my ( $self, $name ) = validate_pos( @_, 1, 1 );

	my $sql = "select ID from song where name = ?";

	my $preparedStatment = $self->{db}->prepare($sql);
	$preparedStatment->execute($name);

	if ( my $hashRef = $preparedStatment->fetchrow_hashref() ) {
		return $hashRef->{ID};
	}
	return undef;
}

=head2 URLsForID

Get an array of URLs for an ID

=cut

sub URLsForID {
	my ( $self, $id ) = validate_pos( @_, 1, 1 );

}

1;
