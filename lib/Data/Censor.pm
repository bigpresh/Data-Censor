package Data::Censor;

use 5.006;
use strict;
use warnings FATAL => 'all';
use Carp;

=head1 NAME

Data::Censor - censor sensitive stuff in a data structure

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

    # OO way, letting you specify your own list of sensitive-looking fields, and
    # what they should be replaced by
    my $censor = Data::Censor->new(
        sensitive_fields => [ qw(card_number password) ],
        replacement => '(Sensitive data hidden)',
    );
    
    # Censor the data in-place (changes the data structure, returns the number
    # of keys censored)
    my $censor_count = $censor->censor(\%data);

    # Or clone the original data structure and return it after censoring:
    my $censored_data = $censor->censored_data(\%data);



=head1 new (CONSTRUCTOR)

Accepts the following arguments:

=over

=item sensitive_fields

Either an arrayref of sensitive fields, checked for equality, or a regex to test
against each key to see if it's considered sensitive.

=item replacement

The string to replace each value with

=item replacement_callbacks

A hashref of key => sub {...}, where each key is a column name to match, and the
coderef takes the uncensored value and returns the censored value, letting you
for instance mask a card number but leave the last 4 digits visible.

=back

=cut

sub new {
    my $class = shift;
    my %args = @_;

    my $self = bless {} => $class;

    if (ref $args{sensitive_fields} eq 'Regexp') {
        $self->{censor_regex} = $args{sensitive_fields};
    } elsif (ref $args{sensitive_fields} eq 'ARRAY') {
        $self->{is_sensitive_field} = { 
            map { $_ => 1 } @{ $args{sensitive_fields} }
        };
    } else {
        $self->{is_sensitive_field} = {
            map { $_ => 1 } qw(
                pass  password  secret  private_key
                cardnum  card_number  pan  cvv cvv2 ccv
            )
        };
    }

    if (ref $args{replacement_callbacks} eq 'HASH') {
        $self->{replacement_callbacks} = $args{replacement_callbacks};
    }
    if (exists $args{replacement}) {
        $self->{replacement} = $args{replacement};
    } else {
        $self->{replacement} = 'Hidden (looks potentially sensitive)';
    }

    $self->{recurse_limit} = $args{recurse_limit} || 100;

    return $self;
}

=head1 METHODS

=head2 censor

Given a data structure (hashref), clones it and returns the cloned version after
censoring potentially sensitive data within.

=cut

sub censor {
    my ($self, $data, $recurse_count) = @_;
    $recurse_count ||= 0;
    
    no warnings 'recursion'; # we're checking ourselves.

    if ($recurse_count++ > $self->{recurse_limit}) {
        warn "Data exceeding $self->{recurse_limit} levels";
        return;
    }

    if (ref $data ne 'HASH') {
        croak('censor expects a hashref');
    }
    
    my $censored = 0;
    for my $key (keys %$data) {
        if (ref $data->{$key} eq 'HASH') {
            $censored += $self->censor($data->{$key}, $recurse_count);
        } elsif (
            ($self->{is_sensitive_field} && $self->{is_sensitive_field}{lc $key})
            ||
            ($self->{censor_regex} && $key =~ $self->{censor_regex})
        ) {
            # OK, censor this
            if ($self->{replacement_callbacks}{lc $key}) {
                $data->{$key} = $self->{replacement_callbacks}{lc $key}->(
                    $data->{$key}
                );
                $censored++;
            } else {
                $data->{$key} = $self->{replacement};
                $censored++;
            }
        }
    }

    return $censored;
}

=head2 censored_data

Class method for quick censoring with default options - takes a hashref, clones
it, applies censoring, and returns the resulting cloned hashref.

=cut
sub censored_data {
    my $class = shift;
    my $data = shift;
    
    eval { require Clone; 1 }
        or die "Can't clone data without Clone installed";

    my $cloned_data = Clone::clone($data);
    $class->new->censor($cloned_data);
    return $cloned_data;
};


=head1 AUTHOR

David Precious (BIGPRESH), C<< <davidp at preshweb.co.uk> >>

This code was originally written for the L<Dancer> project by myself; I've
pulled it out into a seperate distribution as I was using it for code at work.



=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::Censor


=head1 LICENSE AND COPYRIGHT

Copyright 2014 David Precious.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Data::Censor
