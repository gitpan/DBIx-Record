package DBIx::Record;
use strict;
use re 'taint';   
use Carp qw[croak cluck];
use DBI;
use Exporter;
# use Dev::ShowStuff ':all';
use vars qw[@ISA @errors @EXPORT_OK %EXPORT_TAGS $VERSION];
@ISA = 'Exporter';

# version
$VERSION = '0.10';



#---------------------------------------------------------------------
# open POD
# 

=head1 NAME

DBIx::Record - Middle tier system for representing database records as objects.

=head1 SYNOPSIS

 use Hospital;  # load class that implements DBIx::Record class
 my ($login, $patient);
 
 # get object that holds the database connection
 $login = Hospital->get_login;
 
 # Instantiate object representing the patient record
 # that has primary key 1000.  Change the record's name_last field.
 # Then save the record.
 $patient = Hospital::Patient->new($login, 1000, fields=>['name_last']);
 $patient->{'f'}->{'name_last'} = 'Smith';
 $patient->save;
 
 # Instantiate object representing a patient record
 # that doesn't exist yet.  Set the name_last field, save, 
 # and output the primary key of the new record
 $patient = Hospital::Patient->new($login, -1);
 $patient->{'f'}->{'name_last'} = 'Smith';
 $patient->save;
 print 'primary key: ', $patient->{'pk'}, "\n";

=head1 INSTALLATION

DBIx::Record can be installed with the usual routine:

	perl Makefile.PL
	make
	make test
	make install

=head1 OVERVIEW

C<DBIx::Record> is a system for representing database records as objects.
Each table in a database can be considered a class, and each record an
instantiation of that class. By presenting records as objects, each
type of record can have its own custom properties and methods.
C<DBIx::Record> is an abstract class: it must be overridden by a concrete
class to be implemented.

A C<DBIx::Record> record object (more simply known as a "record object")
is instantiated with the C<new> static method, which accepts two
arguments: a L<DBIx::Record::Login|/DBIx::Record::Login> object (which
holds the connection to the database) and one of several objects that
provides the data for a specific record. (C<new> is explained in more
detail below.) For example, consider a database of medical patients.
Each patient has a record in a "Patients" table, and can be represented
by an object of the class C<Hospital::Patient>. The following code
creates a record object with a primary key of 1000:

 my $patient = Hospital::Patient->new($login, 1000);

The new object, then, represents the patient record whose primary key
is 1000. The primary key is stored in the L<C<pk>|/DBIx::Record.f>
property of the object:

 print 'primary key: ', $patient->{'pk'}, "\n";

When the record object is instantiated using an ID, no calls to the
database are made. That is, the object merely knows its primary key. No
data has been retrieved from the database, and in fact, it has not even
been confirmed that the record exists. To pull the record's data from
the database, use the L<C<set_fields>|/DBIx::Record.set_fields> method:

 $patient>set_fields();

C<set_fields> retrieves the record fields from the database and stores
them in the object's L<C<f>|/DBIx::Record.f> ("fields") property. That
data can then be written to and read, and the record saved:

 $patient->{'f'}->{'name_last'} = 'Smith';
 print 'last name: ', $patient->{'f'}->{'name_last'}, "\n";
 $patient->save;

There are other ways to instantiate an object besides using an existing
record's primary key. For example, to create a new record (i.e. to add
a new record to the database, send a negative primary key.
C<DBIx::Record> will understand that to mean a new record. You can put
values in the record's C<f> hash and save the record as usual:

 my $patient = Hospital::Patient->new($login, -1);
 $patient->{'f'}->{'name_last'} = 'Smith';
 $patient->save;
 print 'primary key: ', $patient->{'pk'}, "\n";

Another way to instantiate a record object is to pass a DBI statement
handle as the second argument. C<DBIx::Record> will understand to
populate the object's C<f> hash from the next record in the statement
handle:

 my $patient = Hospital::Patient->new($login, $sth);
 print 'primary key: ', $patient->{'pk'}, "\n";

Yet another way to instantiate a C<DBIx::Record> object is to pass a CGI
query object as the second argument. In that situation you must always
pass a specific list of fields that should be read from the query.
C<DBIx::Record> will read the listed fields from the query and store them
in the C<f> hash:

 my $patient = Hospital::Patient->new($login, $q, fields=>['name_last', 'name_first', 'date_of_birth']);
 $patient->save;

The techniques described here provide the basis for how C<DBIx::Record>
objects work. There are many more features. Just to name a few,
C<DBIx::Records> provide:

=over

=item * L<Centralized enforcement of business rules for database
records|/DBIx::Record.validate>

=item * L<Encapsulation of common database routines|/DBIx::Record>

=item * L<Centralized system for defining how records should be
displayed in text output, web pages, and web page
forms|/DBIx::Record::FieldHash>

=item * L<Cross-platform generization|/DBIx::Record::DBFormat::format>

=back

=head2 Assumptions and Restrictions

C<DBIx::Record> is based on certain assumptions about how you design your
database. While most of the assumed practices are quite typical, it's
necessary to be sure that C<DBIx::Record> and your database design do not
clash.

Tables that are represented by record object classes are assumed to
have a single primary key. It is assumed that that key will never be a
negative integer. It is also assumed that a new primary key can be
programmatically generated for each new record (typically through use
of a sequence). C<DBIx::Record> does not (currently) support referencing
tables with composite primary keys, but it does not prevent you for
including those types of tables in your database and referencing them
in a more traditional manner.

C<DBIx::Record> assumes that no database or HTML form fields start with
the "dbr.". C<DBIx::Record> reserves that prefix for use as hidden fields
in HTML forms. It is also assumed that field names are
case-insensitive.

=head2 Implementation: X<4layers>The Four Layers of DBIx::Record

C<DBIx::Record> is implemented by extending the base class through
several layers that implement different pieces of the database
connection puzzle. A typical implementation will extend C<DBIx::Record>
through four layers. The following sections look at each layer.

=head2 Base: X<DBIx::Record>DBIx::Record

The base class is C<DBIx::Record> itself. C<DBIx::Record> provides the
overall interface as well as a variety of utility functions.
C<DBIx::Record> is an abstract class and defines several methods that
I<must> be overridden. This class also implements a wide range of
concrete methods that can be used by the final concrete classes.

=head2 Database Format: DBIx::Record::DBFormat::I<database format>

The next layer,
L<DBIx::Record::DBFormat::I<format>|/DBIx::Record::DBFormat::format>,
extends C<DBIx::Record> to handle a specific database format such as
MySQL, PosGreSql, Oracle, etc. This layer implements six static methods
that provide generic access to a relational database:

=over

=item * L<select_single($dbh, $pk,
%opts)|/DBIx::Record::DBFormat::format.select_single>: returns the fields
of a single record

=item * L<select_multiple($dbh, $sth,
%opts)|/DBIx::Record::DBFormat::format.select_multiple>: returns a DBI
statement handle for a set of records

=item * L<record_exists($dbh,
$pk)|/DBIx::Record::DBFormat.record_exists>: returns true if a specified
record exists

=item * L<record_delete($dbh, $tablename,
$pk)|/DBIx::Record::DBFormat::format.record_delete>: deletes a specified
record

=item * L<update($dbh, $tablename, $pk,
%fields)|/DBIx::Record::DBFormat::format.update>: saves a set of fields
to a specified record

=item * L<insert($dbh, $tablename, $pk,
%fields)|/DBIx::Record::DBFormat::format.insert>: saves a new record and
returns the primary key

=back

=head2 I<X<Application>Application>

The Application layer extends one of the database format classes to
provide methods that apply to your specific application. This class
provides the L<C<create_login>|/DBIx::Record::Application.create_login>
method that provides a login object and a database handle.

=head2 Table: I<Application>::I<Table>

This concrete class layer extends the application layer to provide
objects for a specific table. This class implements the
L<C<table_name>|/Application::Table.simple_methods>,
L<C<pk_field_name>|/Application::Table.simple_methods>, and
L<C<field_defs>|/Application::Table.field_defs> methods.

=cut

# 
# open POD
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# POD for DBIx::Record
# 

=head1 DBIx::Record

C<DBIx::Record> is the base class for record objects. One class is defined for
each table in the database. Every instantiation of C<DBIx::Record>
represents a single record in that table.

=cut

# 
# 
# POD for DBIx::Record
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# constants
# 

=head2 Constants

C<DBIx::Record> has three constants for indicating the media for the field object. These constants are all integers, so you can use C<==> 
for comparisons.

=over

=item MEDIA_TEXT

output the field as plain text

=item MEDIA_HTML

output the field for use in an HTML web page.

=item MEDIA_HTML_FORM

output the field as an HTML web page form.

=back

=cut

use constant MEDIA_TEXT => 1;
use constant MEDIA_HTML => 2;
use constant MEDIA_HTML_FORM => 3;
# 
# constants
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# import/export
# 

=head2 import/export

C<DBIx::Record> exports the following methods and constants if you load it with the C<:all> option, like this:

 use DBIx::Record ':all';

=over

=item reset_errors

=item add_error

=item add_dbierror

=item show_errors_plain

=item die_errors_plain

=item crunch

=item htmlesc

=item nullfix

=item hascontent

=item as_arr

=item MEDIA_TEXT

=item MEDIA_HTML

=item MEDIA_HTML_FORM

=back

=cut

@EXPORT_OK = qw[
	reset_errors add_error add_dbierror show_errors_plain die_errors_plain
	crunch htmlesc hascontent as_arr MEDIA_TEXT MEDIA_HTML MEDIA_HTML_FORM
	];

%EXPORT_TAGS = (all=>[@EXPORT_OK]);
# 
# import/export
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# hash of tags that don't add spaces to text
# 

=head2 %nospace

C<%DBIx::Record::nospace> is used by C<strip_html>.  C<%nospace> gives a set of HTML tags which, when removed, should 
I<not> be replaced with a single space.  Each key in C<%nospace> is the name of a tag, in lowercase.  The values are ignored.

=cut

use vars qw[%nospace];   
@nospace{qw[
	a i b tt code
	]} = ();
# 
# hash of tags that don't add spaces to text
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# POD: DBIx::Record object properties
# 

=head2 static X<DBIx::Record::Login.errors>@errors

An array of error messages that are created when a function has an
error. Any function may add errors to this array, but only the
following functions may clear the array:

=over

=item * L<C<save>|/DBIx::Record.save>,

=item * L<C<validate>|/DBIx::Record.validate>,

=item * L<C<get_records>|/DBIx::Record.get_records>

=item * L<C<set_fields>|/DBIx::Record.set_fields>

=back

=head2 X<DBIx::Record::Login.login>login

C<login> represents the record's connection to the database. C<login>
is used by every method that sends data to or retrieves data from the
database.

C<login> may either be an object which returns a DBI database handle
via its L<C<get_dbh>|/DBIx::Record::Login.get_dbh> method, or C<login>
may itself be a database handle. C<DBIx::Record> dynamically determines
which type of object it is and acts accordingly. The L<application
layer|/Application> creates the login object using its static
L<C<create_login>|/DBIx::Record::Application.create_login> method.

=head2 X<DBIx::Record.f>C<pk>

The primary key of the record. This property should never be set
outside of the class.

=head2 X<DBIx::Record.is_own_login>is_own_login

If true, then the object uses itself as its own login object. This
property is used by the C<get_login method>.

=head2 X<DBIx::Record.f>C<f>

The hash of field objects. The keys are the field names, the values are
field objects. It's named "f" instead of fields because I found myself
using this property dozens of times per web page, and I wanted
something shorter to type.

