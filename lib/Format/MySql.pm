package DBIx::Record::Format::MySql;
use strict;
use Carp 'croak';
use vars '@ISA';
use DBIx::Record ':all';
# use Dev::ShowStuff ':all';
@ISA = 'DBIx::Record';


#---------------------------------------------------------------------
# open POD
# 

=head1 NAME

DBIx::Record::Format::MySql - DBIx::Record Database format layer for MySql.

=head1 DESCRIPTION

See C<DBIx::Record> POD for documentation on how the format layer works.

=cut

# 
# open POD
#---------------------------------------------------------------------


#------------------------------------------------------------------------------
# select_single
#
sub select_single {
	my ($class, $dbh, $pk, %opts) = @_;
	my ($rv, $sql, $sth, %mt);
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
	
	$rv or return add_error('no such record found');
	
	return %{$rv};
}
# 
# select_single
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# select_multiple
#
sub select_multiple {
	my ($class, $dbh, %opts) = @_;
	my ($rv, $sql, $sth, @where_bind);
	
	# start sql
	$sql = 'select ';
	
	# field list
	if (defined $opts{'fields'})
		{$sql .= join(',', @{$opts{'fields'}})}
	else
		{$sql .= '*'}
	
	# TESTING
	# println $sql;

	# add from and where clause
	$sql .= ' from ' . $class->table_name;

	# where string
	if (defined $opts{'where_str'})
		{$sql .= ' where ' . $opts{'where_str'}}
	
	# order clause
	if ($opts{'order'})
		{$sql .= ' order by ' . join(',', @{$opts{'order'}})}
	
	# prepare statement
	$sth = $dbh->prepare($sql) or return add_dbierror;
	
	# if there are bind variables
	if ($opts{'bindings'}) {
		my $i = 1;
		
		foreach my $bind (@{$opts{'bindings'}})
			{$sth->bind_param($i++, $bind)}
	}

	# return statement handle
	return $sth;
}
# 
# select_multiple
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# select_exists
#
sub select_exists {
	my ($class, $dbh, $pk) = @_;
	my ($rv, $sql, $sth);
	
	# build sql
	$sql = 
		'select count(*) from ' . 
		$class->table_name . 
		' where ' .
		$class->pk_field_name . '=?';
	
	# select and execute
	$sth = $dbh->prepare($sql)    or return add_dbierror;
	$sth->execute($pk)            or return add_dbierror;
	($rv) = $sth->fetchrow_array  or return add_dbierror;
	
	return $rv;
}
# 
# select_exists
#------------------------------------------------------------------------------



#------------------------------------------------------------------------------
# record_delete
#
sub record_delete {
	my ($class, $dbh, $pk) = @_;
	my ($sql, $sth);
	
	# build sql
	$sql = 
		'delete from ' . 
		$class->table_name . 
		' where ' .
		$class->pk_field_name . '=?';
	
	# select and execute
	$sth = $dbh->prepare($sql)    or return add_dbierror;
	$sth->execute($pk)            or return add_dbierror;
	return 1;
}
# 
# record_delete
#------------------------------------------------------------------------------



#------------------------------------------------------------------------------
# insert
# 
sub insert {
	my ($class, $dbh, $names, $values, %opts) = @_;
	my ($sql, $sth, $pk);
	
	# build sql
	$sql = 'insert into ' . 
		$class->table_name . 
		' set ' . join('=?,', @$names) . 
		'=?';
	
	# if show_sql
	if ($opts{'show_sql'})
		{print STDERR $sql, "\n"}

	# prepare and execute statement
	$sth = $dbh->prepare($sql) or return add_dbierror;
	$sth->execute(@$values) or return add_dbierror;
	
	# get new primary key
	$sth = $dbh->prepare('SELECT LAST_INSERT_ID() FROM ' . $class->table_name) or return add_dbierror;
	$sth->execute() or return add_dbierror;
	($pk) = $sth->fetchrow_array;
	defined($pk)  or return add_dbierror;
	
	return $pk;
}
# 
# insert
#------------------------------------------------------------------------------



#------------------------------------------------------------------------------
# update
# 
sub update {
	my ($class, $dbh, $pk, $names, $values) = @_;
	my ($sql, $sth);
	
	# build sql
	$sql = 'update ' . 
		$class->table_name . 
		' set ' . join('=?,', @$names) . 
		'=? where ' . $class->pk_field_name . '=?';
	
	# prepare and execute statement
	$sth = $dbh->prepare($sql) or return add_dbierror;
	$sth->execute(@$values, $pk) or return add_dbierror;
	
	return 1;
}
# 
# update
#------------------------------------------------------------------------------




# return true
1;
__END__


get_sth($dbh, $tablename, $sth, %opts): returns a DBI statement handle for a set of records 
record_exists($dbh, $pk): returns true if a specified record exists 
record_delete($dbh, $tablename, $pk): deletes a specified record 
save_existing($dbh, $tablename, $pk, %fields): saves a set of fields to a specified record 
save_new($dbh, $tablename, $pk, %fields): saves a new record and returns the primary key 
