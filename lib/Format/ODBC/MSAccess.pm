package DBIx::Record::Format::ODBC::MSAccess;
use strict;
use Carp 'croak';
use vars '@ISA';
use DBIx::Record ':all';
# use Dev::ShowStuff ':all';
@ISA = 'DBIx::Record';


# PLEASE NOTE!!!!
# This module is barely started.  I figured out how to get the primary key
# of a newly inserted record, but ehn had to abandon the module.
# Feel free to continue developing the module. -Miko


#------------------------------------------------------------------------------
# select_single
#
sub select_single {
	my ($class, $dbh, $pk, %opts) = @_;
	my ($rv, $sql, $sth);
	reset_errors;
	
	# start sql
	$sql = 'select ';

	# field list
	if (defined $opts{'fields'})
		{$sql .= join(',', @{$opts{'fields'}})}
	else
		{$sql .= '*'}
	
	$sql .= ' from ' . $class->table_name . ' where ' . $class->pk_field_name . '=?';
	
	
	# select and execute
	$sth = $dbh->prepare($sql)    or return add_dbierror;
	$sth->execute($pk)            or return add_dbierror;
	$rv = $sth->fetchrow_hashref  or return add_dbierror;
	return %{$rv};
}
# 
# select_single
#------------------------------------------------------------------------------


# return true
1;
__END__

my ($dbh, $sth);
$dbh = DBI->connect('dbi:ODBC:Patients', 'user', 'password') or die $!;

# insert record
$sth = $dbh->prepare("insert into patients(name_last) VALUES('Gnu')") or die $!;
$sth->execute or die $!;

# insert record
$sth = $dbh->prepare('SELECT @@IDENTITY') or die $!;
$sth->execute or die $!;

while (my $rec = $sth->fetchrow_hashref())
	{showhash $rec}


get_record_fields($dbh, $tablename, $pk, %opts): returns the fields of a single record 
get_sth($dbh, $tablename, $sth, %opts): returns a DBI statement handle for a set of records 
record_exists($dbh, $pk): returns true if a specified record exists 
record_delete($dbh, $tablename, $pk): deletes a specified record 
save_existing($dbh, $tablename, $pk, %fields): saves a set of fields to a specified record 
save_new($dbh, $tablename, $pk, %fields): saves a new record and returns the primary key 