C<f> is reference to a tied hash. If you assign a value to one of the
hash keys, the value is assigned using that field object's
L<C<set_from_interface>|/DBIx::Record::Field.set_from_interface> method.
Also, the tied object tracks if any changes to the fields have been
made, so that no database call is necessary if no changes were made.

=cut

# 
# POD: DBIx::Record object properties
#---------------------------------------------------------------------


#----------------------------------------------------------------------------------
# new
# 

=head2 X<DBIx::Record.new>static new($login, $id, %options)

This static method is the constructor for a C<DBIx::Record> object. The
method has two required arguments. The first, C<$login>, is the login
object. It may instead be a dbh object.

The second, C<$id> is one of these types of scalars:

=over

=item * a primary key: if C<$id> is a defined non-reference, and if it
is an integer greater than or equal to zero, then it is assumed to be
the primary key of an existing record.

=item * undef or negative number: if C<$id> is not defined, or if it is
a number less than zero, then it is assumed that the record object
represents a new record. In this case the C<pk> property is not
defined.

=item * a statement handle: if C<$id> is a DBI statement handle, then
the current record in the handle will be used to set the fields of the
record object. In doing so, the statement handle will be advanced to
the next record. The statement handle I<must> include the primary key
of the record. If the statement handle is at eof, then C<new> returns
undef.

=item * X<CGI>CGI object: if a CGI object is passed as the second
argument, if the C<dbr.form_sent> field in the query is true, and if
the C<dbr.cancel> field in the query is false, then the fields are set
from the CGI object. The feature is only enabled if the
L<C<fields>|/DBIx::Record.new.fields> option is also sent. Only the
fields listed in C<fields> are loaded from the CGI. C<fields> may be
set to C<*> to indicate all fields.

=back

=head2 Options

=head2 set_fields, fields

This option consists of an array of fields to retrieve from the
database. If this option is sent, then the new record object
automatically retrieve. If the list consists of just C<*>, then all the
fields are retrieved. The options C<set_fields> and C<fields> mean
exactly the same thing.

=cut

sub new {
	my ($class, $login, $pk, %opts) = @_;
	my $self = bless({}, $class);
	my ($pkname);
	reset_errors();
	
	# primary key field name
	$pkname = $self->pk_field_name;
	
	# store login object
	$self->{'login'} = $login;
	
	
	#----------------------------------------------------------------------------------------
	# if a reference was sent instead of an ID
	#
	if ($pk && ref($pk)) {
		my ($row);
		
		# statement handle
		if (UNIVERSAL::isa($pk, 'DBI::st')) {
			$row = $pk->fetchrow_hashref or return undef;
			$opts{'from_db'} = 1;
		}
		
		# CGI query
		elsif (UNIVERSAL::isa($pk, 'CGI')) {
			my (@fieldnames);
			
			# field list is required
			unless (defined $opts{'fields'})
				{croak 'if you send the dbrecord argument you must also send the fields argument'}
			
			# if form was sent, set fields from query
			if ($pk->param('dbr.form_sent') || new_record_pk($pk->param($pkname))) {
				my (@getfields);
				$row = {};
				as_arr($opts{'fields'});
				$opts{'set_from_interface'} = 1;
				
				# if * is the field list, get field definitions, use those keys
				if ($opts{'fields'}->[0] eq '*') {
					my %defs = $self->field_defs;
					@fieldnames = keys %defs;
				}
				
				# else use field list
				else
					{@fieldnames = @{$opts{'fields'}}}
				
				# set fields from params
				foreach my $fn (@fieldnames)
					{$row->{$fn} = $pk->param($fn)}
				
				$row->{$pkname} = $pk->param($pkname);
			}
			
			# else form was not sent, so just get the primary key
			else
				{$pk = $pk->param($pkname)}
		}
		
		# hash
		elsif (UNIVERSAL::isa($pk, 'HASH')) 
			{$row = $pk}
		
		# else don't understand reference
		else
			{die "do not know how to handle this type of reference [$pk]"}		
		
		# if row is a hash, set fields from it
		if (UNIVERSAL::isa($row, 'HASH')) {
			# get the primary key
			#unless (defined($self->{'pk'} = $row->{$pkname} ))
			#	{croak 'To instantiate an object using an object, you must include the primary key field in the statement'}
			
			# set fields
			$self->set_fields(hash=>$row, %opts);
		}
	}
	#
	# if a reference was sent instead of an ID
	#----------------------------------------------------------------------------------------
	
	
	#----------------------------------------------------------------------------------------
	# if not a reference
	# 
	if (! ref $pk) {
		
		#----------------------------------------------------------------------------------------
		# if no pk was sent, or if pk is less than zero, load all fields
		#
		if ( new_record_pk($pk) ) {
			delete $opts{'fields'};
			
			$self->set_fields(%opts);
			
			# mark all fields as changed
			@{$self->fields_object->{'changed_fields'}}{keys %{$self->{'f'}}} = ();
			$self->fields_object->{'validated'} = 0;
		}
		#
		# if no pk was sent, or if pk is less than zero, load all fields
		#----------------------------------------------------------------------------------------
		
		
		#----------------------------------------------------------------------------------------
		# else we got a regular ID
		# 
		else {
			# set ID
			$self->{'pk'} = $pk;
			
			# alias set_fields to fields
			if ($opts{'set_fields'})
				{$opts{'fields'} = delete $opts{'set_fields'}}
			
			# if 'fields' or 'set_fields' was sent, attempt retrieve the record
			if (defined $opts{'fields'})
				{$self->set_fields(%opts) or return undef}
		}
		#
		# else we got a regular ID
		#----------------------------------------------------------------------------------------
	}
	# 
	# if not a reference
	#----------------------------------------------------------------------------------------
	
	
	# return
	return $self;
}
# 
# new
#----------------------------------------------------------------------------------


#---------------------------------------------------------------------
# set_fields
# 

=head2 X<DBIx::Record.set_fields>set_fields(%options)

This method retrieves data from the database using the primary key of
the record object, and stores the data into the C<fields> hash. There
are no required arguments. By default, C<set_fields> retrieves all the
fields in the record. This function uses C<select_single(%opts)>, which
is implemented in the database format layer, to do the actual retrieval
of records from the database. An array of errors is returned if C<pk>
is not defined or if the record is not found in the database.

=head2 Options

=head2 fields

C<fields> is an array of the names of fields to retrieve. It may also
be a scalar, which will be interpreted as a single-item array. So, for
example, this code retrieves the C<name> and C<email> fields:

 $client->set_fields(fields=>['name', 'email']);

=head2 hash

TODO

=head2 set_from_interface

TODO

=head2 media_object

TODO

=cut

sub set_fields {
	my ($self, %opts) = @_;
	my (%fields, $fieldsob, $pkname, %defs, $isnew);
	reset_errors();
	
	# tie fields hash to case-insensitive class
	if (! $self->{'f'}) {
		my %f;
		tie %f, 'DBIx::Record::FieldHash', $self;
		$self->{'f'} = \%f;
	}
	
	# shorthand variables
	$pkname = $self->pk_field_name;
	$fieldsob = $self->fields_object;
	
	# get field definitions
	%defs = $self->field_defs;
	
	
	#--------------------------------------------
	# if a hash was sent
	# 
	if ($opts{'hash'}) {
		$isnew = new_record_pk($opts{'hash'}->{$pkname});
		
		# if new record
		# set fields from hash
		if ($isnew)
			{%fields = %{$opts{'hash'}}}
		
		# else existing record
		else {
			my (@getfromdb);
			
			# set regular fields from hash
			# set new-only from database
			while (my($n, $v) = each(%{$opts{'hash'}})) {
				$n = lc($n);
				
				# check if field definition exists
				unless ($defs{$n} || ($n eq $pkname) )
					{die "do not have definition for field \"$n\""}
				
				if ($defs{$n}->{'new_only'})
					{push @getfromdb, $n}
				else
					{$fields{$n} = $v}
			}
			
			# retrieve new-only from database
			if (@getfromdb) {
				my %newonly = $self->select_single(get_ob_dbh($self->{'login'}), $opts{'hash'}->{$pkname}, fields=>\@getfromdb)
					or return 0;
				
				while (my($n, $v) = each(%newonly))
					{$fields{$n} = $v}
			}
		}
	}
	# 
	# if a hash was sent
	#--------------------------------------------
	
	
	#--------------------------------------------
	# else if new record
	# 
	elsif ($isnew = $self->is_new) {
		# hash of undefs with field definition's names
		@fields{keys %defs} = ();
	}
	# 
	# else if new record
	#--------------------------------------------


	#--------------------------------------------
	# else retrieve values from database
	# 
	else {
		# ensure that we get the primary key
		if (defined $opts{'fields'}) {
			my $fields = $opts{'fields'};
			as_arr($fields);
			
			# if the field list consists of *
			if ($fields->[0] eq '*')
				{undef $fields}
			else {
				unless (grep {lc($_) eq $pkname} @$fields)
					{push @$fields, $pkname}
			}
			
			$opts{'fields'} = $fields;
		}
		
		%fields = $self->select_single(get_ob_dbh($self->{'login'}), $self->{'pk'}, %opts)
			or return undef;
		$opts{'from_db'} = 1;
	}
	# 
	# else retrieve values from database
	#--------------------------------------------

	
	# store pk
	if (defined $self->{'pk'})
		{delete $fields{$pkname}}
	else
		{$self->{'pk'} = delete($fields{$pkname}) . ''}
	
	# store fields
	while (my($k, $v) = each(%fields)) {
		my ($field, $def, $default);
		$k = lc($k);
		
		# if we don't have a field definition, fatal error
		unless ($def = $defs{$k})
			{die "do not have definition for field $k"}
		
		# add field name
		$def->{'field_name'} = $k;

		# get default value
		$default = delete $def->{'default'};
		
		# instantiate the field
		$field = $def->{'class'}->new($def, $self->{'login'});
		
		# set from interface if option indicates so
		if ( $opts{'set_from_interface'} && ($def->{'new_only'} ? $isnew : 1) )
			{$field->set_from_interface($v)}
		else {
			if ($isnew) {
				if (defined $default)
					{$field->set_from_db($default)}
			}
			else
				{$field->set_from_db($v)}
		}
		
		# reference media object if it exists
		if ($opts{'media_object'})
			{$field->{'media_object'} = $opts{'media_object'}}
		
		# store the field object
		$fieldsob->STORE($k, $field, %opts);
	}
	
	return 1;
}
# 
# set_fields
#---------------------------------------------------------------------


#----------------------------------------------------------------------------------
# new_record_pk
# 

=head2 static new_record_pk($pk)

Returns true if the given primary key is in the format of a new record.

=cut

sub new_record_pk {
	my ($pk) = @_;

	if ( (! defined($pk)) || ($pk !~ m|\S|) || ($pk =~ m|^\-\d+(\.\d*)?$|s) || ($pk =~ m|^\-\.\d+$|s) )
		{return 1}
	return 0;
}
# 
# new_record_pk
#----------------------------------------------------------------------------------


#----------------------------------------------------------------------------------
# fields_object
# 

=head2 fields_object()

Returns the object to which the fields hash is tied.

=cut

sub fields_object {
	my ($self) = @_;
	return tied(%{$self->{'f'}});
}
# 
# fields_object
#----------------------------------------------------------------------------------


#----------------------------------------------------------------------------------
# show_fields
# 

=head2 show_fields()

A handy utility for debugging.  Displays all fields in a web page

=cut

sub show_fields {
	my ($self) = @_;
	
	print "<TABLE BORDER CELLPADDING=3 RULES=ROWS>\n";
	
	foreach my $key (sort keys %{$self->{'f'}}) {
		print
			'<TR VALIGN=TOP>',
			'<TH>', htmlesc($key), '</TH>',
			'<TD>', $self->{'f'}->{$key}->html_display(), '</TD>',
			"</TR>\n";
	}
	
	print "</TABLE>\n";
}
# 
# show_fields
#----------------------------------------------------------------------------------


