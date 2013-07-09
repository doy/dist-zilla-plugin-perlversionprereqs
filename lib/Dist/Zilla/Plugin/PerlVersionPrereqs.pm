package Dist::Zilla::Plugin::PerlVersionPrereqs;
use Moose;

with 'Dist::Zilla::Role::InstallTool', 'Dist::Zilla::Role::MetaProvider';

has prereq_perl_version => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->plugin_name;
    },
);

has _prereqs => (
    is       => 'ro',
    isa      => 'HashRef[Str]',
    required => 1,
);

sub BUILDARGS {
    my $class = shift;

    my $opts = $class->SUPER::BUILDARGS(@_);

    my $zilla       = delete $opts->{zilla};
    my $plugin_name = delete $opts->{plugin_name};

    my %extra = map { $_ => delete $opts->{$_} } grep { /^\W/ } keys %$opts;

    return {
        zilla       => $zilla,
        plugin_name => $plugin_name,
        _prereqs    => $opts,
        (map { $_ => $extra{$_} } keys %extra),
    };
}

sub setup_installer {
    my $self = shift;

    my $perl_version = $self->prereq_perl_version;

    confess "You must specify a perl version"
        unless $perl_version;

    my ($makefile_pl) = grep { $_->name eq 'Makefile.PL' }
                             @{ $self->zilla->files };

    confess "This plugin only supports [MakeMaker]"
        unless $makefile_pl;

    my $prereqs = $self->_prereqs;
    return unless keys %$prereqs;

    my $content = $makefile_pl->content;

    my $prereq_string = join("\n        ", map {
        qq["$_" => "$prereqs->{$_}",]
    } keys %$prereqs);

    my $extra_content = <<EXTRA;
if (\$] < $perl_version) {
    \$WriteMakefileArgs{PREREQ_PM} = {
        \%{ \$WriteMakefileArgs{PREREQ_PM} },
        $prereq_string
    };
}
EXTRA

    $content =~ s/(WriteMakefile\()/$extra_content\n$1/
        or die "Couldn't update Makefile.PL contents";

    $makefile_pl->content($content);
}

sub metadata {
    return { dynamic_config => 1 };
}

around dump_config => sub {
    my $orig = shift;
    my $self = shift;

    my $config = $self->$orig(@_);

    $config->{''.__PACKAGE__} = {
        perl_version => $self->prereq_perl_version,
    };

    return $config;
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;