#----------------------------------------------------------------------------------
# show_field_names
# 

=head2 show_field_names()

Another handy utility for debugging.  Displays all field names.

=cut

sub show_field_names{
	my ($self) = @_;
	my @fields = sort keys %{$self->{'f'}};
	
	if (in_web()) {
		if (@fields) {
			print
				"<UL><LI>\n",
				join('<LI>', @fields),
				"</UL>\n";
		}
		else
			{print "<I>no fields</I>\n"}
	}
	
	else {
		if (@fields)
			{print "\n", join("\n", @fields), "\n"}
		else
			{print "[no fields]\n"}
	}
}
# 
# show_field_names
#----------------------------------------------------------------------------------


#---------------------------------------------------------------------
# reset_errors
# 

=head2 static reset_errors()

Clears out all errors from C<@DBIx::Record::errors>.

=cut

sub reset_errors{@errors = ()}
# 
# reset_errors
#---------------------------------------------------------------------



#---------------------------------------------------------------------
# add_error
# 

=head2 static add_error()

Adds an error to C<@DBIx::Record::errors>.  Always returns an empty array, so returning the return value of this
function is a clean way to return false from a subroutine.

=cut

# This subroutine always returns an empty array.  It returns an array instead of just
# zero because it is sometimes called in list context, and needs to evaluate to an empty list
sub add_error {
	push @errors, @_;
	my @mt;
	return @mt;
}
# 
# add_error
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# add_dbierror
# 

=head2 static add_dbierror()

Adds the value of C<$DBI::errstr> to C<@DBIx::Record::errors>.  Always returns an empty array, so returning the return value of this
function is a clean way to return false from a subroutine.

=cut

# This subroutine always returns an empty array.  It returns an array instead of just
# zero because it is sometimes called in list context, and needs to evaluate to an empty list
sub add_dbierror {
	push @errors, $DBI::errstr;
	my @mt;
	return @mt;
}
# 
# add_dbierror
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# show_errors_plain
# 

=head2 static show_errors_plain()

Handy for debugging.  Outputs C<@DBIx::Record::errors> to STDOUT.

=cut

sub show_errors_plain {
	foreach my $err (@errors)
		{print $err->output(MEDIA_TEXT), "\n"}
}
# 
# show_errors_plain
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# die_errors_plain
# 

=head2 static die_errors_plain()

Handy for debugging.  Outputs C<@DBIx::Record::errors> to STDOUT, then dies.

=cut

sub die_errors_plain {
	if (defined $_[0])
		{print $_[0], "\n"}
	show_errors_plain();
	exit;
}
# 
# die_errors_plain
#---------------------------------------------------------------------



#---------------------------------------------------------------------
# get_ob_dbh
# 

=head2 static get_ob_dbh($ob)

Returns the database handle from a login, if C<$ob> *is* login object.  Otherwise returns 
C<$ob> itself.

=cut

sub get_ob_dbh {
	my ($ob) = @_;
	
	defined $ob or croak('did not get defined $ob');
	
	# if it's a DBI::db
	if (UNIVERSAL::isa($ob, 'DBI::db'))
		{return $ob}

	# else if it has a get_dbh method
	elsif ($ob->can('get_dbh'))
		{return $ob->get_dbh}
	
	# else fatal error
	die "could not determine if this object is a DBI::db or login: $ob";
}
# 
# get_ob_dbh
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# get_dbh
#

=head2 get_dbh()

Returns the database handle used by the record obejct.

=cut

sub get_dbh {
	my ($self) = @_;
	return get_ob_dbh($self->get_login);
}
#
# get_dbh
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# is_new
# 

=head2 is_new()

Returns true if the record is a new record (i.e. not saved to the database yet).

=cut

sub is_new {
	my ($self) = @_;
	return new_record_pk($self->{'pk'});
}
# 
# is_new
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# save
# 

=head2 X<DBIx::Record.save>save()

This method saves the record to the database, returning an array of
errors if the record could not be saved.

First, C<save> calls X<DBIx::Record.validate>C<validate>. If C<validate>
returns any errors then C<save> returns those errors to the caller and
is done.

If L<C<pk>|/DBIx::Record.f> is defined, then C<save> calls
L<update|/DBIx::Record::DBFormat::format.update>, returning its error
array. Otherwise C<save> calls
L<insert|/DBIx::Record::DBFormat::format.insert>, setting the resulting
new primary key to C<pk> (if there were no errors) and returning the
array of errors.

=cut

sub save {
	my ($self, %opts) = @_;
	my (@names, $newpk, @values);
	reset_errors();
	
	# don't do anything if no changed
	@names = $self->changed or return 1;
	
	# remove fields that aren't changed after the record is first saved
	if (! $self->is_new)
		{@names = grep {! $self->{'f'}->{$_}->{'new_only'}} @names}
	
	# don't do anything if no changed
	@names = $self->changed or return 1;
	
	# validate
	$self->validate or return 0;
	
	# build array of values
	foreach my $name (@names)
		{push @values, $self->{'f'}->{$name}->send_to_db}
	
	# call format layer's update if already exists
	if ($self->is_new) {
		# before insert
		$self->before_insert or return 0;
		
		# insert
		$newpk = $self->insert(
			$self->get_dbh,
			\@names,
			\@values,
			%opts);
		
		# if we didn't ge a defined primary key, the inser failed
		defined($newpk) or return 0;
		
		# store the pk, run after_insert, we're done
		$self->{'pk'} = $newpk;
		$self->after_insert;
		return 1;
	}

	# before update
	$self->before_update or return 0;
	
	# do update	
	$self->update($self->get_dbh, $self->{'pk'}, \@names, \@values)
		or return 0;
	
	# after update
	$self->after_update;
	
	return 1;
}
# 
# save
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# exists
# 

=head2 X<DBIx::Record.exists>exists()

Returns true if the given record exists in the database. Calls
L<record_exists|/DBIx::Record::DBFormat.record_exists> to make the check.

=cut

sub exists {
	my ($self, $login, $pk) = @_;
	
	# if $self is not a reference, instantiate the object with the remaining argument
	unless (ref $self)
		{$self = $self->new($login, $pk)}
	
	# if is new, return false
	$self->is_new and return 0;
	
	# call select_exists
	return $self->select_exists($self->get_dbh, $self->{'pk'});
}
# 
# exists
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# delete
# 

=head2 X<DBIx::Record.delete>delete()

Deletes the record.  Returns true if successful.  Before the record is deleted, the 
C<before_delete> method is called.  If that method returns false, then the record is 
not deleted.  After the deletion, the <after_delete> method is called.

=cut

sub delete {
	my ($self) = @_;
	reset_errors();
	
	# if is new, error
	if ($self->is_new) {
		add_error('Cannot delete record that has not been saved yet');
		return 0;
	}
	
	# before delete
	$self->before_delete or return 0;
	
	# call record_delete
	$self->record_delete($self->get_dbh, $self->{'pk'})
		or return 0;
	
	# after delete
	$self->after_delete;

	return 1;
}
# 
# delete
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# get_records
# 

=head2 X<DBIx::Record.get_records>static get_records($login, %options)

This static method returns a
C<L<DBIx::Record::Looper|/DBIx::Record::Looper>> object representing the
results of a select statement.

By default, every field in every record is returned. For example, this
code loops through the entire Clients table:

 $looper = MyApp::Client->get_records();
 
 while (my $client = $looper->next) {
 	print $client->{'f'}->{'name'}
 }

The optional arguments allow you filter down what is returned.

=head2 Options

Note that if any of these options are tainted then there will be a
fatal error. The only exception is the list of bindings, which may be
tainted.

=head2 fields, where, bindings, order

These options are passed to
L<C<select_multiple>|/DBIx::Record::DBFormat::format.select_multiple>,
which is implemented in the L<database format
level|/DBIx::Record::DBFormat::format>. C<fields>, C<bindings>, and
C<order> are first checked to ensure that they are array refs. If they
are scalars then they are converted to refs to single element arrays.

=cut

sub get_records {
	my ($class, $login, %opts) = @_;
	my ($sth, $pkname);
	reset_errors();
	
	# get name of primary key
	$pkname = $class->pk_field_name;
	
	# if fields list, make sure that the primary key is in the field
	if (defined $opts{'fields'}) {
		# if it's not a reference, make it one
		as_arr($opts{'fields'});
		
		# lowercase and crunch everything
		crunch(@{$opts{'fields'}});
		grep {tr/a-z/A-Z/} @{$opts{'fields'}};
		
		# ensure that the primary key is in the field list
		unless (grep {$_ eq $pkname} @{$opts{'fields'}})
			{push @{$opts{'fields'}}, $pkname}
	}
	
	# if order list, make sure it's an array ref
	as_arr($opts{'order'});
	
	# get statement handle from format layer
	$sth = $class->select_multiple(get_ob_dbh($login), %opts);
	
	# create looper object with class name and statement handle
	return DBIx::Record::Looper->new($login, $class, $sth);
}
# 
# get_records
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# children
# 

=head2 X<DBIx::Record.children>children(%options)

This method returns a looper referencing child records in a foreign
table. The only required argument is C<$class>, which is the name of
the class of the foreign table. For example, the following code returns
a C<X<DBIx::Record::Looper>DBIx::Record::Looper> for the members of a club:

 $looper = $club->children('MyApp::Club');

This method accepts the same options as
L<C<get_records>|/DBIx::Record.get_records>: C<fields>, C<where>,
C<bindings>, and C<order>. The where clause created by the C<where>
option is set in addition to the primary of the current record.

=cut

sub children {
	my ($self, $childclass, %opts) = @_;
	my ($looper);
	
	$looper = $childclass->get_records(
		$self->get_login, 
		where_str => $self->pk_field_name . '=' . $self->{'pk'},
		%opts
		);
	return $looper;
}
# 
# children
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# get_login
# 

=head2 get_login()

Returns the L<login|/DBIx::Record::Login> held in the
L<C<login>|/DBIx::Record::Login.login> property. If the object's
C<is_own_logon> is true, then the object itself is returned.

=head2 get_dbh()

Returns the database handle used by the object.

=cut

sub get_login {
	my ($self) = @_;
	
	$self->{'is_own_login'} and return $self;
	return $self->{'login'};
}
# 
# get_login
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# validate
# 

=head2 X<DBIx::Record.validate>validate()

Validates the record.  Returns true if the record passes valdation, false otherwise.  
If there are any errors,they will be in C<@DBIx::Record::errors>.

Calls C<L<validate_fields()|/DBIx::Record.validate_fields>>, holding on
to the returned array of errors. If no errors are found, or if
C<L<always_rl_validate()|/DBIx::Record.always_rl_validate>> returns true,
the process then calls
C<L<record_level_validate()|/DBIx::Record.record_level_validate>>,
holding on to those errors.

Before any valdation is done, the C<still_valid> method is called. If
it returns true, then the record has not been changed since it was
retrieved from the database, or since it was last confirmed as valid,
so no validation is needed and C<validate> returns true.

If errors are found, C<validate> returns false. C<@DBIx::Record::errors>
contains an array of errors.

=cut

sub validate {
	my ($self) = @_;
	my ($fields, $rl);
	
	# if already validated, and no records have changed since then
	if ($self->still_valid)
		{return 1}
	
	# validate fields
	$fields = $self->validate_fields();
	
	# if fields validated, or if always_rl_validate
	# do record-level validation
	if ($fields || $self->always_rl_validate)
		{$rl = $self->record_level_validate}
	
	# return $fields and $rl
	if ($fields && $rl) {
		$self->fields_object->{'validated'} = 0;
		return 1;
	}
	
	return 0;
}
# 
# validate
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# validate_fields
# 

=head2 X<DBIx::Record.validate_fields>validate_fields()

Loops through all L<changed
fields|/DBIx::Record::FieldHash.changed_fields> and runs their
X<DBIx::Record::Field.validate>C<validate> methods. If any of the
validations return false, then this method returns false. Otherwise it
returns true.

=cut

sub validate_fields {
	my ($self) = @_;
	my $rv = 1;
	
	# loop through changed fields
	foreach my $fn ($self->changed)
		{$self->{'f'}->{$fn}->validate($self) or $rv = 0}
	
	return $rv;
}
# 
# validate_fields
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# still_valid
# 

=head2 X<DBIx::Record.still_valid>still_valid()

Returns true if the record has been validated before and the record has not changed since that validation.

=cut

sub still_valid {
	my ($self) = @_;
	
	# if validated_once, and fields have not changed
	return $self->fields_object->{'validated'};
}
# 
# still_valid
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# changed & reset
# 

=head2 X<DBIx::Record.changed>changed()

Returns an array of the names of fields that have changed since the record object was created or since the last save.
For a new record, all fields are noted as "changed" when the object is created.

This method actually just calls the C<changed()> method of the C<DBIx::Record::FieldHash> object.

=cut

sub changed {return $_[0]->fields_object->changed}


=head2 X<DBIx::Record.reset>reset()

Sets the record so that no fields are marked as changed.  The values of the fields are I<not> changed back to their original values.

This method actually just calls the C<reset()> method of the C<DBIx::Record::FieldHash> object.

=cut

sub reset   {return $_[0]->fields_object->reset}
# 
# changed & reset
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# display_record
# 

=head2 X<DBIx::Record.display_record>static display_record()

Returns a single record with just the fields listed in display_fields.

=cut

sub display_record {
	my ($class, $login, $pk, %opts) = @_;
	$class->add_display_options(\%opts);
	return $class->new($login, $pk, %opts);
}
# 
# display_record
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# display_set
# 

=head2 X<DBIx::Record.display_record>static display_record()

Returns a looper object just like get_records, but with the display fields
specifically requested.

=cut

sub display_set {
	my ($class, $login, %opts) = @_;
	$class->add_display_options(\%opts);
	return $class->get_records($login, %opts);
}
# 
# display_set
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# add_display_options
# 
# Adds the display options to the given hash
# 
sub add_display_options {
	my ($class, $opts) = @_;
	my %adds = $class->display_options;
	
	while (my($n, $v) = each(%adds))
		{$opts->{$n} = $v}

}
# 
# add_display_options
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# display_record_str
# 

=head2 X<DBIx::Record.display_record>static display_record()

Returns the output of the C<display_str> method of the record with the given pk.

=cut

sub display_record_str {
	my ($class, $login, $pk) = @_;
	my $rec = $class->display_record($login, $pk);
	
	$rec or return undef;
	
	return $rec->display_str;
}
# 
# display_str
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# misc utils
# 

=head2 X<DBIx::Record.crunch>static crunch()

Trims leading and trailing space, crunches internal contiguous whitespace
to single spaces.  In void context, modifies the input param itself.  Otherwise
crunches and returns the modified value.

=cut

sub crunch {
	my $array = defined(wantarray) ? [@_] : \@_;
	grep {s|^\s+||s;s|\s+$||s;s|\s+| |sg;} @$array;
	wantarray ? @$array : $array->[0];
}



=head2 X<DBIx::Record.tc>static tc()

Sets the given string title case: the beginning strings are in uppercase, everything else is lowwer case.
In void context, modifies the input param itself.  Otherwise
crunches and returns the modified value.

=cut

sub tc {
	my $array = defined(wantarray) ? [@_] : \@_;
	
	grep {
		tr/A-Z/a-z/;
		s|\b(\w)|\U$1|gs;
	} @$array;
	
	wantarray ? @$array : $array->[0];
}


# as_arr
# If the given value is a scalar, changes it to an array ref with just that
# scalar.  If it's undef, does nothing.
sub as_arr {
	defined $_[0] or return;
	ref($_[0]) or $_[0] = [$_[0]];
}



=head2 X<DBIx::Record.crunch>static htmlesc()

Escapes the given string for display in a web page. In void context, modifies the input param itself.  Otherwise
crunches and returns the modified value.

=cut

sub htmlesc {
	my $array = defined(wantarray) ? [@_] : \@_;
	
	grep {
		if (defined $_) {
			s|&|&#38;|g;
			s|"|&#34;|g;
			s|'|&#39;|g;
			s|<|&#60;|g;
			s|>|&#62;|g;
		}
		else
			{$_ = ''}
	} @$array;
	
	wantarray ? @$array : $array->[0];
}

=head2 X<DBIx::Record.crunch>static hascontent()

Returns true if the given scalar is defined and contains something besides whitespace.

=cut

sub hascontent {
	my ($val) = @_;
	defined($val) or return 0;
	return $val =~ m|\S|s;
}

# 
# misc utils
#---------------------------------------------------------------------


#-----------------------------------------------------------------------
# strip_html
# 

=head2 X<DBIx::Record.crunch>static strip_html()

Removes all HTML tags from the given string.

=cut

sub strip_html {
	my ($html) = @_;
	my (@pieces);
	
	# split
	@pieces = grep {length($_)} split(
		m/
			(
				\<
					(?:
						[^'"\>]+   |
						"[^"]*"  |
						'[^']*'
					)
					*?
				>
			)
		/gsx
		, $html);
	
	@pieces = grep {
		my $rv;
		if (m|^\<\/?([^\s\>\/]+).*\>$|) {
			if (! exists $nospace{lc $1}) {
				$rv = 1;
				$_ = ' ';
			}
		}
		else
			{$rv = 1}
		$rv;
	} @pieces;
	
	$html = join('', @pieces);
	return crunch($html);
}
# 
# strip_html
#-----------------------------------------------------------------------


#---------------------------------------------------------------------
# create_login
#

=head2 X<DBIx::Record::Application.create_login>static create_login()

This method sets C<$login> to either a
L<DBIx::Record::Login|/DBIx::Record::Login> object, or a DBI database
handle. This method returns true/false indicating success. This method
is the most loosely defined in C<DBIx::Record> That is because every
application will have a different way of creating login objects and
connecting to the database.

=cut

sub create_login {die 'override create_login in the application layer'}
#
# create_login
#---------------------------------------------------------------------



#---------------------------------------------------------------------
# record_level_validate
#

=head2 X<Application::Table.record_level_validate>record_level_validate()

Override this method in the table layer.

This method is called by C<L<validate()|/DBIx::Record.validate>> to allow
the designer to perform custom validation beyond that which is
performed at the L<field level|/DBIx::Record.validate_fields>. This
method returns true/false indicating success. The default is to return
true. This method should I<not> be used to check field-level business
rules such as "required". Those checks are done by the individual field
objects and are all called by
L<C<validate_fields>|/DBIx::Record.validate_fields>, which is also called
by C<L<save|/DBIx::Record.save>>.

Designers of extensions of this subroutine should be sensitive to the
fact that not all of the fields for a given record may be loaded into
the object. Therefore, checks on relationships between several fields
may not be necessary if not all of those fields are loaded.

=cut

sub record_level_validate {1}

#
# record_level_validate
#---------------------------------------------------------------------



#---------------------------------------------------------------------
# always_rl_validate
#

=head2 X<DBIx::Record.always_rl_validate>always_rl_validate()

Override this method in the table layer.

If this method returns true, then when C<L<validate()|/DBIx::Record.validate>> calls
C<L<validate_fields()|/validate_fields>> and it gets errors, it
I<still> calls C<record_level_validate()>. Defaults to false.

=cut

sub always_rl_validate {0}
#
# always_rl_validate
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# table_name, pk_field_name
# 

=head2 static X<Application::Table.simple_methods>table_name(), static pk_field_name()

These methods provide simple information about a specific table.
C<table_name> returns the name of the table. C<pk_field_name> returns
the name of the primary key field.

These methods simply return a string. They require no arguments and can
be called as either static or object methods. Generally each can be
implemented in a single line of code:

 sub table_name       {'COUNTRY'}
 sub key_field_name   {'COUNTRY_ID'}

=cut

sub table_name       {die 'override table_name in the table layer'}
sub pk_field_name    {die 'override pk_field_name in the table layer'}
# 
# table_name, pk_field_name
#---------------------------------------------------------------------



#---------------------------------------------------------------------
# display_str, display_fields
# 

=head2 X<Application::Table.display_name>display_str(), static display_fields()

C<display_str> outputs a string that is used to indicate this record. Usually this
method is used in lists of records. For example, in a table holding
country names, this method would return the name of the country (e.g.
"England", "Canada"). In a list of people, this record could return the
list of people's names.

C<display_str> returns an array ref of fields that are used by C<display_str>.

=cut

sub display_str      {die 'override display_str in the table layer'}
sub display_fields   {die 'override display_fields in the table layer'}
# 
# display_str, display_fields
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# events
# 

=head2 before_create(), after_create(), before_update(), after_update(), before_delete(), after_delete

These methods are called before and after the creation, update, and
deletion of a record. If any of "before" events return false 
then the event is cancelled. By default all of these simply
return true.

=cut


sub before_insert {1}
sub after_insert  {1}
sub before_update {1}
sub after_update  {1}
sub before_delete {1}
sub after_delete  {1}
# 
# events
#---------------------------------------------------------------------


#---------------------------------------------------------------------
# field_defs
# 

=head2 static X<Application::Table.field_defs>static field_defs()

This method returns a hash of field definitions. Each field definition
is itself a hash of properties for that field. These definitions are
used to create the fields in the C<f> property of
C<L<DBIx::Record::Field|/DBIx::Record::Field>> objects.

Each key in the hash is the name of the field. Field names should
always be lowercase. The value consists of a hash of field properties.
The only required property is the name of the class of the field. Other
properties are passed to the L<C<field object>|/DBIx::Record::Field>
constructor and will generally be used to set properties of that field
object.

The C<default> property is used to set the default value of the field.
That value is passed to the field object constructor via its
L<C<set_from_interface>|/DBIx::Record::Field.set_from_interface> method.

C<field_defs> determines the definitions in any way the programmer
chooses, but generally it's easiest to simply create and return the
hash directly in the sub, like this:

 sub field_defs {
 	return 
 		name => {
 			class    =>    'DBIx::Record::Text',
 			required =>    1,
 			display_size   =>  25,
 			maxsize  =>    50,
 			},
 		email => {
 			class    =>  'DBIx::Record::Text',
 			rows     =>  5,
 			cols     =>  70,
 			maxsize  =>  '1k',
 			},
 		comments => {
 			class    =>  'DBIx::Record::TextArea',
 			},
 		;
 }

=cut

sub field_defs {die 'override field_defs in the table layer'}
# 
# field_defs
#---------------------------------------------------------------------


#-----------------------------------------------------------------------
# record_delete
# 

=head2 X<DBIx::Record::DBFormat::format.record_delete>static record_delete($dbh, $pk)

Deletes the record in the given table with the given primary key. This
method returns true/false indicating success. Implement this method in the 
database format layer.

=cut

sub record_delete {die 'override record_delete in the database format layer'}
# 
# record_delete
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# select_single
# 

=head2 X<DBIx::Record::DBFormat::format.select_single>static select_single($dbh, $pk, %options)

Retrieves the record's data from the database, returning a hash of the
fields and data. By default, all the fields are retrieved and returned.
If the C<fields> option is sent, then only the fields listed there
should be retrieved.

=cut

sub select_single {die 'override select_single in the database format layer'}
# 
# select_single
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# select_multiple
# 

=head2 X<DBIx::Record::DBFormat::format.select_multiple>static select_multiple($dbh, %options)

This static function is implemented in the database format layer.  C<select_multiple> selects
a set of records from the class' table, returning a DBI statement handle of that selection.  The
statement handle should I<not> be executed.

In its simplest form, C<select_multiple> selects all fields in all records in
the entire table:

 $sth = MyApp::Clients->select_multiple($dbh);

The optional arguments filter down the results:

=over

=item fields

C<fields> is an array of the names of fields to retrieve. The default
is C<*>, which may also be sent explicitly. So, for example, this code
retrieves the C<name> and C<email> fields:

 $sth = MyApp::Clients->select_multiple($dbh, fields=>['name', 'email']);

Regardless of what fields are listed in this argument,
C<select_multiple> should B<always> return the primary key in the
return hash.

=item order

This option is an array of fields on which the select should be
ordered. For example, the following code sets the order to C<age> then
C<name>:

 $sth = MyApp::Clients->select_multiple(
 	fields => ['name', 'email'],
 	order => ['age', 'name']);

=item where_str

This option is a where clause to add to the select. For example, the
following code sets the where clause to people under 21:

 $sth = MyApp::Clients->select_multiple(
 	fields => ['name', 'email'],
 	where_str  => 'age < 21');

=item bindings

This option is only used when there is also a C<where> option. This
option is an array of values associated with the bound params in the
where clause. So, for example, this code binds 21 to the first param
and 'm' to the second:

 $sth = MyApp::Clients->select_multiple(
 	fields    => ['name', 'email'],
 	where     => 'age < ? and gender=?',
 	bindings  => [21, 'm']
 	);

=back

=cut

sub select_multiple {die 'override select_multiple in the database format layer'}
# 
# select_multiple
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# select_exists
# 

=head2 X<DBIx::Record::DBFormat.record_exists>static select_exists($dbh, $pk)

Returns true if a record with the given primary key exists in the given
table.

=cut

sub select_exists {die 'override select_exists in the database format layer'}
# 
# select_exists
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# update
# 

=head2 X<DBIx::Record::DBFormat::format.update>static update($dbh, $pk, %fields)

This static function is implemented in the database format layer.  
This method saves the fields in the C<%fields> to a specific existing
record. The hash will always contain at least one name/value pair, and
the function can assume that the record already exists. This method
returns true/false indicating success.

=cut

sub update {die 'override update in the database format layer'}
# 
# update
#-----------------------------------------------------------------------



#-----------------------------------------------------------------------
# insert
# 

=head2 X<DBIx::Record::DBFormat::format.insert>static insert($dbh, $pk, %fields)

This method creates a new record in the table and returns the primary key
of that new record. C<%fields> ius a hash of field names and values for the new
record. The hash may have any number of name/value pairs, including
none. This method returns true/false indicating success.

=cut

sub insert {die 'override insert in the database format layer'}
# 
# insert
#-----------------------------------------------------------------------


########################################################################
# DBIx::Record::Login
# 

=head2 interface X<DBIx::Record::Login>DBIx::Record::Login

A C<DBIx::Record::Login> object represents the connection to the
database. C<DBIx::Record::Login> is an interface class: it is not
provided by C<DBIx::Record>. Each application must provide its own class
that implements the C<DBIx::Record::Login> interface. Alternatively, the
application can pass around a DBI database handle object and never
implement a C<DBIx::Record::Login> class.

=head2 X<DBIx::Record::Login.get_dbh>get_dbh

Returns an active database handle.

=cut

# 
# DBIx::Record::Login
########################################################################



########################################################################
# DBIx::Record::FieldHash
# 
package DBIx::Record::FieldHash;
use Carp qw[croak confess];


=head2 DBIx::Record::FieldHash

This is the tied hash class that is used to create the tied hash for
the C<f> property of the record object.

=head2 id, login, class

The id, login, and class of the parent record object. Because of Perl's
difficulty in garbage collecting circular references, we don't store a
direct reference to the parent record object. Instead, we hold on to
the info we would need in case we need to retrieve any other fields.

=head2 fields

Hash of field objects.

=head2 X<DBIx::Record::FieldHash.changed_fields>changed_fields

This property indicates which fields have been changed since the record
object was created. When the C<L<save|/DBIx::Record.save>> method is
called, if no fields have been changed, then no save is done. If any
fields have changed, only those fields that have changed are stored
back into the database. C<changed_fields> consists of a hash whose keys
are the changed field names. The values of the hash are not important.

=cut


#-----------------------------------------------------------------------
# changed
# 

=head2 X<DBIx::Record::FieldHash.changed>changed()

Returns an array of the names of fields that have changed since the record object was created or since the last save.
For a new record, all fields are noted as "changed" when the object is created.

=cut

sub changed {
	my $self = shift;
	return keys(%{$self->{'changed_fields'}});
}
# 
# changed
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# reset
# 

=head2 X<DBIx::Record::FieldHash.reset>reset()

Sets the record so that no fields are marked as changed.  The values of the fields are I<not> changed back to their original values.

=cut

sub reset {
	my ($self) = @_;
	$self->{'changed_fields'} = {};
	$self->{'validated'} = 1;
	return 1;
}
# 
# reset
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# TIEHASH
# 

=head2 TIEHASH($class, $record)

Instantiates the object, stores the record's id, login, and class
properties in itself. Creates the C<fields> hash.

=cut

sub TIEHASH {
	my ($class, $record) = @_;
	my $self  = bless({},$class);
	
	# record properties
	$self->{'pk'} = $record->{'pk'};
	$self->{'login'} = $record->{'login'};
	$self->{'class'} = ref($record);
	
	$self->{'cache'} = {};
	$self->reset;
	
	# return
	return $self;
}
# 
# TIEHASH
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# FETCH
# 

=head2 FETCH($key)

Returns the given key from the C<fields> hash. If the field doesn't
exist then the value is loaded from the database, stored in the
C<fields> hash, and returned.

=cut

sub FETCH {
	return $_[0]->{'cache'}->{lc $_[1]};
}
# 
# FETCH
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# STORE
# 

=head2 STORE($key, $val)

If the given val is a C<L<DBIx::Record::Field|/DBIx::Record::Field>> object
(or any class that extends C<DBIx::Record::Field>), then that object is
stored directly in the C<fields> hash, and the field name is stored in
C<changed_fields>. If the C<fields> hash already contains a
C<DBIx::Record::Field> object with that key, then the value is passed to
the object using its C<set_from_interface> method.

If the field doesn't exist in the C<fields> hash, then the class's
C<field_defs> method is called, and a definition for that field name is
sought. If the definition is found, then the field object is added to
the hash and the value stored in it as before.

If the field doesn't exist in the field definitions, then a fatal error
occurs.

=cut

sub STORE {
	my ($self, $fieldname, $fieldval, %opts) = @_;
	$fieldname = lc($fieldname);
	
	if ( UNIVERSAL::isa($fieldval, 'DBIx::Record::Field') ) {
		$self->{'cache'}->{$fieldname} = $fieldval;
		
		if ($opts{'from_db'})
			{delete $self->{'changed_fields'}->{$fieldname}}
		else {
			undef $self->{'changed_fields'}->{$fieldname};
			undef $self->{'validated'};
		}
	}
	
	else {
		# if field does not exist
		if (! exists $self->{'cache'}->{$fieldname})
			{croak "do not have field named $fieldname"}
		
		$self->{'cache'}->{$fieldname}->set_from_interface($fieldval);
		$self->{'changed_fields'}->{$fieldname} = 1;
		$self->{'validated'} = 0;
	}
}
# 
# STORE
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# DELETE
# 

=head2 DELETE

This one's a little weird. You don't delete fields from a database. In
this situation it makes sense to say that delete means "remove from the
cache, don't save any value".

=cut

sub DELETE {
	my ($self, $fieldname) = @_;
	$fieldname = lc($fieldname);
	delete $self->{'cache'}->{$fieldname};
	delete $self->{'changed_fields'}->{$fieldname};
}
# 
# DELETE
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# CLEAR
# 
=head2 CLEAR

Clears out all the fields from the C<fields> hash and sets C<changed>
to false.

=cut

sub CLEAR {
	my $self = shift;
	$self->{'cache'} = {};
	$self->{'changed_fields'} = {};
}
# 
# CLEAR
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# EXISTS
# 

=head2 EXISTS

Returns true if the given field exists in the C<fields> hash. 

=cut

sub EXISTS {
	my ($self, $fieldname) = @_;
	$fieldname = lc($fieldname);
	return exists($self->{'cache'}->{$fieldname});
}
# 
# EXISTS
#-----------------------------------------------------------------------



#-----------------------------------------------------------------------
# FIRSTKEY, NEXTKEY
# 

=head2 FIRSTKEY, NEXTKEY

Used to cycle through the C<fields> hash in the normal tied hash
manner.

=cut

sub FIRSTKEY {
	my $self = shift;
	my $a = keys %{$self->{'cache'}};
	return scalar each %{$self->{'cache'}};
}

sub NEXTKEY {
	my $self = shift;
	return scalar each %{$self->{'cache'}};
}
# 
# FIRSTKEY, NEXTKEY
#-----------------------------------------------------------------------



#
# DBIx::Record::FieldHash
########################################################################


########################################################################
# DBIx::Record::Looper
# 
package DBIx::Record::Looper;
use strict;
# use Dev::ShowStuff ':all';
use Carp 'cluck', 'croak', 'confess';

=head1 DBIx::Record::Looper

A looper object is used to iterate through the results of a select
statement. Each call to L<C<next>|/DBIx::Record::Looper.next> returns a
L<C<DBIx::Record>|/DBIx::Record> object of the class that created the
looper. So, for example, this code selects all clients and returns
their information one at a time:

 $looper = MyApp::Client->get_records();
 
 while (my $client = $looper->next) {
 	...
 }

Looper objects are lazy... they do not actually connect to the database
until the first C<next> method is called. After the last record is
returned, they close the statement handle.

=head2 sth

The statement handle being held for looping through.

=head2 class

The name of the class of the returned record objects.

=head2 executed

If false, then the statement handle has not been executed yet.

=cut

#-----------------------------------------------------------------------
# new
# 

=head2 static new($class, $sth)

This method is the constructor. This method creates the looper object
and stores the class name and the statement handle that are passed as
the arguments.

=cut

sub new {
	my ($class, $login, $bless_class, $sth) = @_;
	my $self = bless({}, $class);
	
	$self->{'login'} = $login;
	$self->{'bless_class'} = $bless_class;
	$self->{'sth'} = $sth;
	
	return $self;
}
# 
# new
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# next
# 

=head2 X<DBIx::Record::Looper.next>next

This method instantiates and returns a single record object
representing the next record in the statement handle.

If the C<executed> property is false, then this is the first time that
C<next> has been called. The statement handle is executed and
C<executed> is set to true.

If the statement handle returns undef, then the handle is done and is
undeffed.

=cut

sub next {
	my ($self) = @_;
	my ($rv);
	
	# if no statement handle, just keep returning undef
	$self->{'sth'} or return undef;
	
	# check if the statement has been executed
	if (! $self->{'executed'}) {
		$self->{'sth'}->execute or return DBIx::Record::add_dbierror();
		$self->{'executed'} = 1;
	}
	
	# get next row	
	$rv = $self->{'bless_class'}->new($self->{'login'}, $self->{'sth'});
	
	# if no next row, undef the statement handle
	$rv or delete $self->{'sth'};
	
	return $rv;
}
# 
# next
#-----------------------------------------------------------------------


# 
# DBIx::Record::Looper
########################################################################



########################################################################
# DBIx::Record::Error
# 
package DBIx::Record::Error;
use strict;
# use Dev::ShowStuff ':all';
use Carp 'cluck', 'croak', 'confess';


=head2 DBIx::Record::Error

C<DBIx::Record::Error> objects represent a single error message returned
by a function. The object oriented format of the error messages allow
function to return messages that take advantage of HTML while still
restricting themselves to plain text when necessary.

=head2 text

The plain text of the error message.

=head2 html

The HTML version of the error message.

=cut


#-----------------------------------------------------------------------
# new
# 

=head2 static new(%options)

Instantiates an error object. The optional arguments must have either
C<html> or C<text>. If neither is sent then a fatal error occurs. The
options are stored in the C<html> or C<text> properties as appropriate.

=cut

sub new {
	my ($class, %opts) = @_;
	my $self = bless({}, $class);
	
	# get text and html
	$self->{'text'} = $opts{'text'};
	$self->{'html'} = $opts{'html'};
	
	# must get at least one or fatal error
	unless (defined($opts{'text'}) || defined($opts{'html'}))
		{croak "cannot instantiate DBIx::Record::Error without 'text' or 'html' option"}
	
	return $self;
}
# 
# new
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# add
# 

=head2 static add(%options)

This static method works just like C<new()>, except that instead of returning the error object, 
it adds the object to the C<@DBIx::Record::errors> array.

=cut

sub add {
	my $class = shift;
	my $new = $class->new(@_);
	return DBIx::Record::add_error($new);
}
# 
# add
#-----------------------------------------------------------------------



#-----------------------------------------------------------------------
# output
# 

=head2 output($media)

Returns the error message for the given media. 

$media should be
C<DBIx::Record::MEDIA_TEXT>, 
C<DBIx::Record::MEDIA_HTML>, or
C<DBIx::Record::MEDIA_HTML_FORM>.

If the object's C<text> property is defined,
but C<html> is not, and if the media indicates HTML, then the C<text>
property is HTML escaped and output. If text is called for and there is
only HTML, then all HTML is stripped (though for the time being
probably not very well for this first release) and returned. If there
is neither, then a fatal error occurs.

=cut

sub output {
	my ($self, $media) = @_;
	
	# text
	if ($media == DBIx::Record::MEDIA_TEXT) {
		defined($self->{'text'}) and return $self->{'text'};
		return DBIx::Record::strip_html($self->{'html'});
	}
	
	# return
	defined($self->{'html'}) and return $self->{'html'};
	return DBIx::Record::htmlesc($self->{'text'});
}
# 
# output
#-----------------------------------------------------------------------




# 
# DBIx::Record::Error
########################################################################



########################################################################
# DBIx::Record::MediaOb
#
# an object that implements the Media Object interface
# for development experimentation purposes
#
package DBIx::Record::MediaOb;
use strict;
# use Dev::ShowStuff ':all';
use Carp 'cluck', 'croak', 'confess';


#-----------------------------------------------------------------------
# new
# 
sub new {
	my ($class) = @_;
	my $self = bless({}, $class);
	
	# default media to HTML
	$self->{'media'} = DBIx::Record::MEDIA_HTML;
	
	# return
	return $self;
}
# 
# new
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# get_media
# 
sub get_media {
	my ($self) = @_;
	return $self->{'media'};
}
# 
# get_media
#-----------------------------------------------------------------------



# 
# DBIx::Record::MediaOb
########################################################################



########################################################################
# DBIx::Record::Field
# 
package DBIx::Record::Field;
use strict;
# use Dev::ShowStuff ':all';
use Carp 'cluck', 'croak', 'confess';


=head1 abstract X<DBIx::Record::Field>DBIx::Record::Field

C<DBIx::Record::Field> represents a single field in a record. A
C<DBIx::Record::Field> knows how to dislay itself in three different
medias, can deserialize itself from two types of data sources, and
knows how to format itself for saving in the database.
C<DBIx::Record::Field> allows the application designer to define once how
a field is displayed and stored, and then use that definition in many
different places.

C<DBIx::Record::Field> is an abstract class. It is extended by several
different classes to implement different types of fields.
C<DBIx::Record::Field> objects stringify to the results of the
C<output()> method. By doing so, fields can be easily output in Perl
"here" documents.

=head2 field_name

The name of the field that is stored in the database.

=head2 value

This property holds the value of the field. Strictly speaking, the type
of data (scalar, array reference, hash reference) that is stored in
this property is up to each extending field class. Calculated fields
may not even use this property. However, default values will be stored
in this property, and extending classes should customarily store data
here.

=head2 required

Indicates if the field is required. Generally it implies that the value
may not be an empty string, and must contain something besides
whitespace. However, extending classes may interpret this property
however they want.

=head2 desc_short

A short description of the field, what many people might call the
"name" of the field. This will often be different than the id. For
example, a field might have a field with an id of C<phone> but a
C<desc_short> of "Phone number".

=head2 desc_long_text

A long text description of the field. This field may be of any length,
but 100 characters is the upper limit of good taste. This field may be
left undefined, in which it is simply not output.

=head2 desc_long_html

The HTML version of C<desc_long_text>. If this property is not defined,
then C<desc_long_text> is HTML escaped and output to the web page.

=head2 media

This property indicates how the field data should be displayed. There
will be three possible values, set as constants in the C<DBIx::Record>
namespace:

=over

=item TEXT: the data should be output as plain text

=item HTML: the data should be output for display in a web page

=item HTML_FORM_FIELD: the data should be output as a form field

=back

=head2 media_object

If this property is set, the object it references is used to determine
the display media rather than the C<media> property itself. The object
must implement the C<get_media> method.

=cut


#-----------------------------------------------------------------------
# stringify the object
# 

=head2 stringification

Field objects stringify to the output of their C<output>methods.
Therefore, the two following commands function identically:

  print $myfield->output;
  print $myfield;

=cut

use overload '""'=>\&text_display, fallback=>1;
# 
# stringify the object
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# new
# 

=head2 static new($definition, $login)

C<new> is the constructor for field objects. C<new> takes two arguments. 
C<$definition> is the field definition as returned by the table layer's 
L<C<field_defs>|/Application::Table.field_defs> method. C<$login> is the
login object used to communicate with the database.

=cut

sub new {
	my ($class, $def, $login) = @_;
	my ($self, $default);
	
	# remove class property
	delete $def->{'class'};
	$default = delete $def->{'default'};
	
	# field aliases
	if (defined $def->{'desc_long'})
		{$def->{'desc_long_text'} = delete $def->{'desc_long'}}
	
	# instantiate
	$self = bless({%$def}, $class);
	
	# default media to HTML
	$self->{'media'} = DBIx::Record::MEDIA_HTML;
	
	# hold on to login object
	$self->{'login'} = $login;

	# return
	return $self;
}
# 
# new
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# output
# 

=head2 output(%options)

Returns the results of either C<text_display()>, C<html_display()>, or
C<html_form_field()>, depending on the media type. This method is used
by the stringification class property to display the field according to
the proper media.

=cut

sub output {
	my ($self, %opts) = @_;
	my ($media);
	
	# media
	if ($opts{'media'})
		{$media = $opts{'media'}}
	elsif ($self->{'media_object'})
		{$media = $self->{'media_object'}->get_media or die('did not get valid media code from media object')}
	else
		{$media = $self->{'media'}}
	
	# text
	if ($media == DBIx::Record::MEDIA_TEXT)
		{return $self->text_display}
	
	# html
	if ($media == DBIx::Record::MEDIA_HTML)
		{return $self->html_display}
	
	# html form field
	if ($media == DBIx::Record::MEDIA_HTML_FORM)
		{return $self->html_form_field}
	
	# if we get this far, we don't recognize the media
	die 'do not recognize media code: ' . $media;
}
# 
# output
#-----------------------------------------------------------------------



#-----------------------------------------------------------------------
# html hidden field
# 
sub html_hidden {
	my ($self) = @_;
	return 
		'<INPUT TYPE=HIDDEN NAME="' . 
		DBIx::Record::htmlesc($self->{'field_name'}) . '" VALUE="' . 
		$self->value_html . "\">\n";

}
# 
# html hidden field
#-----------------------------------------------------------------------



#-----------------------------------------------------------------------
# html_display_row()
# 

=head2 X<DBIx::Record::Field.html_display_row>html_display_row()

Returns an entire row of an HTML table for displaying the name,
description, and value of a form field. Typically, the first column
will contain the C<shortdesc> of the field and the C<longdeschtml> (if
it exists) below that. The second column will contain the form field or
the html value. In no cases should this method return more than two
HTML table columns.

=cut

sub html_display_row {
	my ($self) = @_;
	my (@rv);
	
	# open row
	push @rv,
		'<TR VALIGN=TOP CLASS="dbrecord_html_row">', "\n",
		'<TD CLASS="dbrecord_html_row_name"><SPAN CLASS="dbrecord_desc_short">',
		DBIx::Record::htmlesc($self->{'desc_short'}), '</SPAN>';
	
	# long description, if it's there
	if (defined $self->{'desc_long_html'})
		{push @rv, '<P CLASS="dbrecord_desc_long">', $self->{'desc_long_html'}, '</P>'}
	elsif (defined $self->{'desc_long_text'})
		{push @rv, '<P CLASS="dbrecord_desc_long">', DBIx::Record::htmlesc($self->{'desc_long_text'}), '</P>'}
	
	# finish row
	push @rv, '</TD>', "\n", '<TD CLASS="dbrecord_html_row_field">', $self->output, "</TD>\n</TR>\n\n";
	
	return join('', @rv);
}
# 
# html_display_row()
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# desc_short_html
# 
sub desc_short_html {
	return '<CODE CLASS="field_desc_short">' . DBIx::Record::htmlesc($_[0]->{'desc_short'}) . '</CODE>';
}
# 
# desc_short_html
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# value_html
# 
sub value_html {
	return DBIx::Record::htmlesc($_[0]->{'value'});
}
# 
# value_html
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# abstractish set_from_interface($value)
# 

=head2 X<DBIx::Record::Field.set_from_interface>abstractish set_from_interface($value)

Sets the value based on the value received from the user interface.

=cut

sub set_from_interface{return $_[0]->{'value'} = $_[1]}
# 
# abstractish set_from_interface($val)
#-----------------------------------------------------------------------



#-----------------------------------------------------------------------
# abstractish set_from_db($value)
# 

=head2 abstract set_from_db()

Sets the value of the field based on the value returned from the
database. By default this method is just calls C<set_from_interface>.

=cut

sub set_from_db{return set_from_interface(@_)}
# 
# abstractish set_from_db($value)
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# abstractish send_to_db()
# 

=head2 abstractish send_to_db()

Returns the value that should be stored in the database. By default 
this method just calls C<text_display>.

=cut

sub send_to_db{return text_display(@_)}
# 
# abstractish send_to_db()
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# validate()
# 

=head2 X<DBIx::Record::Field.validate>abstractish validate($rec)

Checks if the data in the field violates any business rules for the
field. This method returns true/false indicating success. The default
base implementation of this method always returns true. The first
argument is the C<DBIx::Record> object, which may be used to do external
checks on the field data.

=cut

sub validate{1}
# 
# validate()
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# store_in_db()
# 
=head2 store_in_db()

If this method returns true, the field is saved to the database.
Otherwise, it is not. This method allows calculated fields to act like
"regular" fields without being actually saved to the database. The
default for this method is to return true.

=cut

sub store_in_db{1}
# 
# store_in_db()
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# foreign_key()
# 
# don't think this is used anywhere anymore
# 
# sub foreign_key{undef}
# 
# foreign_key()
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# text_display()
# 

=head2 abstract text_display()

Returns the value that should be displayed exactly as-is in a
text-based interface. By default this method simply
returns the value of the C<value> property.

=cut

sub text_display{return $_[0]->{'value'}}
# 
# text_display()
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# abstractish html_display()
# 

=head2 abstractish html_display()

Returns the value that should be displayed (not as a form field) in a
web page. Text-fields, for example, will simply return the text with
the HTML escaped. In C<DBIx::Record::Field>, this method simply returns
the HTML escaped value of the C<value> property.

=cut

sub html_display{
	my $rv = $_[0]->text_display;
	
	if (DBIx::Record::hascontent($rv))
		{return DBIx::Record::htmlesc($rv)}
	return '<I>none</I>';
}
# 
# abstractish html_display()
#-----------------------------------------------------------------------



#-----------------------------------------------------------------------
# abstract html_form_field
# 

=head2 abstract html_form_field()

Returns the HTML to display the field in an HTML form. The code should 
default the field to its current value.

=cut

sub html_form_field{die 'override html_form_field in ' . ref($_[0]) . "\n"}
# 
# abstract html_form_field
#-----------------------------------------------------------------------



# 
# DBIx::Record::Field
########################################################################



########################################################################
# DBIx::Record::Field::Text
# 
package DBIx::Record::Field::Text;
use strict;
# use Dev::ShowStuff ':all';
use Carp 'cluck', 'croak', 'confess';
use vars qw[@ISA];
@ISA = 'DBIx::Record::Field';


=head2 DBIx::Record::Field::Text I<extends C<DBIx::Record::Field>>

This class represents a short text field. Examples of data that would
use C<DBIx::Record::Field::Text> would be people's names.

=head2 crunch

Indicates that the data should have leading and trailing whitespace
removed, and internal whitespace crunched down to single spaces.

=head2 display_size

Indicates how many characters wide the text field should be in form
editing.

=head2 max_size

Indicates that the maximum number of characters the text may be. 0 or
undef indicate no maximum size. 'k' may be appended to the value to
indicate that the size is in kilobytes, or 'm' to indicate that the
value is in meg. For example, '3k' would indicate that the string may
be 3 kilobytes long.

=head2 upper, lower, title

If any of these properties are true, then the data is uppercased,
lowercased, or title-cased when it is imported from the user interface.

=cut


#-----------------------------------------------------------------------
# html_form_field
# 

=head2 html_form_field()

Returns the HTML code for an C<E<lt>INPUTE<gt>> element. The size of
the field is set to the C<size> property.

=cut

sub html_form_field {
	my ($self) = @_;
	my (@rv);
	
	# open tag
	push @rv,
		'<INPUT NAME="',
		DBIx::Record::htmlesc($self->{'field_name'}), '" ',
		'VALUE="', $self->value_html, '"';
	
	# size
	if (defined $self->{'display_size'})
		{push @rv, ' SIZE=', $self->{'display_size'}}
	
	# max_size
	if (defined $self->{'max_size'})
		{push @rv, ' MAXLENGTH=', $self->{'max_size'}}
	
	# close tag
	push @rv, '>';

	# return
	return join('', @rv);
}
# 
# html_form_field
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# set_from_interface
# 

=head2 set_from_interface()

Overrides C<DBIx::Record::Field>'s C<set_from_interface> to implement the
C<upper>, C<lower>, and C<title> properties.

=cut

sub set_from_interface {
	my ($self, $value) = @_;
	
	# if defined
	if (defined $value) {
		# crunch, trim
		$self->{'crunch'} and DBIx::Record::crunch($value);
		($self->{'trim'} || $self->{'ltrim'}) and $value =~ s|^\s+||s;
		($self->{'trim'} || $self->{'rtrim'}) and $value =~ s|\s+$||s;
		
		# upper/lower/title
		if ($self->{'upper'})
			{$value = uc($value)}
		elsif ($self->{'lower'})
			{$value = lc($value)}
		elsif ($self->{'title'})
			{DBIx::Record::tc $value}
	}

	# else not defined
	else
		{$value = ''}
	
	# set value
	$self->{'value'} = $value;
}
# 
# set_from_interface
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# validate
# 

=head2 X<validate>validate($rec)

Performs a large set of validation checks. If the field is required,
the value must consist of something besides whitespace. If there is a
maxsize, that is checked. If the record is a C<X<foreign_key>static
foreign_key()>, then the foreign key is checked using
L<record_exists($id)|/DBIx::Record::DBFormat.record_delete>.

=cut

sub validate {
	my ($self) = @_;
	my $value = $self->{'value'};
	my $rv = 1;
	
	# required
	if (! DBIx::Record::hascontent $self->{'value'}) {
		if ($self->{'required'}) {
			$rv = DBIx::Record::Error->add (
				text => $self->{'desc_short'} . ' is a required field',
				html => $self->desc_short_html . ' is a required field',
			);
		}
	}

	# max length
	if ($self->{'max_size'}) {
		my $max = $self->{'max_size'};
		$max =~ s|\s*k\s*$||si and $max *= 1024;
		$max =~ s|\s*m\s*$||si and $max *= (1024 * 1024);
		
		if (
			(defined $self->{'value'}) && 
			(length($self->{'value'}) > $max)
			) {
				$rv = DBIx::Record::Error->add (
					text => $self->{'desc_short'} . " may be no longer than $self->{'max_size'} characters",
					html => $self->desc_short_html . " may be no longer than $self->{'max_size'} characters",
				);
		}
	}
	
	return $rv;
}
# 
# validate
#-----------------------------------------------------------------------


# 
# DBIx::Record::Field::Text
########################################################################



########################################################################
# DBIx::Record::Field::Textarea
# 
package DBIx::Record::Field::Textarea;
use strict;
# use Dev::ShowStuff ':all';
use Carp 'cluck', 'croak', 'confess';
use vars qw[@ISA];
@ISA = 'DBIx::Record::Field::Text';


=head2 DBIx::Record::Field::TextArea I<extends C<DBIx::Record::Field::Text>>

C<DBIx::Record::Field::TextArea> objects are just like
C<DBIx::Record::Field::Text> objects except that they provide a much
larger editing area for the user interface.
C<DBIx::Record::Field::TextArea> are for large blocks of text such as
"description" fields.

=head2 rows, cols

Indicates the number of rows and columns to use for the text editing
box.

=cut

#-----------------------------------------------------------------------
# html_display
# 
sub html_display {
	my ($self) = @_;
	my $value = $self->value_html;
	my (@rv);
	
	# put paragraph markers in the text
	$value =~ s|\r\n|\n|sg;
	$value =~ s|\n([ \t]*\n)+|\<P\>|sg;

	# return
	return $value;
}
# 
# html_display
#-----------------------------------------------------------------------



#-----------------------------------------------------------------------
# html_form_field
# 
sub html_form_field {
	my ($self) = @_;
	my (@rv);
	
	# open tag
	push @rv,
		'<TEXTAREA NAME="',
		DBIx::Record::htmlesc($self->{'field_name'}), '"',
	
	# rows, cols
	defined($self->{'rows'}) and push @rv, ' ROWS=', $self->{'rows'};
	defined($self->{'cols'}) and push @rv, ' COLS=', $self->{'cols'};
	
	# close tag, add value
	push @rv, '>', $self->value_html, '</TEXTAREA>';
	
	# return
	return join('', @rv);
}
# 
# html_form_field
#-----------------------------------------------------------------------


# 
# DBIx::Record::Field::Textarea
########################################################################




########################################################################
# DBIx::Record::Field::ForeignKey
# 
package DBIx::Record::Field::ForeignKey;
use strict;
# use Dev::ShowStuff ':all';
use Carp 'cluck', 'croak', 'confess';
use vars qw[@ISA];
@ISA = 'DBIx::Record::Field::Text';



=head2 DBIx::Record::Field::ForeignKey

I<extends C<DBIx::Record::Field>>

A field that is a foreign key to another table.

=head2 foreign

The class name of the foreign table.

=head2 locked

If this field does not allow the user to change the value of the field.

=cut

#-----------------------------------------------------------------------
# record
# 

=head2 record($login)

Returns the record that this field references. Return undef if C<value>
if undef.

=cut

sub record {
	my ($self, %opts) = @_;
	
	if (! defined $self->{'value'})
		{return undef}
	
	return $self->{'foreign'}->new($self->{'login'}, $self->{'value'}, %opts);
}
# 
# record
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# validate
# 

=head2 validate($rec)

Uses the given record object to check if a record of the given class
exists with the primary key stored in C<value>.

=cut

sub validate {
	my ($self) = @_;
	
	# if it's not defined
	unless (defined $self->{'value'}) {
		# if it's required
		if ($self->{'required'})
			{return DBIx::Record::add_error($self->{'field_name'} . ' is required')}
		return 1;
	}
	
	# instantiate foreign record object
	my $foreign = $self->record;
	
	if (! $foreign->exists)
		{return DBIx::Record::add_error('Do not find primary key ' . $self->{'value'} . ' in table "' . $foreign->table_name . '"')}
	
	return 1;
}
# 
# validate
#-----------------------------------------------------------------------


# 
# DBIx::Record::Field::ForeignKey
########################################################################



########################################################################
# DBIx::Record::Field::Checkbox
# 
package DBIx::Record::Field::Checkbox;
use strict;
# use Dev::ShowStuff ':all';
use Carp 'cluck', 'croak', 'confess';
use vars qw[@ISA];
@ISA = 'DBIx::Record::Field';


=head2 DBIx::Record::Field::Checkbox I<extends C<DBIx::Record::Field>>

A field object of this class holds a true/false value. It is
represented in the user interface with a checkbox.

=head2 value

This property consists only of 1 or 0.

=head2 true_false_reps

This property contains the strings that indicate true or false. The
property consists of an L<C<LCHash>|/Tie::LCHash> in which each key is
a string that might be used to represent true or false. The value of
each hash element is 1 or 0. When data is input into the field using
the L<C<set_from_interface>|/DBIx::Record::Field.set_from_interface>
method, if the input value is defined and matches (on a crunched,
case-insensitive basis) any of the keys in the hash, then the value of
that hash element is stored. If the value does not exist in the hash,
then the value is stored based on its standard Perl truth or falseness.

This property defaults to these keys and values:

 {
 	1      =>  1,
 	0      =>  0,
 	y      =>  1,
 	n      =>  0,
 	yes    =>  1,
 	no     =>  0,
 	t      =>  1,
 	f      =>  0,
 	true   =>  1,
 	false  =>  0,
 }

=head2 output_db

This property holds the strings that are output to the database to
indicate true and false. The property consists of a hash with keys 1
and 0. The default value of this property is this hash:

 {
 	1  =>  1,
 	0  =>  0,
 }

=head2 output_interface

This property holds the strings that are output to the user interface
to indicate true and false. The property consists of a hash with keys 1
and 0. The default value of this property is this hash:

 {
 	1  =>  1,
 	0  =>  0,
 }

=head2 html_img

If this property is set, then when the data is represented in HTML, but
not in a form, the images defined in this property are displayed to
indicate true or false. This property can be used to present images of
checkboxes that look like the checkboxes in a form, but are not
editable.

This property should consist of an anon hash with two elements. The
keys for the hash are 1 and 0. The value of each element is a hash
consisting of the properties of the image. The properties of the image
are C<url>, C<height>, C<width>. An example of this property might
consist of this hash:

 {
 	1  => {
 		url    => '/images/yes.gif',
 		height => 15,
 		width  => 15,
 		},
 	
 	0  => {
 		url    => '/images/no.gif',
 		height => 15,
 		width  => 15,
 		},
 }

=cut

#-----------------------------------------------------------------------
# new
# 
sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	
	# defaults
	defined($self->{'value'}) or $self->{'value'} = 0;
	$self->{'output_db'} ||= {0=>0,1=>1};
	$self->{'output_interface'} ||= {0=>'No',1=>'Yes'};
	$self->{'true_false_reps'} ||= 
		{
			1      =>  1,
			0      =>  0,
			y      =>  1,
			n      =>  0,
			yes    =>  1,
			no     =>  0,
			t      =>  1,
			f      =>  0,
			true   =>  1,
			false  =>  0,
		};
	
	return $self
}
# 
# new
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# set_from_interface
# 

=head2 set_from_interface($val)

This method sets the value of the field according to this algorithm:

=over

=item * If $val is defined

=over

=item * crunch and lowercase $val

=item * if $val exists as a key in C<true_false_reps>

=over

=item * Set C<value> to the Perl truth or falseness of the hash value.

=back

=item * else

=over

=item * set C<value> $val.

=back

=back

=item * else

=over

=item * set C<value> to 0

=back

=back

=cut

sub set_from_interface {
	my ($self, $val) = @_;
	
	# if already false
	$val or return($self->{'value'} = 0);
	
	# crunch and lowercase
	DBIx::Record::crunch($val);
	$val = lc($val);
	
	# if long zero
	if ($self->{'long_zero'} && ( $val =~ m|^0+(\.0*)?$|s || $val =~ m|^\.0+$|s ) )
		{return $self->{'value'} = 0}
	
	# if one of the true or false words
	if (exists $self->{'true_false_reps'}->{$val})
		{return $self->{'value'} = $self->{'true_false_reps'}->{$val}}
	
	# set and return
	return ($self->{'value'} = $val ? 1 : 0);
}
# 
# set_from_interface
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# text_display
# 
sub text_display {
	my ($self) = @_;
	return $self->{'output_interface'}->{$self->{'value'}};
}
# 
# text_display
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# send_to_db
# 
sub send_to_db {
	my ($self) = @_;

	return $self->{'output_db'}->{$self->{'value'}};
}
# 
# send_to_db
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# html_display
# 
sub html_display {
	my $self = shift;
	
	# image
	if (my $img = $self->{'html_img'}->{$self->{'value'}}) {
		return
			'<IMG ',
			'SRC="', DBIx::Record::htmlesc($img->{'url'}), '" ',
			'HEIGHT="', DBIx::Record::htmlesc($img->{'height'}), '" ',
			'WIDTH="', DBIx::Record::htmlesc($img->{'width'}), '">';
	}
	
	return $self->{'output_interface'}->{$self->{'value'}};
}
# 
# html_display
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# html_form_field
# 
sub html_form_field {
	my ($self) = @_;
	my (@rv);
	
	# open tag
	push @rv,
		'<INPUT TYPE=CHECKBOX NAME="',
		DBIx::Record::htmlesc($self->{'field_name'}), '" ',
		'VALUE="1"';

	# checked
	if ($self->{'value'})
		{push @rv, ' CHECKED'}
	
	# close tag
	push @rv, '>';
	
	# return
	return join('', @rv);
}
# 
# html_form_field
#-----------------------------------------------------------------------



# 
# DBIx::Record::Field::Checkbox
########################################################################



########################################################################
# DBIx::Record::Field::Select
# 
package DBIx::Record::Field::Select;
use strict;
# use Dev::ShowStuff ':all';
use Carp 'cluck', 'croak', 'confess';
use vars qw[@ISA];
@ISA = 'DBIx::Record::Field';


=head2 DBIx::Record::Field::Select I<extends C<DBIx::Record::Field>>

Objects in this class have a defined, finite set of available options.
The user interface for this type of field is a dropdown selection in
which the user may select exactly one value.

=head2 options

This property consists of an array of values and value displays. The values and displays alternate: a value, 
then a display, then another value, then its display, etc.  

=head2 foreign

If this property is set, it gives the class name of a table.  This property indicates that the value of the 
field is a foreign key to the given table.  The primary keys and display values are retrieved from the class
using its C<display_options> and C<display_str> methods.

=cut

#-----------------------------------------------------------------------
# text_display
# 
sub text_display {
	my ($self) = @_;
	
	# if value is undefined
	if (! defined $self->{'value'})
		{return undef}
	
	# if we have an opt_hash
	if (defined $self->{'options'}) {
		for (my $i=0; $i<$#{$self->{'options'}}; $i+=2) {
			if ($self->{'value'} eq $self->{'options'}->[$i])
				{return $self->{'options'}->[$i+1]}
		}
		
		return undef;
	}
	
	# if we have a lookup property, get the value from that class
	if (defined $self->{'foreign'})
		{return $self->{'foreign'}->display_record_str($self->{'login'}, $self->{'value'})}
	
	# if we get this far, we have no way of getting the displayt string for the value
	die 'no way of getting the display string for the value';
}
# 
# text_display
#-----------------------------------------------------------------------



#-----------------------------------------------------------------------
# send_to_db
# 
sub send_to_db {
	my ($self) = @_;
	return $self->{'value'};
}
# 
# send_to_db
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# html_form_field
# 

=head2 html_form_field()

Returns HTML for a C<E<lt>SELECTE<gt>> field.

=cut

sub html_form_field {
	my ($self) = @_;
	my $value = $self->{'value'};
	my (@opener, @rv, $selected);
	$self->option_check;		
	
	# open tag
	push @opener, '<SELECT NAME="', DBIx::Record::htmlesc($self->{'field_name'}), "\">\n";
	
	# if there's an options array, output that
	if (defined $self->{'options'}) {
		for (my $i=0; $i<$#{$self->{'options'}}; $i+=2)
			{push @rv, select_option($selected, $value, $self->{'options'}->[$i], $self->{'options'}->[$i+1])}
	}
	
	# if there's a foreign key, output that table
	elsif (defined $self->{'foreign'}) {
		my $looper = $self->{'foreign'}->display_set($self->{'login'});
		
		while (my $rec = $looper->next)
			{push @rv, select_option($selected, $value, $rec->{'pk'}, $rec->display_str)}
	}
	
	# if the value was not found, and if there's a prompt option
	if ( (! $selected) && defined($self->{'undef_display'}) )
		{unshift @rv, '<OPTION VALUE="" SELECTED>', DBIx::Record::htmlesc($self->{'undef_display'}), "</OPTION>\n"}
	
	# close tag
	push @rv, '</SELECT>';
	
	# return
	return join('', @opener, @rv);
	
	# inner sub: output a single select option
	sub select_option {
		my ($selected_placeholder, $cval, $pk, $desc) = @_;
		my (@rvrv);
		
		push @rvrv, '<OPTION VALUE="', DBIx::Record::htmlesc($pk), '"';
		
		if (defined($cval) && ($cval eq $pk)) {
			$_[0] = 1;
			push @rvrv, ' SELECTED';
		}
		
		push @rvrv, '>', DBIx::Record::htmlesc($desc), "</OPTION>\n";
		return join('', @rvrv);
	}
}
# 
# html_form_field
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# validate
# 

=head2 validate($rec)

Checks that the value is one of the defined set of acceptable values.

=cut

sub validate {
	my ($self) = @_;
	my $rv = 1;

	# if it's required
	if (! DBIx::Record::hascontent $self->{'value'}) {
		if ($self->{'required'}) {
			$rv = DBIx::Record::Error->add (
				text => $self->{'desc_short'} . ' is a required field',
				html => '<CODE CLASS="field_desc_short">' . DBIx::Record::htmlesc($self->{'desc_short'}) . '</CODE> is a required field',
			);
		}
	}
	
	# else must be an existing choice
	else {
		$self->option_check;
		
		# options array
		if (defined $self->{'options'}) {
			my %options = @{$self->{'options'}};
			
			unless (exists $options{$self->{'value'}})
				{$rv = DBIx::Record::add_error('"' . $self->{'value'} . '" is not a valid option for the "' . $self->{'field_name'} . '" field')}
		}
		
		# else we have a foreign key
		else {
			unless ($self->{'foreign'}->exists($self->{'login'}, $self->{'value'}))
				{$rv = DBIx::Record::add_error('"' . $self->{'value'} . '" is not a valid option for the "' . $self->{'field_name'} . '" field')}
		}
	}
	
	return $rv;
}
# 
# validate
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# option_check
# 
sub option_check {
	my ($self) = @_;
	unless ($self->{'options'} or defined($self->{'foreign'}))
		{die 'Select object ' . $self->{'field_name'} . ' must have either an "options" or a "foreign" property'}
}
# 
# option_check
#-----------------------------------------------------------------------



# 
# DBIx::Record::Field::Select
########################################################################


########################################################################
# DBIx::Record::Field::Radio
# 
package DBIx::Record::Field::Radio;
use strict;
# use Dev::ShowStuff ':all';
use Carp 'cluck', 'croak', 'confess';
use vars qw[@ISA];
@ISA = 'DBIx::Record::Field::Select';


=head2 DBIx::Record::Field::Radio

I<extends C<DBIx::Record::Select>>

Works just like C<DBIx::Record::Select> except that it outputs radio
buttons instead of a select box.

=cut


#-----------------------------------------------------------------------
# html_form_field
# 

=head2 html_form_field()

Returns HTML for a set of radio buttons.

=cut

sub html_form_field {
	my ($self) = @_;
	my $value = $self->{'value'};
	my (@rv, $fn, @radios);
	$self->option_check;

	$fn = $self->{'field_name'};
	
	# if there's an options array, output that
	if (defined $self->{'options'}) {
		for (my $i=0; $i<$#{$self->{'options'}}; $i+=2)
			{push @radios, radio_button($value, $fn, $self->{'options'}->[$i], $self->{'options'}->[$i+1])}
	}
	
	# if there's a foreign key, output that table
	elsif (defined $self->{'foreign'}) {
		my $looper = $self->{'foreign'}->display_set($self->{'login'});
		while (my $rec = $looper->next)
			{push @radios, radio_button($value, $fn, $rec->{'pk'}, $rec->display_str)}
	}
	
	push @rv, join("<BR>\n", @radios);

	# return
	return join('', @rv);

	# inner sub: output radio button
	sub radio_button {
		my ($cval, $fieldname, $pk, $desc) = @_;
		my (@rvrv);
		
		push @rvrv,
			'<INPUT TYPE=RADIO NAME="',
			DBIx::Record::htmlesc($fieldname),
			'" VALUE="', DBIx::Record::htmlesc($pk), '"';
		
		if (defined($cval) && ($cval eq $pk))
			{push @rvrv, ' CHECKED'}
		
		push @rvrv, '>', DBIx::Record::htmlesc($desc);
		return join('', @rvrv);
	}
}
# 
# html_form_field
#-----------------------------------------------------------------------



# 
# DBIx::Record::Field::Radio
########################################################################



=head1 TERMS AND CONDITIONS

Copyright (c) 2002 by Miko O'Sullivan.  All rights reserved.  This program is 
free software; you can redistribute it and/or modify it under the same terms 
as Perl itself. This software comes with B<NO WARRANTY> of any kind.

=head1 AUTHOR

Miko O'Sullivan
F<miko@idocs.com>


=head1 VERSION

=over

=item Version 0.90    November 13, 2002

Initial release

=back


=begin CPAN

-------------------------------------------------------------------
Version 0.90

uploaded:  
appeared:  
announced: Nov 13, 2002

=end CPAN


=cut


# return true
1;
